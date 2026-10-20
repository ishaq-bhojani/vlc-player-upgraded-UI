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
import VLC.Widgets as Widgets
import VLC.Redesign

/**
 * @brief The equalizer of the Audio page (Figma "Settings - audio"): the on/off switch, a preset
 * dropdown, 10 vertical band sliders, the preamp and the two-pass switch. "Show equalizer" /
 * "Close equalizer" folds the panel; the switch stays in view.
 *
 * Everything goes through Effects: a band is written when the slider is released (or after a
 * pause of the keys), because each write rewrites the configuration file; the preset names are
 * Effects.equalizerPresets, labelled by Effects.equalizerPresetLabel(). The bands are labelled
 * with the frequencies of the filter (modules/audio_filter/equalizer.c, the list of the Figma
 * frame), Effects does not give them.
 */
Item {
    id: root

    // Properties

    //! the SettingsData row
    property var spec

    //! the bands are shown (owned by the page: it opens the panel for a search result)
    property bool expanded: false

    //! the user pressed Show / Close equalizer
    signal toggleExpanded()

    //! the frequencies of the 10 bands of the filter
    readonly property var frequencies: ["60 Hz", "170 Hz", "310 Hz", "600 Hz", "1 kHz", "3 kHz",
                                        "6 kHz", "12 kHz", "14 kHz", "16 kHz"]

    //! -20 .. 20 dB, the range of equalizer-preamp and of the bands
    readonly property real minDb: preampSetting && preampSetting.min !== undefined ? preampSetting.min : -20
    readonly property real maxDb: preampSetting && preampSetting.max !== undefined ? preampSetting.max : 20

    readonly property var preampSetting: RedesignSettings.item("equalizer-preamp")

    // [{value, label}] of the presets, with "Custom" while a band was edited by hand
    readonly property var presetChoices: {
        const choices = Effects.equalizerPresets.map(id => ({ value: id, label: Effects.equalizerPresetLabel(id) }))
        if (Effects.equalizerPreset === "custom")
            choices.push({ value: "custom", label: qsTr("Custom") })
        return choices
    }

    // Settings

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight + 2 * RedesignStyle.spacingXS

    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("Equalizer")

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    // a vertical band slider: the value is written on release (`edited`); from/to are set by the user
    // (an inline component does not see the ids of this file)
    component BandSlider: T.Slider {
        id: band

        property string label
        property string caption

        // the value of the user's pick, not stored yet
        property real pending: 0
        property bool picking: false

        signal edited(real newValue)

        function commit() {
            commitTimer.stop()
            if (!band.picking)
                return
            band.picking = false
            band.edited(band.pending)
        }

        orientation: Qt.Vertical
        stepSize: 0.5
        snapMode: T.Slider.SnapAlways

        implicitWidth: VLCStyle.dp(36, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(160, VLCStyle.scale)

        focusPolicy: Qt.StrongFocus

        Accessible.role: Accessible.Slider
        Accessible.name: label
        Accessible.onIncreaseAction: band.increase()
        Accessible.onDecreaseAction: band.decrease()

        onMoved: {
            band.pending = band.value
            band.picking = true
            if (!band.pressed)
                commitTimer.restart()
        }

        onPressedChanged: {
            if (!band.pressed)
                band.commit()
        }

        onActiveFocusChanged: {
            if (!band.activeFocus)
                band.commit()
        }

        Timer {
            id: commitTimer

            // the keyboard steps by repeats: write when it paused
            interval: 400

            onTriggered: band.commit()
        }

        readonly property ColorContext colorContext: ColorContext {
            id: bandTheme

            colorSet: ColorContext.Slider

            enabled: band.enabled
            focused: band.visualFocus
            hovered: band.hovered
        }

        background: Rectangle {
            x: band.leftPadding + (band.availableWidth - width) / 2
            y: band.topPadding
            width: VLCStyle.dp(16, VLCStyle.scale)
            height: band.availableHeight

            radius: RedesignStyle.radiusS

            color: bandTheme.bg.primary
            border.width: VLCStyle.dp(2, VLCStyle.scale)
            border.color: bandTheme.border

            // the filled part, from the bottom
            Rectangle {
                x: parent.border.width
                width: parent.width - 2 * parent.border.width
                y: parent.height - parent.border.width - height
                height: Math.max(0, (parent.height - 2 * parent.border.width) * band.position)

                radius: Math.max(0, parent.radius - parent.border.width)
                color: bandTheme.fg.primary
            }
        }

        handle: Rectangle {
            x: band.leftPadding + (band.availableWidth - width) / 2
            y: band.topPadding + band.visualPosition * (band.availableHeight - height)

            implicitWidth: VLCStyle.dp(24, VLCStyle.scale)
            implicitHeight: VLCStyle.dp(8, VLCStyle.scale)

            radius: VLCStyle.dp(2, VLCStyle.scale)
            color: bandTheme.accent

            border.width: band.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
            border.color: bandTheme.visualFocus
        }
    }

    ColumnLayout {
        id: layout

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        spacing: RedesignStyle.spacingM

        // the title, the switch and the fold button
        RowLayout {
            Layout.fillWidth: true

            spacing: RedesignStyle.spacingM

            Text {
                Layout.fillWidth: true

                text: root.spec ? root.spec.title : qsTr("Equalizer")
                font.pixelSize: VLCStyle.fontSize_normal
                color: theme.fg.primary
                elide: Text.ElideRight

                Accessible.ignored: true
            }

            Widgets.ButtonExt {
                text: root.expanded ? qsTr("Close equalizer") : qsTr("Show equalizer")

                onClicked: root.toggleExpanded()
            }

            ToggleControl {
                ready: true
                label: qsTr("Equalizer")

                value: Effects.equalizerEnabled

                onEdited: (newValue) => Effects.equalizerEnabled = newValue
            }
        }

        // preset and two-pass
        RowLayout {
            Layout.fillWidth: true

            visible: root.expanded
            spacing: RedesignStyle.spacingM

            Text {
                Layout.fillWidth: true

                text: qsTr("Preset")
                font.pixelSize: VLCStyle.fontSize_normal
                color: theme.fg.primary

                Accessible.ignored: true
            }

            DropdownControl {
                ready: true
                label: qsTr("Equalizer preset")

                choices: root.presetChoices
                value: Effects.equalizerPreset

                onEdited: (newValue) => {
                    // "custom" is the state after a band was edited, not a table to apply
                    if (newValue !== "custom")
                        Effects.applyEqualizerPreset(newValue)
                }
            }
        }

        // the 10 bands
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter

            visible: root.expanded
            spacing: RedesignStyle.spacingS

            Item { Layout.fillWidth: true }

            Repeater {
                model: 10

                ColumnLayout {
                    id: column

                    required property int index

                    Layout.alignment: Qt.AlignTop

                    spacing: RedesignStyle.spacingXS

                    Text {
                        Layout.alignment: Qt.AlignHCenter

                        text: slider.picking ? slider.pending.toFixed(1) : Number(slider.value).toFixed(1)
                        font.pixelSize: VLCStyle.fontSize_small
                        color: theme.fg.secondary

                        Accessible.ignored: true
                    }

                    BandSlider {
                        id: slider

                        Layout.alignment: Qt.AlignHCenter

                        from: root.minDb
                        to: root.maxDb

                        label: qsTr("%1 band, dB").arg(root.frequencies[column.index])

                        onEdited: (newValue) => Effects.setEqualizerBand(column.index, newValue)

                        // follows the stored value, except while the user is picking
                        Binding {
                            target: slider
                            property: "value"
                            value: Math.min(root.maxDb, Math.max(root.minDb,
                                                                 Number(Effects.equalizerBands[column.index] ?? 0)))
                            when: !slider.picking && !slider.pressed
                            restoreMode: Binding.RestoreNone
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter

                        text: root.frequencies[column.index]
                        font.pixelSize: VLCStyle.fontSize_small
                        color: theme.fg.primary

                        Accessible.ignored: true
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        // preamp
        RowLayout {
            Layout.fillWidth: true

            visible: root.expanded
            spacing: RedesignStyle.spacingM

            Text {
                Layout.fillWidth: true

                text: qsTr("Preamp (dB)")
                font.pixelSize: VLCStyle.fontSize_normal
                color: theme.fg.primary

                Accessible.ignored: true
            }

            SliderControl {
                from: root.minDb
                to: root.maxDb
                stepSize: 0.5

                ready: true
                label: qsTr("Equalizer preamp, dB")
                description: root.preampSetting ? root.preampSetting.longText : ""

                value: Effects.equalizerPreamp

                onEdited: (newValue) => Effects.equalizerPreamp = newValue
            }
        }

        // two-pass
        RowLayout {
            Layout.fillWidth: true

            visible: root.expanded
            spacing: RedesignStyle.spacingM

            Text {
                Layout.fillWidth: true

                text: {
                    const setting = RedesignSettings.item("equalizer-2pass")
                    return setting ? setting.text : qsTr("Two-pass")
                }
                font.pixelSize: VLCStyle.fontSize_normal
                color: theme.fg.primary

                Accessible.ignored: true
            }

            ToggleControl {
                ready: true
                label: qsTr("Equalizer two-pass")

                value: Effects.twoPass

                onEdited: (newValue) => Effects.twoPass = newValue
            }
        }
    }
}
