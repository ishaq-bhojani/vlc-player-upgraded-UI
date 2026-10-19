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
 * @brief Which control a setting gets (SettingRow), and the small pure helpers the controls
 * share.
 *
 * The pure part lives here, apart from the controls, because the controls need the theme
 * (ColorContext, MainCtx) that only exists inside the interface, while this can run in qml_test.
 */
QtObject {
    /**
     * The numbers of SettingItem.Type (settingsmodel.hpp). SettingItem is registered by the qt
     * plugin at run time and is not there in qml_test, so they are mirrored here.
     *
     * Two guards, both literal copies of the same order, so edit them together when
     * SettingItem::Type changes: the static_assert in redesign/cpp/qmlregistration.cpp (the C++
     * enum against the numbers) and test_typeNumbers in tests/tst_ControlChooser.qml (these
     * numbers against the numbers). The static_assert alone does not see this file.
     */
    readonly property var type: ({
        Bool: 0,
        Integer: 1,
        Float: 2,
        String: 3,
        Choice: 4,
        Path: 5,
        Hotkey: 6
    })

    /**
     * The file name (next to SettingRow.qml) of the control for a setting of `settingType`
     * (a SettingItem.Type):
     * - `hasRange`: both min and max are known, see hasRange()
     * - `hint`: what the page asks for: "slider" (Integer/Float with a range), "choices" (an
     *   Integer or String option whose plugin enumerates its values: such an option reports
     *   its plain type, SettingItem.choices is read lazily), "password" (a String shown as
     *   dots); anything else is ignored
     *
     * "" if the type has no generic control (a Hotkey is handled by the shortcuts page).
     */
    function controlFor(settingType: var, hasRange: bool, hint: string): string {
        switch (settingType) {
        case type.Bool:
            return "ToggleControl.qml"
        case type.Choice:
            return "DropdownControl.qml"
        case type.Integer:
        case type.Float:
            if (hint === "choices" && settingType === type.Integer)
                return "DropdownControl.qml"
            return (hint === "slider" && hasRange) ? "SliderControl.qml" : "NumberControl.qml"
        case type.Path:
            return "PathControl.qml"
        case type.String:
            return hint === "choices" ? "DropdownControl.qml" : "TextControl.qml"
        default:
            return ""
        }
    }

    // `min` and `max` of a SettingItem are undefined when the option declares no range: a range
    // needs both ends
    function hasRange(min: var, max: var): bool {
        return min !== undefined && min !== null && max !== undefined && max !== null
    }

    // `value` limited to [min, max]; an end that is undefined/null is no bound
    function clamp(value: real, min: var, max: var): real {
        let v = value
        if (min !== undefined && min !== null)
            v = Math.max(min, v)
        if (max !== undefined && max !== null)
            v = Math.min(max, v)
        return v
    }

    // The number typed in a field, or undefined if `text` is not a plain number (a ',' is read as
    // the decimal point). An integer field rounds, and refuses what a double can not hold
    // exactly (beyond +-Number.MAX_SAFE_INTEGER, i.e. 2^53 - 1).
    function parseNumber(text: string, isFloat: bool): var {
        const s = String(text).trim().replace(",", ".")
        if (!/^[+-]?(\d+\.?\d*|\.\d+)$/.test(s))
            return undefined
        const v = Number(s)
        if (!isFinite(v))
            return undefined
        if (isFloat)
            return v
        // (Math.round(v) of a large integer is not exact in the engine: leave integers alone)
        const rounded = Number.isInteger(v) ? v : Math.round(v)
        return Math.abs(rounded) > Number.MAX_SAFE_INTEGER ? undefined : rounded
    }

    // The index in `choices` ([{value, label}]) of `value`: 0 (the first row) if the value is not
    // listed, e.g. "" for a default that is no row of the list, -1 if there are no choices.
    // Values are compared as text: the configuration and the list may differ in type (3 and "3").
    function choiceIndex(choices: var, value: var): int {
        if (!choices || choices.length === 0)
            return -1
        if (value === undefined || value === null)
            return 0
        const wanted = String(value)
        for (let i = 0; i < choices.length; ++i) {
            if (String(choices[i].value) === wanted)
                return i
        }
        return 0
    }

    // The step of a slider from `min` to `max`: 1 for an integer, a hundredth of the range for a
    // float
    function sliderStep(isFloat: bool, min: real, max: real): real {
        if (!isFloat)
            return 1
        const range = max - min
        return range > 0 ? range / 100 : 0.01
    }
}
