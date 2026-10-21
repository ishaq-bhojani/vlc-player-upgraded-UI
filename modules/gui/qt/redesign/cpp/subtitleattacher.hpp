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
#ifndef VLC_QT_REDESIGN_SUBTITLEATTACHER_HPP
#define VLC_QT_REDESIGN_SUBTITLEATTACHER_HPP

#include <functional>
#include <memory>

#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

/**
 * Where the subtitle files saved for a media live: the media library in the app (see
 * mlsubtitlestore.hpp), a table in the tests.
 *
 * Both calls are asynchronous (the library answers on its own thread): `done` is called on the Qt
 * thread, the one of the SubtitleAttacher that owns the store, possibly before the call returns.
 * A store must not call `done` anymore once it is destroyed.
 */
class SubtitleStore
{
public:
    virtual ~SubtitleStore() = default;

    //! `done(mrls)`: the subtitle files saved for the media `mrl`; empty when the media is not in the library
    virtual void subtitles(const QString& mrl, std::function<void(QStringList)> done) = 0;

    //! saves `subtitle` for `mrl`; `done(true)` when it is saved (or already was), false when the
    //! media is not in the library or the library refused
    virtual void add(const QString& mrl, const QString& subtitle, std::function<void(bool)> done) = 0;
};

/**
 * What the subtitle tools need from the player and the play queue (the VLC ones are in
 * subtitleattachervlc.hpp). All the calls are made on the Qt thread and must not block.
 */
struct SubtitleEnvironment
{
    //! adds the subtitle file `mrl` to the media being played; `select`: show it at once, `notify`:
    //! say so on screen. false when it was refused (no media, or the player is not ready)
    std::function<bool(const QString& mrl, bool select, bool notify)> addToCurrent;

    //! the addresses of the media of the play queue, in order
    std::function<QStringList()> queueUrls;

    //! gives the media at `index` of the play queue the subtitle file `mrl` (it is loaded with it
    //! whenever it plays; when it is the media being played, it is added to it as well)
    std::function<bool(int index, const QString& mrl)> addToQueueItem;
};

/**
 * @brief Adds subtitle files to the media being played and to the play queue, and brings back the
 * ones saved in the media library.
 *
 * The QML singleton `SubtitleAttacher` of VLC.Redesign (registered in redesign/cpp/qmlregistration.cpp).
 *
 *  - attachToCurrent / attachToPlaylist add subtitle files and save the association in the media
 *    library (SubtitleStore) when there is one, so that the next playback finds them. Without a
 *    library they still add the files: only the saving is skipped.
 *  - onInputChanged brings them back: whenever a media starts, the subtitle files saved for it are
 *    added to it (the stock interface only reads the main file of a library media, see
 *    MediaToInputItem in modules/misc/medialibrary/entities.cpp). Exactly once per media, and
 *    never without a library. They join the subtitle tracks silently; the last one saved is
 *    also selected, as the user attached it on purpose (the same as a subtitle of a queue item,
 *    which the input forces when it starts).
 *  - listFolder reads a folder for the dialog.
 *
 * The media library is never waited for: it answers through callbacks (SubtitleStore).
 */
class SubtitleAttacher : public QObject
{
    Q_OBJECT

    //! the extensions (lower case, without dot) VLC knows for subtitle files (EXTENSIONS_SUBTITLE)
    Q_PROPERTY(QStringList subtitleExtensions READ subtitleExtensions CONSTANT FINAL)

public:
    //! most entries listFolder returns of each kind
    static constexpr int maxFolderEntries = 2000;

    explicit SubtitleAttacher(QObject* parent = nullptr);

    //! gives the player and the queue; an empty member makes the matching call fail
    void setEnvironment(SubtitleEnvironment environment);

    //! gives the store (the media library); none means there is no library
    void setStore(std::unique_ptr<SubtitleStore> store);

    bool hasStore() const { return static_cast<bool>(m_store); }

    /**
     * Adds the subtitle file `sub` to the media being played and selects it, then saves it for that
     * media. Returns whether the player took it. The saving is asynchronous and silent, see persist().
     */
    Q_INVOKABLE bool attachToCurrent(const QUrl& sub);

    /**
     * Saves `sub` as a subtitle file of the media `media` in the media library. Returns false at
     * once when it can not be tried: no library, or the media is not a local file. true means the
     * library was asked; `persisted` says how it ended (false there: the media is not in the
     * library). It never blocks: the library works on its own thread.
     */
    Q_INVOKABLE bool persist(const QUrl& media, const QUrl& sub);

    /**
     * `pairs` is [{index: int, subtitle: QUrl, video: QUrl (optional)}] over the play queue. Each
     * subtitle is added to the media at `index` and saved for it. A pair with a bad index, an empty
     * subtitle, or a `video` that is not the media now at that index (the queue changed) is skipped.
     * Returns the number of subtitles added.
     */
    Q_INVOKABLE int attachToPlaylist(const QVariantList& pairs);

    //! the addresses of the media of the play queue (QUrl), in order
    Q_INVOKABLE QVariantList playlistUrls() const;

    /**
     * The native path of the folder of a local file ("" for anything else): where the file dialog
     * should open.
     */
    Q_INVOKABLE QString folderOf(const QUrl& media) const;

    /**
     * The videos and subtitle files of a folder (not its subfolders), by VLC's own extension lists:
     * {videos: [{name, url}], subtitles: [{name, url}], truncated: bool, error: QString}. Sorted by
     * name, case does not matter and numbers are compared as numbers (E2 before E10). At most
     * maxFolderEntries of each kind (`truncated` says some were left out). `error` is set (and the
     * lists empty) when the folder is not a readable local folder.
     */
    Q_INVOKABLE QVariantMap listFolder(const QUrl& folder) const;

    //! listFolder() with a limit, for the tests
    static QVariantMap listFolder(const QString& path, int limit);

    static QStringList videoExtensions();
    static QStringList subtitleExtensions();

public slots:
    /**
     * The media of the player changed (PlayerController::inputChanged): `mrl` is its address.
     * Looks for the subtitle files saved for it and adds those that are not there yet. Anything
     * still in flight for the previous media is dropped.
     */
    void onInputChanged(bool hasInput, const QString& mrl);

    //! Tries again to add a saved subtitle the player refused (it was not ready), once. To call when
    //! the media starts playing.
    void retryPending();

signals:
    //! persist() was answered: `stored` is whether the library saved the association
    void persisted(const QUrl& media, const QUrl& sub, bool stored);

private:
    //! a subtitle address in a form that compares equal whatever the way it was written
    static QString key(const QString& mrl);
    static QString encoded(const QUrl& url);
    void attachPending();

    SubtitleEnvironment m_env;
    std::unique_ptr<SubtitleStore> m_store;

    // the media being played, "" for none; bumped at every input change: answers of the store
    // for an older media are dropped
    QString m_currentMrl;
    quint64 m_generation = 0;
    //! the subtitle files (key()) already added to the media being played
    QSet<QString> m_attached;
    //! saved subtitle files the player refused, waiting for retryPending()
    QStringList m_pending;
    //! the saved subtitle (key()) that is shown when it is added: the last one saved for the media
    QString m_selectKey;
};

#endif
