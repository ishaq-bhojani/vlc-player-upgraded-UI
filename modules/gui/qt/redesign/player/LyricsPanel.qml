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

import VLC.Player
import VLC.Style
import VLC.Redesign

/**
 * @brief The synced lyrics of the current media, the current line highlighted and centered.
 *
 * The lyrics come from the media itself (Player.hasLyrics: the SYLT of the tags, Player.syltLyrics
 * and Player.currentLyricIndex of the upstream player) or, without them, from the ".lrc" file next
 * to a local audio file (SidecarLyrics). `available` tells whether there is anything to show: the
 * parent hides the panel (and gives its room back) when it is false.
 *
 * The current line is centered with a short animation. Scrolling the list (wheel, drag, flick)
 * stops that for `resumeDelay` ms after the last movement, so that the lines can be read.
 * The panel is not focusable (the keys are handled by the shell).
 */
Item {
    id: root

    // Properties

    // the lyrics of the media itself win over the ones of a file
    readonly property bool embedded: Player.hasLyrics

    readonly property bool available: root.embedded || sidecar.available

    // index of the line to highlight, -1 before the first line
    readonly property int currentIndex: root.embedded ? Player.currentLyricIndex : root._sidecarIndex

    // time without scrolling by the user before the current line is centered again
    property int resumeDelay: 4000

    // the user scrolled the list less than `resumeDelay` ms ago
    property bool _userScrolling: false

    // The playback time for the lines of the file: Player.positionUpdated gives it at the pace of
    // the position of the seek bar (interpolated between the updates of the player), and on seeks.
    property var _time

    // the line of the file at `_time`
    property int _sidecarIndex: -1

    // Functions

    function refreshSidecarIndex() {
        root._sidecarIndex = sidecar.available ? sidecar.indexAtTime(root._time) : -1
    }

    // other lines or another media: the user starts over
    function reset() {
        resumeTimer.stop()
        root._userScrolling = false
        root._time = Player.time
        root.refreshSidecarIndex()
        Qt.callLater(root.centerCurrent)
    }

    // Brings the current line to the center. A line that is not on screen (a seek, the first
    // line) is jumped to, one that is on screen is reached with an animation.
    function centerCurrent() {
        centerAnimation.stop()

        const idx = root.currentIndex
        if (idx < 0 || root._userScrolling || list.count === 0)
            return

        const item = list.itemAtIndex(idx)
        if (!item) {
            list.positionViewAtIndex(idx, ListView.Center)
            return
        }

        // contentY starts at originY, which is negative by the height of the header
        const minY = list.originY
        const maxY = Math.max(minY, list.originY + list.contentHeight - list.height)
        const target = Math.max(minY, Math.min(maxY, item.y + item.height / 2 - list.height / 2))
        if (Math.abs(target - list.contentY) < 1)
            return

        centerAnimation.to = target
        centerAnimation.restart()
    }

    onCurrentIndexChanged: Qt.callLater(root.centerCurrent)

    // Settings

    Component.onCompleted: root.reset()

    // Children

    Connections {
        target: Player

        function onPositionUpdated(position, time, length) {
            root._time = time
            root.refreshSidecarIndex()
        }

        // another media
        function onInputChanged() {
            root.reset()
        }

        function onSyltLyricsChanged() {
            root.reset()
        }
    }

    Connections {
        target: sidecar

        function onLinesChanged() {
            root.reset()
        }
    }

    ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    SidecarLyrics {
        id: sidecar

        media: Player.url
    }

    ListView {
        id: list

        anchors.fill: parent

        // an empty list is not a list for the accessibility tree
        visible: root.available

        // the model is either a list of TimedText (time, text) or of {timeMs, text}: both have text
        model: root.embedded ? Player.syltLyrics : sidecar.lines

        clip: true
        boundsBehavior: Flickable.StopAtBounds
        activeFocusOnTab: false

        // room above the first line and below the last one, so that they can be centered too
        header: Item { width: list.width; height: list.height / 2 }
        footer: Item { width: list.width; height: list.height / 2 }

        onHeightChanged: Qt.callLater(root.centerCurrent)
        onCountChanged: Qt.callLater(root.centerCurrent)

        // the wheel, a drag and a flick are movements
        onMovementStarted: {
            root._userScrolling = true
            resumeTimer.stop()
            centerAnimation.stop()
        }

        onMovementEnded: resumeTimer.restart()

        Accessible.role: Accessible.List
        Accessible.name: qsTr("Lyrics")

        delegate: Text {
            id: line

            required property int index
            required property var modelData

            readonly property bool isCurrent: line.index === root.currentIndex

            width: ListView.view.width
            // an empty line (a pause in the song) still takes a little room
            height: Math.max(implicitHeight, font.pixelSize)

            topPadding: RedesignStyle.spacingS
            bottomPadding: RedesignStyle.spacingS
            leftPadding: RedesignStyle.spacingM
            rightPadding: RedesignStyle.spacingM

            text: line.modelData.text
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: VLCStyle.fontSize_xlarge
            font.weight: line.isCurrent ? Font.Bold : Font.Normal
            color: theme.fg.primary
            opacity: line.isCurrent ? 1.0 : 0.5

            Behavior on opacity {
                NumberAnimation { duration: VLCStyle.duration_short }
            }

            // a pause in the song is not announced
            Accessible.ignored: line.text.length === 0
            Accessible.role: Accessible.StaticText
            Accessible.name: line.text
        }
    }

    NumberAnimation {
        id: centerAnimation

        target: list
        property: "contentY"
        duration: VLCStyle.duration_long
        easing.type: Easing.OutCubic
    }

    Timer {
        id: resumeTimer

        interval: root.resumeDelay
        repeat: false

        onTriggered: {
            root._userScrolling = false
            root.centerCurrent()
        }
    }
}
