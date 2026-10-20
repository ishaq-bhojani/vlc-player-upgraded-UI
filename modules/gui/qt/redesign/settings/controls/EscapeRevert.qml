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

/**
 * @brief What Escape does in a field of the Settings modal: gives the stored value back when there
 * is something to give back, and then does not close the modal.
 *
 * NumberControl, TextControl and PathControl each have one. Its owner binds `pending` (the text
 * differs from the stored value), shows the stored value again on `revert()`, and passes it the
 * keys of the field:
 *
 *     EscapeRevert { id: escape; pending: root.text !== stored; onRevert: showValue() }
 *     Keys.onEscapePressed: (event) => escape.press(event)
 *     Keys.onReleased: (event) => escape.release(event)
 *     onActiveFocusChanged: { if (!activeFocus) escape.reset() }
 *
 * The modal closes on the release of Escape. With an edit pending the press is taken (`revert()`)
 * and so is its release, or the release would reach the popup and close the whole modal. With
 * nothing pending the press is not accepted, and neither is its release: one Escape closes the
 * modal.
 */
QtObject {
    id: root

    // Properties

    //! there is an edit to take back
    property bool pending: false

    //! the press of Escape was used to take back an edit: its release is ours too
    property bool taken: false

    // Signals

    //! the field has to show the stored value again
    signal revert()

    // Functions

    //! the press of Escape in the field (`event` is the KeyEvent of Keys.onEscapePressed)
    function press(event) {
        if (!root.pending) {
            event.accepted = false
            return
        }
        root.revert()
        root.taken = true
        event.accepted = true
    }

    //! a key released in the field (`event` is the KeyEvent of Keys.onReleased)
    function release(event) {
        if (event.key === Qt.Key_Escape && root.taken && !event.isAutoRepeat) {
            root.taken = false
            event.accepted = true
        }
    }

    //! the field lost the focus: a release that comes later is not ours
    function reset() {
        root.taken = false
    }
}
