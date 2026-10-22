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

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Redesign

/**
 * @brief The sidebar of the settings modal: the search field, the three groups of pages (App,
 * Media, System) and the link to the QWidgets advanced preferences.
 *
 * Up and Down in the list select the previous or next page (the group names are skipped), Home
 * and End the first and the last. Down in the search field goes to the list. Esc in the field
 * clears it before it can close the modal.
 */
FocusScope {
    id: root

    // Properties

    //! the id of the page shown (SettingsData.pages)
    property string currentPage

    //! the text of the search field
    readonly property alias searchText: field.text

    //! the modal shows the results of the search: Down and Enter go to them
    property bool searching: false

    //! [{type: "group" | "page", id, title}], the rows of the list
    readonly property var items: {
        const list = []
        for (const group of SettingsData.groups) {
            list.push({ type: "group", id: group.id, title: group.title })
            for (const id of group.pages)
                list.push({ type: "page", id: id, title: SettingsData.pageById(id).title })
        }
        return list
    }

    // Signals

    //! the user chose a page
    signal pageSelected(string page)

    //! the user asked for the QWidgets advanced preferences
    signal advancedRequested()

    //! the user wants to move to the results of the search
    signal resultsRequested()

    // Functions

    function clearSearch() {
        field.text = ""
    }

    function setSearch(text: string) {
        field.text = text
    }

    function focusSearch() {
        field.forceActiveFocus(Qt.ShortcutFocusReason)
    }

    function focusList() {
        list.forceActiveFocus(Qt.TabFocusReason)
    }

    // moves the selection by `step` pages
    function _step(step: int) {
        const pages = SettingsData.pageIds
        const index = pages.indexOf(currentPage)
        const target = Math.max(0, Math.min(pages.length - 1, (index < 0 ? 0 : index) + step))
        if (pages[target] !== currentPage)
            pageSelected(pages[target])
    }

    // Settings

    implicitWidth: VLCStyle.dp(220, VLCStyle.scale)

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Settings sections")

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    ColumnLayout {
        anchors.fill: parent

        spacing: RedesignStyle.spacingM

        Widgets.TextFieldExt {
            id: field

            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)

            radius: RedesignStyle.radiusM
            selectByMouse: true

            placeholderText: qsTr("Search settings")

            Accessible.role: Accessible.EditableText
            Accessible.name: qsTr("Search settings")

            Keys.onDownPressed: (event) => {
                if (root.searching)
                    root.resultsRequested()
                else
                    root.focusList()
                event.accepted = true
            }

            onAccepted: {
                if (root.searching)
                    root.resultsRequested()
            }

            // the first Esc clears the search, the next one closes the modal. The release of the
            // Esc that cleared it is taken here too, or it would close the modal at once.
            property bool escHandled: false

            Keys.onEscapePressed: (event) => {
                if (field.text.length > 0) {
                    field.text = ""
                    field.escHandled = true
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }

            Keys.onReleased: (event) => {
                if (event.key === Qt.Key_Escape && field.escHandled) {
                    field.escHandled = false
                    event.accepted = true
                }
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true

            focus: true
            activeFocusOnTab: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: root.items

            Accessible.role: Accessible.List
            Accessible.name: qsTr("Settings pages")

            Keys.onUpPressed: (event) => {
                root._step(-1)
                event.accepted = true
            }

            Keys.onDownPressed: (event) => {
                root._step(1)
                event.accepted = true
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Home) {
                    root._step(-100)
                    event.accepted = true
                } else if (event.key === Qt.Key_End) {
                    root._step(100)
                    event.accepted = true
                }
            }

            delegate: Item {
                id: cell

                required property var modelData

                readonly property bool isPage: modelData.type === "page"
                readonly property bool current: isPage && modelData.id === root.currentPage

                width: ListView.view ? ListView.view.width : 0
                height: isPage ? VLCStyle.dp(36, VLCStyle.scale) : VLCStyle.dp(32, VLCStyle.scale)

                Accessible.role: isPage ? Accessible.ListItem : Accessible.StaticText
                Accessible.name: modelData.title
                Accessible.selected: current
                Accessible.onPressAction: if (isPage) root.pageSelected(modelData.id)

                readonly property ColorContext colorContext: ColorContext {
                    id: cellTheme

                    colorSet: ColorContext.Item

                    focused: cell.current
                    hovered: mouse.containsMouse && cell.isPage
                }

                // the group name
                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: RedesignStyle.spacingM
                        bottom: parent.bottom
                        bottomMargin: RedesignStyle.spacingXS
                    }

                    visible: !cell.isPage

                    text: cell.modelData.title.toUpperCase()
                    font.pixelSize: VLCStyle.fontSize_small
                    font.weight: Font.DemiBold
                    color: theme.fg.secondary
                    elide: Text.ElideRight

                    Accessible.ignored: true
                }

                // a page
                Rectangle {
                    anchors.fill: parent

                    visible: cell.isPage

                    radius: RedesignStyle.radiusM
                    color: cellTheme.bg.primary

                    border.width: (cell.current && list.activeFocus) ? VLCStyle.dp(2, VLCStyle.scale) : 0
                    border.color: cellTheme.visualFocus

                    Text {
                        anchors {
                            fill: parent
                            leftMargin: RedesignStyle.spacingM
                            rightMargin: RedesignStyle.spacingM
                        }

                        text: cell.modelData.title
                        font.pixelSize: VLCStyle.fontSize_normal
                        font.weight: cell.current ? Font.DemiBold : Font.Normal
                        color: cellTheme.fg.primary
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight

                        Accessible.ignored: true
                    }
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent

                    enabled: cell.isPage
                    hoverEnabled: true

                    onClicked: {
                        root.pageSelected(cell.modelData.id)
                        list.forceActiveFocus(Qt.MouseFocusReason)
                    }
                }
            }
        }

        Widgets.ButtonExt {
            Layout.fillWidth: true

            text: qsTr("Advanced...")

            Accessible.name: qsTr("Advanced preferences")
            Accessible.description: qsTr("Opens the classic preferences window")

            onClicked: root.advancedRequested()
        }
    }
}
