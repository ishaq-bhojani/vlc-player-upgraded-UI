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

import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Playlist
import VLC.Util

// Restarts the current media from the beginning and makes sure it plays.
Widgets.IconToolButton {
    // also usable once playback has ended: the player is not started then, but the playlist
    // still has a current item
    enabled: Player.isStarted || (!MainPlaylistController.empty && MainPlaylistController.currentIndex >= 0)

    text: VLCIcons.history // stands in for rd_replay
    description: qsTr("Replay")

    onClicked: {
        // MainPlaylistController.play() does nothing while the player is started (paused
        // included), so a started player is rewound and resumed explicitly. A player that is
        // not started (stopped, or playback ended) restarts the current media from the beginning.
        switch (ReplayLogic.replayAction(Player.isStarted,
                                         Player.playingState === Player.PLAYING_STATE_PAUSED)) {
        case "seekResume":
            Player.jumpToPos(0.0)
            MainPlaylistController.togglePlayPause()
            break
        case "seek":
            Player.jumpToPos(0.0)
            break
        case "start":
            MainPlaylistController.play()
            break
        }
    }

    AccessibleCompat.id: "replayButton"
}
