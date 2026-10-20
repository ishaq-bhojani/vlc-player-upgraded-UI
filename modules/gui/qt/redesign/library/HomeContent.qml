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
 * @brief The content of the Home page of the redesign (HomePage.qml loads it when the media
 * library exists, it uses the types that only exist then): "Continue Watching" (the video history, with the
 * progress), "Listen Again" (the audio history) and "Frequently Visited Folders" (the entry
 * points of the media library) as horizontal rows. A row without item is hidden.
 *
 * When History.viewPath[1] is "recent" (Rail > Recent) the sections are replaced by the whole
 * history, newest first. With nothing at all to show, an empty state offers to add folders.
 */
FocusScope {
    id: root

    // Properties

    // the full history instead of the sections (Rail > Recent)
    readonly property bool recentView: History.viewPath.length > 1 && History.viewPath[1] === "recent"

    // the folder model has no `loading`: it is reset once its entry points are listed
    property bool foldersLoaded: false

    // true once the three data sources delivered their content
    readonly property bool sourcesLoaded: !continueModel.loading && !listenModel.loading && foldersLoaded

    // Latched after the first complete load: a later reload of a model (its `loading` is
    // true again) must not flash the empty state.
    readonly property OnceLatch firstLoad: OnceLatch {
        input: root.sourcesLoaded
    }

    // Nothing to show in any section. Only meaningful once the models have loaded.
    readonly property bool isEmpty: firstLoad.latched
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

    // scrolls the sections so that `item` (a section) is visible, used when it gets the focus
    function reveal(item) {
        if (item && item.parent)
            Helpers.positionFlickableToContainItem(flickable, item)
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
            root.foldersLoaded = true
        }
    }

    // the whole history, only loaded while it is shown (Rail > Recent)
    Loader {
        id: recentModelLoader

        active: root.recentView

        sourceComponent: MLRecentMediaModel {
            ml: MediaLib
        }
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
        // shown on a dark surface when the media has no artwork (the stock placeholder is a bright card)
        property string fallbackGlyph: VLCIcons.topbar_music
        property string subtitle

        property real coverWidth: VLCStyle.dp(200, VLCStyle.scale)
        property real coverHeight: VLCStyle.dp(112, VLCStyle.scale)

        readonly property bool isCurrent: ListView.isCurrentItem && ListView.view.activeFocus

        readonly property bool hasCover: !!card.model.small_cover

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

            // no artwork: a muted glyph on a sunken surface, like the empty state
            Rectangle {
                anchors.fill: parent

                visible: !card.hasCover

                color: cardTheme.bg.secondary

                border.width: VLCStyle.dp(1, VLCStyle.scale)
                border.color: placeholderTheme.separator
                radius: parent.radius

                ColorContext {
                    id: placeholderTheme

                    colorSet: ColorContext.View
                }

                Widgets.IconLabel {
                    anchors.centerIn: parent

                    text: card.fallbackGlyph
                    color: cardTheme.fg.secondary
                    font.pixelSize: Math.round(Math.min(card.coverWidth, card.coverHeight) * 0.4)
                }
            }

            Image {
                anchors.fill: parent

                visible: card.hasCover

                source: card.hasCover ? card.model.small_cover : ""
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
                    fallbackGlyph: VLCIcons.topbar_video
                    subtitle: model.duration?.formatHMS() ?? ""
                }

                Navigation.parentItem: sections

                onActiveFocusChanged: {
                    if (activeFocus)
                        root.reveal(continueSection)
                }

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

                onActiveFocusChanged: {
                    if (activeFocus)
                        root.reveal(listenSection)
                }

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

                onActiveFocusChanged: {
                    if (activeFocus)
                        root.reveal(foldersSection)
                }

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

        model: recentModelLoader.item
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

    // The stock empty view (Widgets.EmptyLabel) is a bright cover card, which clashes with the
    // dark theme: a muted glyph on a sunken surface, readable text and the accent button instead.
    FocusScope {
        id: emptyState

        anchors.centerIn: parent

        visible: !root.recentView && root.isEmpty
        enabled: visible

        width: emptyColumn.implicitWidth
        height: emptyColumn.implicitHeight

        Accessible.role: Accessible.Pane
        Accessible.name: qsTr("Empty view")

        Navigation.parentItem: root

        // Enter / OK activates the button (EmptyLabelButton does the same: the button alone
        // only reacts to Space). The keys are not accepted by the button, so they reach here.
        property bool _keyPressed: false

        Keys.priority: Keys.AfterItem

        Keys.onPressed: (event) => {
            _keyPressed = true

            Navigation.defaultKeyAction(event)
        }

        Keys.onReleased: (event) => {
            if (_keyPressed === false)
                return

            _keyPressed = false

            if (KeyHelper.matchOk(event))
                addFolders.clicked()

            Navigation.defaultKeyReleaseAction(event)
        }

        Column {
            id: emptyColumn

            spacing: RedesignStyle.spacingL

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter

                width: VLCStyle.dp(96, VLCStyle.scale)
                height: width

                radius: RedesignStyle.radiusL
                color: theme.bg.secondary

                border.width: VLCStyle.dp(1, VLCStyle.scale)
                border.color: theme.separator

                Widgets.IconLabel {
                    anchors.centerIn: parent

                    text: VLCIcons.topbar_music
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.icon_medium
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter

                spacing: RedesignStyle.spacingXS

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text: qsTr("No media found")
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_xlarge
                    font.weight: Font.DemiBold
                    textFormat: Text.PlainText
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text: qsTr("Please try adding sources")
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.fontSize_normal
                    textFormat: Text.PlainText
                }
            }

            Widgets.ButtonExt {
                id: addFolders

                anchors.horizontalCenter: parent.horizontalCenter

                width: Math.max(VLCStyle.dp(120, VLCStyle.scale), implicitWidth)

                focus: true

                text: qsTr("Add folders")
                iconTxt: VLCIcons.rd_folder
                font.bold: true

                colorContext.colorSet: ColorContext.ButtonAccent

                Navigation.parentItem: emptyState

                // the media library page of the preferences lists the folders of the library
                onClicked: DialogsProvider.prefsDialog()
            }
        }
    }
}
