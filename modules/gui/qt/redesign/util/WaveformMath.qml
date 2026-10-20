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
 * @brief The arithmetic of the waveform seek bar (WaveformTrack): how many bars fit, the peaks
 * folded into that many bars, how many of them are played.
 *
 * No library or player access, so it can be tested on its own.
 */
QtObject {
    // the bars drawn are plain Rectangles: never more than this, whatever the width
    readonly property int maxBars: 400

    function _finite(value: real): real {
        return (isFinite(value) && value > 0) ? value : 0
    }

    // How many bars of `barWidth` with `gap` between them fit in `width` (0 for no room),
    // at most maxBars.
    function barCount(width: real, barWidth: real, gap: real): int {
        const pitch = _finite(barWidth) + _finite(gap)
        if (!(pitch > 0))
            return 0
        return Math.min(maxBars, Math.floor(_finite(width) / pitch))
    }

    // `peaks` (values in [0, 1]) folded into `count` values, the max of the source values every
    // one covers. Never longer than `peaks`; empty for no peaks or no room. The result is what a
    // Repeater takes as model, so its length is the number of bars.
    function decimate(peaks: var, count: real): var {
        if (!peaks || !(peaks.length > 0) || !(count >= 1))
            return []

        const n = peaks.length
        const buckets = Math.min(n, Math.floor(count))
        const out = new Array(buckets)
        for (let i = 0; i < buckets; ++i) {
            // [from, to) of the source: every value belongs to exactly one bucket, none is empty
            const from = Math.floor(i * n / buckets)
            const to = Math.max(from + 1, Math.floor((i + 1) * n / buckets))
            let peak = 0
            for (let j = from; j < to; ++j) {
                if (peaks[j] > peak)
                    peak = peaks[j]
            }
            out[i] = peak
        }
        return out
    }

    // how many of `count` bars, counted from the start, are played at `position` (0..1)
    function playedBars(count: real, position: real): int {
        if (!(count > 0) || !isFinite(position))
            return 0
        return Math.round(count * Math.min(1, Math.max(0, position)))
    }

    // height of the bar of `peak` (0..1) in a track `height` high: silence keeps a stub of
    // `minHeight`, which never exceeds the track
    function barHeight(peak: real, height: real, minHeight: real): real {
        const p = Math.min(1, Math.max(0, peak))
        return Math.min(height, Math.max(minHeight, p * height))
    }
}
