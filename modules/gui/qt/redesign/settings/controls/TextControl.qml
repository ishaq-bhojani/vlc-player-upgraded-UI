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

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Redesign

/**
 * @brief The control of a text setting (Figma "Values" text field, 320 x 36).
 *
 * `value` is shown; the text typed is reported by `edited` when the user validates it (Enter) or
 * leaves the field, and only if it differs from `value`. Escape gives the stored value back when
 * there is something to give back, and then does not close the Settings modal; with nothing typed
 * it is left to the modal, which closes. `password` shows dots instead of the text.
 */
Widgets.TextFieldExt {
    id: root

    // Properties

    //! the stored value
    property var value

    //! the name of the setting, for assistive technologies
    property string label

    //! show dots instead of the text
    property bool password: false

    //! set by the host once the constants (range, choices...) are in: the value is applied after
    property bool ready: false

    //! the long description of the setting, for assistive technologies
    property string description

    //! the user entered `newValue`
    signal edited(var newValue)

    //! the text typed differs from the stored value (there is an edit to take back)
    readonly property bool _pendingEdit: root.text !== ((root.value === undefined || root.value === null) ? "" : String(root.value))

    // Escape takes back a pending edit (and then does not close the modal), see EscapeRevert
    readonly property EscapeRevert _escape: EscapeRevert {
        pending: root._pendingEdit

        onRevert: root._showValue()
    }

    // Functions

    function _showValue() {
        root.text = Qt.binding(() => (root.value === undefined || root.value === null) ? "" : String(root.value))
    }

    // Settings

    implicitWidth: VLCStyle.dp(320, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

    radius: RedesignStyle.radiusM

    echoMode: password ? TextInput.Password : TextInput.Normal

    selectByMouse: true

    text: (value === undefined || value === null) ? "" : String(value)

    Accessible.name: label
    Accessible.description: description

    onEditingFinished: {
        if (root.text !== String(root.value ?? ""))
            root.edited(root.text)
        // typing replaces the binding: restore it, the field goes back to what is stored
        _showValue()
    }

    Keys.onEscapePressed: (event) => root._escape.press(event)

    Keys.onReleased: (event) => root._escape.release(event)

    onActiveFocusChanged: {
        if (!activeFocus)
            root._escape.reset()
    }
}
