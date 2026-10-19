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
