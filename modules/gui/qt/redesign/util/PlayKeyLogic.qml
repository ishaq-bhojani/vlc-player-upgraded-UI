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

// Decisions that make one press of Space toggle play/pause once, kept apart from the items that
// ask so they can be tested. Space reaches the player in two ways: the window forwards it as the
// play/pause hotkey when no item took it (RedesignInterface.qml), and the Play button takes it
// itself while it has the keyboard focus (PlayPillButton.qml, on the release, like the stock one).
QtObject {
    // Whether a key that no item took is forwarded as a hotkey. A key that is held down repeats
    // (isAutoRepeat): for Space every repeat would toggle again (pause, play, pause, ...), so
    // only the press itself counts. The other keys keep repeating (volume, seek).
    function forwardsAsHotkey(key: int, autoRepeat: bool): bool {
        return !(autoRepeat && (key === Qt.Key_Space))
    }

    // Whether the release of Space on the Play button toggles. Only the release of a press this
    // button took does: when the press was taken elsewhere (the window forwarded it as the
    // hotkey, a popup closed on it) and the focus moved to the button before the release, the
    // press already toggled and this release would toggle back (pause, then play at once). A
    // stopped player is not toggled (the stock button does the same).
    function releaseToggles(pressTaken: bool, stopped: bool): bool {
        return pressTaken && !stopped
    }
}
