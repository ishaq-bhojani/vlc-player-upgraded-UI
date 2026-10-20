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
#ifndef VLC_QT_REDESIGN_LRCPARSER_HPP
#define VLC_QT_REDESIGN_LRCPARSER_HPP

#include <QByteArray>
#include <QString>
#include <QVector>

/**
 * One line of a synced lyrics file (".lrc"), at `timeMs` milliseconds into the track.
 */
struct LrcLine
{
    qint64 timeMs = 0;
    QString text;
};

namespace redesign
{

//! more lines than this in a file are dropped (a bigger file is not lyrics)
constexpr int kMaxLrcLines = 10000;
//! the text of a line is cut at this length
constexpr int kMaxLrcLineChars = 1000;

/**
 * Parse the text of an .lrc file.
 *
 * - "[mm:ss]", "[mm:ss.x]", "[mm:ss.xx]" and "[mm:ss.xxx]" stamps; several stamps on one line
 *   give one entry each, with the same text.
 * - "[offset:N]" (milliseconds, anywhere in the file) shifts every line N ms earlier (a negative
 *   N later); the result is never below 0.
 * - the other tags ([ar:], [ti:], [al:], [by:], ...) and malformed stamps are ignored; a line
 *   without any valid stamp is skipped.
 * - a stamp with no text is kept (empty text): it ends the previous line.
 * - the word stamps of enhanced LRC ("<mm:ss.xx>") are removed from the text.
 * - the result is sorted by time (lines with the same time keep the file order), at most
 *   kMaxLrcLines entries.
 */
QVector<LrcLine> parseLrc(const QString& content);

//! the index of the last line with `timeMs <= ms`, -1 before the first line (or without lines)
int lineIndexAt(const QVector<LrcLine>& lines, qint64 ms);

/**
 * Text of the bytes of an .lrc file: UTF-8 (a BOM is removed), or Latin-1 when the bytes are
 * not valid UTF-8.
 */
QString decodeLrc(const QByteArray& data);

} // namespace redesign

#endif
