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
import QtQuick
import QtTest
import VLC.Redesign

TestCase {
    id: testCase
    name: "StopDebounce"

    Component {
        id: debounceComponent

        StopDebounce {
            interval: 60
            property int settledCount: 0
            onSettledStopped: settledCount++
        }
    }

    // the transient STOPPED between two playlist items (STOPPING, STOPPED, STARTED)
    function test_transientStopIsIgnored() {
        const d = createTemporaryObject(debounceComponent, testCase)
        compare(d.stopped, false)
        d.input = true
        compare(d.stopped, false)
        wait(20)
        d.input = false
        wait(150) // well past the interval
        compare(d.stopped, false)
        compare(d.settledCount, 0)
    }

    function test_heldStopSettlesOnce() {
        const d = createTemporaryObject(debounceComponent, testCase)
        d.input = true
        compare(d.stopped, false)
        tryCompare(d, "stopped", true, 1000)
        compare(d.settledCount, 1)
        wait(150)
        compare(d.settledCount, 1)
        compare(d.stopped, true)
    }

    function test_startAfterSettleClearsImmediately() {
        const d = createTemporaryObject(debounceComponent, testCase)
        d.input = true
        tryCompare(d, "stopped", true, 1000)
        d.input = false
        compare(d.stopped, false) // no delay on start
        wait(150)
        compare(d.stopped, false)
        compare(d.settledCount, 1)
    }

    // app start with nothing playing: the library is shown without waiting
    function test_stoppedAtCreationIsImmediate() {
        const d = createTemporaryObject(debounceComponent, testCase, { input: true })
        compare(d.stopped, true)
        wait(150)
        compare(d.stopped, true)
        compare(d.settledCount, 0) // not a transition
    }

    // a second stop after a restart debounces again
    function test_secondStopDebouncesAgain() {
        const d = createTemporaryObject(debounceComponent, testCase, { input: true })
        d.input = false
        d.input = true
        compare(d.stopped, false)
        tryCompare(d, "stopped", true, 1000)
        compare(d.settledCount, 1)
    }

    // a flip stopped -> not stopped -> stopped restarts the interval
    function test_restartRestartsInterval() {
        const d = createTemporaryObject(debounceComponent, testCase)
        d.input = true
        wait(40)
        d.input = false
        d.input = true
        wait(40) // 80 ms since the first stop but only 40 since the last one
        compare(d.stopped, false)
        tryCompare(d, "stopped", true, 1000)
        compare(d.settledCount, 1)
    }

    // as in the shell: the input is a binding on the player state
    function test_boundInput() {
        const host = createTemporaryObject(hostComponent, testCase)
        compare(host.debounce.stopped, true)
        host.state = 1
        compare(host.debounce.stopped, false)
        host.state = 0
        compare(host.debounce.stopped, false)
        host.state = 1
        wait(150)
        compare(host.debounce.stopped, false)
        host.state = 0
        tryCompare(host.debounce, "stopped", true, 1000)
    }

    Component {
        id: hostComponent

        QtObject {
            property int state: 0 // 0 stopped, 1 playing
            readonly property StopDebounce debounce: StopDebounce {
                interval: 60
                input: state === 0
            }
        }
    }
}
