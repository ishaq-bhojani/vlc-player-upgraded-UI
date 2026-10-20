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

    // --- Where the control goes in a row (SettingRow) ---

    //! the share of the row a control may take at most, the rest is for the label
    readonly property real controlShare: 0.55

    //! the control is one that was made for a wide row (a field, a list, a slider): it must be bounded
    function isWide(controlFile: string): bool {
        switch (controlFile) {
        case "PathControl.qml":
        case "TextControl.qml":
        case "NumberControl.qml":
        case "DropdownControl.qml":
        case "SliderControl.qml":
            return true
        default:
            return false
        }
    }

    /**
     * The narrowest a control can be and still be usable beside its label (see controlFit), in
     * the unit of the two arguments: `minPath` for a path (its field and the Browse button),
     * `minOther` for the others (a field or a list of a few characters).
     */
    function minControlWidth(controlFile: string, minPath: real, minOther: real): real {
        return controlFile === "PathControl.qml" ? minPath : minOther
    }

    /**
     * Where the control of a row goes: `stacked` (under the label, in the row below) or beside it
     * with `width`. Everything is in pixels.
     *
     * - `rowWidth`: the width of the row; `infoWidth`: the width of the info button, 0 if it is
     *   not shown; `spacing`: the gap between the items of the row
     * - `implicitWidth`: the width the control would like (320 for a field of the design)
     * - `minControl`: below this width the control is not usable beside the label (a control
     *   that would like less than this, `implicitWidth` < `minControl`, is usable at its own width)
     * - `minLabel`: the width the label always keeps
     *
     * Beside the label the control takes its implicit width, but never more than controlShare of
     * the row and never so much that the label has less than minLabel. A row too narrow for that
     * stacks: the control goes under the label and takes the row, up to its implicit width.
     */
    function controlFit(rowWidth: real, infoWidth: real, spacing: real, implicitWidth: real,
                        minControl: real, minLabel: real): var {
        const info = infoWidth > 0 ? infoWidth + spacing : 0
        // what the label and the control share, less the gap between them
        const free = rowWidth - info - spacing
        const width = Math.min(implicitWidth, Math.floor(rowWidth * controlShare), free - minLabel)
        if (width < Math.min(minControl, implicitWidth))
            return { stacked: true, width: Math.max(0, Math.min(implicitWidth, rowWidth)) }
        return { stacked: false, width: width }
    }
}
