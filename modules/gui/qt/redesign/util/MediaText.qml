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
pragma Singleton
import QtQml

// Text helpers of the media name labels in the control bar.
QtObject {
    function _decode(s: string): string {
        try {
            return decodeURIComponent(s)
        } catch (e) {
            // malformed escape sequence: show the raw text
            return s
        }
    }

    // path components of a URL, without scheme, authority, query and fragment
    function _pathParts(url: string): var {
        const noQuery = url.split(/[?#]/)[0]
        const authorityAt = noQuery.indexOf("//")
        const path = (authorityAt >= 0) ? noQuery.slice(authorityAt + 2) : noQuery
        return path.split("/").filter(function (part) { return part !== "" })
    }

    // Last directory component of a file:// URL, "" for any other URL.
    function folderName(url: string): string {
        if (!url || url.slice(0, 7).toLowerCase() !== "file://")
            return ""

        const parts = _pathParts(url)
        // the first part of a "file://host/..." URL is the host, not a folder
        const hasHost = !/^file:\/\/\//i.test(url)
        const folders = parts.slice(hasHost ? 1 : 0, -1)
        return (folders.length > 0) ? _decode(folders[folders.length - 1]) : ""
    }

    // First non-empty of title, name, then the file name of the URL.
    function titleText(title: string, name: string, url: string): string {
        if (title && title.trim() !== "")
            return title
        if (name && name.trim() !== "")
            return name
        if (!url)
            return ""

        const parts = _pathParts(url)
        return (parts.length > 0) ? _decode(parts[parts.length - 1]) : ""
    }

    // "<title> - <artist>": the title as in titleText, then the artist unless it is empty or the
    // title already starts with "<artist> - " (case-insensitive, e.g. a file name "Artist - Song.mp3").
    function captionText(title: string, name: string, url: string, artist: string): string {
        const resolved = titleText(title, name, url)
        const who = artist ? artist.trim() : ""
        if (who === "")
            return resolved
        if (resolved === "")
            return who
        if (resolved.toLowerCase().indexOf(who.toLowerCase() + " - ") === 0)
            return resolved
        return qsTr("%1 - %2").arg(resolved).arg(who)
    }

    // Durations of a VLCTick (anything with valid() and toSeconds()). Whole seconds are truncated,
    // like VLCTick.formatHMS, so that every view shows the same text for a file. A duration that
    // is unknown or not positive (a folder, a group) gives "", never "0 ms" or "-1 ms".
    function _seconds(tick): int {
        if (!tick || typeof tick.valid !== "function" || !tick.valid())
            return 0
        return Math.max(0, tick.toSeconds())
    }

    function _pad(n: int): string {
        return (n < 10 ? "0" : "") + n
    }

    // "mm:ss", "hh:mm:ss" from one hour
    function durationText(tick): string {
        const total = _seconds(tick)
        if (total <= 0)
            return ""
        const h = Math.floor(total / 3600)
        const m = Math.floor(total / 60) % 60
        const s = total % 60
        return (h > 0 ? _pad(h) + ":" : "") + _pad(m) + ":" + _pad(s)
    }

    // "mm:ss", "1h05" from one hour (the narrow column of the details view)
    function durationShortText(tick): string {
        const total = _seconds(tick)
        if (total < 3600)
            return durationText(tick)
        return Math.floor(total / 3600) + "h" + _pad(Math.floor(total / 60) % 60)
    }

    // "20 sec", "1 min 5 sec", "1 h 2 min" (the total of the queue)
    function durationLongText(tick): string {
        const total = _seconds(tick)
        if (total <= 0)
            return ""
        if (total >= 3600)
            return qsTr("%1 h %2 min").arg(Math.floor(total / 3600)).arg(Math.floor(total / 60) % 60)
        if (total >= 60)
            return qsTr("%1 min %2 sec").arg(Math.floor(total / 60)).arg(total % 60)
        return qsTr("%1 sec").arg(total)
    }
}
