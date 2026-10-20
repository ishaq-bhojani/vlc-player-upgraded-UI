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

import VLC.Redesign

/**
 * @brief The switch of the website playback tools (yt-dlp, ffmpeg): ON is the consent of the
 * dialog that explains the downloads (spec 12.1), OFF takes it back.
 */
RowFrame {
    id: root

    // Properties

    //! the SettingsData row
    property var spec

    // Settings

    title: spec ? spec.title : ""
    description: spec ? (spec.description ?? "") : ""

    // Children

    ToggleControl {
        ready: true
        label: root.title

        value: ToolManager.consentGiven

        // turning it on asks first: the dialog stores the consent
        onEdited: (newValue) => {
            if (newValue)
                consent.open()
            else
                ToolManager.consentGiven = false
        }
    }

    ToolConsentDialog {
        id: consent

        needsFfmpeg: true
    }
}
