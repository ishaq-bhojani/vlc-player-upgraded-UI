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

    // the outline scaled to `width` x `height`: [["M", x, y], ["C", x1, y1, x2, y2, x, y], ["L", x, y], ...]
    // (what a Canvas path needs: moveTo, bezierCurveTo, lineTo)
    function silhouetteSegments(width: real, height: real): var {
        const segments = []
        for (const segment of _outline) {
            const scaled = [segment[0]]
            for (let i = 1; i < segment.length; i += 2) {
                scaled.push((segment[i] - _originX) / _sourceWidth * width)
                scaled.push((segment[i + 1] - _originY) / _sourceHeight * height)
            }
            segments.push(scaled)
        }
        return segments
    }

    // The outline as a closed polyline (curves flattened), for columns().
    function _polyline(width: real, height: real): var {
        const steps = 12
        const points = []
        let x = 0
        let y = 0
        for (const s of silhouetteSegments(width, height)) {
            if (s[0] === "C") {
                for (let k = 1; k <= steps; ++k) {
                    const t = k / steps
                    const u = 1 - t
                    points.push([u * u * u * x + 3 * u * u * t * s[1] + 3 * u * t * t * s[3] + t * t * t * s[5],
                                 u * u * u * y + 3 * u * u * t * s[2] + 3 * u * t * t * s[4] + t * t * t * s[6]])
                }
                x = s[5]
                y = s[6]
            } else {
                x = s[1]
                y = s[2]
                points.push([x, y])
            }
        }
        return points
    }

    // The cone as `count` vertical columns of equal width, [[top, bottom], ...] (y from the top of
    // a box `width` x `height`): QtQuick.Shapes, Path and Canvas are not part of the static Windows
    // build of Qt, so the cone is made of rectangles.
    function silhouetteColumns(width: real, height: real, count: int): var {
        const points = _polyline(width, height)
        const columns = []
        for (let i = 0; i < count; ++i) {
            const x = (i + 0.5) * width / count
            let top = Infinity
            let bottom = -Infinity
            for (let j = 0; j < points.length; ++j) {
                const a = points[j]
                const b = points[(j + 1) % points.length]
                if ((a[0] <= x && b[0] > x) || (b[0] <= x && a[0] > x)) {
                    const y = a[1] + (x - a[0]) / (b[0] - a[0]) * (b[1] - a[1])
                    top = Math.min(top, y)
                    bottom = Math.max(bottom, y)
                }
            }
            columns.push(top <= bottom ? [top, bottom] : [0, 0])
        }
        return columns
    }

    // the same as an SVG path string
    function silhouettePath(width: real, height: real): string {
        let path = ""
        for (const segment of silhouetteSegments(width, height)) {
            path += segment[0]
            for (let i = 1; i < segment.length; ++i)
                path += " " + Number(segment[i].toFixed(3))
            path += " "
        }
        return path + "Z"
    }
}
