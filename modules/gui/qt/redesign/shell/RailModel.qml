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
import QtQml

/**
 * @brief Entries of the rail (the left icon column of the window) and their mapping
 * to the navigation paths of History.
 *
 * `icon` is the name of a VLCIcons glyph (resolved by Rail.qml with VLCIcons[icon]), so
 * that the glyph set can change without touching the model.
 *
 * Without a media library only the network browser and the "add" action are offered, and
 * no pinned playlist.
 */
QtObject {
    id: railModel

    // whether the media library is available (MainCtx.mediaLibraryAvailable)
    property bool hasMediaLibrary: true

    // all entries, in the order of the design. `add` is an action (empty path), not a view.
    readonly property var items: [
        { id: "home", path: ["home"], icon: "home", label: qsTr("Home"), requiresML: true },
        { id: "video", path: ["video"], icon: "topbar_video", label: qsTr("Videos"), requiresML: true },
        { id: "music", path: ["music"], icon: "topbar_music", label: qsTr("Music"), requiresML: true },
        { id: "network", path: ["network"], icon: "topbar_network", label: qsTr("Network"), requiresML: false },
        { id: "playlists", path: ["video", "playlists"], icon: "playlist", label: qsTr("Playlists"), requiresML: true },
        { id: "recent", path: ["home", "recent"], icon: "history", label: qsTr("Recent"), requiresML: true },
        { id: "add", path: [], icon: "add", label: qsTr("Add item"), requiresML: false }
    ]

    // the entries to show, depending on hasMediaLibrary
    function visibleItems(): var {
        const ml = hasMediaLibrary
        return items.filter(function (item) { return ml || !item.requiresML })
    }

    // The pins (entries of PinStore) to show: a playlist is stored in the media library, so
    // it needs the library like the entries with requiresML.
    function visiblePins(pins: var): var {
        const ml = hasMediaLibrary
        return pins.filter(function (pin) { return ml || pin.kind !== "playlist" })
    }

    // Index in `items` of the visible entry whose path is the longest prefix of viewPath,
    // -1 if there is none (or viewPath is not an array). Entries without a path (actions)
    // never match.
    function indexForPath(viewPath: var): int {
        if (!viewPath)
            return -1
        let best = -1
        let bestLength = 0
        const visible = visibleItems()
        for (let i = 0; i < visible.length; ++i) {
            const path = visible[i].path
            if (path.length === 0 || path.length <= bestLength || path.length > viewPath.length)
                continue
            let match = true
            for (let j = 0; j < path.length; ++j) {
                if (path[j] !== viewPath[j]) {
                    match = false
                    break
                }
            }
            if (match) {
                best = items.indexOf(visible[i])
                bestLength = path.length
            }
        }
        return best
    }

    // id of the entry to highlight for viewPath, "" if there is none. Compare ids, not
    // objects: delegates of a Repeater get copies of the entries.
    function selectedId(viewPath: var): string {
        const index = indexForPath(viewPath)
        return index >= 0 ? items[index].id : ""
    }

    // path to show on startup
    function defaultPath(): var {
        return hasMediaLibrary ? ["home"] : ["network"]
    }
}
