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

#include "subtitleattacher.hpp"

#include <algorithm>

#include <QCollator>
#include <QDir>
#include <QFileInfo>
#include <QList>
#include <QMetaObject>
#include <QPointer>
#include <QThreadPool>

#include <vlc_common.h>
#include <vlc_interface.h>

namespace
{

//! "*.mkv;*.mp4" -> ["mkv", "mp4"]
QStringList extensionsOf(const char* patterns)
{
    QStringList list;
    for (QString pattern : QString::fromLatin1(patterns).split(';', Qt::SkipEmptyParts))
    {
        pattern = pattern.trimmed().toLower();
        if (pattern.startsWith(QLatin1String("*.")))
            pattern.remove(0, 2);
        if (!pattern.isEmpty() && !list.contains(pattern))
            list.append(pattern);
    }
    return list;
}

bool isLocal(const QString& mrl)
{
    return QUrl(mrl).scheme().compare(QLatin1String("file"), Qt::CaseInsensitive) == 0;
}

QVariantMap entryOf(const QFileInfo& file)
{
    return {
        {QStringLiteral("name"), file.fileName()},
        {QStringLiteral("url"), QUrl::fromLocalFile(file.absoluteFilePath())},
    };
}

} // namespace

SubtitleAttacher::SubtitleAttacher(QObject* parent)
    : QObject(parent)
{
}

void SubtitleAttacher::setEnvironment(SubtitleEnvironment environment)
{
    m_env = std::move(environment);
}

void SubtitleAttacher::setStore(std::unique_ptr<SubtitleStore> store)
{
    m_store = std::move(store);
}

QString SubtitleAttacher::encoded(const QUrl& url)
{
    return QString::fromUtf8(url.toEncoded());
}

QString SubtitleAttacher::key(const QString& mrl)
{
    return encoded(QUrl(mrl));
}

QStringList SubtitleAttacher::videoExtensions()
{
    static const QStringList list = extensionsOf(EXTENSIONS_VIDEO);
    return list;
}

QStringList SubtitleAttacher::subtitleExtensions()
{
    static const QStringList list = extensionsOf(EXTENSIONS_SUBTITLE);
    return list;
}

bool SubtitleAttacher::attachToCurrent(const QUrl& sub)
{
    if (!sub.isValid() || sub.isEmpty() || !m_env.addToCurrent)
        return false;

    const QString mrl = encoded(sub);
    if (!m_env.addToCurrent(mrl, true, true))
        return false;

    m_attached.insert(key(mrl));
    // a late answer of the library for this media must not add it again
    m_pending.removeIf([&](const QString& pending) { return key(pending) == key(mrl); });

    if (!m_currentMrl.isEmpty())
        persist(QUrl(m_currentMrl), sub);
    return true;
}

bool SubtitleAttacher::persist(const QUrl& media, const QUrl& sub)
{
    if (!m_store || media.isEmpty() || sub.isEmpty() || !media.isLocalFile())
        return false;

    m_store->add(encoded(media), encoded(sub), [this, media, sub](bool stored)
    {
        emit persisted(media, sub, stored);
    });
    return true;
}

int SubtitleAttacher::attachToPlaylist(const QVariantList& pairs)
{
    if (!m_env.addToQueueItem || !m_env.queueUrls)
        return 0;

    const QStringList queue = m_env.queueUrls();
    int attached = 0;

    for (const QVariant& value : pairs)
    {
        const QVariantMap pair = value.toMap();
        bool isInt = false;
        const int index = pair.value(QStringLiteral("index")).toInt(&isInt);
        const QUrl sub = pair.value(QStringLiteral("subtitle")).toUrl();
        if (!isInt || index < 0 || index >= queue.size() || sub.isEmpty())
            continue;

        // the queue may have changed since the pair was made: the media must still be the same
        const QUrl expected = pair.value(QStringLiteral("video")).toUrl();
        if (!expected.isEmpty() && key(queue[index]) != encoded(expected))
            continue;

        if (!m_env.addToQueueItem(index, encoded(sub)))
            continue;
        ++attached;

        // when the item is the media being played, the environment added it to the player as
        // well: the answer of the library must not add it a second time
        if (key(queue[index]) == key(m_currentMrl))
            m_attached.insert(key(encoded(sub)));

        persist(QUrl(queue[index]), sub);
    }
    return attached;
}

QVariantList SubtitleAttacher::playlistUrls() const
{
    QVariantList urls;
    if (!m_env.queueUrls)
        return urls;
    for (const QString& mrl : m_env.queueUrls())
        urls.append(QUrl(mrl));
    return urls;
}

QString SubtitleAttacher::folderOf(const QUrl& media) const
{
    if (!media.isLocalFile())
        return QString();
    return QFileInfo(media.toLocalFile()).absolutePath();
}

namespace
{
QVariantMap folderError(const QString& text)
{
    return {
        {QStringLiteral("videos"), QVariantList()},
        {QStringLiteral("subtitles"), QVariantList()},
        {QStringLiteral("truncated"), false},
        {QStringLiteral("error"), text},
    };
}
}

