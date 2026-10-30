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
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

#include <QDateTime>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include <vlc/vlc.h>
#include <vlc_common.h>
#include <vlc_objects.h>
#include <vlc_player.h>
#include <vlc_variables.h>

#include "../../../../lib/libvlc_internal.h"

#include "../redesign/cpp/waveform.hpp"
#include "../redesign/cpp/waveformvlc.hpp"

using namespace redesign;

namespace
{

//! shared state of a FakeDecoder: the test keeps it after the provider took the decoder
struct FakeState
{
    std::atomic_int decodes{0};
    std::atomic_int running{0};
    std::atomic_int maxRunning{0};
    std::atomic_int cancelled{0};
    std::atomic_bool hold{false};      //!< a decode blocks while this is set (or until it is cancelled)
    std::atomic_bool fail{false};      //!< the decode fails for good
    std::atomic_bool interrupt{false}; //!< the decode is interrupted (transient failure)
    std::vector<int16_t> samples;

    std::mutex mutex;
    QStringList order;                 //!< the files in the order their decode started
};

class FakeDecoder : public WaveformDecoder
{
public:
    explicit FakeDecoder(std::shared_ptr<FakeState> state) : m_state(std::move(state)) {}

    DecodeResult decode(const QString& file, PeaksAccumulator& acc, CancelToken& cancel) override
    {
        FakeState& s = *m_state;
        ++s.decodes;
        {
            std::lock_guard<std::mutex> lock(s.mutex);
            s.order.append(file);
        }
        const int now = ++s.running;
        int prev = s.maxRunning;
        while (now > prev && !s.maxRunning.compare_exchange_weak(prev, now)) {}

        while (s.hold && !cancel.cancelled())
            std::this_thread::sleep_for(std::chrono::milliseconds(5));

        DecodeResult result = DecodeResult::Ok;
        if (cancel.cancelled()) {
            ++s.cancelled;
            result = DecodeResult::Interrupted;
        } else if (s.fail) {
            result = DecodeResult::Failed;
        } else if (s.interrupt) {
            result = DecodeResult::Interrupted;
        } else {
            acc.append(s.samples.data(), s.samples.size());
        }
        --s.running;
        return result;
    }

private:
    std::shared_ptr<FakeState> m_state;
};

//! 100000 samples, one of them 16384 at index 25000 (bucket 250 of 1000)
std::shared_ptr<FakeState> makeState()
{
    auto state = std::make_shared<FakeState>();
    state->samples.assign(100000, 0);
    state->samples[25000] = 16384;
    return state;
}

//! 80000 samples of +-3277 (0.1 of full scale): RMS -20 dBFS, so the measured gain is +2 dB
std::shared_ptr<FakeState> makeLoudState()
{
    auto state = std::make_shared<FakeState>();
    state->samples.assign(80000, 3277);
    for (size_t i = 0; i < state->samples.size(); i += 2)
        state->samples[i] = -3277;
    return state;
}

WaveformEnvironment makeEnv(const QString& cacheDir, const std::shared_ptr<FakeState>& state)
{
    WaveformEnvironment env;
    env.cacheDir = cacheDir;
    env.makeDecoder = [state] { return std::make_unique<FakeDecoder>(state); };
    return env;
}

/**
 * Wraps the real decoder: counts the starts and ends, remembers how many samples every decode
 * got, and can freeze one decode at its first chunk (holdNext) until it is cancelled, so that a
 * test cancels or destroys a provider while samples demonstrably flow and the input is busy.
 */
struct ProbeState
{
    std::atomic_bool holdNext{false};
    std::atomic<size_t> reached{0}; //!< samples of the latest chunk
    std::atomic_int started{0};
    std::atomic_int ended{0};
    std::mutex mutex;
    std::vector<size_t> finals;     //!< samples of every ended decode
    std::vector<int> results;       //!< DecodeResult of every ended decode
};

class ProbeDecoder : public WaveformDecoder
{
public:
    ProbeDecoder(vlc_object_t* obj, std::shared_ptr<ProbeState> state)
        : m_inner(makeVlcWaveformDecoder(obj))
        , m_state(std::move(state))
        , m_hold(m_state->holdNext.exchange(false))
    {
    }

