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
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util
import VLC.Redesign

/**
 * @brief The volume control of the redesign: a speaker button (click mutes) and a cone, a
 * right pointing triangle whose filled part is the volume.
 *
 * The silhouette is the one of the owner's Figma export (docs/redesign/figma-svg/volume.svg,
 * 89 x 28, see ConeMath.silhouetteColumns): a dark track, filled up to the volume with the
 * gradient of the export (green, yellow, accent). Above 100 % (up to MainCtx.maxVolume) the
 * overflow band is filled with the negative colour. Wheel changes the volume by 5 %.
 * Registered for VOLUME in redesign mode only (PlayerControlbarControls.qml).
 */
T.Pane {
    id: root

    // Properties

    property bool paintOnly: false

    readonly property var _player: paintOnly ? ({ muted: false, volume: .5 }) : Player

    // the volume the cone shows (1 is 100 %): the one being set while dragging, else the player's
    readonly property real _volume: mouseArea.pressed ? _pendingVolume : _player.volume
    property real _pendingVolume: 0

    readonly property real _maxVolume: Math.max(1, MainCtx.maxVolume / 100)

    // where 100 % is along the cone (a fraction of its width)
    readonly property real _fullPosition: 1 / _maxVolume

    readonly property real _coneWidth: VLCStyle.dp(89, VLCStyle.scale)
    readonly property real _coneHeight: VLCStyle.dp(28, VLCStyle.scale)

    // Settings

    padding: 0

    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    contentWidth: row.implicitWidth
    contentHeight: row.implicitHeight

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.Slider

        enabled: !root.paintOnly
        hovered: mouseArea.containsMouse
        focused: cone.visualFocus
    }

    // Functions

    function _setVolume(value) {
        const volume = Math.min(root._maxVolume, Math.max(0, value))

        Player.muted = false
        Player.volume = volume
    }

    // Children

    RowLayout {
        id: row

        anchors.fill: parent

        spacing: RedesignStyle.spacingS

        Widgets.IconToolButton {
            id: speaker

            focus: true
            paintOnly: root.paintOnly

            text: {
                if (root._player.muted)
                    return VLCIcons.volume_muted
                else if (root._player.volume === 0)
                    return VLCIcons.volume_zero
                else if (root._player.volume < .33)
                    return VLCIcons.volume_low
                else if (root._player.volume <= .66)
                    return VLCIcons.volume_medium
                else
                    return VLCIcons.volume_high
            }
            description: qsTr("Mute")

            AccessibleCompat.id: "muteButton"

            onClicked: Player.muted = !Player.muted

            Accessible.onIncreaseAction: {
                Player.muted = false
                Player.setVolumeUp()
            }

            Accessible.onDecreaseAction: {
                Player.muted = false
                Player.setVolumeDown()
            }

            Navigation.parentItem: root
            Navigation.rightItem: cone
        }

        T.Control {
            id: cone

            Layout.preferredWidth: root._coneWidth
            Layout.preferredHeight: root._coneHeight
            Layout.alignment: Qt.AlignVCenter

            enabled: !root.paintOnly
            activeFocusOnTab: true

            opacity: root._player.muted ? 0.5 : 1

            Accessible.role: Accessible.Slider
            Accessible.name: qsTr("Volume")
            AccessibleCompat.id: "volumeSlider"

            Navigation.parentItem: root
            Navigation.leftItem: speaker

            Keys.priority: Keys.BeforeItem

            Keys.onUpPressed: (event) => {
                Player.muted = false
                Player.setVolumeUp()
            }

            Keys.onDownPressed: (event) => {
                Player.muted = false
                Player.setVolumeDown()
            }

            Keys.onPressed: (event) => {
                if (KeyHelper.matchOk(event)) {
                    event.accepted = true
                    Player.muted = !Player.muted
                } else {
                    Navigation.defaultKeyAction(event)
                }
            }

            T.ToolTip.visible: mouseArea.containsMouse || mouseArea.pressed
            T.ToolTip.text: Math.round(root._volume * 100) + "%"

            // The cone: rectangles, one per pixel column, sized by the silhouette of volume.svg
            // (QtQuick.Shapes, Path and Canvas are not in the static Windows build of Qt).
            // A column is the track colour, the gradient of volume.svg (green, yellow, accent) up to
            // 100 %, or the negative colour above 100 %, depending on the volume.
            Item {
                id: coneBody

                anchors.fill: parent

                // anti-aliases the sloped edges of the columns
                layer.enabled: true
                layer.samples: 4

                readonly property int columnCount: Math.max(1, Math.round(width))
                readonly property real columnWidth: width / columnCount
                readonly property var columns: ConeMath.silhouetteColumns(width, height, columnCount)

                readonly property real volumeX: width * Math.min(root._volume / root._maxVolume, 1)
                readonly property real fullX: width * root._fullPosition

                function _mix(from, to, t) {
                    return Qt.rgba(from.r + (to.r - from.r) * t, from.g + (to.g - from.g) * t,
                                   from.b + (to.b - from.b) * t, from.a + (to.a - from.a) * t)
                }

                // the stops of volume.svg at `t`, 0 to 1 over the first 100 %
                function _gradient(t) {
                    return (t < 0.73) ? _mix(theme.fg.positive, theme.fg.neutral, t / 0.73)
                                      : _mix(theme.fg.neutral, theme.fg.primary, (t - 0.73) / 0.27)
                }

                function _columnColor(index) {
                    const x = (index + 0.5) * columnWidth
                    if (x > volumeX)
                        return theme.bg.primary
                    return (x <= fullX) ? _gradient(x / fullX) : theme.fg.negative
                }

                Repeater {
                    model: coneBody.columnCount

                    delegate: Rectangle {
                        required property int index

                        x: index * coneBody.columnWidth
                        y: coneBody.columns[index][0]
                        width: coneBody.columnWidth
                        height: coneBody.columns[index][1] - coneBody.columns[index][0]

                        color: coneBody._columnColor(index)
                    }
                }
            }

            // keyboard focus
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: VLCStyle.dp(2, VLCStyle.scale)

                visible: cone.visualFocus
                radius: height / 2
                color: theme.visualFocus
            }

            // 100 %, when the volume can go above
            Rectangle {
                visible: root._maxVolume > 1

                x: cone.width * root._fullPosition
                anchors.verticalCenter: parent.verticalCenter

                width: VLCStyle.dp(1, VLCStyle.scale)
                height: ConeMath.fillHeightAt(x, cone.width, cone.height)

                color: theme.fg.neutral
            }

            MouseArea {
                id: mouseArea

                // the box of the cone is easier to hit than its outline
                anchors.fill: parent

                enabled: !root.paintOnly
                hoverEnabled: true

                function _adjust(mouse) {
                    let value = ConeMath.volumeAt(mouse.x, width, root._maxVolume)

                    // 100 % is easy to hit, hold Shift for the exact value
                    if (!(mouse.modifiers & Qt.ShiftModifier) && Math.abs(value - 1) < 0.03)
                        value = 1

                    root._pendingVolume = value
                    root._setVolume(value)
                }

                onPressed: (mouse) => {
                    cone.forceActiveFocus(Qt.MouseFocusReason)
                    _adjust(mouse)
                }

                onPositionChanged: (mouse) => {
                    if (pressed)
                        _adjust(mouse)
                }

                onWheel: (wheel) => {
                    if (wheel.angleDelta.y === 0)
                        return

                    const step = (wheel.angleDelta.y > 0) ? 0.05 : -0.05
                    root._setVolume(Math.round((root._player.volume + step) * 100) / 100)
                    wheel.accepted = true
                }
            }
        }
    }
}