QVariantMap SubtitleAttacher::listFolder(const QUrl& folder) const
{
    if (!folder.isLocalFile())
        return folderError(tr("Only a folder of this computer can be used."));
    return listFolder(folder.toLocalFile(), maxFolderEntries);
}

int SubtitleAttacher::requestFolder(const QUrl& folder)
{
    const int id = ++m_folderRequest;
    const QPointer<SubtitleAttacher> self(this);
    const auto answer = [self, id](QVariantMap result)
    {
        if (!self)
            return;
        // a queued call, so the answer always comes on the thread of the attacher, and never
        // before requestFolder() has returned
        QMetaObject::invokeMethod(self.data(), [self, id, result = std::move(result)]
        {
            if (self)
                emit self->folderListed(id, result);
        }, Qt::QueuedConnection);
    };

    if (!folder.isLocalFile())
    {
        answer(folderError(tr("Only a folder of this computer can be used.")));
        return id;
    }

    QThreadPool::globalInstance()->start([path = folder.toLocalFile(), answer]
    {
        answer(listFolder(path, maxFolderEntries));
    });
    return id;
}

QVariantMap SubtitleAttacher::listFolder(const QString& path, int limit)
{
    QVariantMap result {
        {QStringLiteral("videos"), QVariantList()},
        {QStringLiteral("subtitles"), QVariantList()},
        {QStringLiteral("truncated"), false},
        {QStringLiteral("error"), QString()},
    };

    const QDir dir(path);
    if (path.isEmpty() || !dir.exists() || !QFileInfo(path).isReadable())
    {
        result[QStringLiteral("error")] = tr("The folder can not be read.");
        return result;
    }

    const QStringList videoExt = videoExtensions();
    const QStringList subtitleExt = subtitleExtensions();

    QFileInfoList videos;
    QFileInfoList subtitles;
    const QFileInfoList files = dir.entryInfoList(QDir::Files | QDir::Readable | QDir::NoDotAndDotDot, QDir::NoSort);
    for (const QFileInfo& file : files)
    {
        const QString ext = file.suffix().toLower();
        if (videoExt.contains(ext))
            videos.append(file);
        else if (subtitleExt.contains(ext))
            subtitles.append(file);
    }

    // "S01E2" before "S01E10", "a" and "A" together
    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    const auto byName = [&collator](const QFileInfo& a, const QFileInfo& b)
    {
        const int order = collator.compare(a.fileName(), b.fileName());
        return order != 0 ? order < 0 : a.fileName() < b.fileName();
    };
    std::sort(videos.begin(), videos.end(), byName);
    std::sort(subtitles.begin(), subtitles.end(), byName);

    bool truncated = false;
    const auto fill = [&](const QFileInfoList& sorted, const QString& name)
    {
        QVariantList list;
        for (const QFileInfo& file : sorted)
        {
            if (list.size() >= limit)
            {
                truncated = true;
                break;
            }
            list.append(entryOf(file));
        }
        result[name] = list;
    };
    fill(videos, QStringLiteral("videos"));
    fill(subtitles, QStringLiteral("subtitles"));
    result[QStringLiteral("truncated")] = truncated;
    return result;
}

void SubtitleAttacher::onInputChanged(bool hasInput, const QString& mrl)
{
    // whatever was in flight belonged to the previous media
    const quint64 generation = ++m_generation;
    m_attached.clear();
    m_pending.clear();
    m_selectKey.clear();
    m_playing = false;
    m_currentMrl = hasInput ? mrl : QString();

    // no library, nothing to bring back; only local files can be in it
    if (!hasInput || !m_store || mrl.isEmpty() || !isLocal(mrl))
        return;

    m_store->subtitles(mrl, [this, generation](QStringList saved)
    {
        if (generation != m_generation)
            return;
        for (const QString& sub : saved)
        {
            if (!m_attached.contains(key(sub)) && !m_pending.contains(sub))
                m_pending.append(sub);
        }
        // the library lists the files in the order they were saved
        if (!m_pending.isEmpty())
            m_selectKey = key(m_pending.last());
        attachPending();
    });
}

void SubtitleAttacher::onPlaying()
{
    if (m_currentMrl.isEmpty())
        return;
    m_playing = true;
    attachPending();
}

// Adds what waits once the media plays; what the player refuses stays for the next onPlaying().
// Silent; only the last subtitle saved for the media is selected (m_selectKey), the others join
// the list of tracks.
void SubtitleAttacher::attachPending()
{
    if (!m_env.addToCurrent || !m_playing || m_pending.isEmpty())
        return;

    // what the item has by now (read after the input loaded its slaves, and fresh at every call)
    QSet<QString> present;
    if (m_env.currentSlaves)
    {
        for (const QString& slave : m_env.currentSlaves())
            present.insert(key(slave));
    }

    QStringList refused;
    for (const QString& sub : std::as_const(m_pending))
    {
        if (m_attached.contains(key(sub)))
            continue;
        if (present.contains(key(sub)))
        {
            m_attached.insert(key(sub));
            continue;
        }
        if (m_env.addToCurrent(sub, key(sub) == m_selectKey, false))
            m_attached.insert(key(sub));
        else
            refused.append(sub);
    }
    m_pending = refused;
}
