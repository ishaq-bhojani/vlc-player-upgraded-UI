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
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.Playlist
import VLC.Redesign

// The PLAYLIST_BUTTON of the redesign: asks the shell to toggle the Queue panel. As the button
// of upstream (PlaylistPane.PlaylistToggleButton), media dragged over it open the panel after a
// moment, so that they can be dropped into the queue.
Widgets.IconToolButton {
    id: root

    text: VLCIcons.rd_queue
    description: qsTr("Queue")

    onClicked: ShellActions.queueRequested()

    AccessibleCompat.id: "queueButton"

    // Not queueRequested: it toggles. The shell maps the upstream flag to the panel (or the
    // detached window).
    Timer {
        id: openTimer

        interval: VLCStyle.duration_humanMoment

        onTriggered: MainCtx.playqueuePanel.visible = true
    }

    DropArea {
        id: dropArea

        anchors.fill: parent

        onContainsDragChanged: {
            if (containsDrag) {
                openTimer.restart()
                MainCtx.setCursor(Qt.DragCopyCursor)
            } else {
                openTimer.stop()
                MainCtx.restoreCursor()
            }
        }

        // accepted only while the queue is closed (else the drop would be lost: it is dropped
        // into the queue itself); without it containsDrag never becomes true
        onEntered: (drag) => {
            drag.accepted = !MainCtx.playqueuePanel.visible
                            && (drag.hasUrls || Helpers.isValidInstanceOf(drag.source, Widgets.DragItem))
        }

        // dropped on the button (the panel may have opened meanwhile): appended, like a drop below
        // the last item of the queue (see the acceptDropFunc of PlaylistPane)
        onDropped: (drop) => {
            if (Helpers.isValidInstanceOf(drop.source, Widgets.DragItem)) {
                drop.accepted = true
                drop.source.getSelectedInputItem().then((inputItems) => {
                    if (Helpers.isArray(inputItems) && inputItems.length > 0)
                        MainPlaylistController.append(inputItems, false)
                })
            } else if (drop.hasUrls) {
                const urls = []
                for (let i = 0; i < drop.urls.length; ++i)
                    urls.push(drop.urls[i])
                MainPlaylistController.append(urls, false)
                // otherwise the backend may handle the drop as well (double addition), see PlaylistPane
                drop.accept(Qt.IgnoreAction)
            }
        }
    }
}
