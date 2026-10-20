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

#include "toolmanager.hpp"

#include <chrono>
#include <new>

#include <QCryptographicHash>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSettings>
#include <QTemporaryDir>
#include <QUrl>

// Qt has no public zip API; QZipReader is a private class of QtCore (present in the
// contribs of the win64 build and in the Linux test image, see docs/redesign/building.md)
#include <private/qzipreader_p.h>

namespace
{

const char SETTINGS_KEY_CONSENT[] = "redesign/toolsConsent";

// the extracted executable of a zip is read into memory: refuse absurd sizes
constexpr qint64 MAX_EXTRACTED_SIZE = qint64(512) << 20;

// the final move may meet a virus scanner that holds the files for a moment
constexpr int RENAME_ATTEMPTS = 10;
constexpr std::chrono::milliseconds RENAME_PAUSE{200};

bool isHttps(const QString& url)
{
    const QUrl u(url, QUrl::StrictMode);
    return u.isValid() && u.scheme() == QLatin1String("https") && !u.host().isEmpty();
}

// name, version and exe become path components
bool isSafeComponent(const QString& s)
{
    static const QRegularExpression re(QStringLiteral("^[A-Za-z0-9][A-Za-z0-9._-]*$"));
    return re.match(s).hasMatch() && !s.contains(QLatin1String(".."));
}

bool isDigest(const QString& s)
{
    static const QRegularExpression re(QStringLiteral("^[0-9a-fA-F]{64}$"));
    return re.match(s).hasMatch();
}

QString cleanedDir(const QString& dir)
{
    return QDir::cleanPath(QDir::fromNativeSeparators(dir));
}

//! a member name of a zip that stays inside the archive's own tree
bool isSafeZipPath(const QString& path)
{
    if (path.isEmpty() || path.startsWith(QLatin1Char('/')) || path.contains(QLatin1Char('\\'))
        || path.contains(QLatin1Char(':')))
        return false;
    const QStringList parts = path.split(QLatin1Char('/'));
    for (const QString& part : parts)
        if (part == QLatin1String(".."))
            return false;
    return true;
}

bool renameWithRetries(const QString& from, const QString& to)
{
    for (int attempt = 0; attempt < RENAME_ATTEMPTS; ++attempt) {
        if (QDir().rename(from, to))
            return true;
        std::this_thread::sleep_for(RENAME_PAUSE);
    }
    return false;
}

/*
 * Extracts the executable named exeName of the zip into outPath. The member must be a regular
 * file with a safe path and the only candidate (among several, the one in a bin/ directory).
 * digestOut receives the SHA-256 of the extracted bytes, computed in memory before they are written;
 * when expectedDigest is not empty the bytes must match it.
 */
bool extractExe(const QString& zipPath, const QString& exeName, const QString& expectedDigest,
                const QString& outPath, QString* digestOut, QString* error)
{
    QZipReader zip(zipPath);
    if (!zip.isReadable()) {
        *error = QObject::tr("The downloaded archive cannot be read.");
        return false;
    }

    QList<QZipReader::FileInfo> candidates;
    const auto infos = zip.fileInfoList();
    for (const auto& info : infos) {
        if (!info.isFile || info.isSymLink || !isSafeZipPath(info.filePath))
            continue;
        if (info.filePath.section(QLatin1Char('/'), -1) == exeName)
            candidates.append(info);
    }
    // prefer the bin/ directory of the typical ffmpeg builds when several files have the name
    if (candidates.size() > 1) {
        QList<QZipReader::FileInfo> inBin;
        for (const auto& info : std::as_const(candidates))
            if (info.filePath.section(QLatin1Char('/'), -2, -2) == QLatin1String("bin"))
                inBin.append(info);
        candidates = inBin;
    }
    if (candidates.size() != 1) {
        *error = QObject::tr("The downloaded archive does not contain exactly one %1.").arg(exeName);
        return false;
    }

    const auto info = candidates.first();
    if (info.size <= 0 || info.size > MAX_EXTRACTED_SIZE) {
        *error = QObject::tr("The executable in the downloaded archive has an unexpected size.");
        return false;
    }
    const QByteArray data = zip.fileData(info.filePath);
    if (data.size() != info.size) {
        *error = QObject::tr("The executable could not be extracted from the downloaded archive.");
        return false;
    }

    *digestOut = QString::fromLatin1(QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex());
    if (!expectedDigest.isEmpty() && digestOut->compare(expectedDigest, Qt::CaseInsensitive) != 0) {
        *error = QObject::tr("The %1 in the downloaded archive does not match its checksum.").arg(exeName);
        return false;
    }

    QFile out(outPath);
    if (!out.open(QIODevice::WriteOnly) || out.write(data) != data.size() || !out.flush()) {
        *error = QObject::tr("The executable could not be written.");
        return false;
    }
    return true;
}

} // anonymous namespace

