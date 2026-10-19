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
#ifndef REDESIGN_TOOLMANAGER_HPP
#define REDESIGN_TOOLMANAGER_HPP

#include <atomic>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <thread>

#include <QByteArray>
#include <QList>
#include <QObject>
#include <QSet>
#include <QString>

class QIODevice;
class QSettings;

/**
 * One external tool of the manifest (redesign/tools/tools.json).
 */
struct ToolEntry
{
    QString name;       //!< "yt-dlp", "ffmpeg"
    QString version;    //!< pinned release tag
    QString url;        //!< https release-tag asset URL, never a "latest" URL
    QString sha256;     //!< lower case hex digest of the downloaded file (the archive, when archive is set)
    QString exe;        //!< file name of the executable
    QString archive;    //!< "" (the download is the executable) or "zip"
    QString exeSha256;  //!< optional digest of the extracted executable (only when the publisher gives one)
    qint64 size = 0;    //!< size in bytes of the download (required, > 0): shown in the consent dialog and enforced
};

/**
 * Blocking download of one URL into a device. The qt module has no Qt Network (contrib builds
 * qtbase with FEATURE_network=OFF), so the production implementation reads through VLC's stream
 * layer (toolmanagervlc.hpp); tests use a fake. It is called on a worker thread, never on the GUI
 * thread, and may be called by several workers at once.
 */
class ToolFetcher
{
public:
    virtual ~ToolFetcher();

    /**
     * Writes the content of the https url to out.
     *
     * @param progress called with (bytes written, total bytes or -1 when unknown)
     * @param cancel   the fetch stops as soon as possible once it is true; the address of the flag
     *                 identifies the fetch for abort()
     * @param error    receives a user readable reason when false is returned
     * @return true if the whole content was written
     */
    virtual bool fetch(const QString& url, QIODevice* out,
                       std::function<void(qint64, qint64)> progress,
                       std::atomic_bool& cancel, QString* error) = 0;

    //! wakes up the fetch that runs with this cancel flag (already set by the caller) if it is
    //! blocked in the network; the other fetches go on. Thread-safe.
    virtual void abort(std::atomic_bool& cancel) { Q_UNUSED(cancel); }

    //! wakes up all the fetches (destruction of the manager only). Thread-safe.
    virtual void abortAll() {}
};

/**
 * Downloads, verifies and installs the external tools (yt-dlp, ffmpeg) of the website
 * playback and download features, after the user gave consent (spec 12.1).
 *
 * Installation layout: <toolsRoot>/<name>-<version>/<exe> next to a "<exe>.verified" record.
 * A download goes to a temporary directory next to toolsRoot (same volume), is verified
 * against the pinned SHA-256 of the manifest, is extracted from its archive if needed, and is
 * moved into toolsRoot as a whole directory only after that. toolsRoot never contains a
 * partial or unverified file.
 *
 * What path() trusts. path() is cheap (GUI thread): it answers from an in-memory result of a
 * verification made by a worker thread, keyed on (path, size, modification time) of the
 * executable, and answers "" until a verification succeeded in this session (ensure() and
 * verifyAsync() make one). A verification is:
 *  - a tool downloaded as an executable (yt-dlp): the SHA-256 of the file equals the sha256 of the
 *    manifest, which is compiled into the application;
 *  - a tool from an archive with an "exeSha256" in the manifest: the SHA-256 of the file equals it;
 *  - a tool from an archive without "exeSha256" (ffmpeg: the publisher gives none): the
 *    "<exe>.verified" record (digest and size of the bytes that were verified and extracted at
 *    install time) equals the file. That record is an integrity hint against truncation and
 *    corruption only: it lives in the user profile, so a process that can write there as the same
 *    user can replace the file and the record together. That attacker (same user, able to write the
 *    profile) is outside the threat model; the archive itself is always verified against the
 *    pinned SHA-256 before extraction.
 *
 * Revoking the consent cancels the running jobs; installed files stay where they are, so the
 * users of path() must check consentGiven before every use of a tool.
 *
 * The QML singleton of the application (redesign::createToolManager) is null when the user data
 * directory is unknown; QML that uses it must guard against that.
 */
class ToolManager : public QObject
{
    Q_OBJECT

    //! the user allowed the downloads; persisted in the QSettings group "redesign", key "toolsConsent"
    Q_PROPERTY(bool consentGiven READ consentGiven WRITE setConsentGiven NOTIFY consentGivenChanged FINAL)

public:
    /**
     * @param toolsRoot  directory of the installed tools (created on demand)
     * @param tools      the manifest
     * @param fetcher    the download implementation
     * @param settings   where the consent is stored; not owned. nullptr: a default QSettings()
     *                   (organization/application of the QApplication, like the QML Settings of the redesign)
     */
    ToolManager(const QString& toolsRoot, const QList<ToolEntry>& tools,
                std::unique_ptr<ToolFetcher> fetcher, QSettings* settings = nullptr,
                QObject* parent = nullptr);
    ~ToolManager() override;

