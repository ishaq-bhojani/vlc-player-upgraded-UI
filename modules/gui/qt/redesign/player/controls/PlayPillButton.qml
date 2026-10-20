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
import VLC.Playlist
import VLC.Util
import VLC.Redesign

/**
 * @brief The Play button of the redesign: a pill, as in the owner's Figma export
 * (docs/redesign/figma-svg/play.svg: 54 x 28, radius 6).
 *
 * The glyph is the action the button performs: Play on the accent fill while the media is
 * paused or stopped, Pause on the muted grey fill of the Figma export while it plays. Press and
 * hold stops, like the stock button. Registered for PLAY_BUTTON in redesign mode only
 * (PlayerControlbarControls.qml).
 */
T.Control {
    id: root

    // Properties

    property bool paintOnly: false

    readonly property bool _playing: !paintOnly
                                     && Player.playingState !== Player.PLAYING_STATE_PAUSED
                                     && Player.playingState !== Player.PLAYING_STATE_STOPPED

    property bool _keyOkPressed: false

    // Aliases

    readonly property bool _hovered: mouseArea.containsMouse

    // Colours: the accent fill follows qt-accent-color, the Pause variant is neutral

    readonly property ColorContext colorContext: ColorContext {
        id: neutralTheme

        colorSet: ColorContext.ButtonStandard

        enabled: root.enabled || root.paintOnly
        focused: root.activeFocus
        hovered: root._hovered
        pressed: mouseArea.containsPress
    }

    readonly property ColorContext accentContext: ColorContext {
        id: accentTheme

        colorSet: ColorContext.ButtonAccent

        enabled: root.enabled || root.paintOnly
        pressed: mouseArea.containsPress
    }

    // Settings

    // Figma: 54 x 28
    implicitWidth: VLCStyle.dp(54, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(28, VLCStyle.scale)

    scale: (_keyOkPressed || mouseArea.pressed) ? 0.95 : 1.00

    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Play/Pause")
    AccessibleCompat.id: "playButton"
    Accessible.checkable: true
    Accessible.checked: root._playing
    Accessible.onPressAction: MainPlaylistController.togglePlayPause()
    Accessible.onToggleAction: MainPlaylistController.togglePlayPause()

    T.ToolTip.visible: (_hovered || visualFocus)
    T.ToolTip.delay: VLCStyle.delayToolTipAppear
    T.ToolTip.text: root.Accessible.name

    // Events

    // the resume prompt is placed above this button
    Component.onCompleted: {
        if (!paintOnly)
            ShellActions.playButton = root
    }

    Component.onDestruction: {
        if (ShellActions.playButton === root)
            ShellActions.playButton = null
    }

    Keys.onPressed: (event) => {
        if (KeyHelper.matchOk(event)) {
            if (!event.isAutoRepeat) {
                _keyOkPressed = true
                keyHoldTimer.restart()
            }
            event.accepted = true
        }
        Navigation.defaultKeyAction(event)
    }

    // The release toggles only when this button took the press (PlayKeyLogic): a press taken
    // elsewhere (the window forwards Space as the play/pause hotkey) has toggled already, and its
    // release must not toggle back when the focus moved here in between.
    Keys.onReleased: (event) => {
        if (KeyHelper.matchOk(event)) {
            if (!event.isAutoRepeat) {
                const pressTaken = _keyOkPressed
                _keyOkPressed = false
                keyHoldTimer.stop()
                if (PlayKeyLogic.releaseToggles(pressTaken, Player.playingState === Player.PLAYING_STATE_STOPPED))
                    MainPlaylistController.togglePlayPause()
            }
            event.accepted = true
        }
    }

    // a press that goes on while the focus leaves (the bar hides) has no release here: it is
    // forgotten, or the hold timer would stop the playback
    onActiveFocusChanged: {
        if (!activeFocus) {
            _keyOkPressed = false
            keyHoldTimer.stop()
        }
    }

    // Children

    Timer {
        id: keyHoldTimer

        interval: mouseArea.pressAndHoldInterval

        onTriggered: {
            root._keyOkPressed = false
            MainPlaylistController.stop()
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent

        hoverEnabled: true
        enabled: !root.paintOnly

        onPressed: root.forceActiveFocus(Qt.MouseFocusReason)

        onClicked: (mouse) => {
            MainPlaylistController.togglePlayPause()
            mouse.accepted = true
        }

        onPressAndHold: (mouse) => {
            MainPlaylistController.stop()
            mouse.accepted = true
        }
    }

    background: Rectangle {
        radius: RedesignStyle.radiusM

        // Figma (play.svg): Pause is the muted text colour (#6B6B6B), not the sunken black that
        // ButtonStandard Bg Secondary is
        color: root._playing ? neutralTheme.fg.secondary : accentTheme.bg.primary

        border.width: root.visualFocus ? VLCStyle.dp(2, VLCStyle.scale) : 0
        border.color: neutralTheme.visualFocus

        Behavior on color {
            ColorAnimation {
                duration: VLCStyle.duration_veryShort
                easing.type: Easing.InOutSine
            }
        }
    }

    contentItem: T.Label {
        text: root._playing ? VLCIcons.pause_filled : VLCIcons.play_filled

        // the dark glyph of the Figma Pause variant (Bg Secondary: #090909, white in the light theme)
        color: root._playing ? neutralTheme.bg.secondary : accentTheme.fg.primary

        font.pixelSize: Math.round(root.height * 0.55)
        font.family: VLCIcons.fontFamily

        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter

        Accessible.ignored: true
    }
}
