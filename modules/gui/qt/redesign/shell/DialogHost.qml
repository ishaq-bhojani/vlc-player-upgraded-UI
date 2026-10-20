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
 *   settingsRequested(page)       -> SettingsModal (also Ctrl+P, see the Shortcut below)
 *
 * The dialogs are based on RedesignModalDialog (a palette for what is in a popup); SettingsModal
 * is not a dialog but its popup has the same need and does it itself.
 *
 * The dialogs that name types of the media library are loaded by name and only when
 * MainCtx.mediaLibraryAvailable (the types are not registered without one, and a file that names
 * them takes the window with it); a request for one of them without a library does nothing, and
 * is logged.
 *
 * The state of a dialog is two flags:
 *   `Open`    the dialog is shown (or about to be): set by a request, cleared by the dialog's `closed`
 *   `Loaded`  the Loader is active: set by a request, cleared a moment after `closed` (the dialog is
 *             in the middle of its own signal then) and only if the dialog was not opened again in
 *             the meantime and is not busy (NewPlaylistDialog.pending: the library is still creating
 *             the playlist, the model must outlive the dialog)
 * A request while a dialog is `Open` is ignored: one modal at a time. A request while the Loader of
 * that dialog still exists (closed, not yet released) opens the existing item again, as the
 * Loader will not load it a second time. A request for the playlist dialog while its playlist is
 * being created is ignored (and logged). A Loader that fails (status Error) clears both flags, so
 * the next request starts afresh instead of jamming the host.
 *
 * To host another dialog: a Loader, the two flags, a request in ShellActions.
 */
Item {
    id: root

    // Properties

    //! the item the dialogs blur behind them (when the backdrop blur is on), the content of the window
    property Item backdrop: null

    //! a dialog is open (or still being closed)
    readonly property bool active: _networkStreamOpen || _newPlaylistOpen || _settingsOpen

    // the media of the playlist being created
    property var _newPlaylistItems: []

    // `Open`: the dialog is shown; `Loaded`: it exists (it stays a little longer than it is shown)
    property bool _networkStreamOpen: false
    property bool _networkStreamLoaded: false
    property bool _newPlaylistOpen: false
    property bool _newPlaylistLoaded: false
    property bool _settingsOpen: false
    property bool _settingsLoaded: false

    // the page the Settings modal opens on
    property string _settingsPage: ""

    // Signals

    //! a dialog was closed
    signal closed()

    // Functions

    // One modal at a time: a request while a dialog is open is ignored.
    function openNetworkStream() {
        if (active)
            return
        _networkStreamOpen = true
        if (networkStreamLoader.item)
            _show(networkStreamLoader.item)
        else
            _networkStreamLoaded = true // onLoaded shows it
    }

    function openNewPlaylist(mediaIds) {
        if (!MainCtx.mediaLibraryAvailable) {
            console.warn("DialogHost: no media library, the playlist can not be created")
            return
        }
        if (active)
            return
        if (newPlaylistLoader.item?.pending) {
            console.warn("DialogHost: the previous playlist is still being created")
            return
        }
        _newPlaylistItems = mediaIds ?? []
        _newPlaylistOpen = true
        if (newPlaylistLoader.item) {
            newPlaylistLoader.item.initialItems = _newPlaylistItems
            _show(newPlaylistLoader.item)
        } else {
            _newPlaylistLoaded = true // onLoaded shows it
        }
    }

    //! `page`: an id of SettingsData.pages, "shortcuts" or "" (see SettingsModal.open)
    function openSettings(page) {
        if (active)
            return
        _settingsPage = page ?? ""
        _settingsOpen = true
        if (settingsLoader.item)
            settingsLoader.item.open(_settingsPage)
        else
            _settingsLoaded = true // onLoaded shows it
    }

    function _show(dialog) {
        dialog.rootWindow = root.backdrop
        dialog.open()
    }

    // Destroys the dialog of `loader` once it is closed: later, the dialog is in the middle of its
    // own `closed` signal. The playlist dialog stays while the library creates the playlist.
    function _networkStreamRelease() {
        Qt.callLater(() => {
            if (!root._networkStreamOpen)
                root._networkStreamLoaded = false
        })
    }

    function _settingsRelease() {
        Qt.callLater(() => {
            if (!root._settingsOpen)
                root._settingsLoaded = false
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

        function onSettingsRequested(page) {
            root.openSettings(page)
        }
    }

    // Ctrl+P opens the Settings modal. The stock shortcut of the same key (GlobalShortcuts.qml,
    // loaded by the shell) is turned off by the shell, or the two would be ambiguous and neither
    // would fire. Like the stock ones it follows MainCtx.useGlobalShortcuts.
    Shortcut {
        sequence: "Ctrl+P"
        context: Qt.ApplicationShortcut
        enabled: MainCtx.useGlobalShortcuts

        onActivated: root.openSettings("")
    }

    // Children

    Loader {
        id: networkStreamLoader

        active: root._networkStreamLoaded

        source: "OpenNetworkStreamDialog.qml"

        onLoaded: root._show(item)

        onStatusChanged: {
            if (status === Loader.Error) {
                root._networkStreamOpen = false
                root._networkStreamLoaded = false
            }
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

    Loader {
        id: settingsLoader

        active: root._settingsLoaded

        source: "SettingsModal.qml"

        onLoaded: item.open(root._settingsPage)

        onStatusChanged: {
            if (status === Loader.Error) {
                root._settingsOpen = false
                root._settingsLoaded = false
            }
        }
    }

    Connections {
        target: settingsLoader.item

        function onClosed() {
            root._settingsOpen = false
            root._settingsRelease()
            root.closed()
        }
    }

    // the dialog names MLPlaylistListModel: loaded by name, only with a media library
    Loader {
        id: newPlaylistLoader

        active: root._newPlaylistLoaded && MainCtx.mediaLibraryAvailable

        source: "NewPlaylistDialog.qml"

        onLoaded: {
            item.initialItems = root._newPlaylistItems
            root._show(item)
        }

        onStatusChanged: {
            if (status === Loader.Error) {
                root._newPlaylistOpen = false
                root._newPlaylistLoaded = false
            }
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
