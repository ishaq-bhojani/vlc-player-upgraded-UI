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
import QtQuick.Templates as T
import QtQuick.Window

import VLC.MainInterface
import VLC.Style
import VLC.Redesign

/**
 * @brief A menu in the style of the redesign: the popup of the menu bar of the palette
 * (ColorContext.MenuBar) with rounded corners, and RedesignMenuItem for its entries and submenus.
 *
 * The keys, the submenus and the focus are the ones of the Qt Quick Controls Menu: Up, Down, Home
 * and End move, Right opens a submenu, Left and Esc close it, Space and Enter choose.
 */
T.Menu {
    id: control

    // Settings

    margins: 0
    padding: RedesignStyle.spacingXS

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding)

    // used for the entries made from a model, and for the entry of a submenu
    delegate: RedesignMenuItem {}

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        palette: VLCStyle.palette
        colorSet: ColorContext.MenuBar
    }

    contentItem: ListView {
        implicitHeight: contentHeight

        model: control.contentModel
        currentIndex: control.currentIndex
        interactive: Window.window ? ((contentHeight + control.topPadding + control.bottomPadding) > Window.window.height)
                                   : false
        clip: true
    }

    background: Rectangle {
        implicitWidth: MainCtx.dp(220, RedesignStyle.scale)

        radius: RedesignStyle.radiusM
        color: theme.bg.secondary

        border.width: 1
        border.color: theme.border
    }
}
