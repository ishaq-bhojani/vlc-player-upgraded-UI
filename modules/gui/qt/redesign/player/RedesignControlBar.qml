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

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.PlayerControls
import VLC.Util
import VLC.Redesign

/**
 * @brief The control bar of the redesign (spec 11.1): one thin row over the bottom of the
 * video, laid out by the profile selected in Customize Player ("Vireo" by default:
 * previous, play, next, seek bar | volume, subtitles, audio, settings, queue, fullscreen).
 *
 * It hosts the upstream PlayerControlLayout, so the profile model, the Customize Player editor
 * and the item registry (PlayerControlbarControls) are the stock ones. The root window shows
 * it while ShellStates.bottomBarVisible.
 */
T.Pane {
    id: root

    // Properties

    property int identifier: Player.hasVideoOutput ? PlayerControlbarModel.Videoplayer
                                                   : PlayerControlbarModel.Audioplayer

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
    rightPadding: RedesignStyle.spacingL

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
}
