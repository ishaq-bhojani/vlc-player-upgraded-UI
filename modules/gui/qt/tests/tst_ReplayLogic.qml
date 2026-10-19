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
    name: "ReplayLogic"

    function test_replayAction() {
        compare(ReplayLogic.replayAction(true, false), "seek")
        compare(ReplayLogic.replayAction(true, true), "seekResume")
        // PlaylistController::play() is a no-op on a started player, so a stopped or finished
        // player (not started) is the only case that uses it
        compare(ReplayLogic.replayAction(false, false), "start")
        compare(ReplayLogic.replayAction(false, true), "start")
    }
}
