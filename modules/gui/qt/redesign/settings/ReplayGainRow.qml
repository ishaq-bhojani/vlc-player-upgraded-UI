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
 * @brief The "Replay gain" choice: None, Track, Album or Measured, through MeasuredGain.
 *
 * None, Track and Album are the values of audio-replay-gain-mode. Measured is the mode "track" of
 * VLC plus the redesign's own flag (MeasuredGain.enabled), which levels the files that carry no
 * replay gain tags from a measurement of their loudness. MeasuredGain writes the mode to the
 * configuration and to the running audio output, and keeps the flag in the QSettings group
 * "redesign".
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

    DropdownControl {
        ready: true
        label: root.title
        description: root.description

        choices: [
            { value: "none", label: qsTr("None") },
            { value: "track", label: qsTr("Track") },
            { value: "album", label: qsTr("Album") },
            { value: "measured", label: qsTr("Measured") }
        ]

        value: MeasuredGain.choice

        onEdited: (newValue) => MeasuredGain.choice = newValue
    }
}
