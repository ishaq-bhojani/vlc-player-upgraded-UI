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
import QtQuick.Templates as T

import VLC.Style
import VLC.Redesign

/**
 * @brief A few buttons side by side, one of them chosen (Theme: Dark / Light / System).
 *
 * `model` is [{text, value}], `current` the chosen `value`; a pick is reported by `picked`
 * (nothing is stored here). Left and Right move the choice, Tab leaves the control.
 */
FocusScope {
    id: root

    // Properties

    //! [{text, value}]
    property var model: []

    //! the `value` of the chosen entry
    property var current

    //! the name of the setting, for assistive technologies
    property string label

    //! the user picked `value`
    signal picked(var value)

    // Settings

    implicitWidth: layout.implicitWidth
    implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

    // In a row too narrow for the segments at their width the segments shrink (to this) rather than
    // overflow; in a wider one the control keeps its own width.
    Layout.fillWidth: true
    Layout.minimumWidth: model.length * VLCStyle.dp(40, VLCStyle.scale)
    Layout.maximumWidth: implicitWidth

    Accessible.role: Accessible.RadioButton
    Accessible.name: label

    // moves the choice by `step` entries
    function _move(step: int) {
        const count = model.length
        if (count === 0)
            return
        let index = model.findIndex(entry => entry.value === current)
        index = Math.max(0, Math.min(count - 1, (index < 0 ? 0 : index) + step))
        root.picked(model[index].value)
    }

    // Children

    RowLayout {
        id: layout

        anchors.fill: parent

        spacing: 0

        Repeater {
            model: root.model

            T.AbstractButton {
                id: segment

                required property var modelData
                required property int index

                readonly property bool chosen: modelData.value === root.current

                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumWidth: VLCStyle.dp(40, VLCStyle.scale)

                focus: chosen
                focusPolicy: segment.chosen ? Qt.StrongFocus : Qt.NoFocus

                leftPadding: RedesignStyle.spacingL
                rightPadding: RedesignStyle.spacingL

                implicitWidth: Math.max(VLCStyle.dp(72, VLCStyle.scale),
                                        contentItem.implicitWidth + leftPadding + rightPadding)

                text: modelData.text

                Accessible.role: Accessible.RadioButton
                Accessible.name: text
                Accessible.checked: chosen
                Accessible.onPressAction: segment.clicked()

                Keys.onLeftPressed: root._move(-1)
                Keys.onRightPressed: root._move(1)

                onClicked: root.picked(modelData.value)

                readonly property ColorContext colorContext: ColorContext {
                    id: theme

                    colorSet: segment.chosen ? ColorContext.ButtonAccent : ColorContext.ButtonStandard

                    focused: segment.visualFocus
                    hovered: segment.hovered
                    pressed: segment.down
                }

                background: Rectangle {
                    // the outer corners of the group are round, the inner ones are square
                    radius: RedesignStyle.radiusM

                    color: theme.bg.primary
                    border.width: VLCStyle.dp(2, VLCStyle.scale)
                    border.color: segment.visualFocus ? theme.visualFocus : theme.border
                }

                contentItem: Text {
                    text: segment.text
                    font.pixelSize: VLCStyle.fontSize_normal
                    font.weight: segment.chosen ? Font.DemiBold : Font.Normal
                    color: theme.fg.primary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight

                    Accessible.ignored: true
                }
            }
        }
    }
}
