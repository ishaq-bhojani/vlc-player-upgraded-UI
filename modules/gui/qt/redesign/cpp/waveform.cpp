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

#include "waveform.hpp"

#include <algorithm>
#include <cstdlib>
#include <cstring>

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QThread>
#include <QtEndian>

namespace redesign
{

namespace
{

constexpr char kCacheMagic[4] = {'V', 'R', 'W', 'F'};
constexpr uint8_t kCacheVersion = 1;
constexpr int kCacheHeaderSize = 5;

//! the accumulator merges blocks when it holds this many (an even number)
constexpr size_t kMaxBlocks = size_t(1) << 20;

std::function<WaveformEnvironment()>& defaultEnvironment()
{
    static std::function<WaveformEnvironment()> factory;
    return factory;
}

inline int16_t absSample(int16_t s)
{
    // |-32768| does not fit: it counts as 32767, the peak then is 32767 / 32768
    return s < 0 ? int16_t(s == INT16_MIN ? INT16_MAX : -s) : s;
}

} // namespace

QVector<float> computePeaks(const int16_t* samples, size_t count, int buckets)
{
    if (buckets <= 0)
        return {};
    QVector<float> peaks(buckets, 0.f);
    if (!samples || count == 0)
        return peaks;

    const size_t nb = size_t(buckets);
    if (count <= nb) {
        for (size_t i = 0; i < count; ++i)
            peaks[int(i)] = std::abs(int(samples[i])) / 32768.f;
        return peaks;
    }

    std::vector<int> maxima(nb, 0);
    for (size_t i = 0; i < count; ++i) {
        const size_t b = size_t((uint64_t(i) * nb) / count);
        maxima[b] = std::max(maxima[b], std::abs(int(samples[i])));
    }
    for (size_t b = 0; b < nb; ++b)
        peaks[int(b)] = maxima[b] / 32768.f;
    return peaks;
}

QByteArray encodePeaks(const QVector<float>& peaks)
{
    QByteArray bytes(peaks.size() * int(sizeof(uint32_t)), Qt::Uninitialized);
    for (int i = 0; i < peaks.size(); ++i) {
        uint32_t bits;
        std::memcpy(&bits, &peaks[i], sizeof(bits));
        qToLittleEndian<uint32_t>(bits, bytes.data() + i * int(sizeof(bits)));
    }
    return bytes;
}

QVector<float> decodePeaks(const QByteArray& bytes)
{
    if (bytes.size() % int(sizeof(uint32_t)) != 0)
        return {};
    QVector<float> peaks(bytes.size() / int(sizeof(uint32_t)));
    for (int i = 0; i < peaks.size(); ++i) {
        const uint32_t bits = qFromLittleEndian<uint32_t>(bytes.constData() + i * int(sizeof(bits)));
        std::memcpy(&peaks[i], &bits, sizeof(bits));
    }
    return peaks;
}

QByteArray encodeWaveformCache(const QVector<float>& peaks)
{
    QByteArray file(kCacheMagic, sizeof(kCacheMagic));
    file.append(char(kCacheVersion));
    file.append(encodePeaks(peaks));
    return file;
}

QVector<float> decodeWaveformCache(const QByteArray& file)
{
    if (file.size() != kCacheHeaderSize + kWaveformBuckets * int(sizeof(uint32_t)))
        return {};
    if (std::memcmp(file.constData(), kCacheMagic, sizeof(kCacheMagic)) != 0
        || uint8_t(file[sizeof(kCacheMagic)]) != kCacheVersion)
        return {};
    return decodePeaks(file.mid(kCacheHeaderSize));
}

QString waveformCacheFile(const QString& cacheDir, const QUrl& url)
{
    const QByteArray key = url.toString(QUrl::FullyEncoded).toUtf8();
    const QByteArray hash = QCryptographicHash::hash(key, QCryptographicHash::Sha1).toHex();
    return cacheDir + QLatin1Char('/') + QString::fromLatin1(hash) + QStringLiteral(".bin");
}

// ---- PeaksAccumulator ------------------------------------------------------------------

PeaksAccumulator::PeaksAccumulator(size_t maxSamples)
    : m_maxSamples(maxSamples)
{
}

void PeaksAccumulator::append(const int16_t* samples, size_t count)
{
    for (size_t i = 0; i < count; ++i) {
        m_blockMax = std::max(m_blockMax, absSample(samples[i]));
        if (++m_inBlock == m_blockSize) {
            m_blocks.push_back(m_blockMax);
            m_blockMax = 0;
            m_inBlock = 0;
            if (m_blocks.size() >= kMaxBlocks)
                fold();
        }
    }
    m_total += count;
}

void PeaksAccumulator::fold()
{
    const size_t half = m_blocks.size() / 2;
    for (size_t i = 0; i < half; ++i)
        m_blocks[i] = std::max(m_blocks[2 * i], m_blocks[2 * i + 1]);
    m_blocks.resize(half);
    m_blockSize *= 2;
}

QVector<float> PeaksAccumulator::finish() const
{
    std::vector<int16_t> blocks = m_blocks;
    if (m_inBlock > 0)
        blocks.push_back(m_blockMax);
    return computePeaks(blocks.data(), blocks.size(), kWaveformBuckets);
}

// ---- CancelToken ------------------------------------------------------------------------

void CancelToken::cancel()
{
    m_cancelled = true;
    notify();
}

void CancelToken::notify()
{
    // taking the mutex orders the notification after a waiter's predicate check
    { std::lock_guard<std::mutex> lock(m_mutex); }
    m_cond.notify_all();
}

void CancelToken::waitUntil(const std::function<bool()>& pred, std::chrono::milliseconds timeout)
{
    std::unique_lock<std::mutex> lock(m_mutex);
    m_cond.wait_for(lock, timeout, [&] { return m_cancelled.load() || pred(); });
}

// ---- WaveformProvider -------------------------------------------------------------------

struct WaveformProvider::Job
{
    quint64 generation = 0;
    QUrl url;
    QThread* thread = nullptr;
    CancelToken cancel;
    bool ok = false;
    QVector<float> peaks; //!< written by the worker thread, read after QThread::finished
};

void WaveformProvider::setDefaultEnvironment(std::function<WaveformEnvironment()> factory)
{
    defaultEnvironment() = std::move(factory);
}

WaveformProvider::WaveformProvider(QObject* parent)
    : WaveformProvider(defaultEnvironment() ? defaultEnvironment()() : WaveformEnvironment(), parent)
{
}

WaveformProvider::WaveformProvider(WaveformEnvironment env, QObject* parent)
    : QObject(parent)
    , m_env(std::move(env))
{
}

WaveformProvider::~WaveformProvider()
{
    if (!m_job)
        return;
    // the worker only touches its own Job (kept alive by the lambda) and the environment copy
    m_job->cancel.cancel();
    m_job->thread->disconnect(this);
    m_job->thread->wait();
    delete m_job->thread;
}

bool WaveformProvider::isAnalysable(const QUrl& url)
{
    return url.isValid() && url.scheme() == QLatin1String("file") && !url.toLocalFile().isEmpty();
}

void WaveformProvider::setUrl(const QUrl& url)
{
    if (url == m_url)
        return;
    m_url = url;
    ++m_generation;
    emit urlChanged();

    if (!m_peaks.isEmpty()) {
        m_peaks.clear();
        emit peaksChanged();
    }
    if (m_job)
        m_job->cancel.cancel(); // the next job starts when this one has ended
    startJobIfNeeded();
}

void WaveformProvider::startJobIfNeeded()
{
    if (m_job || m_handledGeneration == m_generation || !isAnalysable(m_url))
        return;
    m_handledGeneration = m_generation;

    auto job = std::make_shared<Job>();
    job->generation = m_generation;
    job->url = m_url;
    const WaveformEnvironment env = m_env;
    const QString file = m_url.toLocalFile();
    const QString cacheFile = env.cacheDir.isEmpty() ? QString() : waveformCacheFile(env.cacheDir, m_url);

    job->thread = QThread::create([job, env, file, cacheFile] {
        const QFileInfo info(file);
        if (!info.isFile() || info.size() > env.maxFileBytes)
            return;

        // 1. the cache: a valid file written after the source last changed
        if (!cacheFile.isEmpty()) {
            const QFileInfo cacheInfo(cacheFile);
            if (cacheInfo.isFile() && cacheInfo.lastModified() >= info.lastModified()) {
                QFile f(cacheFile);
                if (f.open(QIODevice::ReadOnly)) {
                    const QVector<float> cached = decodeWaveformCache(f.readAll());
                    if (cached.size() == kWaveformBuckets) {
                        job->peaks = cached;
                        job->ok = true;
                        return;
                    }
                }
            }
        }
        if (job->cancel.cancelled() || !env.makeDecoder)
            return;

        // 2. decode
        std::unique_ptr<WaveformDecoder> decoder = env.makeDecoder();
        if (!decoder)
            return;
        PeaksAccumulator acc;
        const bool decoded = decoder->decode(file, acc, job->cancel);
        decoder.reset();
        if (!decoded || job->cancel.cancelled() || acc.exceeded() || acc.sampleCount() == 0)
            return;
        job->peaks = acc.finish();
        job->ok = true;

        // 3. the cache; a failure to write it is not an error
        if (!cacheFile.isEmpty() && QDir().mkpath(QFileInfo(cacheFile).absolutePath())) {
            QSaveFile out(cacheFile);
            if (out.open(QIODevice::WriteOnly)) {
                out.write(encodeWaveformCache(job->peaks));
                out.commit();
            }
        }
    });
    job->thread->setObjectName(QStringLiteral("waveform"));
    connect(job->thread, &QThread::finished, this, &WaveformProvider::onJobFinished, Qt::QueuedConnection);
    m_job = job;
    job->thread->start(QThread::LowPriority);
}

void WaveformProvider::onJobFinished()
{
    if (!m_job)
        return;
    std::shared_ptr<Job> job = std::move(m_job);
    m_job.reset();
    job->thread->wait();
    delete job->thread;
    job->thread = nullptr;

    if (job->ok && job->generation == m_generation && !job->cancel.cancelled()
        && job->peaks.size() == kWaveformBuckets) {
        QVariantList list;
        list.reserve(job->peaks.size());
        for (float p : job->peaks)
            list.append(double(p));
        m_peaks = list;
        emit peaksChanged();
    }
    startJobIfNeeded();
}

} // namespace redesign
