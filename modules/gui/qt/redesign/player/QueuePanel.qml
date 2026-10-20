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
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.Playlist
import VLC.Dialogs
import VLC.Redesign

/**
 * @brief The content of the right panel in the "queue" mode: a header (Queue, Clear, Save) over
 * the play queue of upstream (PlaylistPane, reused as is: the list, the sort, the search, the
 * context menu and the drag and drop of the media of the library into the queue are its own).
 *
 * Clear is what the context menu of the play queue does (MainPlaylistController.clear(), no
 * confirmation, no undo). Save puts the queue into a playlist of the media library, with the dialog
 * of VLC that asks the name (it creates the playlist with MLPlaylistListModel.create), or, without a
 * media library, saves it to a file (the "Save Play Queue to File" action). The media library types
 * are not used here: they do not exist without a media library.
 *
 * Media dropped on the header (outside of the list) are appended to the queue.
 */
FocusScope {
    id: root

    // Properties

    readonly property int count: MainPlaylistController.count

    readonly property alias pane: pane

    // Functions

    function clear() {
        MainPlaylistController.clear()
    }

    // Saves the queue: into a playlist of the media library when there is one, else to a file.
    function save() {
        if (count <= 0)
            return

        if (MainCtx.mediaLibraryAvailable) {
            const indexes = []
            for (let i = 0; i < count; ++i)
                indexes.push(i)
            DialogsProvider.playlistsDialog(pane.model.getItemsForIndexes(indexes))
        } else {
            DialogsProvider.savePlayingToPlaylist()
        }
    }

    // The first label of the pane is its own "Play Queue" title: this header has one, the label
    // keeps its room so that the sort and the search stay at the end of the line.
    function _blankPaneTitle() {
        const stack = [pane.contentItem]
        while (stack.length > 0) {
            const item = stack.pop()
            if (Helpers.isValidInstanceOf(item, Widgets.SubtitleLabel)) {
                item.text = ""
                return
            }
            for (let i = item.children.length - 1; i >= 0; --i)
                stack.push(item.children[i])
        }
    }

    // Signals

    // Escape / Backspace, or the panel has to close
    signal closeRequested()

    // Settings

    focus: true

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Queue")
    AccessibleCompat.id: "queuePanel"

    activeFocusOnTab: true

    Navigation.cancelAction: function() { root.closeRequested() }

    Component.onCompleted: _blankPaneTitle()

    // Children

    ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    // media dropped outside of the list (the header): appended, like a drop below the last item
    DropArea {
        anchors.fill: parent
        z: -1

        onEntered: (drag) => {
            drag.accepted = pane.isDropAcceptableFunc(drag, root.count)
        }

        onDropped: (drop) => {
            drop.accepted = true
            pane.acceptDropFunc(root.count, drop)
        }
    }

    RowLayout {
        id: header

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: RedesignStyle.spacingL
            rightMargin: RedesignStyle.spacingS
        }

        height: RedesignStyle.titleBarHeight
        spacing: RedesignStyle.spacingXS

        Text {
            Layout.fillWidth: true

            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            text: qsTr("Queue")
            font.pixelSize: VLCStyle.fontSize_large
            font.weight: Font.Bold
            color: theme.fg.primary

            Accessible.role: Accessible.Heading
            Accessible.name: text
        }

        Widgets.TextToolButton {
            id: clearButton

            enabled: root.count > 0

            text: qsTr("Clear")
            AccessibleCompat.id: "queueClear"

            Navigation.parentItem: root
            Navigation.rightItem: saveButton
            Navigation.downItem: pane

            onClicked: root.clear()
        }

        Widgets.TextToolButton {
            id: saveButton

            enabled: root.count > 0

            text: qsTr("Save as playlist")
            AccessibleCompat.id: "queueSave"

            Navigation.parentItem: root
            Navigation.leftItem: clearButton
            Navigation.downItem: pane

            onClicked: root.save()
        }
    }

    PlaylistPane {
        id: pane

        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            bottom: parent.bottom
        }

        focus: true

        useAcrylic: false
        verticalPadding: 0
        topPadding: RedesignStyle.spacingS

        // opaque (the fading edge of the list needs it), the colors of the pane are the View ones
        background: Rectangle {
            color: theme.bg.primary
        }

        Navigation.parentItem: root
        Navigation.upItem: clearButton
    }
}
