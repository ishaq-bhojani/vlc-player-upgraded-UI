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

import VLC.MainInterface
import VLC.Style
import VLC.Redesign

/**
 * @brief An entry of RedesignMenu: the text, and a chevron when it opens a submenu.
 *
 * The colors are the ones of the menu bar of the palette (ColorContext.MenuBar): the highlighted
 * entry (hovered, or reached with the keys) is filled, a disabled one is dimmed.
 */
T.MenuItem {
    id: control

    // Settings

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    leftPadding: RedesignStyle.spacingM
    rightPadding: RedesignStyle.spacingM
    topPadding: RedesignStyle.spacingS
    bottomPadding: RedesignStyle.spacingS

    Accessible.role: Accessible.MenuItem
    Accessible.name: text

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        palette: VLCStyle.palette
        colorSet: ColorContext.MenuBar

        enabled: control.enabled
        hovered: control.hovered
        focused: control.highlighted
    }

    background: Rectangle {
        implicitHeight: MainCtx.dp(32, RedesignStyle.scale)

        radius: RedesignStyle.radiusS
        color: theme.bg.primary
    }

    contentItem: RowLayout {
        spacing: RedesignStyle.spacingL

        Text {
            Layout.fillWidth: true

            text: control.text
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter

            font.pixelSize: VLCStyle.fontSize_normal
            color: theme.fg.primary
        }

        // a submenu
        Text {
            visible: control.subMenu !== null

            text: "›"
            verticalAlignment: Text.AlignVCenter

            font.pixelSize: VLCStyle.fontSize_normal
            color: theme.fg.secondary
        }
    }
}
