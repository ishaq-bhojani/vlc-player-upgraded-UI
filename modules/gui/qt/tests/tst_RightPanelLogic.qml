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
    name: "RightPanelLogic"

    function test_normalized() {
        compare(RightPanelLogic.normalized("queue"), "queue")
        compare(RightPanelLogic.normalized("sidebar"), "sidebar")
        compare(RightPanelLogic.normalized(""), "")
        compare(RightPanelLogic.normalized("Queue"), "")
        compare(RightPanelLogic.normalized("bogus"), "")
    }

    function test_toggled() {
        compare(RightPanelLogic.toggled("", "queue"), "queue")
        compare(RightPanelLogic.toggled("queue", "queue"), "")
        // the other panel replaces the open one
        compare(RightPanelLogic.toggled("queue", "sidebar"), "sidebar")
        compare(RightPanelLogic.toggled("sidebar", "queue"), "queue")
        compare(RightPanelLogic.toggled("sidebar", "sidebar"), "")
        // an unknown mode closes
        compare(RightPanelLogic.toggled("queue", "bogus"), "")
    }

    function test_layout_data() {
        // min 240, max 560, stage keeps 480, overlay at most 3/4 of the free width
        return [
            { tag: "room", req: 320, free: 1200, width: 320, overlay: false },
            { tag: "clamped to max", req: 900, free: 1600, width: 560, overlay: false },
            { tag: "clamped to min", req: 100, free: 1200, width: 240, overlay: false },
            { tag: "exactly enough room", req: 320, free: 800, width: 320, overlay: false },
            { tag: "one pixel short: overlay", req: 320, free: 799, width: 320, overlay: true },
            { tag: "small window: overlay, never all of it", req: 560, free: 600, width: 450, overlay: true },
            { tag: "tiny window", req: 320, free: 200, width: 150, overlay: true },
            { tag: "no room", req: 320, free: 0, width: 0, overlay: true },
            { tag: "negative room", req: 320, free: -50, width: 0, overlay: true },
            { tag: "share rounds down", req: 320, free: 319, width: 239, overlay: true },
            { tag: "just above the minimum", req: 240, free: 330, width: 240, overlay: true },
        ]
    }

    function test_layout(data) {
        const l = RightPanelLogic.layout(data.req, 240, 560, data.free, 480, 0.75)
        compare(l.width, data.width)
        compare(l.overlay, data.overlay)
        // an overlay never covers the whole free width
        if (l.overlay && data.free > 0)
            verify(l.width < data.free)
        // ... and is never narrower than the smaller of the minimum width and the share
        if (l.overlay)
            verify(l.width >= Math.min(240, Math.floor(Math.max(0, data.free) * 0.75)))
    }

    function test_modeForQueueState_data() {
        return [
            { tag: "docked + visible opens", mode: "", docked: true, visible: true, out: "queue" },
            { tag: "docked + visible replaces the sidebar", mode: "sidebar", docked: true, visible: true, out: "queue" },
            { tag: "already open", mode: "queue", docked: true, visible: true, out: "queue" },
            { tag: "hidden closes", mode: "queue", docked: true, visible: false, out: "" },
            { tag: "hidden keeps the sidebar", mode: "sidebar", docked: true, visible: false, out: "sidebar" },
            { tag: "detached closes the panel", mode: "queue", docked: false, visible: true, out: "" },
            { tag: "detached keeps the sidebar", mode: "sidebar", docked: false, visible: true, out: "sidebar" },
            { tag: "detached and hidden", mode: "", docked: false, visible: false, out: "" },
        ]
    }

    function test_modeForQueueState(data) {
        compare(RightPanelLogic.modeForQueueState(data.mode, data.docked, data.visible), data.out)
    }
}
