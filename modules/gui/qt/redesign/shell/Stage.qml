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

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Style
import VLC.Redesign

/**
 * @brief The main area of the window. It only follows the state of the shell (it has no
 * state logic of its own, `shellState` is ShellStates.state):
 *   - "browse":    the page of the library (the shell puts it into `pageSlot`)
 *   - "watch":     the video, or the music view when there is no video
 *   - "immersive": the video (the music view if there is no video), nothing else
 *
 * The video surface exists only here or in the mini player card, never in both: it is created
 * while the state is not "browse" and the media has an embedded video.
 */
FocusScope {
    id: root

    // Properties

    // ShellStates.state
    property string shellState: "browse"

    // where the shell puts the page of the library
    readonly property alias pageSlot: pageSlotItem

    readonly property bool showsMedia: root.shellState !== "browse"

    // Functions

    // The pointer or the keyboard is used in an interactive menu (DVD): the navigation box and the
    // button for the bars stay up for a moment and the pointer stays visible.
    function noteInteractiveActivity() {
        interactiveTimer.restart()
    }

    // Signals

    // the user asks for the bars of the immersive state (the pointer does not bring them in a menu)
    signal showBarsRequested()

    // Settings

    Accessible.role: Accessible.Pane
    Accessible.name: root.showsMedia ? qsTr("Player") : qsTr("Library")

    onShellStateChanged: {
        // the pointer is visible when the immersive state starts, then rests
        if (shellState === "immersive")
            pointerRest.restart()
    }

    // Children

    ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    Item {
        id: pageSlotItem

        anchors.fill: parent

        visible: !root.showsMedia
    }

    Loader {
        id: videoLoader

        // The video window of the auto resize compensation looks for this name (see
        // VideoWindowHandler): the loader has the size of the video area
        objectName: "playerSpecializationLoader"

        anchors.fill: parent

        active: root.showsMedia && MainCtx.hasEmbededVideo

        sourceComponent: VideoSurface {
            id: videoSurface

            // nothing is painted behind the video (see Player.qml)
            renderingEnabled: false

            videoSurfaceProvider: MainCtx.videoSurfaceProvider

            // The video does not take the keyboard focus: the keys are sent by the window as hotkeys
            focus: false

            // the pointer of the immersive state hides when it rests
            cursorShape: (root.shellState === "immersive") && !pointerRest.running && !interactiveTimer.running
                         ? Qt.BlankCursor : Qt.ArrowCursor

            // like the stock player: the mouse on the video keeps the interactive menu helpers up
            function onMouseEvent() {
                pointerRest.restart()
                if (Player.isInteractive)
                    interactiveTimer.restart()
            }

            Component.onCompleted: {
                mouseMoved.connect(videoSurface.onMouseEvent)
                mousePressed.connect(videoSurface.onMouseEvent)
                mouseReleased.connect(videoSurface.onMouseEvent)
                mouseDblClicked.connect(videoSurface.onMouseEvent)
            }
        }
    }

    // the pointer of the immersive state hides when it rests
    Timer {
        id: pointerRest

        running: true
        interval: MainCtx.mouseHideTimeout
    }

    // the helpers of an interactive menu (DVD) stay up for a moment after the last mouse or key activity
    Timer {
        id: interactiveTimer

        interval: 3000
    }

    Connections {
        target: MainCtx

        function onNavBoxToggled() {
            interactiveTimer.restart()
        }
    }

    // the navigation buttons of a DVD menu (shown with the navigation button of the control bar)
    NavigationBox {
        id: navBox

        z: 1

        visible: root.showsMedia && Player.isInteractive && navBox.show
                 && (interactiveTimer.running || navBox.hovered || !MainCtx.hasEmbededVideo)

        // the box can be dragged, which breaks these bindings
        x: RedesignStyle.spacingL
        y: root.height - navBox.height - RedesignStyle.spacingL

        dragXMin: 0
        dragXMax: root.width - navBox.width
        dragYMin: 0
        dragYMax: root.height - navBox.height

        Connections {
            target: root

            function onWidthChanged() {
                if (navBox.x > navBox.dragXMax)
                    navBox.x = navBox.dragXMax
            }

            function onHeightChanged() {
                if (navBox.y > navBox.dragYMax)
                    navBox.y = navBox.dragYMax
            }
        }
    }

    // In an interactive menu the bars of the immersive state do not follow the pointer (the menu is
    // under it): this button shows them.
    Widgets.IconToolButton {
        z: 1

        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: RedesignStyle.spacingL
        }

        visible: (root.shellState === "immersive") && Player.isInteractive && MainCtx.hasEmbededVideo
                 && (interactiveTimer.running || hovered)

        font.pixelSize: VLCStyle.icon_large
        text: VLCIcons.expand_inverted
        description: qsTr("Show the controls")

        onClicked: root.showBarsRequested()
    }

    // The music view: the artwork of the playing media and its title. The full music view
    // (large cover, lyrics) replaces it.
    Loader {
        id: musicLoader

        anchors.fill: parent

        active: root.showsMedia && !MainCtx.hasEmbededVideo

        sourceComponent: Item {
            Rectangle {
                anchors.fill: parent

                color: theme.bg.primary
            }

            ColumnLayout {
                anchors.centerIn: parent

                width: Math.min(parent.width - 2 * RedesignStyle.spacingXL, VLCStyle.dp(480, VLCStyle.scale))
                spacing: RedesignStyle.spacingL

                Image {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(parent.width, root.height / 2)
                    Layout.preferredHeight: Layout.preferredWidth

                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    source: (Player.artwork && Player.artwork.toString()) ? Player.artwork
                                                                          : VLCStyle.noArtAlbumCover
                    sourceSize: Qt.size(width * 2, height * 2)
                }

                Text {
                    Layout.fillWidth: true

                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: Player.title
                    font.pixelSize: VLCStyle.fontSize_xlarge
                    color: theme.fg.primary
                }

                Text {
                    Layout.fillWidth: true

                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: Player.artist
                    font.pixelSize: VLCStyle.fontSize_large
                    color: theme.fg.secondary
                }
            }
        }
    }
}
