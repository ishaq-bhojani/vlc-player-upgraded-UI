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

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Redesign

/**
 * @brief The Home page of the redesign: the rows of HomeContent (Continue Watching, Listen
 * Again, Frequently Visited Folders) and, for Rail > Recent, the whole history.
 *
 * The content uses the types of the media library (MLRecentVideoModel, MediaLib, ...), which
 * are only registered when the interface has a library: a QML file that names them does not
 * load without, and would take the whole window with it. So this page loads HomeContent only
 * when MainCtx.mediaLibraryAvailable, and says so otherwise.
 */
FocusScope {
    id: root

    // Properties

    // upstream pages carry the prefix of the path they were pushed with, the PageLoader sets it
    property var pagePrefix: []

    // Functions

    function setCurrentItemFocus(reason) {
        if (content.item)
            content.item.setCurrentItemFocus(reason)
        else
            noLibrary.forceActiveFocus(reason)
    }

    // Children

    Loader {
        id: content

        anchors.fill: parent

        active: MainCtx.mediaLibraryAvailable
        focus: true

        // by name, not by type: see the comment of the page
        source: "HomeContent.qml"
    }

    Widgets.EmptyLabel {
        id: noLibrary

        anchors.centerIn: parent

        visible: !MainCtx.mediaLibraryAvailable

        cover: VLCStyle.noArtAlbumCover
        text: qsTr("The media library is not available")

        Navigation.parentItem: root
    }
}
