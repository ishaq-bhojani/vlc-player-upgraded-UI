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
 * @brief One page of the settings modal: its title with "Reset to defaults", the rows of
 * SettingsData in the order of docs/redesign/settings-map.md, and a collapsed Advanced section.
 *
 * The rows are a ListView (a page can have a few hundred Advanced rows, only those in view are
 * created). The Advanced section lists the options of the VLC subcategories of the page that no
 * page shows as a row; it is built when the user opens it (SettingsOps.advancedKeys()).
 *
 * "Reset to defaults" puts the rows of the page back (the Advanced section is not part of it),
 * after an inline confirmation that says how many settings it changes.
 *
 * A row whose option is missing in this build (its plugin is not there) is not listed.
 */
FocusScope {
    id: root

    // Properties

    //! the id of the page in SettingsData.pages (GeneralPage sets it)
    property string pageId

    //! the id of the row to flash (a search result), "" for none
    property string highlightId

    //! the page object of SettingsData
    readonly property var page: SettingsData.pageById(pageId)

    //! the title of the page
    readonly property string title: page ? page.title : ""

    //! the rows of the page this build has
    readonly property var rows: page ? SettingsOps.presentRows(page) : []

    //! the page has an Advanced section
    readonly property bool hasAdvanced: page !== undefined && page.subcats.length > 0

    //! the Advanced section is open
    property bool advancedOpen: false

    //! the bands of the equalizer are shown
    property bool equalizerOpen: false

    //! the list of the rows
    readonly property alias view: list

    //! what the list shows
    readonly property var entries: {
        const list = rows.map(row => ({ type: "row", id: row.id, row: row }))
        if (hasAdvanced) {
            list.push({ type: "advancedHeader", id: "advanced" })
            if (advancedOpen) {
                for (const key of SettingsOps.advancedKeys(page))
                    list.push({ type: "advanced", id: "advanced:" + key, key: key })
            }
        }
        return list
    }

    // the number of settings the confirmation is about, -1 while there is no question
    property int _resetCount: -1

    // scrollTo(): the index to keep in view and the passes left
    property int _scrollIndex: 0
    property int _scrollPasses: 0

    // "Reset to defaults" had nothing to reset
    property bool _nothingToReset: false

    // Signals

    //! the user asked for another page ("shortcuts")
    signal navigate(string target)

    // Functions

    //! scrolls to the row with this id and flashes it
    function scrollTo(rowId: string) {
        const index = entries.findIndex(entry => entry.id === rowId)
        if (index < 0)
            return
        if (entries[index].row && entries[index].row.kind === "equalizer")
            equalizerOpen = true
        _scrollIndex = index
        list.positionViewAtIndex(index, ListView.Beginning)
        // the rows above are only estimated until they exist: place the view again as the sizes
        // settle, so that a row deep in the page lands on target
        _scrollPasses = 4
        scrollTimer.restart()
        highlightId = rowId
        flashTimer.restart()
    }

    function openAdvanced() {
        if (!hasAdvanced)
            return
        advancedOpen = true
        // the section is rebuilt: show its start
        Qt.callLater(() => list.positionViewAtIndex(rows.length, ListView.Beginning))
    }

    function closeAdvanced() {
        advancedOpen = false
        // the list is rebuilt: keep the header in view
        Qt.callLater(() => list.positionViewAtIndex(rows.length, ListView.End))
    }

    function _askReset() {
        const count = SettingsOps.changedCount(page)
        _nothingToReset = count === 0
        _resetCount = count > 0 ? count : -1
        if (_nothingToReset)
            noticeTimer.restart()
    }

    function _confirmReset() {
        _resetCount = -1
        SettingsOps.resetPage(page)
    }

    function _handleAction(name: string) {
        switch (name) {
        case "shortcuts":
            navigate("shortcuts")
            break
        case "advanced":
            openAdvanced()
            break
        case "extensions":
            DialogsProvider.pluginDialog()
            break
        }
    }

    // what a row of the list is made of
    function _componentFor(entry: var): Component {
        if (entry.type === "advancedHeader")
            return advancedHeaderComponent
        if (entry.type === "advanced")
            return settingComponent
        switch (entry.row.kind) {
        case "accent": return accentComponent
        case "theme": return themeComponent
        case "shortcuts": return shortcutsComponent
        case "advancedLink": return advancedLinkComponent
        case "equalizer": return equalizerComponent
        case "effectToggle": return effectToggleComponent
        case "effectSlider": return effectSliderComponent
        case "filterToken": return filterTokenComponent
        case "libraryFolders": return libraryFoldersComponent
        case "extensions": return extensionsComponent
        case "toolConsent": return toolConsentComponent
        case "replayGain": return replayGainComponent
        default: return settingComponent
        }
    }

    // Settings

    Accessible.role: Accessible.Pane
    Accessible.name: title

    onPageIdChanged: {
        advancedOpen = false
        equalizerOpen = false
        highlightId = ""
        _resetCount = -1
        _nothingToReset = false
    }

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    Timer {
        id: scrollTimer

        interval: 80
        repeat: true

        onTriggered: {
            list.positionViewAtIndex(root._scrollIndex, ListView.Beginning)
            if (--root._scrollPasses <= 0)
                scrollTimer.stop()
        }
    }

    Timer {
        id: flashTimer

        interval: 1800

        onTriggered: root.highlightId = ""
    }

    Timer {
        id: noticeTimer

        interval: 2500

        onTriggered: root._nothingToReset = false
    }

    // a plain option of VLC; the Advanced section uses it for its keys too
    component SettingEntry: SettingRow {
        property var spec

        key: spec ? spec.key : ""
        hint: spec ? (spec.hint ?? "") : ""

        // a path has a Browse button: the native folder or file dialog of the main window
        canBrowse: item !== null && item.type === ControlChooser.type.Path

        onBrowseRequested: (setting) => {
            const start = String(setting.value ?? "")
            let picked
            switch (setting.pathKind) {
            case "directory":
                picked = SettingsBridge.pickFolder(setting.text, start)
                break
            case "savefile":
                picked = SettingsBridge.pickSaveFile(setting.text, start)
                break
            default:
                picked = SettingsBridge.pickFile(setting.text, start)
                break
            }
            // "" is a cancel
            if (picked.length > 0)
                setting.value = picked
        }
    }

    Component { id: settingComponent; SettingEntry {} }
    Component { id: accentComponent; AccentRow {} }
    Component { id: themeComponent; ThemeRow {} }
    Component { id: effectToggleComponent; EffectToggleRow {} }
    Component { id: effectSliderComponent; EffectSliderRow {} }
    Component { id: filterTokenComponent; FilterTokenRow {} }
    Component { id: libraryFoldersComponent; LibraryFoldersRow {} }
    Component { id: toolConsentComponent; ToolConsentRow {} }
    Component { id: replayGainComponent; ReplayGainRow {} }

    Component {
        id: equalizerComponent

        EqualizerPanel {
            expanded: root.equalizerOpen

            onToggleExpanded: root.equalizerOpen = !root.equalizerOpen
        }
    }

    Component {
        id: shortcutsComponent

        ActionRow {
            actionName: "shortcuts"
            buttonText: qsTr("Edit shortcuts")

            onAction: (name) => root._handleAction(name)
        }
    }

    Component {
        id: advancedLinkComponent

        ActionRow {
            actionName: "advanced"
            buttonText: qsTr("Show")

            onAction: (name) => root._handleAction(name)
        }
    }

    Component {
        id: extensionsComponent

        ActionRow {
            actionName: "extensions"
            buttonText: qsTr("Manage extensions...")

            onAction: (name) => root._handleAction(name)
        }
    }

    // the header of the Advanced section: a button that opens and closes it
    Component {
        id: advancedHeaderComponent

        T.AbstractButton {
            id: header

            property var spec

            implicitWidth: headerRow.implicitWidth
            implicitHeight: VLCStyle.dp(52, VLCStyle.scale)

            focusPolicy: Qt.StrongFocus
            hoverEnabled: true

            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Advanced settings")
            Accessible.description: root.advancedOpen ? qsTr("Expanded") : qsTr("Collapsed")
            Accessible.onPressAction: header.clicked()

            onClicked: {
                if (root.advancedOpen)
                    root.closeAdvanced()
                else
                    root.openAdvanced()
            }

            readonly property ColorContext colorContext: ColorContext {
                id: headerTheme

                colorSet: ColorContext.Item

                focused: header.visualFocus
                hovered: header.hovered
            }

            background: Rectangle {
                radius: RedesignStyle.radiusM
                color: headerTheme.bg.primary
                border.width: header.visualFocus ? VLCStyle.dp(2, VLCStyle.scale) : 0
                border.color: headerTheme.visualFocus
            }

            contentItem: RowLayout {
                id: headerRow

                spacing: RedesignStyle.spacingM

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: RedesignStyle.spacingM

                    spacing: 0

                    Text {
                        Layout.fillWidth: true

                        text: qsTr("Advanced")
                        font.pixelSize: VLCStyle.fontSize_normal
                        font.weight: Font.DemiBold
                        color: headerTheme.fg.primary

                        Accessible.ignored: true
                    }

                    Text {
                        Layout.fillWidth: true

                        text: qsTr("Every other option of this page")
                        font.pixelSize: VLCStyle.fontSize_small
                        color: headerTheme.fg.secondary
                        elide: Text.ElideRight

                        Accessible.ignored: true
                    }
                }

                Widgets.IconLabel {
                    Layout.rightMargin: RedesignStyle.spacingM

                    text: root.advancedOpen ? VLCIcons.ic_fluent_chevron_up_24 : VLCIcons.ic_fluent_chevron_down_24
                    color: headerTheme.fg.primary
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent

        spacing: RedesignStyle.spacingM

        // the title, and "Reset to defaults" with its confirmation
        RowLayout {
            Layout.fillWidth: true

            spacing: RedesignStyle.spacingM

            Text {
                Layout.fillWidth: true

                text: root.title
                font.pixelSize: VLCStyle.fontSize_xlarge
                font.weight: Font.DemiBold
                color: theme.fg.primary
                elide: Text.ElideRight

                Accessible.role: Accessible.Heading
                Accessible.name: root.title
            }

            Text {
                visible: root._resetCount >= 0 || root._nothingToReset

                text: root._nothingToReset ? qsTr("Nothing to reset")
                      : (root._resetCount === 1 ? qsTr("Reset 1 setting?")
                                                : qsTr("Reset %1 settings?").arg(root._resetCount))
                font.pixelSize: VLCStyle.fontSize_normal
                color: theme.fg.primary

                Accessible.role: Accessible.StaticText
            }

            Widgets.ButtonExt {
                visible: root._resetCount >= 0

                text: qsTr("Reset")

                colorContext.colorSet: ColorContext.ButtonAccent

                onClicked: root._confirmReset()
            }

            Widgets.ButtonExt {
                visible: root._resetCount >= 0

                text: qsTr("Cancel")

                onClicked: root._resetCount = -1
            }

            Widgets.ButtonExt {
                visible: root._resetCount < 0

                text: qsTr("Reset to defaults")

                onClicked: root._askReset()
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true

            focus: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: false

            model: root.entries

            T.ScrollBar.vertical: Widgets.ScrollBarExt {}

            delegate: Item {
                id: cell

                required property var modelData

                readonly property bool flashed: root.highlightId.length > 0 && root.highlightId === modelData.id

                width: ListView.view ? ListView.view.width : 0
                height: loader.height + (loader.height > 0 ? 1 : 0)

                // the row of a search result
                Rectangle {
                    anchors.fill: parent

                    radius: RedesignStyle.radiusM
                    color: theme.accent
                    opacity: cell.flashed ? 0.2 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: VLCStyle.duration_short }
                    }
                }

                Loader {
                    id: loader

                    // the scrollbar is outside of the rows
                    width: parent.width - RedesignStyle.spacingM
                    height: item ? item.implicitHeight : 0

                    sourceComponent: root._componentFor(cell.modelData)

                    onLoaded: {
                        const entry = cell.modelData
                        if (entry.type === "row")
                            item.spec = entry.row
                        else if (entry.type === "advanced")
                            item.spec = { key: entry.key, hint: "" }
                    }
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    height: 1
                    visible: loader.height > 0
                    color: theme.separator
                }
            }
        }
    }
}
