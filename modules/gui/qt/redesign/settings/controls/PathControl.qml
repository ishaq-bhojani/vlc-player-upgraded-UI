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
import QtQuick.Layouts

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Redesign

/**
 * @brief The control of a file or folder setting (Figma "Values" path field with the Browse
 * button).
 *
 * The path can be typed: it is reported by `edited` when the user validates it (Enter) or leaves
 * the field, if it differs from `value`. Picking a path in a file dialog is not done here (the
 * dialog helpers are C++ widgets, there is no QML dialog in the static Qt build): the Browse
 * button, visible only if `canBrowse`, emits `browseRequested` and whoever hosts the control
 * opens the dialog and stores the path.
 */
FocusScope {
    id: root

    // Properties

    //! the stored value
    property var value

    //! the name of the setting, for assistive technologies
    property string label

    //! the host handles browseRequested; without it the Browse button is hidden
    property bool canBrowse: false

    //! set by the host once the constants (range, choices...) are in: the value is applied after
    property bool ready: false

    //! the long description of the setting, for assistive technologies
    property string description

    //! the user entered `newValue`
    signal edited(var newValue)

    //! the Browse button was activated
    signal browseRequested()

    // Settings

    implicitWidth: VLCStyle.dp(320, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

    // Children

    RowLayout {
        anchors.fill: parent

        spacing: RedesignStyle.spacingS

        Widgets.TextFieldExt {
            id: field

            Layout.fillWidth: true
            Layout.fillHeight: true

            focus: true

            radius: RedesignStyle.radiusM

            selectByMouse: true

            text: (root.value === undefined || root.value === null) ? "" : String(root.value)

            Accessible.name: root.label
            Accessible.description: root.description

            function showValue() {
                field.text = Qt.binding(() => (root.value === undefined || root.value === null) ? "" : String(root.value))
            }

            onEditingFinished: {
                if (field.text !== String(root.value ?? ""))
                    root.edited(field.text)
                // typing replaces the binding: restore it, the field goes back to what is stored
                showValue()
            }

            Keys.onEscapePressed: (event) => {
                showValue()
                event.accepted = true
            }
        }

        Widgets.ButtonExt {
            Layout.preferredWidth: VLCStyle.dp(100, VLCStyle.scale)
            Layout.fillHeight: true

            visible: root.canBrowse

            text: qsTr("Browse")

            Accessible.name: qsTr("Browse for %1").arg(root.label)

            onClicked: root.browseRequested()
        }
    }
}
