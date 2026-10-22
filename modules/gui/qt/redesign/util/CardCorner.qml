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
 * @brief Corner snapping of the mini player card (MiniPlayerCard): which corner of the area a
 * card dropped at some position belongs to, and where a card sits in a corner.
 *
 * A corner is one of "top-left", "top-right", "bottom-left", "bottom-right" (the string is
 * persisted), anything else is read as the default corner.
 */
QtObject {
    readonly property var corners: ["top-left", "top-right", "bottom-left", "bottom-right"]

    readonly property string defaultCorner: "bottom-right"

    // `corner` if it is one of the four corners, else the default corner
    function normalized(corner: string): string {
        return corners.includes(corner) ? corner : defaultCorner
    }

    // The corner nearest to a card of size `cardWidth` x `cardHeight` whose top left is at
    // (`x`, `y`) in an area of `areaWidth` x `areaHeight`: the quadrant its centre is in.
    function nearest(x: real, y: real, cardWidth: real, cardHeight: real,
                     areaWidth: real, areaHeight: real): string {
        const right = (x + cardWidth / 2) > (areaWidth / 2)
        const bottom = (y + cardHeight / 2) > (areaHeight / 2)
        return (bottom ? "bottom-" : "top-") + (right ? "right" : "left")
    }

    // Top left of a card of size `cardWidth` x `cardHeight` in `corner` of an area of
    // `areaWidth` x `areaHeight`, `margin` away from the edges. An area too small for the card
    // keeps the card at the top left edge (never at a negative position).
    function position(corner: string, cardWidth: real, cardHeight: real,
                      areaWidth: real, areaHeight: real, margin: real): point {
        const c = normalized(corner)
        const x = c.endsWith("right") ? (areaWidth - cardWidth - margin) : margin
        const y = c.startsWith("bottom") ? (areaHeight - cardHeight - margin) : margin
        return Qt.point(Math.max(0, x), Math.max(0, y))
    }
}
