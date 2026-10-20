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
 * @brief The keyboard shortcuts (reached from the Controls page): one row per action of
 * ShortcutsModel, its keys and, for the actions that have one, its global keys.
 *
 * Pressing a key button asks for the new key: Esc cancels, Backspace or Delete removes the key,
 * any other key (with its modifiers) is the new one. A key that another action of the same scope
 * already uses is not taken silently: the page names the action and asks (Replace takes the key
 * away from it, as ShortcutsModel.assign() does). The new key replaces all the keys of the
 * action, as in the QWidgets preferences.
 *
 * The model does not follow changes made elsewhere: it is reloaded when the page opens.
 */
FocusScope {
    id: root

    // Properties

    //! the filter typed by the user
    property string filterText

    // A narrow page (the owner's window is 600 dp wide: the page is about 320): an action does not
    // fit in a line with its two key buttons of 160 dp and keeps 120 dp for its name, so the name
    // takes the line and the buttons the line under it, and the filter goes under the title.
    readonly property bool narrow: width < VLCStyle.dp(500, VLCStyle.scale)

    // the key being asked for: the action, its label and the scope; "" for none
    property string _actionKey
    property string _actionLabel
    property bool _global: false

    // the key that is in use by another action, waiting for the answer
    property string _pendingKey
    property string _conflictLabel

    // Signals

    //! the user wants the settings page back
    signal back()

    // Functions

    // The label of an action; the actions the core declares without text are named here
    function displayName(actionKey: string, label: string): string {
        if (actionKey === "key-projection-toggle")
            return qsTr("Toggle 360° projection")
        return label
    }

    // "Space\tMedia Play Pause" -> "Space, Media Play Pause"
    function keysText(hotkey: string): string {
        const keys = String(hotkey).split("\t").filter(key => key.length > 0)
        return keys.length > 0 ? keys.join(", ") : qsTr("Not set")
    }

    function matches(actionKey: string, label: string, hotkey: string): bool {
        const wanted = filterText.trim().toLowerCase()
        if (wanted.length === 0)
            return true
        return displayName(actionKey, label).toLowerCase().includes(wanted)
               || hotkey.toLowerCase().includes(wanted)
    }

    function startCapture(actionKey: string, label: string, global: bool) {
        _actionKey = actionKey
        _actionLabel = label
        _global = global
        _pendingKey = ""
        _conflictLabel = ""
        capture.forceActiveFocus()
    }

    function stopCapture() {
        _actionKey = ""
        _pendingKey = ""
        _conflictLabel = ""
        list.forceActiveFocus()
    }

    // `hotkey` is the new key ("" removes the keys of the action)
    function offer(hotkey: string) {
        const other = hotkey.length > 0 ? ShortcutsModel.conflictFor(_actionKey, hotkey, _global) : ""
        if (other.length > 0) {
            _pendingKey = hotkey
            _conflictLabel = other
            // the answer is one key away: Enter or Space replaces, Tab goes to Cancel
            Qt.callLater(() => replaceButton.forceActiveFocus(Qt.TabFocusReason))
            return
        }
        ShortcutsModel.assign(_actionKey, hotkey, _global)
        stopCapture()
    }

    function replaceConflict() {
        ShortcutsModel.assign(_actionKey, _pendingKey, _global)
        stopCapture()
    }

    // Settings

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Keyboard shortcuts")

    // Fresh keys when the page opens: the model reads the configuration live, but does not know
    // that it changed
    Component.onCompleted: ShortcutsModel.reload()

    // Children

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    ColumnLayout {
        anchors.fill: parent

        spacing: RedesignStyle.spacingM

        GridLayout {
            Layout.fillWidth: true

            columns: root.narrow ? 2 : 3
            columnSpacing: RedesignStyle.spacingM
            rowSpacing: RedesignStyle.spacingS

            Widgets.ButtonExt {
                text: qsTr("Back")

                Accessible.name: qsTr("Back to Controls")

                onClicked: root.back()
            }

            Text {
                Layout.fillWidth: true

                text: qsTr("Keyboard shortcuts")
                font.pixelSize: VLCStyle.fontSize_xlarge
                font.weight: Font.DemiBold
                color: theme.fg.primary
                elide: Text.ElideRight

                Accessible.role: Accessible.Heading
                Accessible.name: qsTr("Keyboard shortcuts")
            }

            Widgets.TextFieldExt {
                Layout.fillWidth: root.narrow
                Layout.columnSpan: root.narrow ? 2 : 1
                Layout.preferredWidth: VLCStyle.dp(220, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)

                radius: RedesignStyle.radiusM
                selectByMouse: true

                placeholderText: qsTr("Filter shortcuts")
                text: root.filterText

                Accessible.name: qsTr("Filter shortcuts")

                onTextChanged: root.filterText = text
            }
        }

        // the question for a new key
        FocusScope {
            id: capture

            Layout.fillWidth: true
            Layout.preferredHeight: visible ? captureColumn.implicitHeight + 2 * RedesignStyle.spacingM : 0

            visible: root._actionKey.length > 0

            Accessible.role: Accessible.Pane
            Accessible.name: qsTr("New key for %1").arg(root._actionLabel)

            // the application shortcuts (Ctrl+P...) must not fire while a key is asked for
            Keys.onShortcutOverride: (event) => {
                if (root._actionKey.length > 0)
                    event.accepted = true
            }

            Keys.onPressed: (event) => {
                // holding a key down asks for nothing more
                if (event.isAutoRepeat) {
                    event.accepted = true
                    return
                }

                // Esc is acted on at its release: the release has to be taken here too, or it
                // would reach the popup and close the whole modal
                if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
                    event.accepted = true
                    return
                }

                // a key is already waiting for the answer: the buttons answer (Tab, Enter and
                // Space are theirs)
                if (root._pendingKey.length > 0) {
                    event.accepted = false
                    return
                }

                event.accepted = true

                if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete)
                        && event.modifiers === Qt.NoModifier) {
                    root.offer("")
                } else {
                    const hotkey = SettingsBridge.hotkeyFromKeyEvent(event.key, event.modifiers, event.text)
                    if (hotkey.length > 0)
                        root.offer(hotkey)
                }
            }

            Keys.onReleased: (event) => {
                if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier && !event.isAutoRepeat) {
                    root.stopCapture()
                    event.accepted = true
                }
            }

            Rectangle {
                anchors.fill: parent

                radius: RedesignStyle.radiusM
                color: theme.bg.secondary
                border.width: VLCStyle.dp(2, VLCStyle.scale)
                border.color: capture.activeFocus ? theme.visualFocus : theme.border
            }

            ColumnLayout {
                id: captureColumn

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: RedesignStyle.spacingM
                }

                spacing: RedesignStyle.spacingS

                Text {
                    Layout.fillWidth: true

                    text: root._pendingKey.length > 0
                          ? qsTr("%1 is already used by \"%2\". Replace it?").arg(root._pendingKey).arg(root._conflictLabel)
                          : qsTr("Press the new key for \"%1\".").arg(root._actionLabel)
                    font.pixelSize: VLCStyle.fontSize_normal
                    color: theme.fg.primary
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true

                    visible: root._pendingKey.length === 0

                    text: qsTr("Esc cancels, Backspace removes the key.")
                    font.pixelSize: VLCStyle.fontSize_small
                    color: theme.fg.secondary
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    spacing: RedesignStyle.spacingS

                    Widgets.ButtonExt {
                        id: replaceButton

                        visible: root._pendingKey.length > 0

                        text: qsTr("Replace")

                        colorContext.colorSet: ColorContext.ButtonAccent

                        onClicked: root.replaceConflict()
                    }

                    Widgets.ButtonExt {
                        text: qsTr("Cancel")

                        onClicked: root.stopCapture()
                    }
                }
            }
        }

        // the names of the two key columns (the narrow page has the buttons under the names, the
        // global key says so)
        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: RedesignStyle.spacingM

            visible: !root.narrow

            spacing: RedesignStyle.spacingM

            Item { Layout.fillWidth: true }

            Text {
                Layout.preferredWidth: VLCStyle.dp(160, VLCStyle.scale)

                text: qsTr("Key")
                font.pixelSize: VLCStyle.fontSize_small
                color: theme.fg.secondary

                Accessible.ignored: true
            }

            Text {
                Layout.preferredWidth: VLCStyle.dp(160, VLCStyle.scale)

                text: qsTr("Global key")
                font.pixelSize: VLCStyle.fontSize_small
                color: theme.fg.secondary

                Accessible.ignored: true
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true

            focus: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: ShortcutsModel

            T.ScrollBar.vertical: Widgets.ScrollBarExt {}

            delegate: Item {
                id: cell

                required property string actionKey
                required property string label
                required property string hotkey
                required property string globalHotkey
                required property string globalKey

                readonly property string name: root.displayName(actionKey, label)
                readonly property bool shown: root.matches(actionKey, label, hotkey + globalHotkey)

                width: ListView.view ? ListView.view.width : 0
                height: shown ? Math.max(VLCStyle.dp(46, VLCStyle.scale), row.implicitHeight + 2 * RedesignStyle.spacingXS) : 0
                visible: shown

                Accessible.role: Accessible.Grouping
                Accessible.name: name

                GridLayout {
                    id: row

                    anchors {
                        left: parent.left
                        right: parent.right
                        rightMargin: RedesignStyle.spacingM
                        verticalCenter: parent.verticalCenter
                    }

                    // the name, the key, the global key; in a narrow page the name over the keys
                    columns: root.narrow ? 2 : 3
                    columnSpacing: RedesignStyle.spacingM
                    rowSpacing: RedesignStyle.spacingS

                    Text {
                        Layout.fillWidth: true
                        Layout.columnSpan: root.narrow ? 2 : 1

                        text: cell.name
                        font.pixelSize: VLCStyle.fontSize_normal
                        color: theme.fg.primary
                        elide: Text.ElideRight

                        Accessible.ignored: true
                    }

                    Widgets.ButtonExt {
                        Layout.fillWidth: root.narrow
                        Layout.preferredWidth: VLCStyle.dp(160, VLCStyle.scale)
                        Layout.maximumWidth: VLCStyle.dp(160, VLCStyle.scale)

                        text: root.keysText(cell.hotkey)

                        Accessible.name: qsTr("%1, key: %2").arg(cell.name).arg(text)

                        onClicked: root.startCapture(cell.actionKey, cell.name, false)
                    }

                    // the global key: the keys that work when the player has no focus
                    Widgets.ButtonExt {
                        Layout.fillWidth: root.narrow
                        Layout.preferredWidth: VLCStyle.dp(160, VLCStyle.scale)
                        Layout.maximumWidth: VLCStyle.dp(160, VLCStyle.scale)

                        visible: cell.globalKey.length > 0

                        text: root.narrow ? qsTr("Global: %1").arg(root.keysText(cell.globalHotkey))
                                          : root.keysText(cell.globalHotkey)

                        Accessible.name: qsTr("%1, global key: %2").arg(cell.name).arg(root.keysText(cell.globalHotkey))

                        onClicked: root.startCapture(cell.actionKey, cell.name, true)
                    }

                    // keeps the key column aligned for an action without a global key
                    Item {
                        Layout.fillWidth: root.narrow
                        Layout.preferredWidth: VLCStyle.dp(160, VLCStyle.scale)
                        Layout.maximumWidth: VLCStyle.dp(160, VLCStyle.scale)

                        visible: cell.globalKey.length === 0
                    }
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    height: 1
                    visible: cell.shown
                    color: theme.separator
                }
            }
        }
    }
}
