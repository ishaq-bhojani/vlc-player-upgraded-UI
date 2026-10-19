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

// NOTE: All available modules used throughout the interface, at least the ones
//       that are unconditionally available, must be imported here as well, so
//       that if they can not be imported the interface can close gracefully:
import QtQml
import QtQml.Models
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Templates
import QtQuick.Window

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.Playlist
import VLC.Player
import VLC.Dialogs
import VLC.Menus
import VLC.Network
import VLC.PlayerControls
import VLC.Redesign

/**
 * @brief Root item of the interface when the redesign is enabled (qt-redesign), loaded
 * instead of MainInterface.qml (see redesign::rootQmlUrl).
 *
 *   TitleBar
 *   Rail | library panel | Stage | right panel
 *   control bar
 *
 * ShellStates selects what is shown (browse, watch or immersive). The Stage still hosts
 * the pages of the stock interface (MainDisplay, Player, MinimalView) that bring their own
 * dialogs, control bar and panels, it is replaced by the redesign views later. The
 * library panel, right panel and control bar are slots without content for now.
 *
 * Besides the layout, the root provides what MainInterface.qml provides to its pages: the
 * window background, the interface metrics, the tooltips, the detached play queue window,
 * the global shortcuts, drag and drop of media, and the resize and shadow of a window with
 * client side decorations. The pages find `playlistWindowLoader` of this file by id.
 */
