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
import QtQml

import VLC.Util

/**
 * @brief Shell state machine of the redesign: which of the three shell states
 * (browse / watch / immersive) is active and what the shell chrome shows in it.
 *
 * Bind the inputs to the application state; the root window, the panels and the
 * control bar bind to the outputs. The state itself is held by an FSM, the other
 * outputs are derived from the state and the inputs.
 *
 *   state:     "immersive" if fullscreen || minimalView, else "watch" if playerView,
 *              else "browse"
 *   panelMode: "hidden" in immersive or when no panel is requested; in watch "docked"
 *              if canShowVideoPIP, else "overlay"; in browse "docked"
 *   bars:      browse shows both (uiHidden is ignored), watch shows both unless
 *              uiHidden, immersive shows a bar only while the pointer is near it or
 *              a key was recently pressed (and never when uiHidden)
 */
QtObject {
    id: root

    // inputs
    property bool playerView: false
    property bool fullscreen: false
    property bool minimalView: false
    property bool canShowVideoPIP: false
    property bool panelRequested: false
    property bool uiHidden: false
    property bool pointerNearTop: false
    property bool pointerNearBottom: false
    property bool recentKeyActivity: false

    // outputs
    readonly property string state: _state
    readonly property string panelMode: {
        if (!panelRequested || _state === "immersive")
            return "hidden"
        if (_state === "watch")
            return canShowVideoPIP ? "docked" : "overlay"
        return "docked"
    }
    readonly property bool miniPlayerShowsVideo: _state === "browse" && canShowVideoPIP
    readonly property bool topBarVisible: {
        if (_state === "browse")
            return true
        if (_state === "watch")
            return !uiHidden
        return !uiHidden && (pointerNearTop || recentKeyActivity)
    }
    readonly property bool bottomBarVisible: {
        if (_state === "browse")
            return true
        if (_state === "watch")
            return !uiHidden
        return !uiHidden && (pointerNearBottom || recentKeyActivity)
    }

    // the state the inputs ask for
    readonly property string _target: (fullscreen || minimalView) ? "immersive"
                                    : playerView ? "watch"
                                    : "browse"
    // the state of the machine, set by the enter handlers of the FSM states
    property string _state: "browse"

    // sent whenever an input that selects the state changed
    signal _inputsChanged()

    on_TargetChanged: _inputsChanged()

    property FSM _fsm: FSM {
        // the machine starts in the state the inputs ask for (they may be set before it exists)
        initialState: root._target === "immersive" ? immersiveState
                    : root._target === "watch" ? watchState
                    : browseState

        signalMap: ({
            "inputsChanged": root._inputsChanged
        })

        // every state follows _target, a state is only left when the target differs
        FSMState {
            id: browseState
            function enter() { root._state = "browse" }
            transitions: ({
                "inputsChanged": [
                    { guard: () => root._target === "watch", target: watchState },
                    { guard: () => root._target === "immersive", target: immersiveState },
                ]
            })
        }
        FSMState {
            id: watchState
            function enter() { root._state = "watch" }
            transitions: ({
                "inputsChanged": [
                    { guard: () => root._target === "browse", target: browseState },
                    { guard: () => root._target === "immersive", target: immersiveState },
                ]
            })
        }
        FSMState {
            id: immersiveState
            function enter() { root._state = "immersive" }
            transitions: ({
                "inputsChanged": [
                    { guard: () => root._target === "browse", target: browseState },
                    { guard: () => root._target === "watch", target: watchState },
                ]
            })
        }
    }
}
