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

    // Properties

    // the name of the menu for the assistive technologies, the title of a submenu by default
    property string accessibleName: title

    // The room of the popup: the height of the window less where the popup starts (y: it opens
    // below the button) and the margin that keeps it inside, but room for a few entries at least.
    // The window is the one of the parent (the item the menu opens in): the content has none until
    // the menu is open, and by then the popup has already moved up to fit its full height. `y` is
    // relative to the parent, so it is mapped to the window.
    readonly property real _maxHeight: {
        const win = parent ? parent.Window.window : null
        if (!win)
            return Number.POSITIVE_INFINITY
        const top = parent.mapToItem(null, 0, y).y
        return Math.max(MainCtx.dp(96, RedesignStyle.scale), win.height - top - bottomMargin)
    }

    // Settings

    margins: RedesignStyle.spacingS
    padding: RedesignStyle.spacingXS

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding)
    // a menu taller than the window scrolls
    implicitHeight: Math.min(Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                      contentHeight + topPadding + bottomPadding),
                             _maxHeight)

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
        interactive: contentHeight > height
        clip: true

        Accessible.role: Accessible.PopupMenu
        Accessible.name: control.accessibleName
    }

    background: Rectangle {
        implicitWidth: MainCtx.dp(220, RedesignStyle.scale)

        radius: RedesignStyle.radiusM
        color: theme.bg.secondary

        border.width: 1
        border.color: theme.border
    }
}
