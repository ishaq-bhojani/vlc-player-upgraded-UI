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
import QtCore as QtCore

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs
import VLC.Menus
import VLC.Util
import VLC.Redesign

/**
 * @brief The rail: the left column of the window, a column of icons (collapsed) or of
 * icons with labels (expanded). Selecting an entry navigates with History, the "add" entry
 * opens the open dialog.
 *
 * The expanded state is persisted. The entries and their mapping to navigation paths are
 * defined by RailModel. Below a divider, the rail lists the items pinned with PinStore:
 * activating one opens it, the context menu unpins it.
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

    // Functions

    // the glyph of a pinned item
    function pinIcon(kind: string): string {
        switch (kind) {
        case "playlist":
            return VLCIcons.playlist
        case "stream":
            return VLCIcons.stream
        default:
            return VLCIcons.ic_fluent_folder_open_24_regular
        }
    }

    // Opens a pinned item with the views of the network browser (folders and streams, by
    // `tree`) and of the playlists of the media library (by `parentId`)
    function openPin(pin: var) {
        if (pin.kind === "playlist")
            History.push(["video", "playlists", "list"], { parentId: pin.target, title: pin.label })
        else
            History.push(["network", "browse"], { tree: pin.target })
    }

    // shows the context menu of the pinned item pinId at the global position globalPos
    function showPinMenu(pinId: string, globalPos: point) {
        pinMenu.pinId = pinId
        pinMenu.popup(globalPos, [qsTr("Unpin")])
    }

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

    StringListMenu {
        id: pinMenu

        property string pinId

        ctx: MainCtx

        onSelected: (index, _) => {
            if (index === 0)
                PinStore.unpin(pinMenu.pinId)
        }
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
                selected: modelData.id === railModel.selectedId(root.viewPath)

                onClicked: {
                    if (modelData.id === "add")
                        DialogsProvider.simpleOpenDialog()
                    else
                        History.push(modelData.path)
                }
            }
        }

        // separates the fixed entries from the pins
        Rectangle {
            visible: pinRepeater.count > 0

            width: column.width
            height: VLCStyle.border

            color: theme.separator
        }

        Repeater {
            id: pinRepeater

            model: PinStore.items

            RailButton {
                id: pinButton

                required property var modelData

                width: column.width

                icon: root.pinIcon(modelData.kind)
                label: modelData.label
                showLabel: root.expanded
                description: modelData.label

                onClicked: root.openPin(modelData)

                Keys.onMenuPressed: root.showPinMenu(modelData.id, mapToGlobal(width / 2, height / 2))

                TapHandler {
                    acceptedButtons: Qt.RightButton

                    onTapped: (eventPoint, button) => root.showPinMenu(pinButton.modelData.id,
                                                                       pinButton.mapToGlobal(eventPoint.position))
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

        contentItem: RowLayout {
            spacing: RedesignStyle.spacingS

            Widgets.IconLabel {
                Layout.preferredWidth: RedesignStyle.railWidthCollapsed - 2 * RedesignStyle.spacingS
                Layout.fillHeight: true

                text: button.icon
                color: (button.selected || button.hovered)
                       ? itemTheme.fg.highlight
                       : itemTheme.fg.primary
            }

            Text {
                visible: button.showLabel
                Layout.fillWidth: true
                Layout.fillHeight: true

                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: button.label
                font.pixelSize: VLCStyle.fontSize_normal
                color: button.selected ? itemTheme.fg.highlight : itemTheme.fg.primary
            }
        }
    }
}
