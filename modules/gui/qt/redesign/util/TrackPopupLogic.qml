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
 * @brief Logic of the track popup (TrackPopup): which tabs exist and are usable, the tab and the
 * focus ring the keys move through, and where the popup is placed relative to its button.
 *
 * A tab is one of "subtitles", "audio", "video" (the string is what the buttons of the control
 * bar request through ShellActions.trackPopupRequested).
 */
QtObject {
    readonly property var tabs: ["subtitles", "audio", "video"]

    readonly property string defaultTab: "subtitles"

    // `tab` if it is one of the tabs, else the default tab
    function normalized(tab: string): string {
        return tabs.includes(tab) ? tab : defaultTab
    }

    // Which tabs can be used. The subtitles tab always can: "Add subtitles..." is its action,
    // useful exactly when the media has no subtitle track. The audio tab has the audio tracks
    // and the output devices, the video tab only the video tracks (an audio only media has none).
    function enabledTabs(audioTracks: int, audioDevices: int, videoTracks: int): var {
        return {
            "subtitles": true,
            "audio": (audioTracks > 0) || (audioDevices > 0),
            "video": videoTracks > 0
        }
    }

    // The tab to show when `requested` is asked for: itself, else the first usable tab.
    function resolveTab(requested: string, enabled: var): string {
        const tab = normalized(requested)
        if (enabled[tab])
            return tab
        return tabs.find(t => enabled[t]) ?? defaultTab
    }

    // The usable tab `step` (+1 or -1) places away from `current`, without wrapping; `current`
    // itself when there is none.
    function stepTab(current: string, step: int, enabled: var): string {
        let i = tabs.indexOf(normalized(current)) + step
        while (i >= 0 && i < tabs.length) {
            if (enabled[tabs[i]])
                return tabs[i]
            i += step
        }
        return normalized(current)
    }

    // The index `step` (+1 or -1) places away from `index` in a ring of `count` entries (the
    // entries Tab visits), -1 for an empty ring.
    function ringStep(index: int, count: int, step: int): int {
        if (count <= 0)
            return -1
        if (index < 0)
            return step > 0 ? 0 : count - 1
        return (index + step + count) % count
    }

    // Top left of a popup of `width` x `height` placed above the button at (`anchorX`,
    // `anchorY`) of size `anchorWidth` x `anchorHeight`, `gap` away from it, horizontally
    // centred on it, `margin` away from the edges of the area of `areaWidth` x `areaHeight`.
    // When there is no room above it goes below the button, else it sticks to the top edge.
    function place(anchorX: real, anchorY: real, anchorWidth: real, anchorHeight: real,
                   width: real, height: real, areaWidth: real, areaHeight: real,
                   gap: real, margin: real): point {
        const maxX = Math.max(margin, areaWidth - width - margin)
        const x = Math.min(maxX, Math.max(margin, anchorX + anchorWidth / 2 - width / 2))

        let y = anchorY - gap - height
        if (y < margin) {
            const below = anchorY + anchorHeight + gap
            y = (below + height + margin <= areaHeight) ? below : margin
        }
        return Qt.point(x, y)
    }
}
