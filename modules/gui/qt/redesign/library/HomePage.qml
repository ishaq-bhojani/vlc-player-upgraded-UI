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

import VLC.MediaLibrary

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Dialogs
import VLC.Redesign

/**
 * @brief The Home page of the redesign: "Continue Watching" (the video history, with the
 * progress), "Listen Again" (the audio history) and "Frequently Visited Folders" (the entry
 * points of the media library) as horizontal rows. A row without item is hidden.
 *
 * When History.viewPath[1] is "recent" (Rail > Recent) the sections are replaced by the whole
 * history, newest first. With nothing at all to show, an empty state offers to add folders.
 */
FocusScope {
    id: root

    // Properties

    // upstream pages carry the prefix of the path they were pushed with, the Stage sets it
    property var pagePrefix: []

    // the full history instead of the sections (Rail > Recent)
    readonly property bool recentView: History.viewPath.length > 1 && History.viewPath[1] === "recent"

    // true once the three data sources delivered their first content (the folder model has no
    // `loading`: it is reset once its entry points are listed)
    property bool _foldersLoaded: false

    // Nothing to show in any section. Only meaningful once the models have loaded.
    readonly property bool isEmpty: !continueModel.loading && !listenModel.loading && _foldersLoaded
                                    && continueSection.count === 0
                                    && listenSection.count === 0
                                    && foldersSection.count === 0

    // number of items of a row
    readonly property int rowLimit: 20

    // Settings

    Accessible.role: Accessible.Pane
    Accessible.name: recentView ? qsTr("Recent") : qsTr("Home")

    // Functions

    function setCurrentItemFocus(reason) {
        if (recentView)
            recentList.forceActiveFocus(reason)
        else if (continueSection.visible)
            continueSection.forceActiveFocus(reason)
        else if (listenSection.visible)
            listenSection.forceActiveFocus(reason)
        else if (foldersSection.visible)
            foldersSection.forceActiveFocus(reason)
        else
            addFolders.forceActiveFocus(reason)
    }

    // plays the media of a card / row delegate (its `id` role is the ML id of the media)
    function play(delegateItem) {
        if (delegateItem && delegateItem.model.id !== undefined)
            MediaLib.addAndPlay(delegateItem.model.id)
    }

    // browses the folder of a FolderCard in the network browser
    function openFolder(delegateItem) {
        if (!delegateItem)
            return
        const tree = PinNavigation.networkTree(delegateItem.model.url, delegateItem.folderName)
        if (tree)
            History.push(["network", "browse"], { tree: tree })
        else
            History.push(["network"])
    }

    // Models

    MLRecentVideoModel {
        id: continueModel

        ml: MediaLib
        limit: root.rowLimit
    }

    MLRecentAudioModel {
        id: listenModel

        ml: MediaLib
        limit: root.rowLimit
    }

    // the entry points the library was told to scan, in the order of the settings
    MLFolderModel {
        id: foldersModel

        ctx: MainCtx
    }

    Connections {
        target: foldersModel

        function onModelReset() {
            root._foldersLoaded = true
        }
    }

    MLRecentMediaModel {
        id: recentModel

        ml: MediaLib
    }

    ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    // Cards

    // a media of the history: cover, a progress bar at the bottom of the cover (when the media
    // was partly played), the title and a second line
    component MediaCard: FocusScope {
        id: card

        required property int index
        required property var model

        // the "progress" role is a fraction, 0 when never played
        property bool showProgress: false
        property url fallbackImage: VLCStyle.noArtAlbumCover
        property string subtitle

        property real coverWidth: VLCStyle.dp(200, VLCStyle.scale)
        property real coverHeight: VLCStyle.dp(112, VLCStyle.scale)

        readonly property bool isCurrent: ListView.isCurrentItem && ListView.view.activeFocus

        width: coverWidth
        height: ListView.view ? ListView.view.height : coverHeight

        Accessible.role: Accessible.ListItem
        Accessible.name: title.text
        Accessible.onPressAction: ListView.view.actionAtIndex(index)

        ColorContext {
            id: cardTheme

            colorSet: ColorContext.Item

            focused: card.isCurrent
            hovered: hover.hovered
        }

        Rectangle {
            id: cover

            width: card.coverWidth
            height: card.coverHeight

            radius: RedesignStyle.radiusL
            color: cardTheme.bg.primary
            clip: true

            border.width: card.isCurrent ? VLCStyle.focus_border : 0
            border.color: cardTheme.visualFocus

            Image {
                anchors.fill: parent

                source: card.model.small_cover ? card.model.small_cover : card.fallbackImage
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize: Qt.size(card.coverWidth * 2, card.coverHeight * 2)
            }

            // progress: the played part of the media
            Rectangle {
                visible: card.showProgress && card.model.progress > 0

                anchors.left: parent.left
                anchors.bottom: parent.bottom

                width: parent.width * Math.min(1, Math.max(0, card.model.progress ?? 0))
                height: RedesignStyle.spacingXS

                color: cardTheme.accent
            }
        }

        ColumnLayout {
            anchors.top: cover.bottom
            anchors.topMargin: RedesignStyle.spacingXS
            anchors.left: cover.left
            anchors.right: cover.right

            spacing: 0

            Text {
                id: title

                Layout.fillWidth: true

                text: card.model.title || qsTr("Unknown Title")
                color: card.isCurrent || hover.hovered ? cardTheme.fg.highlight : cardTheme.fg.primary
                font.pixelSize: VLCStyle.fontSize_normal
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Text {
                Layout.fillWidth: true

                visible: text.length > 0

                text: card.subtitle
                color: cardTheme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_small
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }

        HoverHandler {
            id: hover
        }

        TapHandler {
            onTapped: {
                card.ListView.view.currentIndex = card.index
                card.ListView.view.actionAtIndex(card.index)
            }
        }
    }

    // an entry point of the media library
    component FolderCard: FocusScope {
        id: folderCard

        required property int index
        required property var model

        readonly property bool isCurrent: ListView.isCurrentItem && ListView.view.activeFocus

        // the last element of the path is the name of the folder
        readonly property string folderName: {
            const display = model.display_url ?? ""
            const parts = display.split(/[\\/]/).filter(part => part.length > 0)
            return parts.length > 0 ? parts[parts.length - 1] : display
        }

        width: VLCStyle.dp(200, VLCStyle.scale)
        height: ListView.view ? ListView.view.height : VLCStyle.dp(80, VLCStyle.scale)

        Accessible.role: Accessible.ListItem
        Accessible.name: folderName
        Accessible.onPressAction: ListView.view.actionAtIndex(index)

        ColorContext {
            id: folderTheme

            colorSet: ColorContext.Item

            focused: folderCard.isCurrent
            hovered: folderHover.hovered
        }

        Rectangle {
            id: folderBackground

            width: parent.width
            height: VLCStyle.dp(112, VLCStyle.scale)

            radius: RedesignStyle.radiusL
            color: folderHover.hovered || folderCard.isCurrent ? folderTheme.bg.highlight : folderTheme.bg.primary

            border.width: folderCard.isCurrent ? VLCStyle.focus_border : 0
            border.color: folderTheme.visualFocus

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: RedesignStyle.spacingM

                spacing: RedesignStyle.spacingS

                Widgets.IconLabel {
                    Layout.alignment: Qt.AlignLeft

                    text: VLCIcons.rd_folder
                    color: folderTheme.fg.highlight
                }

                Item {
                    Layout.fillHeight: true
                }

                Text {
                    Layout.fillWidth: true

                    text: folderCard.folderName
                    color: folderTheme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_normal
                    font.bold: true
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }

                Text {
                    Layout.fillWidth: true

                    text: folderCard.model.display_url ?? ""
                    color: folderTheme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_small
                    elide: Text.ElideMiddle
                    textFormat: Text.PlainText
                }
            }
        }

        HoverHandler {
            id: folderHover
        }

        TapHandler {
            onTapped: {
                folderCard.ListView.view.currentIndex = folderCard.index
                folderCard.ListView.view.actionAtIndex(folderCard.index)
            }
        }
    }

    // Children: the sections

    Flickable {
        id: flickable

        anchors.fill: parent

        visible: !root.recentView && !root.isEmpty

        contentWidth: width
        contentHeight: sections.implicitHeight + 2 * RedesignStyle.spacingL

        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        clip: true

        T.ScrollBar.vertical: Widgets.ScrollBarExt { }

        Widgets.NavigableCol {
            id: sections

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: RedesignStyle.spacingL

            spacing: RedesignStyle.spacingXL

            Navigation.parentItem: root

            HomeSection {
                id: continueSection

                width: parent.width

                title: qsTr("Continue Watching")
                linkDescription: qsTr("Show all videos")

                model: continueModel

                delegate: MediaCard {
                    showProgress: true
                    fallbackImage: VLCStyle.noArtVideoCover
                    subtitle: model.duration?.formatHMS() ?? ""
                }

                Navigation.parentItem: sections

                onItemActivated: (index) => root.play(listView.itemAtIndex(index))
                onLinkActivated: (reason) => History.push(["video"], reason)
            }

            HomeSection {
                id: listenSection

                width: parent.width

                title: qsTr("Listen Again")
                linkDescription: qsTr("Show all music")

                // square covers
                cardWidth: VLCStyle.dp(140, VLCStyle.scale)
                cardHeight: VLCStyle.dp(140, VLCStyle.scale)

                model: listenModel

                delegate: MediaCard {
                    coverWidth: VLCStyle.dp(140, VLCStyle.scale)
                    coverHeight: VLCStyle.dp(140, VLCStyle.scale)
                    subtitle: model.main_artist ?? ""
                }

                Navigation.parentItem: sections

                onItemActivated: (index) => root.play(listView.itemAtIndex(index))
                onLinkActivated: (reason) => History.push(["music"], reason)
            }

            HomeSection {
                id: foldersSection

                width: parent.width

                title: qsTr("Frequently Visited Folders")
                linkDescription: qsTr("Browse folders")

                cardHeight: VLCStyle.dp(112, VLCStyle.scale)
                captionHeight: 0

                model: foldersModel

                delegate: FolderCard { }

                Navigation.parentItem: sections

                onItemActivated: (index) => root.openFolder(listView.itemAtIndex(index))
                onLinkActivated: (reason) => History.push(["network"], reason)
            }
        }
    }

    // Children: the whole history

    Widgets.ListViewExt {
        id: recentList

        anchors.fill: parent
        anchors.margins: RedesignStyle.spacingL

        visible: root.recentView

        model: recentModel
        spacing: RedesignStyle.spacingXS

        header: Text {
            width: recentList.width
            height: implicitHeight + RedesignStyle.spacingM

            text: qsTr("Recent")
            color: theme.fg.primary
            font.pixelSize: VLCStyle.fontSize_large
            font.bold: true
            textFormat: Text.PlainText
        }

        delegate: T.ItemDelegate {
            id: recentDelegate

            required property int index
            required property var model

            readonly property bool isCurrent: ListView.isCurrentItem && recentList.activeFocus

            width: recentList.width
            height: VLCStyle.dp(48, VLCStyle.scale)

            hoverEnabled: true

            Accessible.name: model.title

            ColorContext {
                id: recentTheme

                colorSet: ColorContext.Item

                focused: recentDelegate.isCurrent
                hovered: recentDelegate.hovered
            }

            background: Rectangle {
                radius: RedesignStyle.radiusM

                visible: recentDelegate.hovered || recentDelegate.isCurrent
                color: recentTheme.bg.highlight

                border.width: recentDelegate.isCurrent ? VLCStyle.focus_border : 0
                border.color: recentTheme.visualFocus
            }

            contentItem: RowLayout {
                spacing: RedesignStyle.spacingM

                Widgets.IconLabel {
                    text: recentDelegate.model.isVideo ? VLCIcons.topbar_video : VLCIcons.topbar_music
                    color: recentTheme.fg.secondary
                }

                Text {
                    Layout.fillWidth: true

                    text: recentDelegate.model.title || qsTr("Unknown Title")
                    color: recentTheme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_normal
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }

                Text {
                    text: recentDelegate.model.duration?.formatHMS() ?? ""
                    color: recentTheme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_small
                    textFormat: Text.PlainText
                }
            }

            onClicked: {
                recentList.currentIndex = index
                recentList.actionAtIndex(index)
            }
        }

        onActionAtIndex: (index) => root.play(itemAtIndex(index))

        Navigation.parentItem: root
    }

    // Children: nothing to show

    Widgets.EmptyLabel {
        id: emptyState

        anchors.centerIn: parent

        visible: !root.recentView && root.isEmpty

        cover: VLCStyle.noArtAlbumCover
        text: qsTr("No media found\nPlease try adding sources")

        Navigation.parentItem: root

        Widgets.ButtonExt {
            id: addFolders

            anchors.horizontalCenter: parent.horizontalCenter

            width: Math.max(VLCStyle.dp(84, VLCStyle.scale), implicitWidth)

            focus: true

            text: qsTr("Add folders")
            iconTxt: VLCIcons.rd_folder

            Navigation.parentItem: emptyState

            // the media library page of the preferences lists the folders of the library
            onClicked: DialogsProvider.prefsDialog()
        }
    }
}
