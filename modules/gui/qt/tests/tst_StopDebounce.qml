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
            interval: 200
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
        wait(30)
        d.input = false
        wait(600) // 3x the interval
        compare(d.stopped, false)
        compare(d.settledCount, 0)
    }

    function test_heldStopSettlesOnce() {
        const d = createTemporaryObject(debounceComponent, testCase)
        d.input = true
        compare(d.stopped, false)
        tryCompare(d, "stopped", true, 5000)
        compare(d.settledCount, 1)
        wait(600)
        compare(d.settledCount, 1)
        compare(d.stopped, true)
    }

    function test_startAfterSettleClearsImmediately() {
        const d = createTemporaryObject(debounceComponent, testCase)
        d.input = true
        tryCompare(d, "stopped", true, 5000)
        d.input = false
        compare(d.stopped, false) // no delay on start
        wait(600)
        compare(d.stopped, false)
        compare(d.settledCount, 1)
    }

    // app start with nothing playing: the library is shown without waiting
    function test_stoppedAtCreationIsImmediate() {
        const d = createTemporaryObject(debounceComponent, testCase, { input: true })
        compare(d.stopped, true)
        wait(600)
        compare(d.stopped, true)
        compare(d.settledCount, 0) // not a transition
    }

    // a second stop after a restart debounces again
    function test_secondStopDebouncesAgain() {
        const d = createTemporaryObject(debounceComponent, testCase, { input: true })
        d.input = false
        d.input = true
        compare(d.stopped, false)
        tryCompare(d, "stopped", true, 5000)
        compare(d.settledCount, 1)
    }

    // a flip stopped -> not stopped -> stopped restarts the interval
    function test_restartRestartsInterval() {
        const d = createTemporaryObject(debounceComponent, testCase)
        d.input = true
        // 300 ms since the first stop, but never more than 50 ms since the last restart
        for (let i = 0; i < 6; ++i) {
            wait(50)
            d.input = false
            d.input = true
            compare(d.stopped, false)
        }
        tryCompare(d, "stopped", true, 5000)
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
        wait(600)
        compare(host.debounce.stopped, false)
        host.state = 0
        tryCompare(host.debounce, "stopped", true, 5000)
    }

    Component {
        id: hostComponent

        QtObject {
            property int state: 0 // 0 stopped, 1 playing
            readonly property StopDebounce debounce: StopDebounce {
                interval: 200
                input: state === 0
            }
        }
    }
}
