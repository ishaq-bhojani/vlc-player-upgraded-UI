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
    name: "OnceLatch"

    Component {
        id: latchComponent

        OnceLatch { }
    }

    function test_startsFalse() {
        const latch = createTemporaryObject(latchComponent, testCase)
        compare(latch.latched, false)
    }

    // the flip must come from the change of `input`, which is a binding in the page
    function test_flipsOnFirstTrue() {
        const latch = createTemporaryObject(latchComponent, testCase)
        latch.input = false
        compare(latch.latched, false)
        latch.input = true
        compare(latch.latched, true)
    }

    function test_staysTrue() {
        const latch = createTemporaryObject(latchComponent, testCase)
        latch.input = true
        latch.input = false
        compare(latch.latched, true)
        latch.input = true
        latch.input = false
        compare(latch.latched, true)
    }

    function test_trueAtCreation() {
        const latch = createTemporaryObject(latchComponent, testCase, { input: true })
        compare(latch.latched, true)
    }

    // as in HomePage: input bound to the "loaded" state of the sources
    function test_boundInput() {
        const source = createTemporaryObject(sourceComponent, testCase)
        compare(source.latch.latched, false)
        source.loading = false
        compare(source.latch.latched, true)
        source.loading = true // reload
        compare(source.latch.input, false)
        compare(source.latch.latched, true)
    }

    Component {
        id: sourceComponent

        QtObject {
            property bool loading: true
            readonly property OnceLatch latch: OnceLatch { input: !loading }
        }
    }
}