Item {
    id: root

    // Properties

    // whether the library panel is requested (browse: docked beside the stage)
    property bool libraryPanelOpen: true

    // the folder the library was last asked to show (file:// URL), for the library panel
    property string libraryFolderUrl

    // title shown while no media with a folder is playing: the label of the current rail entry
    readonly property string pageTitle: {
        const id = rail.model.selectedId(History.viewPath)
        const items = rail.model.items
        for (let i = 0; i < items.length; ++i) {
            if (items[i].id === id)
                return items[i].label
        }
        return MainCtx.productName
    }

    property bool _extendedFrameVisible: MainCtx.windowSuportExtendedFrame
                                      && MainCtx.clientSideDecoration
                                      && (MainCtx.intfMainWindow.visibility === Window.Windowed)

    // pages of the media library, they only exist with a media library
    readonly property var _mediaLibraryPages: ["home", "video", "music"]

    // Settings

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Main interface")
    AccessibleCompat.id: "mainInterface"

    // Functions

    // Shows the page of the rail the interface starts on, when History has none (or one that
    // needs the media library, which is not available). Called when the pages are loaded,
    // as MainDisplay sets "home" on its own first load.
    function _showStartPage() {
        const path = History.viewPath
        const needsLibrary = path.length > 0 && _mediaLibraryPages.includes(path[0])
        if (path.length > 0 && !(needsLibrary && !MainCtx.mediaLibraryAvailable))
            return

        const start = rail.model.defaultPath()
        const page = stageLoader.item
        if (History.previousEmpty && page && (typeof page.loadCurrentHistoryView === "function")) {
            // nothing to go back to: replace the page instead of stacking one on it
            History.update(start)
            page.loadCurrentHistoryView(Qt.OtherFocusReason)
        } else {
            History.push(start)
        }
    }

    // Events

    Component.onCompleted: Qt.callLater(_showStartPage)

    // key presses show the bars of the immersive state
    Keys.onPressed: (event) => {
        shellStates.recentKeyActivity = true
        keyActivityTimer.restart()
        // only observed here
        event.accepted = false
    }

    Timer {
        id: keyActivityTimer

        interval: 2000

        onTriggered: shellStates.recentKeyActivity = false
    }

    // Children

    ShellStates {
        id: shellStates

        playerView: MainCtx.playerView
        // the fullscreen of the player, or the one of the window (F11, the title bar button)
        fullscreen: Player.fullscreen || (MainCtx.intfMainWindow.visibility === Window.FullScreen)
        minimalView: MainCtx.minimalView
        canShowVideoPIP: MainCtx.canShowVideoPIP
        panelRequested: root.libraryPanelOpen

        // the pointer within 80 px of an edge shows the bar of that edge in the immersive state
        pointerNearTop: pointer.hovered && (pointer.point.position.y < MainCtx.dp(80))
        pointerNearBottom: pointer.hovered && (pointer.point.position.y > (root.height - MainCtx.dp(80)))
    }

    HoverHandler {
        id: pointer
    }

    Item {
        id: shell

        anchors.fill: parent
        anchors.topMargin: MainCtx.windowExtendedMargin
        anchors.leftMargin: MainCtx.windowExtendedMargin
        anchors.rightMargin: MainCtx.windowExtendedMargin
        anchors.bottomMargin: MainCtx.windowExtendedMargin

        // If there is depth buffer, clipping is not necessary:
        clip: _extendedFrameVisible && !windowShadow.hasDepthBuffer

        Binding {
            target: VLCStyle
            property: "appWidth"
            value: shell.width
        }

        Binding {
            target: VLCStyle
            property: "appHeight"
            value: shell.height
        }

        Binding {
            target: MainCtx
            property: "windowExtendedMargin"
            value: _extendedFrameVisible ? (Qt.platform.pluginName.startsWith("wayland") ? 60 : 30) : 0
        }

        Window.onWindowChanged: {
            if (Window.window && !Qt.colorEqual(Window.window.color, "transparent")) {
                Window.window.color = Qt.binding(function() { return theme.bg.primary })
            }
        }

        ColorContext {
            id: theme

            palette: VLCStyle.palette
            colorSet: ColorContext.View
        }

        Widgets.ToolTipExt {
            id: attachedToolTip

            parent: null
            z: 99
            colorContext.palette: parent && parent.colorContext ? parent.colorContext.palette
                                                                : VLCStyle.palette

            Component.onCompleted: {
                MainCtx.setAttachedToolTip(this)
            }
        }

        Widgets.PointingTooltip {
            parent: null
            z: 99

            colorContext.palette: parent && parent.colorContext ? parent.colorContext.palette
                                                                : VLCStyle.palette

            Widgets.PointingToolTipAttached.instance: this

            Component.onDestruction: {
                console.assert(Widgets.PointingToolTipAttached.instance === this)
                Widgets.PointingToolTipAttached.instance = null
            }
        }

        // the play queue in its own window, the pages use it to find the list for drag and drop
        Loader {
            id: playlistWindowLoader

            asynchronous: true
            active: !MainCtx.playqueuePanel.docked
            source: "qrc:///qt/qml/VLC/Playlist/PlaylistDetachedWindow.qml"
        }

        Connections {
            target: Player

            function onPlayingStateChanged() {
                if (Player.playingState === Player.PLAYING_STATE_STOPPED) {
                    MainCtx.playerView = false
                }
            }
        }

        // media dropped on the window (same behaviour as MainInterface.qml)
        DropArea {
            anchors.fill: parent
            z: -1

            onEntered: (drag) => {
                // Do not handle internal drag here:
                if (!drag.source) {
                    // Foreign drag, check if valid:
                    if (drag.hasUrls || drag.hasText) {
                        drag.accepted = true
                        return
                    }
                }

                drag.accepted = false
            }

            onDropped: (drop) => {
                let urls = []
                if (drop.hasUrls) {

                    for (let i = 0; i < drop.urls.length; i++)
                        urls.push(drop.urls[i])

                } else if (drop.hasText) {
                    /* Browsers give content as text if you dnd the addressbar,
                       so check if mimedata has valid url in text and use it
                       if we didn't get any normal Urls()*/

                    if (drop.text.includes("\n")) {
                        const normalizedLineEndingsDropText = drop.text.replace("\r\n", "\n")
                        urls.push(...normalizedLineEndingsDropText.split("\n"))
                    } else {
                        urls.push(drop.text)
                    }
                }

                if (urls.length > 0) {
                    /* D&D of a subtitles file, add it on the fly */
                    if (Player.isStarted && urls.length == 1) {
                        if (Player.associateSubtitleFile(urls[0])) {
                            drop.accept()
                            return
                        }
                    }

                    MainPlaylistController.append(urls, true)
                    drop.accept()
                }
            }
        }

        // the stage and the panels fill the window; in the immersive state the title bar
        // floats over them instead of pushing them down
        ColumnLayout {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                top: (titleBar.visible && (shellStates.state !== "immersive")) ? titleBar.bottom
                                                                              : parent.top
            }

            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                spacing: 0

                Rail {
                    id: rail

                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop

                    visible: shellStates.state !== "immersive"
                }

                // slot of the library panel (resizable drawer beside the stage)
                Item {
                    id: libraryPanelSlot

                    Layout.fillHeight: true
                    Layout.preferredWidth: 0

                    visible: shellStates.panelMode === "docked"
                }

                // the stage: for now the pages of the stock interface
                Item {
                    id: stage

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Loader {
                        id: stageLoader

                        anchors.fill: parent

                        focus: true

                        source: {
                            // priority applies accross modes
                            // minimal > player > medialib
                            // MEDIALIB_MODE flag should always be set

                            switch (MainCtx.effectiveMainInterfaceMode) {
                            case MainCtx.MAININTERFACE_MODE_MINIMAL:
                                return "qrc:///qt/qml/VLC/Player/MinimalView.qml"
                            case MainCtx.MAININTERFACE_MODE_PLAYER:
                                return "qrc:///qt/qml/VLC/Player/Player.qml"
                            default:
                                console.error("unexpected interface mode", MainCtx.effectiveMainInterfaceMode)
                            case MainCtx.MAININTERFACE_MODE_MAINDISPLAY:
                                return "qrc:///qt/qml/VLC/MainInterface/MainDisplay.qml"
                            }
                        }
                    }
                }

                // slot of the right panel (queue, watch sidebar)
                Item {
                    id: rightPanelSlot

                    Layout.fillHeight: true
                    Layout.preferredWidth: 0

                    visible: false
                }
            }

            // slot of the control bar
            Item {
                id: controlBarSlot

                Layout.fillWidth: true
                Layout.preferredHeight: 0

                visible: shellStates.bottomBarVisible
            }
        }

        TitleBar {
            id: titleBar

            z: 10

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }

            visible: shellStates.topBarVisible

            pageTitle: root.pageTitle
            libraryPanelOpen: root.libraryPanelOpen

            onLibraryToggleRequested: root.libraryPanelOpen = !root.libraryPanelOpen

            onLibraryRequested: (folderUrl) => {
                root.libraryFolderUrl = folderUrl
                root.libraryPanelOpen = true
            }

            // the menu itself comes with the menu task, nothing opens yet
            onMenuRequested: (globalPos) => {}
        }

        Loader {
            asynchronous: true
            source: "qrc:///qt/qml/VLC/Menus/GlobalShortcuts.qml"
        }

        Loader {
            active: {
                const windowVisibility = MainCtx.intfMainWindow.visibility
                return MainCtx.clientSideDecoration && !MainCtx.platformHandlesResizeWithCSD()
                        && (windowVisibility !== Window.Maximized)
                        && (windowVisibility !== Window.FullScreen)

            }
            Component.onCompleted: {
                setSource(
                    "qrc:///qt/qml/VLC/Widgets/CSDMouseStealer.qml", {
                        target: shell,
                        anchorInside: Qt.binding(() => !_extendedFrameVisible)
                    })
            }
        }
    }

    // draw the window drop shadow ourselves when the windowing system does not
    // provide them but supports the extended frame
    Widgets.RoundedRectangleShadow {
        id: windowShadow

        parent: shell
        hollow: (z >= 0) || (Window.window && (Window.window.color.a < 1.0)) // the interface may be translucent if the window has backdrop blur
        // See MainInterface.qml: no blending, the hollow mode discards the inner pixels
        blending: false
        visible: _extendedFrameVisible && !MainCtx.platformHandlesShadowsWithCSD()
        color: Qt.rgba(0.0, 0.0, 0.0, 0.5) // sg opacity < 1.0 force enables blending, so we adjust the color instead

        // If there is depth buffer, we enable hollow mode. The inner area is discarded, so we can do this:
        z: hasDepthBuffer ? 99 : -1

        readonly property bool hasDepthBuffer: (Window.window && MainCtx.windowHasDepthBuffer(Window.window))

        blurRadius: (MainCtx.windowExtendedMargin / windowShadow.compensationFactor)

        compensationFactor: MainCtx.intfMainWindow.active ? (implicitCompensationFactor)
                                                          : (implicitCompensationFactor * 2)

        Behavior on compensationFactor {
            // FIXME: Use UniformAnimator instead
            NumberAnimation {
                duration: VLCStyle.duration_veryShort
            }
        }
    }
}
