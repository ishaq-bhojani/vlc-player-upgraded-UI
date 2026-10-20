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
import VLC.Redesign

/**
 * @brief The line of a row of a settings page that is not a plain SettingRow (theme, accent,
 * effects...): the name and a caption on the left, the children (a control) on the right. It has
 * the metrics of SettingRow so that the page reads as one list.
 */
Item {
    id: root

    // Properties

    //! the name of the setting
    property string title

    //! a line under the name, also the Accessible.description of the row
    property string description

    //! the change is only applied by the next start
    property bool restart: false

    //! the controls
    default property alias content: slot.data

    // Settings

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(VLCStyle.dp(46, VLCStyle.scale),
                             row.implicitHeight + 2 * RedesignStyle.spacingXS)

    Accessible.role: Accessible.Grouping
    Accessible.name: title
    Accessible.description: description

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    RowLayout {
        id: row

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        spacing: RedesignStyle.spacingM

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            spacing: 0

            Text {
                Layout.fillWidth: true

                text: root.title
                font.pixelSize: VLCStyle.fontSize_normal
                color: theme.fg.primary
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight

                Accessible.ignored: true
            }

            Text {
                Layout.fillWidth: true

                visible: root.description.length > 0

                text: root.description
                font.pixelSize: VLCStyle.fontSize_small
                color: theme.fg.secondary
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight

                Accessible.ignored: true
            }

            Text {
                Layout.fillWidth: true

                visible: root.restart

                text: qsTr("Restart required")
                font.pixelSize: VLCStyle.fontSize_small
                color: theme.fg.secondary
                elide: Text.ElideRight

                Accessible.ignored: true
            }
        }

        RowLayout {
            id: slot

            Layout.alignment: Qt.AlignVCenter

            spacing: RedesignStyle.spacingS
        }
    }
}
