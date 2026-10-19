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
import QtCore as QtCore

/**
 * @brief The items pinned to the rail: folders, playlists and streams, in insertion order.
 *
 * An entry is `{id, kind, label, target}`: `kind` is "folder", "playlist" or "stream", `target`
 * is a URL for a folder or a stream, and the id of the media library for a playlist (as a
 * string). Pinning the same `kind` and `target` again does not add a second entry.
 *
 * The pins are stored as a JSON string in the settings (category "redesign"). A stored string
 * that cannot be read gives an empty store, it never throws.
 */
QtObject {
    id: store

    // the pinned items, to bind to. Read it, do not modify it: use pin(), unpin() and move()
    property var items: []

    // false: the settings are neither read nor written (tests)
    property bool persistent: true

    readonly property var kinds: ["folder", "playlist", "stream"]

    // a copy of the pinned items, in order
    function pins(): var {
        return JSON.parse(serialized())
    }

    // Pins target and returns the id of its entry. Pinning a kind and target that are already
    // pinned returns the existing id. Returns "" if kind or target are invalid.
    function pin(kind: string, label: string, target: string): string {
        if (kinds.indexOf(kind) < 0 || !target)
            return ""

        const existing = _find(kind, target)
        if (existing >= 0)
            return items[existing].id

        const id = _newId()
        _commit(items.concat([{ id: id, kind: kind, label: label || target, target: target }]))
        return id
    }

    function unpin(id: string) {
        const index = _indexOfId(id)
        if (index < 0)
            return

        const copy = items.slice()
        copy.splice(index, 1)
        _commit(copy)
    }

    // Moves the entry id to toIndex (clamped to the valid range).
    function move(id: string, toIndex: int) {
        const from = _indexOfId(id)
        if (from < 0)
            return

        const to = Math.max(0, Math.min(items.length - 1, toIndex))
        if (to === from)
            return

        const copy = items.slice()
        copy.splice(to, 0, copy.splice(from, 1)[0])
        _commit(copy)
    }

    function isPinned(kind: string, target: string): bool {
        return _find(kind, target) >= 0
    }

    // the JSON string that is stored in the settings
    function serialized(): string {
        return JSON.stringify(items)
    }

    // Replaces the content by what the stored string raw describes. Invalid entries are
    // dropped, and an unreadable string gives an empty store.
    function reset(raw: string) {
        _commit(_parse(raw))
    }

    // Private

    function _parse(raw: string): var {
        let parsed = null
        try {
            parsed = JSON.parse(raw)
        } catch (e) {
            return []
        }
        if (!Array.isArray(parsed))
            return []

        const result = []
        const seen = {}
        for (const entry of parsed) {
            if (!entry || typeof entry !== "object"
                    || typeof entry.id !== "string" || !entry.id
                    || kinds.indexOf(entry.kind) < 0
                    || typeof entry.label !== "string"
                    || typeof entry.target !== "string" || !entry.target
                    || seen[entry.id])
                continue
            seen[entry.id] = true
            result.push({ id: entry.id, kind: entry.kind, label: entry.label, target: entry.target })
        }
        return result
    }

    function _find(kind: string, target: string): int {
        return items.findIndex(function (item) { return item.kind === kind && item.target === target })
    }

    function _indexOfId(id: string): int {
        return items.findIndex(function (item) { return item.id === id })
    }

    function _newId(): string {
        let id
        do {
            id = Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
        } while (_indexOfId(id) >= 0)
        return id
    }

    function _commit(newItems: var) {
        items = newItems
        if (persistent && settings.pins !== serialized())
            settings.pins = serialized()
    }

    readonly property QtCore.Settings _settings: QtCore.Settings {
        id: settings

        category: "redesign"

        property string pins: "[]"
    }

    Component.onCompleted: {
        if (persistent)
            items = _parse(settings.pins)
    }
}
