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
import QtQuick.Templates as T

import VLC.Style
import VLC.Redesign

/**
 * @brief The control of a boolean setting: an ON/OFF switch (Figma "Toggle", 68 x 32 with a 2
 * border, a 26 wide knob and the state written on the other half).
 *
 * `value` is shown, never written: the user's change is reported by `edited`, the owner of the
 * setting stores it and `value` follows. Space (or a click) toggles.
 */
T.Switch {
    id: root

    // Properties

    //! the stored value, a boolean
    property var value: false

    //! the name of the setting, for assistive technologies
    property string label

    //! the user chose `newValue`
    signal edited(var newValue)

    // Settings

    readonly property int _border: VLCStyle.dp(2, VLCStyle.scale)
    readonly property int _knobWidth: VLCStyle.dp(26, VLCStyle.scale)

    implicitWidth: VLCStyle.dp(68, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

    // the content (knob and state text) sits inside the border
    padding: _border

    focusPolicy: Qt.StrongFocus

    checked: !!value

    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checked: checked

    onToggled: {
        root.edited(root.checked)
        // a user's toggle replaces the binding: restore it, the knob goes where `value` says
        root.checked = Qt.binding(() => !!root.value)
    }

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.Switch

        enabled: root.enabled
        focused: root.visualFocus
        hovered: root.hovered
        pressed: root.down
    }

    background: Rectangle {
        radius: RedesignStyle.radiusM

        // OFF: the sunken label area, ON: the tinted track
        color: root.checked ? theme.accent : theme.bg.primary

        border.width: root._border
        border.color: root.visualFocus ? theme.visualFocus : theme.border
    }

    contentItem: Item {
        // the state is written on the half the knob is not on
        Text {
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                right: parent.right
            }

            horizontalAlignment: root.checked ? Text.AlignLeft : Text.AlignRight
            leftPadding: root.checked ? RedesignStyle.spacingS : 0
            rightPadding: root.checked ? 0 : RedesignStyle.spacingS

            text: root.checked ? qsTr("ON") : qsTr("OFF")
            font.pixelSize: VLCStyle.fontSize_small
            font.weight: Font.Medium
            color: root.checked ? theme.fg.secondary : theme.fg.primary
        }

        Rectangle {
            id: knob

            y: 0
            width: root._knobWidth
            height: parent.height

            x: root.checked ? parent.width - width : 0

            radius: Math.max(0, RedesignStyle.radiusM - root._border)
            color: root.checked ? theme.bg.secondary : theme.fg.primary

            Behavior on x {
                enabled: theme.initialized

                NumberAnimation {
                    duration: VLCStyle.duration_short
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
