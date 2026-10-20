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
    name: "WaveformTrack"

    width: 400
    height: 100

    function ramp(n) {
        const peaks = []
        for (let i = 0; i < n; ++i)
            peaks.push(i / (n - 1))
        return peaks
    }

    function track(props) {
        const item = createTemporaryObject(trackComponent, this, props)
        verify(item)
        return item
    }

    Component {
        id: trackComponent

        WaveformTrack {
            height: 28
        }
    }

    function test_oneDelegatePerDecimatedPeak() {
        const t = track({ width: 93, peaks: ramp(1000) })
        // floor(93 / (2 + 2)) bars, as many delegates as the decimated array is long
        compare(t.bars.length, 23)
        compare(t.delegateCount, 23)
        compare(t.delegateCount, t.bars.length)
    }

    function test_followsTheWidth() {
        const t = track({ width: 93, peaks: ramp(1000) })
        t.width = 200
        compare(t.bars.length, 50)
        compare(t.delegateCount, 50)
        t.width = 10
        compare(t.bars.length, 2)
        compare(t.delegateCount, 2)
    }

    function test_neverMoreThanMaxBars() {
        const t = track({ width: 100000, peaks: ramp(1000) })
        compare(t.bars.length, WaveformMath.maxBars)
        compare(t.delegateCount, WaveformMath.maxBars)
        verify(t.delegateCount <= 400)
    }

    function test_fewPeaksFewBars() {
        const t = track({ width: 400, peaks: [0.1, 0.5, 0.2] })
        compare(t.bars.length, 3)
        compare(t.delegateCount, 3)
    }

    function test_noWidthOrNoPeaksNoBars() {
        const t = track({ width: 0, peaks: ramp(1000) })
        compare(t.delegateCount, 0)
        const e = track({ width: 200, peaks: [] })
        compare(e.bars.length, 0)
        compare(e.delegateCount, 0)
    }

    function test_resizeWithinTheSameCountKeepsTheBars() {
        const t = track({ width: 93, peaks: ramp(1000) })
        compare(t.delegateCount, 23)
        // 93 .. 95 px all fit 23 bars
        t.width = 95
        compare(t.delegateCount, 23)
        compare(t.bars.length, 23)
    }

    function test_lastPeaksStayWhenTheyGoAway() {
        const t = track({ width: 93, peaks: ramp(1000) })
        t.peaks = []
        // the owner fades the track out: the bars stay until then
        compare(t.delegateCount, 23)
        t.peaks = [0.5, 0.5]
        compare(t.delegateCount, 2)
    }
}
