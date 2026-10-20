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

class QThread;

namespace redesign
{

//! number of values of a waveform (what the seek bar draws)
constexpr int kWaveformBuckets = 1000;

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
//! empty on a wrong magic, a version other than the one this build writes, or a wrong size
QVector<float> decodeWaveformCache(const QByteArray& file);
//! <cacheDir>/<sha1 of the url, hex>.bin
QString waveformCacheFile(const QString& cacheDir, const QUrl& url);

/**
 * Builds the peaks of a stream of mono 16-bit samples of unknown length, in bounded memory:
 * it keeps the max |s| of blocks of samples and merges neighbouring blocks (the block size
 * doubles) whenever it holds too many of them, so the bucket borders move by at most a block.
 * Not thread safe: feed it from one thread.
 */
class PeaksAccumulator
{
public:
    //! more than maxSamples samples count as "too long" (exceeded()): 2 hours of 8 kHz audio
    explicit PeaksAccumulator(size_t maxSamples = size_t(2) * 3600 * 8000);

    void append(const int16_t* samples, size_t count);
    size_t sampleCount() const { return m_total; }
    bool exceeded() const { return m_total > m_maxSamples; }
    //! the peaks of everything appended so far (kWaveformBuckets values)
    QVector<float> finish() const;

private:
    void fold();

    size_t m_maxSamples;
    size_t m_total = 0;
    size_t m_blockSize = 1;
    size_t m_inBlock = 0;
    int16_t m_blockMax = 0;
    std::vector<int16_t> m_blocks;
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

/**
 * Decodes a local file to mono 16-bit PCM and feeds it to a PeaksAccumulator. decode() is
 * blocking and runs on the worker thread of the provider: it returns false on a failure and
 * when cancel is raised (it must then stop quickly), and stops when acc.exceeded().
 */
class WaveformDecoder
{
public:
    virtual ~WaveformDecoder() = default;
    virtual bool decode(const QString& localFile, PeaksAccumulator& acc, CancelToken& cancel) = 0;
};

struct WaveformEnvironment
{
    QString cacheDir;                                           //!< empty: no cache
    std::function<std::unique_ptr<WaveformDecoder>()> makeDecoder; //!< called on the worker thread
    qint64 maxFileBytes = qint64(1) << 30;                      //!< larger files are skipped
};

/**
 * The waveform of the file at `url` as kWaveformBuckets values in [0, 1].
 * Only file:// urls are analysed; every other url (and a file that is missing, too large, too
 * long, without audio or that cannot be decoded) leaves ready == false. The work (cache read,
 * decoding, cache write) runs on one worker thread at a time, never on the GUI thread; a new
 * url cancels the running job.
 */
class WaveformProvider : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged)
    //! kWaveformBuckets values in [0, 1], empty until ready
    Q_PROPERTY(QVariantList peaks READ peaks NOTIFY peaksChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY peaksChanged)

public:
    //! the environment of the application (set by registerQmlTypes); without one nothing is analysed
    static void setDefaultEnvironment(std::function<WaveformEnvironment()> factory);

    explicit WaveformProvider(QObject* parent = nullptr);
    explicit WaveformProvider(WaveformEnvironment env, QObject* parent = nullptr);
    ~WaveformProvider() override;

    QUrl url() const { return m_url; }
    void setUrl(const QUrl& url);
    QVariantList peaks() const { return m_peaks; }
    bool ready() const { return !m_peaks.isEmpty(); }

signals:
    void urlChanged();
    void peaksChanged();

private:
    struct Job;
    void startJobIfNeeded();
    void onJobFinished();
    static bool isAnalysable(const QUrl& url);

    WaveformEnvironment m_env;
    QUrl m_url;
    QVariantList m_peaks;
    quint64 m_generation = 0;     //!< bumped by every setUrl()
    quint64 m_handledGeneration = 0; //!< the generation whose job was started
    std::shared_ptr<Job> m_job;   //!< the running job: at most one
};

} // namespace redesign

#endif
