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
    name: "LibraryOptions"

    readonly property var pageSort: [
        {text: "Alphabetic", criteria: "title"},
        {text: "Duration", criteria: "duration"}
    ]

    function test_viewModes() {
        compare(LibraryOptions.nextViewMode("grid"), "list")
        compare(LibraryOptions.nextViewMode("list"), "details")
        compare(LibraryOptions.nextViewMode("details"), "grid")
        compare(LibraryOptions.nextViewMode("bogus"), "grid")
        compare(LibraryOptions.nextViewMode(""), "grid")
    }

    function test_effectiveViewMode() {
        compare(LibraryOptions.effectiveViewMode("details", false), "details")
        compare(LibraryOptions.effectiveViewMode("bogus", false), "grid")
        // the panel beside the video always shows the compact list
        compare(LibraryOptions.effectiveViewMode("grid", true), "list")
        compare(LibraryOptions.effectiveViewMode("details", true), "list")
    }

    function test_sortOptions() {
        compare(LibraryOptions.sortOptions(pageSort, false),
                [{label: "Alphabetic", criteria: "title", order: undefined},
                 {label: "Duration", criteria: "duration", order: undefined}])
        compare(LibraryOptions.sortOptions(pageSort, true),
                [{label: "Alphabetic", criteria: "title", order: undefined},
                 {label: "Duration", criteria: "duration", order: undefined},
                 {label: "Unwatched first", criteria: "playcount", order: Qt.AscendingOrder},
                 {label: "Watched first", criteria: "playcount", order: Qt.DescendingOrder}])
    }

    function test_sortOptionsWithoutPageList() {
        compare(LibraryOptions.sortOptions(null, false), [])
        compare(LibraryOptions.sortOptions(undefined, true).length, 2)
        // entries without a criteria are not sortable
        compare(LibraryOptions.sortOptions([{text: "x"}], false), [])
    }

    function test_chooseSort() {
        const options = LibraryOptions.sortOptions(pageSort, true)
        // another key: ascending
        compare(LibraryOptions.chooseSort(options[1], "title", Qt.DescendingOrder),
                {criteria: "duration", order: Qt.AscendingOrder})
        // the current key again: reversed
        compare(LibraryOptions.chooseSort(options[0], "title", Qt.AscendingOrder),
                {criteria: "title", order: Qt.DescendingOrder})
        compare(LibraryOptions.chooseSort(options[0], "title", Qt.DescendingOrder),
                {criteria: "title", order: Qt.AscendingOrder})
        // watched / unwatched have their own order
        compare(LibraryOptions.chooseSort(options[3], "playcount", Qt.AscendingOrder),
                {criteria: "playcount", order: Qt.DescendingOrder})
        compare(LibraryOptions.chooseSort(options[2], "playcount", Qt.AscendingOrder),
                {criteria: "playcount", order: Qt.AscendingOrder})
    }

    function test_isCurrentSort() {
        const options = LibraryOptions.sortOptions(pageSort, true)
        verify(LibraryOptions.isCurrentSort(options[0], "title", Qt.DescendingOrder))
        verify(!LibraryOptions.isCurrentSort(options[1], "title", Qt.AscendingOrder))
        verify(LibraryOptions.isCurrentSort(options[2], "playcount", Qt.AscendingOrder))
        verify(!LibraryOptions.isCurrentSort(options[3], "playcount", Qt.AscendingOrder))
    }

    function test_supportsPlaycount() {
        verify(LibraryOptions.supportsPlaycount({toString: () => "MLVideoModel(0x1234)"}))
        verify(!LibraryOptions.supportsPlaycount({toString: () => "MLVideoGroupsModel(0x1234)"}))
        verify(!LibraryOptions.supportsPlaycount(null))
    }
}
