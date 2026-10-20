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

#include "sidecarlyrics.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QVariantMap>

SidecarLyrics::SidecarLyrics(QObject* parent)
    : QObject(parent)
{
}

QString SidecarLyrics::sidecarPath(const QUrl& media)
{
    if (!media.isLocalFile())
        return {};

    const QFileInfo audio(media.toLocalFile());
    const QString base = audio.completeBaseName();
    if (base.isEmpty())
        return {};

    const QDir dir = audio.dir();

    // Windows and macOS file systems ignore the case of a name: ".lrc" finds ".LRC". Elsewhere the
    // usual spellings are probed one by one (no directory listing).
#if defined(Q_OS_WIN) || defined(Q_OS_MACOS)
    const QStringList extensions = { QStringLiteral(".lrc") };
#else
    const QStringList extensions = { QStringLiteral(".lrc"), QStringLiteral(".LRC"),
                                     QStringLiteral(".Lrc") };
#endif
    for (const QString& extension : extensions) {
        const QFileInfo candidate(dir.filePath(base + extension));
        if (candidate.isFile())
            return candidate.filePath();
    }
    return {};
}

void SidecarLyrics::setMedia(const QUrl& media)
{
    if (m_media == media)
        return;
    m_media = media;
    emit mediaChanged();

    QVector<LrcLine> lines;
    const QString path = sidecarPath(media);
    if (!path.isEmpty() && QFileInfo(path).size() <= maxFileSize) {
        QFile file(path);
        if (file.open(QIODevice::ReadOnly)) {
            // one more byte than allowed, in case the file grew after the size check
            const QByteArray data = file.read(maxFileSize + 1);
            if (data.size() <= maxFileSize)
                lines = redesign::parseLrc(redesign::decodeLrc(data));
        }
    }

    const bool wasAvailable = available();
    m_lines = lines;

    QVariantList variants;
    variants.reserve(m_lines.size());
    for (const LrcLine& l : std::as_const(m_lines)) {
        QVariantMap m;
        m.insert(QStringLiteral("timeMs"), l.timeMs);
        m.insert(QStringLiteral("text"), l.text);
        variants.append(m);
    }
    m_variantLines = variants;

    emit linesChanged();
    if (wasAvailable != available())
        emit availableChanged();
}

int SidecarLyrics::indexAt(qint64 ms) const
{
    return redesign::lineIndexAt(m_lines, ms);
}

int SidecarLyrics::indexAtTime(const VLCTime& time) const
{
    if (!time.valid())
        return -1;
    return indexAt(time.toMilliseconds());
}