ToolFetcher::~ToolFetcher() = default;

ToolManager::ToolManager(const QString& toolsRoot, const QList<ToolEntry>& tools,
                         std::unique_ptr<ToolFetcher> fetcher, QSettings* settings, QObject* parent)
    : QObject(parent)
    , m_toolsRoot(cleanedDir(toolsRoot))
    , m_tools(tools)
    , m_fetcher(std::move(fetcher))
    , m_settings(settings)
{
    Q_ASSERT(m_fetcher); // abortJob() and ensure() still cope with a null one
    if (!m_settings)
        m_settings = new QSettings(this); // child of this: deleted with it

    // downloads that a crash left behind (a running one is younger than a day)
    const QDir parentDir(QFileInfo(m_toolsRoot).absolutePath());
    const auto stale = parentDir.entryInfoList({QStringLiteral("tools-tmp-*")}, QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QFileInfo& dir : stale)
        if (dir.lastModified() < QDateTime::currentDateTime().addDays(-1))
            QDir(dir.absoluteFilePath()).removeRecursively();
}

ToolManager::~ToolManager()
{
    for (auto& [name, job] : m_jobs)
        job->cancel = true;
    if (m_fetcher)
        m_fetcher->abortAll();
    for (auto& [name, job] : m_jobs) {
        if (job->thread.joinable())
            job->thread.join();
    }
}

bool ToolManager::consentGiven() const
{
    return m_settings->value(QLatin1String(SETTINGS_KEY_CONSENT), false).toBool();
}

void ToolManager::setConsentGiven(bool given)
{
    if (given == consentGiven())
        return;
    m_settings->setValue(QLatin1String(SETTINGS_KEY_CONSENT), given);
    m_settings->sync();

    if (!given) {
        // no download goes on without the consent; what is installed stays, and a verification
        // needs no consent
        m_pendingEnsure.clear();
        for (auto& [name, job] : m_jobs)
            if (job->download)
                abortJob(*job);
    }
    emit consentGivenChanged();
}

const ToolEntry* ToolManager::find(const QString& name) const
{
    for (const auto& entry : m_tools)
        if (entry.name == name)
            return &entry;
    return nullptr;
}

QString ToolManager::installDir(const QString& toolsRoot, const ToolEntry& entry)
{
    return toolsRoot + QLatin1Char('/') + entry.name + QLatin1Char('-') + entry.version;
}

ToolManager::FileStamp ToolManager::stampOf(const QString& file)
{
    const QFileInfo info(file);
    FileStamp stamp;
    if (info.isFile()) {
        stamp.path = info.absoluteFilePath();
        stamp.size = info.size();
        stamp.mtime = info.lastModified().toMSecsSinceEpoch();
    }
    return stamp;
}

bool ToolManager::isVerified(const ToolEntry& entry) const
{
    const auto it = m_verified.find(entry.name);
    if (it == m_verified.end())
        return false;
    const FileStamp now = stampOf(installDir(m_toolsRoot, entry) + QLatin1Char('/') + entry.exe);
    return now.size >= 0 && now == it->second;
}

