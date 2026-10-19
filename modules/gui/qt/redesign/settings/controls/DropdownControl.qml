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
 * @brief The control of a setting with a list of values (Figma "Dropdown", 320 x 36).
 *
 * `choices` is [{value, label}] (SettingItem.choices), `value` the stored value. The user's
 * pick is reported by `edited` with the `value` of the row; nothing is written otherwise: a
 * stored value that is not in the list (aout "" when the list has no such row) shows the first
 * row as selected, without a write. Arrow keys change the pick when closed, Space opens the list.
 */
Widgets.ComboBoxExt {
    id: root

    // Properties

    //! the stored value
    property var value

    //! the name of the setting, for assistive technologies
    property string label

    //! [{value, label}]
    property var choices: []

    //! the user chose `newValue`
    signal edited(var newValue)

    // Settings

    implicitWidth: VLCStyle.dp(320, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

    font.pixelSize: VLCStyle.fontSize_normal

    model: choices
    textRole: "label"

    currentIndex: ControlChooser.choiceIndex(choices, value)

    Accessible.name: label

    onActivated: (index) => {
        if (index >= 0 && index < root.choices.length)
            root.edited(root.choices[index].value)
        // a pick replaces the binding: restore it, the selection goes where `value` says
        root.currentIndex = Qt.binding(() => ControlChooser.choiceIndex(root.choices, root.value))
    }
}
