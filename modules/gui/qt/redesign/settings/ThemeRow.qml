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
 * @brief The theme row of the General page: Dark, Light or System.
 *
 * The color scheme is not a configuration item: it is the current row of the ColorSchemeModel of
 * the main window. SettingsBridge gives each row a `kind`, the buttons are matched to the rows by
 * it and never by position.
 */
RowFrame {
    id: root

    // Properties

    //! the SettingsData row
    property var spec

    //! "dark", "light" or "system": the scheme in use
    readonly property string current: {
        const scheme = SettingsBridge.colorSchemes[SettingsBridge.colorSchemeIndex]
        return scheme ? scheme.kind : "system"
    }

    // Settings

    title: spec ? spec.title : ""
    description: spec ? (spec.description ?? "") : ""

    // Children

    SegmentedControl {
        label: root.title

        // the order of the Figma frame
        model: [
            { text: qsTr("Dark"), value: "dark" },
            { text: qsTr("Light"), value: "light" },
            { text: qsTr("System"), value: "system" }
        ]
        current: root.current

        onPicked: (kind) => {
            const index = SettingsOps.schemeIndex(kind)
            if (index >= 0)
                SettingsBridge.colorSchemeIndex = index
        }
    }
}
