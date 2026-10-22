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
import QtQml

/**
 * @brief The steps of the onboarding, a pure model (no UI), so that the order and the limits are
 * tested on their own (tst_OnboardingSteps).
 *
 * The steps are "theme", "shortcuts", "privacy", "folders" and "done". "folders" (the folders the
 * media library scans) is left out without a media library. `current` is the index in `steps`,
 * next() and back() stop at the ends. The last step is the one that finishes the onboarding.
 */
QtObject {
    id: root

    // Properties

    //! whether the interface has a media library (MainCtx.mediaLibraryAvailable)
    property bool hasMediaLibrary: true

    //! the ids of the steps, in order
    readonly property var steps: hasMediaLibrary
        ? ["theme", "shortcuts", "privacy", "folders", "done"]
        : ["theme", "shortcuts", "privacy", "done"]

    //! the index in `steps` of the step shown
    property int current: 0

    //! the id of the step shown
    readonly property string currentStep: steps[Math.max(0, Math.min(current, steps.length - 1))]

    //! the last step is shown: the onboarding can be finished
    readonly property bool canFinish: current === steps.length - 1

    //! The shortcuts of the card of the "shortcuts" step: the action (a key of ShortcutsModel,
    //! its keys are read live) and what it does. "Hide UI" has no hotkey of its own yet: the
    //! entry is the hotkey that shows or hides the controls.
    readonly property var essentials: [
        { action: "key-play-pause", label: qsTr("Play or pause") },
        { action: "key-jump-short", label: qsTr("Seek back 10 seconds") },
        { action: "key-jump+short", label: qsTr("Seek forward 10 seconds") },
        { action: "key-vol-up", label: qsTr("Volume up") },
        { action: "key-vol-down", label: qsTr("Volume down") },
        { action: "key-toggle-fullscreen", label: qsTr("Full screen") },
        { action: "key-subtitle-track", label: qsTr("Next subtitle track") },
        { action: "key-intf-show", label: qsTr("Show or hide the controls (full screen)") },
        { action: "key-set-bookmark1", label: qsTr("Quick bookmark") }
    ]

    //! the themes of the cards of the "theme" step, in order (the kinds of SettingsBridge.colorSchemes)
    readonly property var themeKinds: ["system", "light", "dark"]

    // Functions

    //! The row of the color scheme model (`schemes`: SettingsBridge.colorSchemes, [{kind}]) that a
    //! card selects, -1 if the model has none of that kind.
    function schemeIndexFor(schemes, kind) {
        return schemes.findIndex(scheme => scheme.kind === kind)
    }

    //! The card ("system", "light" or "dark") of the scheme in use (`index`: the current row of the
    //! color scheme model), "system" for an index out of range.
    function kindFor(schemes, index) {
        const scheme = schemes[index]
        return scheme ? scheme.kind : "system"
    }

    function next() {
        current = Math.min(current + 1, steps.length - 1)
    }

    function back() {
        current = Math.max(current - 1, 0)
    }

    // Events

    // the media library appearing or going away shortens or lengthens `steps`: stay in range
    onStepsChanged: current = Math.max(0, Math.min(current, steps.length - 1))
}