    bool consentGiven() const;
    //! false cancels the running jobs (failed follows); installed files are left in place
    void setConsentGiven(bool given);

    //! absolute path of the tool when it is installed and was verified in this session (see the
    //! class comment), "" otherwise. Cheap, never hashes.
    Q_INVOKABLE QString path(const QString& name) const;

    //! size in bytes of the download of the tool (consent dialog), 0 if unknown
    Q_INVOKABLE qint64 downloadSize(const QString& name) const;

    //! a download or a verification of the tool is running
    Q_INVOKABLE bool busy(const QString& name) const;

    /**
     * Installs the tool if it is not installed (or does not verify). Does nothing without consent
     * (consentRequired is emitted). Emits ready at once when the tool was verified in this session;
     * an installed tool that was not verified yet is verified first (worker thread), then ready
     * follows without a download. A running job of the same tool is not started twice. Result by
     * ready / failed, progress by progress.
     */
    Q_INVOKABLE void ensure(const QString& name);

    /**
     * Verifies an installed tool on a worker thread, without consent and without downloading:
     * verified(name, true) and path() answers afterwards, or verified(name, false). If a job of
     * the tool is already running its ready / failed comes instead.
     */
    Q_INVOKABLE void verifyAsync(const QString& name);

    //! stops the running job of the tool (only that one), failed follows
    Q_INVOKABLE void cancel(const QString& name);

    //! the pinned manifest of the build (:/redesign/tools/tools.json); empty and logged on error
    static QList<ToolEntry> bundledManifest();

    /**
     * Parses and validates a manifest. Rejects: other version than 1, a URL that is not https or
     * contains "/latest/", a digest that is not 64 hex digits, a missing or non-positive size,
     * names/versions that are not safe path components, an exe with a path, an unknown archive
     * type, duplicate tools.
     */
    static std::optional<QList<ToolEntry>> parseManifest(const QByteArray& json, QString* error);

    //! true if the SHA-256 of the file equals hexDigest (case-insensitive); false if unreadable
    static bool verifySha256(const QString& file, const QByteArray& hexDigest);

    //! lower case hex digest of the file, "" when it cannot be read or cancel became true meanwhile
    static QString sha256OfFile(const QString& file, const std::atomic_bool* cancel = nullptr);

signals:
    void consentGivenChanged();
    void consentRequired(const QString& name);
    void progress(const QString& name, qint64 done, qint64 total);
    void ready(const QString& name);
    void failed(const QString& name, const QString& reason);
    void verified(const QString& name, bool ok);

private:
    //! identifies the state of an executable that was verified
    struct FileStamp
    {
        QString path;
        qint64 size = -1;
        qint64 mtime = 0;

        bool operator==(const FileStamp& o) const
        {
            return path == o.path && size == o.size && mtime == o.mtime;
        }
    };

    struct Outcome
    {
        bool ok = false;
        QString error;
        FileStamp stamp;
    };

    struct Job
    {
        std::thread thread;
        std::atomic_bool cancel{false};
        bool download = true; //!< false: verification only (verifyAsync)
    };

    const ToolEntry* find(const QString& name) const;
    static QString installDir(const QString& toolsRoot, const ToolEntry& entry);
    static FileStamp stampOf(const QString& file);
    bool isVerified(const ToolEntry& entry) const;
    void start(const ToolEntry& entry, bool download);
    void finish(const QString& name, const Outcome& outcome);
    static Outcome work(const ToolEntry& entry, const QString& toolsRoot, ToolFetcher* fetcher,
                        const std::function<void(qint64, qint64)>& progress,
                        std::atomic_bool& cancel, bool download);
    static bool verifyInstalled(const ToolEntry& entry, const QString& exe, const std::atomic_bool& cancel);
    static bool install(const ToolEntry& entry, const QString& toolsRoot, ToolFetcher* fetcher,
                        const std::function<void(qint64, qint64)>& progress,
                        std::atomic_bool& cancel, QString* error);

    QString m_toolsRoot;
    QList<ToolEntry> m_tools;
    std::shared_ptr<ToolFetcher> m_fetcher;
    QSettings* m_settings = nullptr;
    std::map<QString, std::unique_ptr<Job>> m_jobs;
    std::map<QString, FileStamp> m_verified; //!< tools verified in this session
    QSet<QString> m_pendingEnsure;           //!< ensure() came while a verification ran
};

#endif
