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
import QtQuick.Templates as T

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Redesign

/**
 * @brief The "Keyboard shortcuts" dialog: the same page as the Settings modal shows under
 * Controls (ShortcutsPage: the list of actions with search, click a key to record a new one, a
 * prompt when the key is already used), in a dialog of its own, so that it can be opened from the
 * main menu without the Settings.
 *
 * There is no second copy of the recording and conflict logic: this file only hosts the page.
 * It does not host itself anywhere: DialogHost.qml creates it and opens it. Esc closes it, except
 * while the page waits for a key (Esc then cancels the recording).
 */
RedesignModalDialog {
    id: root

    // Properties

    // the room around the dialog in the window
    readonly property real _windowWidth: T.Overlay.overlay ? T.Overlay.overlay.width : VLCStyle.dp(800, VLCStyle.scale)
    readonly property real _windowHeight: T.Overlay.overlay ? T.Overlay.overlay.height : VLCStyle.dp(600, VLCStyle.scale)

    // Settings

    title: qsTr("Keyboard shortcuts")

    bodyWidth: Math.min(VLCStyle.dp(640, VLCStyle.scale),
                        Math.max(VLCStyle.dp(320, VLCStyle.scale),
                                 root._windowWidth - 2 * (root.margins + root.padding)))

    // the filter gets the keyboard each time the dialog opens: typing narrows the list at once
    onAboutToShow: page.focusFilter()

    // Children

    ShortcutsPage {
        id: page

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(VLCStyle.dp(520, VLCStyle.scale),
                                         Math.max(VLCStyle.dp(240, VLCStyle.scale),
                                                  root._windowHeight * 0.7 - VLCStyle.dp(120, VLCStyle.scale)))

        showBack: false
        showTitle: false
    }

    footerItems: [
        Widgets.ButtonExt {
            text: qsTr("Close")

            Accessible.name: qsTr("Close the keyboard shortcuts")

            onClicked: root.close()
        }
    ]
}
