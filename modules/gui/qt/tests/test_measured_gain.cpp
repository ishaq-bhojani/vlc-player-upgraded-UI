/*****************************************************************************
 * Copyright (C) 2026 Vireo contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <memory>
#include <optional>
#include <vector>

#include <QElapsedTimer>
#include <QFile>
#include <QSettings>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include <vlc/vlc.h>
#include <vlc_common.h>
#include <vlc_aout.h>
#include <vlc_input_item.h>
#include <vlc_meta.h>
#include <vlc_objects.h>
#include <vlc_player.h>
#include <vlc_variables.h>

#include "../../../../lib/libvlc_internal.h"

#include "../redesign/cpp/measuredgain.hpp"
#include "../redesign/cpp/measuredgainvlc.hpp"
#include "../redesign/cpp/waveform.hpp"
#include "../redesign/cpp/waveformvlc.hpp"

using namespace redesign;

namespace
{

// ---- a backend and a decoder without VLC ---------------------------------------------------

//! what the test sets and reads; the backend only forwards
struct FakeState
{
    MeasuredGainBackend::Media media;
    MeasuredGainSettings settings;
    QList<std::optional<float>> calls; //!< every setOutputGain()
    int mediaReads = 0;                //!< every currentMedia()
    QStringList modes;                 //!< every setReplayGainMode()

    //! the gain the output has now
    std::optional<float> current() const { return calls.isEmpty() ? std::nullopt : calls.last(); }
    int sets() const
    {
        int n = 0;
        for (const auto& c : calls)
            n += c.has_value() ? 1 : 0;
        return n;
    }
};

class FakeBackend : public MeasuredGainBackend
{
public:
    explicit FakeBackend(FakeState* state) : m_state(state) {}
    Media currentMedia() override
    {
        ++m_state->mediaReads;
        return m_state->media;
    }
    MeasuredGainSettings settings() override { return m_state->settings; }
    void setReplayGainMode(const QString& mode) override
    {
        m_state->modes.append(mode);
        m_state->settings.mode = mode;
    }
    void setOutputGain(std::optional<float> factor) override { m_state->calls.append(factor); }
    std::optional<float> outputGain() override { return m_state->current(); }

private:
    FakeState* m_state;
};

struct DecoderState
{
    std::atomic_int decodes{0};
    std::atomic_bool fail{false};
};

//! a file whose name contains "quiet" is -40 dBFS RMS (gain +4, limited), any other -20 dBFS (+2)
class FakeDecoder : public WaveformDecoder
{
public:
    explicit FakeDecoder(std::shared_ptr<DecoderState> state) : m_state(std::move(state)) {}

    DecodeResult decode(const QString& file, PeaksAccumulator& acc, CancelToken&) override
    {
        ++m_state->decodes;
        if (m_state->fail)
            return DecodeResult::Failed;
        const int16_t amplitude = file.contains("quiet") ? 328 : 3277;
        std::vector<int16_t> samples(80000, amplitude);
        for (size_t i = 0; i < samples.size(); i += 2)
            samples[i] = int16_t(-amplitude);
        acc.append(samples.data(), samples.size());
        return DecodeResult::Ok;
    }

private:
    std::shared_ptr<DecoderState> m_state;
};

constexpr float kLoudPeak = 3277.f / 32768.f;

/** 16-bit PCM WAV of a 440 Hz sine of the given amplitude. */
QByteArray makeWav(int rate, int channels, double seconds, double amplitude)
{
    const int frames = int(seconds * rate);
    QByteArray pcm(frames * channels * 2, Qt::Uninitialized);
    char* out = pcm.data();
    for (int i = 0; i < frames; ++i) {
        const double v = amplitude * std::sin(2.0 * 3.14159265358979323846 * 440.0 * i / rate);
        for (int c = 0; c < channels; ++c) {
            const int16_t s = int16_t(std::lround(v * 32767.0));
            std::memcpy(out, &s, 2);
            out += 2;
        }
    }
    QByteArray wav;
    auto put32 = [&wav](uint32_t v) { for (int i = 0; i < 4; ++i) wav.append(char((v >> (8 * i)) & 0xff)); };
    auto put16 = [&wav](uint16_t v) { for (int i = 0; i < 2; ++i) wav.append(char((v >> (8 * i)) & 0xff)); };
    wav.append("RIFF");
    put32(36 + uint32_t(pcm.size()));
    wav.append("WAVEfmt ");
    put32(16);
    put16(1);
    put16(uint16_t(channels));
    put32(uint32_t(rate));
    put32(uint32_t(rate * channels * 2));
    put16(uint16_t(channels * 2));
    put16(16);
    wav.append("data");
    put32(uint32_t(pcm.size()));
    wav.append(pcm);
    return wav;
}