    DecodeResult decode(const QString& file, PeaksAccumulator& acc, CancelToken& cancel) override
    {
        ++m_state->started;
        acc.setProgressCallback([this, &cancel](size_t n) {
            m_state->reached = n;
            while (m_hold && !cancel.cancelled())
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
        });
        const DecodeResult result = m_inner->decode(file, acc, cancel);
        {
            std::lock_guard<std::mutex> lock(m_state->mutex);
            m_state->finals.push_back(acc.sampleCount());
            m_state->results.push_back(int(result));
        }
        ++m_state->ended;
        return result;
    }

private:
    std::unique_ptr<WaveformDecoder> m_inner;
    std::shared_ptr<ProbeState> m_state;
    bool m_hold;
};

/** The jobs of the process are over (they use the libvlc instance that is released next). */
struct IdleGuard
{
    ~IdleGuard()
    {
        QElapsedTimer timer;
        timer.start();
        while (WaveformProvider::activeJobs() > 0 && timer.elapsed() < 30000)
            QTest::qWait(10);
    }
};

/** 16 or 8-bit PCM WAV: `silenceSec` of silence, then `toneSec` of a 440 Hz sine of the given amplitude. */
QByteArray makeWav(int rate, int channels, double silenceSec, double toneSec, double amplitude, int bits = 16)
{
    const int frames = int((silenceSec + toneSec) * rate);
    const int silentFrames = int(silenceSec * rate);
    const int bytesPerSample = bits / 8;
    QByteArray pcm;
    pcm.resize(frames * channels * bytesPerSample);
    char* out = pcm.data();
    for (int i = 0; i < frames; ++i) {
        const double v = i < silentFrames ? 0.0 : amplitude * std::sin(2.0 * 3.14159265358979323846 * 440.0 * i / rate);
        for (int c = 0; c < channels; ++c) {
            if (bits == 16) {
                const int16_t s = int16_t(std::lround(v * 32767.0));
                std::memcpy(out, &s, 2);
            } else {
                *reinterpret_cast<uint8_t*>(out) = uint8_t(128 + std::lround(v * 127.0)); // unsigned
            }
            out += bytesPerSample;
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
    put32(uint32_t(rate * channels * bytesPerSample));
    put16(uint16_t(channels * bytesPerSample));
    put16(uint16_t(bits));
    wav.append("data");
    put32(uint32_t(pcm.size()));
    wav.append(pcm);
    return wav;
}

} // namespace

class TestWaveform : public QObject
{
    Q_OBJECT

private slots:
    void init()
    {
        m_dir = std::make_unique<QTemporaryDir>();
        QVERIFY(m_dir->isValid());
        m_cache = m_dir->filePath("cache");
    }

    void cleanup()
    {
        // the jobs of a test are over before its files go away
        QTRY_COMPARE_WITH_TIMEOUT(WaveformProvider::activeJobs(), 0, 30000);
        m_dir.reset();
    }

    // ---- computePeaks / encoding -------------------------------------------------

    void peaksOfSilence()
    {
        std::vector<int16_t> samples(50000, 0);
        const QVector<float> peaks = computePeaks(samples.data(), samples.size(), 1000);
        QCOMPARE(peaks.size(), 1000);
        for (float p : peaks)
            QCOMPARE(p, 0.f);
    }

    void peakValue()
    {
        std::vector<int16_t> samples(10000, 0);
        samples[3 * 10 + 4] = 16384; // bucket 3 holds the samples 30..39
        samples[3 * 10 + 5] = -8192;
        const QVector<float> peaks = computePeaks(samples.data(), samples.size(), 1000);
        QCOMPARE(peaks.size(), 1000);
        QCOMPARE(peaks[3], 0.5f);
        for (int i = 0; i < peaks.size(); ++i)
            if (i != 3)
                QCOMPARE(peaks[i], 0.f);
    }

    void peakOfNegativeFullScale()
    {
        std::vector<int16_t> samples(2000, 0);
        samples[1999] = -32768;
        const QVector<float> peaks = computePeaks(samples.data(), samples.size(), 1000);
        QCOMPARE(peaks[999], 1.f);
    }

    void shortInput()
    {
        std::vector<int16_t> samples(10, 0);
        samples[2] = 16384;
        const QVector<float> peaks = computePeaks(samples.data(), samples.size(), 1000);
        QCOMPARE(peaks.size(), 1000);
        QCOMPARE(peaks[2], 0.5f);
        for (int i = 10; i < 1000; ++i)
            QCOMPARE(peaks[i], 0.f);

        QCOMPARE(computePeaks(nullptr, 0, 1000).size(), 1000);
    }

    void encodeRoundTrip()
    {
        QVector<float> peaks;
        for (int i = 0; i < 1000; ++i)
            peaks.append(float(i) / 1000.f);
        const QByteArray bytes = encodePeaks(peaks);
        QCOMPARE(bytes.size(), 4000);
        // little endian float32: 1.0f is 00 00 80 3f
        QCOMPARE(encodePeaks({1.f}), QByteArray::fromHex("0000803f"));
        QCOMPARE(decodePeaks(bytes), peaks);
    }

    void decodeRejectsOddSize()
    {
        QVERIFY(decodePeaks(QByteArray(7, 'x')).isEmpty());
        QVERIFY(decodePeaks(QByteArray(4001, 'x')).isEmpty());
        QVERIFY(decodePeaks(QByteArray()).isEmpty());
    }

    // ---- accumulator ----------------------------------------------------------------

    void accumulatorKeepsPeakPositionAcrossFolds()
    {
        // far more samples than the accumulator stores: it folds blocks, the peak stays in its bucket
        PeaksAccumulator acc;
        const size_t total = 5 * 1000 * 1000;
        std::vector<int16_t> chunk(10000, 0);
        size_t written = 0;
        while (written < total) {
            std::fill(chunk.begin(), chunk.end(), int16_t(0));
            const size_t peakAt = total / 2 + 1000; // inside bucket 500
            if (peakAt >= written && peakAt < written + chunk.size())
                chunk[peakAt - written] = 16384;
            acc.append(chunk.data(), chunk.size());
            written += chunk.size();
        }
        QCOMPARE(acc.sampleCount(), total);
        const QVector<float> peaks = acc.finish();
        QCOMPARE(peaks.size(), 1000);
        QCOMPARE(peaks[500], 0.5f);
        QCOMPARE(peaks[499], 0.f);
        QCOMPARE(peaks[501], 0.f);
    }

    void accumulatorCap()
    {
        PeaksAccumulator acc(1000);
        std::vector<int16_t> chunk(600, 1);
        acc.append(chunk.data(), chunk.size());
        QVERIFY(!acc.exceeded());
        acc.append(chunk.data(), chunk.size());
        QVERIFY(acc.exceeded());
    }

    // ---- cache format -----------------------------------------------------------------

    void cacheFileRoundTripAndRejection()
    {
        QVector<float> peaks(kWaveformBuckets, 0.25f);
        const QByteArray file = encodeWaveformCache(peaks, 1.5f);
        QCOMPARE(file.size(), 5 + 4000 + 4);
        QCOMPARE(file.left(4), QByteArray("VRWF"));
        QCOMPARE(uint8_t(file[4]), uint8_t(2));
        const WaveformCache decoded = decodeWaveformCache(file);
        QCOMPARE(decoded.peaks, peaks);
        QCOMPARE(decoded.gainDb, 1.5f);

        QByteArray badMagic = file;
        badMagic[0] = 'X';
        QVERIFY(decodeWaveformCache(badMagic).isEmpty());

        QByteArray otherVersion = file;
        otherVersion[4] = char(file[4] + 1);
        QVERIFY(decodeWaveformCache(otherVersion).isEmpty());

        QVERIFY(decodeWaveformCache(file.left(file.size() - 4)).isEmpty());
        QVERIFY(decodeWaveformCache(file.left(file.size() - 1)).isEmpty());
        QVERIFY(decodeWaveformCache(file + QByteArray(4, 0)).isEmpty());
        QVERIFY(decodeWaveformCache(file.left(3)).isEmpty());
        QVERIFY(decodeWaveformCache(QByteArray()).isEmpty());
        // a file of the right size without the header (the raw payload of a plain encodePeaks)
        QVERIFY(decodeWaveformCache(encodePeaks(peaks) + QByteArray(5 + 4, 0)).isEmpty());
    }

    void cacheFileVersion1IsStale()
    {
        // what the previous build wrote: "VRWF", 1, the peaks and nothing else
        const QVector<float> peaks(kWaveformBuckets, 0.25f);
        QByteArray v1("VRWF\x01", 5);
        v1.append(encodePeaks(peaks));
        QCOMPARE(v1.size(), 4005);
        QVERIFY(decodeWaveformCache(v1).isEmpty());
        QVERIFY(!isWaveformFailedMarker(v1));
        // the old failure marker is stale too: the file is analysed again
        QVERIFY(!isWaveformFailedMarker(QByteArray("VRWF\x01", 5)));
        // the same bytes with the version of this build and the gain appended are a cache file
        QByteArray v2 = v1;
        v2[4] = char(2);
        v2.append(QByteArray(4, 0));
        QCOMPARE(decodeWaveformCache(v2).peaks, peaks);
        QCOMPARE(decodeWaveformCache(v2).gainDb, 0.f);
    }

    void cacheFileKeepsTheGain()
    {
        const QVector<float> peaks(kWaveformBuckets, 0.5f);
        for (float gain : {-12.f, -3.25f, 0.f, 2.5f, 4.f}) {
            const WaveformCache decoded = decodeWaveformCache(encodeWaveformCache(peaks, gain));
            QCOMPARE(decoded.peaks, peaks);
            QCOMPARE(decoded.gainDb, gain);
        }
    }

    void cacheFileRejectsAGainOutOfRange()
    {
        const QVector<float> peaks(kWaveformBuckets, 0.5f);
        const float bad[] = {std::numeric_limits<float>::quiet_NaN(), std::numeric_limits<float>::infinity(),
                             4.5f, -12.5f, 100.f};
        for (float gain : bad)
            QVERIFY2(decodeWaveformCache(encodeWaveformCache(peaks, gain)).isEmpty(),
                     qPrintable(QString::number(gain)));
    }

    // ---- loudness ---------------------------------------------------------------------

    void rmsOfAFullScaleSine()
    {
        std::vector<int16_t> samples(8000);
        for (size_t i = 0; i < samples.size(); ++i)
            samples[i] = int16_t(std::lround(32767.0 * std::sin(2.0 * 3.14159265358979323846 * 100.0 * i / 8000.0)));
        QVERIFY(std::abs(rmsDbfs(samples.data(), samples.size()) - (-3.01f)) < 0.05f);
    }

    void rmsOfAHalfScaleSine()
    {
        std::vector<int16_t> samples(8000);
        for (size_t i = 0; i < samples.size(); ++i)
            samples[i] = int16_t(std::lround(16384.0 * std::sin(2.0 * 3.14159265358979323846 * 100.0 * i / 8000.0)));
        QVERIFY(std::abs(rmsDbfs(samples.data(), samples.size()) - (-9.03f)) < 0.05f);
    }

    void rmsOfAFullScaleSquare()
    {
        std::vector<int16_t> samples(1000, 32767);
        for (size_t i = 0; i < samples.size(); i += 2)
            samples[i] = -32768;
        QVERIFY(std::abs(rmsDbfs(samples.data(), samples.size())) < 0.01f); // 0 dBFS
    }

    void rmsOfSilenceIsTheFloor()
    {
        std::vector<int16_t> samples(5000, 0);
        QVERIFY(rmsDbfs(samples.data(), samples.size()) <= -90.f);
        QVERIFY(std::isfinite(rmsDbfs(samples.data(), samples.size())));
        QCOMPARE(rmsDbfs(samples.data(), samples.size()), kRmsFloorDbfs);
        QVERIFY(rmsDbfs(nullptr, 0) <= -90.f);
        QVERIFY(rmsDbfs(samples.data(), 0) <= -90.f);
        // a single least-significant bit is very low but above the floor
        std::vector<int16_t> ones(5000, 1);
        QVERIFY(rmsDbfs(ones.data(), ones.size()) < -90.f);
        QVERIFY(rmsDbfs(ones.data(), ones.size()) > kRmsFloorDbfs);
    }

    void measuredGainFormula()
    {
        QCOMPARE(measuredGainDb(-30.f), 4.f);   // 12 dB wanted, limited to +4
        QCOMPARE(measuredGainDb(-18.f), 0.f);
        QCOMPARE(measuredGainDb(-3.f), -12.f);  // -15 dB wanted, limited to -12
        QCOMPARE(measuredGainDb(-22.f), 4.f);
        QCOMPARE(measuredGainDb(-21.f), 3.f);
        QCOMPARE(measuredGainDb(-12.f), -6.f);
        QCOMPARE(measuredGainDb(-6.f), -12.f);
        QCOMPARE(measuredGainDb(kRmsFloorDbfs), 4.f);
    }

    void accumulatorMeasuresTheLevelInOnePass()
    {
        // the same samples appended in pieces give the level of a single rmsDbfs() call
        std::vector<int16_t> samples(20000);
        for (size_t i = 0; i < samples.size(); ++i)
            samples[i] = int16_t(std::lround(8000.0 * std::sin(0.05 * double(i))));
        PeaksAccumulator acc;
        for (size_t at = 0; at < samples.size(); at += 3000)
            acc.append(samples.data() + at, std::min<size_t>(3000, samples.size() - at));
        QVERIFY(std::abs(acc.levelDbfs() - rmsDbfs(samples.data(), samples.size())) < 0.001f);
        QCOMPARE(acc.gainDb(), measuredGainDb(acc.levelDbfs()));
        // far more samples than the blocks of the peaks hold: the level does not depend on the folds
        PeaksAccumulator quiet;
        std::vector<int16_t> chunk(10000, 100);
        for (int i = 0; i < 300; ++i)
            quiet.append(chunk.data(), chunk.size());
        QVERIFY(std::abs(quiet.levelDbfs() - rmsDbfs(chunk.data(), chunk.size())) < 0.001f);
        PeaksAccumulator nothing;
        QCOMPARE(nothing.levelDbfs(), kRmsFloorDbfs);
        QCOMPARE(nothing.gainDb(), kMeasuredGainMaxDb);
    }

    void cacheFileRejectsValuesOutsideZeroToOne()
    {
        const float bad[] = {std::numeric_limits<float>::quiet_NaN(), std::numeric_limits<float>::infinity(),
                             1.5f, -0.1f};
        for (float value : bad) {
            QVector<float> peaks(kWaveformBuckets, 0.25f);
            peaks[17] = value;
            QVERIFY2(decodeWaveformCache(encodeWaveformCache(peaks, 0.f)).isEmpty(), qPrintable(QString::number(value)));
        }
        QVector<float> edges(kWaveformBuckets, 0.f);
        edges[0] = 1.f;
        QCOMPARE(decodeWaveformCache(encodeWaveformCache(edges, 0.f)).peaks, edges);
    }

    void failedMarkerIsNotAPeaksFile()
    {
        const QByteArray marker = encodeWaveformFailed();
        QCOMPARE(marker, QByteArray("VRWF\x02", 5));
        QVERIFY(isWaveformFailedMarker(marker));
        QVERIFY(decodeWaveformCache(marker).isEmpty());
        QVERIFY(!isWaveformFailedMarker(encodeWaveformCache(QVector<float>(kWaveformBuckets, 0.f), 0.f)));
        QVERIFY(!isWaveformFailedMarker(QByteArray()));
    }

    void cacheFileNameIsSha1OfUrl()
    {
        const QUrl url("file:///music/a.mp3");
        const QString path = waveformCacheFile("/c", url);
        QVERIFY(path.startsWith("/c/"));
        QVERIFY(path.endsWith(".bin"));
        QCOMPARE(path.size(), int(QString("/c/").size() + 40 + 4));
        QVERIFY(path != waveformCacheFile("/c", QUrl("file:///music/b.mp3")));
        QCOMPARE(path, waveformCacheFile("/c", url));
    }

    // ---- provider ---------------------------------------------------------------------

    void streamUrlNeverReady()
    {
        auto state = makeState();
        WaveformProvider provider(makeEnv(m_cache, state));
        QSignalSpy changed(&provider, &WaveformProvider::peaksChanged);
        QSignalSpy failedSpy(&provider, &WaveformProvider::failedChanged);
        provider.setUrl(QUrl("https://x/a.mp3"));
        QTest::qWait(200);
        QVERIFY(!provider.ready());
        QVERIFY(!provider.failed()); // nothing is analysed, so nothing failed
        QVERIFY(provider.peaks().isEmpty());
        QCOMPARE(changed.count(), 0);
        QCOMPARE(failedSpy.count(), 0);
        QCOMPARE(state->decodes.load(), 0);
        QVERIFY(!QDir(m_cache).exists()); // nothing written either
    }

    void otherNonFileUrlsNeverReady()
    {
        auto state = makeState();
        WaveformProvider provider(makeEnv(m_cache, state));
        for (const char* u : {"smb://host/share/a.mp3", "dvd:///dev/sr0", "http://x/a.wav", "relative/a.mp3", ""}) {
            provider.setUrl(QUrl(QString::fromLatin1(u)));
            QTest::qWait(30);
            QVERIFY2(!provider.ready(), u);
            QVERIFY2(!provider.failed(), u);
        }
        QCOMPARE(state->decodes.load(), 0);
    }

    void fileUrlBecomesReady()
    {
        auto state = makeState();
        const QUrl url = makeFile("song.mp3");
        WaveformProvider provider(makeEnv(m_cache, state));
        QSignalSpy changed(&provider, &WaveformProvider::peaksChanged);
        provider.setUrl(url);
        QVERIFY(!provider.ready()); // the GUI thread does not decode
        QVERIFY(!provider.failed()); // analysing
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 5000);
        QVERIFY(!provider.failed());
        QCOMPARE(changed.count(), 1);

        const QVariantList peaks = provider.peaks();
        QCOMPARE(peaks.size(), kWaveformBuckets);
        QCOMPARE(peaks[250].toFloat(), 0.5f);
        QCOMPARE(peaks[249].toFloat(), 0.f);
        for (const QVariant& v : peaks) {
            QVERIFY(v.toDouble() >= 0.0);
            QVERIFY(v.toDouble() <= 1.0);
        }
        QCOMPARE(state->decodes.load(), 1);
        QVERIFY(QFile::exists(waveformCacheFile(m_cache, url)));
    }

    void cacheRoundTripSkipsDecoding()
    {
        const QUrl url = makeFile("song.mp3");
        {
            auto state = makeState();
            WaveformProvider first(makeEnv(m_cache, state));
            first.setUrl(url);
            QTRY_VERIFY_WITH_TIMEOUT(first.ready(), 5000);
            QCOMPARE(state->decodes.load(), 1);
        }

        auto state = makeState();
        WaveformProvider second(makeEnv(m_cache, state));
        second.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(second.ready(), 5000);
        QCOMPARE(state->decodes.load(), 0);
        QCOMPARE(second.peaks().size(), kWaveformBuckets);
        QCOMPARE(second.peaks()[250].toFloat(), 0.5f);
    }

    void corruptCacheIsDecodedAgain()
    {
        const QUrl url = makeFile("song.mp3");
        QVERIFY(QDir().mkpath(m_cache));
        const QString cacheFile = waveformCacheFile(m_cache, url);
        {
            QFile f(cacheFile);
            QVERIFY(f.open(QIODevice::WriteOnly));
            f.write(QByteArray(4005, 'z')); // right size, wrong header
        }

        auto state = makeState();
        WaveformProvider provider(makeEnv(m_cache, state));
        provider.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 5000);
        QCOMPARE(state->decodes.load(), 1);

        // the broken file was replaced by a valid one
        QFile f(cacheFile);
        QVERIFY(f.open(QIODevice::ReadOnly));
        QCOMPARE(decodeWaveformCache(f.readAll()).peaks.size(), kWaveformBuckets);
    }

