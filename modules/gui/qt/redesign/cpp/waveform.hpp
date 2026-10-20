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
#ifndef REDESIGN_WAVEFORM_HPP
#define REDESIGN_WAVEFORM_HPP

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <vector>

#include <QByteArray>
#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantList>
#include <QVector>

namespace redesign
{

//! number of values of a waveform (what the seek bar draws)
constexpr int kWaveformBuckets = 1000;
//! sample rate of the decoded mono PCM the peaks are computed from
constexpr int kWaveformRate = 8000;
//! files longer than this are not analysed (2 hours)
constexpr int kWaveformMaxSeconds = 2 * 3600;

//! max |s| / 32768 of every bucket; size() == buckets. The samples are spread evenly over the
//! buckets; with fewer samples than buckets, sample i is bucket i and the trailing buckets are 0.
QVector<float> computePeaks(const int16_t* samples, size_t count, int buckets);

//! little-endian float32, 4 bytes per value
QByteArray encodePeaks(const QVector<float>& peaks);
//! empty when the size is not a multiple of 4
QVector<float> decodePeaks(const QByteArray& bytes);

//! The cache file: "VRWF", one version byte (1), then encodePeaks() of exactly kWaveformBuckets
//! values. A later version may append fields (the loudness gain): bump the byte, old files are
//! then rejected by decodeWaveformCache() and decoded again.
QByteArray encodeWaveformCache(const QVector<float>& peaks);
//! empty on a wrong magic, a version other than the one this build writes, a wrong size, or a
//! value that is not a finite number in [0, 1]
QVector<float> decodeWaveformCache(const QByteArray& file);
//! The negative marker, stored in the cache file of a url that can not be analysed (too long, no
//! audio, undecodable): "VRWF" + the version byte and nothing else. It stops the file from being
//! decoded again at every play; the provider ignores it when the source changed after it was
//! written, and after a week.
QByteArray encodeWaveformFailed();
bool isWaveformFailedMarker(const QByteArray& file);
//! <cacheDir>/<sha1 of the url, hex>.bin
QString waveformCacheFile(const QString& cacheDir, const QUrl& url);

/**
 * Builds the peaks of a stream of mono 16-bit samples of unknown length, in bounded memory:
 * it keeps the max |s| of blocks of samples and merges neighbouring blocks (the block size
 * doubles) whenever it holds too many of them, so the bucket borders move by at most a block.
 * Feed it from one thread; sampleCount() and exceeded() may be read from any thread.
 */
class PeaksAccumulator
{
public:
    //! more than maxSamples samples count as "too long" (exceeded()): 2 hours of 8 kHz audio
    explicit PeaksAccumulator(size_t maxSamples = size_t(kWaveformMaxSeconds) * kWaveformRate);

    void append(const int16_t* samples, size_t count);
    size_t sampleCount() const { return m_total.load(); }
    bool exceeded() const { return m_total.load() > m_maxSamples; }
    //! the peaks of everything appended so far (kWaveformBuckets values)
    QVector<float> finish() const;
    //! called on the feeding thread after every append() with sampleCount() (progress, tests)
    void setProgressCallback(std::function<void(size_t)> cb) { m_progress = std::move(cb); }

private:
    void fold();

    size_t m_maxSamples;
    std::atomic<size_t> m_total{0};
    size_t m_blockSize = 1;
    size_t m_inBlock = 0;
    int16_t m_blockMax = 0;
    std::vector<int16_t> m_blocks;
    std::function<void(size_t)> m_progress;
};

/** Cooperative cancellation of a job running on a worker thread. */
class CancelToken
{
public:
    void cancel();
    bool cancelled() const { return m_cancelled.load(); }
    //! wakes waitUntil(): call it after changing the state that the predicate reads
    void notify();
    //! blocks until the job is cancelled or pred() is true (pred reads atomics, see notify())
    void waitUntil(const std::function<bool()>& pred, std::chrono::milliseconds timeout);

private:
    std::atomic_bool m_cancelled{false};
    std::mutex m_mutex;
    std::condition_variable m_cond;
};

enum class DecodeResult
{
    Ok,
    Failed,      //!< the file can not be analysed (undecodable, too long, wrong format): remembered
    Interrupted, //!< cancelled, or the input stalled: not remembered, a later play may succeed
};

/**
 * Decodes a local file to mono 16-bit PCM and feeds it to a PeaksAccumulator. decode() is
 * blocking and runs on the worker thread of the job: it must return Interrupted quickly when
 * cancel is raised, and stop when acc.exceeded().
 */
class WaveformDecoder
{
public:
    virtual ~WaveformDecoder() = default;
    virtual DecodeResult decode(const QString& localFile, PeaksAccumulator& acc, CancelToken& cancel) = 0;
};

struct WaveformEnvironment
{
    QString cacheDir;                                           //!< empty: no cache
    std::function<std::unique_ptr<WaveformDecoder>()> makeDecoder; //!< called on the worker thread
    qint64 maxFileBytes = qint64(1) << 30;                      //!< larger files are skipped
};

class WaveformCoordinator;
struct WaveformJob;

/**
 * The waveform of the file at `url` as kWaveformBuckets values in [0, 1].
 *
 * Only file:// urls are analysed (a network share, \\host\share or a mounted NAS, is a file
 * url too and is allowed); every other url stays ready == false and failed == false. A file url
 * ends either ready (peaks) or failed (missing, too large, too long, without audio, undecodable,
 * input stalled); until then neither is set ("analysing").
 *
 * The work (cache read, decoding, cache write) runs on a worker thread, never on the GUI
 * thread, and is shared by all providers of the process: providers of the same url wait for one
 * job, and only one job runs at a time (the most recently requested waits least). A provider
 * that changes its url or is destroyed leaves its job, which is cancelled when nobody is left.
 * Providers must be used from the thread they were created in (the GUI thread).
 *
 * Shutdown: the application's end waits for the running job to stop. That wait is bounded by
 * the decoder, but a stalled read of a network share can keep VLC from stopping for a while;
 * the thread is never abandoned because it runs plugin code.
 */
class WaveformProvider : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged)
    //! kWaveformBuckets values in [0, 1], empty until ready
    Q_PROPERTY(QVariantList peaks READ peaks NOTIFY peaksChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY peaksChanged)
    //! the analysis of a file url ended without peaks
    Q_PROPERTY(bool failed READ failed NOTIFY failedChanged)

public:
    //! the environment of the application (set by registerQmlTypes); without one nothing is analysed
    static void setDefaultEnvironment(std::function<WaveformEnvironment()> factory);
    //! jobs that are running or waiting, all providers together (tests)
    static int activeJobs();

    explicit WaveformProvider(QObject* parent = nullptr);
    explicit WaveformProvider(WaveformEnvironment env, QObject* parent = nullptr);
    ~WaveformProvider() override;

    QUrl url() const { return m_url; }
    void setUrl(const QUrl& url);
    QVariantList peaks() const { return m_peaks; }
    bool ready() const { return !m_peaks.isEmpty(); }
    bool failed() const { return m_failed; }

signals:
    void urlChanged();
    void peaksChanged();
    void failedChanged();

private:
    friend class WaveformCoordinator;
    //! the job of the url ended (not called for a cancelled one)
    void jobEnded(bool ok, const QVector<float>& peaks);
    static bool isAnalysable(const QUrl& url);

    WaveformEnvironment m_env;
    QUrl m_url;
    QVariantList m_peaks;
    bool m_failed = false;
    std::shared_ptr<WaveformJob> m_job; //!< the job this provider waits for
};

} // namespace redesign

#endif
