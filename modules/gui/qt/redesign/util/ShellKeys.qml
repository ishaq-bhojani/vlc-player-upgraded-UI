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
 * @brief The keys that the window takes before the player's hotkeys see them.
 *
 * ShortcutsModel only knows the hotkeys of the core (the "key-*" options). The window has
 * shortcuts of its own: Ctrl+P of the redesign (DialogHost.qml, Settings), and the shortcuts of
 * the stock interface that the redesign still loads (menus/qml/GlobalShortcuts.qml). A Qt shortcut
 * is handled before the key reaches the hotkeys, so a hotkey on one of these keys may never fire.
 * The shortcuts page uses this list to warn, it does not forbid anything.
 *
 * Keep it in step with DialogHost.qml and GlobalShortcuts.qml.
 */
QtObject {
    // [{key, text}]: `key` in the notation of the hotkeys ("Ctrl+P"), `text` what the window does
    readonly property var reserved: [
        {key: "Ctrl+P", text: qsTr("opens Settings")},
        {key: "Ctrl+L", text: qsTr("shows or hides the play queue")},
        {key: "Ctrl+O", text: qsTr("opens a file")},
        {key: "Ctrl+Shift+O", text: qsTr("opens several files")},
        {key: "Ctrl+F", text: qsTr("opens a folder")},
        {key: "Ctrl+D", text: qsTr("opens a disc")},
        {key: "Ctrl+N", text: qsTr("opens a network stream")},
        {key: "Ctrl+C", text: qsTr("opens a capture device")},
        {key: "Ctrl+V", text: qsTr("pastes the clipboard")},
        {key: "Ctrl+Y", text: qsTr("saves the playlist")},
        {key: "Ctrl+R", text: qsTr("converts media")},
        {key: "Ctrl+S", text: qsTr("streams media")},
        {key: "Ctrl+Q", text: qsTr("quits")},
        {key: "Ctrl+E", text: qsTr("opens the effects")},
        {key: "Ctrl+I", text: qsTr("shows the media information")},
        {key: "Ctrl+J", text: qsTr("shows the codec information")},
        {key: "Ctrl+M", text: qsTr("shows the messages")},
        {key: "Ctrl+T", text: qsTr("jumps to a time")},
        {key: "Ctrl+H", text: qsTr("switches the minimal view")},
        {key: "Ctrl+Shift+W", text: qsTr("opens the VLM configuration")},
        {key: "F1", text: qsTr("opens the help")},
        {key: "F10", text: qsTr("shows the menu bar")},
        {key: "F11", text: qsTr("switches the full screen of the interface")},
        {key: "Ctrl+=", text: qsTr("zooms the interface in")},
        {key: "Ctrl++", text: qsTr("zooms the interface in")},
        {key: "Ctrl+-", text: qsTr("zooms the interface out")},
        {key: "Ctrl+Shift+-", text: qsTr("zooms the interface out")}
    ]

    // Functions

    //! A key in one notation whatever the case or the order of its modifiers:
    //! "Shift+Ctrl+P" and "ctrl+shift+p" give "ctrl+shift+p". "" for nothing.
    function normalize(hotkey) {
        let rest = String(hotkey ?? "").trim().toLowerCase()
        if (rest === "")
            return ""

        const modifiers = []
        for (;;) {
            const found = /^(ctrl|alt|shift|meta)\+(.+)$/.exec(rest)
            if (!found)
                break
            modifiers.push(found[1])
            rest = found[2]
        }
        modifiers.sort()
        return modifiers.concat([rest]).join("+")
    }

    //! What the window does with `hotkey` ("opens Settings"), "" when it does not use it. A value
    //! of several keys ("Space\tMedia Play Pause") is asked for each of them, the first hit wins.
    function reservedFor(hotkey) {
        for (const key of String(hotkey ?? "").split("\t")) {
            const wanted = normalize(key)
            if (wanted === "")
                continue
            const found = reserved.find(entry => normalize(entry.key) === wanted)
            if (found)
                return found.text
        }
        return ""
    }
}
