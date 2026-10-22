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
import QtQuick
import QtTest
import VLC.Redesign

TestCase {
    name: "CardCorner"

    function test_normalized() {
        for (const c of CardCorner.corners)
            compare(CardCorner.normalized(c), c)
        compare(CardCorner.normalized(""), "bottom-right")
        compare(CardCorner.normalized("center"), "bottom-right")
        compare(CardCorner.normalized("Top-Left"), "bottom-right")
    }

    // area 1000 x 600, card 320 x 180
    function test_nearest_data() {
        return [
            { tag: "top left", x: 10, y: 10, expected: "top-left" },
            { tag: "top right", x: 600, y: 20, expected: "top-right" },
            { tag: "bottom left", x: 20, y: 400, expected: "bottom-left" },
            { tag: "bottom right", x: 650, y: 400, expected: "bottom-right" },
            // the centre decides, not the top left of the card: centre x is 500 + 160
            { tag: "centre right of the middle", x: 341, y: 0, expected: "top-right" },
            // centre x is 340 + 160 = 500, exactly the middle goes left
            { tag: "exactly in the middle", x: 340, y: 210, expected: "top-left" },
            // dropped outside of the area
            { tag: "outside", x: -500, y: 9000, expected: "bottom-left" },
        ]
    }

    function test_nearest(data) {
        compare(CardCorner.nearest(data.x, data.y, 320, 180, 1000, 600), data.expected)
    }

    function test_position_data() {
        return [
            { tag: "top-left", corner: "top-left", x: 16, y: 16 },
            { tag: "top-right", corner: "top-right", x: 664, y: 16 },
            { tag: "bottom-left", corner: "bottom-left", x: 16, y: 404 },
            { tag: "bottom-right", corner: "bottom-right", x: 664, y: 404 },
            { tag: "unknown is the default", corner: "nowhere", x: 664, y: 404 },
        ]
    }

    function test_position(data) {
        const p = CardCorner.position(data.corner, 320, 180, 1000, 600, 16)
        compare(p.x, data.x)
        compare(p.y, data.y)
    }

    function test_positionInTooSmallArea() {
        const p = CardCorner.position("bottom-right", 320, 180, 200, 100, 16)
        compare(p.x, 0)
        compare(p.y, 0)
    }

    // a snapped card is found in the corner it was snapped to
    function test_roundTrip() {
        for (const c of CardCorner.corners) {
            const p = CardCorner.position(c, 320, 180, 1000, 600, 16)
            compare(CardCorner.nearest(p.x, p.y, 320, 180, 1000, 600), c)
        }
    }
}
