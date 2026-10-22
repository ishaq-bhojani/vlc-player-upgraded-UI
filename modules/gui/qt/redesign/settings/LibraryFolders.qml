/*****************************************************************************
 * Copyright (C) 2026 Vireo contributors
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
 * A folder is added with the native folder dialog (Browse), or by typing or pasting its path.
 */
ColumnLayout {
    id: root

    // Functions

    function addFolder() {
        const url = SettingsData.localUrl(field.text)
        if (url.length === 0)
            return
        foldersModel.add(url)
        field.text = ""
    }

    // the native folder dialog of the main window; a cancel adds nothing
    function browseFolder() {
        const path = SettingsBridge.pickFolder(qsTr("Add a folder to the media library"), "")
        const url = SettingsData.localUrl(path)
        if (url.length > 0)
            foldersModel.add(url)
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

    // The Browse button, the field for the path of a folder and the Add folder button. In a narrow
    // page (the owner's window is 600 dp wide: the page is about 320) the field would get ~110 dp
    // between the two buttons, so Add folder goes to a line of its own under the other two. The
    // items stay in the order of the keyboard (Browse, field, Add folder) in both layouts, so Tab
    // follows what is drawn.
    GridLayout {
        id: addRow

        readonly property bool narrow: root.width < VLCStyle.dp(440, VLCStyle.scale)

        Layout.fillWidth: true

        columns: narrow ? 2 : 3
        columnSpacing: RedesignStyle.spacingS
        rowSpacing: RedesignStyle.spacingS

        Widgets.ButtonExt {
            id: browseButton

            Layout.row: 0
            Layout.column: 0

            text: qsTr("Browse...")

            Accessible.name: qsTr("Browse for a folder to add")

            onClicked: root.browseFolder()
        }

        Widgets.TextFieldExt {
            id: field

            Layout.row: 0
            Layout.column: 1
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)

            radius: RedesignStyle.radiusM
            selectByMouse: true

            placeholderText: qsTr("Path of a folder to add")

            Accessible.name: qsTr("Folder to add")

            onAccepted: root.addFolder()
        }

        Widgets.ButtonExt {
            Layout.row: addRow.narrow ? 1 : 0
            Layout.column: addRow.narrow ? 0 : 2
            Layout.columnSpan: addRow.narrow ? 2 : 1
            Layout.fillWidth: addRow.narrow

            text: qsTr("Add folder")

            enabled: field.text.trim().length > 0

            onClicked: root.addFolder()
        }
    }
}
