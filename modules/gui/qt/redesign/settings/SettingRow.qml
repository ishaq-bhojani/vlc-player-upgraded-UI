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
 * @brief One line of a settings page: the name of a VLC configuration item, an info button
 * with its long description, and the control that fits its type.
 *
 * `key` is the configuration key (RedesignSettings.item(key)); a key that does not exist hides
 * the row (`item` is null). The control comes from ControlChooser.controlFor() with `hint`:
 * "slider" for a range shown as a slider, "choices" for an option whose values come from its
 * plugin, "password" for a secret. The control shows `item.value` (bound, nothing is copied) and
 * a change made in it is stored with `item.value = v`.
 *
 * `item.choices` is only read when the control is a dropdown: for an option that is not a
 * Choice reading it may load the plugin that declares the option, and when that gives no
 * values the row falls back to the plain control of the type.
 *
 * Every control this row loads MUST declare `property bool ready` (see controls/): the value
 * Binding below waits for `ready === true`, so a control without the property never receives
 * its value, and no error says so. Keep that for any control added to ControlChooser.
 */
Item {
    id: root

    // Properties

    //! the configuration key of the setting
    property string key

    //! "slider", "choices", "password" or empty, see ControlChooser.controlFor()
    property string hint

    //! a file dialog is available for a path setting: its Browse button is shown
    property bool canBrowse: false

    //! the SettingItem of `key`, null if there is none
    readonly property var item: key.length > 0 ? RedesignSettings.item(key) : null

    //! the file name of the control, empty if the setting has none (a hotkey)
    readonly property string controlFile: {
        if (!item)
            return ""

        const hasRange = ControlChooser.hasRange(item.min, item.max)
        const wanted = ControlChooser.controlFor(item.type, hasRange, hint)
        if (wanted !== "DropdownControl.qml" || item.type === ControlChooser.type.Choice)
            return wanted

        // the values of a plugin: nothing to choose from means a plain control
        return item.choices.length > 0 ? wanted : ControlChooser.controlFor(item.type, hasRange, "")
    }

    //! the control, null while there is none
    readonly property var control: loader.item

    //! the user asked to browse for the path of `item` (a Browse button press, see canBrowse)
    signal browseRequested(var setting)

    // Private

    readonly property string _description: item ? item.longText : ""

    // the info tooltip does not grow wider than this, longer lines wrap
    readonly property real _tipMaxWidth: VLCStyle.dp(320, VLCStyle.scale)

    // Settings

    visible: item !== null

    implicitWidth: row.implicitWidth
    implicitHeight: visible ? Math.max(VLCStyle.dp(46, VLCStyle.scale),
                                       row.implicitHeight + 2 * RedesignStyle.spacingXS)
                            : 0

    Accessible.role: Accessible.Grouping
    Accessible.name: item ? item.text : ""

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    RowLayout {
        id: row

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        spacing: RedesignStyle.spacingM

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            spacing: 0

            Text {
                Layout.fillWidth: true

                text: root.item ? root.item.text : ""
                font.pixelSize: VLCStyle.fontSize_normal
                color: theme.fg.primary
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight

                Accessible.ignored: true
            }

            // the change is only applied by the next start
            Text {
                Layout.fillWidth: true

                visible: root.item !== null && root.item.requiresRestart

                text: qsTr("Restart required")
                font.pixelSize: VLCStyle.fontSize_small
                color: theme.fg.secondary
                elide: Text.ElideRight

                Accessible.ignored: true
            }
        }

        // Figma "i": the long description, on hover. Not a tab stop (the description is also the
        // Accessible.description of the control): one stop per row.
        T.AbstractButton {
            id: infoButton

            Layout.alignment: Qt.AlignVCenter

            visible: root._description.length > 0

            hoverEnabled: true
            focusPolicy: Qt.NoFocus
            activeFocusOnTab: false

            implicitWidth: VLCStyle.icon_normal
            implicitHeight: VLCStyle.icon_normal

            Accessible.role: Accessible.Button
            Accessible.name: qsTr("More information")

            contentItem: Widgets.IconLabel {
                text: VLCIcons.info
                font.pixelSize: VLCStyle.icon_normal
                color: infoButton.hovered ? theme.fg.primary : theme.fg.secondary
            }

            Widgets.ToolTipExt {
                id: infoTip

                visible: infoButton.hovered
                delay: VLCStyle.delayToolTipAppear
                text: root._description

                // wraps at _tipMaxWidth (the stock tooltip only wraps at the window width)
                contentItem: Item {
                    implicitWidth: tipText.width
                    implicitHeight: tipText.implicitHeight

                    Text {
                        id: tipText

                        width: Math.min(tipMetrics.width, root._tipMaxWidth)

                        text: infoTip.text
                        font: infoTip.font
                        color: tipTheme.fg.primary
                        wrapMode: Text.Wrap
                    }

                    TextMetrics {
                        id: tipMetrics

                        font: infoTip.font
                        text: infoTip.text
                    }

                    ColorContext {
                        id: tipTheme

                        colorSet: ColorContext.Tooltip
                    }
                }
            }
        }

        Loader {
            id: loader

            Layout.alignment: Qt.AlignVCenter

            source: root.controlFile

            onLoaded: {
                const control = loader.item
                const setting = root.item

                control.label = setting.text
                control.description = setting.longText

                switch (root.controlFile) {
                case "SliderControl.qml":
                    control.from = setting.min
                    control.to = setting.max
                    control.stepSize = ControlChooser.sliderStep(setting.type === ControlChooser.type.Float,
                                                                 setting.min, setting.max)
                    break
                case "NumberControl.qml":
                    control.isFloat = setting.type === ControlChooser.type.Float
                    // undefined when the option has no range: no bound
                    control.from = setting.min
                    control.to = setting.max
                    control.stepSize = ControlChooser.sliderStep(control.isFloat,
                                                                 setting.min ?? 0, setting.max ?? 100)
                    break
                case "DropdownControl.qml":
                    control.choices = setting.choices
                    break
                case "TextControl.qml":
                    control.password = Qt.binding(() => root.hint === "password")
                    break
                case "PathControl.qml":
                    control.canBrowse = Qt.binding(() => root.canBrowse)
                    break
                }

                // the constants are in: now the value can be applied against the right range
                control.ready = true
            }
        }
    }

    // the control shows the setting: no copy of the value that could go stale
    Binding {
        target: loader.item
        property: "value"
        value: root.item ? root.item.value : undefined
        when: loader.item !== null && loader.item.ready === true && root.item !== null
    }

    // and what the user does in it is stored in the setting
    Connections {
        target: loader.item

        ignoreUnknownSignals: true

        function onEdited(newValue) {
            if (root.item)
                root.item.value = newValue
        }

        function onBrowseRequested() {
            root.browseRequested(root.item)
        }
    }
}