    void cacheOlderThanSourceIsDecodedAgain()
    {
        const QUrl url = makeFile("song.mp3");
        {
            auto state = makeState();
            WaveformProvider first(makeEnv(m_cache, state));
            first.setUrl(url);
            QTRY_VERIFY_WITH_TIMEOUT(first.ready(), 5000);
        }
        touchSource(url, 60);

        auto state = makeState();
        WaveformProvider second(makeEnv(m_cache, state));
        second.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(second.ready(), 5000);
        QCOMPARE(state->decodes.load(), 1);
    }

    // ---- loudness through the provider and the cache ------------------------------------

    void providerReportsTheMeasuredGainAndPeak()
    {
        auto state = makeLoudState();
        const QUrl url = makeFile("song.mp3");
        WaveformProvider provider(makeEnv(m_cache, state));
        QCOMPARE(provider.gainDb(), 0.0);
        QCOMPARE(provider.peak(), 0.0);
        provider.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 5000);
        // +-3277 is -20 dBFS RMS: 2 dB to the target
        QVERIFY2(std::abs(provider.gainDb() - 2.0) < 0.01, qPrintable(QString::number(provider.gainDb())));
        QVERIFY2(std::abs(provider.peak() - 3277.0 / 32768.0) < 1e-6, qPrintable(QString::number(provider.peak())));

