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

/**
 * @brief Turns the raw "player is stopped" flag into a debounced "really stopped" one.
 *
 * VLC's player goes STOPPING, STOPPED, STARTED between two items of the playlist (the
 * notifications arrive asynchronously), so reacting to STOPPED at once makes the shell
 * flash the library while the playlist advances. Entering the stopped state starts a short
 * timer; `stopped` flips only if the state is still stopped when it fires. Leaving the
 * stopped state clears `stopped` at once (no delay when playback starts).
 *
 * The value found at creation is taken as is (app start with nothing playing shows the
 * library without waiting): only the transitions are debounced.
 */
QtObject {
    id: debounce

    // the raw flag, bound to `Player.playingState === Player.PLAYING_STATE_STOPPED`
    property bool input: false

    // how long the stop must last to be real, in ms
    property int interval: 300

    // the debounced flag
    readonly property bool stopped: _stopped

    // the stop lasted for `interval` (not emitted for the state found at creation)
    signal settledStopped()

    property bool _stopped: false
    property bool _ready: false

    readonly property Timer _timer: Timer {
        interval: debounce.interval
        repeat: false

        onTriggered: {
            if (debounce.input && !debounce._stopped) {
                debounce._stopped = true
                debounce.settledStopped()
            }
        }
    }

    onInputChanged: {
        if (!_ready)
            return

        if (input) {
            _timer.restart()
        } else {
            _timer.stop()
            _stopped = false
        }
    }

    Component.onCompleted: {
        _ready = true
        _stopped = input
    }
}