//! the "gain" an audio output sees (its own variable, else the configuration)
double gainOf(audio_output_t* aout)
{
    return double(var_InheritFloat(aout, "gain"));
}

double rmsOf(const QByteArray& s16, qsizetype firstSample, qsizetype count)
{
    const int16_t* samples = reinterpret_cast<const int16_t*>(s16.constData());
    double sum = 0;
    for (qsizetype i = 0; i < count; ++i) {
        const double v = samples[firstSample + i];
        sum += v * v;
    }
    return std::sqrt(sum / double(count));
}

} // namespace

class TestMeasuredGain : public QObject
{
    Q_OBJECT

private slots:
    void init()
    {
        m_dir = std::make_unique<QTemporaryDir>();
        QVERIFY(m_dir->isValid());
        m_cache = m_dir->filePath("cache");
        m_ini = std::make_unique<QSettings>(m_dir->filePath("settings.ini"), QSettings::IniFormat);
    }

    void cleanup()
    {
        QTRY_COMPARE_WITH_TIMEOUT(WaveformProvider::activeJobs(), 0, 30000);
        m_ini.reset();
        m_dir.reset();
    }

    // ---- the decision -------------------------------------------------------------------

    void decisionTable()
    {
        const QUrl song("file:///music/a.mp3");
        const ReplayGainInfo none;
        QVERIFY(needsMeasuredGain(true, "track", song, none));

        QVERIFY(!needsMeasuredGain(false, "track", song, none));   // the choice is not Measured
        QVERIFY(!needsMeasuredGain(true, "none", song, none));     // the mode of VLC is not track
        QVERIFY(!needsMeasuredGain(true, "album", song, none));
        QVERIFY(!needsMeasuredGain(true, "", song, none));
    }

    void taggedFilesAreLeftAlone()
    {
        const QUrl song("file:///music/a.mp3");
        ReplayGainInfo track;
        track.trackGain = true;
        ReplayGainInfo album;
        album.albumGain = true;
        ReplayGainInfo both;
        both.trackGain = both.albumGain = true;
        QVERIFY(!needsMeasuredGain(true, "track", song, track));
        QVERIFY(!needsMeasuredGain(true, "track", song, album)); // VLC uses the other gain when its mode has none
        QVERIFY(!needsMeasuredGain(true, "track", song, both));
        QVERIFY(track.any() && album.any() && both.any());
        QVERIFY(!ReplayGainInfo().any());
    }

    void onlyLocalAudioFiles()
    {
        const ReplayGainInfo none;
        QVERIFY(!needsMeasuredGain(true, "track", QUrl("http://example.com/a.mp3"), none));
        QVERIFY(!needsMeasuredGain(true, "track", QUrl("https://example.com/a.mp3"), none));
        QVERIFY(!needsMeasuredGain(true, "track", QUrl("smb://host/share/a.mp3"), none));
        QVERIFY(!needsMeasuredGain(true, "track", QUrl("dvd:///dev/sr0"), none));
        QVERIFY(!needsMeasuredGain(true, "track", QUrl(), none));
        QVERIFY(!needsMeasuredGain(true, "track", QUrl("file:///videos/movie.mkv"), none)); // video
        QVERIFY(!needsMeasuredGain(true, "track", QUrl("file:///docs/readme.txt"), none));
        QVERIFY(!needsMeasuredGain(true, "track", QUrl("file:///music/noextension"), none));
        QVERIFY(!needsMeasuredGain(true, "track", QUrl("file:"), none));

        for (const char* name : {"a.mp3", "a.FLAC", "a.m4a", "dir.with.dots/a.ogg", "a.opus", "a.wav", "a.wma"})
            QVERIFY2(isLocalAudioFile(QUrl::fromLocalFile(QString("/music/") + name)), name);
        // a network share is a file url too
        QVERIFY(isLocalAudioFile(QUrl("file://nas/share/a.mp3")));
        QVERIFY(isLocalAudioFile(QUrl::fromLocalFile("C:/Music/\xC3\xA9t\xC3\xA9.mp3")));
    }

    // ---- the value handed to the audio output ---------------------------------------------

    void outputGainValues()
    {
        MeasuredGainSettings s;
        s.mode = "track";
        s.defaultGainDb = -7.f;
        s.preampDb = 0.f;
        s.peakProtection = true;
        s.userGain = 1.f;

        // 0 dB: VLC itself adds -7 dB to a stream without gain, the variable takes it back
        QVERIFY(std::abs(measuredOutputGain(0.f, 0.5f, s) - std::pow(10.f, 7.f / 20.f)) < 1e-4f);
        // +3 dB with room (peak 0.5 allows +6 dB)
        QVERIFY(std::abs(measuredOutputGain(3.f, 0.5f, s) - std::pow(10.f, 10.f / 20.f)) < 1e-4f);
        // -6 dB
        QVERIFY(std::abs(measuredOutputGain(-6.f, 1.f, s) - std::pow(10.f, 1.f / 20.f)) < 1e-4f);
        // the product with the gain VLC adds is the target alone
        for (float target : {-12.f, -3.f, 0.f}) {
            const float product = measuredOutputGain(target, 1.f, s) * std::pow(10.f, s.defaultGainDb / 20.f);
            QVERIFY(std::abs(product - std::pow(10.f, target / 20.f)) < 1e-4f);
        }
    }

