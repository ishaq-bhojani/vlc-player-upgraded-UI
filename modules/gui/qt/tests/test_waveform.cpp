/*****************************************************************************
 * Copyright (C) 2026 VLC Reborn contributors
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
#include <memory>
#include <thread>
#include <vector>

#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include <vlc/vlc.h>
#include <vlc_common.h>

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
    std::atomic_bool hold{false}; //!< a decode blocks while this is set (or until it is cancelled)
    std::atomic_bool fail{false};
    std::vector<int16_t> samples;
};

class FakeDecoder : public WaveformDecoder
{
public:
    explicit FakeDecoder(std::shared_ptr<FakeState> state) : m_state(std::move(state)) {}

    bool decode(const QString&, PeaksAccumulator& acc, CancelToken& cancel) override
    {
        FakeState& s = *m_state;
        ++s.decodes;
        const int now = ++s.running;
        int prev = s.maxRunning;
        while (now > prev && !s.maxRunning.compare_exchange_weak(prev, now)) {}

        while (s.hold && !cancel.cancelled())
            std::this_thread::sleep_for(std::chrono::milliseconds(5));

        bool ok = false;
        if (cancel.cancelled())
            ++s.cancelled;
        else if (!s.fail) {
            acc.append(s.samples.data(), s.samples.size());
            ok = true;
        }
        --s.running;
        return ok;
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

WaveformEnvironment makeEnv(const QString& cacheDir, const std::shared_ptr<FakeState>& state)
{
    WaveformEnvironment env;
    env.cacheDir = cacheDir;
    env.makeDecoder = [state] { return std::make_unique<FakeDecoder>(state); };
    return env;
}

/** 16-bit PCM WAV: `silenceSec` of silence, then `toneSec` of a 440 Hz sine of the given amplitude. */
QByteArray makeWav(int rate, int channels, double silenceSec, double toneSec, double amplitude)
{
    const int frames = int((silenceSec + toneSec) * rate);
    const int silentFrames = int(silenceSec * rate);
    QByteArray pcm;
    pcm.resize(frames * channels * 2);
    auto* out = reinterpret_cast<int16_t*>(pcm.data());
    for (int i = 0; i < frames; ++i) {
        const double v = i < silentFrames ? 0.0 : amplitude * std::sin(2.0 * 3.14159265358979323846 * 440.0 * i / rate);
        for (int c = 0; c < channels; ++c)
            *out++ = int16_t(std::lround(v * 32767.0));
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

    void cleanup() { m_dir.reset(); }

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
        const QByteArray file = encodeWaveformCache(peaks);
        QCOMPARE(file.size(), 5 + 4000);
        QCOMPARE(file.left(4), QByteArray("VRWF"));
        QCOMPARE(decodeWaveformCache(file), peaks);

        QByteArray badMagic = file;
        badMagic[0] = 'X';
        QVERIFY(decodeWaveformCache(badMagic).isEmpty());

        QByteArray otherVersion = file;
        otherVersion[4] = char(file[4] + 1);
        QVERIFY(decodeWaveformCache(otherVersion).isEmpty());

        QVERIFY(decodeWaveformCache(file.left(file.size() - 4)).isEmpty());
        QVERIFY(decodeWaveformCache(file + QByteArray(4, 0)).isEmpty());
        QVERIFY(decodeWaveformCache(file.left(3)).isEmpty());
        QVERIFY(decodeWaveformCache(QByteArray()).isEmpty());
        // a file of the right size without the header (the raw payload of a plain encodePeaks)
        QVERIFY(decodeWaveformCache(encodePeaks(peaks) + QByteArray(5, 0)).isEmpty());
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
        provider.setUrl(QUrl("https://x/a.mp3"));
        QTest::qWait(200);
        QVERIFY(!provider.ready());
        QVERIFY(provider.peaks().isEmpty());
        QCOMPARE(changed.count(), 0);
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
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 5000);
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
        QCOMPARE(decodeWaveformCache(f.readAll()).size(), kWaveformBuckets);
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
        // the song was replaced after the cache was written
        QFile source(url.toLocalFile());
        QVERIFY(source.open(QIODevice::Append));
        QVERIFY(source.setFileTime(QDateTime::currentDateTime().addSecs(60),
                                   QFileDevice::FileModificationTime));
        source.close();

        auto state = makeState();
        WaveformProvider second(makeEnv(m_cache, state));
        second.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(second.ready(), 5000);
        QCOMPARE(state->decodes.load(), 1);
    }

    void failedDecodeStaysNotReadyAndWritesNoCache()
    {
        auto state = makeState();
        state->fail = true;
        const QUrl url = makeFile("song.mp3");
        WaveformProvider provider(makeEnv(m_cache, state));
        provider.setUrl(url);
        QTRY_COMPARE_WITH_TIMEOUT(state->decodes.load(), 1, 5000);
        QTest::qWait(100);
        QVERIFY(!provider.ready());
        QVERIFY(!QFile::exists(waveformCacheFile(m_cache, url)));
    }

    void emptyDecodeStaysNotReady()
    {
        auto state = makeState();
        state->samples.clear(); // no audio stream
        const QUrl url = makeFile("clip.mp4");
        WaveformProvider provider(makeEnv(m_cache, state));
        provider.setUrl(url);
        QTRY_COMPARE_WITH_TIMEOUT(state->decodes.load(), 1, 5000);
        QTest::qWait(100);
        QVERIFY(!provider.ready());
    }

    void missingFileNeverDecodes()
    {
        auto state = makeState();
        WaveformProvider provider(makeEnv(m_cache, state));
        provider.setUrl(QUrl::fromLocalFile(m_dir->filePath("nope.mp3")));
        QTest::qWait(150);
        QVERIFY(!provider.ready());
        QCOMPARE(state->decodes.load(), 0);
    }

    void tooLargeFileIsSkipped()
    {
        auto state = makeState();
        const QUrl url = makeFile("big.mp3", 5000);
        WaveformEnvironment env = makeEnv(m_cache, state);
        env.maxFileBytes = 4096;
        WaveformProvider provider(env);
        provider.setUrl(url);
        QTest::qWait(150);
        QVERIFY(!provider.ready());
        QCOMPARE(state->decodes.load(), 0);

        // the default cap is 1 GiB
        QCOMPARE(WaveformEnvironment().maxFileBytes, qint64(1) << 30);
    }

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
        QCOMPARE(state->maxRunning.load(), 1); // never two jobs at once
        QVERIFY(!QFile::exists(waveformCacheFile(m_cache, first)));
        QVERIFY(QFile::exists(waveformCacheFile(m_cache, second)));
    }

    void changingUrlDropsOldPeaks()
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
    }

    void destroyingTheProviderCancelsTheJob()
    {
        auto state = makeState();
        state->hold = true;
        {
            WaveformProvider provider(makeEnv(m_cache, state));
            provider.setUrl(makeFile("song.mp3"));
            QTRY_COMPARE_WITH_TIMEOUT(state->running.load(), 1, 5000);
        }
        QCOMPARE(state->running.load(), 0);
        QCOMPARE(state->cancelled.load(), 1);
    }

    // ---- the real decoder (libvlccore: transcode + smem, no temp file, no output device) --------

    void decodesAWavEndToEnd()
    {
        VlcInstance vlc;
        QVERIFY(vlc.ok());

        // 2 s of silence, then 2 s of a 0.5 amplitude sine; 44.1 kHz stereo
        const QUrl url = makeFile("tone.wav", makeWav(44100, 2, 2.0, 2.0, 0.5));

        WaveformEnvironment env;
        env.cacheDir = m_cache;
        env.makeDecoder = [obj = vlc.object()] { return makeVlcWaveformDecoder(obj); };
        WaveformProvider provider(env);

        QElapsedTimer timer;
        timer.start();
        provider.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 30000);
        qInfo() << "decoded 4 s of stereo 44.1 kHz audio in" << timer.elapsed() << "ms";
        // faster than real time by a wide margin (4 s of audio)
        QVERIFY2(timer.elapsed() < 3500, qPrintable(QString::number(timer.elapsed())));

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

        WaveformEnvironment env;
        env.cacheDir = m_cache;
        env.makeDecoder = [obj = vlc.object()] { return makeVlcWaveformDecoder(obj); };

        // the first decode of a process loads the plugins: warm up with a short file
        {
            WaveformProvider warm(env);
            warm.setUrl(makeFile("warm.wav", makeWav(8000, 1, 0.0, 1.0, 0.5)));
            QTRY_VERIFY_WITH_TIMEOUT(warm.ready(), 30000);
        }

        // 2 minutes of 44.1 kHz stereo
        const QUrl url = makeFile("two-minutes.wav", makeWav(44100, 2, 0.0, 120.0, 0.5));
        WaveformProvider provider(env);
        QElapsedTimer timer;
        timer.start();
        provider.setUrl(url);
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 30000);
        qInfo() << "decoded 120 s of stereo 44.1 kHz audio in" << timer.elapsed() << "ms";
        QVERIFY2(timer.elapsed() < 10000, qPrintable(QString::number(timer.elapsed())));
    }

    void realDecoderCancels()
    {
        VlcInstance vlc;
        QVERIFY(vlc.ok());

        // 10 minutes of tone: long enough to still run when the url changes
        const QUrl longUrl = makeFile("long.wav", makeWav(44100, 2, 0.0, 600.0, 0.5));
        const QUrl shortUrl = makeFile("short.wav", makeWav(44100, 1, 0.0, 1.0, 0.25));

        WaveformEnvironment env;
        env.cacheDir = m_cache;
        env.makeDecoder = [obj = vlc.object()] { return makeVlcWaveformDecoder(obj); };
        WaveformProvider provider(env);
        provider.setUrl(longUrl);
        QTest::qWait(30);
        QElapsedTimer timer;
        timer.start();
        provider.setUrl(shortUrl);
        QTRY_VERIFY_WITH_TIMEOUT(provider.ready(), 30000);
        qInfo() << "short file ready" << timer.elapsed() << "ms after the url change (the 10 min file was running)";
        QCOMPARE(provider.url(), shortUrl);
        const QVariantList peaks = provider.peaks();
        QCOMPARE(peaks.size(), kWaveformBuckets);
        QVERIFY(peaks[500].toDouble() > 0.15 && peaks[500].toDouble() < 0.35);
    }

    void realDecoderFailsOnGarbage()
    {
        VlcInstance vlc;
        QVERIFY(vlc.ok());
        const QUrl url = makeFile("garbage.mp3", 3000);

        WaveformEnvironment env;
        env.cacheDir = m_cache;
        env.makeDecoder = [obj = vlc.object()] { return makeVlcWaveformDecoder(obj); };
        WaveformProvider provider(env);
        QSignalSpy changed(&provider, &WaveformProvider::peaksChanged);
        provider.setUrl(url);
        QTest::qWait(1500);
        QVERIFY(!provider.ready());
        QVERIFY(!QFile::exists(waveformCacheFile(m_cache, url)));
    }

private:
    //! a libvlc instance on a throwaway profile; its libvlccore object is the parent of the decoder
    class VlcInstance
    {
    public:
        VlcInstance()
        {
            setenv("VLC_PLUGIN_PATH", TOP_BUILDDIR"/modules", 1);
            setenv("VLC_LIB_PATH", TOP_BUILDDIR"/modules", 1);
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
