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

// The Escape behaviour of NumberControl, TextControl and PathControl, which is EscapeRevert plus
// three lines of Keys handlers. The controls themselves can not be created here (they are
// TextFields of VLC.Widgets with a ColorContext, and the qt plugin registers that type at run
// time, as it does MainCtx), so the field below has the very wiring of the controls, under a parent
// that counts the Escape presses and releases that nobody took: the ones that would reach the
// popup of the Settings modal and close it.
TestCase {
    id: testCase

    name: "EscapeRevert"

    when: windowShown

    width: 200
    height: 100

    // the stored value of the setting
    property string stored: "10"

    // a field like the controls: it shows `stored` until something is typed
    Component {
        id: holderComponent

        Item {
            id: holder

            property int presses: 0
            property int releases: 0

            readonly property alias field: field

            width: 200
            height: 40

            // what a field does not take goes to its parent
            Keys.onEscapePressed: holder.presses++
            Keys.onReleased: (event) => {
                if (event.key === Qt.Key_Escape)
                    holder.releases++
            }

            TextInput {
                id: field

                readonly property bool pendingEdit: field.text !== testCase.stored

                readonly property EscapeRevert reverter: EscapeRevert {
                    pending: field.pendingEdit

                    onRevert: field.showValue()
                }

                function showValue() {
                    field.text = Qt.binding(() => testCase.stored)
                }

                anchors.fill: parent

                focus: true
                text: testCase.stored

                Keys.onEscapePressed: (event) => field.reverter.press(event)

                Keys.onReleased: (event) => field.reverter.release(event)

                onActiveFocusChanged: {
                    if (!activeFocus)
                        field.reverter.reset()
                }
            }
        }
    }

    // the field of PathControl sits in a FocusScope
    Component {
        id: nestedComponent

        Item {
            id: outer

            readonly property Item inner: loader.item

            width: 200
            height: 40

            FocusScope {
                anchors.fill: parent

                focus: true

                Loader {
                    id: loader

                    anchors.fill: parent

                    focus: true
                    sourceComponent: holderComponent
                }
            }
        }
    }

    Component {
        id: reverterComponent

        EscapeRevert {}
    }

    function init() {
        stored = "10"
    }

    function holder() {
        const h = createTemporaryObject(holderComponent, testCase)
        verify(h)
        h.field.forceActiveFocus()
        verify(h.field.activeFocus)
        return h
    }

    function type(h, text) {
        for (const c of text)
            keyClick(c)
        verify(h.field.pendingEdit)
    }

    function test_firstEscapeRevertsAndIsTaken() {
        const h = holder()
        type(h, "42")
        compare(h.field.text, "1042")

        keyClick(Qt.Key_Escape)

        // the typed text is gone, and neither the press nor the release got out
        compare(h.field.text, "10")
        compare(h.field.pendingEdit, false)
        compare(h.presses, 0)
        compare(h.releases, 0)
    }

    function test_secondEscapeReachesTheParent() {
        const h = holder()
        type(h, "7")

        keyClick(Qt.Key_Escape)
        compare(h.presses, 0)
        compare(h.releases, 0)

        // nothing pending now: Escape is left to whoever is above, press and release
        keyClick(Qt.Key_Escape)
        compare(h.presses, 1)
        compare(h.releases, 1)
        compare(h.field.text, "10")
    }

    function test_escapeWithNothingTypedReachesTheParent() {
        const h = holder()

        keyClick(Qt.Key_Escape)

        compare(h.presses, 1)
        compare(h.releases, 1)
    }

    // the field follows the stored value again after a revert
    function test_revertRestoresTheBinding() {
        const h = holder()
        type(h, "1")
        keyClick(Qt.Key_Escape)

        stored = "20"
        compare(h.field.text, "20")
    }

    // The press took the edit back, the release comes after the focus left: it must not be taken
    // for the one of a later Escape.
    function test_focusLossForgetsATakenPress() {
        const h = holder()
        type(h, "9")

        keyPress(Qt.Key_Escape)
        verify(h.field.reverter.taken)
        compare(h.presses, 0)

        h.field.focus = false
        h.forceActiveFocus()
        verify(!h.field.activeFocus)
        verify(!h.field.reverter.taken)

        // the release now goes up
        keyRelease(Qt.Key_Escape)
        compare(h.releases, 1)
    }

    function test_otherKeysAreNotTaken() {
        const h = holder()
        type(h, "3")

        keyClick(Qt.Key_Escape)
        verify(!h.field.reverter.taken)

        // a release of another key while an Escape was taken is not accepted by EscapeRevert
        type(h, "4")
        keyPress(Qt.Key_Escape)
        verify(h.field.reverter.taken)
        keyRelease(Qt.Key_A)
        verify(h.field.reverter.taken)
        keyRelease(Qt.Key_Escape)
        verify(!h.field.reverter.taken)
        compare(h.releases, 0)
    }

    // a repeat of the key (held down) is not the release that ends a taken press
    function test_autoRepeatReleaseIsNotTaken() {
        const reverter = createTemporaryObject(reverterComponent, testCase)
        verify(reverter)
        reverter.taken = true

        const repeat = { key: Qt.Key_Escape, isAutoRepeat: true, accepted: false }
        reverter.release(repeat)
        compare(repeat.accepted, false)
        verify(reverter.taken)

        const real = { key: Qt.Key_Escape, isAutoRepeat: false, accepted: false }
        reverter.release(real)
        compare(real.accepted, true)
        verify(!reverter.taken)
    }

    // inside a FocusScope, as the field of PathControl
    function test_inAFocusScope() {
        const outer = createTemporaryObject(nestedComponent, testCase)
        verify(outer)
        const h = outer.inner
        verify(h)
        h.field.forceActiveFocus()
        verify(h.field.activeFocus)

        type(h, "5")
        keyClick(Qt.Key_Escape)
        compare(h.presses, 0)
        compare(h.releases, 0)
        compare(h.field.text, "10")

        keyClick(Qt.Key_Escape)
        compare(h.presses, 1)
        compare(h.releases, 1)
    }
}
