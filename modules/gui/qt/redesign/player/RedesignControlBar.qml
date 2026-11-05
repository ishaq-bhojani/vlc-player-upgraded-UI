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
import QtQuick
import QtQml
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.PlayerControls
import VLC.Util
import VLC.Widgets as Widgets
import VLC.Redesign

/**
 * @brief The control bar of the redesign (spec 11.1): one thin row over the bottom of the
 * video, laid out by the profile selected in Customize Player ("Vireo" by default:
 * previous, play, next, seek bar | volume, subtitles, audio, settings, queue, fullscreen).
 *
 * It hosts the upstream PlayerControlLayout, so the profile model, the Customize Player editor
 * and the item registry (PlayerControlbarControls) are the stock ones. The root window shows
 * it while ShellStates.bottomBarVisible.
 *
 * A window too narrow for every control hides the ones that do not fit (ControlRepeater). They
 * are then the entries of the menu of the "More" button at the right end of the bar, which shows
 * only while a control is hidden (see ControlOverflow).
 */
T.Pane {
    id: root

    // Properties

    property int identifier: Player.hasVideoOutput ? PlayerControlbarModel.Videoplayer
                                                   : PlayerControlbarModel.Audioplayer

    // the files of the controls the layout hides (see _scan)
    property var hiddenSources: []

    // Signals

    signal requestLockUnlockAutoHide(bool lock)

    ///incoming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
    implicitHeight: RedesignStyle.controlBarHeight

    topPadding: 0
    bottomPadding: 0
    leftPadding: RedesignStyle.spacingL
    // the room of the "More" button (it is not part of the layout, which would hide it too)
    rightPadding: RedesignStyle.spacingL + (moreButton.visible ? moreButton.width + RedesignStyle.spacingM : 0)

    Accessible.name: qsTr("Player controls")
    AccessibleCompat.id: "playerControlBar"

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => root.Navigation.defaultKeyAction(event)

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.Window
    }

    // Children

    background: Rectangle {
        color: theme.bg.primary
    }

    contentItem: PlayerControlLayout {
        identifier: root.identifier

        spacing: RedesignStyle.spacingM
        layoutSpacing: RedesignStyle.spacingM

        onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)

        Component.onCompleted: root.forceUnlock.connect(forceUnlock)
    }

    // The controls are replaced when the profile or the kind of media changes (a video starts), and
    // the upstream layout takes the keyboard into the bar then; it goes back to where it was. A
    // pointer press on the bar (a click on a control, on a button that opens a popup), Tab (the
    // window calls endFocusGuard()) and the resume prompt are moves on purpose, they end the
    // guard. What is pressed outside of the bar is not seen: a popup (its own item of the shell,
    // or the menus, which live in the overlay layer) and the pages are outside, and the focus
    // that moves there is simply remembered. The value of `trigger` is also set while the bar is
    // created: that first guard is wanted, the first layout takes the focus the same way.
    FocusKeeper {
        id: focusKeeper

        scope: root
        exclude: resumePrompt
        trigger: root.contentItem.model
    }

    // the bar is a Pane: an item of its own is needed above the controls to see the presses they take
    // (a PointHandler observes: the press and the hover go on to the controls)
    Item {
        parent: root
        anchors.fill: parent
        z: 100

        PointHandler {
            acceptedButtons: Qt.AllButtons

            onActiveChanged: {
                if (active)
                    focusKeeper.end()
            }
        }
    }

    // the keyboard moves into or out of the bar on purpose (Tab, Shift+Tab)
    function endFocusGuard() {
        focusKeeper.end()
    }

    // just above the Play button (a child of the pane would land in the layout)
    ResumePrompt {
        id: resumePrompt

        parent: root
        z: 1
    }

    // Finds the controls the layout hides: its Loaders that hold a control (they have a source; the
    // ones of the layout itself have a component) and that are not visible. It is done once the
    // layout has settled (its visibility bindings are delayed), and again when the bar, the profile
    // or the room of the controls changes.
    function _scan() {
        if (!root.visible || !root.contentItem)
            return

        const hidden = []
        const walk = (item) => {
            for (const child of item.children) {
                if (child.sourceComponent !== undefined && String(child.source) !== "") {
                    if (!child.visible)
                        hidden.push(String(child.source))
                } else if (child.sourceComponent !== undefined) {
                    if (child.item)
                        walk(child.item)
                } else {
                    walk(child)
                }
            }
        }
        walk(root.contentItem)

        // the same entries: the menu is not rebuilt
        if (JSON.stringify(ControlOverflow.kinds(hidden)) !== JSON.stringify(ControlOverflow.kinds(root.hiddenSources)))
            root.hiddenSources = hidden
    }

    function _openMoreMenu() {
        // see RedesignMenu.anchorTop: set before popup(). The menu opens above the button, it may
        // use the height of the window.
        moreMenu.anchorTop = 0
        moreMenu.popup(moreButton, moreButton.width - moreMenu.implicitWidth, -moreMenu.height - RedesignStyle.spacingXS)
    }

    function _kindText(kind: string): string {
        switch (kind) {
        case "mute": return Player.muted ? qsTr("Unmute") : qsTr("Mute")
        case "subtitles": return qsTr("Subtitles")
        case "audio": return qsTr("Audio")
        case "settings": return qsTr("Settings")
        case "queue": return qsTr("Queue")
        case "fullscreen": return Player.fullscreen ? qsTr("Exit fullscreen") : qsTr("Fullscreen")
        }
        return ""
    }

    function _kindAction(kind: string) {
        switch (kind) {
        case "mute": Player.muted = !Player.muted; break
        // the track popup opens above the button: the button of the bar
        case "subtitles": ShellActions.trackPopupRequested("subtitles", moreButton); break
        case "audio": ShellActions.trackPopupRequested("audio", moreButton); break
        case "settings": ShellActions.sidebarRequested(); break
        case "queue": ShellActions.queueRequested(); break
        case "fullscreen": Player.fullscreen = !Player.fullscreen; break
        }
    }

    Timer {
        id: scanTimer

        interval: 100

        onTriggered: root._scan()
    }

    Connections {
        target: root

        function onWidthChanged() { scanTimer.restart() }
        function onVisibleChanged() { scanTimer.restart() }
    }

    Connections {
        target: root.contentItem

        function onWidthChanged() { scanTimer.restart() }
        function onModelChanged() { scanTimer.restart() }
    }

    // The menu of the hidden controls, one entry for each (ControlOverflow.kinds). As in MainMenu,
    // the entries of an Instantiator are put into the menu by hand.
    RedesignMenu {
        id: moreMenu

        parent: moreButton

        accessibleName: qsTr("More controls")
    }

    Instantiator {
        model: ControlOverflow.kinds(root.hiddenSources)

        delegate: RedesignMenuItem {
            required property string modelData

            text: root._kindText(modelData)

            // the fullscreen of the player needs a video
            enabled: modelData !== "fullscreen" || Player.hasVideoOutput

            onTriggered: root._kindAction(modelData)
        }

        onObjectAdded: (index, object) => moreMenu.insertItem(index, object)
        onObjectRemoved: (index, object) => moreMenu.removeItem(object)
    }

    Widgets.IconToolButton {
        id: moreButton

        parent: root

        anchors.right: parent.right
        anchors.rightMargin: RedesignStyle.spacingL
        anchors.verticalCenter: parent.verticalCenter

        visible: ControlOverflow.kinds(root.hiddenSources).length > 0
        activeFocusOnTab: true

        text: VLCIcons.ellipsis
        description: qsTr("More")

        onClicked: root._openMoreMenu()

        AccessibleCompat.id: "moreControlsButton"
    }
}
