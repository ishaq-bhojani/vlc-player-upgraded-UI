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
import QtQuick

/**
 * @brief Keeps the keyboard focus where it was while the content of `scope` is rebuilt.
 *
 * The control bar hosts the upstream PlayerControlLayout. When its controls are replaced (a video
 * starts, the profile changes) the ControlRepeater of upstream calls `recoverFocus()` for every
 * removed control, which `forceActiveFocus()`es a neighbour: the bar takes the keyboard from
 * wherever the shell put it (the Stage), after the shell decided where it is. The upstream code
 * is not changed; this puts the focus back.
 *
 * Call `begin()` when the content is about to change. For `guardInterval` the item that had the
 * focus outside of `scope` is remembered (and updated while the focus moves outside of it); each
 * time the focus then enters `scope`, `quietInterval` after the last such change it goes back
 * to that item. A focus that was inside of `scope` before is not touched (the user is on the
 * bar), and after the guard the focus moves freely (Tab, a click).
 */
QtObject {
    id: root

    // Properties

    // the item whose subtree must not take the focus away from the outside
    property Item scope

    // how long after begin() a focus change into `scope` is taken back, in ms
    property int guardInterval: 1500

    // the focus must stay in `scope` this long, in ms, before it is taken back (a rebuild moves
    // it several times in one go)
    property int quietInterval: 50

    // Functions

    function begin() {
        const window = root.scope ? root.scope.Window.window : null
        if (!window)
            return

        const current = window.activeFocusItem
        root._outside = (current && !root._inside(current)) ? current : null
        root._guarding = root._outside !== null
        if (root._guarding)
            guardTimer.restart()
    }

    // Private

    property bool _guarding: false
    property Item _outside: null

    function _inside(item: Item): bool {
        for (let it = item; it; it = it.parent) {
            if (it === root.scope)
                return true
        }
        return false
    }

    function _restore() {
        const target = root._outside
        const window = root.scope ? root.scope.Window.window : null
        if (!root._guarding || !target || !window)
            return

        const current = window.activeFocusItem
        if (current && root._inside(current) && target.visible && target.enabled)
            target.forceActiveFocus(Qt.OtherFocusReason)
    }

    readonly property Connections _windowConnection: Connections {
        target: root.scope ? root.scope.Window.window : null

        function onActiveFocusItemChanged() {
            if (!root._guarding)
                return

            const current = target.activeFocusItem
            if (current && root._inside(current))
                restoreTimer.restart()
            else if (current)
                root._outside = current // the shell moved it meanwhile
        }
    }

    readonly property Timer _guardTimer: Timer {
        id: guardTimer

        interval: root.guardInterval

        onTriggered: {
            restoreTimer.stop()
            root._guarding = false
            root._outside = null
        }
    }

    readonly property Timer _restoreTimer: Timer {
        id: restoreTimer

        interval: root.quietInterval

        onTriggered: root._restore()
    }
}
