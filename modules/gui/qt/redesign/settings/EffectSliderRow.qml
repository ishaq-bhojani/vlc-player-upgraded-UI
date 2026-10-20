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
import QtQuick.Layouts

import VLC.Style
import VLC.Redesign

/**
 * @brief A parameter of an audio or video effect (compressor attack, hue...). The name and the
 * range are those of the configuration item; the value is read from and written to Effects, which
 * also sets it on the running output.
 */
RowFrame {
    id: root

    // Properties

    //! the SettingsData row: `group` the Effects map, `name` its key, `key` the item
    property var spec

    readonly property var setting: spec ? RedesignSettings.item(spec.key) : null

    // Settings

    title: setting ? setting.text : ""

    // the slider of a wide row: bounded (see RowFrame), usable from 160 dp
    controlMinimum: VLCStyle.dp(160, VLCStyle.scale)

    // Children

    SliderControl {
        Layout.fillWidth: true

        from: root.setting && root.setting.min !== undefined ? root.setting.min : 0
        to: root.setting && root.setting.max !== undefined ? root.setting.max : 1
        stepSize: ControlChooser.sliderStep(!root.setting || root.setting.type === ControlChooser.type.Float,
                                            from, to)

        ready: true
        label: root.title
        description: root.setting ? root.setting.longText : ""

        value: root.spec ? Effects[root.spec.group][root.spec.name] : 0

        onEdited: (newValue) => {
            const values = {}
            values[root.spec.name] = newValue
            Effects[root.spec.group] = values
        }
    }
}
