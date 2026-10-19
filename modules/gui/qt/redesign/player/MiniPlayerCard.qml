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
import QtQuick.Window
import QtCore as QtCore

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Style
import VLC.Util
import VLC.Redesign

/**
 * @brief The floating card of the browse state: the playing video (when the video can be
 * placed anywhere, `showsVideo`) or the artwork of the playing media.
 *
 * The card can be dragged and snaps to the nearest of the four corners of its parent
 * (CardCorner); the corner is persisted. Clicking the card requests the watch state
 * (`activated`, the shell sets `MainCtx.playerView`).
 *
 * The card shows the VideoSurface only while it is visible: the video has one surface at a
 * time, the Stage owns it in the other states.
 */
Item {
    id: root

    // Properties

    // show the live video instead of the artwork
    property bool showsVideo: false

    // the corner the card sits in (persisted)
    readonly property string corner: CardCorner.normalized(persisted.corner)

    // distance of the card from the edges of its parent
    property real margin: RedesignStyle.spacingL

    // size of the area the card moves in
    readonly property real areaWidth: parent ? parent.width : 0
    readonly property real areaHeight: parent ? parent.height : 0

    readonly property bool dragging: dragHandler.active

    readonly property url artworkSource: (Player.artwork && Player.artwork.toString()) ? Player.artwork
                                                                                        : VLCStyle.noArtAlbumCover

    // Signals

    // the card was clicked
    signal activated()

    // Settings

    implicitWidth: RedesignStyle.miniPlayerWidth
    implicitHeight: RedesignStyle.miniPlayerHeight
    width: implicitWidth
    height: implicitHeight

    // the card follows its corner; the drag breaks these bindings, they are restored when the card is dropped
    x: _target.x
    y: _target.y

    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Mini player, show the player")
    Accessible.onPressAction: root.activated()

    // the card can be reached and used with the keyboard
    activeFocusOnTab: true

    Keys.onReturnPressed: root.activated()
    Keys.onEnterPressed: root.activated()
    Keys.onSpacePressed: root.activated()

    // Private

    // the card is placed without animation until the area has its size
    property bool _animate: false

    Component.onCompleted: Qt.callLater(() => { root._animate = true })

    readonly property point _target: CardCorner.position(root.corner, width, height,
                                                         areaWidth, areaHeight, margin)

    function _snap() {
        persisted.corner = CardCorner.nearest(x, y, width, height, areaWidth, areaHeight)
        // back to the bindings, the Behaviors move the card to the corner
        x = Qt.binding(() => root._target.x)
        y = Qt.binding(() => root._target.y)
    }

    // Children

    QtCore.Settings {
        id: persisted

        category: "redesign"

        property string corner: CardCorner.defaultCorner
    }

    Behavior on x {
        enabled: root._animate && !dragHandler.active

        NumberAnimation {
            duration: VLCStyle.duration_short
            easing.type: Easing.OutQuad
        }
    }

    Behavior on y {
        enabled: root._animate && !dragHandler.active

        NumberAnimation {
            duration: VLCStyle.duration_short
            easing.type: Easing.OutQuad
        }
    }

    ColorContext {
        id: theme

        colorSet: ColorContext.Window
    }

    Rectangle {
        anchors.fill: parent

        color: theme.bg.secondary
    }

    ColorContext {
        id: focusTheme

        colorSet: ColorContext.Item

        focused: root.activeFocus
    }

    Image {
        anchors.fill: parent

        visible: !videoLoader.active

        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        source: root.artworkSource
        sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
    }

    Loader {
        id: videoLoader

        anchors.fill: parent

        active: root.showsVideo && root.visible && MainCtx.hasEmbededVideo

        sourceComponent: VideoSurface {
            videoSurfaceProvider: MainCtx.videoSurfaceProvider
        }
    }

    // It is acceptable for effects to exceed the boundaries of the parent
    Widgets.DefaultShadow {
    }

    // the focus ring
    Rectangle {
        anchors.fill: parent

        z: 2

        visible: root.activeFocus

        color: "transparent"
        border.width: VLCStyle.focus_border
        border.color: focusTheme.visualFocus
    }

    // The card takes the mouse before the video does (a click must not pause the video, a double
    // click must not leave it fullscreen), same as the PIP player of the stock interface.
    DoubleClickIgnoringItem {
        anchors.fill: parent

        z: 1

        MouseArea {
            anchors.fill: parent

            cursorShape: dragHandler.active ? Qt.DragMoveCursor : Qt.PointingHandCursor

            onClicked: root.activated()
        }

        DragHandler {
            id: dragHandler

            target: root

            dragThreshold: VLCStyle.dp(4, VLCStyle.scale)
            grabPermissions: PointerHandler.CanTakeOverFromAnything

            xAxis.minimum: 0
            xAxis.maximum: Math.max(0, root.areaWidth - root.width)
            yAxis.minimum: 0
            yAxis.maximum: Math.max(0, root.areaHeight - root.height)

            onActiveChanged: {
                if (!active)
                    root._snap()
            }
        }
    }
}
