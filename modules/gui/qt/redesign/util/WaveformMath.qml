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

    // Colours. The played bars are the accent, whatever the user picked, so the colour of the
    // others is computed from it: WCAG 1.4.11 asks 3:1 between the two parts of a control, and
    // hue alone does not give that (the grey of the muted text against the default orange is
    // 1.65:1 in the dark theme, 1.23:1 in the light one).

    // the least luminance contrast between the played and the other bars (3 is the minimum)
    readonly property real minRestContrast: 3.2

    // below this contrast with its background, a bar dimmer than the played ones is hard to see
    readonly property real minRestVisibility: 1.5

    function _linear(channel: real): real {
        return channel <= 0.03928 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
    }

    function _unlinear(value: real): real {
        return value <= 0.0031308 ? value * 12.92 : 1.055 * Math.pow(value, 1 / 2.4) - 0.055
    }

    // relative luminance (WCAG) of a colour
    function luminance(value: var): real {
        // a colour value or a string, "#RRGGBB"
        const c = Qt.color(value)
        return 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b)
    }

    // contrast ratio (WCAG, 1..21) of two colours
    function contrast(a: var, b: var): real {
        const la = luminance(a)
        const lb = luminance(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }

    // The colour of the bars that are not played yet: a grey `minRestContrast`:1 from `played`
    // (luminance), on `background`. The dimmer one when it can still be seen against the
    // background (always in the light theme, and in the dark one for the usual accents), the
    // brighter one otherwise (a dark accent on a dark bar).
    function restColor(played: var, background: var): var {
        const lp = luminance(played) + 0.05
        const lb = luminance(background)
        // the luminances that are `minRestContrast`:1 darker and brighter than `played`
        const dim = Math.max(0, lp / minRestContrast - 0.05)
        const bright = lp * minRestContrast - 0.05

        const dimVisible = (Math.max(dim, lb) + 0.05) / (Math.min(dim, lb) + 0.05) >= minRestVisibility
        const grey = _unlinear((dimVisible || bright > 1) ? dim : bright)
        return Qt.rgba(grey, grey, grey, 1)
    }
}
