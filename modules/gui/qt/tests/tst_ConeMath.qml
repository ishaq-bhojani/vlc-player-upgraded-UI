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
    name: "ConeMath"

    function test_volumeAt() {
        compare(ConeMath.volumeAt(0, 200, 1.25), 0)
        compare(ConeMath.volumeAt(200, 200, 1.25), 1.25)
        // 0.625 rounds to the nearest 0.01
        compare(ConeMath.volumeAt(100, 200, 1.25), 0.63)
        // outside of the cone the position is clamped
        compare(ConeMath.volumeAt(-5, 200, 1), 0)
        compare(ConeMath.volumeAt(500, 200, 1), 1)
    }

    function test_volumeAtDegenerateWidth() {
        compare(ConeMath.volumeAt(10, 0, 1.25), 0)
    }

    function test_fillHeightAt() {
        compare(ConeMath.fillHeightAt(50, 200, 40), 10)
        compare(ConeMath.fillHeightAt(-10, 200, 40), 0)
        compare(ConeMath.fillHeightAt(300, 200, 40), 40)
    }

    function test_silhouetteSegments() {
        const segments = ConeMath.silhouetteSegments(89, 27.3322)
        compare(segments.length, 9)
        compare(segments[0][0], "M")
        compare(segments[1][0], "C")
        compare(segments[1].length, 7)
        // everything is inside the box, the wide end touches its right edge and spans the height
        let maxX = 0, minY = 1e9, maxY = 0
        for (const segment of segments)
            for (let i = 1; i < segment.length; i += 2) {
                maxX = Math.max(maxX, segment[i])
                minY = Math.min(minY, segment[i + 1])
                maxY = Math.max(maxY, segment[i + 1])
            }
        compare(maxX, 89)
        fuzzyCompare(minY, 0, 0.5) // the curves' control points reach a little further
        fuzzyCompare(maxY, 27.3322, 0.5)
        // the tip is on the left edge, in the middle
        fuzzyCompare(segments[2][1], 0, 0.001)
    }

    function test_silhouetteColumns() {
        const columns = ConeMath.silhouetteColumns(89, 28, 89)
        compare(columns.length, 89)
        // narrow at the tip, wide at the other end, centred on the middle line
        const tip = columns[0][1] - columns[0][0]
        const wide = columns[88][1] - columns[88][0]
        verify(tip > 0 && tip < 14)
        verify(wide > 24 && wide <= 28.5)
        for (const column of columns)
            fuzzyCompare((column[0] + column[1]) / 2, 14, 0.5)
        // the cone grows from the tip to the wide end
        verify(columns[60][1] - columns[60][0] > columns[30][1] - columns[30][0])
    }

    function test_silhouettePath() {
        // the path of volume.svg scaled to the box: starts at the lower left corner of the
        // narrow end and ends closed
        const path = ConeMath.silhouettePath(89, 27.34)
        verify(path.startsWith("M "))
        verify(path.endsWith("Z"))
        // the wide end spans the full height
        verify(path.indexOf("89") !== -1)
    }
}
