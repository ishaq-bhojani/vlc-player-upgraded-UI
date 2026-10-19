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
 * stored value back.
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

    //! the user entered `newValue`
    signal edited(var newValue)

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

    implicitWidth: VLCStyle.dp(160, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

    radius: RedesignStyle.radiusM

    selectByMouse: true

    inputMethodHints: isFloat ? Qt.ImhFormattedNumbersOnly : Qt.ImhDigitsOnly

    text: _format(value)

    Accessible.name: label

    onEditingFinished: {
        const parsed = ControlChooser.parseNumber(root.text, root.isFloat)
        if (parsed === undefined)
            _showValue()
        else
            _report(parsed)
    }

    Keys.onEscapePressed: (event) => {
        _showValue()
        event.accepted = true
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
