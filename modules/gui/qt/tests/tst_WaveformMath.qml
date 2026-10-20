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
    name: "WaveformMath"

    function ramp(n) {
        const peaks = []
        for (let i = 0; i < n; ++i)
            peaks.push(i / (n - 1))
        return peaks
    }

    function test_decimateTakesTheMaxOfEveryBucket() {
        // 1000 values in 100 buckets of 10: the max of bucket i is the last value of the bucket
        const out = WaveformMath.decimate(ramp(1000), 100)
        compare(out.length, 100)
        fuzzyCompare(out[0], 9 / 999, 1e-9)
        fuzzyCompare(out[50], 509 / 999, 1e-9)
        fuzzyCompare(out[99], 1, 1e-9)

        // a single spike survives a coarse decimation
        const spike = new Array(1000).fill(0.1)
        spike[503] = 0.9
        const out2 = WaveformMath.decimate(spike, 10)
        compare(out2.length, 10)
        compare(out2[5], 0.9)
        compare(out2[4], 0.1)
    }

    function test_decimateUnevenBucketsCoverEverything() {
        // 1000 into 300: every source value is in exactly one bucket, the max of all is kept
        const peaks = new Array(1000).fill(0)
        peaks[999] = 1
        peaks[0] = 0.5
        const out = WaveformMath.decimate(peaks, 300)
        compare(out.length, 300)
        compare(out[0], 0.5)
        compare(out[299], 1)
        compare(Math.max.apply(null, out), 1)
    }

    function test_decimateClampsToTheSourceLength() {
        const out = WaveformMath.decimate(ramp(1000), 5000)
        compare(out.length, 1000)
        compare(out[10], 10 / 999)
        compare(WaveformMath.decimate([0.2, 0.4], 2).length, 2)
    }

    function test_decimateDegenerateInput() {
        compare(WaveformMath.decimate(ramp(1000), 0).length, 0)
        compare(WaveformMath.decimate(ramp(1000), -3).length, 0)
        compare(WaveformMath.decimate([], 100).length, 0)
        compare(WaveformMath.decimate(null, 100).length, 0)
        compare(WaveformMath.decimate(undefined, 100).length, 0)
        compare(WaveformMath.decimate(ramp(1000), NaN).length, 0)
    }

    function test_barCount() {
        compare(WaveformMath.barCount(300, 2, 1), 100)
        compare(WaveformMath.barCount(301, 2, 1), 100)
        compare(WaveformMath.barCount(0, 2, 1), 0)
        compare(WaveformMath.barCount(-5, 2, 1), 0)
        compare(WaveformMath.barCount(NaN, 2, 1), 0)
        compare(WaveformMath.barCount(300, 0, 0), 0)
        // bounded, whatever the width
        compare(WaveformMath.barCount(100000, 2, 1), WaveformMath.maxBars)
        verify(WaveformMath.maxBars <= 400)
    }

    function test_playedBars() {
        compare(WaveformMath.playedBars(100, 0), 0)
        compare(WaveformMath.playedBars(100, 0.5), 50)
        compare(WaveformMath.playedBars(100, 1), 100)
        compare(WaveformMath.playedBars(100, 1.7), 100)
        compare(WaveformMath.playedBars(100, -1), 0)
        compare(WaveformMath.playedBars(100, NaN), 0)
        compare(WaveformMath.playedBars(0, 0.5), 0)
    }

    function test_barHeight() {
        compare(WaveformMath.barHeight(1, 28, 2), 28)
        compare(WaveformMath.barHeight(0.5, 28, 2), 14)
        // silence keeps a visible stub
        compare(WaveformMath.barHeight(0, 28, 2), 2)
        compare(WaveformMath.barHeight(5, 28, 2), 28)
        compare(WaveformMath.barHeight(-1, 28, 2), 2)
        compare(WaveformMath.barHeight(0.5, 1, 2), 1)
    }
}
