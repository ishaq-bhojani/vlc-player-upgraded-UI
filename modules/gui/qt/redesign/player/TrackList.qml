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

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Redesign

/**
 * @brief One list of the track popup (TrackPopup): the tracks of a TrackListModel as checkable
 * rows, or, with `radio`, the entries of a model of which one is selected (AudioDeviceModel).
 *
 * The models of the player share their protocol (the same one TracksListPage.qml uses): the roles
 * `display` (the text) and `checked` (writing it selects the entry). Choosing a row leaves the
 * list as it is, it is the model that reports the new selection. Choosing the checked track again
 * switches it off, which is how a track list is "disabled".
 *
 * The list takes the keyboard focus as a whole (it is one stop of the Tab ring of the popup) and
 * moves its current row with Up and Down; Space and Enter choose it. At the first or the last row
 * Up or Down is reported through `boundaryReached` instead.
 */
ListView {
    id: root

    // Properties

    // one entry is selected and can not be unselected (the output devices)
    property bool radio: false

    // accessible name of the list
    property string name

    // shown instead of the rows of a model without any
    property string emptyText

    // number of rows the list shows without scrolling
    property int maxVisibleRows: 6

    // the row with the keyboard focus is outlined (the keyboard is used, not the pointer)
    property bool showFocus: false

    readonly property int rowHeight: VLCStyle.dp(36, VLCStyle.scale)

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.Tooltip
    }

    // Signals

    // Up on the first row (`direction` -1) or Down on the last row (1)
    signal boundaryReached(int direction)

    // a key went to the list
    signal keyboardUsed()

    // a row was clicked
    signal pointerUsed()

    // Functions

    // choose the current row
    function activateCurrent() {
        if (currentItem)
            currentItem.activate()
    }

    // Settings

    implicitWidth: VLCStyle.dp(240, VLCStyle.scale)
    implicitHeight: (count > 0) ? Math.min(contentHeight, maxVisibleRows * rowHeight) : rowHeight

    clip: true
    interactive: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    currentIndex: -1

    // the popup moves the focus with Tab
    activeFocusOnTab: false

    Accessible.role: Accessible.List
    Accessible.name: root.name

    T.ScrollBar.vertical: Widgets.ScrollBarExt { }

    // Events

    onActiveFocusChanged: {
        if (activeFocus && (currentIndex < 0) && (count > 0))
            currentIndex = 0
    }

    Keys.onPressed: (event) => {
        root.keyboardUsed()

        if (event.key === Qt.Key_Up) {
            if (root.currentIndex > 0)
                root.decrementCurrentIndex()
            else
                root.boundaryReached(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            if (root.currentIndex < (root.count - 1))
                root.incrementCurrentIndex()
            else
                root.boundaryReached(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateCurrent()
            event.accepted = true
        }
    }

    // Children

    T.Label {
        anchors.fill: parent

        visible: (root.count === 0)

        text: root.emptyText
        color: theme.fg.secondary
        font.pixelSize: VLCStyle.fontSize_normal
        verticalAlignment: Text.AlignVCenter
        leftPadding: VLCStyle.margin_xsmall
        elide: Text.ElideRight
    }

    delegate: T.ItemDelegate {
        id: row

        // the player (not this list) reports the selection through the model
        readonly property bool selected: (model.checked === true)

        readonly property bool current: root.activeFocus && root.showFocus && ListView.isCurrentItem

        function activate() {
            if (root.radio) {
                if (!selected)
                    model.checked = true
            } else {
                model.checked = !selected
            }
        }

        width: ListView.view.width
        height: root.rowHeight

        leftPadding: VLCStyle.margin_xsmall
        rightPadding: VLCStyle.margin_xsmall

        text: model.display ?? ""

        hoverEnabled: true

        // the list holds the focus, a row is never a stop of its own
        focusPolicy: Qt.NoFocus

        Accessible.role: root.radio ? Accessible.RadioButton : Accessible.CheckBox
        Accessible.name: row.text
        Accessible.checkable: true
        Accessible.checked: row.selected
        Accessible.onPressAction: row.activate()

        onClicked: {
            root.currentIndex = index
            root.pointerUsed()
            root.forceActiveFocus(Qt.MouseFocusReason)
            row.activate()
        }

        readonly property ColorContext colorContext: ColorContext {
            id: rowTheme

            colorSet: ColorContext.Item

            focused: row.current
            hovered: row.hovered
            pressed: row.down
            enabled: row.enabled
        }

        background: Rectangle {
            radius: RedesignStyle.radiusM

            color: row.selected ? rowTheme.bg.highlight : rowTheme.bg.primary

            border.width: VLCStyle.focus_border
            border.color: row.current ? rowTheme.visualFocus : "transparent"
        }

        contentItem: Item {
            // the mark: a check for a track, a dot in a ring for a device
            Item {
                id: mark

                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }

                width: VLCStyle.icon_track
                height: VLCStyle.icon_track

                Widgets.IconLabel {
                    anchors.fill: parent

                    visible: !root.radio && row.selected

                    text: VLCIcons.check
                    color: rowTheme.fg.highlight
                    font.pixelSize: VLCStyle.icon_track
                }

                Rectangle {
                    anchors.centerIn: parent

                    visible: root.radio

                    width: VLCStyle.dp(16, VLCStyle.scale)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: VLCStyle.dp(1, VLCStyle.scale)
                    border.color: row.selected ? rowTheme.fg.highlight : rowTheme.fg.secondary

                    Rectangle {
                        anchors.centerIn: parent

                        visible: row.selected

                        width: VLCStyle.dp(8, VLCStyle.scale)
                        height: width
                        radius: width / 2
                        color: rowTheme.fg.highlight
                    }
                }
            }

            T.Label {
                anchors {
                    left: mark.right
                    leftMargin: VLCStyle.margin_xsmall
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                text: row.text
                color: row.selected ? rowTheme.fg.highlight : rowTheme.fg.primary
                font.pixelSize: VLCStyle.fontSize_normal
                font.weight: row.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }
    }
}
