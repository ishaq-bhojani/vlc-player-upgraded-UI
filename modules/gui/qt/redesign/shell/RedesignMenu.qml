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

    //! Where the menu is anchored, the y of its top edge in the window; NaN for a menu that is not
    //! (a submenu: Qt places it beside its entry). A menu opened below a button sets it before it
    //! opens (MainMenu.openAtGlobal) and the menu keeps its top there: it is made to fit under it.
    //!
    //! CALLERS MUST SET IT BEFORE `popup()`: the height of the menu is computed from it when the
    //! popup opens. Without it the room is taken from the top margin (the whole window), so a menu
    //! opened lower in the window is not shortened to fit under its anchor: Qt then shifts it up to
    //! keep it inside the window, and it covers what is above the point it was opened at.
    property real anchorTop: Number.NaN

    // The room of the popup: the height of the window less where the popup starts and the margin
    // that keeps it inside, but room for a few entries at least. The window is the one of the parent
    // (the item the menu opens in): the content has none until the menu is open.
    //
    // It is NOT computed from `y`. The popup moves itself to fit its window (it is shifted up while
    // it is taller than the room under it) and writes the new position into `y`; a room that follows
    // `y` then grows with the shift, and the menu ends up over the title bar. `anchorTop` is what was
    // asked for, and nothing moves it. A submenu has no anchor: its room is the window less the
    // margins, Qt shifts it to fit.
    readonly property real _maxHeight: {
        const win = parent ? parent.Window.window : null
        if (!win)
            return Number.POSITIVE_INFINITY
        const top = isNaN(anchorTop) ? topMargin : anchorTop
        return Math.max(MainCtx.dp(96, RedesignStyle.scale), win.height - top - bottomMargin)
    }

    // What the entries need: their heights (a ListView that has not created every entry yet only
    // estimates its contentHeight), and the padding and background around them. Every entry
    // counts, whether it is visible or not: the list gives a hidden entry its place like any other
    // (a hidden entry would need `height: 0`), and the menus of the redesign hide none.
    readonly property real _wantedHeight: {
        let entries = 0
        for (let i = 0; i < count; ++i) {
            const entry = itemAt(i)
            if (entry)
                entries += entry.implicitHeight
        }
        return Math.max(implicitBackgroundHeight + topInset + bottomInset,
                        entries + topPadding + bottomPadding)
    }

    // Settings

    margins: RedesignStyle.spacingS
    padding: RedesignStyle.spacingXS

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding)

    // The height is set, not left to the implicit one: a menu taller than the room scrolls (the
    // list is interactive then), and one that fits has the height of its entries. A popup that is
    // not given a height that fits is moved up over what is above it.
    implicitHeight: Math.min(_wantedHeight, _maxHeight)
    height: implicitHeight

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
