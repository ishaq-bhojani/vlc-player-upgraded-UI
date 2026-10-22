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
    name: "OnboardingSteps"

    Component {
        id: stepsComponent

        OnboardingSteps { }
    }

    function test_stepsWithMediaLibrary() {
        const model = createTemporaryObject(stepsComponent, testCase, { hasMediaLibrary: true })
        compare(model.steps, ["theme", "shortcuts", "privacy", "folders", "done"])
    }

    function test_stepsWithoutMediaLibrary() {
        const model = createTemporaryObject(stepsComponent, testCase, { hasMediaLibrary: false })
        compare(model.steps, ["theme", "shortcuts", "privacy", "done"])
    }

    function test_startsOnTheFirstStep() {
        const model = createTemporaryObject(stepsComponent, testCase)
        compare(model.current, 0)
        compare(model.currentStep, "theme")
        compare(model.canFinish, false)
    }

    function test_nextWalksTheStepsAndStopsOnDone() {
        const model = createTemporaryObject(stepsComponent, testCase, { hasMediaLibrary: true })
        const seen = [model.currentStep]
        for (let i = 0; i < 10; ++i) {
            model.next()
            if (seen[seen.length - 1] !== model.currentStep)
                seen.push(model.currentStep)
        }
        compare(seen, ["theme", "shortcuts", "privacy", "folders", "done"])
        compare(model.currentStep, "done")
        compare(model.current, 4)
        model.next()
        compare(model.currentStep, "done")
    }

    function test_backAtZeroStays() {
        const model = createTemporaryObject(stepsComponent, testCase)
        model.back()
        compare(model.current, 0)
        model.next()
        model.back()
        compare(model.current, 0)
        model.back()
        compare(model.current, 0)
    }

    function test_canFinishOnlyOnTheLastStep() {
        for (const ml of [true, false]) {
            const model = createTemporaryObject(stepsComponent, testCase, { hasMediaLibrary: ml })
            for (let i = 0; i < model.steps.length - 1; ++i) {
                compare(model.canFinish, false, "step " + i)
                model.next()
            }
            compare(model.canFinish, true)
            compare(model.currentStep, "done")
            model.back()
            compare(model.canFinish, false)
        }
    }

    function test_withoutMediaLibraryHasNoFoldersStep() {
        const model = createTemporaryObject(stepsComponent, testCase, { hasMediaLibrary: false })
        model.next()
        model.next()
        compare(model.currentStep, "privacy")
        model.next()
        compare(model.currentStep, "done")
    }

    // the library goes away while the last step is shown: still on a step
    function test_current_staysInRange() {
        const model = createTemporaryObject(stepsComponent, testCase, { hasMediaLibrary: true })
        model.current = 4
        model.hasMediaLibrary = false
        compare(model.current, 3)
        compare(model.currentStep, "done")
    }

    function test_essentialsAreActionsWithALabel() {
        const model = createTemporaryObject(stepsComponent, testCase)
        verify(model.essentials.length >= 7)
        for (const entry of model.essentials) {
            verify(entry.action.startsWith("key-"), entry.action)
            verify(entry.label.length > 0, entry.action)
        }
    }
}
