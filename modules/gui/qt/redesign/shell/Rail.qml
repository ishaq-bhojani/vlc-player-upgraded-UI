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
import QtQuick.Templates as T
import QtCore as QtCore

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs
import VLC.Util
import VLC.Redesign

/**
 * @brief The rail: the left column of the window, a column of icons (collapsed) or of
 * icons with labels (expanded). Selecting an entry navigates with History, the "add" entry
 * opens the open dialog.
 *
 * The expanded state is persisted. The entries and their mapping to navigation paths are
 * defined by RailModel.
 */
FocusScope {
    id: root

    // Properties

    // the view path to highlight
    property var viewPath: History.viewPath

    property alias expanded: persisted.expanded

    readonly property alias model: railModel

    implicitWidth: root.expanded ? RedesignStyle.railWidthExpanded : RedesignStyle.railWidthCollapsed
    implicitHeight: column.implicitHeight + 2 * RedesignStyle.spacingS

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Navigation")

    // Children

    RailModel {
        id: railModel

        hasMediaLibrary: MainCtx.mediaLibraryAvailable
    }

    QtCore.Settings {
        id: persisted

        category: "redesign"

        property bool expanded: false
    }

    ColorContext {
        id: theme

        colorSet: ColorContext.Window
    }

    Rectangle {
        anchors.fill: parent

        radius: RedesignStyle.radiusM
        color: theme.bg.secondary
    }

    Column {
        id: column

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: RedesignStyle.spacingS
        }

        spacing: RedesignStyle.spacingXS

        RailButton {
            width: column.width

            icon: VLCIcons.panel_left
            label: root.expanded ? qsTr("Collapse") : qsTr("Expand")
            showLabel: false
            description: root.expanded ? qsTr("Collapse the sidebar") : qsTr("Expand the sidebar")

            onClicked: root.expanded = !root.expanded
        }

        Repeater {
            id: repeater

            model: railModel.visibleItems()

            RailButton {
                required property var modelData

                width: column.width

                icon: VLCIcons[modelData.icon]
                label: modelData.label
                showLabel: root.expanded
                description: modelData.label
                selected: railModel.items.indexOf(modelData) === railModel.indexForPath(root.viewPath)

                onClicked: {
                    if (modelData.id === "add")
                        DialogsProvider.simpleOpenDialog()
                    else
                        History.push(modelData.path)
                }
            }
        }
    }

    // One entry of the rail
    component RailButton: T.AbstractButton {
        id: button

        property string icon
        property string label
        property string description
        property bool showLabel: true
        property bool selected: false

        implicitHeight: RedesignStyle.railWidthCollapsed - 2 * RedesignStyle.spacingS
        padding: 0
        hoverEnabled: true

        Accessible.name: description
        Accessible.onPressAction: button.clicked()

        ColorContext {
            id: itemTheme

            colorSet: ColorContext.Item

            enabled: button.enabled
            focused: button.visualFocus
            hovered: button.hovered
            pressed: button.down
        }

        T.ToolTip.visible: !button.showLabel && (button.hovered || button.visualFocus)
        T.ToolTip.delay: VLCStyle.delayToolTipAppear
        T.ToolTip.text: button.description

        background: Rectangle {
            radius: RedesignStyle.radiusS

            visible: button.selected || button.hovered || button.visualFocus
            color: itemTheme.bg.highlight

            border.width: button.visualFocus ? VLCStyle.focus_border : 0
            border.color: itemTheme.visualFocus
        }

        contentItem: Row {
            spacing: RedesignStyle.spacingS

            Widgets.IconLabel {
                width: RedesignStyle.railWidthCollapsed - 2 * RedesignStyle.spacingS
                height: parent.height

                text: button.icon
                color: (button.selected || button.hovered)
                       ? itemTheme.fg.highlight
                       : itemTheme.fg.primary
            }

            Text {
                visible: button.showLabel
                height: parent.height
                width: parent.width - x

                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: button.label
                font.pixelSize: VLCStyle.fontSize_normal
                color: button.selected ? itemTheme.fg.highlight : itemTheme.fg.primary
            }
        }
    }
}
