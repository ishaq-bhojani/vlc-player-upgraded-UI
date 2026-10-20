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
import QtTest
import VLC.Redesign

TestCase {
    id: testCase

    name: "PlayKeyLogic"

    width: 200
    height: 100
    visible: true
    when: windowShown

    // The two ways Space reaches the player, wired the way RedesignInterface.qml and
    // PlayPillButton.qml wire them: the window forwards the keys no item took as the hotkey, the
    // button toggles on the release of a press it took.
    Item {
        id: window

        anchors.fill: parent

        property int hotkeys: 0

        Keys.onPressed: (event) => {
            if (PlayKeyLogic.forwardsAsHotkey(event.key, event.isAutoRepeat))
                window.hotkeys++
            event.accepted = true
        }

        // an item that takes no key: the focus the stage and the control bar have
        Item {
            id: plain

            width: 10
            height: 10
        }

        Item {
            id: button

            width: 10
            height: 10

            property int toggles: 0
            property bool pressTaken: false
            property bool stopped: false

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Space) {
                    if (!event.isAutoRepeat)
                        button.pressTaken = true
                    event.accepted = true
                }
            }

            Keys.onReleased: (event) => {
                if (event.key === Qt.Key_Space) {
                    if (!event.isAutoRepeat) {
                        const taken = button.pressTaken
                        button.pressTaken = false
                        if (PlayKeyLogic.releaseToggles(taken, button.stopped))
                            button.toggles++
                    }
                    event.accepted = true
                }
            }
        }
    }

    function init() {
        window.hotkeys = 0
        button.toggles = 0
        button.pressTaken = false
        button.stopped = false
        plain.forceActiveFocus()
    }

    function test_forwardsAsHotkey() {
        verify(PlayKeyLogic.forwardsAsHotkey(Qt.Key_Space, false))
        // a held Space repeats: the repeats are not presses
        verify(!PlayKeyLogic.forwardsAsHotkey(Qt.Key_Space, true))
        // the other keys keep repeating (volume, seek)
        verify(PlayKeyLogic.forwardsAsHotkey(Qt.Key_Right, true))
        verify(PlayKeyLogic.forwardsAsHotkey(Qt.Key_Up, true))
        verify(PlayKeyLogic.forwardsAsHotkey(Qt.Key_Right, false))
    }

    function test_releaseToggles() {
        verify(PlayKeyLogic.releaseToggles(true, false))
        // a release of a press somewhere else
        verify(!PlayKeyLogic.releaseToggles(false, false))
        // a stopped player is not toggled
        verify(!PlayKeyLogic.releaseToggles(true, true))
        verify(!PlayKeyLogic.releaseToggles(false, true))
    }

    // one press of Space with the focus on an item that takes nothing: one hotkey
    function test_oneHotkeyPerPress() {
        keyPress(Qt.Key_Space)
        keyRelease(Qt.Key_Space)
        compare(window.hotkeys, 1)
        compare(button.toggles, 0)
    }

    // the Play button has the focus: it toggles once, on the release, and no hotkey is sent
    function test_oneToggleOnTheButton() {
        button.forceActiveFocus()
        keyPress(Qt.Key_Space)
        compare(button.toggles, 0)
        keyRelease(Qt.Key_Space)
        compare(button.toggles, 1)
        compare(window.hotkeys, 0)
    }

    // The case of the bug report: the press is forwarded as the hotkey (pause), the focus moves to
    // the button before the release (a control bar that is rebuilt, a popup that closes), and the
    // release must not toggle again (play).
    function test_releaseOfAForwardedPressDoesNotToggle() {
        keyPress(Qt.Key_Space)
        compare(window.hotkeys, 1)
        button.forceActiveFocus()
        keyRelease(Qt.Key_Space)
        compare(window.hotkeys, 1)
        compare(button.toggles, 0)
        // the next press on the button is its own
        keyClick(Qt.Key_Space)
        compare(button.toggles, 1)
    }

    function test_stoppedIsNotToggled() {
        button.stopped = true
        button.forceActiveFocus()
        keyClick(Qt.Key_Space)
        compare(button.toggles, 0)
    }
}
