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
import QtQml
import QtCore as QtCore

/**
 * @brief The player preferences of the redesign that more than one item reads or writes, kept in
 * the settings (category "redesign") by this one object so that a change is seen by all of them
 * at once.
 *
 * `showWaveform`: the seek bar shows the waveform of local audio (SeekBarWidget); the Playback
 * tab of the settings writes it.
 */
QtObject {
    property alias showWaveform: settings.showWaveform

    readonly property QtCore.Settings _settings: QtCore.Settings {
        id: settings

        category: "redesign"

        property bool showWaveform: true
    }
}
