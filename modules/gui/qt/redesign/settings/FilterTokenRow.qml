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
 * @brief The switch of a filter that is one entry of a list option (Negate colors: "invert" in
 * video-filter). Only the option is written: the filter is in use from the next video.
 */
RowFrame {
    id: root

    // Properties

    //! the SettingsData row: `key` the list option, `token` the filter
    property var spec

    // Settings

    title: spec ? spec.title : ""
    description: spec ? (spec.description ?? "") : ""

    // Children

    ToggleControl {
        ready: true
        label: root.title

        value: root.spec ? SettingsOps.hasFilter(root.spec.key, root.spec.token) : false

        onEdited: (newValue) => SettingsOps.setFilter(root.spec.key, root.spec.token, newValue)
    }
}
