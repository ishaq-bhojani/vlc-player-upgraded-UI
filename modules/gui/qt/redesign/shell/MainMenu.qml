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
import QtQuick.Templates as T

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
 * classic menu. The recent media come from the media library (see MainMenuRecent.qml), without a
 * media library the entry is disabled and says so.
 *
 * The menu closes when the window loses the focus (see `openAtGlobal` for opening it), and before
 * an entry opens its dialog, so it never stays over it.
 */
RedesignMenu {
    id: root

    // Properties

    // the recent media: loaded only with a media library, by name, because the file names types
    // that are not registered without one (see the comment of MainMenuRecent.qml). It is a property
    // and not a child because an item child of a menu is an entry of it.
    readonly property Loader recentSource: Loader {
        active: MainCtx.mediaLibraryAvailable

        source: "MainMenuRecent.qml"
    }

    // the number of recent media in the menu
    readonly property int recentCount: recentSource.item ? recentEntries.count : 0

    // Functions

    // Opens the menu where the point (in global coordinates) is, e.g. under the menu button.
    function openAtGlobal(globalPos) {
        const pos = (parent ? parent.mapFromGlobal(globalPos.x, globalPos.y) : globalPos)
        popup(pos.x, pos.y)
    }

    // closes the menu, then runs the action (a dialog): the dialog opens over a menu that is gone
    function _launch(action) {
        dismiss()
        Qt.callLater(action)
    }

    // Settings

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

            onTriggered: root._launch(() => root.recentSource.item.play(model.id))
        }

        onObjectAdded: (index, object) => recentMenu.insertItem(index, object)
        onObjectRemoved: (index, object) => recentMenu.removeItem(object)
    }

    component Separator: T.MenuSeparator {
        implicitWidth: contentItem.implicitWidth
        implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding

        topPadding: RedesignStyle.spacingXS
        bottomPadding: RedesignStyle.spacingXS

        readonly property ColorContext colorContext: ColorContext {
            id: separatorTheme

            palette: VLCStyle.palette
            colorSet: ColorContext.MenuBar
        }

        contentItem: Rectangle {
            implicitHeight: 1

            color: separatorTheme.separator
        }
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

        title: MainCtx.mediaLibraryAvailable ? qsTr("Recent media")
                                             : qsTr("Recent media (media library is off)")

        // nothing to open: no media library, or an empty history
        enabled: root.recentCount > 0

        Separator {}

        RedesignMenuItem {
            text: qsTr("Clear")

            onTriggered: root.recentSource.item.clear()
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

    Separator {}

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
