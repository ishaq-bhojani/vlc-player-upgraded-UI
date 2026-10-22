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
import QtTest
import VLC.Redesign

TestCase {
    id: testCase

    name: "FocusKeeper"

    width: 200
    height: 100
    visible: true
    when: windowShown

    // The shell puts the keyboard on the stage; the bar is rebuilt, and an item of the new content
    // takes it (what ControlRepeater.recoverFocus() does).
    Item {
        id: window

        anchors.fill: parent

        FocusScope {
            id: stage

            width: 10
            height: 10
        }

        Item {
            id: other

            width: 10
            height: 10

            focus: false
        }

        FocusScope {
            id: bar

            width: 50
            height: 20

            property int rebuilds: 0
            property Item first: null

            // a control that takes the focus when it is pressed (the Play button does)
            MouseArea {
                id: pressed

                x: 30
                width: 10
                height: 10

                onPressed: pressTarget.forceActiveFocus(Qt.MouseFocusReason)

                Item {
                    id: pressTarget

                    width: 5
                    height: 5
                }
            }

            // the resume prompt: takes the focus by itself
            FocusScope {
                id: prompt

                x: 40
                width: 10
                height: 10

                Item {
                    id: promptButton

                    width: 5
                    height: 5
                    focus: true
                }
            }

            // the same observer as in RedesignControlBar.qml
            Item {
                anchors.fill: parent
                z: 100

                PointHandler {
                    acceptedButtons: Qt.AllButtons

                    onActiveChanged: {
                        if (active)
                            keeper.end()
                    }
                }
            }

            // the content is replaced by a new one, whose first control takes the focus
            function rebuild() {
                if (first)
                    first.destroy()
                first = control.createObject(bar)
                first.forceActiveFocus()
                rebuilds++
            }

            Component {
                id: control

                Item {
                    width: 10
                    height: 10

                    focus: true
                }
            }
        }
    }

    FocusKeeper {
        id: keeper

        scope: bar
        exclude: prompt
        quietInterval: 20
        guardInterval: 300
    }

    function init() {
        if (bar.first) {
            bar.first.destroy()
            bar.first = null
        }
        stage.forceActiveFocus()
        compare(testCase.Window.window.activeFocusItem, stage)
        wait(keeper.guardInterval + 50) // a guard of an earlier test is over
    }

    // the bug: the rebuilt bar keeps the keyboard it took
    function test_withoutBeginTheBarKeepsTheFocus() {
        bar.rebuild()
        wait(100)
        verify(testCase.Window.window.activeFocusItem === bar.first)
    }

    // the focus goes back to the stage after a rebuild
    function test_rebuildGivesTheFocusBack() {
        keeper.begin()
        bar.rebuild()
        compare(testCase.Window.window.activeFocusItem, bar.first)
        tryCompare(testCase.Window.window, "activeFocusItem", stage, 500)
    }

    // the focus the shell moves meanwhile is the one that is restored
    function test_followsTheFocusOutside() {
        keeper.begin()
        other.forceActiveFocus()
        bar.rebuild()
        tryCompare(testCase.Window.window, "activeFocusItem", other, 500)
    }

    // the user is on the bar: a rebuild does not take the focus away from it
    function test_focusInsideTheBarIsKept() {
        bar.rebuild()
        wait(50)
        verify(testCase.Window.window.activeFocusItem === bar.first)
        keeper.begin()
        bar.rebuild()
        wait(150)
        verify(testCase.Window.window.activeFocusItem === bar.first)
    }

    // after the guard the focus moves freely (Tab, a click on a control)
    function test_afterTheGuardTheBarCanTakeTheFocus() {
        keeper.begin()
        wait(keeper.guardInterval + 50)
        bar.rebuild()
        wait(100)
        verify(testCase.Window.window.activeFocusItem === bar.first)
    }

    // a second change while the first is being taken back: the first one's item is kept
    function test_secondBeginKeepsTheRememberedItem() {
        keeper.begin()
        bar.rebuild()
        keeper.begin()
        bar.rebuild()
        tryCompare(testCase.Window.window, "activeFocusItem", stage, 500)
    }

    // a click on a control of the bar inside the guard is a move on purpose
    function test_clickInTheBarEndsTheGuard() {
        keeper.begin()
        mouseClick(bar, 35, 5)
        compare(testCase.Window.window.activeFocusItem, pressTarget)
        wait(150)
        compare(testCase.Window.window.activeFocusItem, pressTarget)
    }

    // Tab (the window calls end()) and the focus it moves into the bar
    function test_endKeepsAFocusInTheBar() {
        keeper.begin()
        keeper.end()
        bar.rebuild()
        wait(150)
        verify(testCase.Window.window.activeFocusItem === bar.first)
    }

    // the resume prompt takes the focus inside the guard and keeps it, even when the layout is
    // rebuilt behind it
    function test_promptFocusSurvives() {
        keeper.begin()
        promptButton.forceActiveFocus()
        wait(150)
        compare(testCase.Window.window.activeFocusItem, promptButton)
        bar.rebuild()
        // the steal after the prompt goes back to the prompt, not to the stage
        tryCompare(testCase.Window.window, "activeFocusItem", promptButton, 500)
    }

    // the remembered item is gone: nothing is restored, the focus stays where it is
    function test_destroyedRememberedItem() {
        const temp = tempComponent.createObject(window)
        temp.forceActiveFocus()
        compare(testCase.Window.window.activeFocusItem, temp)
        keeper.begin()
        bar.rebuild()
        temp.destroy()
        wait(150)
        verify(testCase.Window.window.activeFocusItem === bar.first)
    }

    // a change of `trigger` begins a guard (RedesignControlBar binds it to the layout model)
    function test_triggerBegins() {
        keeper.trigger = bar.rebuilds + 1000
        bar.rebuild()
        tryCompare(testCase.Window.window, "activeFocusItem", stage, 500)
    }

    Component {
        id: tempComponent

        Item {
            width: 5
            height: 5
        }
    }
}
