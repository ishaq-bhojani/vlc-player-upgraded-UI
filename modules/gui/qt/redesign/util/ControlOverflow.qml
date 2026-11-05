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

// Decision logic of the overflow button of the control bar, kept apart from the bar so it can be
// tested. The bar hides the controls that do not fit its width (ControlRepeater); the overflow
// menu gives them back as menu entries.
QtObject {
    // the entry of the overflow menu that stands for a control, by the file of the control
    readonly property var _kinds: ({
        "ConeVolumeSlider.qml": "mute",
        "SubtitlePopupButton.qml": "subtitles",
        "AudioPopupButton.qml": "audio",
        "SidebarButton.qml": "settings",
        "QueueButton.qml": "queue",
        "FullscreenButton.qml": "fullscreen"
    })

    // The entries for the controls that are hidden, in the order of the bar, each once. `sources` are
    // the urls (or paths) of the files of the hidden controls; a control without an entry (the seek
    // bar, a control of a custom profile) has none.
    function kinds(sources: var): var {
        const out = []
        for (const source of sources) {
            const kind = _kinds[String(source).split("/").pop()]
            if (kind !== undefined && out.indexOf(kind) < 0)
                out.push(kind)
        }
        return out
    }
}