QString ToolManager::path(const QString& name) const
{
    const ToolEntry* entry = find(name);
    if (!entry || !isVerified(*entry))
        return {};
    return m_verified.at(name).path;
}

qint64 ToolManager::downloadSize(const QString& name) const
{
    const ToolEntry* entry = find(name);
    return entry ? entry->size : 0;
}

bool ToolManager::busy(const QString& name) const
{
    return m_jobs.count(name) != 0;
}

void ToolManager::ensure(const QString& name)
{
    const ToolEntry* entry = find(name);
    if (!entry) {
        emit failed(name, tr("Unknown tool \"%1\".").arg(name));
        return;
    }
    if (!consentGiven()) {
        emit consentRequired(name);
        return;
    }
    if (isVerified(*entry)) {
        emit ready(name);
        return;
    }
    const auto running = m_jobs.find(name);
    if (running != m_jobs.end()) {
        // coalesced with the running job; after a verification-only job the download may still be needed
        if (!running->second->download)
            m_pendingEnsure.insert(name);
        return;
    }
    if (!isHttps(entry->url) || !m_fetcher) {
        emit failed(name, tr("The download address of %1 is not an https address.").arg(name));
        return;
    }
    start(*entry, true);
}

void ToolManager::verifyAsync(const QString& name)
{
    const ToolEntry* entry = find(name);
    if (!entry) {
        emit verified(name, false);
        return;
    }
    if (isVerified(*entry)) {
        emit verified(name, true);
        return;
    }
    if (busy(name))
        return;
    if (!QFileInfo(installDir(m_toolsRoot, *entry) + QLatin1Char('/') + entry->exe).isFile()) {
        emit verified(name, false);
        return;
    }
    start(*entry, false);
}

void ToolManager::start(const ToolEntry& entry, bool download)
{
    const QString name = entry.name;
    auto job = std::make_unique<Job>();
    job->download = download;
    Job* raw = job.get();
    m_jobs[name] = std::move(job);

    raw->thread = std::thread([this, raw, name, entry, download, root = m_toolsRoot, fetcher = m_fetcher.get()] {
        // the progress events are throttled: a fetch reports every few KB
        auto last = std::chrono::steady_clock::now() - std::chrono::seconds(1);
        const auto report = [this, &name, &last](qint64 done, qint64 total) {
            const auto now = std::chrono::steady_clock::now();
            if (now - last < std::chrono::milliseconds(100) && done != total)
                return;
            last = now;
            QMetaObject::invokeMethod(this, [this, name, done, total] {
                emit progress(name, done, total);
            }, Qt::QueuedConnection);
        };

        Outcome outcome;
        try {
            outcome = work(entry, root, fetcher, report, raw->cancel, download);
        } catch (const std::bad_alloc&) {
            outcome.ok = false;
            outcome.error = tr("Not enough memory to unpack the download.");
        } catch (...) {
            outcome.ok = false;
            outcome.error = tr("Unexpected error while installing the tool.");
        }
        if (!outcome.ok && outcome.error.isEmpty())
            outcome.error = tr("The download failed.");

        QMetaObject::invokeMethod(this, [this, name, outcome] {
            finish(name, outcome);
        }, Qt::QueuedConnection);
    });
}

void ToolManager::cancel(const QString& name)
{
    const auto it = m_jobs.find(name);
    if (it == m_jobs.end())
        return;
    m_pendingEnsure.remove(name);
    abortJob(*it->second);
}

void ToolManager::abortJob(Job& job)
{
    job.cancel = true;
    if (m_fetcher)
        m_fetcher->abort(job.cancel);
}

void ToolManager::finish(const QString& name, const Outcome& outcome)
{
    bool download = true;
    const auto it = m_jobs.find(name);
    if (it != m_jobs.end()) {
        download = it->second->download;
        if (it->second->thread.joinable())
            it->second->thread.join();
        m_jobs.erase(it);
    }
    const bool pending = m_pendingEnsure.remove(name);

    if (outcome.ok) {
        m_verified[name] = outcome.stamp;
        if (download || pending)
            emit ready(name);
        if (!download)
            emit verified(name, true);
    } else if (download) {
        emit failed(name, outcome.error);
    } else {
        emit verified(name, false);
        if (pending)
            ensure(name); // the installed file does not verify: download it
    }
}

