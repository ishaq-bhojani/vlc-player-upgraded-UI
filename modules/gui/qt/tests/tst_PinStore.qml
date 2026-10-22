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
    name: "PinStore"

    function init() {
        // never touch the settings of the user, start every test from an empty store
        PinStore.persistent = false
        PinStore.reset("")
    }

    function ids() {
        return PinStore.pins().map(p => p.id)
    }

    function test_empty() {
        compare(PinStore.pins(), [])
    }

    function test_pin() {
        const a = PinStore.pin("folder", "Movies", "file:///movies")
        const b = PinStore.pin("playlist", "Road trip", "42")
        compare(PinStore.pins().length, 2)
        compare(ids(), [a, b])
        compare(PinStore.pins()[0], { id: a, kind: "folder", label: "Movies", target: "file:///movies" })
        verify(a !== b)
        verify(PinStore.isPinned("folder", "file:///movies"))
        verify(PinStore.isPinned("playlist", "42"))
        // same target, other kind
        verify(!PinStore.isPinned("stream", "file:///movies"))
        verify(!PinStore.isPinned("folder", "file:///other"))
    }

    function test_pinTwice() {
        const a = PinStore.pin("stream", "Radio", "http://radio.example/stream")
        compare(PinStore.pin("stream", "Radio again", "http://radio.example/stream"), a)
        compare(PinStore.pins().length, 1)
        // the first label is kept
        compare(PinStore.pins()[0].label, "Radio")
        // same target but another kind is a different pin
        verify(PinStore.pin("folder", "Radio", "http://radio.example/stream") !== a)
        compare(PinStore.pins().length, 2)
    }

    function test_invalidPin() {
        compare(PinStore.pin("bogus", "x", "y"), "")
        compare(PinStore.pin("folder", "x", ""), "")
        compare(PinStore.pins().length, 0)
    }

    function test_unpin() {
        const a = PinStore.pin("folder", "A", "file:///a")
        const b = PinStore.pin("folder", "B", "file:///b")
        PinStore.unpin(a)
        compare(ids(), [b])
        verify(!PinStore.isPinned("folder", "file:///a"))
        // unknown id: no-op
        PinStore.unpin("nope")
        compare(ids(), [b])
        // pinning again after unpinning works
        verify(PinStore.pin("folder", "A", "file:///a") !== "")
        compare(PinStore.pins().length, 2)
    }

    function test_move() {
        const a = PinStore.pin("folder", "A", "file:///a")
        const b = PinStore.pin("folder", "B", "file:///b")
        const c = PinStore.pin("folder", "C", "file:///c")
        PinStore.move(c, 0)
        compare(ids(), [c, a, b])
        PinStore.move(c, 2)
        compare(ids(), [a, b, c])
        // out of range indexes are clamped
        PinStore.move(a, 99)
        compare(ids(), [b, c, a])
        PinStore.move(a, -5)
        compare(ids(), [a, b, c])
        // unknown id: no-op
        PinStore.move("nope", 0)
        compare(ids(), [a, b, c])
    }

    function test_corruptStorage() {
        PinStore.reset("{")
        compare(PinStore.pins(), [])
        PinStore.reset("not json")
        compare(PinStore.pins(), [])
        // valid JSON of the wrong shape
        PinStore.reset("{\"a\": 1}")
        compare(PinStore.pins(), [])
        PinStore.reset("[1, null, {\"id\": 3}]")
        compare(PinStore.pins(), [])
        // the store is usable afterwards
        verify(PinStore.pin("folder", "A", "file:///a") !== "")
        compare(PinStore.pins().length, 1)
    }

    function test_roundTrip() {
        const a = PinStore.pin("playlist", "P", "7")
        const raw = PinStore.serialized()
        PinStore.reset("")
        compare(PinStore.pins().length, 0)
        PinStore.reset(raw)
        compare(ids(), [a])
        // entries that are not valid are dropped, the others kept
        PinStore.reset(JSON.stringify([
            { id: "x", kind: "folder", label: "X", target: "file:///x" },
            { id: "y", kind: "weird", label: "Y", target: "file:///y" }
        ]))
        compare(ids(), ["x"])
    }

    function test_pinsIsACopy() {
        PinStore.pin("folder", "A", "file:///a")
        const copy = PinStore.pins()
        copy[0].label = "changed"
        copy.pop()
        compare(PinStore.pins().length, 1)
        compare(PinStore.pins()[0].label, "A")
    }

    function test_itemsChanged() {
        let count = 0
        const f = () => ++count
        PinStore.itemsChanged.connect(f)
        const a = PinStore.pin("folder", "A", "file:///a")
        PinStore.unpin(a)
        PinStore.itemsChanged.disconnect(f)
        compare(count, 2)
    }
}
