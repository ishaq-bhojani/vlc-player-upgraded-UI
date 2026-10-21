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

/**
 * @brief Pairs the videos of a folder or of the queue with their subtitle files, by name.
 *
 * No library or file access: it only works on names (file names with their extension). A subtitle
 * belongs to a video when their base names are equal, the case does not matter. The base name of a
 * file is its name without the last extension; a subtitle may also carry a language after the base
 * name ("Show.S01E01.en.srt": 2 or 3 letters between dots), which is then not part of the base
 * name. A subtitle matches its video with or without that cut, so a video called "A.Film.TV.mkv"
 * still finds "A.Film.TV.srt".
 */
QtObject {
    // Functions

    //! `name` without its last extension ("a.b.mkv" -> "a.b"); a name without a dot is kept
    function baseName(name) {
        const text = String(name ?? "")
        const dot = text.lastIndexOf(".")
        return dot > 0 ? text.substring(0, dot) : text
    }

    //! the name of the file a path or an address points to, decoded ("file:///C:/a%20b/c.mkv" ->
    //! "c.mkv"); "" for nothing
    function fileName(location) {
        let text = String(location ?? "")
        if (text === "")
            return ""

        // an address (two letters or more before "://": "C:\a" is a path)
        const isUrl = /^[A-Za-z][A-Za-z0-9+.\-]+:\/\//.test(text)
        if (isUrl)
            text = text.replace(/[?#].*$/, "")

        const name = text.split(/[\\/]/).pop()
        if (!isUrl)
            return name

        try {
            return decodeURIComponent(name)
        } catch (e) {
            return name
        }
    }

    //! the base names a subtitle can be known by: without its extension, and without the language
    function _subtitleKeys(subtitle) {
        const base = baseName(subtitle).toLowerCase()
        const keys = [base]
        const withoutLanguage = base.replace(/\.[a-z]{2,3}$/, "")
        if (withoutLanguage !== base)
            keys.push(withoutLanguage)
        return keys
    }

    /**
     * Pairs each video with a subtitle.
     *
     * `videoNames` and `subtitleNames` are lists of file names. Returns [{video, subtitle}] in the
     * order of `videoNames`; `subtitle` is "" when none matches. When several subtitles match a
     * video (two languages), the first one of `subtitleNames` is taken. A subtitle can serve
     * several videos only when they have the same base name.
     */
    function pair(videoNames, subtitleNames) {
        const videos = videoNames ?? []
        const subtitles = (subtitleNames ?? []).map(name => ({name: name, keys: _subtitleKeys(name)}))

        return videos.map(video => {
            const wanted = baseName(video).toLowerCase()
            const found = subtitles.find(subtitle => subtitle.keys.includes(wanted))
            return {video: video, subtitle: found ? found.name : ""}
        })
    }
}
