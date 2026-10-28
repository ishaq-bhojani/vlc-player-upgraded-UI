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
import VLC.Util
import VLC.Redesign

/**
 * @brief The address bar of the library: the crumbs of the page, separated by "›".
 *
 * `crumbs` is [{label, ...}] (AddressPath.crumbs, plus the folders of a network page). The last
 * crumb is the page that is shown: plain text. The others are buttons, activating one emits
 * `crumbActivated(index)`. When they do not fit, the list starts scrolled to its end, so the page
 * that is shown stays visible; the others are reached by scrolling (wheel, drag, keyboard).
 */
FocusScope {
    id: root

    // Properties

    property var crumbs: []

    // Signals

    signal crumbActivated(int index, int reason)

    // Settings

    implicitHeight: VLCStyle.dp(28, VLCStyle.scale)

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Address")

    onCrumbsChanged: Qt.callLater(listView.positionViewAtEnd)
    onWidthChanged: Qt.callLater(listView.positionViewAtEnd)

    // Children

    ColorContext {
        id: theme

        colorSet: ColorContext.Window
    }

    ListView {
        id: listView

        anchors.fill: parent

        orientation: ListView.Horizontal
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        focus: true
        keyNavigationEnabled: true
        // the last crumb (the page) is not a button: the keys stop before it
        currentIndex: Math.max(0, count - 2)

        model: root.crumbs

        delegate: Row {
            id: crumb

            required property int index
            required property var modelData

            readonly property bool last: index === listView.count - 1

            height: ListView.view.height
            spacing: 0

            T.AbstractButton {
                id: button

                anchors.verticalCenter: parent.verticalCenter

                visible: !crumb.last

                implicitWidth: label.implicitWidth + 2 * RedesignStyle.spacingXS
                implicitHeight: crumb.height

                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                focus: crumb.ListView.isCurrentItem

                text: crumb.modelData.label

                Accessible.name: qsTr("Go to %1").arg(text)
                Accessible.onPressAction: button.clicked()

                Keys.onPressed: (event) => {
                    if (KeyHelper.matchOk(event)) {
                        event.accepted = true
                        button.clicked()
                    }
                }

                onClicked: root.crumbActivated(crumb.index, button.visualFocus ? Qt.TabFocusReason
                                                                               : Qt.MouseFocusReason)

                ColorContext {
                    id: buttonTheme

                    colorSet: ColorContext.Item

                    focused: button.visualFocus
                    hovered: button.hovered
                    pressed: button.down
                }

                background: Rectangle {
                    radius: RedesignStyle.radiusS

                    visible: button.hovered || button.visualFocus
                    color: buttonTheme.bg.highlight

                    border.width: button.visualFocus ? VLCStyle.focus_border : 0
                    border.color: buttonTheme.visualFocus
                }

                contentItem: Text {
                    id: label

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    text: button.text
                    color: (button.hovered || button.visualFocus) ? buttonTheme.fg.highlight
                                                                  : buttonTheme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_normal
                    textFormat: Text.PlainText
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter

                visible: !crumb.last
                width: implicitWidth + 2 * RedesignStyle.spacingXS

                horizontalAlignment: Text.AlignHCenter
                text: "›" // ›
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
                textFormat: Text.PlainText

                Accessible.ignored: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter

                visible: crumb.last
                // a long name of the page is elided to the width of the bar
                width: Math.min(implicitWidth, listView.width)
                leftPadding: (crumb.index === 0) ? RedesignStyle.spacingXS : 0

                text: crumb.modelData.label
                elide: Text.ElideRight
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_large
                font.bold: true
                textFormat: Text.PlainText

                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }
        }
    }
}
