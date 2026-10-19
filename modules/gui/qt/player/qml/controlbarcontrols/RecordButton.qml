/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import QtQuick.Templates as T


import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util

Widgets.IconToolButton {
    id: control

    enabled: !paintOnly && Player.isStarted

    color: _recordColor //red means recording
    text: VLCIcons.record
    description: qsTr("record")

    AccessibleCompat.id: "recordButton"

    // stock keeps the upstream pure red, the redesign takes the palette's negative colour
    readonly property ColorContext negativeContext: ColorContext {
        id: negativeTheme
        colorSet: ColorContext.View
    }
    readonly property color _recordColor: MainCtx.redesign ? negativeTheme.fg.negative : "#FFFF0000"

    onClicked: Player.toggleRecord()

    //IconToolButton already contains a color animation that would conflict
    contentItem: Widgets.IconLabel {
        text: control.text

        color: control.color

        SequentialAnimation on color {
            loops: Animation.Infinite
            running: control.enabled && Player.recording

            ColorAnimation  {
                from: control._recordColor
                to: Qt.alpha(control._recordColor, 0.0) //use "red" transparent
                //this is an animation and not a transisition, we explicitly want a long duration
                duration: 1000
                easing.type: Easing.InSine
            }

            ColorAnimation  {
                from: Qt.alpha(control._recordColor, 0.0)
                to: control._recordColor
                //this is an animation and not a transisition, we explicitly want a long duration
                duration: 1000
                easing.type: Easing.OutSine
            }

            onStopped: {
                color = control._recordColor
            }
        }
        font: control.font
    }


}
