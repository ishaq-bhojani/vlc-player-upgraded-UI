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
    name: "TrackPopupLogic"

    readonly property var all: ({ subtitles: true, audio: true, video: true })
    readonly property var noVideo: ({ subtitles: true, audio: true, video: false })
    readonly property var subsOnly: ({ subtitles: true, audio: false, video: false })

    function test_normalized() {
        for (const t of TrackPopupLogic.tabs)
            compare(TrackPopupLogic.normalized(t), t)
        compare(TrackPopupLogic.normalized(""), "subtitles")
        compare(TrackPopupLogic.normalized("Audio"), "subtitles")
    }

    function test_enabledTabs_data() {
        return [
            { tag: "all", a: 2, d: 1, v: 1, audio: true, video: true },
            { tag: "audio only media", a: 1, d: 2, v: 0, audio: true, video: false },
            { tag: "devices without tracks", a: 0, d: 1, v: 0, audio: true, video: false },
            { tag: "tracks without devices", a: 1, d: 0, v: 0, audio: true, video: false },
            { tag: "nothing", a: 0, d: 0, v: 0, audio: false, video: false },
        ]
    }

    function test_enabledTabs(data) {
        const e = TrackPopupLogic.enabledTabs(data.a, data.d, data.v)
        // subtitles stay usable: "Add subtitles..." is useful when there is no track
        compare(e.subtitles, true)
        compare(e.audio, data.audio)
        compare(e.video, data.video)
    }

    function test_resolveTab() {
        compare(TrackPopupLogic.resolveTab("audio", all), "audio")
        compare(TrackPopupLogic.resolveTab("video", noVideo), "subtitles")
        compare(TrackPopupLogic.resolveTab("video", ({ subtitles: false, audio: true, video: false })), "audio")
        compare(TrackPopupLogic.resolveTab("bogus", all), "subtitles")
        // nothing usable: the default tab
        compare(TrackPopupLogic.resolveTab("audio", ({ subtitles: false, audio: false, video: false })), "subtitles")
    }

    function test_stepTab() {
        compare(TrackPopupLogic.stepTab("subtitles", 1, all), "audio")
        compare(TrackPopupLogic.stepTab("audio", 1, all), "video")
        compare(TrackPopupLogic.stepTab("video", 1, all), "video")
        compare(TrackPopupLogic.stepTab("subtitles", -1, all), "subtitles")
        compare(TrackPopupLogic.stepTab("video", -1, all), "audio")
        // a disabled tab is skipped
        compare(TrackPopupLogic.stepTab("subtitles", 1, ({ subtitles: true, audio: false, video: true })), "video")
        compare(TrackPopupLogic.stepTab("video", -1, ({ subtitles: true, audio: false, video: true })), "subtitles")
        // nothing beyond: stays
        compare(TrackPopupLogic.stepTab("subtitles", 1, subsOnly), "subtitles")
        compare(TrackPopupLogic.stepTab("audio", 1, noVideo), "audio")
    }

    function test_ringStep() {
        compare(TrackPopupLogic.ringStep(0, 3, 1), 1)
        compare(TrackPopupLogic.ringStep(2, 3, 1), 0)
        compare(TrackPopupLogic.ringStep(0, 3, -1), 2)
        compare(TrackPopupLogic.ringStep(-1, 3, 1), 0)
        compare(TrackPopupLogic.ringStep(-1, 3, -1), 2)
        compare(TrackPopupLogic.ringStep(0, 1, 1), 0)
        compare(TrackPopupLogic.ringStep(0, 0, 1), -1)
    }

    // area 1000 x 600, popup 320 x 200, button 40 x 40 at the bottom
    function test_place_data() {
        return [
            { tag: "above, centred", ax: 480, ay: 550, x: 340, y: 342 },
            { tag: "clamped left", ax: 0, ay: 550, x: 8, y: 342 },
            { tag: "clamped right", ax: 960, ay: 550, x: 672, y: 342 },
            // 100 - 8 - 200 < 8: no room above, 100 + 40 + 8 + 200 + 8 <= 600 fits below
            { tag: "below when no room above", ax: 480, ay: 100, x: 340, y: 148 },
            // no room on either side (area 400 high): sticks to the top
            { tag: "top edge", ax: 480, ay: 150, x: 340, y: 8 },
        ]
    }

    function test_place(data) {
        const area = data.tag === "top edge" ? 400 : 600
        const p = TrackPopupLogic.place(data.ax, data.ay, 40, 40, 320, 200, 1000, area, 8, 8)
        compare(p.x, data.x)
        compare(p.y, data.y)
    }

    // taller than the area: sticks to the top edge (the popup caps its own height)
    function test_placeTallerThanArea() {
        const p = TrackPopupLogic.place(480, 550, 40, 40, 320, 700, 1000, 600, 8, 8)
        compare(p.x, 340)
        compare(p.y, 8)
    }

    function test_placeInTooNarrowArea() {
        const p = TrackPopupLogic.place(100, 300, 40, 40, 320, 200, 200, 600, 8, 8)
        compare(p.x, 8)
    }
}
