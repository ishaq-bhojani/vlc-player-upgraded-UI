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

import VLC.Dialogs
import VLC.Style
import VLC.Util

/**
 * @brief The base of the modal dialogs of the redesign: a ModalDialog whose body and footer have a
 * palette.
 *
 * A Popup is not an Item of the window, so the ColorContext of the window does not reach it: the
 * controls in a dialog (buttons, text fields) find no palette and are drawn magenta, unless the
 * content and the footer each sit in their own ColorContext. This type does that once, so that a
 * dialog only writes its body and its buttons:
 *
 *   RedesignModalDialog {
 *       title: qsTr("New playlist")
 *       bodyWidth: VLCStyle.dp(380, VLCStyle.scale)
 *
 *       Text { Layout.fillWidth: true; ... }          // the body (a ColumnLayout)
 *       Widgets.TextFieldExt { ... }
 *
 *       footerItems: [                                // the buttons, after a spacer (a RowLayout)
 *           Widgets.ButtonExt { text: qsTr("Cancel"); onClicked: root.close() },
 *           Widgets.ButtonExt { text: qsTr("Create"); colorContext.colorSet: ColorContext.ButtonAccent }
 *       ]
 *   }
 *
 * `colorContext` (the one of ModalDialog) gives the colours for the texts of the body. The dialog
 * is described to assistive technologies by its body (a popup is not an Item).
 *
 * Whoever shows the dialog sets `rootWindow` (the item that is blurred behind it) and calls
 * `open()`: DialogHost.qml does.
 */
ModalDialog {
    id: root

    // Properties

    //! the items of the body, a ColumnLayout: they use Layout.* like in any layout
    default property alias body: bodyLayout.data

    //! the buttons of the footer, placed to the right of the free room of a RowLayout
    property alias footerItems: footerLayout.data

    //! the width the body asks for
    property real bodyWidth: VLCStyle.dp(420, VLCStyle.scale)

    //! the space between the items of the body
    property alias bodySpacing: bodyLayout.spacing

    // Settings

    contentItem: ColumnLayout {
        id: bodyLayout

        implicitWidth: root.bodyWidth

        // this context is the one of everything in the body (see above)
        readonly property ColorContext bodyContext: ColorContext {
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        Accessible.role: Accessible.Dialog
        Accessible.name: root.title

        spacing: VLCStyle.margin_small
    }

    footer: RowLayout {
        id: footerLayout

        // the footer is not under the body: its own context
        readonly property ColorContext footerContext: ColorContext {
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        spacing: VLCStyle.margin_small

        Item { Layout.fillWidth: true }
    }
}
