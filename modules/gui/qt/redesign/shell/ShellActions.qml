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
pragma Singleton
import QtQuick

/**
 * @brief Requests of the controls of the player to the shell.
 *
 * Control items (the buttons of the control bar) emit these signals and know nothing about the
 * panels; the root window connects them (queue panel, watch sidebar, track popups).
 */
QtObject {
    // the Queue button was clicked: toggle the queue panel
    signal queueRequested()

    // the Settings button was clicked: toggle the watch sidebar
    signal sidebarRequested()

    // Dialogs: the redesign dialogs are hosted once, by DialogHost.qml; whoever wants one emits the
    // request and knows nothing about the dialog.

    // open the "Open network stream" dialog (the main menu of the title bar)
    signal networkStreamRequested()

    // open the Settings modal on `page` (an id of SettingsData.pages, "shortcuts" for the keyboard
    // shortcuts of Controls; "" for the page shown last)
    signal settingsRequested(string page)

    // open the "Add subtitles" dialog on `mode`: "current" (a file for the media being played),
    // "playlist" (the media of the play queue), "folder" (a folder of videos), or "" to let the
    // dialog choose by what is playing
    signal addSubtitlesRequested(string mode)

    // open the "Keyboard shortcuts" dialog (the same page as Settings > Controls > Keyboard shortcuts)
    signal keyboardShortcutsRequested()

    // open the "New playlist" dialog, which puts the media of `mediaIds` (a list of media library
    // ids, [] for an empty playlist) into the playlist it creates. It needs the media library.
    signal newPlaylistRequested(var mediaIds)

    // open the track popup on `tab` ("subtitles", "audio" or "video"), placed at `anchor`
    signal trackPopupRequested(string tab, Item anchor)

    // the Play button of the control bar (null while there is none), the resume prompt is
    // placed above it
    property Item playButton: null
}
