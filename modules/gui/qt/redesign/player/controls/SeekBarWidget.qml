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
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Util
import VLC.Redesign

/**
 * @brief The seek bar of the redesign control bar: elapsed time, a thick track, total time.
 *
 * The track fills the accent colour up to the current position, chapter starts are ticks across
 * it. Click or drag seeks (Player.jumpToPos). Registered as REDESIGN_SEEKBAR.
 *
 * Fills the free width of the bar the way the Expanding Spacer does: it asks for far more width
 * than there is (implicitWidth) and gives way to its neighbours down to Layout.minimumWidth, which
 * also makes ControlRepeater give it Layout.fillWidth.
 */
T.Control {
    id: root

    // Properties

    property bool paintOnly: false

    // position (0..1) the pointer is at while it is over the bar, -1 otherwise
    property real hoverPosition: -1

    // 0..1 position shown: the one being dragged to, else the player's
    readonly property real visualPosition: paintOnly ? 0.35 : (dragHandler.active ? _dragPosition : Player.position)

    readonly property bool _canSeek: !paintOnly
                                     && (Player.playingState === Player.PLAYING_STATE_PLAYING
                                         || Player.playingState === Player.PLAYING_STATE_PAUSED)

    property real _dragPosition: 0
    property bool _hovered: hoverHandler.hovered

    // Signals

    // the pointer moved over the track: `position` is 0..1 along the media, `x` the pointer
    // position in the coordinates of this item (for the seek preview)
    signal hoveredAt(real position, real x)

    // Settings

    // see the note on top: the free width of the bar, not a size
    implicitWidth: paintOnly ? VLCStyle.dp(160, VLCStyle.scale) : VLCStyle.dp(4096, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(28, VLCStyle.scale)

    Layout.minimumWidth: VLCStyle.dp(160, VLCStyle.scale)

    enabled: root.paintOnly || root._canSeek

    activeFocusOnTab: true

    Accessible.role: Accessible.Slider
    Accessible.name: qsTr("Progress")
    AccessibleCompat.id: "progressSlider"
    Accessible.onIncreaseAction: Player.jumpFwd()
    Accessible.onDecreaseAction: Player.jumpBwd()

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)
    Keys.onRightPressed: Player.jumpFwd()
    Keys.onLeftPressed: Player.jumpBwd()

    // Functions

    function _clamp(value) {
        return Math.min(1, Math.max(0, value))
    }

    // position (0..1) along the media of `x`, in the coordinates of this item
    function _positionAt(x) {
        return _clamp(track.mapFromItem(root, x, 0).x / track.width)
    }

    function _seekNow() {
        seekTimer.stop()
        Player.jumpToPos(root._dragPosition)
    }

    // Colours

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.Slider

        enabled: root.enabled
        focused: root.visualFocus
        hovered: root._hovered
    }

    readonly property ColorContext textContext: ColorContext {
        id: textTheme

        colorSet: ColorContext.Window
    }

    // Children

    TextMetrics {
        id: timeMetrics

        font.pixelSize: VLCStyle.fontSize_small

        // both times take the room of the widest of the two so the track does not jump
        text: (Player.time.isSubHour() && Player.length.isSubHour()) ? "00:00" : "00:00:00"
    }

    // seeks while dragging, but not on every pointer event
    Timer {
        id: seekTimer

        interval: 100

        onTriggered: root._seekNow()
    }

    HoverHandler {
        id: hoverHandler

        enabled: root._canSeek

        onPointChanged: {
            if (hovered) {
                root.hoverPosition = root._positionAt(point.position.x)
                root.hoveredAt(root.hoverPosition, point.position.x)
            }
        }

        onHoveredChanged: {
            if (!hovered)
                root.hoverPosition = -1
        }
    }

    DragHandler {
        id: dragHandler

        target: null

        enabled: root._canSeek

        // the last position of the drag is the one to seek to
        onActiveChanged: {
            if (!active)
                root._seekNow()
        }

        onCentroidChanged: {
            if (active) {
                root._dragPosition = root._positionAt(centroid.position.x)
                if (!seekTimer.running)
                    seekTimer.start()
            }
        }
    }

    TapHandler {
        enabled: root._canSeek

        onTapped: (eventPoint) => {
            root._dragPosition = root._positionAt(eventPoint.position.x)
            root._seekNow()
            root.forceActiveFocus(Qt.MouseFocusReason)
        }
    }

    contentItem: RowLayout {
        spacing: RedesignStyle.spacingS

        T.Label {
            Layout.preferredWidth: timeMetrics.width

            text: root.paintOnly ? "00:00" : Player.time.formatHMS()
            color: textTheme.fg.primary
            font: timeMetrics.font
            horizontalAlignment: Text.AlignRight

            Accessible.ignored: true
        }

        Item {
            id: track

            Layout.fillWidth: true
            Layout.fillHeight: true

            // the groove: a thick bar, RedesignStyle.spacingS high
            Rectangle {
                id: groove

                anchors.verticalCenter: parent.verticalCenter

                width: parent.width
                height: RedesignStyle.spacingS
                radius: height / 2

                color: theme.bg.primary

                // progress, accent
                Rectangle {
                    width: groove.width * root.visualPosition
                    height: parent.height
                    radius: parent.radius

                    color: theme.fg.primary
                }

                // chapters: a tick at the start of each one (but the first)
                Repeater {
                    model: root.paintOnly ? null : Player.chapters

                    delegate: Rectangle {
                        required property real startPosition

                        visible: startPosition > 0 && startPosition < 1

                        x: groove.width * startPosition - width / 2
                        width: VLCStyle.dp(2, VLCStyle.scale)
                        height: groove.height

                        color: theme.bg.secondary
                    }
                }
            }

            // handle at the position
            Rectangle {
                anchors.verticalCenter: groove.verticalCenter

                x: Math.min(groove.width, Math.max(0, groove.width * root.visualPosition)) - width / 2
                width: RedesignStyle.spacingXS
                height: groove.height + RedesignStyle.spacingS
                radius: width / 2

                visible: root.enabled || root.paintOnly

                color: theme.fg.primary
                border.width: root.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                border.color: theme.visualFocus
            }
        }

        T.Label {
            Layout.preferredWidth: timeMetrics.width

            text: root.paintOnly ? "00:00" : Player.length.formatHMS()
            color: textTheme.fg.primary
            font: timeMetrics.font
            horizontalAlignment: Text.AlignLeft

            Accessible.ignored: true
        }
    }
}
