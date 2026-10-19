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

import VLC.Player
import VLC.Dialogs
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Redesign

/**
 * @brief The track popup of the redesign: the subtitle, audio and video tracks of the playing
 * media in one popup with the tabs Subtitles | Audio | Video, opened above the control bar button
 * that asked for it (ShellActions.trackPopupRequested).
 *
 *   Subtitles: the subtitle tracks, "Add subtitles..."
 *   Audio:     the audio tracks, then the "Output" devices
 *   Video:     the video tracks
 *
 * It fills its parent (the area it floats in) and is invisible while closed. Choosing a track
 * does not close it, the point is to try tracks one after the other. It closes on a click
 * outside (that click does nothing else: a click on the button that opened it closes it, so the
 * button toggles), on Esc (the keyboard focus returns to the button) and by `close()`.
 *
 * A tab without entries is disabled (shown, so the layout does not jump). Keys: Left and Right
 * change the tab, Down, Up and Tab go through the tabs, the lists and the action, Space and
 * Enter choose.
 */
FocusScope {
    id: root

    // Properties

    // the tab shown when the popup opens: "subtitles", "audio" or "video"
    property string initialTab: TrackPopupLogic.defaultTab

    // the item the popup is placed above (a control bar button)
    property Item anchorItem: null

    // the popup is open
    property bool opened: false

    // the tab shown: the tab the user chose, or the first usable tab if that one has no entries
    readonly property string shownTab: TrackPopupLogic.resolveTab(_tab, tabsEnabled)

    readonly property var tabsEnabled: TrackPopupLogic.enabledTabs(audioList.count, deviceList.count,
                                                                   videoList.count)

    // the last input was the keyboard: the focused row is outlined
    property bool _keyboard: false

    // the tab the popup was opened on or the user chose
    property string _tab: TrackPopupLogic.defaultTab

    readonly property int _margin: RedesignStyle.spacingS

    // Functions

    // Opens the popup on `tab`, above `anchor`.
    function open(tab: string, anchor: Item) {
        initialTab = tab
        anchorItem = anchor
        _tab = TrackPopupLogic.normalized(tab)
        // the focus ring of the button tells whether the keyboard opened it
        _keyboard = (anchor?.visualFocus === true)
        opened = true
        reposition()
        _focusTab(_keyboard ? Qt.TabFocusReason : Qt.OtherFocusReason)
    }

    // Closes the popup. With `refocus` the keyboard focus goes back to the button, if the popup
    // has it.
    function close(refocus: bool) {
        if (!opened)
            return

        const hadFocus = root.activeFocus
        opened = false

        if (refocus && hadFocus && anchorItem && anchorItem.visible)
            anchorItem.forceActiveFocus(_keyboard ? Qt.TabFocusReason : Qt.OtherFocusReason)
    }

    // The button asks again: the same request closes the popup, another one moves it.
    function toggle(tab: string, anchor: Item) {
        if (opened && anchor === anchorItem && TrackPopupLogic.normalized(tab) === shownTab)
            close(true)
        else
            open(tab, anchor)
    }

    function reposition() {
        if (!anchorItem || !opened)
            return

        const point = anchorItem.mapToItem(root, 0, 0)
        const placed = TrackPopupLogic.place(point.x, point.y, anchorItem.width, anchorItem.height,
                                             panel.width, panel.height, root.width, root.height,
                                             RedesignStyle.spacingS, _margin)
        panel.x = placed.x
        panel.y = placed.y
    }

    function selectTab(tab: string) {
        _tab = tab
    }

    // Left or Right on a tab: the next usable tab, with the focus
    function stepTab(step: int) {
        _keyboard = true

        const next = TrackPopupLogic.stepTab(shownTab, step, tabsEnabled)
        if (next === shownTab)
            return

        selectTab(next)
        _focusTab(step > 0 ? Qt.TabFocusReason : Qt.BacktabFocusReason)
    }

    // the button of a tab
    function _tabButton(tab: string): Item {
        return (tab === "audio") ? audioTab : (tab === "video") ? videoTab : subtitlesTab
    }

    function _focusTab(reason) {
        _tabButton(shownTab).forceActiveFocus(reason)
    }

    // the items Tab visits, in order
    function _ring(): var {
        const items = [_tabButton(shownTab)]

        if (shownTab === "subtitles") {
            if (subtitleList.count > 0)
                items.push(subtitleList)
            items.push(addSubtitles)
        } else if (shownTab === "audio") {
            if (audioList.count > 0)
                items.push(audioList)
            if (deviceList.count > 0)
                items.push(deviceList)
        } else if (videoList.count > 0) {
            items.push(videoList)
        }
        return items
    }

    // moves the focus `step` (+1 or -1) places in the ring
    function _moveFocus(step: int) {
        _keyboard = true

        const items = _ring()
        const next = TrackPopupLogic.ringStep(items.findIndex(item => item.activeFocus), items.length, step)
        if (next >= 0)
            items[next].forceActiveFocus((step > 0) ? Qt.TabFocusReason : Qt.BacktabFocusReason)
    }

    // Settings

    visible: opened

    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Tracks")

    // Events

    onWidthChanged: reposition()
    onHeightChanged: reposition()

    // The keys the lists and the buttons did not take. The arrows are not for the interface
    // behind the popup either (they would seek and change the volume).
    Keys.onPressed: (event) => {
        _keyboard = true

        if (event.key === Qt.Key_Escape) {
            close(true)
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            _moveFocus(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Backtab) {
            _moveFocus(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                   || event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            event.accepted = true
        }
    }

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.Tooltip
    }

    // a click outside of the popup closes it and does nothing else
    MouseArea {
        anchors.fill: parent

        acceptedButtons: Qt.AllButtons

        onPressed: {
            root._keyboard = false
            root.close(true)
        }
    }

    Rectangle {
        id: panel

        width: Math.min(VLCStyle.dp(320, VLCStyle.scale), root.width - 2 * root._margin)
        height: column.implicitHeight + 2 * RedesignStyle.spacingS

        radius: RedesignStyle.radiusL
        color: Qt.alpha(theme.bg.primary, 0.95)
        border.width: VLCStyle.dp(1, VLCStyle.scale)
        border.color: Qt.alpha(theme.fg.primary, 0.15)

        onWidthChanged: root.reposition()
        onHeightChanged: root.reposition()

        // a click on the popup itself is not outside
        MouseArea {
            anchors.fill: parent

            acceptedButtons: Qt.AllButtons

            onPressed: root._keyboard = false
        }

        ColumnLayout {
            id: column

            anchors {
                fill: parent
                margins: RedesignStyle.spacingS
            }

            spacing: RedesignStyle.spacingS

            RowLayout {
                Layout.fillWidth: true

                spacing: RedesignStyle.spacingXS

                PopupTab {
                    id: subtitlesTab

                    tabName: "subtitles"
                    text: qsTr("Subtitles")
                }

                PopupTab {
                    id: audioTab

                    tabName: "audio"
                    text: qsTr("Audio")
                }

                PopupTab {
                    id: videoTab

                    tabName: "video"
                    text: qsTr("Video")
                }
            }

            // the pages share the room, the shown one sets the height
            Item {
                id: pages

                readonly property Item current: (root.shownTab === "audio") ? audioPage
                                              : (root.shownTab === "video") ? videoPage
                                              : subtitlesPage

                Layout.fillWidth: true
                Layout.preferredHeight: current.implicitHeight

                ColumnLayout {
                    id: subtitlesPage

                    width: parent.width
                    visible: (root.shownTab === "subtitles")

                    spacing: RedesignStyle.spacingXS

                    TrackList {
                        id: subtitleList

                        Layout.fillWidth: true

                        model: Player.subtitleTracks
                        name: qsTr("Subtitle tracks")
                        emptyText: qsTr("No subtitle tracks")
                        showFocus: root._keyboard

                        onBoundaryReached: (direction) => root._moveFocus(direction)
                        onKeyboardUsed: root._keyboard = true
                        onPointerUsed: root._keyboard = false
                    }

                    ActionRow {
                        id: addSubtitles

                        Layout.fillWidth: true

                        text: qsTr("Add subtitles2026")
                        iconText: VLCIcons.add

                        // Task 37 replaces it with the dialog of the redesign
                        onTriggered: DialogsProvider.loadSubtitlesFile()
                    }
                }

                ColumnLayout {
                    id: audioPage

                    width: parent.width
                    visible: (root.shownTab === "audio")

                    spacing: RedesignStyle.spacingXS

                    TrackList {
                        id: audioList

                        Layout.fillWidth: true

                        maxVisibleRows: 4
                        model: Player.audioTracks
                        name: qsTr("Audio tracks")
                        emptyText: qsTr("No audio tracks")
                        showFocus: root._keyboard

                        onBoundaryReached: (direction) => root._moveFocus(direction)
                        onKeyboardUsed: root._keyboard = true
                        onPointerUsed: root._keyboard = false
                    }

                    T.Label {
                        Layout.fillWidth: true
                        Layout.topMargin: RedesignStyle.spacingXS
                        Layout.leftMargin: VLCStyle.margin_xsmall

                        visible: (deviceList.count > 0)

                        text: qsTr("Output")
                        color: theme.fg.secondary
                        font.pixelSize: VLCStyle.fontSize_small
                        font.bold: true
                        elide: Text.ElideRight

                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }

                    TrackList {
                        id: deviceList

                        Layout.fillWidth: true

                        visible: (count > 0)

                        radio: true
                        maxVisibleRows: 4
                        model: Player.audioDevices
                        name: qsTr("Output devices")
                        showFocus: root._keyboard

                        onBoundaryReached: (direction) => root._moveFocus(direction)
                        onKeyboardUsed: root._keyboard = true
                        onPointerUsed: root._keyboard = false
                    }
                }

                ColumnLayout {
                    id: videoPage

                    width: parent.width
                    visible: (root.shownTab === "video")

                    spacing: RedesignStyle.spacingXS

                    TrackList {
                        id: videoList

                        Layout.fillWidth: true

                        model: Player.videoTracks
                        name: qsTr("Video tracks")
                        emptyText: qsTr("No video tracks")
                        showFocus: root._keyboard

                        onBoundaryReached: (direction) => root._moveFocus(direction)
                        onKeyboardUsed: root._keyboard = true
                        onPointerUsed: root._keyboard = false
                    }
                }
            }
        }
    }

    // A tab of the row above the lists. Left and Right change the tab, Down goes to the list.
    component PopupTab: T.AbstractButton {
        id: tab

        required property string tabName

        readonly property bool shown: (root.shownTab === tabName)

        Layout.fillWidth: true

        implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                                implicitContentWidth + leftPadding + rightPadding)
        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

        padding: RedesignStyle.spacingS

        enabled: (root.tabsEnabled[tabName] === true)

        hoverEnabled: true

        Accessible.role: Accessible.PageTab
        Accessible.name: tab.text
        Accessible.selected: tab.shown
        Accessible.onPressAction: tab.clicked()

        onClicked: {
            root._keyboard = false
            root.selectTab(tabName)
        }

        Keys.onLeftPressed: root.stepTab(-1)
        Keys.onRightPressed: root.stepTab(1)
        Keys.onDownPressed: root._moveFocus(1)
        Keys.onUpPressed: root._moveFocus(-1)
        Keys.onReturnPressed: tab.clicked()
        Keys.onEnterPressed: tab.clicked()

        readonly property ColorContext colorContext: ColorContext {
            id: tabTheme

            colorSet: ColorContext.TabButton

            focused: tab.visualFocus
            hovered: tab.hovered
            pressed: tab.down
            enabled: tab.enabled
        }

        background: Rectangle {
            radius: RedesignStyle.radiusM

            color: tabTheme.bg.primary
            border.width: VLCStyle.focus_border
            border.color: tab.visualFocus ? tabTheme.visualFocus : "transparent"

            // the shown tab
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: RedesignStyle.spacingS
                    rightMargin: RedesignStyle.spacingS
                }

                height: VLCStyle.dp(2, VLCStyle.scale)
                radius: height / 2
                color: tabTheme.accent

                visible: tab.shown
            }
        }

        contentItem: T.Label {
            text: tab.text
            color: tabTheme.fg.primary
            opacity: tab.shown ? 1.0 : 0.75
            font.pixelSize: VLCStyle.fontSize_normal
            font.bold: tab.shown
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    // A row that runs an action, not a choice ("Add subtitles...").
    component ActionRow: T.ItemDelegate {
        id: action

        property string iconText

        signal triggered()

        implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

        leftPadding: VLCStyle.margin_xsmall
        rightPadding: VLCStyle.margin_xsmall

        hoverEnabled: true

        Accessible.role: Accessible.Button
        Accessible.name: action.text
        Accessible.onPressAction: action.triggered()

        onClicked: {
            root._keyboard = false
            action.triggered()
        }

        Keys.onReturnPressed: action.triggered()
        Keys.onEnterPressed: action.triggered()
        Keys.onSpacePressed: action.triggered()
        Keys.onDownPressed: root._moveFocus(1)
        Keys.onUpPressed: root._moveFocus(-1)

        readonly property ColorContext colorContext: ColorContext {
            id: actionTheme

            colorSet: ColorContext.Item

            focused: action.visualFocus
            hovered: action.hovered
            pressed: action.down
            enabled: action.enabled
        }

        background: Rectangle {
            radius: RedesignStyle.radiusM

            color: actionTheme.bg.primary
            border.width: VLCStyle.focus_border
            border.color: action.visualFocus ? actionTheme.visualFocus : "transparent"
        }

        contentItem: Item {
            Widgets.IconLabel {
                id: actionIcon

                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }

                width: VLCStyle.icon_track
                height: VLCStyle.icon_track

                text: action.iconText
                color: actionTheme.accent
                font.pixelSize: VLCStyle.icon_track
            }

            T.Label {
                anchors {
                    left: actionIcon.right
                    leftMargin: VLCStyle.margin_xsmall
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                text: action.text
                color: actionTheme.fg.primary
                font.pixelSize: VLCStyle.fontSize_normal
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }
    }
}
