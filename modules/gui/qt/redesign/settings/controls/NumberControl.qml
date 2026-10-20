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

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Redesign

/**
 * @brief The control of a numeric setting without a slider (Figma "Values" number field).
 *
 * `from`/`to` are the bounds of the option; undefined means no bound (they are never read as
 * 0 or NaN). The number typed is reported by `edited` when the user validates it (Enter) or
 * leaves the field, clamped to the bounds, and only if it differs from `value`; text that is
 * not a number is dropped. Up and Down step by `stepSize` and report at once. Escape gives the
 * stored value back when there is something to give back, and then does not close the Settings
 * modal; with nothing typed it is left to the modal, which closes.
 */
Widgets.TextFieldExt {
    id: root

    // Properties

    //! the stored value
    property var value

    //! the name of the setting, for assistive technologies
    property string label

    //! a float setting, else an integer
    property bool isFloat: false

    //! lower bound, undefined for none
    property var from

    //! upper bound, undefined for none
    property var to

    property real stepSize: 1

    //! set by the host once the constants (range, choices...) are in: the value is applied after
    property bool ready: false

    //! the long description of the setting, for assistive technologies
    property string description

    //! the user entered `newValue`
    signal edited(var newValue)

    //! the text typed differs from the stored value (there is an edit to take back)
    readonly property bool _pendingEdit: root.text !== root._format(root.value)

    // Escape takes back a pending edit (and then does not close the modal), see EscapeRevert
    readonly property EscapeRevert _escape: EscapeRevert {
        pending: root._pendingEdit

        onRevert: root._showValue()
    }

    // Functions

    // 0.3 and not 0.30000000000000004
    function _format(v: var): string {
        const n = Number(v)
        if (v === undefined || v === null || !isFinite(n))
            return ""
        return String(Math.round(n * 1e6) / 1e6)
    }

    function _showValue() {
        root.text = Qt.binding(() => root._format(root.value))
    }

    function _report(number: var) {
        const v = ControlChooser.clamp(number, root.from, root.to)
        // an integer the configuration (and a double) can not hold exactly: not written
        if (!root.isFloat && Math.abs(v) > Number.MAX_SAFE_INTEGER) {
            _showValue()
            return
        }
        if (v !== Number(root.value))
            root.edited(v)
        _showValue()
    }

    function _step(direction: int) {
        // from what is typed, if it is a number
        let current = ControlChooser.parseNumber(root.text, root.isFloat)
        if (current === undefined)
            current = Number(root.value)
        if (!isFinite(current))
            current = 0
        _report(current + direction * root.stepSize)
    }

    // Settings

    // The width of the design, also the narrowest a control can be beside its label (the 160 dp
    // `minControl` that SettingRow gives ControlChooser.controlFit): the number field is exactly
    // as wide as it may be at least, so beside the label it gets its full width or none (the row
    // stacks). Should this change, controlFit still keeps the field beside the label at its own
    // width when that is below the minimum (it uses min(minControl, implicitWidth)).
    implicitWidth: VLCStyle.dp(160, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

    radius: RedesignStyle.radiusM

    selectByMouse: true

    inputMethodHints: isFloat ? Qt.ImhFormattedNumbersOnly : Qt.ImhDigitsOnly

    text: _format(value)

    Accessible.name: label
    Accessible.description: description

    onEditingFinished: {
        const parsed = ControlChooser.parseNumber(root.text, root.isFloat)
        if (parsed === undefined)
            _showValue()
        else
            _report(parsed)
    }

    Keys.onEscapePressed: (event) => root._escape.press(event)

    Keys.onReleased: (event) => root._escape.release(event)

    onActiveFocusChanged: {
        if (!activeFocus)
            root._escape.reset()
    }

    Keys.onUpPressed: (event) => {
        _step(1)
        event.accepted = true
    }

    Keys.onDownPressed: (event) => {
        _step(-1)
        event.accepted = true
    }
}
