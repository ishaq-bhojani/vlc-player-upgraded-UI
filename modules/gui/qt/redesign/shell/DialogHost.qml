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
import VLC.Redesign

/**
 * @brief The host of the modal dialogs of the redesign. RedesignInterface instantiates it once.
 *
 * A dialog is a Loader that is active only while the dialog is open: nothing of it exists the rest
 * of the time. The host connects to the requests of ShellActions, opens the dialog, and says
 * `closed()` when it has been closed so that the owner can give the keyboard back.
 *
 *   networkStreamRequested()      -> OpenNetworkStreamDialog
 *   newPlaylistRequested(ids)     -> NewPlaylistDialog (media library only)
 *
 * The dialogs that name types of the media library are loaded by name and only when
 * MainCtx.mediaLibraryAvailable (the types are not registered without one, and a file that names
 * them takes the window with it); a request for one of them without a library does nothing, and
 * is logged.
 *
 * To host another dialog: a Loader, a `_xxxOpen` flag, a request in ShellActions.
 */
Item {
    id: root

    // Properties

    //! the item the dialogs blur behind them (when the backdrop blur is on), the content of the window
    property Item backdrop: null

    //! a dialog is open (or still being closed)
    readonly property bool active: _networkStreamOpen || _newPlaylistOpen

    // the media of the playlist being created
    property var _newPlaylistItems: []

    // `Open`: the dialog is shown; `Loaded`: it exists (it stays a little longer than it is shown)
    property bool _networkStreamOpen: false
    property bool _networkStreamLoaded: false
    property bool _newPlaylistOpen: false
    property bool _newPlaylistLoaded: false

    // Signals

    //! a dialog was closed
    signal closed()

    // Functions

    // One modal at a time: a request while a dialog is open is ignored.
    function openNetworkStream() {
        if (active)
            return
        _networkStreamLoaded = true
        _networkStreamOpen = true
    }

    function openNewPlaylist(mediaIds) {
        if (!MainCtx.mediaLibraryAvailable) {
            console.warn("DialogHost: no media library, the playlist can not be created")
            return
        }
        if (active)
            return
        _newPlaylistItems = mediaIds ?? []
        _newPlaylistLoaded = true
        _newPlaylistOpen = true
    }

    // Destroys the dialog of `loader` once it is closed: later, the dialog is in the middle of its
    // own `closed` signal. The playlist dialog stays while the library creates the playlist.
    function _networkStreamRelease() {
        Qt.callLater(() => {
            if (!root._networkStreamOpen)
                root._networkStreamLoaded = false
        })
    }

    function _newPlaylistRelease() {
        Qt.callLater(() => {
            if (!root._newPlaylistOpen && !(newPlaylistLoader.item?.pending ?? false))
                root._newPlaylistLoaded = false
        })
    }

    // Settings

    width: 0
    height: 0

    // Events

    Connections {
        target: ShellActions

        function onNetworkStreamRequested() {
            root.openNetworkStream()
        }

        function onNewPlaylistRequested(mediaIds) {
            root.openNewPlaylist(mediaIds)
        }
    }

    // Children

    Loader {
        id: networkStreamLoader

        active: root._networkStreamLoaded

        source: "OpenNetworkStreamDialog.qml"

        onLoaded: {
            item.rootWindow = root.backdrop
            item.open()
        }
    }

    Connections {
        target: networkStreamLoader.item

        function onClosed() {
            root._networkStreamOpen = false
            root._networkStreamRelease()
            root.closed()
        }
    }

    // the dialog names MLPlaylistListModel: loaded by name, only with a media library
    Loader {
        id: newPlaylistLoader

        active: root._newPlaylistLoaded && MainCtx.mediaLibraryAvailable

        source: "NewPlaylistDialog.qml"

        onLoaded: {
            item.rootWindow = root.backdrop
            item.initialItems = root._newPlaylistItems
            item.open()
        }
    }

    Connections {
        target: newPlaylistLoader.item

        function onClosed() {
            root._newPlaylistOpen = false
            root._newPlaylistRelease()
            root.closed()
        }

        // the library finished creating the playlist while the dialog was closed
        function onPendingChanged() {
            if (!root._newPlaylistOpen)
                root._newPlaylistRelease()
        }
    }
}
