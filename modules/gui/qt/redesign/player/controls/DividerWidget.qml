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

import VLC.Style

// Thin vertical rule between groups of controls.
Item {
    id: root

    property bool paintOnly: false

    // a 1 px rule is too thin to grab in the customize panel
    implicitWidth: paintOnly ? VLCStyle.icon_toolbar : VLCStyle.dp(1, VLCStyle.scale)
    implicitHeight: VLCStyle.icon_toolbar

    enabled: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.ToolButton

        enabled: root.enabled || root.paintOnly
    }

    Rectangle {
        anchors.centerIn: parent

        width: VLCStyle.dp(1, VLCStyle.scale)
        height: parent.height * 0.6

        color: theme.separator
    }
}