    void peakProtectionLimitsABoost()
    {
        MeasuredGainSettings s;
        s.defaultGainDb = -7.f;
        // peak 1.0: no boost at all, as for a tag with that peak
        const float atFullScale = measuredOutputGain(4.f, 1.f, s);
        QVERIFY(std::abs(atFullScale * std::pow(10.f, -7.f / 20.f) - 1.f) < 1e-4f);
        // peak 0.8 allows +1.94 dB
        const float peak08 = measuredOutputGain(4.f, 0.8f, s);
        QVERIFY(std::abs(peak08 * std::pow(10.f, -7.f / 20.f) - 1.f / 0.8f) < 1e-3f);
        // a missing peak (0) or an invalid one counts as 1.0
        QCOMPARE(measuredOutputGain(4.f, 0.f, s), atFullScale);
        QCOMPARE(measuredOutputGain(4.f, -1.f, s), atFullScale);
        QCOMPARE(measuredOutputGain(4.f, std::nanf(""), s), atFullScale);
        // a cut is never limited
        QVERIFY(std::abs(measuredOutputGain(-9.f, 1.f, s) * std::pow(10.f, -7.f / 20.f) - std::pow(10.f, -9.f / 20.f)) < 1e-4f);
        // protection off: the boost goes through
        s.peakProtection = false;
        QVERIFY(std::abs(measuredOutputGain(4.f, 1.f, s) * std::pow(10.f, -7.f / 20.f) - std::pow(10.f, 4.f / 20.f)) < 1e-4f);
    }

    void preampAndUserGainAreKept()
    {
        MeasuredGainSettings s;
        s.defaultGainDb = -7.f;
        s.peakProtection = false;
        s.preampDb = 2.f;
        s.userGain = 1.5f;
        // userGain * 10^((measured + preamp)/20) once VLC's own default gain is counted
        const float product = measuredOutputGain(-3.f, 1.f, s) * std::pow(10.f, -7.f / 20.f);
        QVERIFY(std::abs(product - 1.5f * std::pow(10.f, -1.f / 20.f)) < 1e-4f);
        // not a number: no change of level
        QVERIFY(std::abs(measuredOutputGain(std::nanf(""), 1.f, s) * std::pow(10.f, -7.f / 20.f)
                         - 1.5f * std::pow(10.f, 2.f / 20.f)) < 1e-4f);
    }

    void choiceOfTheModeAndTheFlag()
    {
        QCOMPARE(replayGainChoice(true, "track"), QString("measured"));
        QCOMPARE(replayGainChoice(false, "track"), QString("track"));
        QCOMPARE(replayGainChoice(true, "album"), QString("album")); // Measured needs the mode track
        QCOMPARE(replayGainChoice(true, "none"), QString("none"));
        QCOMPARE(replayGainChoice(false, "none"), QString("none"));
    }

    // ---- MeasuredGain, against a fake player and decoder ----------------------------------------

