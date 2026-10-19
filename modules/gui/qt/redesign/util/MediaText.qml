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
}
