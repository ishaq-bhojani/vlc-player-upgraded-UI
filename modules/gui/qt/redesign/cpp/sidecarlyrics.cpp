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

    // the usual spelling first, without listing the directory
    const QFileInfo direct(dir.filePath(base + QStringLiteral(".lrc")));
    if (direct.isFile())
        return direct.filePath();

    // ".LRC", ".Lrc": the extension is matched without case, whatever the file system
    const QFileInfoList files = dir.entryInfoList(QDir::Files | QDir::Readable | QDir::NoDotAndDotDot);
    for (const QFileInfo& f : files) {
        if (f.completeBaseName() == base
            && f.suffix().compare(QLatin1String("lrc"), Qt::CaseInsensitive) == 0)
            return f.filePath();
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