        // a new url forgets them
        provider.setUrl(QUrl("http://example.com/a.mp3"));
        QVERIFY(!provider.ready());
        QCOMPARE(provider.gainDb(), 0.0);
        QCOMPARE(provider.peak(), 0.0);
    }

    void gainSurvivesTheCacheWithoutDecoding()
    {
        const QUrl url = makeFile("song.mp3");
        {
            auto state = makeLoudState();
            WaveformProvider first(makeEnv(m_cache, state));
            first.setUrl(url);
            QTRY_VERIFY_WITH_TIMEOUT(first.ready(), 5000);
            QCOMPARE(state->decodes.load(), 1);
        }
        auto state = makeLoudState();
        WaveformProvider second(makeEnv(m_cache, state));
        second.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(second.ready(), 5000);
        QCOMPARE(state->decodes.load(), 0);
        QVERIFY2(std::abs(second.gainDb() - 2.0) < 0.01, qPrintable(QString::number(second.gainDb())));
        QVERIFY(std::abs(second.peak() - 3277.0 / 32768.0) < 1e-6);
    }

    void cacheOfVersion1IsDecodedAgainAndReplaced()
    {
        const QUrl url = makeFile("song.mp3");
        QVERIFY(QDir().mkpath(m_cache));
        const QString cacheFile = waveformCacheFile(m_cache, url);
        {
            // a valid file of the previous build, written after the source
            QByteArray v1("VRWF\x01", 5);
            v1.append(encodePeaks(QVector<float>(kWaveformBuckets, 0.25f)));
            QFile f(cacheFile);
            QVERIFY(f.open(QIODevice::WriteOnly));
            f.write(v1);
        }

        auto state = makeLoudState();
        WaveformProvider provider(makeEnv(m_cache, state));
        provider.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 5000);
        QCOMPARE(state->decodes.load(), 1); // the old file was not used
        QVERIFY(std::abs(provider.peak() - 3277.0 / 32768.0) < 1e-6);

        QFile f(cacheFile);
        QVERIFY(f.open(QIODevice::ReadOnly));
        const WaveformCache stored = decodeWaveformCache(f.readAll());
        QCOMPARE(stored.peaks.size(), kWaveformBuckets);
        QVERIFY(std::abs(stored.gainDb - 2.0f) < 0.01f);
    }

    void failureMarkerOfVersion1IsDecodedAgain()
    {
        auto state = makeLoudState();
        const QUrl url = makeFile("song.mp3");
        QVERIFY(QDir().mkpath(m_cache));
        {
            QFile f(waveformCacheFile(m_cache, url));
            QVERIFY(f.open(QIODevice::WriteOnly));
            f.write(QByteArray("VRWF\x01", 5)); // the marker of the previous build
        }
        WaveformProvider provider(makeEnv(m_cache, state));
        provider.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 5000);
        QCOMPARE(state->decodes.load(), 1);
    }

    // ---- the queue of the process survives the end of the application object -------------------

    void queueWorksAgainAfterShutdown()
    {
        const QUrl url = makeFile("song.mp3");
        auto state = makeLoudState();
        auto old = std::make_unique<WaveformProvider>(makeEnv(m_cache, state));
        old->setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(old->ready(), 5000);

        // what the end of an application does: the queue is gone, a provider of the old interface
        // that is still alive must not touch it any more
        WaveformProvider::shutdown();
        QCOMPARE(WaveformProvider::activeJobs(), 0);

        const QUrl url2 = makeFile("other.mp3");
        auto state2 = makeLoudState();
        WaveformProvider fresh(makeEnv(m_cache, state2));
        fresh.setUrl(url2);
        QTRY_VERIFY_WITH_TIMEOUT(fresh.ready(), 5000);
        QCOMPARE(state2->decodes.load(), 1);

        old->setUrl(QUrl()); // unsubscribes from the queue that no longer knows it
        old.reset();
    }

    void shutdownCancelsTheRunningJobAndWaitsForIt()
    {
        auto state = makeLoudState();
        state->hold = true; // the decode blocks until it is cancelled
        const QUrl url = makeFile("song.mp3");
        WaveformProvider provider(makeEnv(m_cache, state));
        provider.setUrl(url);
        QTRY_COMPARE_WITH_TIMEOUT(state->running.load(), 1, 5000);

        WaveformProvider::shutdown();
        // the join is part of it: the decode is over when it returns
        QCOMPARE(state->running.load(), 0);
        QCOMPARE(state->cancelled.load(), 1);
        QCOMPARE(WaveformProvider::activeJobs(), 0);
        QVERIFY(!provider.ready());
    }

    // ---- failures are remembered ------------------------------------------------------

    void failedDecodeIsRememberedAndNotDecodedAgain()
    {
        auto state = makeState();
        state->fail = true;
        const QUrl url = makeFile("song.mp3");
        {
            WaveformProvider provider(makeEnv(m_cache, state));
            QSignalSpy failedSpy(&provider, &WaveformProvider::failedChanged);
            provider.setUrl(url);
            QVERIFY(!provider.failed());
            QTRY_VERIFY_WITH_TIMEOUT(provider.failed(), 5000);
            QVERIFY(!provider.ready());
            QCOMPARE(failedSpy.count(), 1);
            QCOMPARE(state->decodes.load(), 1);
        }
        QFile f(waveformCacheFile(m_cache, url));
        QVERIFY(f.open(QIODevice::ReadOnly));
        QVERIFY(isWaveformFailedMarker(f.readAll()));
        f.close();

        // the next play does not decode again, even when the decoder would work now
        state->fail = false;
        WaveformProvider again(makeEnv(m_cache, state));
        again.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(again.failed(), 5000);
        QVERIFY(!again.ready());
        QCOMPARE(state->decodes.load(), 1);
    }

    void failedMarkerIsIgnoredWhenTheSourceChanged()
    {
        auto state = makeState();
        state->fail = true;
        const QUrl url = makeFile("song.mp3");
        {
            WaveformProvider provider(makeEnv(m_cache, state));
            provider.setUrl(url);
            QTRY_VERIFY_WITH_TIMEOUT(provider.failed(), 5000);
        }
        touchSource(url, 60); // replaced after the marker was written
        state->fail = false;
        WaveformProvider again(makeEnv(m_cache, state));
        again.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(again.ready(), 5000);
        QCOMPARE(state->decodes.load(), 2);
    }

    void failedMarkerExpiresAfterAWeek()
    {
        auto state = makeState();
        state->fail = true;
        const QUrl url = makeFile("song.mp3");
        {
            WaveformProvider provider(makeEnv(m_cache, state));
            provider.setUrl(url);
            QTRY_VERIFY_WITH_TIMEOUT(provider.failed(), 5000);
        }
        // the source is older than the marker, but the marker is older than a week
        touchSource(url, -9 * 24 * 3600);
        QFile marker(waveformCacheFile(m_cache, url));
        QVERIFY(marker.open(QIODevice::Append));
        QVERIFY(marker.setFileTime(QDateTime::currentDateTime().addDays(-8), QFileDevice::FileModificationTime));
        marker.close();

        state->fail = false;
        WaveformProvider again(makeEnv(m_cache, state));
        again.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(again.ready(), 5000);
        QCOMPARE(state->decodes.load(), 2);
    }

    void interruptedDecodeIsNotRemembered()
    {
        auto state = makeState();
        state->interrupt = true; // a stalled input: transient
        const QUrl url = makeFile("song.mp3");
        {
            WaveformProvider provider(makeEnv(m_cache, state));
            provider.setUrl(url);
            QTRY_VERIFY_WITH_TIMEOUT(provider.failed(), 5000);
        }
        QVERIFY(!QFile::exists(waveformCacheFile(m_cache, url)));

        state->interrupt = false;
        WaveformProvider again(makeEnv(m_cache, state));
        again.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(again.ready(), 5000);
        QCOMPARE(state->decodes.load(), 2);
    }

    void emptyDecodeFailsAndIsRemembered()
    {
        auto state = makeState();
        state->samples.clear(); // no audio stream
        const QUrl url = makeFile("clip.mp4");
        {
            WaveformProvider provider(makeEnv(m_cache, state));
            provider.setUrl(url);
            QTRY_VERIFY_WITH_TIMEOUT(provider.failed(), 5000);
            QVERIFY(!provider.ready());
        }
        QFile f(waveformCacheFile(m_cache, url));
        QVERIFY(f.open(QIODevice::ReadOnly));
        QVERIFY(isWaveformFailedMarker(f.readAll()));
    }

    void missingFileFailsWithoutDecoding()
    {
        auto state = makeState();
        WaveformProvider provider(makeEnv(m_cache, state));
        provider.setUrl(QUrl::fromLocalFile(m_dir->filePath("nope.mp3")));
        QTRY_VERIFY_WITH_TIMEOUT(provider.failed(), 5000);
        QVERIFY(!provider.ready());
        QCOMPARE(state->decodes.load(), 0);
    }

    void tooLargeFileFailsWithoutDecoding()
    {
        auto state = makeState();
        const QUrl url = makeFile("big.mp3", 5000);
        WaveformEnvironment env = makeEnv(m_cache, state);
        env.maxFileBytes = 4096;
        WaveformProvider provider(env);
        provider.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(provider.failed(), 5000);
        QVERIFY(!provider.ready());
        QCOMPARE(state->decodes.load(), 0);

        // the default cap is 1 GiB
        QCOMPARE(WaveformEnvironment().maxFileBytes, qint64(1) << 30);
    }

    // ---- cancellation and sharing ----------------------------------------------------------

    void newUrlCancelsRunningJob()
    {
        auto state = makeState();
        state->hold = true;
        const QUrl first = makeFile("one.mp3");
        const QUrl second = makeFile("two.mp3");
        WaveformProvider provider(makeEnv(m_cache, state));
        provider.setUrl(first);
        QTRY_COMPARE_WITH_TIMEOUT(state->running.load(), 1, 5000);

        provider.setUrl(second); // cancels `first`, `second` waits for it
        QTRY_COMPARE_WITH_TIMEOUT(state->cancelled.load(), 1, 5000);
        QTRY_COMPARE_WITH_TIMEOUT(state->decodes.load(), 2, 5000);
        state->hold = false;
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 5000);

        QCOMPARE(provider.url(), second);
        QVERIFY(!provider.failed()); // the cancelled job did not report a failure
        QCOMPARE(state->maxRunning.load(), 1); // never two jobs at once
        QVERIFY(!QFile::exists(waveformCacheFile(m_cache, first)));
        QVERIFY(QFile::exists(waveformCacheFile(m_cache, second)));
    }

    void changingUrlDropsOldPeaksAndFailure()
    {
        auto state = makeState();
        const QUrl url = makeFile("song.mp3");
        WaveformProvider provider(makeEnv(m_cache, state));
        provider.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 5000);

        QSignalSpy changed(&provider, &WaveformProvider::peaksChanged);
        provider.setUrl(QUrl("https://x/a.mp3"));
        QVERIFY(!provider.ready());
        QVERIFY(provider.peaks().isEmpty());
        QCOMPARE(changed.count(), 1);

        provider.setUrl(QUrl::fromLocalFile(m_dir->filePath("nope.mp3")));
        QTRY_VERIFY_WITH_TIMEOUT(provider.failed(), 5000);
        QSignalSpy failedSpy(&provider, &WaveformProvider::failedChanged);
        provider.setUrl(url);
        QVERIFY(!provider.failed());
        QCOMPARE(failedSpy.count(), 1);
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 5000);
    }

    void destroyingTheProviderCancelsTheJobWithoutWaiting()
    {
        auto state = makeState();
        state->hold = true;
        {
            WaveformProvider provider(makeEnv(m_cache, state));
            provider.setUrl(makeFile("song.mp3"));
            QTRY_COMPARE_WITH_TIMEOUT(state->running.load(), 1, 5000);
        }
        QTRY_COMPARE_WITH_TIMEOUT(state->running.load(), 0, 5000);
        QCOMPARE(state->cancelled.load(), 1);
        QTRY_COMPARE_WITH_TIMEOUT(WaveformProvider::activeJobs(), 0, 5000);
    }

    void twoProvidersOnOneUrlShareOneDecode()
    {
        auto state = makeState();
        state->hold = true;
        const QUrl url = makeFile("song.mp3");
        WaveformProvider a(makeEnv(m_cache, state));
        WaveformProvider b(makeEnv(m_cache, state));
        a.setUrl(url);
        QTRY_COMPARE_WITH_TIMEOUT(state->running.load(), 1, 5000);
        b.setUrl(url); // joins the running job
        QCOMPARE(WaveformProvider::activeJobs(), 1);

        // one leaving does not cancel the job of the other
        a.setUrl(QUrl());
        QTest::qWait(50);
        QCOMPARE(state->cancelled.load(), 0);
        a.setUrl(url);
        state->hold = false;
        QTRY_VERIFY_WITH_TIMEOUT(a.ready() && b.ready(), 5000);
        QCOMPARE(state->decodes.load(), 1);
        QCOMPARE(a.peaks(), b.peaks());
    }

    void onlyOneJobRunsAtATimeAndTheNewestPendingStartsFirst()
    {
        auto state = makeState();
        state->hold = true;
        const QUrl u1 = makeFile("one.mp3");
        const QUrl u2 = makeFile("two.mp3");
        const QUrl u3 = makeFile("three.mp3");
        WaveformProvider p1(makeEnv(m_cache, state));
        WaveformProvider p2(makeEnv(m_cache, state));
        WaveformProvider p3(makeEnv(m_cache, state));
        p1.setUrl(u1);
        QTRY_COMPARE_WITH_TIMEOUT(state->running.load(), 1, 5000);
        p2.setUrl(u2);
        p3.setUrl(u3);
        QCOMPARE(WaveformProvider::activeJobs(), 3);
        QTest::qWait(50);
        QCOMPARE(state->decodes.load(), 1);

        state->hold = false;
        QTRY_VERIFY_WITH_TIMEOUT(p1.ready() && p2.ready() && p3.ready(), 10000);
        QCOMPARE(state->maxRunning.load(), 1);
        QCOMPARE(state->order, (QStringList{u1.toLocalFile(), u3.toLocalFile(), u2.toLocalFile()}));
    }

    // ---- the real decoder (libvlccore: transcode + smem, no temp file, no output device) --------

    void holderIsolatesThePlayer()
    {
        VlcInstance vlc;
        QVERIFY(vlc.ok());
        // the default asks the user whether to resume; the holder must say never
        QVERIFY(var_InheritInteger(vlc.object(), "restore-playback-pos") != VLC_PLAYER_RESTORE_PLAYBACK_POS_NEVER);

        vlc_object_t* holder = createWaveformHolder(vlc.object());
        QVERIFY(holder);
        // the input and the player look the variables up from below the holder
        vlc_object_t* child = static_cast<vlc_object_t*>(vlc_object_create(holder, sizeof(vlc_object_t)));
        QVERIFY(child);
        QCOMPARE(var_InheritInteger(child, "restore-playback-pos"), qint64(VLC_PLAYER_RESTORE_PLAYBACK_POS_NEVER));
        QVERIFY(!var_InheritBool(child, "restore-playback-states"));
        char* aout = var_InheritString(child, "aout");
        QCOMPARE(QString::fromUtf8(aout), QString("dummy"));
        free(aout);
        char* vout = var_InheritString(child, "vout");
        QCOMPARE(QString::fromUtf8(vout), QString("dummy"));
        free(vout);
        vlc_object_delete(child);
        vlc_object_delete(holder);
    }

    void decodesAWavEndToEnd()
    {
        VlcInstance vlc;
        QVERIFY(vlc.ok());
        IdleGuard idle;

        // 2 s of silence, then 2 s of a 0.5 amplitude sine; 44.1 kHz stereo
        const QUrl url = makeFile("tone.wav", makeWav(44100, 2, 2.0, 2.0, 0.5));

        auto probe = std::make_shared<ProbeState>();
        WaveformProvider provider(realEnv(vlc, probe));
        provider.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 30000);

        const QVariantList peaks = provider.peaks();
        QCOMPARE(peaks.size(), kWaveformBuckets);
        // silence in the first half (the edge bucket may hold the first period of the tone)
        for (int i = 0; i < 480; ++i)
            QVERIFY2(peaks[i].toDouble() < 0.02, qPrintable(QString::number(i)));
        // the tone in the second half, resampled to 8 kHz and mixed to mono: about its amplitude
        double maxPeak = 0;
        for (int i = 520; i < 1000; ++i) {
            const double p = peaks[i].toDouble();
            QVERIFY2(p > 0.3 && p < 0.7, qPrintable(QString("%1: %2").arg(i).arg(p)));
            maxPeak = std::max(maxPeak, p);
        }
        QVERIFY(maxPeak > 0.45);
        QVERIFY(QFile::exists(waveformCacheFile(m_cache, url)));

        // no temp file is left next to the source or in the cache directory
        for (const QString& name : QDir(m_cache).entryList(QDir::Files))
            QVERIFY2(name.endsWith(".bin"), qPrintable(name));
    }

    void decodesFasterThanRealTime()
    {
        VlcInstance vlc;
        QVERIFY(vlc.ok());
        IdleGuard idle;

        // the first decode of a process loads the plugins: warm up with a short file
        warmUp(vlc);

        // 2 minutes of 44.1 kHz stereo
        const QUrl url = makeFile("two-minutes.wav", makeWav(44100, 2, 0.0, 120.0, 0.5));
        WaveformProvider provider(realEnv(vlc, std::make_shared<ProbeState>()));
        QElapsedTimer timer;
        timer.start();
        provider.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 30000);
        qInfo() << "decoded 120 s of stereo 44.1 kHz audio in" << timer.elapsed() << "ms";
        QVERIFY2(timer.elapsed() < 10000, qPrintable(QString::number(timer.elapsed())));
    }

    void realDecoderStopsWhenTheUrlChanges()
    {
        VlcInstance vlc;
        QVERIFY(vlc.ok());
        IdleGuard idle;
        warmUp(vlc);

        // 10 minutes (4.8 M samples at 8 kHz) and 1 s
        const QUrl longUrl = makeFile("long.wav", makeWav(8000, 1, 0.0, 600.0, 0.5));
        const QUrl shortUrl = makeFile("short.wav", makeWav(8000, 1, 0.0, 1.0, 0.25));

        auto probe = std::make_shared<ProbeState>();
        probe->holdNext = true; // the first decode freezes at its first chunk until it is cancelled
        WaveformProvider provider(realEnv(vlc, probe));
        provider.setUrl(longUrl);
        QTRY_VERIFY_WITH_TIMEOUT(probe->reached.load() > 0, 30000); // samples flow, the input is busy

        QElapsedTimer timer;
        timer.start();
        provider.setUrl(shortUrl);
        // the short file can only be decoded after the frozen one was really stopped
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 20000);
        QVERIFY2(timer.elapsed() < 10000, qPrintable(QString::number(timer.elapsed())));
        QCOMPARE(provider.url(), shortUrl);
        const QVariantList peaks = provider.peaks();
        QVERIFY(peaks[500].toDouble() > 0.15 && peaks[500].toDouble() < 0.35);

        QCOMPARE(probe->ended.load(), 2);
        {
            std::lock_guard<std::mutex> lock(probe->mutex);
            qInfo() << "cancelled decode of the 10 min file got" << probe->finals[0] << "of 4.8 M samples";
            QVERIFY2(probe->finals[0] < 100000, qPrintable(QString::number(probe->finals[0]))); // not 4.8 M
            QCOMPARE(probe->results[0], int(DecodeResult::Interrupted));
        }
        QVERIFY(!QFile::exists(waveformCacheFile(m_cache, longUrl)));
        QVERIFY(QFile::exists(waveformCacheFile(m_cache, shortUrl)));
    }

    void realDecoderStopsWhenTheProviderIsDestroyed()
    {
        VlcInstance vlc;
        QVERIFY(vlc.ok());
        IdleGuard idle;
        warmUp(vlc);

        const QUrl longUrl = makeFile("long.wav", makeWav(8000, 1, 0.0, 600.0, 0.5));
        auto probe = std::make_shared<ProbeState>();
        probe->holdNext = true;

        auto provider = std::make_unique<WaveformProvider>(realEnv(vlc, probe));
        provider->setUrl(longUrl);
        QTRY_VERIFY_WITH_TIMEOUT(probe->reached.load() > 0, 30000);

        QElapsedTimer timer;
        timer.start();
        provider.reset();
        QVERIFY2(timer.elapsed() < 1000, qPrintable(QString::number(timer.elapsed()))); // does not wait

        QTRY_COMPARE_WITH_TIMEOUT(probe->ended.load(), 1, 20000); // the decode really stopped
        {
            std::lock_guard<std::mutex> lock(probe->mutex);
            QVERIFY2(probe->finals[0] < 100000, qPrintable(QString::number(probe->finals[0])));
        }
        QTRY_COMPARE_WITH_TIMEOUT(WaveformProvider::activeJobs(), 0, 20000);
        QVERIFY(!QFile::exists(waveformCacheFile(m_cache, longUrl)));
    }

    void realDecoderFailsOnGarbageAndRemembersIt()
    {
        VlcInstance vlc;
        QVERIFY(vlc.ok());
        IdleGuard idle;
        const QUrl url = makeFile("garbage.mp3", 3000);

        auto probe = std::make_shared<ProbeState>();
        {
            WaveformProvider provider(realEnv(vlc, probe));
            provider.setUrl(url);
            QTRY_COMPARE_WITH_TIMEOUT(probe->ended.load(), 1, 30000);
            QTRY_VERIFY_WITH_TIMEOUT(provider.failed(), 5000);
            QVERIFY(!provider.ready());
        }
        QFile f(waveformCacheFile(m_cache, url));
        QVERIFY(f.open(QIODevice::ReadOnly));
        QVERIFY(isWaveformFailedMarker(f.readAll()));
        f.close();

        // not decoded again
        WaveformProvider again(realEnv(vlc, probe));
        again.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(again.failed(), 5000);
        QCOMPARE(probe->started.load(), 1);
    }

    void realDecoderRefusesTooLongFilesBeforeDecoding()
    {
        VlcInstance vlc;
        QVERIFY(vlc.ok());
        IdleGuard idle;
        warmUp(vlc);

        // 2 h 10 min of 8-bit mono at 1 kHz: 7.8 MB, 62 M samples once resampled to 8 kHz
        const QUrl url = makeFile("long.wav", makeWav(1000, 1, 0.0, 7800.0, 0.5, 8));
        auto probe = std::make_shared<ProbeState>();
        WaveformProvider provider(realEnv(vlc, probe));
        provider.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(provider.failed(), 60000);
        QVERIFY(!provider.ready());
        {
            std::lock_guard<std::mutex> lock(probe->mutex);
            QCOMPARE(probe->results[0], int(DecodeResult::Failed));
            qInfo() << "too long file: samples decoded before the refusal" << probe->finals[0];
            // refused from the reported length, long before the 57.6 M samples of the sample cap
            QVERIFY2(probe->finals[0] < 5000000, qPrintable(QString::number(probe->finals[0])));
        }
        QFile f(waveformCacheFile(m_cache, url));
        QVERIFY(f.open(QIODevice::ReadOnly));
        QVERIFY(isWaveformFailedMarker(f.readAll()));
    }

