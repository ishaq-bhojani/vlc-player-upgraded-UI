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
import QtCore as QtCore

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Redesign

/**
 * @brief The header of the library: back / forward, the address bar (Breadcrumbs), the number of
 * items, the view mode, the sort menu, the search and a menu to add media.
 *
 * It works on the page that `page` (the PageLoader of the library) shows: the "leaf", the
 * innermost page of the nested PageLoaders. A stock page (a PageExt) has its own header with a
 * grid/list button, a sort control and a search box. This header replaces it (it is hidden) and
 * drives the same things: the page's SortCtx (`leaf.sort`, its `sortModel` gives the entries, the
 * page saves its choice) and SearchCtx (`leaf.search`), and the global MainCtx.gridView.
 *
 * `compact` is the panel beside the video: the page is always shown as the compact list there,
 * and the header keeps back / forward, the address, the sort and the menu.
 */
FocusScope {
    id: root

    // Properties

    // the PageLoader of the library
    property Item page: null

    // the panel beside the video (narrow): see the comment above
    property bool compact: false

    // the name of the first crumb: the entry of the rail that is shown
    property string rootLabel

    // the innermost page shown: the PageLoaders are walked down to the page they show
    readonly property Item leaf: {
        let item = root.page?.currentItem ?? null
        while (item && typeof item.loadView === "function")
            item = item.currentItem ?? null
        return item
    }

    // What holds the items of the leaf: its `model` and `selectionModel`. Usually the first child
    // of the PageExt (a MainViewLoader; PageExt names it _firstChild); some pages expose both
    // themselves (the tracks: the page aliases those of its table).
    readonly property Item content: {
        const holds = (item) => !!item && !!item.model
                                && (item.selectionModel !== undefined || typeof item.actionAtIndex === "function")
        const child = root.leaf?._firstChild ?? null
        if (holds(child))
            return child
        return holds(root.leaf) ? root.leaf : null
    }

    readonly property int itemCount: root.content?.model?.count ?? -1

    readonly property string viewMode: LibraryOptions.effectiveViewMode(persisted.viewMode, root.compact)

    // the shell covers the page with a CompactListView of `content`
    readonly property bool showsCompactList: (root.viewMode === "list") && !!root.content

    readonly property var sortOptions: LibraryOptions.sortOptions(root.leaf?.sort?.model ?? null,
                                                                  LibraryOptions.supportsPlaycount(root.content?.model ?? null))

    readonly property var crumbs: {
        const path = Array.from(History.viewPath)
        const labels = Object.assign({}, _segmentLabels)
        if (path.length > 0)
            labels[path[0]] = root.rootLabel || path[0]
        const out = AddressPath.crumbs(path, labels)

        // A page that shows one thing (a group, a playlist, an album) has its name in the History.
        // Read only when the key exists: a QQmlPropertyMap creates the properties QML reads, and the
        // PageLoader would then give the page a "title" it does not have. (Its value() is not
        // callable from QML.)
        const props = History.viewProp
        const title = (props && props.keys().includes("title")) ? props.title : undefined
        if (out.length > 1 && (typeof title === "string") && title !== "")
            out[out.length - 1].label = title

        // the folders of a network folder (the "browse" route, the one _activateCrumb pushes; the
        // pages of the services build theirs differently)
        const folders = History.match(History.viewPath, ["network", "browse"]) ? root.leaf?.headerPath : null
        if (folders && folders.length > 0) {
            for (const node of Array.from(folders))
                out.push({label: node.display, path: [], tree: node.tree})
        }
        return out
    }

    // the segments that are not the first one; "" for a step with no page of its own (the first
    // tab of a page, the base of the videos)
    readonly property var _segmentLabels: ({
        all: "",
        base: "",
        browse: "",
        home: "",
        recent: qsTr("Recent"),
        playlists: qsTr("Playlists"),
        list: qsTr("Playlist"),
        artists: qsTr("Artists"),
        albums: qsTr("Albums"),
        tracks: qsTr("Tracks"),
        genres: qsTr("Genres"),
        group: qsTr("Group"),
        folders: qsTr("Folders"),
        device: qsTr("Device"),
        services: qsTr("Services"),
        services_manage: qsTr("Manage"),
        source_root: "",
        source_browse: "",
        url: qsTr("URL"),
        continueWatching: qsTr("Continue watching"),
        favorites: qsTr("Favorites"),
        newVideo: qsTr("New videos"),
        newMusic: qsTr("New music")
    })

    // Settings

    implicitHeight: RedesignStyle.titleBarHeight

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Library header")
    onViewModeChanged: _applyViewMode()
    Component.onCompleted: _applyViewMode()

    // A new page starts with an empty search. The panel beside the video has no search box: a
    // filter typed in the stage is dropped there, it could not be seen or cleared.
    onLeafChanged: searchBox.textField.clear()
    onCompactChanged: {
        if (compact)
            searchBox.textField.clear()
    }

    // "Unwatched first" was chosen for the videos, then they were grouped (here or elsewhere):
    // the groups and the folders can not sort by play count, the first entry of the page is used
    Connections {
        target: root.leaf?.sort ?? null

        function onCriteriaChanged() {
            root._dropUnsupportedSort()
        }
    }

    onSortOptionsChanged: _dropUnsupportedSort()

    // Functions

    function back() {
        if (History.previousEmpty)
            return
        forwardStack.noteBack(History.viewPath, _propsOf(History.viewProp))
        History.previous(Qt.OtherFocusReason)
    }

    function forward() {
        const next = forwardStack.take()
        if (next)
            History.push(next.path, next.props, Qt.OtherFocusReason)
    }

    function _propsOf(map): var {
        const out = {}
        if (map)
            for (const key of map.keys())
                out[key] = map[key]
        return out
    }

    function _activateCrumb(index: int, reason: int) {
        const crumb = root.crumbs[index]
        if (!crumb)
            return
        if (crumb.tree)
            History.push(["network", "browse"], {tree: crumb.tree}, reason)
        else
            History.push(crumb.path, reason)
    }

    // the grid and the table of the stock pages follow the global MainCtx.gridView; the compact
    // list is drawn over the page and leaves it as it is
    function _applyViewMode() {
        if (root.compact)
            return
        if (root.viewMode === "grid")
            MainCtx.gridView = true
        else if (root.viewMode === "details")
            MainCtx.gridView = false
    }

    function _dropUnsupportedSort() {
        const sort = root.leaf?.sort
        if (!sort || sort.criteria !== "playcount" || root.sortOptions.length === 0)
            return
        if (!root.sortOptions.some((option) => option.criteria === "playcount"))
            sort.criteria = root.sortOptions[0].criteria
    }

    // The entries a page has and the others do not are put into their menu when it opens, and
    // taken out otherwise (an entry of a menu is never hidden, see RedesignMenu._wantedHeight):
    // the grouping of the videos (the stock video pages have a sort menu with it, SortMenuVideo)
    // and the indexing of a network folder (the button of the stock network header).
    // `entry` is a submenu when `isMenu` (as MainMenu._syncRecentEntry does), else an item;
    // `index` < 0 puts it at the end
    function _syncEntry(menu, entry, isMenu, wanted, index) {
        let at = -1
        for (let i = 0; i < menu.count; ++i) {
            const item = menu.itemAt(i)
            if (isMenu ? (item?.subMenu === entry) : (item === entry)) {
                at = i
                break
            }
        }
        const where = (index < 0) ? menu.count : index
        if (wanted && at < 0) {
            if (isMenu)
                menu.insertMenu(where, entry)
            else
                menu.insertItem(where, entry)
        } else if (!wanted && at >= 0) {
            if (isMenu)
                menu.takeMenu(at)
            else
                menu.takeItem(at)
        }
    }

    function _openSortMenu() {
        // the class of the stock sort menu of the page (QObject's toString), the type is not
        // registered without a media library
        const groups = String(root.leaf?.sortMenu ?? "").startsWith("SortMenuVideo")
        _syncEntry(sortMenu, groupingMenu, true, groups, -1)
        _openMenu(sortMenu, sortButton)
    }

    function _openMoreMenu() {
        _syncEntry(moreMenu, indexEntry, false, !!root.leaf?.model?.canBeIndexed, 0)
        _openMenu(moreMenu, moreButton)
    }

    function _openMenu(menu, button) {
        const pos = button.mapToItem(menu.parent, 0, button.height)
        // see RedesignMenu.anchorTop: set before popup()
        menu.anchorTop = button.mapToItem(null, 0, button.height).y
        menu.popup(pos.x, pos.y)
    }

    // the text of a menu entry, marked when it is the current choice (the entries have no check mark)
    function _marked(text: string, current: bool): string {
        return current ? text + "  •" : text // •
    }

    function _sortLabel(option): string {
        const sort = root.leaf?.sort
        if (!sort || option.order !== undefined || !LibraryOptions.isCurrentSort(option, sort.criteria, sort.order))
            return option.label
        return option.label + ((sort.order === Qt.AscendingOrder) ? "  ↑" : "  ↓") // ↑ ↓
    }

    // Children

    QtCore.Settings {
        id: persisted

        category: "redesign"

        property string viewMode: "grid"
    }

    ForwardStack {
        id: forwardStack
    }

    Connections {
        target: History

        function onNavigate(focusReason) {
            forwardStack.noteNavigation()
        }
    }

    // the header of the stock page is replaced by this one
    Binding {
        target: root.leaf?.header ?? null
        property: "visible"
        value: false
        when: !!root.leaf?.header
        restoreMode: Binding.RestoreBindingOrValue
    }

    // what is typed in the search box filters the page
    Binding {
        target: root.leaf?.search ?? null
        property: "pattern"
        value: searchBox.searchPattern
        when: !!root.leaf?.search
    }

    ColorContext {
        id: theme

        colorSet: ColorContext.Window
    }

    RowLayout {
        anchors.fill: parent

        spacing: 0

        HeaderButton {
            text: VLCIcons.back
            description: qsTr("Back")
            enabled: !History.previousEmpty

            onClicked: root.back()
        }

        HeaderButton {
            // the back arrow, turned
            rotation: 180

            text: VLCIcons.back
            description: qsTr("Forward")
            enabled: !forwardStack.empty

            onClicked: root.forward()
        }

        Breadcrumbs {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: RedesignStyle.spacingXS

            crumbs: root.crumbs

            onCrumbActivated: (index, reason) => root._activateCrumb(index, reason)
        }

        Text {
            Layout.leftMargin: RedesignStyle.spacingS
            Layout.rightMargin: RedesignStyle.spacingS

            visible: !root.compact && root.itemCount >= 0

            // not the plural form of qsTr ("%n item(s)"): it gives an empty text in the app
            text: (root.itemCount === 1) ? qsTr("1 item") : qsTr("%1 items").arg(root.itemCount)
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.fontSize_small
            textFormat: Text.PlainText

            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        HeaderButton {
            visible: !root.compact && (MainCtx.hasGridListMode || !!root.content)

            text: (root.viewMode === "grid") ? VLCIcons.grid : VLCIcons.list
            description: {
                switch (root.viewMode) {
                case "list":
                    return qsTr("View: list (switch to details)")
                case "details":
                    return qsTr("View: details (switch to grid)")
                default:
                    return qsTr("View: grid (switch to list)")
                }
            }

            onClicked: persisted.viewMode = LibraryOptions.nextViewMode(root.viewMode)
        }

        HeaderButton {
            id: sortButton

            visible: root.sortOptions.length > 0 && !!root.leaf?.sort

            text: VLCIcons.topbar_sort
            description: qsTr("Sort")

            onClicked: root._openSortMenu()
        }

        Widgets.SearchBox {
            id: searchBox

            Layout.fillHeight: true

            visible: !root.compact && !!root.leaf?.search?.available
        }

        HeaderButton {
            id: moreButton

            text: VLCIcons.ellipsis
            description: qsTr("More")

            onClicked: root._openMoreMenu()
        }
    }

    RedesignMenu {
        id: sortMenu

        accessibleName: qsTr("Sort")
    }

    Instantiator {
        model: root.sortOptions

        delegate: RedesignMenuItem {
            required property var modelData

            text: root._sortLabel(modelData)

            onTriggered: {
                const sort = root.leaf?.sort
                if (!sort)
                    return
                const next = LibraryOptions.chooseSort(modelData, sort.criteria, sort.order)
                sort.criteria = next.criteria
                sort.order = next.order
            }
        }

        onObjectAdded: (index, object) => sortMenu.insertItem(index, object)
        onObjectRemoved: (index, object) => sortMenu.removeItem(object)
    }

    // put into sortMenu by _openSortMenu (a property: a child of the header would be in no menu,
    // a child of the menu would always be in it)
    readonly property RedesignMenu groupingMenu: RedesignMenu {
        title: qsTr("Group videos")

        RedesignMenuItem {
            text: root._marked(qsTr("Do not group"), MainCtx.grouping === MainCtx.GROUPING_NONE)

            onTriggered: MainCtx.grouping = MainCtx.GROUPING_NONE
        }

        RedesignMenuItem {
            text: root._marked(qsTr("By name"), MainCtx.grouping === MainCtx.GROUPING_NAME)

            onTriggered: MainCtx.grouping = MainCtx.GROUPING_NAME
        }

        RedesignMenuItem {
            text: root._marked(qsTr("By folder"), MainCtx.grouping === MainCtx.GROUPING_FOLDER)

            onTriggered: MainCtx.grouping = MainCtx.GROUPING_FOLDER
        }
    }

    // put into moreMenu by _openMoreMenu on a network folder that the library can index
    readonly property RedesignMenuItem indexEntry: RedesignMenuItem {
        text: root.leaf?.model?.indexed ? qsTr("Remove this folder from the library")
                                        : qsTr("Add this folder to the library")

        onTriggered: {
            const model = root.leaf?.model
            if (model)
                model.indexed = !model.indexed
        }
    }

    RedesignMenu {
        id: moreMenu

        accessibleName: qsTr("More")

        RedesignMenuItem {
            text: qsTr("Add files to the queue…")

            onTriggered: Qt.callLater(() => DialogsProvider.simpleOpenDialog(false))
        }

        RedesignMenuItem {
            text: qsTr("Add a folder to the queue…")

            onTriggered: Qt.callLater(() => DialogsProvider.PLAppendDir())
        }

        RedesignMenuItem {
            // the folders of the media library are set in the Library page of the settings
            enabled: MainCtx.mediaLibraryAvailable

            text: qsTr("Add a folder to the library…")

            onTriggered: ShellActions.settingsRequested("library")
        }
    }

    component HeaderButton: Widgets.IconToolButton {
        Layout.fillHeight: true
        Layout.preferredWidth: RedesignStyle.titleBarHeight

        font.pixelSize: VLCStyle.icon_normal
    }
}
