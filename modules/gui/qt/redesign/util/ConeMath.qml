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
 * @brief Geometry of the cone shaped volume slider (ConeVolumeSlider).
 *
 * Positions are measured from the left (narrow) end of the cone, `width` is the width of the
 * cone, `height` the height of its wide end.
 */
QtObject {
    // `x` as a fraction of `width`, clamped to [0, 1] (0 for a cone without width)
    function _ratio(x: real, width: real): real {
        if (!(width > 0))
            return 0
        return Math.min(1, Math.max(0, x / width))
    }

    // volume (1 is 100 %) selected by a pointer at `x`, rounded to 0.01
    function volumeAt(x: real, width: real, maxVolume: real): real {
        return Math.round(_ratio(x, width) * maxVolume * 100) / 100
    }

    // height of the cone grown linearly from its tip, at `x`
    function fillHeightAt(x: real, width: real, height: real): real {
        return height * _ratio(x, width)
    }

    // The outline of the cone, from the owner's Figma export (docs/redesign/figma-svg/volume.svg,
    // the track `<path fill="#090909">`): 89 x 27.33 px, a narrow rounded left end (10.7 px
    // tall) and a wide rounded right end. Returned as an SVG path (PathSvg) scaled to
    // `width` x `height`.
    readonly property var _outline: [
        // [command, x, y, ...] in the coordinates of the export
        ["M", 24.5976, 40.3638],
        ["C", 22.5547, 40.1572, 21, 38.4374, 21, 36.3841],
        ["L", 21, 33.6159],
        ["C", 21, 31.5626, 22.5547, 29.8428, 24.5976, 29.6362],
        ["L", 106.698, 21.3339],
        ["C", 108.465, 21.1552, 110, 22.5425, 110, 24.3187],
        ["L", 110, 45.6813],
        ["C", 110, 47.4575, 108.465, 48.8448, 106.698, 48.6661],
        ["L", 24.5976, 40.3638]
    ]
    readonly property real _originX: 21
    readonly property real _originY: 21.3339
    readonly property real _sourceWidth: 89
    readonly property real _sourceHeight: 27.3322

    function silhouettePath(width: real, height: real): string {
        let path = ""
        for (const segment of _outline) {
            path += segment[0]
            for (let i = 1; i < segment.length; i += 2) {
                const px = (segment[i] - _originX) / _sourceWidth * width
                const py = (segment[i + 1] - _originY) / _sourceHeight * height
                path += " " + Number(px.toFixed(3)) + " " + Number(py.toFixed(3))
            }
            path += " "
        }
        return path + "Z"
    }
}
