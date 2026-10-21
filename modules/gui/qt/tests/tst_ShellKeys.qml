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
    name: "ShellKeys"

    function test_normalize() {
        compare(ShellKeys.normalize("Ctrl+P"), "ctrl+p")
        compare(ShellKeys.normalize("ctrl+p"), "ctrl+p")
        compare(ShellKeys.normalize("Shift+Ctrl+P"), "ctrl+shift+p")
        compare(ShellKeys.normalize("Ctrl+Shift+P"), "ctrl+shift+p")
        compare(ShellKeys.normalize(" Space "), "space")
        compare(ShellKeys.normalize(""), "")
        compare(ShellKeys.normalize(undefined), "")
    }

    // the key itself may be a "+" or a "-"
    function test_plusAndMinusKeys() {
        compare(ShellKeys.normalize("Ctrl++"), "ctrl++")
        compare(ShellKeys.normalize("Ctrl+Shift+-"), "ctrl+shift+-")
    }

    function test_settingsKeyIsReserved() {
        verify(ShellKeys.reservedFor("Ctrl+P") !== "")
        verify(ShellKeys.reservedFor("Ctrl+p") !== "")
        compare(ShellKeys.reservedFor("Ctrl+p"), ShellKeys.reservedFor("Ctrl+P"))
    }

    function test_freeKeys() {
        compare(ShellKeys.reservedFor("Space"), "")
        compare(ShellKeys.reservedFor("Ctrl+Alt+P"), "")
        compare(ShellKeys.reservedFor("Alt+Left"), "")
        compare(ShellKeys.reservedFor(""), "")
    }

    // a value of several keys: any of them
    function test_severalKeys() {
        verify(ShellKeys.reservedFor("Space\tCtrl+P") !== "")
        compare(ShellKeys.reservedFor("Space\tMedia Play Pause"), "")
    }

    // no two entries answer for the same key
    function test_noDuplicates() {
        const seen = {}
        for (const entry of ShellKeys.reserved) {
            const key = ShellKeys.normalize(entry.key)
            verify(!seen[key], "duplicate " + key)
            seen[key] = true
        }
    }
}
