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
import VLC.Redesign

/**
 * @brief A row that is a button: Keyboard shortcuts, the Advanced options links, the extensions.
 * Pressing it emits `action(actionName)`, the page does the rest.
 */
RowFrame {
    id: root

    // Properties

    //! the SettingsData row
    property var spec

    //! what `action` says
    property string actionName

    property string buttonText

    // Signals

    signal action(string name)

    // Settings

    title: spec ? spec.title : ""
    description: spec ? (spec.description ?? "") : ""

    // Children

    Widgets.ButtonExt {
        text: root.buttonText

        Accessible.name: root.title + ", " + root.buttonText

        onClicked: root.action(root.actionName)
    }
}
