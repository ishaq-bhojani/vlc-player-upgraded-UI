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
import QtQuick.Layouts
import QtQuick.Templates as T

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

    // The padding of a dialog is the one of its body only: the header and the footer span the whole
    // popup. Both get the padding of the body here, so the title and the buttons line up with it
    // (the header of ModalDialog has a padding of its own, 6 px, and the footer had none: the
    // buttons touched the edges).
    header: T.Label {
        readonly property ColorContext headerContext: ColorContext {
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        visible: root.title !== ""

        leftPadding: root.leftPadding
        rightPadding: root.rightPadding
        topPadding: root.topPadding
        bottomPadding: 0

        text: root.title
        elide: Text.ElideRight
        font.bold: true
        color: headerContext.fg.primary
    }

    footer: T.Pane {
        leftPadding: root.leftPadding
        rightPadding: root.rightPadding
        bottomPadding: root.bottomPadding
        topPadding: 0

        // a template Pane computes no size of its own
        implicitWidth: implicitContentWidth + leftPadding + rightPadding
        implicitHeight: implicitContentHeight + topPadding + bottomPadding

        contentItem: RowLayout {
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
}
