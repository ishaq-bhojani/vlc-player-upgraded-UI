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

// The view modes and the sort entries of the header of the library (library/ViewHeader.qml).
QtObject {
    // in the order of the view-mode button
    readonly property var viewModes: ["grid", "list", "details"]

    // "grid" -> "list" -> "details" -> "grid"; anything else -> "grid"
    function nextViewMode(mode: string): string {
        const i = viewModes.indexOf(mode)
        return (i < 0) ? "grid" : viewModes[(i + 1) % viewModes.length]
    }

    // The mode the page is shown in: the saved one in the stage, always the compact list in the
    // panel beside the video (the grid and the table of the pages follow the global
    // MainCtx.gridView, which the panel must not flip).
    function effectiveViewMode(saved: string, inPanel: bool): string {
        if (inPanel)
            return "list"
        return viewModes.includes(saved) ? saved : "grid"
    }

    /**
     * The entries of the sort menu: [{label, criteria, order}].
     *
     * `pageSortModel` is the sort list of the page ([{text, criteria}], the `sortModel` of a
     * PageExt): its entries have no order (`undefined`), choosing the current one again reverses
     * it, as the sort control of the stock pages does. With `playcount` (the model of the page
     * sorts by play count) "Unwatched first" and "Watched first" follow, each with its order.
     */
    function sortOptions(pageSortModel: var, playcount: bool): var {
        const out = []
        const entries = Array.from(pageSortModel ?? [])
        for (let i = 0; i < entries.length; ++i) {
            const entry = entries[i]
            if (entry && entry.criteria)
                out.push({label: entry.text ?? entry.criteria, criteria: entry.criteria, order: undefined})
        }
        if (playcount && !out.some((o) => o.criteria === "playcount")) {
            out.push({label: qsTr("Unwatched first"), criteria: "playcount", order: Qt.AscendingOrder})
            out.push({label: qsTr("Watched first"), criteria: "playcount", order: Qt.DescendingOrder})
        }
        return out
    }

    // the sort {criteria, order} after `option` is chosen while the page sorts by `criteria`, `order`
    function chooseSort(option: var, criteria: string, order: int): var {
        if (option.order !== undefined)
            return {criteria: option.criteria, order: option.order}
        if (option.criteria === criteria)
            return {criteria: criteria, order: (order === Qt.AscendingOrder) ? Qt.DescendingOrder : Qt.AscendingOrder}
        return {criteria: option.criteria, order: Qt.AscendingOrder}
    }

    // whether `option` is the sort the page uses
    function isCurrentSort(option: var, criteria: string, order: int): bool {
        if (option.criteria !== criteria)
            return false
        return (option.order === undefined) || (option.order === order)
    }

    // Whether a model sorts by play count: only the media list of the videos does (MLVideoModel;
    // the groups and the folders of the videos do not). The type is read from the name of its class
    // (QObject's toString), the module of the media library is not loaded without a library.
    function supportsPlaycount(model: var): bool {
        return !!model && String(model).startsWith("MLVideoModel")
    }
}