/*
 * Runs on the worker thread: an installed tool that verifies is used as it is, otherwise (when
 * the job may download) it is installed.
 */
ToolManager::Outcome ToolManager::work(const ToolEntry& entry, const QString& toolsRoot, ToolFetcher* fetcher,
                                       const std::function<void(qint64, qint64)>& progress,
                                       std::atomic_bool& cancel, bool download)
{
    Outcome outcome;
    const QString exe = installDir(toolsRoot, entry) + QLatin1Char('/') + entry.exe;

    if (QFileInfo(exe).isFile() && verifyInstalled(entry, exe, cancel)) {
        outcome.stamp = stampOf(exe);
        outcome.ok = outcome.stamp.size >= 0 && !cancel; // a cancellation after the last check counts
        if (cancel)
            outcome.error = tr("The download was cancelled.");
        return outcome;
    }
    if (cancel) {
        outcome.error = tr("The download was cancelled.");
        return outcome;
    }
    if (!download) {
        outcome.error = tr("%1 is not installed or does not match its checksum.").arg(entry.name);
        return outcome;
    }

    if (!install(entry, toolsRoot, fetcher, progress, cancel, &outcome.error))
        return outcome;
    outcome.stamp = stampOf(exe);
    outcome.ok = outcome.stamp.size >= 0;
    if (!outcome.ok)
        outcome.error = tr("The tool cannot be found after the installation.");
    else if (cancel) { // e.g. the consent was revoked after the last check of install()
        outcome.ok = false;
        outcome.error = tr("The download was cancelled.");
    }
    return outcome;
}

/*
 * Whether the installed executable is the verified one; see the class comment for what is
 * trusted for each kind of tool.
 */
bool ToolManager::verifyInstalled(const ToolEntry& entry, const QString& exe, const std::atomic_bool& cancel)
{
    const QString digest = sha256OfFile(exe, &cancel);
    if (digest.isEmpty())
        return false;

    if (entry.archive.isEmpty())
        return digest == entry.sha256;
    if (!entry.exeSha256.isEmpty())
        return digest == entry.exeSha256;

    // an archive without a published digest of the executable: the record of the installation is
    // an integrity hint only (it is user-writable, see the class comment)
    QFile record(exe + QLatin1String(".verified"));
    if (!record.open(QIODevice::ReadOnly))
        return false;
    const QList<QByteArray> fields = record.readAll().trimmed().split(' ');
    return fields.size() == 2 && QString::fromLatin1(fields.at(0)) == digest
           && fields.at(1).toLongLong() == QFileInfo(exe).size();
}

/*
 * Runs on the worker thread. Nothing is written below toolsRoot until the download is verified
 * and (for an archive) extracted: everything happens in a temporary directory beside toolsRoot (same
 * volume, so the final move is a rename), which is deleted on every exit path.
 */
