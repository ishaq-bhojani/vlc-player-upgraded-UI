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
import QtTest
import VLC.Redesign

// SettingItem and RedesignSettings are registered by the qt plugin at run time, so they do not
// exist in qml_test: the type numbers are ControlChooser.type, which mirrors SettingItem.Type
// (the order is pinned by a static_assert in redesign/cpp/qmlregistration.cpp).
TestCase {
    name: "ControlChooser"

    readonly property var t: ControlChooser.type

    function test_typeNumbers() {
        // the order of SettingItem::Type in settingsmodel.hpp
        compare(t.Bool, 0)
        compare(t.Integer, 1)
        compare(t.Float, 2)
        compare(t.String, 3)
        compare(t.Choice, 4)
        compare(t.Path, 5)
        compare(t.Hotkey, 6)
    }

    function test_controlFor_data() {
        return [
            { tag: "bool", type: t.Bool, range: false, hint: "", expected: "ToggleControl.qml" },
            { tag: "bool, range and slider hint do not matter", type: t.Bool, range: true, hint: "slider", expected: "ToggleControl.qml" },
            { tag: "choice", type: t.Choice, range: false, hint: "", expected: "DropdownControl.qml" },
            { tag: "choice, slider hint", type: t.Choice, range: true, hint: "slider", expected: "DropdownControl.qml" },
            { tag: "integer slider", type: t.Integer, range: true, hint: "slider", expected: "SliderControl.qml" },
            { tag: "float slider", type: t.Float, range: true, hint: "slider", expected: "SliderControl.qml" },
            // a slider needs both ends
            { tag: "integer slider without range", type: t.Integer, range: false, hint: "slider", expected: "NumberControl.qml" },
            { tag: "float slider without range", type: t.Float, range: false, hint: "slider", expected: "NumberControl.qml" },
            { tag: "integer", type: t.Integer, range: false, hint: "", expected: "NumberControl.qml" },
            { tag: "integer with a range", type: t.Integer, range: true, hint: "", expected: "NumberControl.qml" },
            { tag: "float", type: t.Float, range: false, hint: "", expected: "NumberControl.qml" },
            { tag: "float with a range", type: t.Float, range: true, hint: "number", expected: "NumberControl.qml" },
            { tag: "path", type: t.Path, range: false, hint: "", expected: "PathControl.qml" },
            { tag: "string", type: t.String, range: false, hint: "", expected: "TextControl.qml" },
            { tag: "string, unrelated hint", type: t.String, range: false, hint: "slider", expected: "TextControl.qml" },
            { tag: "string, password hint", type: t.String, range: false, hint: "password", expected: "TextControl.qml" },
            // plugin enumerated options report String (SettingItem.choices is lazy)
            { tag: "string with plugin choices", type: t.String, range: false, hint: "choices", expected: "DropdownControl.qml" },
            { tag: "integer with plugin choices", type: t.Integer, range: false, hint: "choices", expected: "DropdownControl.qml" },
            { tag: "hotkey", type: t.Hotkey, range: false, hint: "", expected: "" },
            { tag: "unknown type", type: 42, range: false, hint: "", expected: "" },
            { tag: "undefined type", type: undefined, range: false, hint: "", expected: "" },
        ]
    }

    function test_controlFor(data) {
        compare(ControlChooser.controlFor(data.type, data.range, data.hint), data.expected)
    }

    function test_integerSliderHintWithoutRangeIsNumber() {
        compare(ControlChooser.controlFor(t.Integer, false, "slider"), "NumberControl.qml")
    }

    // a range is "both ends known"; an option without range is unbounded, not 0..undefined
    function test_hasRange_data() {
        return [
            { tag: "both", min: 0, max: 10, expected: true },
            { tag: "zero is a bound", min: 0, max: 0, expected: true },
            { tag: "negative", min: -5, max: 5, expected: true },
            { tag: "neither", min: undefined, max: undefined, expected: false },
            { tag: "null", min: null, max: null, expected: false },
            { tag: "only min", min: 0, max: undefined, expected: false },
            { tag: "only max", min: undefined, max: 10, expected: false },
        ]
    }

    function test_hasRange(data) {
        compare(ControlChooser.hasRange(data.min, data.max), data.expected)
    }

    function test_clamp_data() {
        return [
            { tag: "inside", v: 5, min: 0, max: 10, expected: 5 },
            { tag: "below", v: -5, min: 0, max: 10, expected: 0 },
            { tag: "above", v: 50, min: 0, max: 10, expected: 10 },
            { tag: "no bounds", v: 1e9, min: undefined, max: undefined, expected: 1e9 },
            { tag: "only min", v: -3, min: 0, max: undefined, expected: 0 },
            { tag: "only max, below", v: -3, min: undefined, max: 10, expected: -3 },
            { tag: "only max, above", v: 30, min: undefined, max: 10, expected: 10 },
        ]
    }

    function test_clamp(data) {
        compare(ControlChooser.clamp(data.v, data.min, data.max), data.expected)
    }

    function test_parseNumber_data() {
        return [
            { tag: "integer", text: "42", isFloat: false, expected: 42 },
            { tag: "negative", text: " -7 ", isFloat: false, expected: -7 },
            { tag: "integer rounds", text: "2.6", isFloat: false, expected: 3 },
            { tag: "float", text: "1.25", isFloat: true, expected: 1.25 },
            { tag: "float with comma", text: "1,25", isFloat: true, expected: 1.25 },
            { tag: "empty", text: "", isFloat: false, expected: undefined },
            { tag: "blank", text: "  ", isFloat: true, expected: undefined },
            { tag: "text", text: "abc", isFloat: false, expected: undefined },
            { tag: "trailing garbage", text: "12px", isFloat: false, expected: undefined },
            { tag: "infinity", text: "Infinity", isFloat: true, expected: undefined },
            // an integer beyond 2^53 - 1 is not exact in a double: refused, a float is not
            { tag: "largest safe integer", text: "9007199254740991", isFloat: false, expected: 9007199254740991 },
            { tag: "smallest safe integer", text: "-9007199254740991", isFloat: false, expected: -9007199254740991 },
            { tag: "integer beyond 2^53", text: "9007199254740993", isFloat: false, expected: undefined },
            { tag: "negative integer beyond 2^53", text: "-9007199254740993", isFloat: false, expected: undefined },
            { tag: "huge integer", text: "1" + "0".repeat(40), isFloat: false, expected: undefined },
            { tag: "huge float", text: "1" + "0".repeat(40), isFloat: true, expected: 1e40 },
        ]
    }

    function test_parseNumber(data) {
        compare(ControlChooser.parseNumber(data.text, data.isFloat), data.expected)
    }

    function test_choiceIndex() {
        const choices = [ { value: "", label: "Default" }, { value: "a", label: "A" }, { value: 3, label: "Three" } ]
        compare(ControlChooser.choiceIndex(choices, "a"), 1)
        compare(ControlChooser.choiceIndex(choices, 3), 2)
        // the value of the configuration may come as the other type
        compare(ControlChooser.choiceIndex(choices, "3"), 2)
        compare(ControlChooser.choiceIndex(choices, ""), 0)
    }

    // a value that is not in the list (aout "" when the list has no "") shows the first row
    function test_choiceIndexUnknownValueShowsFirst() {
        const choices = [ { value: "x", label: "X" }, { value: "y", label: "Y" } ]
        compare(ControlChooser.choiceIndex(choices, ""), 0)
        compare(ControlChooser.choiceIndex(choices, undefined), 0)
        compare(ControlChooser.choiceIndex(choices, "zzz"), 0)
    }

    function test_choiceIndexEmptyList() {
        compare(ControlChooser.choiceIndex([], "a"), -1)
        compare(ControlChooser.choiceIndex(undefined, "a"), -1)
    }

    function test_sliderStep_data() {
        return [
            { tag: "integer range", isFloat: false, min: 60, max: 300, expected: 1 },
            { tag: "float 0..1", isFloat: true, min: 0, max: 1, expected: 0.01 },
            { tag: "float 0..2", isFloat: true, min: 0, max: 2, expected: 0.02 },
            { tag: "float wide range", isFloat: true, min: 0, max: 1000, expected: 10 },
            { tag: "float empty range", isFloat: true, min: 1, max: 1, expected: 0.01 },
        ]
    }

    function test_sliderStep(data) {
        fuzzyCompare(ControlChooser.sliderStep(data.isFloat, data.min, data.max), data.expected, 1e-9)
    }

    function test_isWide_data() {
        return [
            { tag: "path", file: "PathControl.qml", wide: true },
            { tag: "text", file: "TextControl.qml", wide: true },
            { tag: "number", file: "NumberControl.qml", wide: true },
            { tag: "dropdown", file: "DropdownControl.qml", wide: true },
            { tag: "slider", file: "SliderControl.qml", wide: true },
            { tag: "toggle", file: "ToggleControl.qml", wide: false },
            { tag: "none", file: "", wide: false },
        ]
    }

    function test_isWide(data) {
        compare(ControlChooser.isWide(data.file), data.wide)
    }

    // the sizes of the design at 100%: a field of 320, an info button of 24, gaps of 12, a label
    // that keeps 120, a control that is not usable under 160 (a path under 200)
    function fit(rowWidth, implicitWidth, info, minControl) {
        return ControlChooser.controlFit(rowWidth, info === undefined ? 24 : info, 12, implicitWidth,
                                         minControl ?? 160, 120)
    }

    function test_controlFit_data() {
        return [
            { tag: "narrow row stacks", row: 291, implicit: 320, stacked: true, width: 291 },
            { tag: "stacked, field narrower than the row", row: 291, implicit: 160, minControl: 200, stacked: true, width: 160 },
            { tag: "just wide enough for a path", row: 420, implicit: 320, minControl: 200, stacked: false, width: 231 },
            { tag: "settings page at 900", row: 555, implicit: 320, stacked: false, width: 305 },
            { tag: "wide row: the implicit width", row: 743, implicit: 320, stacked: false, width: 320 },
            { tag: "small field is not stretched", row: 555, implicit: 160, stacked: false, width: 160 },
            { tag: "no info button gives the room", row: 300, implicit: 320, info: 0, stacked: false, width: 165 },
            { tag: "empty row", row: 0, implicit: 320, stacked: true, width: 0 },
        ]
    }

    function test_controlFit(data) {
        const r = fit(data.row, data.implicit, data.info, data.minControl)
        compare(r.stacked, data.stacked)
        compare(r.width, data.width)
    }

    // whatever the width of the row: a control beside the label leaves the label its room and at
    // most the share of the row, a stacked one never overflows
    function test_controlFit_neverOverflows() {
        for (const implicit of [160, 320]) {
            for (let row = 150; row <= 1600; row += 7) {
                const r = fit(row, implicit)
                verify(r.width <= row, "row " + row + ": " + JSON.stringify(r))
                verify(r.width <= implicit)
                if (!r.stacked) {
                    verify(r.width >= 160, "row " + row)
                    verify(r.width <= row * ControlChooser.controlShare, "row " + row)
                    // the label, the info button and the two gaps
                    verify(row - r.width - 24 - 12 - 12 >= 120, "label room at row " + row)
                }
            }
        }
    }

    function test_controlFit_monotonic() {
        // a wider row never makes the control narrower while it stays beside the label
        let last = 0
        for (let row = 300; row <= 1600; row += 5) {
            const r = fit(row, 320)
            if (r.stacked)
                continue
            verify(r.width >= last, "row " + row)
            last = r.width
        }
    }
}
