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
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Redesign

/**
 * @brief A titled horizontal row of the Home page: a title with a "›" link on the left,
 * under it a horizontal list of cards.
 *
 * The section is hidden while its model has no item. The cards are made by `delegate` (an item
 * of `cardWidth` x `cardHeight` that has `required property int index` and `required property
 * var model`); activating a card (click, Enter) emits `itemActivated(index)`, the "›" link
 * emits `linkActivated()`.
 */
FocusScope {
    id: root

    // Properties

    property string title

    // accessible name of the link, e.g. "Show all videos"
    property string linkDescription

    property alias model: listView.model
    property alias delegate: listView.delegate
    property alias listView: listView

    property real cardWidth: VLCStyle.dp(200, VLCStyle.scale)
    property real cardHeight: VLCStyle.dp(112, VLCStyle.scale)

    // the height of what is under the cards (a caption)
    property real captionHeight: VLCStyle.dp(40, VLCStyle.scale)

    readonly property int count: listView.count

    // Settings

    // a section with no item is hidden (and takes no room)
    visible: count > 0

    implicitHeight: visible ? column.implicitHeight : 0

    // Signals

    signal itemActivated(int index)
    signal linkActivated(int reason)

    // Children

    ColorContext {
        id: theme

        colorSet: ColorContext.Window
    }

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right

        spacing: RedesignStyle.spacingS

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: RedesignStyle.spacingL

            spacing: RedesignStyle.spacingXS

            Text {
                Layout.alignment: Qt.AlignVCenter

                text: root.title
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_large
                font.bold: true
                elide: Text.ElideRight
                textFormat: Text.PlainText

                Accessible.role: Accessible.Heading
                Accessible.name: text
            }

            T.AbstractButton {
                id: link

                Layout.alignment: Qt.AlignVCenter

                implicitWidth: VLCStyle.dp(24, VLCStyle.scale)
                implicitHeight: implicitWidth

                hoverEnabled: true
                focusPolicy: Qt.StrongFocus

                text: "›" // ›

                Accessible.name: root.linkDescription || root.title
                Accessible.onPressAction: link.clicked()

                Navigation.parentItem: root
                Navigation.downItem: listView

                Keys.onPressed: (event) => {
                    if (KeyHelper.matchOk(event)) {
                        event.accepted = true
                        link.clicked()
                    } else {
                        Navigation.defaultKeyAction(event)
                    }
                }

                onClicked: root.linkActivated(link.visualFocus ? Qt.TabFocusReason : Qt.MouseFocusReason)

                ColorContext {
                    id: linkTheme

                    colorSet: ColorContext.Item

                    focused: link.visualFocus
                    hovered: link.hovered
                    pressed: link.down
                }

                background: Rectangle {
                    radius: RedesignStyle.radiusS

                    visible: link.hovered || link.visualFocus
                    color: linkTheme.bg.highlight

                    border.width: link.visualFocus ? VLCStyle.focus_border : 0
                    border.color: linkTheme.visualFocus
                }

                contentItem: Text {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    text: link.text
                    color: (link.hovered || link.visualFocus) ? linkTheme.fg.highlight : linkTheme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_xlarge
                    textFormat: Text.PlainText
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Widgets.ListViewExt {
            id: listView

            Layout.fillWidth: true
            Layout.preferredHeight: root.cardHeight + root.captionHeight

            orientation: ListView.Horizontal
            spacing: RedesignStyle.spacingM

            leftMargin: RedesignStyle.spacingL
            rightMargin: RedesignStyle.spacingL

            clip: true

            focus: true

            Navigation.parentItem: root
            Navigation.upItem: link

            onActionAtIndex: (index) => root.itemActivated(index)
        }
    }
}
