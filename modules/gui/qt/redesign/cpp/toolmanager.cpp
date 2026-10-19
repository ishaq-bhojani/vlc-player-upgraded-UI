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
#include <QDebug>

// Qt has no public zip API; QZipReader is a private class of QtCore (present in the
// contribs of the win64 build and in the Linux test image, see docs/redesign/building.md)
#include <private/qzipreader_p.h>

namespace
{

const char SETTINGS_KEY_CONSENT[] = "redesign/toolsConsent";

// the extracted executable of a zip is read into memory: refuse absurd sizes
constexpr qint64 MAX_EXTRACTED_SIZE = qint64(1) << 30;

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

//! extracts the executable named exeName of the zip into outPath
bool extractExe(const QString& zipPath, const QString& exeName, const QString& outPath, QString* error)
{
    QZipReader zip(zipPath);
    if (!zip.isReadable()) {
        *error = QObject::tr("The downloaded archive cannot be read.");
        return false;
    }

    QList<QZipReader::FileInfo> candidates;
    const auto infos = zip.fileInfoList();
    for (const auto& info : infos) {
        if (!info.isFile)
            continue;
        const QString file = info.filePath.section(QLatin1Char('/'), -1);
        if (file == exeName)
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
    if (!m_settings) {
        m_settings = new QSettings(this);
        m_ownsSettings = true;
    }

    // downloads that a crash left behind (a running one is younger than a day)
    const QDir parentDir(QFileInfo(m_toolsRoot).absolutePath());
    const auto stale = parentDir.entryInfoList({QStringLiteral("tools-tmp-*")}, QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QFileInfo& dir : stale)
        if (dir.lastModified() < QDateTime::currentDateTime().addDays(-1))
            QDir(dir.absoluteFilePath()).removeRecursively();
}

ToolManager::~ToolManager()
{
    for (auto& [name, job] : m_jobs) {
        job->cancel = true;
    }
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
    emit consentGivenChanged();
}

const ToolEntry* ToolManager::find(const QString& name) const
{
    for (const auto& entry : m_tools)
        if (entry.name == name)
            return &entry;
    return nullptr;
}

QString ToolManager::installDir(const ToolEntry& entry) const
{
    return m_toolsRoot + QLatin1Char('/') + entry.name + QLatin1Char('-') + entry.version;
}

QString ToolManager::path(const QString& name) const
{
    const ToolEntry* entry = find(name);
    if (!entry)
        return {};

    // the directory appears in the tools directory only complete (see install()), the record is
    // checked against the file so that a replaced or truncated executable is not reported
    const QString exe = installDir(*entry) + QLatin1Char('/') + entry->exe;
    const QFileInfo info(exe);
    if (!info.isFile())
        return {};

    QFile record(exe + QLatin1String(".verified"));
    if (!record.open(QIODevice::ReadOnly))
        return {};
    const QList<QByteArray> fields = record.readAll().trimmed().split(' ');
    if (fields.size() != 2 || fields.at(1).toLongLong() != info.size())
        return {};

    return info.absoluteFilePath();
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
    if (!path(name).isEmpty()) {
        emit ready(name);
        return;
    }
    if (busy(name))
        return; // coalesced with the running download
    if (!isHttps(entry->url)) {
        emit failed(name, tr("The download address of %1 is not an https address.").arg(name));
        return;
    }

    auto job = std::make_unique<Job>();
    Job* raw = job.get();
    m_jobs[name] = std::move(job);

    raw->thread = std::thread([this, raw, name, entry = *entry, root = m_toolsRoot, fetcher = m_fetcher.get()] {
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

        QString error;
        bool ok = false;
        try {
            ok = install(entry, root, fetcher, report, raw->cancel, &error);
        } catch (const std::bad_alloc&) {
            error = tr("Not enough memory to unpack the download.");
        } catch (...) {
            error = tr("Unexpected error while installing the tool.");
        }
        if (!ok && error.isEmpty())
            error = tr("The download failed.");

        QMetaObject::invokeMethod(this, [this, name, ok, error] {
            finish(name, ok ? QString() : error);
        }, Qt::QueuedConnection);
    });
}

void ToolManager::cancel(const QString& name)
{
    const auto it = m_jobs.find(name);
    if (it == m_jobs.end())
        return;
    it->second->cancel = true;
    if (m_fetcher)
        m_fetcher->abortAll();
}

void ToolManager::finish(const QString& name, const QString& reason)
{
    const auto it = m_jobs.find(name);
    if (it != m_jobs.end()) {
        if (it->second->thread.joinable())
            it->second->thread.join();
        m_jobs.erase(it);
    }

    if (reason.isEmpty())
        emit ready(name);
    else
        emit failed(name, reason);
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

        bool oversize = false;
        const auto guarded = [&](qint64 done, qint64 total) {
            // the manifest pins the size: stop a download that is larger instead of filling the disk
            if (entry.size > 0 && done > entry.size) {
                oversize = true;
                cancel = true;
            }
            progress(done, total);
        };
        if (!fetcher->fetch(entry.url, &out, guarded, cancel, error)) {
            if (oversize)
                *error = tr("The download is larger than expected.");
            else if (cancel)
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

    if (!verifySha256(download, entry.sha256.toLatin1())) {
        *error = tr("The download of %1 does not match its checksum and was deleted.").arg(entry.name);
        return false;
    }

    const QString stage = tmp.filePath(QStringLiteral("stage"));
    if (!QDir().mkpath(stage)) {
        *error = tr("The folder for the tool cannot be created.");
        return false;
    }
    const QString exe = stage + QLatin1Char('/') + entry.exe;

    if (entry.archive == QLatin1String("zip")) {
        if (!extractExe(download, entry.exe, exe, error))
            return false;
        // the manifest has a digest of the executable only when the publisher gives one
        if (!entry.exeSha256.isEmpty() && !verifySha256(exe, entry.exeSha256.toLatin1())) {
            *error = tr("The %1 in the downloaded archive does not match its checksum.").arg(entry.exe);
            return false;
        }
    } else if (!QFile::rename(download, exe)) {
        *error = tr("The tool cannot be moved into place.");
        return false;
    }

    // the record lets path() tell an installed file from a tampered one without hashing it
    const QString digest = sha256OfFile(exe);
    QFile record(exe + QLatin1String(".verified"));
    if (digest.isEmpty() || !record.open(QIODevice::WriteOnly)
        || record.write(QByteArray(digest.toLatin1()).append(' ').append(QByteArray::number(QFileInfo(exe).size()))) < 0
        || !record.flush()) {
        *error = tr("The tool cannot be recorded as verified.");
        return false;
    }
    record.close();

    const QString finalDir = toolsRoot + QLatin1Char('/') + entry.name + QLatin1Char('-') + entry.version;
    if (!QDir().mkpath(toolsRoot)) {
        *error = tr("The folder for the tools cannot be created.");
        return false;
    }
    if (QFileInfo::exists(finalDir) && !QDir(finalDir).removeRecursively()) {
        *error = tr("An old installation of %1 cannot be replaced.").arg(entry.name);
        return false;
    }
    if (!QDir().rename(stage, finalDir)) {
        *error = tr("The tool cannot be moved into place.");
        return false;
    }
    return true;
}

QString ToolManager::sha256OfFile(const QString& file)
{
    QFile f(file);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    QCryptographicHash hash(QCryptographicHash::Sha256);
    if (!hash.addData(&f))
        return {};
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
        if (e.size < 0)
            return fail(QStringLiteral("%1: negative size").arg(e.name));
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
