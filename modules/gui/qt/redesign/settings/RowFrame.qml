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
 * @brief The line of a row of a settings page that is not a plain SettingRow (theme, accent,
 * effects...): the name and a caption on the left, the children (a control) on the right. It has
 * the metrics of SettingRow so that the page reads as one list, and its rule for a narrow row
 * (ControlChooser.controlFit): the label keeps 120 dp beside the control, and a row too narrow for
 * that puts the control under the label.
 *
 * The children are one control, or a few that go together (the segments of the theme, the swatches
 * of the accent). They take their own width. A control that was made for a wide row (a list or a
 * slider of 320 dp) is bounded instead: set `controlMinimum` to the narrowest it is usable at and
 * give it `Layout.fillWidth: true`, it then gets what is left to it (never more than its own width
 * nor 55% of the row) and shrinks with the row, as the control of a SettingRow does.
 */
Item {
    id: root

    // Properties

    //! the name of the setting
    property string title

    //! a line under the name, also the Accessible.description of the row
    property string description

    //! the change is only applied by the next start
    property bool restart: false

    //! the controls
    default property alias content: slot.data

    //! The narrowest a bounded control (see above) is usable at, in pixels; 0 when the children are
    //! not bounded and keep their own width
    property real controlMinimum: 0

    // the label keeps this beside the control, or the control goes under it
    readonly property real _minLabel: VLCStyle.dp(120, VLCStyle.scale)

    readonly property bool _bounded: controlMinimum > 0

    readonly property var _fit: ControlChooser.controlFit(root.width, 0, grid.columnSpacing, slot.implicitWidth,
                                                          controlMinimum, _minLabel)

    // the controls are under the label
    readonly property bool _stacked: _bounded ? _fit.stacked
                                              : root.width - slot.implicitWidth - grid.columnSpacing < _minLabel

    // the width of the controls: the bounded ones get what the rule gives, the others their own
    // (less than the row when they are under the label, they shrink to it)
    readonly property real _slotWidth: _bounded ? _fit.width : slot.implicitWidth

    // Settings

    implicitWidth: grid.implicitWidth
    implicitHeight: Math.max(VLCStyle.dp(46, VLCStyle.scale),
                             grid.implicitHeight + 2 * RedesignStyle.spacingXS)

    Accessible.role: Accessible.Grouping
    Accessible.name: title
    Accessible.description: description

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    // the label, then the controls: beside it, or under it in a row that is too narrow (stacked)
    GridLayout {
        id: grid

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        columns: root._stacked ? 1 : 2
        columnSpacing: RedesignStyle.spacingM
        rowSpacing: RedesignStyle.spacingS

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            spacing: 0

            Text {
                Layout.fillWidth: true

                text: root.title
                font.pixelSize: VLCStyle.fontSize_normal
                color: theme.fg.primary
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight

                Accessible.ignored: true
            }

            Text {
                Layout.fillWidth: true

                visible: root.description.length > 0

                text: root.description
                font.pixelSize: VLCStyle.fontSize_small
                color: theme.fg.secondary
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight

                Accessible.ignored: true
            }

            Text {
                Layout.fillWidth: true

                visible: root.restart

                text: qsTr("Restart required")
                font.pixelSize: VLCStyle.fontSize_small
                color: theme.fg.secondary
                elide: Text.ElideRight

                Accessible.ignored: true
            }
        }

        RowLayout {
            id: slot

            Layout.alignment: root._stacked ? (Qt.AlignVCenter | Qt.AlignLeft) : Qt.AlignVCenter

            // beside the label: the width of the controls. Under it: up to that width, less when
            // the row is narrower (the controls that can shrink do)
            Layout.fillWidth: root._stacked
            Layout.preferredWidth: root._slotWidth
            Layout.maximumWidth: root._slotWidth

            spacing: RedesignStyle.spacingS
        }
    }
}
