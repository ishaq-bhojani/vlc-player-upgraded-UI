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
import VLC.MainInterface
import VLC.MediaLibrary

/**
 * @brief The recent media of the main menu: the history of the media library, at most 10 items.
 *
 * It names the media library types (MLRecentMediaModel, MediaLib), which are only registered when
 * the interface has a library: a QML file that names them does not load without, and would take
 * the whole window with it. So MainMenu.qml loads this file by name, and only when
 * MainCtx.mediaLibraryAvailable.
 *
 * The stock menu (menus.cpp, RecentMenu) does the same: the model with a limit of 10, the media
 * is added to the play queue and played (addAndPlay) and "Clear" is MLRecentMediaModel.clearHistory.
 */
Item {
    id: root

    // Properties

    // the history, roles: id, title, fileName, mrl
    readonly property alias model: recentModel

    // Functions

    // adds the media to the play queue and plays it
    function play(mediaId) {
        MediaLib.addAndPlay(mediaId)
    }

    // forgets the history
    function clear() {
        recentModel.clearHistory()
    }

    // Children

    MLRecentMediaModel {
        id: recentModel

        ml: MediaLib
        limit: 10
    }
}
