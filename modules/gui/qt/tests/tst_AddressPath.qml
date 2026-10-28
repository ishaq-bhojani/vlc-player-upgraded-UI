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
    name: "AddressPath"

    function test_crumbs() {
        compare(AddressPath.crumbs(["video", "all"], {video: "Videos", all: "All"}),
                [{label: "Videos", path: ["video"]}, {label: "All", path: ["video", "all"]}])
        compare(AddressPath.crumbs([], {}), [])
    }

    function test_unknownSegmentShownAsIs() {
        compare(AddressPath.crumbs(["music", "zz"], {music: "Music"}),
                [{label: "Music", path: ["music"]}, {label: "zz", path: ["music", "zz"]}])
        compare(AddressPath.crumbs(["a"], undefined), [{label: "a", path: ["a"]}])
    }

    function test_emptyLabelSkipsTheSegment() {
        // "base" has no page of its own: the group crumb includes it in its path
        compare(AddressPath.crumbs(["video", "all", "base", "group"],
                                {video: "Videos", all: "", base: "", group: "Holidays"}),
                [{label: "Videos", path: ["video"]},
                 {label: "Holidays", path: ["video", "all", "base", "group"]}])
    }

    function test_inheritedNamesAreNotLabels() {
        // "constructor", "toString"... are segments like any other, not properties of the map
        compare(AddressPath.crumbs(["constructor"], {}), [{label: "constructor", path: ["constructor"]}])
    }
}
