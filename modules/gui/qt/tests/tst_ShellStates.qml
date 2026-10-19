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
    name: "ShellStates"

    Component {
        id: shellComponent
        ShellStates {}
    }

    function createShell(props) {
        const shell = createTemporaryObject(shellComponent, testCase, props || {})
        verify(shell !== null)
        return shell
    }

    function test_defaults() {
        const shell = createShell()
        compare(shell.state, "browse")
        compare(shell.panelMode, "hidden") // no panel requested
        compare(shell.miniPlayerShowsVideo, false)
        compare(shell.topBarVisible, true)
        compare(shell.bottomBarVisible, true)
    }

    function test_states_data() {
        return [
            // playerView, fullscreen, minimalView, canShowVideoPIP, panelRequested -> state, panelMode, miniPlayerShowsVideo
            { tag: "browse, pip",        playerView: false, fullscreen: false, minimalView: false, canShowVideoPIP: true,  panelRequested: true,  state: "browse",    panelMode: "docked",  miniPlayerShowsVideo: true  },
            { tag: "browse, no pip",     playerView: false, fullscreen: false, minimalView: false, canShowVideoPIP: false, panelRequested: true,  state: "browse",    panelMode: "docked",  miniPlayerShowsVideo: false },
            { tag: "watch, pip",         playerView: true,  fullscreen: false, minimalView: false, canShowVideoPIP: true,  panelRequested: true,  state: "watch",     panelMode: "docked",  miniPlayerShowsVideo: false },
            { tag: "watch, no pip",      playerView: true,  fullscreen: false, minimalView: false, canShowVideoPIP: false, panelRequested: true,  state: "watch",     panelMode: "overlay", miniPlayerShowsVideo: false },
            { tag: "watch, no panel",    playerView: true,  fullscreen: false, minimalView: false, canShowVideoPIP: true,  panelRequested: false, state: "watch",     panelMode: "hidden",  miniPlayerShowsVideo: false },
            { tag: "fullscreen",         playerView: true,  fullscreen: true,  minimalView: false, canShowVideoPIP: true,  panelRequested: true,  state: "immersive", panelMode: "hidden",  miniPlayerShowsVideo: false },
            { tag: "minimal view",       playerView: false, fullscreen: false, minimalView: true,  canShowVideoPIP: true,  panelRequested: true,  state: "immersive", panelMode: "hidden",  miniPlayerShowsVideo: false },
        ]
    }

    // the inputs are set after creation, so the state machine has to follow input changes
    function test_states(data) {
        const shell = createShell()
        shell.canShowVideoPIP = data.canShowVideoPIP
        shell.panelRequested = data.panelRequested
        shell.minimalView = data.minimalView
        shell.fullscreen = data.fullscreen
        shell.playerView = data.playerView
        compare(shell.state, data.state)
        compare(shell.panelMode, data.panelMode)
        compare(shell.miniPlayerShowsVideo, data.miniPlayerShowsVideo)
    }

    function test_initialInputs_data() { return test_states_data() }

    // the inputs are already set when the component completes
    function test_initialInputs(data) {
        const shell = createShell({
            playerView: data.playerView,
            fullscreen: data.fullscreen,
            minimalView: data.minimalView,
            canShowVideoPIP: data.canShowVideoPIP,
            panelRequested: data.panelRequested,
        })
        compare(shell.state, data.state)
        compare(shell.panelMode, data.panelMode)
        compare(shell.miniPlayerShowsVideo, data.miniPlayerShowsVideo)
    }

    function test_fullscreenRoundTrip_data() {
        return [
            { tag: "docked",  canShowVideoPIP: true,  panelRequested: true,  panelMode: "docked" },
            { tag: "overlay", canShowVideoPIP: false, panelRequested: true,  panelMode: "overlay" },
            { tag: "hidden",  canShowVideoPIP: true,  panelRequested: false, panelMode: "hidden" },
        ]
    }

    function test_fullscreenRoundTrip(data) {
        const shell = createShell({
            playerView: true,
            canShowVideoPIP: data.canShowVideoPIP,
            panelRequested: data.panelRequested,
        })
        compare(shell.state, "watch")
        compare(shell.panelMode, data.panelMode)

        shell.fullscreen = true
        compare(shell.state, "immersive")
        compare(shell.panelMode, "hidden")

        shell.fullscreen = false
        compare(shell.state, "watch")
        compare(shell.panelMode, data.panelMode)
    }

    function test_minimalViewWhileFullscreen() {
        const shell = createShell({ playerView: true, fullscreen: true, minimalView: true })
        compare(shell.state, "immersive")
        shell.fullscreen = false
        compare(shell.state, "immersive") // still minimal
        shell.minimalView = false
        compare(shell.state, "watch")
        shell.playerView = false
        compare(shell.state, "browse")
    }

    // fullscreen with nothing playing is no empty immersive view: the library stays
    function test_fullscreenWithoutMedia() {
        const shell = createShell({ fullscreen: true, hasMedia: false, panelRequested: true })
        compare(shell.state, "browse")
        compare(shell.panelMode, "docked")
        shell.hasMedia = true
        compare(shell.state, "immersive")
        compare(shell.panelMode, "hidden")
        // playback ends while fullscreen
        shell.hasMedia = false
        compare(shell.state, "browse")
        shell.hasMedia = true
        compare(shell.state, "immersive")
    }

    // the minimal view is not about the media: it stays immersive without any
    function test_minimalViewWithoutMedia() {
        const shell = createShell({ minimalView: true, hasMedia: false })
        compare(shell.state, "immersive")
    }

    function test_hasMediaDefault() {
        compare(createShell().hasMedia, true)
    }

    function test_panelFollowsInputsInState() {
        const shell = createShell({ playerView: true, canShowVideoPIP: true, panelRequested: true })
        compare(shell.panelMode, "docked")
        shell.canShowVideoPIP = false
        compare(shell.panelMode, "overlay")
        shell.panelRequested = false
        compare(shell.panelMode, "hidden")
        shell.panelRequested = true
        shell.playerView = false
        compare(shell.state, "browse")
        compare(shell.panelMode, "docked")
    }

    function test_bars_data() {
        return [
            // state, uiHidden, pointerNearTop, pointerNearBottom, recentKeyActivity -> topBarVisible, bottomBarVisible
            { tag: "browse ignores uiHidden", state: "browse",    uiHidden: true,  nearTop: false, nearBottom: false, key: false, top: true,  bottom: true  },
            { tag: "watch shown",             state: "watch",     uiHidden: false, nearTop: false, nearBottom: false, key: false, top: true,  bottom: true  },
            { tag: "watch hidden",            state: "watch",     uiHidden: true,  nearTop: false, nearBottom: false, key: false, top: false, bottom: false },
            { tag: "immersive idle",          state: "immersive", uiHidden: false, nearTop: false, nearBottom: false, key: false, top: false, bottom: false },
            { tag: "immersive near top",      state: "immersive", uiHidden: false, nearTop: true,  nearBottom: false, key: false, top: true,  bottom: false },
            { tag: "immersive near bottom",   state: "immersive", uiHidden: false, nearTop: false, nearBottom: true,  key: false, top: false, bottom: true  },
            { tag: "immersive key activity",  state: "immersive", uiHidden: false, nearTop: false, nearBottom: false, key: true,  top: true,  bottom: true  },
            { tag: "immersive uiHidden wins", state: "immersive", uiHidden: true,  nearTop: true,  nearBottom: true,  key: true,  top: false, bottom: false },
        ]
    }

    function test_bars(data) {
        const shell = createShell()
        shell.playerView = data.state !== "browse"
        shell.fullscreen = data.state === "immersive"
        compare(shell.state, data.state)
        shell.uiHidden = data.uiHidden
        shell.pointerNearTop = data.nearTop
        shell.pointerNearBottom = data.nearBottom
        shell.recentKeyActivity = data.key
        compare(shell.topBarVisible, data.top)
        compare(shell.bottomBarVisible, data.bottom)
    }
}
