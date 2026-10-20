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
#ifndef VLC_QT_REDESIGN_SIDECARLYRICS_HPP
#define VLC_QT_REDESIGN_SIDECARLYRICS_HPP

#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantList>
#include <QVector>

#include "lrcparser.hpp"
#include "util/vlctick.hpp"

/**
 * @brief The synced lyrics of a local audio file, from the ".lrc" file next to it.
 *
 * For `<dir>/<name>.<ext>` the file is `<dir>/<name>.lrc` (the extension is matched without
 * case). Only local files are looked at, the file is read once when `media` is set (it is not
 * watched), a file bigger than maxFileSize is ignored, and a file that is not valid UTF-8 is read
 * as Latin-1.
 *
 * QML type SidecarLyrics of VLC.Redesign (registered in redesign/cpp/qmlregistration.cpp).
 */
class SidecarLyrics : public QObject
{
    Q_OBJECT

    //! the URL of the audio file; setting it (re)loads the lyrics
    Q_PROPERTY(QUrl media READ media WRITE setMedia NOTIFY mediaChanged FINAL)
    //! [{timeMs, text}], sorted by time
    Q_PROPERTY(QVariantList lines READ lines NOTIFY linesChanged FINAL)
    //! there is at least one line
    Q_PROPERTY(bool available READ available NOTIFY availableChanged FINAL)

public:
    //! a bigger .lrc file is not read
    static constexpr qint64 maxFileSize = 1024 * 1024;

    explicit SidecarLyrics(QObject* parent = nullptr);

    QUrl media() const { return m_media; }
    void setMedia(const QUrl& media);

    QVariantList lines() const { return m_variantLines; }
    bool available() const { return !m_lines.isEmpty(); }

    //! the index of the line to show at `ms` into the track, -1 before the first line
    Q_INVOKABLE int indexAt(qint64 ms) const;

    //! same for a Player.time (it counts from VLC_TICK_0, an invalid time gives -1)
    Q_INVOKABLE int indexAtTime(const VLCTime& time) const;

    //! the .lrc file next to `media`, empty when media is not a local file or there is none
    static QString sidecarPath(const QUrl& media);

signals:
    void mediaChanged();
    void linesChanged();
    void availableChanged();

private:
    QUrl m_media;
    QVector<LrcLine> m_lines;
    QVariantList m_variantLines;
};

#endif
