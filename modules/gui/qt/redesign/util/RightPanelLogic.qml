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
pragma Singleton
import QtQml

/**
 * @brief Logic of the right panel (RightPanel): the modes, the width it takes, and how the mode
 * follows the play queue state of upstream (MainCtx.playqueuePanel: docked, visible).
 *
 * A mode is one of "" (closed), "queue" or "sidebar".
 */
QtObject {
    readonly property var modes: ["", "queue", "sidebar"]

    // `mode` if it is one of the modes, else "" (closed)
    function normalized(mode: string): string {
        return modes.includes(mode) ? mode : ""
    }

    // The mode after `requested` was toggled: closed if it was the open one, else `requested`.
    function toggled(current: string, requested: string): string {
        return (current === requested) ? "" : normalized(requested)
    }

    /**
     * Width and placement of the panel.
     *   requested:  the width the user chose (persisted), kept within [minWidth, maxWidth]
     *   free:       the width the panel and the stage share
     *   stageMin:   the width the stage keeps at least when the panel is docked
     * The panel is docked (the stage shrinks) while the stage keeps `stageMin`. Else it is an
     * overlay on the stage: at most `share` of the free width, so it never covers all of it.
     * Returns { width, overlay }.
     */
    function layout(requested: real, minWidth: real, maxWidth: real, free: real,
                    stageMin: real, share: real): var {
        const width = Math.max(minWidth, Math.min(maxWidth, requested))
        if ((free - width) >= stageMin)
            return { "width": width, "overlay": false }
        return { "width": Math.max(0, Math.min(width, Math.floor(free * share))), "overlay": true }
    }

    // The mode after the upstream play queue state changed: a docked and visible queue is the
    // "queue" mode; any other state closes the "queue" mode (a detached queue is a window, not
    // the panel) and leaves the other modes alone.
    function modeForQueueState(mode: string, docked: bool, visible: bool): string {
        if (docked && visible)
            return "queue"
        return (mode === "queue") ? "" : mode
    }
}