bool ToolManager::install(const ToolEntry& entry, const QString& toolsRoot, ToolFetcher* fetcher,
                          const std::function<void(qint64, qint64)>& progress,
                          std::atomic_bool& cancel, QString* error)
{
    const QString parentDir = QFileInfo(toolsRoot).absolutePath();
    if (!QDir().mkpath(parentDir)) {
        *error = tr("The folder for the tools cannot be created.");
        return false;
    }
    QTemporaryDir tmp(parentDir + QLatin1String("/tools-tmp-XXXXXX"));
    if (!tmp.isValid()) {
        *error = tr("The folder for the download cannot be created.");
        return false;
    }

    const QString download = tmp.filePath(QStringLiteral("download"));
    {
        QFile out(download);
        if (!out.open(QIODevice::WriteOnly)) {
            *error = tr("The download file cannot be created.");
            return false;
        }

        // the manifest pins the size: a download of another size is stopped as soon as it is
        // known (the announced size, or more data than expected) instead of filling the disk
        bool badSize = false;
        const auto guarded = [&](qint64 done, qint64 total) {
            if ((total >= 0 && total != entry.size) || done > entry.size) {
                badSize = true;
                cancel = true;
            }
            progress(done, total);
        };
        const bool fetched = fetcher->fetch(entry.url, &out, guarded, cancel, error);
        if (badSize) {
            *error = tr("The download does not have the expected size.");
            return false;
        }
        if (!fetched) {
            if (cancel)
                *error = tr("The download was cancelled.");
            return false;
        }
        if (cancel) {
            *error = tr("The download was cancelled.");
            return false;
        }
        if (!out.flush()) {
            *error = tr("The download could not be written.");
            return false;
        }
    }

    if (QFileInfo(download).size() != entry.size) {
        *error = tr("The download does not have the expected size.");
        return false;
    }
    const QString downloadDigest = sha256OfFile(download, &cancel);
    if (downloadDigest.isEmpty() && cancel) {
        *error = tr("The download was cancelled.");
        return false;
    }
    if (downloadDigest.compare(entry.sha256, Qt::CaseInsensitive) != 0) {
        *error = tr("The download of %1 does not match its checksum and was deleted.").arg(entry.name);
        return false;
    }

    const QString stage = tmp.filePath(QStringLiteral("stage"));
    if (!QDir().mkpath(stage)) {
        *error = tr("The folder for the tool cannot be created.");
        return false;
    }
    const QString exe = stage + QLatin1Char('/') + entry.exe;

    // the digest of the bytes that were verified: of the download, or of the extracted bytes
    QString verifiedDigest;
    if (entry.archive == QLatin1String("zip")) {
        if (!extractExe(download, entry.exe, entry.exeSha256, exe, &verifiedDigest, error))
            return false;
    } else {
        verifiedDigest = downloadDigest;
        if (!QFile::rename(download, exe)) {
            *error = tr("The tool cannot be moved into place.");
            return false;
        }
    }

    QFile record(exe + QLatin1String(".verified"));
    if (!record.open(QIODevice::WriteOnly)
        || record.write(QByteArray(verifiedDigest.toLatin1()).append(' ').append(QByteArray::number(QFileInfo(exe).size()))) < 0
        || !record.flush()) {
        *error = tr("The tool cannot be recorded as verified.");
        return false;
    }
    record.close();

    if (cancel) { // e.g. the consent was revoked while the archive was unpacked
        *error = tr("The download was cancelled.");
        return false;
    }

    // move into place: the old installation (which did not verify) goes aside first and is
    // restored if the new one cannot be moved in, so there is never a moment without a directory
    // to fall back to
    const QString finalDir = installDir(toolsRoot, entry);
    if (!QDir().mkpath(toolsRoot)) {
        *error = tr("The folder for the tools cannot be created.");
        return false;
    }
    const QString aside = tmp.filePath(QStringLiteral("old"));
    const bool hadOld = QFileInfo::exists(finalDir);
    if (hadOld && !renameWithRetries(finalDir, aside)) {
        *error = tr("An old installation of %1 cannot be replaced.").arg(entry.name);
        return false;
    }
    if (!renameWithRetries(stage, finalDir)) {
        if (hadOld && !renameWithRetries(aside, finalDir)) {
            // the old installation is deleted with the temporary directory: say so, the next
            // ensure() installs the tool again
            qWarning() << "tool manager: cannot move" << entry.name << "into place nor restore the previous installation in"
                       << finalDir;
            *error = tr("%1 could not be installed and the previous installation could not be restored.").arg(entry.name);
            return false;
        }
        *error = tr("The tool cannot be moved into place.");
        return false;
    }
    return true; // the old installation is deleted with the temporary directory
}

QString ToolManager::sha256OfFile(const QString& file, const std::atomic_bool* cancel)
{
    QFile f(file);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    QCryptographicHash hash(QCryptographicHash::Sha256);
    QByteArray buffer(1 << 20, Qt::Uninitialized);
    while (!f.atEnd()) {
        if (cancel && *cancel)
            return {};
        const qint64 got = f.read(buffer.data(), buffer.size());
        if (got < 0)
            return {};
        hash.addData(QByteArrayView(buffer.constData(), got));
    }
    return QString::fromLatin1(hash.result().toHex());
}

