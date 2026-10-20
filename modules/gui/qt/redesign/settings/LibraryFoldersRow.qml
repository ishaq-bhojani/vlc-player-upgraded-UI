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
import VLC.Style
import VLC.Redesign

/**
 * @brief The folders the media library scans (Library page).
 *
 * The list is the MLFolderModel of the media library. Its types are only registered when the
 * interface has a library: a QML file that names them does not load without, and would take the
 * window with it. So LibraryFolders.qml, which names them, is loaded by name and only when
 * MainCtx.mediaLibraryAvailable; otherwise this row says that the library is off.
 */
Item {
    id: root

    // Properties

    //! the SettingsData row
    property var spec

    // Settings

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight + 2 * RedesignStyle.spacingXS

    Accessible.role: Accessible.Grouping
    Accessible.name: spec ? spec.title : ""

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    ColumnLayout {
        id: layout

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        spacing: RedesignStyle.spacingS

        Text {
            Layout.fillWidth: true

            text: root.spec ? root.spec.title : ""
            font.pixelSize: VLCStyle.fontSize_normal
            color: theme.fg.primary
            elide: Text.ElideRight

            Accessible.ignored: true
        }

        // by name, not by type: see the comment of the row
        Loader {
            Layout.fillWidth: true

            active: MainCtx.mediaLibraryAvailable
            visible: active

            source: "LibraryFolders.qml"
        }

        // the library is off: the folders are not available
        Text {
            Layout.fillWidth: true

            visible: !MainCtx.mediaLibraryAvailable

            text: qsTr("Media library is off. Turn on \"Enable media library\" above and restart to choose its folders.")
            font.pixelSize: VLCStyle.fontSize_small
            color: theme.fg.secondary
            wrapMode: Text.WordWrap
        }
    }
}
