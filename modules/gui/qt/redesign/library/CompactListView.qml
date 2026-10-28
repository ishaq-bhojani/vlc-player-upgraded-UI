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
import QtQuick.Templates as T
import QtQml.Models

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Redesign

/**
 * @brief The "list" view mode of the library: one row per item of the page (thumbnail, title,
 * duration), drawn over the page. It is the view of the panel beside the video, which is too
 * narrow for the grid or the table of the stock pages.
 *
 * `content` holds the items of the page (its MainViewLoader, or the page itself when it exposes the
 * model and the selection of its table, as the tracks do): its `model` is shown. Activating a row selects the item in the page's own selection and
 * emits the page view's `actionAtIndex`, so the page does what it does on a double click in its
 * grid or table (play, open a group, an album, a folder). Nothing here knows the media library.
 */
FocusScope {
    id: root

    // Properties

    property Item content: null

    readonly property var model: content?.model ?? null

    // Settings

    Accessible.role: Accessible.List
    Accessible.name: qsTr("Items")

    // Functions

    // The view whose actionAtIndex the page handles: the content itself when it is a list view, the
    // current grid / table of a MainViewLoader, or a list view a few levels inside a page that only
    // aliases the model and the selection of its table (the tracks).
    function _actionView(): var {
        if (!content)
            return null
        const isView = (item) => !!item && typeof item.actionAtIndex === "function"
        if (isView(content))
            return content
        if (isView(content.currentItem))
            return content.currentItem
        const find = (item, depth) => {
            for (const child of item.children) {
                if (isView(child) && child.model === root.model)
                    return child
                const inner = (depth > 0) ? find(child, depth - 1) : null
                if (inner)
                    return inner
            }
            return null
        }
        return find(content, 2)
    }

    function activate(index: int) {
        if (!root.model || index < 0)
            return
        const selection = content.selectionModel ?? null
        if (selection)
            selection.select(root.model.index(index, 0), ItemSelectionModel.ClearAndSelect)
        const view = _actionView()
        if (view)
            view.actionAtIndex(index)
        else
            console.warn("CompactListView: the page has no action for its items")
    }

    // Children

    ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    Rectangle {
        anchors.fill: parent

        color: theme.bg.primary
    }

    Widgets.ListViewExt {
        id: listView

        anchors.fill: parent

        model: root.model

        focus: true
        clip: true

        topMargin: RedesignStyle.spacingXS
        bottomMargin: RedesignStyle.spacingXS

        Navigation.parentItem: root

        onActionAtIndex: (index) => root.activate(index)

        delegate: T.ItemDelegate {
            id: row

            required property int index
            required property var model

            readonly property string title: model.title || model.name || ""
            readonly property string thumbnail: model.thumbnail || model.small_cover || model.cover
                                                || model.artwork || ""
            // none for a folder or a group, whose duration is not known (it reads "0 ms")
            readonly property string durationText: {
                const duration = model.duration
                if (!duration || typeof duration.formatHMS !== "function")
                    return ""
                return (duration.valid() && duration.toSeconds() > 0) ? duration.formatHMS() : ""
            }

            readonly property bool current: ListView.isCurrentItem

            width: ListView.view.width
            height: VLCStyle.dp(48, VLCStyle.scale)

            hoverEnabled: true

            // the list holds the focus, a row is never a stop of its own
            focusPolicy: Qt.NoFocus

            Accessible.role: Accessible.ListItem
            Accessible.name: row.durationText ? qsTr("%1, %2").arg(row.title).arg(row.durationText)
                                              : row.title
            Accessible.onPressAction: root.activate(row.index)

            onClicked: {
                listView.currentIndex = row.index
                listView.forceActiveFocus(Qt.MouseFocusReason)
            }
            onDoubleClicked: root.activate(row.index)

            readonly property ColorContext colorContext: ColorContext {
                id: rowTheme

                colorSet: ColorContext.Item

                focused: row.current && listView.activeFocus
                hovered: row.hovered
                pressed: row.down
            }

            background: Rectangle {
                radius: RedesignStyle.radiusM

                color: row.current ? rowTheme.bg.highlight : rowTheme.bg.primary

                border.width: VLCStyle.focus_border
                border.color: (row.current && listView.activeFocus) ? rowTheme.visualFocus : "transparent"
            }

            contentItem: Item {
                Rectangle {
                    id: thumbFrame

                    anchors {
                        left: parent.left
                        leftMargin: RedesignStyle.spacingS
                        verticalCenter: parent.verticalCenter
                    }

                    width: VLCStyle.dp(64, VLCStyle.scale)
                    height: VLCStyle.dp(36, VLCStyle.scale)
                    radius: RedesignStyle.radiusS
                    clip: true

                    color: theme.bg.secondary

                    Image {
                        anchors.fill: parent

                        source: row.thumbnail
                        sourceSize: Qt.size(width, height)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: status === Image.Ready
                    }
                }

                Text {
                    anchors {
                        left: thumbFrame.right
                        leftMargin: RedesignStyle.spacingS
                        right: duration.left
                        rightMargin: RedesignStyle.spacingS
                        verticalCenter: parent.verticalCenter
                    }

                    text: row.title
                    elide: Text.ElideRight
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_normal
                    textFormat: Text.PlainText
                }

                Text {
                    id: duration

                    anchors {
                        right: parent.right
                        rightMargin: RedesignStyle.spacingS
                        verticalCenter: parent.verticalCenter
                    }

                    text: row.durationText
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_small
                    textFormat: Text.PlainText
                }
            }
        }
    }
}
