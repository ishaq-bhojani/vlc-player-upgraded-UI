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
import QtQuick.Templates as T

import VLC.Style
import VLC.Redesign

/**
 * @brief The control of a numeric setting with a range (Figma slider: 16 track with a 2
 * border, 8 x 24 thumb) and its value written next to it.
 *
 * `from`/`to` are the range. The value written follows the thumb live, but `edited` is only
 * reported when the pick ends: the mouse button is released, or the keyboard stopped stepping
 * (a short pause, or the focus leaving), because every report rewrites the configuration file.
 * Left/Right and Up/Down step by `stepSize`.
 */
FocusScope {
    id: root

    // Properties

    //! the stored value
    property var value: 0

    //! the name of the setting, for assistive technologies
    property string label

    property real from: 0
    property real to: 1
    property real stepSize: 1

    //! the user chose `newValue`, once per pick
    signal edited(var newValue)

    // the pick in progress, not reported yet
    property real _pending: 0
    property bool _picking: false

    readonly property real _shown: _picking ? _pending : _number(value)

    // 1 -> 0 digits, 0.01 -> 2 digits
    readonly property int _decimals: stepSize >= 1 ? 0 : Math.min(6, Math.ceil(-Math.log10(stepSize) - 1e-9))

    // Functions

    function _number(v: var): real {
        const n = Number(v)
        return isFinite(n) ? n : root.from
    }

    // reports the pick in progress
    function _commit() {
        commitTimer.stop()
        if (!root._picking)
            return
        root._picking = false
        root.edited(root._pending)
    }

    // Settings

    implicitWidth: VLCStyle.dp(320, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(28, VLCStyle.scale)

    onActiveFocusChanged: if (!activeFocus) _commit()

    // Children

    Timer {
        id: commitTimer

        // the keyboard steps by repeats: report when it paused
        interval: 400

        onTriggered: root._commit()
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.Slider

        enabled: root.enabled
        focused: slider.visualFocus
        hovered: slider.hovered
    }

    readonly property ColorContext textContext: ColorContext {
        id: textTheme

        colorSet: ColorContext.View

        enabled: root.enabled
    }

    RowLayout {
        anchors.fill: parent

        spacing: RedesignStyle.spacingM

        T.Slider {
            id: slider

            Layout.fillWidth: true
            Layout.fillHeight: true

            focus: true
            focusPolicy: Qt.StrongFocus

            from: root.from
            to: root.to
            stepSize: root.stepSize
            snapMode: T.Slider.SnapAlways

            Accessible.role: Accessible.Slider
            Accessible.name: root.label

            Accessible.onIncreaseAction: slider.increase()
            Accessible.onDecreaseAction: slider.decrease()

            // `moved` is the user's, the stored value never goes through here
            onMoved: {
                root._pending = slider.value
                root._picking = true
                // a drag ends with the release, a key press has no end event
                if (!slider.pressed)
                    commitTimer.restart()
            }

            onPressedChanged: {
                if (!slider.pressed)
                    root._commit()
            }

            // follows the stored value, except while the user is picking
            Binding {
                target: slider
                property: "value"
                value: root._number(root.value)
                when: !root._picking && !slider.pressed
                restoreMode: Binding.RestoreNone
            }

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + (slider.availableHeight - height) / 2
                width: slider.availableWidth
                height: VLCStyle.dp(16, VLCStyle.scale)

                radius: RedesignStyle.radiusS

                color: theme.bg.primary
                border.width: VLCStyle.dp(2, VLCStyle.scale)
                border.color: theme.border

                // the filled part
                Rectangle {
                    x: parent.border.width
                    y: parent.border.width
                    width: Math.max(0, (parent.width - 2 * parent.border.width) * slider.position)
                    height: parent.height - 2 * parent.border.width

                    radius: Math.max(0, parent.radius - parent.border.width)
                    color: theme.fg.primary
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + (slider.availableHeight - height) / 2

                implicitWidth: VLCStyle.dp(8, VLCStyle.scale)
                implicitHeight: VLCStyle.dp(24, VLCStyle.scale)

                radius: VLCStyle.dp(2, VLCStyle.scale)
                color: theme.accent

                border.width: slider.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                border.color: theme.visualFocus
            }
        }

        Text {
            Layout.preferredWidth: valueMetrics.width
            Layout.alignment: Qt.AlignVCenter

            horizontalAlignment: Text.AlignRight

            text: root._shown.toFixed(root._decimals)
            font.pixelSize: VLCStyle.fontSize_normal
            color: textTheme.fg.primary

            // the value is not read by assistive technologies twice: the slider has it
            Accessible.ignored: true

            TextMetrics {
                id: valueMetrics

                font.pixelSize: VLCStyle.fontSize_normal

                // the widest value, so the track does not move while dragging
                text: "8".repeat(Math.max(Number(root.to).toFixed(root._decimals).length,
                                          Number(root.from).toFixed(root._decimals).length))
            }
        }
    }
}
