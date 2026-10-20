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
 * @brief The accent row of the settings: the 9 swatches of Figma, the chosen one ringed.
 *
 * A pick is stored as "#rrggbb" in qt-accent-color (RedesignSettings.accentSwatches are written
 * that way). The accent is read once at startup: the row says so (Restart required).
 */
RowFrame {
    id: root

    // Properties

    //! the SettingsData row
    property var spec

    //! qt-accent-color
    readonly property var setting: RedesignSettings.item("qt-accent-color")

    //! "#rrggbb", or "default" / "system" while no swatch was picked
    readonly property string current: setting ? String(setting.value).toLowerCase() : "default"

    // the names of the swatches, in the order of RedesignSettings.accentSwatches (tokens.md Table C)
    readonly property var names: [qsTr("Orange"), qsTr("Red"), qsTr("Gold"), qsTr("Green"), qsTr("Teal"),
                                  qsTr("Blue"), qsTr("Purple"), qsTr("Pink"), qsTr("Grey")]

    // Settings

    title: setting ? setting.text : ""
    restart: setting ? setting.requiresRestart : false

    // Children

    Repeater {
        model: RedesignSettings.accentSwatches

        T.AbstractButton {
            id: swatch

            required property string modelData
            required property int index

            // "default" is the first swatch (the default accent). "system" (the accent of the
            // operating system, only set by hand in the configuration file) is none of the
            // swatches: nothing is ringed on purpose, picking a swatch replaces it.
            readonly property bool chosen: root.current === modelData
                                           || (index === 0 && root.current === "default")

            implicitWidth: VLCStyle.dp(28, VLCStyle.scale)
            implicitHeight: implicitWidth

            focusPolicy: Qt.StrongFocus
            hoverEnabled: true

            Accessible.role: Accessible.RadioButton
            Accessible.name: root.names[index] ?? modelData
            Accessible.checked: chosen
            Accessible.onPressAction: swatch.clicked()

            onClicked: {
                if (root.setting)
                    root.setting.value = modelData
            }

            readonly property ColorContext colorContext: ColorContext {
                id: theme

                colorSet: ColorContext.View

                focused: swatch.visualFocus
                hovered: swatch.hovered
            }

            background: Rectangle {
                radius: width / 2
                color: "transparent"

                // the ring of the chosen swatch, or the focus
                border.width: (swatch.chosen || swatch.visualFocus) ? VLCStyle.dp(2, VLCStyle.scale) : 0
                border.color: swatch.visualFocus ? theme.visualFocus : theme.fg.primary
            }

            contentItem: Rectangle {
                radius: width / 2
                color: swatch.modelData
            }

            // the gap between the ring and the color
            padding: VLCStyle.dp(4, VLCStyle.scale)
        }
    }
}
