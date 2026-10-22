/*****************************************************************************
 * Copyright (C) 2026 Vireo contributors
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
import QtCore as QtCore

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.Redesign

/**
 * @brief The right panel: a resizable column on the right of the stage that shows the play queue
 * (mode "queue") or, later, the watch sidebar (mode "sidebar"; its content is not there yet).
 *
 * `mode` is "" (closed), "queue" or "sidebar"; `toggle(m)` opens `m`, or closes the panel when `m`
 * is the open one. The shell gives the room (`freeWidth`, see RightPanelLogic.layout): the panel is
 * docked beside the stage (`slotWidth` is the room it takes in the layout) while the stage keeps
 * `stageMinWidth`, else (or with `forceOverlay`) it is an overlay on the stage (`slotWidth` is 0),
 * never over all of it. The width the user dragged is persisted.
 *
 * Escape (or Backspace, like every Navigation.cancelAction) closes the panel; the shell moves the
 * keyboard (RedesignInterface._focusState) when `modeChanged`.
 */
FocusScope {
    id: root

    // Properties

    property string mode: ""

    // the shell has no room beside the stage (the immersive state: the stage is the whole window):
    // the panel is an overlay whatever the room
    property bool forceOverlay: false

    // the width the panel and the stage share, given by the shell
    property real freeWidth: 0

    // what the stage keeps at least beside a docked panel
    property real stageMinWidth: MainCtx.dp(480, RedesignStyle.scale)

    // the panel is on screen
    readonly property bool shown: mode !== ""

    // docked beside the stage (false) or over it (true)
    readonly property bool overlay: forceOverlay || placement.overlay

    // the width of the panel, within the limits of the design and the room
    readonly property int panelWidth: placement.width

    // the room the panel takes in the layout: nothing while it is hidden or an overlay
    readonly property int slotWidth: (shown && !overlay) ? panelWidth : 0

    // what the panel shows (null while closed or for the sidebar)
    readonly property Item content: contentLoader.item

    readonly property var placement: RightPanelLogic.layout(persisted.rightPanelWidth,
                                                            RedesignStyle.panelWidthMin,
                                                            RedesignStyle.panelWidthMax,
                                                            freeWidth,
                                                            stageMinWidth,
                                                            0.75)

    // Functions

    function toggle(requested: string) {
        mode = RightPanelLogic.toggled(mode, requested)
    }

    function close() {
        mode = ""
    }

    // puts the keyboard in the content
    function focusContent() {
        forceActiveFocus(Qt.TabFocusReason)
    }

    // Settings

    visible: shown
    width: panelWidth

    Accessible.role: Accessible.Pane
    Accessible.name: (mode === "queue") ? qsTr("Queue") : qsTr("Sidebar")
    AccessibleCompat.id: "rightPanel"

    // Events

    onModeChanged: {
        const normal = RightPanelLogic.normalized(mode)
        if (mode !== normal)
            mode = normal
    }

    Keys.onEscapePressed: (event) => {
        root.close()
        event.accepted = true
    }

    // Children

    QtCore.Settings {
        id: persisted

        category: "redesign"

        property int rightPanelWidth: RedesignStyle.panelWidthDefault
    }

    ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    Rectangle {
        anchors.fill: parent

        color: theme.bg.primary
    }

    Loader {
        id: contentLoader

        anchors.fill: parent

        focus: true
        active: root.mode === "queue"

        sourceComponent: QueuePanel {
            onCloseRequested: root.close()
        }
    }

    Widgets.HorizontalResizeHandle {
        id: resizeHandle

        anchors {
            top: parent.top
            bottom: parent.bottom
            // straddles the left edge
            horizontalCenter: parent.left
        }

        atRight: false
        currentWidth: root.panelWidth
        minimumWidth: RedesignStyle.panelWidthMin
        maximumWidth: RedesignStyle.panelWidthMax

        onRequestedWidthChanged: persisted.rightPanelWidth = requestedWidth
    }
}