private:
    //! a libvlc instance on a throwaway profile; its libvlccore object is the parent of the decoder
    class VlcInstance
    {
    public:
        VlcInstance()
        {
            setenv("VLC_PLUGIN_PATH", TOP_BUILDDIR"/modules", 0);
            setenv("VLC_LIB_PATH", TOP_BUILDDIR"/modules", 0);
            m_config = m_dir.filePath("vlcrc").toUtf8();
            const QByteArray configArg = "--config=" + m_config;
            const char* argv[] = {"--ignore-config", configArg.constData(), "--no-media-library"};
            m_vlc = libvlc_new(3, argv);
        }
        ~VlcInstance()
        {
            if (m_vlc)
                libvlc_release(m_vlc);
        }
        bool ok() const { return m_vlc != nullptr; }
        vlc_object_t* object() const { return VLC_OBJECT(m_vlc->p_libvlc_int); }

    private:
        QTemporaryDir m_dir;
        QByteArray m_config;
        libvlc_instance_t* m_vlc = nullptr;
    };

    WaveformEnvironment realEnv(const VlcInstance& vlc, const std::shared_ptr<ProbeState>& probe)
    {
        WaveformEnvironment env;
        env.cacheDir = m_cache;
        env.makeDecoder = [obj = vlc.object(), probe] { return std::make_unique<ProbeDecoder>(obj, probe); };
        return env;
    }

    //! one short decode, so that the plugins of the real decoder are loaded
    void warmUp(const VlcInstance& vlc)
    {
        WaveformEnvironment env;
        env.cacheDir = m_dir->filePath("warm-cache");
        env.makeDecoder = [obj = vlc.object()] { return makeVlcWaveformDecoder(obj); };
        WaveformProvider warm(env);
        warm.setUrl(makeFile("warm.wav", makeWav(8000, 1, 0.0, 1.0, 0.5)));
        QTRY_VERIFY_WITH_TIMEOUT(warm.ready(), 60000);
    }

    //! the source file gets a modification time `seconds` in the future
    void touchSource(const QUrl& url, int seconds)
    {
        QFile source(url.toLocalFile());
        QVERIFY(source.open(QIODevice::Append));
        QVERIFY(source.setFileTime(QDateTime::currentDateTime().addSecs(seconds),
                                   QFileDevice::FileModificationTime));
    }

    QUrl makeFile(const QString& name, int size = 64)
    {
        return makeFile(name, QByteArray(size, 'a'));
    }

    QUrl makeFile(const QString& name, const QByteArray& content)
    {
        const QString path = m_dir->filePath(name);
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly) || f.write(content) != content.size())
            qFatal("cannot write %s", qPrintable(path));
        return QUrl::fromLocalFile(path);
    }

    std::unique_ptr<QTemporaryDir> m_dir;
    QString m_cache;
};

QTEST_GUILESS_MAIN(TestWaveform)
#include "test_waveform.moc"
