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
 *   Rail | LibraryPanel | Stage | right panel
 *   control bar
 *
 * ShellStates selects what is shown (browse, watch or immersive): the Stage shows the video in
 * watch and immersive, the page of the library in browse; the LibraryPanel is a header strip in
 * browse and a drawer beside the video in watch (an overlay when the video can not be placed
 * around it); the MiniPlayerCard shows the playing media over the library in browse. The page
 * of the library is one item that moves between the panel and the Stage. The right panel shows
 * the play queue (the watch sidebar comes later); the queue follows the docked / visible state of
 * the play queue of upstream (MainCtx.playqueuePanel): detached, it stays the window of upstream.
 *
 * Besides the layout, the root provides what MainInterface.qml and MainDisplay.qml provide to
 * their pages: the window background, the interface metrics, the tooltips, the detached play
 * queue window, the dialogs, the notifications, the global shortcuts, the hotkeys, drag and drop
 * of media, the two-finger swipe back, the history navigation of the pages and the resize and
 * shadow of a window with client side decorations.
 */
Item {
    id: root

    // Properties

    // whether the header strip of the library is shown in the browse state
    property bool browsePanelOpen: true

    // Whether the library panel is requested in the watch state: docked beside the video by
    // default (where the video keeps its room), an overlay (which covers the video) only when
    // the user asks for it
    property bool watchPanelOpen: MainCtx.canShowVideoPIP && root._panelFits

    // A docked library panel leaves the stage at least what a docked right panel leaves it
    // (RightPanel.stageMinWidth). The right panel is not counted: it adapts to what is left.
    readonly property bool _panelFits: panelsRow.width - rail.width - libraryPanel.panelWidth >= rightPanel.stageMinWidth

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

    // The pages of the library, same entries as MainDisplay.qml (without the settings of the
    // media library folders). Home is the redesign page, it reads History.viewPath itself to
    // switch to the whole history ("recent"); without a media library it is the stock page.
    readonly property var pageModel: [
        {
            name: "home",
            component: MainCtx.mediaLibraryAvailable ? homePage : null,
            url: "qrc:///qt/qml/VLC/MainInterface/NoMedialibHome.qml"
        }, {
            name: "video",
            url: "qrc:///qt/qml/VLC/MediaLibrary/VideoDisplay.qml"
        }, {
            name: "music",
            url: "qrc:///qt/qml/VLC/MediaLibrary/MusicDisplay.qml"
        }, {
            name: "network",
            url: "qrc:///qt/qml/VLC/Network/BrowseDisplay.qml"
        }, {
            name: "discover",
            url: "qrc:///qt/qml/VLC/Network/DiscoverDisplay.qml"
        }
    ]

    // the library panel is not shown beside the video: it is an overlay, a click outside closes it
    readonly property bool _panelIsOverlay: shellStates.panelMode === "overlay"

    // the player stopped for good: the STOPPED between two items of the playlist (STOPPING,
    // STOPPED, STARTED) is not one, the shell must not flip to the library for it
    readonly property bool _stopped: stopDebounce.stopped

    // the media is playing or paused (or being replaced by the next item)
    readonly property bool _hasMedia: !_stopped

    StopDebounce {
        id: stopDebounce

        input: Player.playingState === Player.PLAYING_STATE_STOPPED

        onSettledStopped: MainCtx.playerView = false
    }

    // Settings

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Main interface")
    AccessibleCompat.id: "mainInterface"

    // Functions

    // Loads the page of History (the navigation of the pages: MainDisplay does the same).
    function loadCurrentHistoryView(focusReason) {
        libraryPages.loadView(History.viewPath, History.viewProp, focusReason)
        contextSaver.restore(History.viewPath)
    }

    // Shows the page of the rail the interface starts on, when History has none (or one that
    // needs the media library, which is not available).
    function _showStartPage() {
        const path = History.viewPath
        const needsLibrary = path.length > 0 && _mediaLibraryPages.includes(path[0])
        if (path.length === 0 || (needsLibrary && !MainCtx.mediaLibraryAvailable)) {
            // nothing to go back to: replace the page instead of stacking one on it
            if (History.previousEmpty)
                History.update(rail.model.defaultPath())
            else
                History.push(rail.model.defaultPath())
        }
        loadCurrentHistoryView(Qt.OtherFocusReason)
    }

    // The one place that decides where the keyboard is, called (delayed, so that the state and the panel
    // mode are final) whenever one of them changes:
    //   - the right panel was just opened: the panel
    //   - the overlay is open: the page in it
    //   - browse: the current page
    //   - watch (panel docked or closed) and immersive: the Stage, whose keys are the hotkeys
    function _focusState() {
        if (root._panelFocusPending) {
            root._panelFocusPending = false
            if (rightPanel.shown) {
                rightPanel.focusContent()
                return
            }
        }

        const showsPage = (shellStates.state === "browse") || (shellStates.panelMode === "overlay")
        if (showsPage) {
            libraryHost.forceActiveFocus(Qt.TabFocusReason)
            // the compact list covers the page: it has the focus (Loader.focus), not the page
            if (libraryPages.currentItem && !compactList.active)
                libraryPages.setCurrentItemFocus(Qt.TabFocusReason)
        } else {
            stage.forceActiveFocus()
        }
    }

    // The explicit actions of the user that leave the video for the library (the title bar button, the
    // "Browse the library" button of the panel, the back gesture): the library is shown in the Stage.
    // Without a way to place the video around the library (see ShellStates.miniPlayerShowsVideo) the
    // video would have no surface in the browse state: it stops, like the stock back button does.
    // Never called when the playback ends by itself.
    function leaveToBrowse() {
        root.browsePanelOpen = true
        if (MainCtx.minimalView)
            MainCtx.minimalView = false
        // fullscreen is the immersive state, the library is not shown in it
        if (Player.fullscreen)
            Player.fullscreen = false
        if (MainCtx.intfMainWindow.visibility === Window.FullScreen)
            MainCtx.toggleInterfaceFullScreen()

        if (root._hasMedia && MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP)
            MainPlaylistController.stop()
        MainCtx.playerView = false
    }

    // The library button of the title bar: from the video to the library and, when there is
    // something to watch or listen to, from the library back to it (else it shows or hides the strip).
    function toggleLibrary() {
        if (shellStates.state !== "browse")
            leaveToBrowse()
        else if (root._hasMedia)
            MainCtx.playerView = true
        else
            root.browsePanelOpen = !root.browsePanelOpen
    }

    // the main menu was opened from the keyboard (with the menu button focused)
    property bool _menuFromKeyboard: false

    // Where the keyboard goes when the main menu closed: back to the menu button if it was opened from
    // it with the keyboard, else where the state wants it. Not when the window lost the focus (the
    // menu launched a dialog) or when something else took the focus meanwhile.
    function _restoreFocusAfterMenu() {
        const win = MainCtx.intfMainWindow
        if (!win.active)
            return

        // nothing has the focus, or it is in a popup (the menu, a submenu: they live in the overlay)
        const focused = win.activeFocusItem
        if (focused && (focused !== win.contentItem)) {
            let inPopup = false
            for (let item = focused; item && !inPopup; item = item.parent)
                inPopup = (item.parent === root.Overlay.overlay)
            if (!inPopup)
                return
        }

        if (root._menuFromKeyboard && titleBar.visible)
            titleBar.focusMenuButton()
        else
            root._focusState()
    }

    // shows the bars of the immersive state for a moment
    function _showBars() {
        shellStates.recentKeyActivity = true
        keyActivityTimer.restart()
    }

    // the right panel was opened: the next _focusState puts the keyboard in it (once)
    property bool _panelFocusPending: false

    // the interface finished loading (the panel restored from the settings does not take the keyboard)
    property bool _completed: false

    // The Queue button, and the shortcut of upstream: with the play queue docked it is the queue
    // panel; detached (the user chose that) it is the window of upstream, which is shown or hidden.
    function toggleQueue() {
        if (MainCtx.playqueuePanel.docked) {
            rightPanel.toggle("queue")
        } else {
            MainCtx.playqueuePanel.visible = !MainCtx.playqueuePanel.visible
            const window = playlistWindowLoader.item
            if (MainCtx.playqueuePanel.visible && window)
                window.raise()
        }
    }

    // The mode of the right panel follows the state of the play queue of upstream, which also
    // changes with its shortcut (Ctrl+L), its drop button and its saved state; and the other way
    // around, so that the detached window and the menu of upstream stay right.
    function _syncPanelToQueue() {
        const panel = MainCtx.playqueuePanel
        rightPanel.mode = RightPanelLogic.modeForQueueState(rightPanel.mode, panel.docked, panel.visible)
    }

    // Events

    Component.onCompleted: {
        _showStartPage()
        _syncPanelToQueue()
        root._completed = true
        Qt.callLater(_focusState)
        // The request of MainCtx is queued at startup and may have been sent before this item
        // existed: ask again here (a second request while the onboarding is open is ignored).
        if (MainCtx.hasFirstrun)
            Qt.callLater(ShellActions.onboardingRequested)
    }

    // The keys no item took: the search shortcut, else a hotkey. The video does not take the keyboard
    // focus, so in the watch and immersive states every key ends up here, which also keeps the bars of
    // the immersive state up while the keyboard is used. (The window does not turn the keys into
    // hotkeys by itself: that is MainCtx.preferHotkeys, which stays off.) A held Space repeats: only
    // its press is the hotkey (PlayKeyLogic), or each repeat would toggle play/pause again.
    Keys.onPressed: (event) => {
        if (Player.isInteractive)
            // in a DVD menu the keys are for the menu: they do not bring up the bars
            stage.noteInteractiveActivity()
        else
            root._showBars()

        if ((event.key === Qt.Key_Escape) && UiVisibility.hidden) {
            // Hide UI ends first (before the overlay and the fullscreen)
            UiVisibility.hidden = false
        } else if ((event.key === Qt.Key_Escape) && root._panelIsOverlay) {
            // the overlay closes first
            root.watchPanelOpen = false
        } else if (KeyHelper.matchSearch(event)) {
            MainCtx.search.askShow()
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            // the focus is about to move on purpose: not taken back by the control bar guard
            if (controlBar)
                controlBar.endFocusGuard()
            event.accepted = false
            return
        } else if (PlayKeyLogic.forwardsAsHotkey(event.key, event.isAutoRepeat)) {
            MainCtx.sendHotkey(event.key, event.modifiers)
        }
        event.accepted = true
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
        panelFits: root._panelFits
        hasMedia: root._hasMedia
        panelRequested: (shellStates.state === "browse") ? root.browsePanelOpen : root.watchPanelOpen

        // the pointer within 80 px of an edge shows the bar of that edge in the immersive state
        // (not in an interactive menu, the DVD menu is under the pointer there: the bars come with the button of the Stage)
        pointerNearTop: pointer.hovered && !Player.isInteractive && (pointer.point.position.y < MainCtx.dp(80))
        pointerNearBottom: pointer.hovered && !Player.isInteractive && (pointer.point.position.y > (root.height - MainCtx.dp(80)))
        // the track popup is placed above a button of the bottom bar: the bar stays while it is open
        keepBottomBar: trackPopup.opened
        // the main menu opens under the menu button of the title bar: the bar stays while it is open
        keepTopBar: mainMenu.opened
        // Hide UI: the right-click menu (C++) and Ctrl+H toggle it, Esc ends it
        uiHidden: UiVisibility.hidden

        // Hide UI is about the player: the library always comes back with its bars, and they are
        // not hidden the next time the player is shown
        onStateChanged: {
            if (state === "browse")
                UiVisibility.hidden = false
        }
    }

    // Hide UI. The stock Ctrl+H (the minimal view, GlobalShortcuts.qml) is turned off below. Only
    // while the player is shown: the library has no bars to hide.
    Shortcut {
        sequence: "Ctrl+H"
        context: Qt.ApplicationShortcut
        enabled: MainCtx.useGlobalShortcuts && (shellStates.state !== "browse")

        onActivated: UiVisibility.toggle()
    }

    HoverHandler {
        id: pointer
    }

    // remembers the sort of each page
    ModelSortSettingHandler {
        id: contextSaver
    }

    Connections {
        target: MainCtx.sort

        function onCriteriaChanged(criteria) {
            contextSaver.save(History.viewPath)
        }

        function onOrderChanged(order) {
            contextSaver.save(History.viewPath)
        }
    }

    // the interface is asked to show itself (second instance, tray)
    Connections {
        target: MainCtx

        function onAskShow() {
            root._showBars()
        }

        // first run: the onboarding replaces the QWidgets wizard
        function onRequestRedesignOnboarding() {
            ShellActions.onboardingRequested()
        }
    }

    // The accent is live (Settings, onboarding): the palettes read qt-accent-color again. The
    // palette of the interface goes last, the one that installs the palette of the QWidgets.
    Connections {
        target: RedesignSettings.item("qt-accent-color")

        function onValueChanged() {
            VLCStyle.darkPalette.reloadAccent()
            VLCStyle.palette.reloadAccent()
        }
    }

    Connections {
        target: History

        function onNavigate(focusReason) {
            root.loadCurrentHistoryView(focusReason)

            // a page asked for while watching is shown beside the video
            if (shellStates.state === "watch")
                root.watchPanelOpen = true
        }
    }

    Connections {
        target: shellStates

        function onStateChanged() {
            // the track popup does not float over the library
            if (shellStates.state === "browse")
                trackPopup.close(false)
            Qt.callLater(root._focusState)
        }

        function onPanelModeChanged() {
            Qt.callLater(root._focusState)
        }
    }

    Connections {
        target: MainCtx.playqueuePanel

        function onVisibleChanged() {
            root._syncPanelToQueue()
        }

        function onDockedChanged() {
            root._syncPanelToQueue()
        }
    }

    Connections {
        target: ShellActions

        function onQueueRequested() {
            root.toggleQueue()
        }
    }

    Component {
        id: homePage

        HomePage {
            // The page reads History.viewPath itself ("home", "recent"): there is nothing to load
            // for a sub path, the loader only has to focus it.
            function loadView(path, properties, focusReason) {
                if (focusReason !== Qt.OtherFocusReason)
                    setCurrentItemFocus(focusReason)
            }
        }
    }

    Item {
        id: shell

        anchors.fill: parent
        anchors.topMargin: MainCtx.windowExtendedMargin
        anchors.leftMargin: MainCtx.windowExtendedMargin
        anchors.rightMargin: MainCtx.windowExtendedMargin
        anchors.bottomMargin: MainCtx.windowExtendedMargin

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

        // Two-finger swipe back (touchscreen, touchpad): copied from MainInterface.qml
        // (historyDragHandler and goingBackIndicator), which has no component to reuse.
        DragHandler {
            id: historyDragHandler

            acceptedDevices: PointerDevice.TouchScreen | PointerDevice.TouchPad

            target: null

            minimumPointCount: 2
            maximumPointCount: 2

            grabPermissions: PointerHandler.CanTakeOverFromAnything

            yAxis.enabled: false

            // Qt version check in disguise, only available starting with 6.5:
            enabled: !!xAxis?.activeValueChanged

            property double accumulatedDelta: 0.0

            readonly property real threshold: 80.0

            function onXAxisActiveValueChanged(delta) {
                // We do not want to set enabled based on history condition, because the gesture should be captured
                // regardless to prevent confusion:
                if (History.previousEmpty && (MainCtx.effectiveMainInterfaceMode === MainCtx.MAININTERFACE_MODE_MAINDISPLAY))
                    return

                historyDragHandler.accumulatedDelta = Math.min(threshold, historyDragHandler.accumulatedDelta + delta)
            }

            Component.onCompleted: {
                if (historyDragHandler?.xAxis?.activeValueChanged) {
                    xAxis.activeValueChanged.connect(historyDragHandler, onXAxisActiveValueChanged)
                }
            }

            onActiveChanged: {
                if (!active) {
                    if (historyDragHandler.accumulatedDelta >= threshold) {
                        if (MainCtx.playerView)
                            root.leaveToBrowse()
                        else if (MainCtx.minimalView)
                            MainCtx.minimalView = false
                        else
                            History.previous()
                    }

                    historyDragHandler.accumulatedDelta = 0.0
                    accumulatedDelta = 0.0
                }
            }
        }

        // Going back indicator:
        Rectangle {
            id: goingBackIndicator

            z: 100

            anchors.verticalCenter: parent.verticalCenter

            visible: (historyDragHandler.accumulatedDelta > 0.0)

            scale: Math.min(Math.max(historyDragHandler.accumulatedDelta / historyDragHandler.threshold, 0.2), 1.0)

            readonly property real margin: VLCStyle.dp(128, VLCStyle.scale)

            x: (historyDragHandler.accumulatedDelta / historyDragHandler.threshold * margin)

            implicitWidth: implicitHeight
            implicitHeight: backArrowText.implicitHeight + VLCStyle.margin_small
            radius: (width / 2)

            border.width: 1
            border.color: theme.accent
            border.pixelAligned: (radius < Number.EPSILON)

            color: (historyDragHandler.accumulatedDelta >= historyDragHandler.threshold) ? theme.accent
                                                                                         : theme.bg.primary

            Behavior on color {
                ColorAnimation {
                    duration: VLCStyle.duration_short
                }
            }

            Widgets.IconLabel {
                id: backArrowText

                anchors.centerIn: parent

                text: VLCIcons.back

                font.pixelSize: VLCStyle.fontSize_xxxlarge * 1.2

                color: (historyDragHandler.accumulatedDelta >= historyDragHandler.threshold) ? theme.bg.primary
                                                                                             : theme.accent
            }

            Widgets.RoundedRectangleShadow {
                opacity: (historyDragHandler.accumulatedDelta >= historyDragHandler.threshold) ? 1.0
                                                                                               : 0.0

                color: theme.accent

                blurRadius: VLCStyle.dp(8, VLCStyle.scale)

                compensationFactor: 3.0

                visible: (opacity > 0.0)

                Behavior on opacity {
                    NumberAnimation {
                        duration: VLCStyle.duration_short
                    }
                }
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

        // the play queue in its own window (when it is not docked)
        Loader {
            id: playlistWindowLoader

            asynchronous: true
            active: !MainCtx.playqueuePanel.docked
            source: "qrc:///qt/qml/VLC/Playlist/PlaylistDetachedWindow.qml"
        }

        Connections {
            target: Player

            function onHasVideoOutputChanged() {
                // a video starts: show it
                if (Player.hasVideoOutput && MainCtx.hasEmbededVideo)
                    MainCtx.playerView = true
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

        // the content, clipped to the window when the shadow is not clipped by a depth test:
        // the shadow is a child of `shell` and extends outside of it, so `shell` itself is not clipped
        Item {
            id: content

            anchors.fill: parent

            // If there is depth buffer, clipping is not necessary:
            clip: _extendedFrameVisible && !windowShadow.hasDepthBuffer

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
                    id: panelsRow

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    spacing: 0

                    Rail {
                        id: rail

                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignTop

                        visible: shellStates.state !== "immersive"
                    }

                    // the library panel, the stage and the mini player card
                    Item {
                        id: body

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Stage {
                            id: stage

                            anchors {
                                left: (libraryPanel.mode === "docked") ? libraryPanel.right : parent.left
                                top: (libraryPanel.mode === "strip") ? libraryPanel.bottom : parent.top
                                right: parent.right
                                bottom: parent.bottom
                            }

                            shellState: shellStates.state

                            onShowBarsRequested: root._showBars()
                        }

                        // the library over the video: a click outside of the panel closes it
                        MouseArea {
                            anchors.fill: stage

                            z: 1

                            visible: root._panelIsOverlay

                            onClicked: root.watchPanelOpen = false

                            ColorContext {
                                id: scrimTheme

                                colorSet: ColorContext.Window
                            }

                            Rectangle {
                                anchors.fill: parent

                                color: scrimTheme.bg.primary
                                opacity: 0.6
                            }
                        }

                        LibraryPanel {
                            id: libraryPanel

                            z: 2

                            anchors {
                                left: parent.left
                                top: parent.top
                            }

                            height: strip ? implicitHeight : parent.height

                            mode: (shellStates.panelMode === "hidden") ? "hidden"
                                                                       : (shellStates.state === "browse") ? "strip"
                                                                                                          : shellStates.panelMode
                            title: root.pageTitle
                            page: libraryPages

                            onBrowseRequested: root.leaveToBrowse()
                        }

                        // The pages of the library. It is one item: the panel shows it beside the video,
                        // the stage in the browse state, the pages keep their state when it moves.
                        FocusScope {
                            id: libraryHost

                            parent: (shellStates.state === "browse") ? stage.pageSlot : libraryPanel.body
                            // (no anchors: they would point to the old parent while it changes)
                            width: parent.width
                            height: parent.height

                            Navigation.cancelAction: function() {
                                // Esc ends Hide UI first, wherever the focus is (see Keys.onPressed)
                                if (UiVisibility.hidden)
                                    UiVisibility.hidden = false
                                else if (root._panelIsOverlay)
                                    root.watchPanelOpen = false
                                else if (shellStates.state === "browse")
                                    History.previous(Qt.BacktabFocusReason)
                                else
                                    stage.forceActiveFocus()
                            }

                            Widgets.PageLoader {
                                id: libraryPages

                                anchors.fill: parent

                                focus: !compactList.active

                                pageModel: root.pageModel

                                Navigation.parentItem: libraryHost
                            }

                            // The "list" view mode (always beside the video): the items of the page in
                            // compact rows, over the page, which keeps its own view underneath.
                            Loader {
                                id: compactList

                                anchors.fill: parent

                                active: libraryPanel.showsCompactList
                                focus: active

                                sourceComponent: CompactListView {
                                    content: libraryPanel.pageContent

                                    Navigation.parentItem: libraryHost
                                }
                            }
                        }

                        Item {
                            id: cardArea

                            anchors.fill: stage

                            z: 3

                            MiniPlayerCard {
                                visible: (shellStates.state === "browse")
                                         && root._hasMedia

                                showsVideo: shellStates.miniPlayerShowsVideo

                                onActivated: MainCtx.playerView = true
                            }
                        }
                    }

                    // Slot of the right panel (queue, watch sidebar): it takes the room of a docked
                    // panel, none for an overlay, which extends to the left over the stage.
                    Item {
                        id: rightPanelSlot

                        Layout.fillHeight: true
                        Layout.preferredWidth: rightPanel.slotWidth

                        z: 5

                        RightPanel {
                            id: rightPanel

                            anchors {
                                right: parent.right
                                top: parent.top
                                bottom: parent.bottom
                            }

                            // the immersive stage is the whole window: the panel floats over the video
                            forceOverlay: shellStates.state === "immersive"
                            // what the rail and a docked library panel leave
                            freeWidth: panelsRow.width
                                       - (rail.visible ? rail.width : 0)
                                       - ((libraryPanel.mode === "docked") ? libraryPanel.width : 0)

                            onModeChanged: {
                                const panel = MainCtx.playqueuePanel
                                // the upstream state follows the panel (see _syncPanelToQueue)
                                if (panel.docked && (panel.visible !== (mode === "queue")))
                                    panel.visible = (mode === "queue")

                                if (mode !== "" && root._completed)
                                    root._panelFocusPending = true
                                Qt.callLater(root._focusState)
                            }
                        }
                    }
                }

                // The update pane of upstream (UpdatePane.qml, reused as is), a banner above the control
                // bar, the same Loader as MainDisplay.qml: it opens itself for the status of UpdateModel
                // and is dismissed by its button. WARNING: the object name is how C++ (MainCtx::getUpdateModel)
                // knows this pane is loaded; without it a modal update dialog opens instead.
                // UpdateModel only exists with UPDATE_CHECK, hence the typeof guard (the Loader stays inactive).
                Item {
                    id: updatePaneSlot

                    Layout.fillWidth: true
                    Layout.preferredHeight: updatePaneLoader.height

                    // not in the immersive state (the bars are hidden there)
                    visible: shellStates.state !== "immersive"

                    Loader {
                        id: updatePaneLoader

                        objectName: "updatePaneLoader"

                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }

                        readonly property bool updateModelIsAvailable: (typeof UpdateModel !== 'undefined')

                        active: updateModelIsAvailable && (shouldShow || height > 0.0)

                        property int _updateStatusOnDismissal: -1

                        readonly property bool shouldShow: {
                            if (!updateModelIsAvailable)
                                return false

                            if (UpdateModel.explicitCheck)
                                return (UpdateModel.updateStatus !== UpdateModel.Unchecked)

                            if (UpdateModel.updateStatus === _updateStatusOnDismissal)
                                return false // already dismissed with the same status

                            switch (UpdateModel.updateStatus) {
                                case UpdateModel.Unchecked:
                                case UpdateModel.Checking:
                                case UpdateModel.UpToDate:
                                    return false
                                default:
                                    return true
                            }
                        }

                        function dismiss() {
                            if (updateModelIsAvailable)
                                _updateStatusOnDismissal = UpdateModel.updateStatus

                            height = 0.0
                        }

                        onShouldShowChanged: {
                            if (shouldShow)
                                height = Qt.binding(() => { return implicitHeight })
                        }

                        onActiveChanged: {
                            if (updateModelIsAvailable && !active)
                                UpdateModel.explicitCheck = undefined // Resets the property
                        }

                        clip: (height < implicitHeight)

                        Behavior on height {
                            id: updatePaneHeightBehavior

                            NumberAnimation {
                                easing.type: Easing.InOutSine
                                duration: VLCStyle.duration_long
                            }
                        }

                        source: "qrc:///qt/qml/VLC/MainInterface/UpdatePane.qml"

                        onLoaded: {
                            item.dismissRequested.connect(function() {
                                updatePaneLoader.dismiss()
                                // the pane (maybe with the keyboard) is going away
                                Qt.callLater(root._focusState)
                            })

                            // the height animates here, not inside of the item as well
                            item.animations = Qt.binding(function() { return !updatePaneHeightBehavior.enabled })
                        }
                    }
                }

                // the control bar: a row below the panels; in the immersive state it takes no room
                // and floats over the stage instead
                Item {
                    id: controlBarSlot

                    Layout.fillWidth: true
                    Layout.preferredHeight: (shellStates.bottomBarVisible && (shellStates.state !== "immersive")) ? controlBar.implicitHeight
                                                                                                                  : 0

                    RedesignControlBar {
                        id: controlBar

                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }

                        visible: shellStates.bottomBarVisible

                        // ShellActions.queueRequested is connected above (toggleQueue);
                        // sidebarRequested where the watch sidebar is; trackPopupRequested is
                        // connected below, at the track popup
                    }
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
                libraryActive: shellStates.state === "browse"

                onLibraryToggleRequested: root.toggleLibrary()

                onLibraryRequested: (folderUrl) => {
                    root.browsePanelOpen = true
                    root.watchPanelOpen = true
                    libraryPanel.openAt(folderUrl)
                }

                onMenuRequested: (globalPos) => {
                    // opened with the keyboard: the focus goes back to the button when it closes
                    root._menuFromKeyboard = titleBar.menuButtonKeyboardFocus
                    mainMenu.openAtGlobal(globalPos)
                }
            }

            // --- Menus (host lines of the menus; the main menu opened by the title bar) ---

            // The main menu, in place of the menu bar of the classic interface. It closes when the shell
            // changes state (a menu does not follow the bars it was opened from). It keeps the title bar
            // while it is open (shellStates.keepTopBar), and the keyboard goes back to where it was.
            MainMenu {
                id: mainMenu

                onClosed: Qt.callLater(root._restoreFocusAfterMenu)
            }

            Connections {
                target: shellStates

                function onStateChanged() {
                    mainMenu.dismiss()
                }
            }

            // The modal dialogs of the redesign (network stream, new playlist...), opened by the requests
            // of ShellActions; the keyboard goes back to where it belongs when one closes.
            DialogHost {
                id: dialogHost

                backdrop: content

                onClosed: Qt.callLater(root._focusState)
            }

            // The stock control-bar control LangButton (a profile may contain it) opens its tracks menu in
            // the item with this id (`rootPlayer` in the stock player), above `positionSliderY`.
            Item {
                id: g_mainDisplay

                readonly property real positionSliderY: content.height - controlBar.height

                anchors.fill: parent
                enabled: false
            }

            // The subtitle, audio and video tracks, above the button of the control bar that opened
            // them. It stays open while tracks are chosen and leaves with the player.
            TrackPopup {
                id: trackPopup

                z: 15

                anchors.fill: parent

                // the keyboard focus was in the popup and its button can not take it
                onClosed: Qt.callLater(root._focusState)
            }

            Connections {
                target: ShellActions

                function onTrackPopupRequested(tab, anchor) {
                    // the popup does not float over the library
                    if (shellStates.state === "browse")
                        return
                    trackPopup.toggle(tab, anchor)
                }
            }

            Connections {
                target: shellStates

                // the bars are hidden: there is no button to anchor the popup
                function onUiHiddenChanged() {
                    if (shellStates.uiHidden)
                        trackPopup.close(false)
                }
            }

            // The dialogs of VLC (questions, login, progress, errors): there must be one instance
            // (it provides the models of the dialogs to the core), above the control bar.
            Dialogs {
                z: 20

                bgContent: shell

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                    bottomMargin: controlBarSlot.height
                }
            }

            Widgets.FloatingNotification {
                z: 21

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    bottomMargin: controlBarSlot.height + VLCStyle.margin_large
                    leftMargin: VLCStyle.margin_large
                    rightMargin: VLCStyle.margin_large
                }
            }
        }

        Loader {
            asynchronous: true
            source: "qrc:///qt/qml/VLC/Menus/GlobalShortcuts.qml"

            // Ctrl+P opens the Settings modal (DialogHost.qml): the stock shortcut of the same key is
            // turned off, or the two would be ambiguous and neither would fire. F10 (the menu bar,
            // which the redesign does not have) is turned off too, so that the key is free for a hotkey,
            // and Ctrl+H (the minimal view of the stock interface), which is Hide UI here.
            // UPSTREAM COUPLING (docs/redesign/upstream-touchpoints.md): it looks for the Shortcut of
            // GlobalShortcuts.qml that has this key; without a match nothing is changed.
            onLoaded: {
                for (const child of item.data) {
                    if (child.portableText === "Ctrl+P" || child.portableText === "F10" || child.portableText === "Ctrl+H")
                        child.enabled = false
                }
            }
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
