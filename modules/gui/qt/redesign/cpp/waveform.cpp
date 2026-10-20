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
#include <cmath>
#include <cstdlib>
#include <cstring>

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QPointer>
#include <QSaveFile>
#include <QThread>
#include <QtEndian>

namespace redesign
{

namespace
{

constexpr char kCacheMagic[4] = {'V', 'R', 'W', 'F'};
constexpr uint8_t kCacheVersion = 2;
constexpr int kCacheHeaderSize = 5;
//! a negative marker older than this (a week) is ignored
constexpr qint64 kFailedMarkerSeconds = qint64(7) * 24 * 3600;

//! the accumulator merges blocks when it holds this many (an even number)
constexpr size_t kMaxBlocks = size_t(1) << 20;

std::function<WaveformEnvironment()>& defaultEnvironment()
{
    static std::function<WaveformEnvironment()> factory;
    return factory;
}

//! RMS level in dBFS of `count` samples whose squares add up to `sumSquares`
float levelFromSum(uint64_t sumSquares, size_t count)
{
    if (count == 0 || sumSquares == 0)
        return kRmsFloorDbfs;
    const double meanSquare = double(sumSquares) / double(count);
    const double db = 10.0 * std::log10(meanSquare / (32768.0 * 32768.0));
    return float(std::max(db, double(kRmsFloorDbfs)));
}

inline uint64_t squareOf(int16_t s)
{
    return uint64_t(int32_t(s) * int32_t(s)); // at most 2^30
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

float rmsDbfs(const int16_t* samples, size_t count)
{
    if (!samples)
        return kRmsFloorDbfs;
    uint64_t sum = 0;
    for (size_t i = 0; i < count; ++i)
        sum += squareOf(samples[i]);
    return levelFromSum(sum, count);
}

float measuredGainDb(float rms)
{
    if (std::isnan(rms))
        return 0.f;
    return std::clamp(kMeasuredTargetDbfs - rms, kMeasuredGainMinDb, kMeasuredGainMaxDb);
}

QByteArray encodeWaveformCache(const QVector<float>& peaks, float gainDb)
{
    QByteArray file(kCacheMagic, sizeof(kCacheMagic));
    file.append(char(kCacheVersion));
    file.append(encodePeaks(peaks));
    file.append(encodePeaks({gainDb}));
    return file;
}

WaveformCache decodeWaveformCache(const QByteArray& file)
{
    constexpr int peaksBytes = kWaveformBuckets * int(sizeof(uint32_t));
    if (file.size() != kCacheHeaderSize + peaksBytes + int(sizeof(uint32_t)))
        return {};
    if (std::memcmp(file.constData(), kCacheMagic, sizeof(kCacheMagic)) != 0
        || uint8_t(file[sizeof(kCacheMagic)]) != kCacheVersion)
        return {};
    WaveformCache out;
    out.peaks = decodePeaks(file.mid(kCacheHeaderSize, peaksBytes));
    for (float p : out.peaks)
        if (!std::isfinite(p) || p < 0.f || p > 1.f)
            return {};
    const QVector<float> gain = decodePeaks(file.mid(kCacheHeaderSize + peaksBytes));
    if (gain.size() != 1 || !std::isfinite(gain[0]) || gain[0] < kMeasuredGainMinDb || gain[0] > kMeasuredGainMaxDb)
        return {};
    out.gainDb = gain[0];
    return out;
}

QByteArray encodeWaveformFailed()
{
    QByteArray file(kCacheMagic, sizeof(kCacheMagic));
    file.append(char(kCacheVersion));
    return file;
}

bool isWaveformFailedMarker(const QByteArray& file)
{
    return file == encodeWaveformFailed();
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
        m_sumSquares += squareOf(samples[i]);
        m_blockMax = std::max(m_blockMax, absSample(samples[i]));
        if (++m_inBlock == m_blockSize) {
            m_blocks.push_back(m_blockMax);
            m_blockMax = 0;
            m_inBlock = 0;
            if (m_blocks.size() >= kMaxBlocks)
                fold();
        }
    }
    const size_t total = m_total.load() + count;
    m_total.store(total);
    if (m_progress)
        m_progress(total);
}

void PeaksAccumulator::fold()
{
    const size_t half = m_blocks.size() / 2;
    for (size_t i = 0; i < half; ++i)
        m_blocks[i] = std::max(m_blocks[2 * i], m_blocks[2 * i + 1]);
    m_blocks.resize(half);
    m_blockSize *= 2;
}

float PeaksAccumulator::levelDbfs() const
{
    return levelFromSum(m_sumSquares, m_total.load());
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

// ---- jobs and their coordinator ---------------------------------------------------------

enum class JobOutcome { Ready, Failed, Cancelled };

struct WaveformJob
{
    QString key;
    QUrl url;
    WaveformEnvironment env;
    CancelToken cancel;
    QThread* thread = nullptr;
    std::vector<WaveformProvider*> subscribers;
    JobOutcome outcome = JobOutcome::Failed; //!< written by the worker, read after it ended
    QVector<float> peaks;
    float gainDb = 0.f;
};

namespace
{

void writeCacheFile(const QString& cacheFile, const QByteArray& content)
{
    if (cacheFile.isEmpty() || !QDir().mkpath(QFileInfo(cacheFile).absolutePath()))
        return;
    QSaveFile out(cacheFile);
    if (out.open(QIODevice::WriteOnly)) {
        out.write(content);
        out.commit();
    }
}

//! the whole work of a job, on its worker thread
JobOutcome runJob(WaveformJob& job)
{
    const WaveformEnvironment& env = job.env;
    const QString file = job.url.toLocalFile();
    const QFileInfo info(file);
    if (!info.isFile() || info.size() > env.maxFileBytes)
        return JobOutcome::Failed;

    // 1. the cache: a file written after the source last changed
    const QString cacheFile = env.cacheDir.isEmpty() ? QString() : waveformCacheFile(env.cacheDir, job.url);
    if (!cacheFile.isEmpty()) {
        const QFileInfo cacheInfo(cacheFile);
        if (cacheInfo.isFile() && cacheInfo.lastModified() >= info.lastModified()) {
            QFile f(cacheFile);
            if (f.open(QIODevice::ReadOnly)) {
                const QByteArray bytes = f.readAll();
                const WaveformCache cached = decodeWaveformCache(bytes);
                if (cached.peaks.size() == kWaveformBuckets) {
                    job.peaks = cached.peaks;
                    job.gainDb = cached.gainDb;
                    return JobOutcome::Ready;
                }
                if (isWaveformFailedMarker(bytes)
                    && cacheInfo.lastModified().secsTo(QDateTime::currentDateTime()) < kFailedMarkerSeconds)
                    return JobOutcome::Failed;
            }
        }
    }
    if (job.cancel.cancelled())
        return JobOutcome::Cancelled;
    if (!env.makeDecoder)
        return JobOutcome::Failed;

    // 2. decode
    std::unique_ptr<WaveformDecoder> decoder = env.makeDecoder();
    if (!decoder)
        return JobOutcome::Failed;
    PeaksAccumulator acc;
    const DecodeResult result = decoder->decode(file, acc, job.cancel);
    decoder.reset();
    if (job.cancel.cancelled())
        return JobOutcome::Cancelled;
    if (result == DecodeResult::Interrupted)
        return JobOutcome::Failed; // transient: no marker
    if (result == DecodeResult::Failed || acc.exceeded() || acc.sampleCount() == 0) {
        writeCacheFile(cacheFile, encodeWaveformFailed());
        return JobOutcome::Failed;
    }

    // 3. the cache; a failure to write it is not an error
    job.peaks = acc.finish();
    job.gainDb = acc.gainDb();
    writeCacheFile(cacheFile, encodeWaveformCache(job.peaks, job.gainDb));
    return JobOutcome::Ready;
}

} // namespace

/**
 * The process-wide queue of the jobs of all providers. It lives in the GUI thread (child of the
 * application object), runs one job thread at a time and shares a job between the providers of
 * the same url. Pending jobs are started newest first: the track that plays now is the one
 * whose waveform matters.
 */
class WaveformCoordinator : public QObject
{
public:
    /**
     * The queue of the process. It is a child of the QCoreApplication, so it is deleted (and its
     * running job joined) with it; the QPointer tells the next caller that it is gone, so an
     * interface that is opened again in the same process (with a new application object) gets a
     * new queue instead of a dangling one. Without an application object (a tool, a test that
     * has none) the queue has no parent and a static guard deletes it when the process ends.
     * Used from the GUI thread, like the providers.
     */
    static WaveformCoordinator& instance()
    {
        QPointer<WaveformCoordinator>& slot = instanceSlot();
        if (!slot) {
            QCoreApplication* app = QCoreApplication::instance();
            slot = new WaveformCoordinator(app);
            if (!app)
                orphanGuard().reset(slot.data());
        }
        return *slot;
    }

    //! the queue if there is one
    static WaveformCoordinator* existing() { return instanceSlot().data(); }

    //! deletes the queue (stops and joins the running job); the next instance() makes a new one
    static void shutdown()
    {
        WaveformCoordinator* coordinator = instanceSlot().data();
        if (!coordinator)
            return;
        if (orphanGuard().get() == coordinator)
            orphanGuard().release();
        delete coordinator; // the slot sees it go
    }

    //! no new queue is made just to ask
    static int jobsOfTheProcess()
    {
        const WaveformCoordinator* coordinator = instanceSlot().data();
        return coordinator ? coordinator->jobCount() : 0;
    }

    ~WaveformCoordinator() override
    {
        // never abandon a thread that runs plugin code: stop it and wait
        if (m_running && m_running->thread) {
            m_running->cancel.cancel();
            m_running->thread->wait();
            delete m_running->thread;
            m_running->thread = nullptr;
        }
    }

    std::shared_ptr<WaveformJob> subscribe(WaveformProvider* provider, const QUrl& url,
                                           const WaveformEnvironment& env)
    {
        const QString key = url.toString(QUrl::FullyEncoded) + QLatin1Char('\n') + env.cacheDir;
        std::shared_ptr<WaveformJob> job = find(key);
        if (!job) {
            job = std::make_shared<WaveformJob>();
            job->key = key;
            job->url = url;
            job->env = env;
            m_pending.push_back(job);
        }
        job->subscribers.push_back(provider);
        pump();
        return job;
    }

    void unsubscribe(WaveformProvider* provider, const std::shared_ptr<WaveformJob>& job)
    {
        auto& subs = job->subscribers;
        subs.erase(std::remove(subs.begin(), subs.end(), provider), subs.end());
        if (!subs.empty())
            return;
        if (job == m_running)
            job->cancel.cancel(); // ends by itself, onFinished() cleans up
        else
            m_pending.erase(std::remove(m_pending.begin(), m_pending.end(), job), m_pending.end());
    }

    int jobCount() const { return int(m_pending.size()) + (m_running ? 1 : 0); }

private:
    explicit WaveformCoordinator(QObject* parent) : QObject(parent) {}

    static QPointer<WaveformCoordinator>& instanceSlot()
    {
        static QPointer<WaveformCoordinator> slot;
        return slot;
    }

    static std::unique_ptr<WaveformCoordinator>& orphanGuard()
    {
        static std::unique_ptr<WaveformCoordinator> guard;
        return guard;
    }

    std::shared_ptr<WaveformJob> find(const QString& key) const
    {
        if (m_running && m_running->key == key && !m_running->cancel.cancelled())
            return m_running;
        for (const auto& job : m_pending)
            if (job->key == key)
                return job;
        return nullptr;
    }

    void pump()
    {
        if (m_running || m_pending.empty())
            return;
        m_running = m_pending.back();
        m_pending.pop_back();

        std::shared_ptr<WaveformJob> job = m_running;
        job->thread = QThread::create([this, job] {
            job->outcome = runJob(*job);
            QMetaObject::invokeMethod(this, [this, job] { onFinished(job); }, Qt::QueuedConnection);
        });
        job->thread->setObjectName(QStringLiteral("waveform"));
        // Only this waiting thread gets the low priority; the input and decoder threads that VLC
        // creates for the decode keep the normal one.
        job->thread->start(QThread::LowPriority);
    }

    void onFinished(const std::shared_ptr<WaveformJob>& job)
    {
        if (job->thread) {
            job->thread->wait();
            delete job->thread; // also drops the lambda that holds `job`
            job->thread = nullptr;
        }
        if (m_running == job)
            m_running.reset();

        // A handler of the signals may change or destroy a provider that is still waiting: take
        // the subscribers one by one (a provider that leaves removes itself from the list).
        while (!job->subscribers.empty()) {
            WaveformProvider* provider = job->subscribers.front();
            job->subscribers.erase(job->subscribers.begin());
            if (job->outcome != JobOutcome::Cancelled)
                provider->jobEnded(job->outcome == JobOutcome::Ready, job->peaks, job->gainDb);
        }
        pump();
    }

    std::shared_ptr<WaveformJob> m_running;
    std::vector<std::shared_ptr<WaveformJob>> m_pending;
};

// ---- WaveformProvider -------------------------------------------------------------------

void WaveformProvider::setDefaultEnvironment(std::function<WaveformEnvironment()> factory)
{
    defaultEnvironment() = std::move(factory);
}

int WaveformProvider::activeJobs()
{
    return WaveformCoordinator::jobsOfTheProcess();
}

void WaveformProvider::shutdown()
{
    WaveformCoordinator::shutdown();
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
    // does not wait: a job nobody waits for is cancelled and ends on its own
    leaveJob();
}

void WaveformProvider::leaveJob()
{
    if (!m_job)
        return;
    // a queue that is gone (shutdown) has nothing to tell; do not make one just for that
    if (WaveformCoordinator* coordinator = WaveformCoordinator::existing())
        coordinator->unsubscribe(this, m_job);
    m_job.reset();
}

bool WaveformProvider::isAnalysable(const QUrl& url)
{
    return url.isValid() && url.scheme() == QLatin1String("file") && !url.toLocalFile().isEmpty();
}

void WaveformProvider::setUrl(const QUrl& url)
{
    if (url == m_url)
        return;
    leaveJob();
    m_url = url;
    emit urlChanged();

    if (!m_peaks.isEmpty()) {
        m_peaks.clear();
        m_gainDb = 0.0;
        m_peak = 0.0;
        emit peaksChanged();
    }
    if (m_failed) {
        m_failed = false;
        emit failedChanged();
    }
    if (isAnalysable(m_url))
        m_job = WaveformCoordinator::instance().subscribe(this, m_url, m_env);
}

void WaveformProvider::jobEnded(bool ok, const QVector<float>& peaks, float gainDb)
{
    m_job.reset();
    if (ok && peaks.size() == kWaveformBuckets) {
        QVariantList list;
        list.reserve(peaks.size());
        for (float p : peaks)
            list.append(double(p));
        m_peaks = list;
        m_gainDb = double(gainDb);
        m_peak = double(*std::max_element(peaks.begin(), peaks.end()));
        emit peaksChanged();
    } else {
        m_failed = true;
        emit failedChanged();
    }
}

} // namespace redesign
