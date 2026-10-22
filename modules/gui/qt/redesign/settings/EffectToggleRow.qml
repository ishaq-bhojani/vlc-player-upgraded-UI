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

import VLC.Redesign

/**
 * @brief The on/off switch of an audio filter (compressor, spatial audio, stereo widening), through
 * Effects: it adds the filter to the running chain or takes it out, and is stored.
 */
RowFrame {
    id: root

    // Properties

    //! the SettingsData row: `prop` is the Effects property
    property var spec

    // Settings

    title: spec ? spec.title : ""
    description: spec ? (spec.description ?? "") : ""

    // Children

    ToggleControl {
        ready: true
        label: root.title

        value: root.spec ? Effects[root.spec.prop] : false

        onEdited: (newValue) => Effects[root.spec.prop] = newValue
    }
}
