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

import VLC.MediaLibrary

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Redesign

/**
 * @brief The folder list of the Library page: each folder with a Remove button, and a field to add
 * one. It names MLFolderModel, so it is only loaded when the interface has a media library (see
 * LibraryFoldersRow).
 *
 * There is no folder dialog in QML (the static Qt build has no QtQuick.Dialogs): a folder is added
 * by typing or pasting its path.
 */
ColumnLayout {
    id: root

    // Functions

    // "C:\Music" or "/home/me/Music" or already a URL -> the url the model wants
    function toUrl(path: string): string {
        const text = path.trim()
        if (text.length === 0)
            return ""
        if (/^[a-zA-Z][a-zA-Z0-9+.-]+:\/\//.test(text))
            return text
        const slashes = text.replace(/\\/g, "/")
        return slashes.startsWith("/") ? "file://" + slashes : "file:///" + slashes
    }

    function addFolder() {
        const url = root.toUrl(field.text)
        if (url.length === 0)
            return
        foldersModel.add(url)
        field.text = ""
    }

    // Settings

    spacing: RedesignStyle.spacingS

    // Models

    MLFolderModel {
        id: foldersModel

        ctx: MainCtx
    }

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    Repeater {
        id: folders

        model: foldersModel

        RowLayout {
            id: folder

            required property int index
            required property string display_url

            Layout.fillWidth: true

            spacing: RedesignStyle.spacingS

            Text {
                Layout.fillWidth: true

                text: folder.display_url
                font.pixelSize: VLCStyle.fontSize_normal
                color: theme.fg.primary
                elide: Text.ElideMiddle

                Accessible.ignored: true
            }

            Widgets.ButtonExt {
                text: qsTr("Remove")

                Accessible.name: qsTr("Remove %1").arg(folder.display_url)

                onClicked: foldersModel.removeAt(folder.index)
            }
        }
    }

    Text {
        Layout.fillWidth: true

        visible: folders.count === 0

        text: qsTr("No folder yet.")
        font.pixelSize: VLCStyle.fontSize_small
        color: theme.fg.secondary
    }

    RowLayout {
        Layout.fillWidth: true

        spacing: RedesignStyle.spacingS

        Widgets.TextFieldExt {
            id: field

            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)

            radius: RedesignStyle.radiusM
            selectByMouse: true

            placeholderText: qsTr("Path of a folder to add")

            Accessible.name: qsTr("Folder to add")

            onAccepted: root.addFolder()
        }

        Widgets.ButtonExt {
            text: qsTr("Add folder")

            enabled: field.text.trim().length > 0

            onClicked: root.addFolder()
        }
    }
}
