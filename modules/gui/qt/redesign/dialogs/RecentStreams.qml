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

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Style
import VLC.Redesign

/**
 * @brief The addresses played lately (MLUrlModel), shown under the address field of
 * OpenNetworkStreamDialog.
 *
 * It names the media library types (MLUrlModel, MediaLib), which are only registered when the
 * interface has a library: a QML file that names them does not load without, and would take the
 * dialog with it. So OpenNetworkStreamDialog.qml loads this file by name, and only when
 * MainCtx.mediaLibraryAvailable. The dialog works without it.
 *
 * Up / Down and a click choose an address (`selected`, the dialog puts it in its field);
 * Enter and a double click play it (`activated`).
 */
ColumnLayout {
    id: root

    // Properties

    //! the number of addresses
    readonly property int count: urlModel.count

    // Signals

    //! the user chose `address`
    signal selected(string address)

    //! the user asked to play `address`
    signal activated(string address)

    // Settings

    spacing: RedesignStyle.spacingXS

    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("Recent streams")

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    MLUrlModel {
        id: urlModel

        ml: MediaLib
    }

    Text {
        Layout.fillWidth: true

        text: qsTr("Recent")

        color: theme.fg.secondary
        font.pixelSize: VLCStyle.fontSize_small
        font.bold: true
    }

    ListView {
        id: list

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, VLCStyle.dp(160, VLCStyle.scale))

        model: urlModel

        clip: true
        currentIndex: -1
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: true
        activeFocusOnTab: true

        Accessible.role: Accessible.List
        Accessible.name: qsTr("Recent streams")

        onCurrentIndexChanged: {
            // only the keys and the clicks choose, not the model filling up
            if (list.activeFocus && currentItem)
                root.selected(currentItem.address)
        }

        Keys.onReturnPressed: (event) => {
            if (currentItem)
                root.activated(currentItem.address)
            event.accepted = true
        }

        Keys.onEnterPressed: (event) => {
            if (currentItem)
                root.activated(currentItem.address)
            event.accepted = true
        }

        delegate: Rectangle {
            id: row

            required property int index
            required property string url
            required property string last_played_date

            readonly property string address: url

            width: ListView.view.width
            height: VLCStyle.dp(32, VLCStyle.scale)

            radius: RedesignStyle.radiusS

            color: (ListView.isCurrentItem && list.activeFocus) ? theme.bg.highlight
                 : mouse.containsMouse ? Qt.alpha(theme.bg.highlight, 0.4)
                 : "transparent"

            Accessible.role: Accessible.ListItem
            Accessible.name: row.url

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: RedesignStyle.spacingS
                anchors.rightMargin: RedesignStyle.spacingS

                spacing: RedesignStyle.spacingM

                Text {
                    Layout.fillWidth: true

                    text: row.url

                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_normal
                    elide: Text.ElideMiddle
                }

                Text {
                    text: row.last_played_date

                    visible: text !== ""

                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_small
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent

                hoverEnabled: true

                onClicked: {
                    list.forceActiveFocus()
                    if (list.currentIndex === row.index)
                        root.selected(row.address)
                    else
                        list.currentIndex = row.index
                }

                onDoubleClicked: root.activated(row.address)
            }
        }
    }
}
