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
 * `begin()` (also called when `trigger` changes: bind it to what changes when the content is
 * replaced) starts a guard of `guardInterval`. The item that has the focus outside of `scope` is
 * remembered (and updated while the focus moves outside of it); each time the focus then enters
 * `scope`, `quietInterval` after the last such change it goes back to that item. A focus that was
 * inside of `scope` before is not touched (the user is on the bar). The code cannot tell the
 * upstream steal from a move the user or the shell makes on purpose, so those end the guard with
 * `end()` (a pointer press, Tab, see RedesignControlBar.qml), or are outside of `scope` for it
 * (`exclude`, the resume prompt that takes the focus by itself). After the guard the focus moves
 * freely.
 *
 * Limit: a window that is not active has no active focus item, so a `begin()` then remembers
 * nothing and no guard starts (the focus the window gets back on activation is the one it had).
 * A remembered item that is destroyed is forgotten.
 */
QtObject {
    id: root

    // Properties

    // the item whose subtree must not take the focus away from the outside
    property Item scope

    // an item in `scope` whose focus is deliberate (the resume prompt): it counts as outside
    property Item exclude

    // a change of this value is a begin()
    property var trigger

    // how long after begin() a focus change into `scope` is taken back, in ms
    property int guardInterval: 1500

    // the focus must stay in `scope` this long, in ms, before it is taken back (a rebuild moves
    // it several times in one go)
    property int quietInterval: 50

    // Functions

    // the content is about to change
    function begin() {
        const window = root.scope ? root.scope.Window.window : null
        if (!window)
            return

        // a second change while the first is still being taken back: the item remembered by
        // the first one is the right one, the focus is on the bar by now
        if (root._guarding && root._outside) {
            guardTimer.restart()
            return
        }

        const current = window.activeFocusItem
        root._outside = (current && !root._inside(current)) ? current : null
        root._guarding = root._outside !== null
        if (root._guarding)
            guardTimer.restart()
    }

    // a move of the focus into `scope` that is wanted: the guard stops
    function end() {
        restoreTimer.stop()
        guardTimer.stop()
        root._guarding = false
        root._outside = null
    }

    onTriggerChanged: root.begin()

    // Private

    property bool _guarding: false
    property Item _outside: null

    function _inside(item: Item): bool {
        for (let it = item; it; it = it.parent) {
            if (it === root.exclude)
                return false
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

        onTriggered: root.end()
    }

    readonly property Timer _restoreTimer: Timer {
        id: restoreTimer

        interval: root.quietInterval

        onTriggered: root._restore()
    }
}
