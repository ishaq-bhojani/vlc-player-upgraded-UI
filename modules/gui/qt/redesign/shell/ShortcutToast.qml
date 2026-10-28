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

import VLC.MainInterface
import VLC.Style
import VLC.Redesign

/**
 * @brief The shortcut toast (spec 11.1): which keys were pressed and what they did, e.g.
 * "Space — Play/Pause", for 1.5 s, at the top centre of its parent.
 *
 * One toast at a time: a new key replaces the text and starts the time again. `show("")` (a key
 * no action holds) shows nothing. The look is the one of Widgets.FloatingNotification.
 */
Item {
    id: root

    // Properties

    property int duration: 1500

    // Functions

    function show(text: string) {
        if (text === "")
            return
        label.text = text
        toast.shown = true
        lifetime.restart()
    }

    // Settings

    implicitWidth: toast.width
    implicitHeight: toast.height

    // the keys did something visible already: the toast is not read out on its own
    Accessible.ignored: true

    // Children

    Timer {
        id: lifetime

        interval: root.duration

        onTriggered: toast.shown = false
    }

    Rectangle {
        id: toast

        property bool shown: false

        readonly property ColorContext colorContext: ColorContext {
            id: theme

            colorSet: ColorContext.Window
        }

        anchors.horizontalCenter: parent.horizontalCenter

        width: label.implicitWidth
        height: label.implicitHeight
        radius: RedesignStyle.radiusM

        color: theme.bg.primary
        border.width: VLCStyle.dp(1, VLCStyle.scale)
        border.color: theme.border

        visible: opacity > 0
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.9

        Behavior on opacity {
            NumberAnimation {
                duration: VLCStyle.duration_short
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: VLCStyle.duration_short
                easing.type: Easing.InOutQuad
            }
        }

        Text {
            id: label

            leftPadding: RedesignStyle.spacingM
            rightPadding: RedesignStyle.spacingM
            topPadding: RedesignStyle.spacingS
            bottomPadding: RedesignStyle.spacingS

            color: theme.fg.primary
            font.pixelSize: VLCStyle.fontSize_large
            textFormat: Text.PlainText
        }
    }
}