bool ToolManager::verifySha256(const QString& file, const QByteArray& hexDigest)
{
    const QString actual = sha256OfFile(file);
    if (actual.isEmpty() || hexDigest.size() != 64)
        return false;
    return actual.compare(QString::fromLatin1(hexDigest), Qt::CaseInsensitive) == 0;
}

std::optional<QList<ToolEntry>> ToolManager::parseManifest(const QByteArray& json, QString* error)
{
    const auto fail = [error](const QString& why) -> std::optional<QList<ToolEntry>> {
        if (error)
            *error = why;
        return std::nullopt;
    };

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(json, &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject())
        return fail(QStringLiteral("not a JSON object: ") + parseError.errorString());

    const QJsonObject root = doc.object();
    if (root.value(QLatin1String("version")).toInt(-1) != 1)
        return fail(QStringLiteral("unsupported manifest version"));
    if (!root.value(QLatin1String("tools")).isArray())
        return fail(QStringLiteral("missing \"tools\" array"));

    QList<ToolEntry> tools;
    const QJsonArray array = root.value(QLatin1String("tools")).toArray();
    for (const QJsonValue& value : array) {
        const QJsonObject o = value.toObject();
        ToolEntry e;
        e.name = o.value(QLatin1String("name")).toString();
        e.version = o.value(QLatin1String("version")).toString();
        e.url = o.value(QLatin1String("url")).toString();
        e.sha256 = o.value(QLatin1String("sha256")).toString().toLower();
        e.exe = o.value(QLatin1String("exe")).toString();
        e.archive = o.value(QLatin1String("archive")).toString();
        e.exeSha256 = o.value(QLatin1String("exeSha256")).toString().toLower();
        e.size = qint64(o.value(QLatin1String("size")).toDouble(0));

        if (!isSafeComponent(e.name))
            return fail(QStringLiteral("invalid tool name \"%1\"").arg(e.name));
        if (!isSafeComponent(e.version))
            return fail(QStringLiteral("%1: invalid version").arg(e.name));
        if (!isSafeComponent(e.exe))
            return fail(QStringLiteral("%1: invalid exe").arg(e.name));
        if (!isHttps(e.url))
            return fail(QStringLiteral("%1: the url must be an https url").arg(e.name));
        if (e.url.contains(QLatin1String("/latest/"), Qt::CaseInsensitive))
            return fail(QStringLiteral("%1: the url must name a release tag, not /latest/").arg(e.name));
        if (!isDigest(e.sha256))
            return fail(QStringLiteral("%1: sha256 must be 64 hex digits").arg(e.name));
        if (!e.exeSha256.isEmpty() && !isDigest(e.exeSha256))
            return fail(QStringLiteral("%1: exeSha256 must be 64 hex digits").arg(e.name));
        if (!e.archive.isEmpty() && e.archive != QLatin1String("zip"))
            return fail(QStringLiteral("%1: unsupported archive type").arg(e.name));
        if (e.size <= 0)
            return fail(QStringLiteral("%1: size must be the positive size in bytes of the download").arg(e.name));
        for (const auto& other : std::as_const(tools))
            if (other.name == e.name)
                return fail(QStringLiteral("%1: duplicate tool").arg(e.name));

        tools.append(e);
    }
    if (tools.isEmpty())
        return fail(QStringLiteral("no tools"));
    return tools;
}

QList<ToolEntry> ToolManager::bundledManifest()
{
    QFile file(QStringLiteral(":/redesign/tools/tools.json"));
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "tool manifest missing from the resources";
        return {};
    }
    QString error;
    const auto tools = parseManifest(file.readAll(), &error);
    if (!tools) {
        qWarning() << "tool manifest rejected:" << error;
        return {};
    }
    return *tools;
}