    void appliesTheMeasuredGainOnceAnalysed()
    {
        FakeState state = trackState(makeFile("loud.mp3"));
        auto decoder = std::make_shared<DecoderState>();
        MeasuredGain gain(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
        gain.setEnabled(true);

        QVERIFY(!gain.active()); // the analysis runs on a worker
        QTRY_VERIFY_WITH_TIMEOUT(gain.active(), 5000);
        QVERIFY(state.current().has_value());
        QVERIFY2(std::abs(gain.gainDb() - 2.0) < 0.01, qPrintable(QString::number(gain.gainDb())));
        const float expected = measuredOutputGain(2.f, kLoudPeak, state.settings);
        QVERIFY2(std::abs(*state.current() - expected) < 0.01f, qPrintable(QString::number(*state.current())));
        QCOMPARE(decoder->decodes.load(), 1);
    }

    void aTaggedFileGetsNothing()
    {
        FakeState state = trackState(makeFile("loud.mp3"));
        state.media.tags.trackGain = true;
        auto decoder = std::make_shared<DecoderState>();
        MeasuredGain gain(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
        gain.setEnabled(true);
        QTest::qWait(300);
        QCOMPARE(state.sets(), 0);
        QVERIFY(!gain.active());
        QCOMPARE(decoder->decodes.load(), 0); // not even analysed
    }

    void nothingWhileTheChoiceIsNotMeasured()
    {
        FakeState state = trackState(makeFile("loud.mp3"));
        auto decoder = std::make_shared<DecoderState>();
        MeasuredGain gain(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
        QVERIFY(!gain.enabled());
        gain.refresh();
        QTest::qWait(300);
        QCOMPARE(state.sets(), 0);
        QCOMPARE(decoder->decodes.load(), 0);
        QCOMPARE(state.mediaReads, 0); // off: the player is not looked at

        // the mode of VLC must be track as well
        gain.setEnabled(true);
        QTRY_VERIFY_WITH_TIMEOUT(gain.active(), 5000);
        state.settings.mode = "album";
        gain.refresh();
        QVERIFY(!gain.active());
        QVERIFY(!state.current().has_value());
    }

    void switchingOffTakesTheGainBack()
    {
        FakeState state = trackState(makeFile("loud.mp3"));
        auto decoder = std::make_shared<DecoderState>();
        MeasuredGain gain(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
        gain.setEnabled(true);
        QTRY_VERIFY_WITH_TIMEOUT(gain.active(), 5000);
        gain.setEnabled(false);
        QVERIFY(!gain.active());
        QVERIFY(!state.current().has_value());
        QCOMPARE(gain.gainDb(), 0.0);
    }

    void waitsUntilTheInputRuns()
    {
        FakeState state = trackState(makeFile("loud.mp3"));
        state.media.settled = false; // opening: the tags of the file are not known yet
        auto decoder = std::make_shared<DecoderState>();
        MeasuredGain gain(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
        gain.setEnabled(true);
        QTRY_COMPARE_WITH_TIMEOUT(decoder->decodes.load(), 1, 5000);
        QTest::qWait(300);
        QCOMPARE(state.sets(), 0);

        state.media.settled = true;
        gain.refresh();
        QVERIFY(gain.active());
        QCOMPARE(state.sets(), 1);
    }

    void tagsThatAppearLaterTakeTheGainBack()
    {
        FakeState state = trackState(makeFile("loud.mp3"));
        auto decoder = std::make_shared<DecoderState>();
        MeasuredGain gain(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
        gain.setEnabled(true);
        QTRY_VERIFY_WITH_TIMEOUT(gain.active(), 5000);

        state.media.tags.trackGain = true; // the metadata arrived: the file has its own level
        gain.refresh();
        QVERIFY(!gain.active());
        QVERIFY(!state.current().has_value());
    }

    void theGainFollowsTheMedia()
    {
        const QUrl loud = makeFile("loud.mp3");
        const QUrl quiet = makeFile("quiet.mp3");
        FakeState state = trackState(loud);
        auto decoder = std::make_shared<DecoderState>();
        MeasuredGain gain(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
        gain.setEnabled(true);
        QTRY_VERIFY_WITH_TIMEOUT(gain.active(), 5000);
        const float first = *state.current();

        // the next track: the loud one's gain is gone at once, the quiet one's comes after its analysis
        state.media.url = quiet;
        gain.refresh();
        QVERIFY(!gain.active());
        QVERIFY(!state.current().has_value());
        QTRY_VERIFY_WITH_TIMEOUT(gain.active(), 5000);
        QVERIFY(state.current().has_value());
        QVERIFY2(std::abs(gain.gainDb() - 4.0) < 0.01, qPrintable(QString::number(gain.gainDb()))); // limited to +4
        QVERIFY(*state.current() != first);

        // a stream: nothing, and the analysis stops
        state.media.url = QUrl("http://example.com/radio.mp3");
        gain.refresh();
        QVERIFY(!gain.active());
        QVERIFY(!state.current().has_value());
    }

    void aCachedFileIsLevelledWithoutDecoding()
    {
        const QUrl song = makeFile("loud.mp3");
        auto decoder = std::make_shared<DecoderState>();
        {
            FakeState state = trackState(song);
            MeasuredGain gain(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
            gain.setEnabled(true);
            QTRY_VERIFY_WITH_TIMEOUT(gain.active(), 5000);
            QCOMPARE(decoder->decodes.load(), 1);
        }
        FakeState state = trackState(song);
        MeasuredGain again(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
        QVERIFY(again.enabled()); // remembered
        again.refresh();
        QTRY_VERIFY_WITH_TIMEOUT(again.active(), 5000);
        QCOMPARE(decoder->decodes.load(), 1);
        QVERIFY(std::abs(again.gainDb() - 2.0) < 0.01);
    }

    void anUnanalysableFileKeepsTheOutputAlone()
    {
        FakeState state = trackState(makeFile("loud.mp3"));
        auto decoder = std::make_shared<DecoderState>();
        decoder->fail = true;
        MeasuredGain gain(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
        gain.setEnabled(true);
        QTRY_COMPARE_WITH_TIMEOUT(decoder->decodes.load(), 1, 5000);
        QTest::qWait(200);
        QVERIFY(!gain.active());
        QCOMPARE(state.sets(), 0);
    }

    void aRefreshThatChangesNothingDoesNotTouchTheOutput()
    {
        FakeState state = trackState(makeFile("loud.mp3"));
        auto decoder = std::make_shared<DecoderState>();
        MeasuredGain gain(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
        gain.setEnabled(true);
        QTRY_VERIFY_WITH_TIMEOUT(gain.active(), 5000);
        QCOMPARE(state.sets(), 1);

        // metadata and info events: nothing to set again
        for (int i = 0; i < 5; ++i)
            gain.refresh();
        QCOMPARE(state.sets(), 1);

        // the player thread took the gain off for a new input of the same file: levelled again
        state.calls.append(std::nullopt);
        gain.refresh();
        QCOMPARE(state.sets(), 2);

        // another preamp is another value
        state.settings.preampDb = -2.f;
        gain.refresh();
        QCOMPARE(state.sets(), 3);
    }

    void destroyingItDoesNotSignal()
    {
        FakeState state = trackState(makeFile("loud.mp3"));
        auto decoder = std::make_shared<DecoderState>();
        int emissions = 0;
        {
            MeasuredGain gain(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
            gain.setEnabled(true);
            QTRY_VERIFY_WITH_TIMEOUT(gain.active(), 5000);
            connect(&gain, &MeasuredGain::activeChanged, this, [&] { ++emissions; });
        }
        QCOMPARE(emissions, 0);
        QVERIFY(!state.current().has_value()); // the output was still given back
    }

    void destroyingItGivesTheOutputBackItsOwnGain()
    {
        FakeState state = trackState(makeFile("loud.mp3"));
        auto decoder = std::make_shared<DecoderState>();
        {
            MeasuredGain gain(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
            gain.setEnabled(true);
            QTRY_VERIFY_WITH_TIMEOUT(gain.active(), 5000);
            QVERIFY(state.current().has_value());
        }
        QVERIFY(!state.current().has_value());
    }

    void theChoiceIsStoredAndDrivesTheMode()
    {
        FakeState state = trackState(makeFile("loud.mp3"));
        state.settings.mode = "none";
        auto decoder = std::make_shared<DecoderState>();
        MeasuredGain gain(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
        QCOMPARE(gain.choice(), QString("none"));

        QSignalSpy choiceChanged(&gain, &MeasuredGain::choiceChanged);
        gain.setChoice("measured");
        QCOMPARE(state.modes, QStringList{"track"}); // "Measured" is the mode track plus the flag
        QVERIFY(gain.enabled());
        QCOMPARE(gain.choice(), QString("measured"));
        QVERIFY(choiceChanged.count() >= 1);
        QCOMPARE(m_ini->value("redesign/measuredLoudness").toBool(), true);
        QTRY_VERIFY_WITH_TIMEOUT(gain.active(), 5000);

        gain.setChoice("album");
        QCOMPARE(state.modes.last(), QString("album"));
        QVERIFY(!gain.enabled());
        QCOMPARE(gain.choice(), QString("album"));
        QCOMPARE(m_ini->value("redesign/measuredLoudness").toBool(), false);
        QVERIFY(!gain.active());
        QVERIFY(!state.current().has_value());

        gain.setChoice("track");
        QCOMPARE(gain.choice(), QString("track"));
        QVERIFY(!gain.enabled());
        gain.setChoice("none");
        QCOMPARE(gain.choice(), QString("none"));

        const int modes = state.modes.size();
        gain.setChoice("nonsense");
        QCOMPARE(state.modes.size(), modes);
        QCOMPARE(gain.choice(), QString("none"));
    }

    void theFlagIsPersistedUnderTheRedesignGroup()
    {
        FakeState state = trackState(makeFile("loud.mp3"));
        auto decoder = std::make_shared<DecoderState>();
        {
            MeasuredGain gain(std::make_unique<FakeBackend>(&state), env(decoder), m_ini.get());
            QVERIFY(!gain.enabled());
            gain.setEnabled(true);
        }
        m_ini->sync();
        m_ini->beginGroup("redesign");
        QCOMPARE(m_ini->value("measuredLoudness").toBool(), true);
        m_ini->endGroup();

        FakeState other = trackState(makeFile("loud.mp3"));
        MeasuredGain second(std::make_unique<FakeBackend>(&other), env(decoder), m_ini.get());
        QVERIFY(second.enabled());
    }

    // ---- the VLC backend: a real player and audio output --------------------------------------

    void backendSetsAndRemovesTheGainOnTheAudioOutput()
    {
        VlcRig rig(this);
        QVERIFY(rig.ok());

        audio_output_t* aout = vlc_player_aout_Hold(rig.player);
        QVERIFY(aout);
        QCOMPARE(var_Type(aout, "gain"), 0);
        QCOMPARE(gainOf(aout), 1.0);

        QVERIFY(!rig.backend->outputGain().has_value());
        rig.backend->setOutputGain(0.5f);
        QCOMPARE(gainOf(aout), 0.5);
        QCOMPARE(rig.backend->outputGain().value_or(-1.f), 0.5f);
        // only this output: the configuration is untouched
        QCOMPARE(double(var_InheritFloat(rig.holder, "gain")), 1.0);
        rig.backend->setOutputGain(0.25f);
        QCOMPARE(gainOf(aout), 0.25);

        rig.backend->setOutputGain(std::nullopt);
        QCOMPARE(var_Type(aout, "gain"), 0);
        QCOMPARE(gainOf(aout), 1.0);
        QVERIFY(!rig.backend->outputGain().has_value());
        // nothing to take back: no error, no variable
        rig.backend->setOutputGain(std::nullopt);
        QCOMPARE(var_Type(aout, "gain"), 0);
        aout_Release(aout);
    }

    void releaseRemovesAGainCreatedAfterTheMediaChangeCleared()
    {
        VlcRig rig(this);
        QVERIFY(rig.ok());
        const QUrl first = writeWav("one.wav", 1.0, 0.2);
        const QUrl second = writeWav("two.wav", 1.0, 0.2);
        audio_output_t* aout = vlc_player_aout_Hold(rig.player);
        QVERIFY(aout);

        // the sequence of the race: the media change (listener) runs while the variable does not
        // exist yet, and the gain is created right after it, for the new media
        rig.setMedia(first);
        rig.setMedia(second);
        QTRY_COMPARE_WITH_TIMEOUT(rig.backend->currentMedia().url, second, 5000);
        QCOMPARE(var_Type(aout, "gain"), 0);
        rig.backend->setOutputGain(0.5f);
        QCOMPARE(var_Type(aout, "gain") != 0, true);

        // the following release removes it, whatever the listener did before
        rig.backend->setOutputGain(std::nullopt);
        QCOMPARE(var_Type(aout, "gain"), 0);
        QCOMPARE(gainOf(aout), 1.0);

        // and a variable that this backend knows nothing about (made after the listener ran) goes too
        var_Create(aout, "gain", VLC_VAR_FLOAT);
        var_SetFloat(aout, "gain", 3.f);
        rig.backend->setOutputGain(std::nullopt);
        QCOMPARE(var_Type(aout, "gain"), 0);
        QCOMPARE(gainOf(aout), 1.0);
        aout_Release(aout);
    }

    void backendDropsTheGainWhenTheMediaChanges()
    {
        VlcRig rig(this);
        QVERIFY(rig.ok());
        const QUrl first = writeWav("one.wav", 1.0, 0.2);
        const QUrl second = writeWav("two.wav", 1.0, 0.2);

        rig.setMedia(first);
        rig.backend->setOutputGain(2.f);
        audio_output_t* aout = vlc_player_aout_Hold(rig.player);
        QVERIFY(aout);
        QCOMPARE(var_Type(aout, "gain") != 0, true);

        // the player thread calls back before the new input exists
        rig.setMedia(second);
        QTRY_COMPARE_WITH_TIMEOUT(var_Type(aout, "gain"), 0, 5000);
        QCOMPARE(gainOf(aout), 1.0);
        aout_Release(aout);
    }

    void backendReadsTheModeAndWritesIt()
    {
        VlcRig rig(this);
        QVERIFY(rig.ok());
        MeasuredGainSettings s = rig.backend->settings();
        QCOMPARE(s.mode, QString("none"));
        QCOMPARE(s.defaultGainDb, -7.f);
        QCOMPARE(s.preampDb, 0.f);
        QVERIFY(s.peakProtection);
        QCOMPARE(s.userGain, 1.f);

        rig.backend->setReplayGainMode("track");
        QCOMPARE(rig.backend->settings().mode, QString("track"));
        // the configuration (the next start) and the running output (now)
        char* config = var_InheritString(rig.holder, "audio-replay-gain-mode");
        QCOMPARE(QString::fromUtf8(config), QString("track"));
        free(config);
        audio_output_t* aout = vlc_player_aout_Hold(rig.player);
        QVERIFY(aout);
        char* live = var_GetString(aout, "audio-replay-gain-mode");
        QCOMPARE(QString::fromUtf8(live), QString("track"));
        free(live);
        aout_Release(aout);

        rig.backend->setReplayGainMode("none");
        QCOMPARE(rig.backend->settings().mode, QString("none"));
    }

    void backendSeesTheTagsOfTheCurrentMedia()
    {
        VlcRig rig(this);
        QVERIFY(rig.ok());
        QVERIFY(rig.backend->currentMedia().url.isEmpty());

        const QUrl plain = writeWav("plain.wav", 0.5, 0.2);
        rig.setMedia(plain);
        QTRY_COMPARE_WITH_TIMEOUT(rig.backend->currentMedia().url, plain, 5000);
        MeasuredGainBackend::Media media = rig.backend->currentMedia();
        QVERIFY(!media.tags.any());
        QVERIFY(!media.settled); // not started

        const QUrl tagged = writeWav("tagged.wav", 0.5, 0.2);
        rig.setMedia(tagged, "REPLAYGAIN_TRACK_GAIN", "-6.50 dB");
        QTRY_COMPARE_WITH_TIMEOUT(rig.backend->currentMedia().url, tagged, 5000);
        media = rig.backend->currentMedia();
        QVERIFY(media.tags.trackGain);
        QVERIFY(!media.tags.albumGain);

        const QUrl album = writeWav("album.wav", 0.5, 0.2);
        rig.setMedia(album, "replaygain_album_gain", "-3.00 dB");
        QTRY_COMPARE_WITH_TIMEOUT(rig.backend->currentMedia().url, album, 5000);
        media = rig.backend->currentMedia();
        QVERIFY(!media.tags.trackGain);
        QVERIFY(media.tags.albumGain);
    }

    // ---- the gain really changes what is played, during playback, without the volume -------------

    void aGainSetDuringPlaybackChangesTheLevel()
    {
        VlcRig rig(this, /*toFile*/ true);
        QVERIFY(rig.ok());
        const QUrl tone = writeWav("tone.wav", 4.0, 0.25);

        rig.setMedia(tone);
        // the output writes about a second ahead of the clock: 1.5 s in, the last half second is still to come
        rig.play([&] { rig.backend->setOutputGain(0.5f); });

        const QByteArray out = rig.output();
        const qsizetype samples = out.size() / 2;
        QVERIFY2(samples > 44100 * 2 * 3, qPrintable(QString::number(samples)));
        const double before = rmsOf(out, 0, 44100 / 2);          // the first quarter second
        const double after = rmsOf(out, samples - 44100, 44100); // the last half second (stereo samples)
        qInfo() << "level before" << before << "after" << after << "ratio" << after / before;
        QVERIFY(before > 1000.0);
        QVERIFY2(std::abs(after / before - 0.5) < 0.03, qPrintable(QString::number(after / before)));
    }

    void measuredModeAppliesTheTargetOnAnUntaggedTrack()
    {
        // mode none: the file at its own level; mode track + the measured gain: +3 dB above it
        const QUrl tone = writeWav("tone.wav", 3.0, 0.25);
        double plain = 0;
        {
            VlcRig rig(this, true);
            QVERIFY(rig.ok());
            rig.setMedia(tone);
            rig.play({});
            const QByteArray out = rig.output();
            plain = rmsOf(out, out.size() / 2 - 44100, 44100);
        }
        QVERIFY(plain > 1000.0);

        VlcRig rig(this, true);
        QVERIFY(rig.ok());
        rig.backend->setReplayGainMode("track"); // VLC alone would now play it 7 dB lower
        rig.setMedia(tone);
        MeasuredGainSettings s = rig.backend->settings();
        QCOMPARE(s.mode, QString("track"));
        rig.play({}, /*beforeStart*/ [&] {
            rig.backend->setOutputGain(measuredOutputGain(3.f, 0.25f, s));
        });
        const QByteArray out = rig.output();
        const double measured = rmsOf(out, out.size() / 2 - 44100, 44100);
        const double db = 20.0 * std::log10(measured / plain);
        qInfo() << "measured mode vs plain:" << db << "dB";
        QVERIFY2(std::abs(db - 3.0) < 0.4, qPrintable(QString::number(db)));
    }

private:
    //! a libvlc instance on a throwaway profile with a player on a holder object: the audio
    //! output is the dummy one, or the "file" one that writes the samples to <dir>/out.raw
    class VlcRig
    {
    public:
        VlcRig(TestMeasuredGain* test, bool toFile = false)
            : t(test)
            , outFile(test->m_dir->filePath("out.raw"))
        {
            setenv("VLC_PLUGIN_PATH", TOP_BUILDDIR"/modules", 0);
            setenv("VLC_LIB_PATH", TOP_BUILDDIR"/modules", 0);
            config = test->m_dir->filePath("vlcrc").toUtf8();
            const QByteArray configArg = "--config=" + config;
            const char* argv[] = {"--ignore-config", configArg.constData(), "--no-media-library"};
            vlc = libvlc_new(3, argv);
            if (!vlc)
                return;
            holder = createWaveformHolder(VLC_OBJECT(vlc->p_libvlc_int));
            if (!holder)
                return;
            if (toFile) {
                var_SetString(holder, "aout", "file");
                var_Create(holder, "audiofile-file", VLC_VAR_STRING);
                var_SetString(holder, "audiofile-file", outFile.toUtf8().constData());
                var_Create(holder, "audiofile-wav", VLC_VAR_BOOL);
                var_SetBool(holder, "audiofile-wav", false);
                var_Create(holder, "audiofile-format", VLC_VAR_STRING);
                var_SetString(holder, "audiofile-format", "s16");
            }
            player = vlc_player_New(holder, VLC_PLAYER_LOCK_NORMAL);
            if (!player)
                return;
            backend = makeVlcMeasuredGainBackend(player, VLC_OBJECT(vlc->p_libvlc_int));
        }

        ~VlcRig()
        {
            backend.reset();
            if (player)
                vlc_player_Delete(player);
            if (holder)
                vlc_object_delete(holder);
            if (vlc)
                libvlc_release(vlc);
        }

        bool ok() const { return backend != nullptr; }

        void setMedia(const QUrl& url, const char* tagKey = nullptr, const char* tagValue = nullptr)
        {
            const QByteArray uri = url.toEncoded();
            input_item_t* item = input_item_New(uri.constData(), nullptr);
            QVERIFY(item);
            if (tagKey) {
                vlc_meta_t* meta = vlc_meta_New();
                vlc_meta_SetExtra(meta, tagKey, tagValue);
                vlc_mutex_lock(&item->lock);
                item->p_meta = meta;
                vlc_mutex_unlock(&item->lock);
            }
            vlc_player_Lock(player);
            QCOMPARE(vlc_player_SetCurrentMedia(player, item), int(VLC_SUCCESS));
            vlc_player_Unlock(player);
            input_item_Release(item);
        }

        //! starts the current media, calls `midway` after 1.5 s of it, returns when it ended
        void play(const std::function<void()>& midway, const std::function<void()>& beforeStart = {})
        {
            if (beforeStart)
                beforeStart();
            vlc_player_Lock(player);
            QCOMPARE(vlc_player_Start(player), int(VLC_SUCCESS));
            vlc_player_Unlock(player);

            QElapsedTimer timer;
            timer.start();
            bool started = false;
            bool called = !midway;
            while (timer.elapsed() < 40000) {
                QTest::qWait(20);
                vlc_player_Lock(player);
                const enum vlc_player_state state = vlc_player_GetState(player);
                vlc_player_Unlock(player);
                if (state != VLC_PLAYER_STATE_STOPPED)
                    started = true;
                else if (started)
                    break;
                if (!called && timer.elapsed() > 1500) {
                    midway();
                    called = true;
                }
            }
            QVERIFY(started);
            QVERIFY(called);
        }

        //! what the "file" output wrote: 16-bit samples
        QByteArray output() const
        {
            // the file is closed when the stream ends; give the output a moment
            QFile f(outFile);
            for (int i = 0; i < 100 && (!f.exists() || f.size() == 0); ++i)
                QTest::qWait(20);
            return f.open(QIODevice::ReadOnly) ? f.readAll() : QByteArray();
        }

        TestMeasuredGain* t;
        QString outFile;
        QByteArray config;
        libvlc_instance_t* vlc = nullptr;
        vlc_object_t* holder = nullptr;
        vlc_player_t* player = nullptr;
        std::unique_ptr<MeasuredGainBackend> backend;
    };

    //! the environment of the analysis: the cache of the test and a fake decoder
    WaveformEnvironment env(const std::shared_ptr<DecoderState>& decoder)
    {
        WaveformEnvironment e;
        e.cacheDir = m_cache;
        e.makeDecoder = [decoder] { return std::make_unique<FakeDecoder>(decoder); };
        return e;
    }

    //! the state of a player that plays an untagged song in the mode track, started
    FakeState trackState(const QUrl& url)
    {
        FakeState state;
        state.settings.mode = "track";
        state.settings.defaultGainDb = -7.f;
        state.media.url = url;
        state.media.settled = true;
        return state;
    }

    QUrl makeFile(const QString& name, const QByteArray& content = QByteArray(64, 'a'))
    {
        const QString path = m_dir->filePath(name);
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly) || f.write(content) != content.size())
            qFatal("cannot write %s", qPrintable(path));
        return QUrl::fromLocalFile(path);
    }

    QUrl writeWav(const QString& name, double seconds, double amplitude)
    {
        return makeFile(name, makeWav(44100, 2, seconds, amplitude));
    }

    std::unique_ptr<QTemporaryDir> m_dir;
    std::unique_ptr<QSettings> m_ini;
    QString m_cache;
};

QTEST_GUILESS_MAIN(TestMeasuredGain)
#include "test_measured_gain.moc"
