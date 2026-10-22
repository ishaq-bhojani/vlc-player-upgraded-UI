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
import QtQuick
import QtTest
import VLC.Redesign

TestCase {
    id: testCase
    name: "RailModel"

    RailModel {
        id: rail
    }

    function test_noML() {
        rail.hasMediaLibrary = false
        compare(rail.visibleItems().map(i => i.id), ["network", "add"])
        compare(rail.defaultPath(), ["network"])
        // views of the media library are not part of the rail
        compare(rail.indexForPath(["home"]), -1)
        compare(rail.items[rail.indexForPath(["network", "foo"])].id, "network")
    }

    function test_withML() {
        rail.hasMediaLibrary = true
        compare(rail.visibleItems().map(i => i.id),
                ["home", "video", "music", "network", "playlists", "recent", "add"])
        compare(rail.defaultPath(), ["home"])
    }

    function test_selectedId() {
        rail.hasMediaLibrary = true
        compare(rail.selectedId(["video", "playlists", "all"]), "playlists")
        compare(rail.selectedId(["mlsettings"]), "")
        rail.hasMediaLibrary = false
        compare(rail.selectedId(["home"]), "")
        compare(rail.selectedId(["network"]), "network")
    }

    function test_requiresML() {
        compare(rail.items.filter(i => i.requiresML).map(i => i.id),
                ["home", "video", "music", "playlists", "recent"])
    }

    function test_visiblePins() {
        const pins = [
            { id: "a", kind: "folder", label: "A", target: "file:///a" },
            { id: "b", kind: "playlist", label: "B", target: "VLC_ML_PARENT_PLAYLIST - 1" },
            { id: "c", kind: "stream", label: "C", target: "http://c" }
        ]
        rail.hasMediaLibrary = true
        compare(rail.visiblePins(pins).map(p => p.id), ["a", "b", "c"])
        rail.hasMediaLibrary = false
        compare(rail.visiblePins(pins).map(p => p.id), ["a", "c"])
        compare(rail.visiblePins([]), [])
    }

    function test_index() {
        rail.hasMediaLibrary = true
        compare(rail.items[rail.indexForPath(["video", "playlists", "all"])].id, "playlists")
        compare(rail.items[rail.indexForPath(["video", "all"])].id, "video")
        compare(rail.items[rail.indexForPath(["home", "recent"])].id, "recent")
        compare(rail.items[rail.indexForPath(["home"])].id, "home")
        compare(rail.indexForPath(["mlsettings"]), -1)
        compare(rail.indexForPath([]), -1)
    }
}
