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
    name: "ForwardStack"

    Component {
        id: stackComponent

        ForwardStack {}
    }

    function test_backThenForward() {
        const stack = createTemporaryObject(stackComponent, this)
        verify(stack.empty)
        compare(stack.take(), null)

        stack.noteBack(["video", "all", "group"], {title: "Holidays"})
        stack.noteNavigation() // the History.previous() of the header
        stack.noteBack(["video", "all"], {})
        stack.noteNavigation()
        verify(!stack.empty)

        compare(stack.take(), {path: ["video", "all"], props: {}})
        stack.noteNavigation() // the push of the header
        compare(stack.take(), {path: ["video", "all", "group"], props: {title: "Holidays"}})
        stack.noteNavigation()
        verify(stack.empty)
    }

    function test_otherNavigationClears() {
        const stack = createTemporaryObject(stackComponent, this)
        stack.noteBack(["music"], {})
        stack.noteNavigation()
        stack.noteNavigation() // the user opened another page: a new branch
        verify(stack.empty)
        compare(stack.take(), null)
    }

    function test_navigationBeforeTheExpectedOneIsCounted() {
        const stack = createTemporaryObject(stackComponent, this)
        stack.noteBack(["a"], {})
        stack.noteBack(["b"], {})
        // two expected navigations: neither clears
        stack.noteNavigation()
        stack.noteNavigation()
        verify(!stack.empty)
        stack.noteNavigation()
        verify(stack.empty)
    }
}
