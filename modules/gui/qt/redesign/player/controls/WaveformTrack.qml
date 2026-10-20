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

import VLC.Redesign

/**
 * @brief The track of the seek bar drawn as a waveform: one rounded bar per decimated peak,
 * the played ones in `playedColor`, the rest in `restColor`.
 *
 * A picture only, it takes no input: SeekBarWidget keeps all the seek logic (click, drag, keys,
 * hover, focus) and shows this in place of its groove while a waveform is ready.
 *
 * The bars are plain Rectangles (the static win64 Qt has no QtQuick.Shapes): at most
 * WaveformMath.maxBars of them, the model of the Repeater is the decimated array itself, so the
 * number of bars can never differ from what the delegates read. The played part is one number
 * computed from `position`; a bar only compares its index with it.
 *
 * The bars are rebuilt when the peaks or the number of bars that fit change, not on every pixel
 * of a resize. The last non-empty peaks are kept: when the peaks go away the bars stay (while
 * the owner fades this out) instead of vanishing at once.
 */
Item {
    id: root

    // Properties

    // the peaks (values in [0, 1]) of the media, WaveformProvider.peaks
    property var peaks: []

    // 0..1 position of the playback
    property real position: 0

    property color playedColor: "white"
    property color restColor: "gray"

    // sizes, in pixels: the bars are barWidth wide at best, gap apart, at least minBarHeight high
    property real barWidth: 2
    property real gap: 2
    property real minBarHeight: 2

    // the number of bars that fit
    readonly property int _count: WaveformMath.barCount(width, barWidth, gap)

    // the peaks drawn: the last non-empty ones
    property var _shown: []

    // the decimated peaks, one per bar (length == number of bars)
    readonly property var bars: WaveformMath.decimate(_shown, _count)

    readonly property int _played: WaveformMath.playedBars(bars.length, position)

    // how many bars the Repeater made (== bars.length)
    readonly property int delegateCount: repeater.count

    function _sync() {
        if (peaks && peaks.length > 0)
            _shown = peaks
    }

    onPeaksChanged: _sync()
    Component.onCompleted: _sync()

    // Children

    Repeater {
        id: repeater

        model: root.bars

        delegate: Rectangle {
            required property int index
            required property real modelData

            // the bars share the width evenly, the gap is split on both sides of a bar so the
            // first and the last are as far from the edges as from each other
            readonly property real _pitch: root.width / Math.max(1, root.bars.length)

            x: index * _pitch + root.gap / 2
            width: Math.max(1, _pitch - root.gap)
            height: WaveformMath.barHeight(modelData, root.height, root.minBarHeight)
            y: (root.height - height) / 2
            radius: width / 2

            color: index < root._played ? root.playedColor : root.restColor
        }
    }
}
