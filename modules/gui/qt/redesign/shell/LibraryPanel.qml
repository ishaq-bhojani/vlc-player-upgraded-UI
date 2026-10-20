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
import QtCore as QtCore

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.Redesign

/**
 * @brief The library panel: a resizable drawer on the left of the stage that shows the page of
 * the library the rail selected, and the header of that page (back, title).
 *
 * The page itself is not created here: the shell owns it and puts it into `body` or into the
 * Stage (the page is one item that moves, so it keeps its scroll position and selection).
 *
 * `mode` (from ShellStates.panelMode and state):
 *   - "docked":  a column beside the stage, resizable with the handle on its right edge
 *   - "overlay": the same column drawn above the stage (the shell adds the scrim and closes the
 *                panel on an outside click)
 *   - "strip":   browse state, only the header, as wide as the parent; the page is in the Stage
 *   - "hidden":  nothing
 *
 * The width is persisted.
 */
FocusScope {
    id: root

    // Properties

    property string mode: "hidden"

    // title of the header: the page that is shown
    property string title

    // where the shell puts the page (docked and overlay modes)
    readonly property alias body: bodyItem

    // the width of the docked / overlay column, within the limits of the design
    readonly property int panelWidth: Helpers.clamp(persisted.panelWidth,
                                                    RedesignStyle.panelWidthMin,
                                                    RedesignStyle.panelWidthMax)

    readonly property bool strip: root.mode === "strip"

    // Functions

    /**
     * Shows the folder `folderUrl` (file:// URL) in the browse page of the network. Does nothing
     * (but a warning) when the folder can not be browsed.
     */
    function openAt(folderUrl: string) {
        // MediaText.folderName gives the folder of a file URL: ask for the folder of a file inside
        const name = MediaText.folderName(folderUrl.replace(/\/+$/, "") + "/-")
        const tree = PinNavigation.networkTree(folderUrl, name)
        if (tree)
            History.push(["network", "browse"], { tree: tree })
        else
            console.warn("LibraryPanel: can not open the folder", folderUrl)
    }

    // Signals

    // the "browse" button of the header was activated: show the library in the whole stage
    signal browseRequested()

    // Settings

    visible: root.mode !== "hidden"

    width: strip ? (parent ? parent.width : 0) : panelWidth
    implicitHeight: RedesignStyle.titleBarHeight

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Library")
    AccessibleCompat.id: "libraryPanel"

    // Children

    QtCore.Settings {
        id: persisted

        category: "redesign"

        property int panelWidth: RedesignStyle.panelWidthDefault
    }

    ColorContext {
        id: theme

        colorSet: ColorContext.Window
    }

    ColorContext {
        id: viewTheme

        colorSet: ColorContext.View
    }

    // The strip (browse state) is the top of the page: the background of the page, the window
    // paints none (see Stage.qml). Docked, the panel is flush with the rail, the bars and the
    // window: square corners. As an overlay over the stage its free side, the right one, is
    // rounded (the square rectangle below keeps the left corners square).
    Rectangle {
        anchors.fill: parent

        color: root.strip ? viewTheme.bg.primary : theme.bg.secondary

        radius: (root.mode === "overlay") ? RedesignStyle.radiusM : 0

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }

            width: parent.radius
            visible: parent.radius > 0

            color: parent.color
        }
    }

    RowLayout {
        id: header

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: RedesignStyle.spacingS
            rightMargin: RedesignStyle.spacingS
        }

        height: RedesignStyle.titleBarHeight
        spacing: RedesignStyle.spacingXS

        Widgets.IconToolButton {
            Layout.preferredWidth: RedesignStyle.titleBarHeight
            Layout.fillHeight: true

            font.pixelSize: VLCStyle.icon_normal
            text: VLCIcons.back
            description: qsTr("Previous")
            enabled: !History.previousEmpty

            onClicked: History.previous()
        }

        Text {
            Layout.fillWidth: true

            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            text: root.title
            font.pixelSize: VLCStyle.fontSize_large
            color: theme.fg.primary
        }

        Widgets.IconToolButton {
            Layout.preferredWidth: RedesignStyle.titleBarHeight
            Layout.fillHeight: true

            // watching: the panel is a side view, this shows the library in the whole stage
            visible: !root.strip

            font.pixelSize: VLCStyle.icon_normal
            text: VLCIcons.rd_library
            description: qsTr("Browse the library")

            onClicked: root.browseRequested()
        }
    }

    Item {
        id: bodyItem

        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            bottom: parent.bottom
        }

        visible: !root.strip
    }

    Widgets.HorizontalResizeHandle {
        id: resizeHandle

        anchors {
            top: parent.top
            bottom: parent.bottom
            // straddles the right edge
            horizontalCenter: parent.right
        }

        visible: !root.strip

        atRight: true
        currentWidth: root.panelWidth
        minimumWidth: RedesignStyle.panelWidthMin
        maximumWidth: RedesignStyle.panelWidthMax

        onRequestedWidthChanged: persisted.panelWidth = requestedWidth
    }
}
