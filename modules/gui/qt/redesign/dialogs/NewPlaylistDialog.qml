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
import VLC.Dialogs
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets
import VLC.Redesign

/**
 * @brief The "New playlist" dialog: asks the name and creates the playlist in the media library
 * (MLPlaylistListModel.create), with the media it was opened for in it.
 *
 * It names the media library types (MLPlaylistListModel, MediaLib), which are only registered when
 * the interface has a library: a QML file that names them does not load without, and would take
 * the window with it. So DialogHost.qml loads this file by name, and only when
 * MainCtx.mediaLibraryAvailable.
 *
 * The creation is asynchronous (the library thread), and the model has to live until it has
 * finished: `pending` tells the host when the dialog may be destroyed.
 */
ModalDialog {
    id: root

    // Properties

    //! the media (library ids) that go into the new playlist, [] for an empty one
    property var initialItems: []

    //! what the user typed, without the spaces around
    readonly property string playlistName: nameField.text.trim()

    readonly property bool valid: playlistName !== ""

    //! the library is still creating the playlist: the dialog is closed but must not be destroyed
    readonly property bool pending: playlistModel.transactionPending

    // Functions

    //! creates the playlist, only when there is a name
    function create() {
        if (!root.valid)
            return
        playlistModel.create(root.playlistName, root.initialItems ?? [])
        root.close()
    }

    // Settings

    title: qsTr("New playlist")

    // the field gets the keyboard each time the dialog opens, and starts empty
    onAboutToShow: {
        nameField.text = ""
        nameField.forceActiveFocus()
    }

    // Children

    MLPlaylistListModel {
        id: playlistModel

        ml: MediaLib
    }

    contentItem: ColumnLayout {
        implicitWidth: VLCStyle.dp(380, VLCStyle.scale)

        // a popup is not under the ColorContext of the window: the content and the footer have
        // their own, or the controls in them get no palette (and are drawn magenta)
        readonly property ColorContext colorContext: ColorContext {
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        // a popup is not an Item: the dialog is described by its content
        Accessible.role: Accessible.Dialog
        Accessible.name: root.title

        spacing: VLCStyle.margin_small

        Text {
            Layout.fillWidth: true

            text: (root.initialItems?.length ?? 0) > 0
                  ? qsTr("Name of the playlist that will hold the %n selected item(s).", "", root.initialItems.length)
                  : qsTr("Name of the new playlist.")

            color: root.colorContext.fg.secondary
            font.pixelSize: VLCStyle.fontSize_small
            wrapMode: Text.WordWrap
        }

        Widgets.TextFieldExt {
            id: nameField

            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)

            focus: true
            selectByMouse: true

            radius: RedesignStyle.radiusM

            placeholderText: qsTr("Playlist name")

            Accessible.role: Accessible.EditableText
            Accessible.name: qsTr("Playlist name")

            // Enter creates, only when there is a name
            onAccepted: root.create()
        }
    }

    footer: RowLayout {
        spacing: VLCStyle.margin_small

        // the footer is not under the content: its own context (see the content)
        readonly property ColorContext colorContext: ColorContext {
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        Item { Layout.fillWidth: true }

        Widgets.ButtonExt {
            text: qsTr("Cancel")

            onClicked: root.close()
        }

        Widgets.ButtonExt {
            text: qsTr("Create")

            enabled: root.valid
            font.bold: true

            colorContext.colorSet: ColorContext.ButtonAccent

            Accessible.name: qsTr("Create the playlist")

            onClicked: root.create()
        }
    }
}
