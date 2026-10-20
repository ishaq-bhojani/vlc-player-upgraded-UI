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

import VLC.MainInterface
import VLC.Dialogs
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Redesign

/**
 * @brief The settings of the player: a modal with a sidebar (search, App / Media / System groups)
 * and the 13 pages of docs/redesign/settings-map.md.
 *
 * It hosts nothing and is hosted by nothing: whoever shows it creates it (an Item of the window)
 * and calls `open(page)`. `close()`, Esc and the close button hide it, `closed()` tells the host,
 * which decides where the focus goes. Changes are applied as they are made.
 *
 * - The sidebar is navigated with the arrow keys; the search finds the pages and the rows of the
 *   pages (SettingsSearch) and a result opens its page, scrolled to the row.
 * - The keyboard shortcuts are a sub-page of Controls (ShortcutsPage).
 * - A banner says that a change needs a restart (RedesignSettings.restartPending).
 * - "Advanced..." opens the QWidgets preferences (DialogsProvider.prefsDialog()).
 */
Item {
    id: root

    // Properties

    //! the id of the page shown (SettingsData.pages)
    property string page: "general"

    //! the keyboard shortcuts replace the page of Controls
    property bool shortcutsOpen: false

    //! the modal is shown
    readonly property bool opened: popup.opened

    //! the page shown, null while the shortcuts or the results of a search are shown
    readonly property Item pageItem: pageLoader.item

    //! the entries of the search, built when the user starts to search
    property var _index: null

    //! the results of the text in the search field
    readonly property var results: SettingsSearch.filter(_index, sidebar.searchText)

    // Signals

    //! the modal was hidden (close(), Esc, or the close button)
    signal closed()

    // Functions

    /**
     * Shows the modal on a page (an id of SettingsData.pages; the page shown last when empty or
     * unknown), scrolled to the row `rowId` when it is given. "shortcuts" shows the keyboard
     * shortcuts, the sub-page of Controls.
     */
    function open(pageId: var, rowId: var) {
        sidebar.clearSearch()
        const shortcuts = pageId === "shortcuts"
        if (shortcuts)
            page = "controls"
        else if (pageId !== undefined && pageId !== null && SettingsData.pageIds.includes(pageId))
            page = pageId
        shortcutsOpen = shortcuts
        popup.open()
        if (rowId)
            Qt.callLater(() => pageLoader.item?.scrollTo(rowId))
    }

    function close() {
        popup.close()
    }

    //! searches the settings (what the user does by typing in the search field)
    function search(text: string) {
        sidebar.setSearch(text)
    }

    // shows a page of the sidebar
    function showPage(pageId: string, rowId: var) {
        sidebar.clearSearch()
        page = pageId
        shortcutsOpen = false
        if (rowId)
            Qt.callLater(() => pageLoader.item?.scrollTo(rowId))
    }

    // the file of the page: "audio" -> "AudioPage.qml"
    function _pageFile(pageId: string): string {
        return pageId.charAt(0).toUpperCase() + pageId.slice(1) + "Page.qml"
    }

    // Settings

    // the modal is in the overlay of the window, this item takes no room
    visible: false
    width: 0
    height: 0

    // the index is built the first time something is typed
    Connections {
        target: sidebar

        function onSearchTextChanged() {
            if (sidebar.searchText.length > 0 && root._index === null)
                root._index = SettingsOps.searchIndex()
        }
    }

    // Children

    T.Popup {
        id: popup

        readonly property Item overlay: T.Overlay.overlay

        parent: overlay
        anchors.centerIn: overlay

        width: overlay ? Math.min(overlay.width - 2 * VLCStyle.margin_large, VLCStyle.dp(1040, VLCStyle.scale)) : 0
        height: overlay ? Math.min(overlay.height - 2 * VLCStyle.margin_large, VLCStyle.dp(720, VLCStyle.scale)) : 0

        modal: true
        focus: true
        padding: 0

        closePolicy: T.Popup.CloseOnEscape

        onOpened: {
            if (root.shortcutsOpen && shortcutsLoader.item)
                shortcutsLoader.item.forceActiveFocus()
            else
                sidebar.focusList()
        }
        onClosed: root.closed()

        enter: Transition {
            OpacityAnimator { from: 0.0; to: 1.0; duration: VLCStyle.duration_short }
        }

        exit: Transition {
            OpacityAnimator { from: 1.0; to: 0.0; duration: VLCStyle.duration_short }
        }

        T.Overlay.modal: Rectangle {
            color: theme.bg.primary
            opacity: 0.6
        }

        background: Rectangle {
            radius: RedesignStyle.radiusL

            color: theme.bg.primary
            border.width: 1
            border.color: theme.border
        }

        contentItem: ColumnLayout {
            spacing: 0

            // A popup is not an Item of the window: its content is not under the ColorContext of the
            // window, and the controls of the pages would get no palette (magenta). A ColorContext
            // that is a child of the popup does not help either (the palette lookup walks the parent
            // Items, and a popup is not one), so the content has its own. The background and the
            // overlay, which are not in the content, use it by its id.
            readonly property ColorContext colorContext: ColorContext {
                id: theme

                palette: VLCStyle.palette
                colorSet: ColorContext.Window
            }

            Accessible.role: Accessible.Dialog
            Accessible.name: qsTr("Settings")

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                spacing: 0

                SettingsSidebar {
                    id: sidebar

                    Layout.fillHeight: true
                    // A narrow window: the sidebar and its margins keep a third of the modal at
                    // most, the page needs the rest (the sidebar is 220 dp wide, in a modal of
                    // 1040 dp at most), but never less than the floor, or the names of the pages
                    // do not fit.
                    Layout.preferredWidth: Math.max(VLCStyle.dp(140, VLCStyle.scale),
                                                    Math.min(implicitWidth,
                                                             popup.width / 3 - 2 * RedesignStyle.spacingL))
                    Layout.margins: RedesignStyle.spacingL

                    currentPage: root.shortcutsOpen ? "controls" : root.page
                    searching: sidebar.searchText.length > 0

                    onPageSelected: (pageId) => root.showPage(pageId)
                    onAdvancedRequested: DialogsProvider.prefsDialog()
                    onResultsRequested: resultsList.forceActiveFocus(Qt.TabFocusReason)
                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1

                    color: theme.separator
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: RedesignStyle.spacingL

                    spacing: RedesignStyle.spacingS

                    RowLayout {
                        Layout.fillWidth: true

                        Item { Layout.fillWidth: true }

                        Widgets.IconToolButton {
                            text: VLCIcons.close
                            description: qsTr("Close settings")

                            onClicked: root.close()
                        }
                    }

                    Text {
                        Layout.fillWidth: true

                        visible: sidebar.searching && root.results.length === 0

                        text: qsTr("No setting found")
                        font.pixelSize: VLCStyle.fontSize_normal
                        color: theme.fg.secondary

                        Accessible.role: Accessible.StaticText
                    }

                    // the results of the search
                    ListView {
                        id: resultsList

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        visible: sidebar.searching && root.results.length > 0

                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        keyNavigationEnabled: true
                        currentIndex: 0

                        model: root.results

                        T.ScrollBar.vertical: Widgets.ScrollBarExt {}

                        Accessible.role: Accessible.List
                        Accessible.name: qsTr("Search results")

                        Keys.onReturnPressed: root._pick(resultsList.currentIndex)
                        Keys.onEnterPressed: root._pick(resultsList.currentIndex)

                        delegate: T.ItemDelegate {
                            id: result

                            required property var modelData
                            required property int index

                            readonly property string pageTitle: SettingsData.pageById(modelData.page)?.title ?? ""

                            width: ListView.view.width
                            implicitHeight: VLCStyle.dp(56, VLCStyle.scale)

                            hoverEnabled: true

                            Accessible.role: Accessible.ListItem
                            Accessible.name: modelData.label + ", " + pageTitle
                            Accessible.description: modelData.description
                            Accessible.onPressAction: result.clicked()

                            onClicked: root._pick(result.index)

                            readonly property ColorContext colorContext: ColorContext {
                                id: resultTheme

                                colorSet: ColorContext.Item

                                focused: result.ListView.isCurrentItem && resultsList.activeFocus
                                hovered: result.hovered
                            }

                            background: Rectangle {
                                radius: RedesignStyle.radiusM
                                color: resultTheme.bg.primary
                            }

                            contentItem: ColumnLayout {
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true

                                    text: result.modelData.label
                                    font.pixelSize: VLCStyle.fontSize_normal
                                    color: resultTheme.fg.primary
                                    elide: Text.ElideRight

                                    Accessible.ignored: true
                                }

                                Text {
                                    Layout.fillWidth: true

                                    text: result.pageTitle + (result.modelData.description.length > 0
                                                              ? "  -  " + result.modelData.description : "")
                                    font.pixelSize: VLCStyle.fontSize_small
                                    color: resultTheme.fg.secondary
                                    elide: Text.ElideRight

                                    Accessible.ignored: true
                                }
                            }
                        }
                    }

                    // the keyboard shortcuts, a sub-page of Controls
                    Loader {
                        id: shortcutsLoader

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        active: root.shortcutsOpen && !sidebar.searching
                        visible: active

                        source: "ShortcutsPage.qml"

                        onLoaded: item.forceActiveFocus()
                    }

                    Connections {
                        target: shortcutsLoader.item

                        function onBack() {
                            root.shortcutsOpen = false
                        }
                    }

                    // the page
                    Loader {
                        id: pageLoader

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        active: !root.shortcutsOpen && !sidebar.searching
                        visible: active

                        source: root._pageFile(root.page)
                    }

                    Connections {
                        target: pageLoader.item

                        function onNavigate(target) {
                            if (target === "shortcuts")
                                root.shortcutsOpen = true
                        }
                    }
                }
            }

            // a change that is only applied by the next start
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? banner.implicitHeight + 2 * RedesignStyle.spacingM : 0

                visible: RedesignSettings.restartPending

                color: theme.bg.secondary

                Accessible.role: Accessible.AlertMessage
                Accessible.name: banner.text

                Text {
                    id: banner

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: RedesignStyle.spacingL
                        rightMargin: RedesignStyle.spacingL
                    }

                    text: qsTr("Some changes take effect after you restart the player.")
                    font.pixelSize: VLCStyle.fontSize_normal
                    color: theme.fg.primary
                    wrapMode: Text.WordWrap

                    Accessible.ignored: true
                }
            }
        }
    }

    // the user chose a result of the search
    function _pick(resultIndex: int) {
        const entry = results[resultIndex]
        if (entry)
            showPage(entry.page, entry.rowId)
    }
}
