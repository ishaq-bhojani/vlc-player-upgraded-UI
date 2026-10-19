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
import QtQml

import VLC.MainInterface
import VLC.Style
import VLC.Dialogs
import VLC.Util
import VLC.Redesign

/**
 * @brief The main menu of the redesign, opened by the menu button of the title bar. It replaces
 * the menu bar of the classic interface, which the redesign does not instantiate.
 *
 *   Open file, Open folder, Network stream, Capture device, Open from clipboard
 *   Recent media >  (the last 10 media of the library, Clear)
 *   Convert / Save, Stream
 *   -----
 *   Keyboard shortcuts, Settings, Help >  (Help, About, Messages)
 *
 * Each entry opens the dialog of VLC (DialogsProvider), the same one as the matching entry of the
 * classic menu. The recent media come from the media library (see MainMenuRecent.qml). As in the
 * classic menu, the entry is there only with a media library and with the "save-recentplay"
 * setting on, which is read each time the menu opens (see `openAtGlobal`). The menu closes when
 * the window loses the focus, and before an entry opens its dialog, so it never stays over it.
 */
RedesignMenu {
    id: root

    // Properties

    accessibleName: qsTr("Main menu")

    // whether the setting "save-recentplay" is on, read when the menu opens
    property bool recentSetting: true

    // the entry of the recent media is shown
    readonly property bool recentAvailable: MainCtx.mediaLibraryAvailable && recentSetting

    // the recent media: loaded only with a media library, by name, because the file names types
    // that are not registered without one (see the comment of MainMenuRecent.qml). It is a property
    // and not a child because an item child of a menu is an entry of it.
    readonly property Loader recentSource: Loader {
        active: root.recentAvailable

        source: "MainMenuRecent.qml"
    }

    // the number of recent media in the menu
    readonly property int recentCount: recentSource.item ? recentEntries.count : 0

    // Functions

    // Opens the menu where the point (in global coordinates) is, e.g. under the menu button.
    function openAtGlobal(globalPos) {
        // a change of the setting while the menu was closed is honoured
        const setting = RedesignSettings.item("save-recentplay")
        root.recentSetting = setting ? !!setting.value : true
        _syncRecentEntry()

        const pos = (parent ? parent.mapFromGlobal(globalPos.x, globalPos.y) : globalPos)
        popup(pos.x, pos.y)
    }

    // closes the menu, then runs the action (a dialog): the dialog opens over a menu that is gone
    function _launch(action) {
        dismiss()
        Qt.callLater(action)
    }

    // The entry of the recent media is a menu that is taken out of this one when it is not
    // available, and put back where it was.
    property int _recentIndex: -1

    function _syncRecentEntry() {
        let at = -1
        for (let i = 0; i < count; ++i) {
            if (itemAt(i).subMenu === recentMenu) {
                at = i
                break
            }
        }

        if (recentAvailable && at < 0 && _recentIndex >= 0) {
            insertMenu(_recentIndex, recentMenu)
        } else if (!recentAvailable && at >= 0) {
            _recentIndex = at
            takeMenu(at)
        }
    }

    onRecentAvailableChanged: _syncRecentEntry()

    Component.onCompleted: _syncRecentEntry()

    // Events

    // the menu does not stay open over another window
    readonly property Connections windowConnections: Connections {
        target: MainCtx.intfMainWindow

        function onActiveChanged() {
            if (!MainCtx.intfMainWindow.active)
                root.dismiss()
        }
    }

    // the entries made of the recent media, before the separator and "Clear" of the submenu
    readonly property Instantiator recentEntries: Instantiator {
        model: root.recentSource.item ? root.recentSource.item.model : null

        delegate: RedesignMenuItem {
            required property var model

            text: MediaText.titleText(model.title, model.fileName, model.mrl)

            onTriggered: {
                // the id before the menu closes: the model may change under it
                const mediaId = model.id
                root._launch(() => root.recentSource.item?.play(mediaId))
            }
        }

        onObjectAdded: (index, object) => recentMenu.insertItem(index, object)
        onObjectRemoved: (index, object) => recentMenu.removeItem(object)
    }

    // Children

    RedesignMenuItem {
        text: qsTr("Open file…")

        onTriggered: root._launch(() => DialogsProvider.simpleOpenDialog())
    }

    RedesignMenuItem {
        text: qsTr("Open folder…")

        onTriggered: root._launch(() => DialogsProvider.PLOpenDir())
    }

    RedesignMenuItem {
        text: qsTr("Network stream…")

        // OpenNetworkStreamDialog replaces it when it exists
        onTriggered: root._launch(() => DialogsProvider.openNetDialog())
    }

    RedesignMenuItem {
        text: qsTr("Capture device…")

        onTriggered: root._launch(() => DialogsProvider.openCaptureDialog())
    }

    RedesignMenuItem {
        text: qsTr("Open from clipboard")

        // the dialog is filled with the clipboard
        onTriggered: root._launch(() => DialogsProvider.openUrlDialog())
    }

    RedesignMenu {
        id: recentMenu

        title: qsTr("Recent media")

        // nothing to open (yet, or any more): the entry is dimmed (RedesignMenuItem follows it)
        enabled: root.recentCount > 0

        RedesignMenuSeparator {}

        RedesignMenuItem {
            text: qsTr("Clear")

            onTriggered: root.recentSource.item?.clear()
        }
    }

    RedesignMenuItem {
        text: qsTr("Convert / Save…")

        onTriggered: root._launch(() => DialogsProvider.openAndTranscodingDialogs())
    }

    RedesignMenuItem {
        text: qsTr("Stream…")

        onTriggered: root._launch(() => DialogsProvider.openAndStreamingDialogs())
    }

    RedesignMenuSeparator {}

    RedesignMenuItem {
        text: qsTr("Keyboard shortcuts")

        // KeyboardShortcutsDialog replaces it when it exists: the preferences have the hotkeys
        onTriggered: root._launch(() => DialogsProvider.prefsDialog())
    }

    RedesignMenuItem {
        text: qsTr("Settings")

        // SettingsModal replaces it when it exists
        onTriggered: root._launch(() => DialogsProvider.prefsDialog())
    }

    RedesignMenu {
        title: qsTr("Help")

        RedesignMenuItem {
            text: qsTr("Help")

            onTriggered: root._launch(() => DialogsProvider.helpDialog())
        }

        RedesignMenuItem {
            text: qsTr("About")

            onTriggered: root._launch(() => DialogsProvider.aboutDialog())
        }

        RedesignMenuItem {
            text: qsTr("Messages")

            onTriggered: root._launch(() => DialogsProvider.messagesDialog())
        }
    }
}
