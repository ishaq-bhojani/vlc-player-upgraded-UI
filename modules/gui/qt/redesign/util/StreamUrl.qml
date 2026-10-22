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

/**
 * @brief Turns what the user typed or pasted in a "network stream" field into the address to play.
 *
 * No library or network access: it only decides what text VLC is given.
 */
QtObject {
    // the schemes VLC opens as streams or remote files: kept as they are, with or without the `//`
    // ("udp:@239.0.0.1:1234", "file:/x"); any other `scheme://` is kept too
    readonly property var knownSchemes: [
        "http", "https", "rtsp", "rtmp", "udp", "rtp", "mms", "smb", "ftp", "sftp", "file"
    ]

    // schemes that have no `//` and are not streams of the list above
    readonly property var otherSchemes: ["magnet"]

    // true when `line` starts with one of the schemes followed by a colon (case does not matter)
    function _startsWithScheme(line, schemes) {
        const lower = line.toLowerCase()
        return schemes.some(scheme => lower.startsWith(scheme + ":"))
    }

    // The first line of `text` that has something in it, trimmed ("" when there is none): a pasted
    // block of text plays its first address.
    function firstLine(text) {
        if (text === undefined || text === null)
            return ""
        for (const line of String(text).split(/\r\n|[\r\n\u2028\u2029]/)) {
            const trimmed = line.trim()
            if (trimmed !== "")
                return trimmed
        }
        return ""
    }

    // The address to play for `text`, "" when there is nothing to play.
    //  - the first non-empty line, trimmed
    //  - kept as it is when it has a scheme (`xxx://`, or a known one without the `//`) or is a local
    //    path (a drive letter, a network share, `/x`)
    //  - gets "https://" when it has a dot ("example.org/a.m3u8")
    //  - kept as it is otherwise ("hello")
    function normalize(text) {
        const line = firstLine(text)
        if (line === "")
            return ""

        if (/^[A-Za-z][A-Za-z0-9+.\-]*:\/\//.test(line))
            return line

        // "udp:@239.0.0.1:1234", "file:/x", "magnet:?xt=..."
        if (_startsWithScheme(line, knownSchemes) || _startsWithScheme(line, otherSchemes))
            return line

        // a local file: a drive letter ("C:\a.mp4", "C:/a.mp4"), a network share or an absolute path
        if (/^[A-Za-z]:[\\/]/.test(line) || line.startsWith("\\\\") || line.startsWith("/"))
            return line

        if (line.includes("."))
            return "https://" + line

        return line
    }

    function isValid(text) {
        return normalize(text) !== ""
    }
}
