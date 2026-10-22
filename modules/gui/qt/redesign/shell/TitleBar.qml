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
import QtQuick.Layouts
import QtQuick.Templates as T
import QtQuick.Window

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Style
import VLC.Util
import VLC.Redesign

/**
 * @brief The title bar of the redesign window, left to right: the menu button, the title
 * (the folder of the playing media, else the title of the current page; clicking the folder
 * requests the library on it), the library panel toggle, the fullscreen button and the
 * window buttons.
 *
 * With client side decorations the bar is the drag area of the window (double click
 * maximises, right click opens the window menu) and hosts the window buttons of VLC
 * (CSDWindowButtonSet), which keeps the snap layouts of Windows 11. Without them only the
 * buttons are shown.
 */
FocusScope {
    id: root

    // Properties

    // title shown when no media with a folder is playing
    property string pageTitle: MainCtx.productName

    // whether the library is shown in the whole window, the browse state (checked state of the library button)
    property bool libraryActive: false

    // the folder of the playing media (file:// URL), "" if there is none
    readonly property string folderUrl: Player.isStarted ? _parentUrl(Player.url.toString()) : ""

    readonly property string folderName: Player.isStarted ? MediaText.folderName(Player.url.toString()) : ""

    // true when the window is decorated by the interface
    readonly property bool showCSD: MainCtx.clientSideDecoration
                                    && (MainCtx.intfMainWindow.visibility !== Window.FullScreen)

    // the menu button was reached with the keyboard (it shows its focus ring)
    readonly property bool menuButtonKeyboardFocus: menuButton.visualFocus

    // Functions

    // gives the keyboard focus to the menu button (after its menu closed)
    function focusMenuButton() {
        menuButton.forceActiveFocus(Qt.TabFocusReason)
    }

    // the URL of the folder of a file:// URL, "" for any other URL
    function _parentUrl(url: string): string {
        if (!url || url.slice(0, 7).toLowerCase() !== "file://")
            return ""

        const noQuery = url.split(/[?#]/)[0]
        const slash = noQuery.lastIndexOf("/")
        // keep the slash of "file:///"
        return (slash > 8) ? noQuery.slice(0, slash) : ""
    }

    // Signals

    // the menu button was activated, globalPos is where to open the menu
    signal menuRequested(point globalPos)

    // the title (the folder of the playing media) was activated
    signal libraryRequested(string folderUrl)

    // the library panel toggle was activated
    signal libraryToggleRequested()

    // Settings

    implicitHeight: RedesignStyle.titleBarHeight

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Title bar")
    AccessibleCompat.id: "redesignTitleBar"

    // Children

    ColorContext {
        id: theme

        colorSet: ColorContext.Window
    }

    Rectangle {
        anchors.fill: parent

        color: theme.bg.primary
    }

    // drag and double click in the empty parts of the bar, under the buttons
    Loader {
        anchors.fill: parent

        z: -1

        active: root.showCSD
        source: "qrc:///qt/qml/VLC/Widgets/CSDTitlebarTapNDrapHandler.qml"
    }

    RowLayout {
        anchors {
            left: parent.left
            right: csdButtons.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: RedesignStyle.spacingS
            rightMargin: RedesignStyle.spacingS
        }

        spacing: RedesignStyle.spacingXS

        TitleButton {
            id: menuButton

            text: VLCIcons.rd_menu
            description: qsTr("Menu")

            onClicked: root.menuRequested(menuButton.mapToGlobal(0, menuButton.height))
        }

        T.AbstractButton {
            id: titleButton

            // the title is a button only while it names the folder of the playing media
            readonly property bool isFolder: root.folderName !== ""

            Layout.fillHeight: true
            Layout.maximumWidth: root.width / 3

            padding: RedesignStyle.spacingS
            hoverEnabled: true
            enabled: isFolder

            Accessible.name: isFolder ? qsTr("Show folder %1 in the library").arg(root.folderName)
                                      : root.pageTitle
            Accessible.onPressAction: titleButton.clicked()

            onClicked: root.libraryRequested(root.folderUrl)

            T.ToolTip.visible: isFolder && (hovered || visualFocus)
            T.ToolTip.delay: VLCStyle.delayToolTipAppear
            T.ToolTip.text: qsTr("Show in the library")

            ColorContext {
                id: titleTheme

                colorSet: ColorContext.Item

                enabled: titleButton.enabled
                focused: titleButton.visualFocus
                hovered: titleButton.hovered
                pressed: titleButton.down
            }

            background: Rectangle {
                radius: RedesignStyle.radiusS

                visible: titleButton.isFolder && (titleButton.hovered || titleButton.visualFocus)
                color: titleTheme.bg.highlight

                border.width: titleButton.visualFocus ? VLCStyle.focus_border : 0
                border.color: titleTheme.visualFocus
            }

            contentItem: RowLayout {
                spacing: RedesignStyle.spacingS

                Widgets.IconLabel {
                    visible: titleButton.isFolder

                    text: VLCIcons.rd_folder
                    font.pixelSize: VLCStyle.icon_normal
                    color: theme.fg.primary
                }

                Text {
                    Layout.fillWidth: true

                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    text: titleButton.isFolder ? root.folderName : root.pageTitle
                    font.pixelSize: VLCStyle.fontSize_normal
                    color: titleButton.isFolder ? theme.fg.primary : theme.fg.secondary
                }
            }
        }

        // pushes the remaining buttons to the right
        Item {
            Layout.fillWidth: true
        }

        TitleButton {
            text: VLCIcons.rd_sidebar
            description: root.libraryActive ? qsTr("Back to the player") : qsTr("Show the library")
            checked: root.libraryActive

            onClicked: root.libraryToggleRequested()
        }

        TitleButton {
            text: (MainCtx.intfMainWindow.visibility === Window.FullScreen) ? VLCIcons.defullscreen
                                                                            : VLCIcons.fullscreen
            description: (MainCtx.intfMainWindow.visibility === Window.FullScreen) ? qsTr("Exit fullscreen")
                                                                                   : qsTr("Fullscreen")

            onClicked: MainCtx.toggleInterfaceFullScreen()
        }
    }

    Loader {
        id: csdButtons

        anchors {
            right: parent.right
            top: parent.top
        }

        height: root.height
        active: root.showCSD
        source: VLCStyle.palette.hasCSDImage
                ? "qrc:///qt/qml/VLC/Widgets/CSDThemeButtonSet.qml"
                : "qrc:///qt/qml/VLC/Widgets/CSDWindowButtonSet.qml"
    }

    // One icon button of the bar
    component TitleButton: Widgets.IconToolButton {
        Layout.fillHeight: true
        Layout.preferredWidth: RedesignStyle.titleBarHeight

        font.pixelSize: VLCStyle.icon_normal
    }
}
