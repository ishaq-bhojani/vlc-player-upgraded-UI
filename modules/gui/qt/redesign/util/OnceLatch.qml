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
import QtQml

/**
 * @brief A flag that turns true the first time `input` is true and then stays true.
 *
 * Used to tell "never loaded yet" from "reloading": the Home page shows its empty state
 * only after the first complete load, a later reload (the sources are `loading` again) must
 * not flash it.
 */
QtObject {
    id: latch

    // the condition to watch
    property bool input: false

    // true from the first time `input` was true on
    readonly property bool latched: _latched

    property bool _latched: false

    onInputChanged: {
        if (input)
            _latched = true
    }

    Component.onCompleted: {
        if (input)
            _latched = true
    }
}
