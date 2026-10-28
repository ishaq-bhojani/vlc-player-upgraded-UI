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
import QtQml

/**
 * @brief The "forward" of the library header. History (upstream) only goes back, so the header
 * keeps the pages it left with its back button:
 *   - `noteBack(path, props)` before it calls History.previous();
 *   - `take()` gives the last one back, the header pushes it;
 *   - `noteNavigation()` on every History.navigate: the navigations the header asked for are
 *     expected and kept, any other one (a page, the rail, Esc) starts a new branch and clears it.
 */
QtObject {
    id: root

    // Properties

    readonly property bool empty: _stack.length === 0

    property var _stack: []

    // the navigations that noteBack() and take() announced and History has not made yet
    property int _expected: 0

    // Functions

    function noteBack(path: var, props: var) {
        _stack = _stack.concat([{path: Array.from(path ?? []), props: props ?? {}}])
        ++_expected
    }

    // the last page noted (and taken off), or null
    function take(): var {
        if (_stack.length === 0)
            return null
        const top = _stack[_stack.length - 1]
        _stack = _stack.slice(0, -1)
        ++_expected
        return top
    }

    function noteNavigation() {
        if (_expected > 0) {
            --_expected
            return
        }
        _stack = []
    }
}
