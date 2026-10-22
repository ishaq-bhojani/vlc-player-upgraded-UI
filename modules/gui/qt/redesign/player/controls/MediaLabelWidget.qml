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
import QtQuick.Layouts

import VLC.Widgets as Widgets
import VLC.Style

// Base of the media name labels of the control bar (title, artist, folder, play queue
// position). A plain, non-interactive item like the spacers: it shrinks (elided text)
// when the bar is narrow and takes no room while it has nothing to show.
Item {
    id: root

    // set by the customize panel: show a sample instead of the live text
    property bool paintOnly: false

    // live text of the current media, "" when there is nothing to show
    property string text
    // sample shown in the customize panel
    property string placeholder
    // optional VLCIcons glyph in front of the text
    property string glyph
    // use the secondary text colour
    property bool secondary: false

    readonly property string displayText: paintOnly ? placeholder : text

    readonly property real _maxTextWidth: VLCStyle.dp(240, VLCStyle.scale)
    readonly property real _spacing: VLCStyle.margin_xsmall / 2

    implicitHeight: VLCStyle.icon_toolbar
    implicitWidth: (displayText === "") ? 0
                                        : (glyphLabel.visible ? glyphLabel.implicitWidth + _spacing : 0)
                                          + Math.min(label.implicitWidth, _maxTextWidth)

    // a positive minimum width makes the control bar stretch the label up to implicitWidth
    Layout.minimumWidth: (paintOnly || displayText === "") ? 0 : VLCStyle.dp(48, VLCStyle.scale)

    Accessible.role: Accessible.StaticText
    Accessible.name: displayText
    Accessible.ignored: displayText === ""

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.ToolButton
    }

    T.Label {
        id: glyphLabel

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        visible: root.glyph !== "" && root.displayText !== ""

        text: root.glyph
        color: theme.fg.secondary

        font.family: VLCIcons.fontFamily
        font.pixelSize: VLCStyle.fontSize_large

        Accessible.ignored: true
    }

    Widgets.LabelExt {
        id: label

        anchors.left: glyphLabel.visible ? glyphLabel.right : parent.left
        anchors.leftMargin: glyphLabel.visible ? root._spacing : 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        text: root.displayText
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: root.secondary ? theme.fg.secondary : theme.fg.primary

        font.pixelSize: VLCStyle.fontSize_normal

        Accessible.ignored: true
    }
}
