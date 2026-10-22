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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Redesign

/**
 * @brief The line between two groups of entries of a RedesignMenu.
 */
T.MenuSeparator {
    id: control

    // Settings

    implicitWidth: contentItem.implicitWidth
    implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding

    topPadding: RedesignStyle.spacingXS
    bottomPadding: RedesignStyle.spacingXS

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        palette: VLCStyle.palette
        colorSet: ColorContext.MenuBar
    }

    contentItem: Rectangle {
        implicitHeight: 1

        color: theme.separator
    }
}
