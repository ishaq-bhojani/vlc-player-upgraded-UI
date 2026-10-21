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
import VLC.Player
import VLC.Playlist
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Redesign

/**
 * @brief The "Add subtitles" dialog, in three modes:
 *
 *  - "current": a subtitle file for the media being played;
 *  - "playlist": the subtitle files of a folder for the media of the play queue, paired by name
 *    (SubtitleMatch.pair), shown for review, then attached;
 *  - "folder": the videos of a folder are paired with the subtitle files of the same folder,
 *    shown for review, appended to the play queue and given their subtitle.
 *
 * Whatever is attached is also saved for its media in the media library (when there is one), so
 * that the next playback of the media finds it (SubtitleAttacher). The dialog does not name any
 * type of the media library: without one it works the same and only does not save.
 *
 * `requestedMode` ("current", "playlist", "folder", or "" to let the dialog choose: the media being
 * played, else the queue, else a folder) is set by DialogHost.qml before it opens the dialog; the
 * mode can be changed in the dialog. Everything is reset each time the dialog opens.
 */
RedesignModalDialog {
    id: root

    // Properties

    //! the mode to open on, see above
    property string requestedMode: ""

    //! "current", "playlist" or "folder"
    property string mode: "current"

    //! the media being played has an address
    readonly property bool hasCurrent: Player.url.toString() !== ""

    //! the subtitle file chosen in the "current" mode, "" for none
    property string subtitleFile: ""

    //! the folder chosen in the "playlist" and "folder" modes (a native path), "" for none
    property string folderPath: ""

    //! what SubtitleAttacher.listFolder said of the folder: {videos, subtitles, truncated, error}
    property var folderInfo: null

    //! the addresses of the media of the queue (the "playlist" mode)
    property var queueUrls: []

    //! what went wrong, "" for nothing
    property string errorText: ""

    //! the folder is being read (on a worker thread): the answer is waited for, Add is off
    property bool readingFolder: false

    // the request whose answer is waited for; an answer for another one is stale
    property int _folderRequest: -1

    // the folder whose videos this dialog has already put in the queue (folder mode): they are
    // never appended a second time, a retry only attaches
    property string _appendedFolder: ""
    property int _appendedFirst: 0

    //! [{video, videoUrl, subtitle, subtitleUrl}] for the "playlist" and "folder" modes: one per
    //! video, in order; `subtitle` is "" when none matches
    readonly property var rows: _buildRows()

    //! the number of rows that have a subtitle
    readonly property int matched: rows.filter(row => row.subtitle !== "").length

    //! the Add button can be used
    readonly property bool valid: mode === "current" ? (hasCurrent && subtitleFile !== "")
                                                     : (!readingFolder && matched > 0)

    // Functions

    function _buildRows() {
        if (mode === "current" || !folderInfo)
            return []

        const subtitles = folderInfo.subtitles ?? []
        const subtitleUrls = {}
        for (const entry of subtitles)
            subtitleUrls[entry.name] = entry.url

        let videoNames
        let videoUrls
        if (mode === "playlist") {
            videoUrls = queueUrls
            videoNames = queueUrls.map(url => SubtitleMatch.fileName(url))
        } else {
            videoUrls = (folderInfo.videos ?? []).map(entry => entry.url)
            videoNames = (folderInfo.videos ?? []).map(entry => entry.name)
        }

        return SubtitleMatch.pair(videoNames, subtitles.map(entry => entry.name)).map((pair, index) => ({
            video: pair.video,
            videoUrl: videoUrls[index],
            subtitle: pair.subtitle,
            subtitleUrl: pair.subtitle !== "" ? subtitleUrls[pair.subtitle] : ""
        }))
    }

    function _subtitleFilter(): string {
        const patterns = SubtitleAttacher.subtitleExtensions.map(extension => "*." + extension).join(" ")
        return qsTr("Subtitle files") + " (" + patterns + ");;" + qsTr("All files") + " (*)"
    }

    //! starts over in `newMode`
    function _setMode(newMode: string) {
        mode = newMode
        subtitleFile = ""
        folderPath = ""
        folderInfo = null
        errorText = ""
        _cancelFolderRequest()
        queueUrls = newMode === "playlist" ? SubtitleAttacher.playlistUrls() : []

        // the subtitles of a queue are most often next to its first video
        if (newMode === "playlist" && queueUrls.length > 0) {
            const folder = SubtitleAttacher.folderOf(queueUrls[0])
            if (folder !== "")
                _listFolder(folder)
        }
    }

    //! the answer of a request in flight is not wanted anymore
    function _cancelFolderRequest() {
        _folderRequest = -1
        readingFolder = false
    }

    function _start() {
        _appendedFolder = ""
        let wanted = requestedMode
        if (wanted !== "current" && wanted !== "playlist" && wanted !== "folder")
            wanted = hasCurrent ? "current" : (MainPlaylistController.count > 0 ? "playlist" : "folder")
        _setMode(wanted)
    }

    //! Reads the folder on a worker thread (a slow disk or share must not stop the interface);
    //! _onFolderListed takes the answer.
    function _listFolder(path: string) {
        folderPath = path
        folderInfo = null
        errorText = ""
        readingFolder = true
        _folderRequest = SubtitleAttacher.requestFolder(SettingsBridge.localFileUrl(path))
    }

    function _onFolderListed(requestId: int, result) {
        if (requestId !== _folderRequest)
            return // an older folder, or the dialog was closed or changed mode
        readingFolder = false
        _folderRequest = -1
        folderInfo = result
        errorText = result.error ?? ""
        if (valid)
            addButton.forceActiveFocus()
    }

    function choose() {
        errorText = ""
        if (mode === "current") {
            const start = SubtitleAttacher.folderOf(Player.url)
            const picked = SettingsBridge.pickFile(qsTr("Choose a subtitle file"), start, _subtitleFilter())
            if (picked !== "")
                subtitleFile = picked
        } else {
            const start = folderPath !== "" ? folderPath
                          : (queueUrls.length > 0 ? SubtitleAttacher.folderOf(queueUrls[0]) : "")
            const picked = SettingsBridge.pickFolder(mode === "playlist" ? qsTr("Choose the folder with the subtitles")
                                                                         : qsTr("Choose a folder with videos"), start)
            if (picked !== "")
                _listFolder(picked)
        }
        if (valid)
            addButton.forceActiveFocus()
    }

    //! attaches what is chosen and closes; on a failure the dialog stays and says so
    function submit() {
        if (!valid)
            return

        if (mode === "current") {
            if (SubtitleAttacher.attachToCurrent(SettingsBridge.localFileUrl(subtitleFile))) {
                root.close()
            } else {
                errorText = qsTr("The player did not accept this subtitle file.")
            }
            return
        }

        // The folder mode puts its videos at the end of the queue first, once: when that worked and
        // the subtitles did not, a second try only attaches (the videos are in the queue).
        let first = 0
        if (mode === "folder") {
            if (_appendedFolder === folderPath) {
                first = _appendedFirst
            } else {
                // the position is read from the queue itself, not from a count that may not have
                // caught up, right before the append
                first = SubtitleAttacher.playlistUrls().length
                MainPlaylistController.append(rows.map(row => row.videoUrl))
                _appendedFolder = folderPath
                _appendedFirst = first
            }
        }

        const pairs = []
        rows.forEach((row, index) => {
            if (row.subtitle !== "")
                pairs.push({index: first + index, subtitle: row.subtitleUrl, video: row.videoUrl})
        })

        if (SubtitleAttacher.attachToPlaylist(pairs) > 0) {
            root.close()
        } else if (mode === "folder") {
            errorText = _appendedFolder === folderPath
                        ? qsTr("The videos were added to the play queue, but the subtitles were not. Try Add again to add only the subtitles.")
                        : qsTr("No subtitle could be added.")
        } else {
            errorText = qsTr("No subtitle could be added: the play queue changed.")
        }
    }

    // Settings

    title: qsTr("Add subtitles")
    bodyWidth: Math.min(VLCStyle.dp(560, VLCStyle.scale),
                        Math.max(VLCStyle.dp(320, VLCStyle.scale),
                                 (T.Overlay.overlay ? T.Overlay.overlay.width : VLCStyle.dp(560, VLCStyle.scale))
                                 - 2 * (root.margins + root.padding)))

    onAboutToShow: {
        root._start()
        modeControl.forceActiveFocus()
    }

    // a folder still being read is of no use to a closed dialog
    onClosed: _cancelFolderRequest()

    Connections {
        target: SubtitleAttacher

        function onFolderListed(requestId, result) {
            root._onFolderListed(requestId, result)
        }
    }

    // Children

    SegmentedControl {
        id: modeControl

        Layout.fillWidth: true

        label: qsTr("Add subtitles to")
        model: [
            {text: qsTr("This file"), value: "current"},
            {text: qsTr("Play queue"), value: "playlist"},
            {text: qsTr("Folder"), value: "folder"}
        ]
        current: root.mode

        onPicked: (value) => root._setMode(value)
    }

    Text {
        Layout.fillWidth: true

        text: root.mode === "current"
              ? (root.hasCurrent ? qsTr("Subtitle file for \"%1\"").arg(Player.name)
                                 : qsTr("Nothing is playing. Play a video first."))
              : root.mode === "playlist"
                ? (root.queueUrls.length > 0
                   ? qsTr("Choose the folder with the subtitles of the %n video(s) in the play queue.", "", root.queueUrls.length)
                   : qsTr("The play queue is empty."))
                : qsTr("Choose a folder: its videos are added to the play queue with the subtitle files that have the same name.")

        color: root.colorContext.fg.secondary
        font.pixelSize: VLCStyle.fontSize_small
        wrapMode: Text.WordWrap
    }

    // the library keeps only what it knows
    Text {
        Layout.fillWidth: true

        visible: MainCtx.mediaLibraryAvailable

        text: qsTr("Subtitles are remembered for the videos of your library that are stored on this computer, and are added again when those videos play.")
        color: root.colorContext.fg.secondary
        font.pixelSize: VLCStyle.fontSize_small
        wrapMode: Text.WordWrap
    }

    // what is chosen, and the button to choose
    RowLayout {
        Layout.fillWidth: true

        spacing: RedesignStyle.spacingS

        Text {
            id: chosenText

            Layout.fillWidth: true

            readonly property string chosen: root.mode === "current" ? root.subtitleFile : root.folderPath

            text: chosen !== "" ? chosen : (root.mode === "current" ? qsTr("No file chosen") : qsTr("No folder chosen"))
            color: chosen !== "" ? root.colorContext.fg.primary : root.colorContext.fg.secondary
            font.pixelSize: VLCStyle.fontSize_normal
            elide: Text.ElideMiddle

            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        Widgets.ButtonExt {
            id: chooseButton

            text: root.mode === "current" ? qsTr("Choose file…") : qsTr("Choose folder…")

            enabled: root.mode !== "current" || root.hasCurrent

            Accessible.name: root.mode === "current" ? qsTr("Choose a subtitle file") : qsTr("Choose a folder")

            onClicked: root.choose()
        }
    }

    // the answer of the folder or the player
    Text {
        Layout.fillWidth: true

        visible: root.errorText !== ""

        text: root.errorText
        color: root.colorContext.fg.primary
        font.pixelSize: VLCStyle.fontSize_normal
        wrapMode: Text.WordWrap

        Accessible.role: Accessible.AlertMessage
        Accessible.name: text
    }

    // the folder is being read
    Text {
        Layout.fillWidth: true

        visible: root.readingFolder

        text: qsTr("Reading the folder�")
        color: root.colorContext.fg.secondary
        font.pixelSize: VLCStyle.fontSize_normal

        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }

    // the review: which subtitle goes to which video
    ColumnLayout {
        Layout.fillWidth: true

        visible: root.mode !== "current" && root.folderInfo !== null && root.errorText === ""
        spacing: RedesignStyle.spacingXS

        Text {
            Layout.fillWidth: true

            text: root.rows.length === 0
                  ? (root.mode === "folder" ? qsTr("There is no video in this folder.") : qsTr("The play queue is empty."))
                  : qsTr("%1 of %2 videos have a subtitle.").arg(root.matched).arg(root.rows.length)
                    + (root.folderInfo?.truncated ? " " + qsTr("Only the first files of the folder are listed.") : "")
            color: root.colorContext.fg.primary
            font.pixelSize: VLCStyle.fontSize_normal
            wrapMode: Text.WordWrap

            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        RowLayout {
            Layout.fillWidth: true

            visible: root.rows.length > 0
            spacing: RedesignStyle.spacingM

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 1

                text: qsTr("Video")
                color: root.colorContext.fg.secondary
                font.pixelSize: VLCStyle.fontSize_small

                Accessible.ignored: true
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 1

                text: qsTr("Subtitle")
                color: root.colorContext.fg.secondary
                font.pixelSize: VLCStyle.fontSize_small

                Accessible.ignored: true
            }
        }

        ListView {
            id: reviewList

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, VLCStyle.dp(220, VLCStyle.scale))

            visible: root.rows.length > 0

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            activeFocusOnTab: true
            keyNavigationEnabled: true
            model: root.rows

            Accessible.role: Accessible.List
            Accessible.name: qsTr("Subtitles found for the videos")

            T.ScrollBar.vertical: Widgets.ScrollBarExt {}

            delegate: Item {
                id: rowItem

                required property var modelData
                required property int index

                width: ListView.view ? ListView.view.width : 0
                height: Math.max(VLCStyle.dp(32, VLCStyle.scale), rowLayout.implicitHeight + RedesignStyle.spacingS)

                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.subtitle !== ""
                                 ? qsTr("%1, subtitle %2").arg(modelData.video).arg(modelData.subtitle)
                                 : qsTr("%1, no subtitle found").arg(modelData.video)

                Rectangle {
                    anchors.fill: parent

                    visible: rowItem.ListView.isCurrentItem && reviewList.activeFocus
                    radius: RedesignStyle.radiusS
                    color: "transparent"
                    border.width: VLCStyle.dp(2, VLCStyle.scale)
                    border.color: root.colorContext.visualFocus
                }

                RowLayout {
                    id: rowLayout

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: RedesignStyle.spacingS
                        rightMargin: RedesignStyle.spacingS
                    }

                    spacing: RedesignStyle.spacingM

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1

                        text: rowItem.modelData.video
                        color: root.colorContext.fg.primary
                        font.pixelSize: VLCStyle.fontSize_normal
                        elide: Text.ElideMiddle

                        Accessible.ignored: true
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1

                        text: rowItem.modelData.subtitle !== "" ? rowItem.modelData.subtitle : qsTr("No subtitle found")
                        color: rowItem.modelData.subtitle !== "" ? root.colorContext.fg.primary : root.colorContext.fg.secondary
                        font.pixelSize: VLCStyle.fontSize_normal
                        elide: Text.ElideMiddle

                        Accessible.ignored: true
                    }
                }
            }
        }
    }

    footerItems: [
        Widgets.ButtonExt {
            text: qsTr("Cancel")

            onClicked: root.close()
        },

        Widgets.ButtonExt {
            id: addButton

            text: qsTr("Add")

            enabled: root.valid
            font.bold: true

            colorContext.colorSet: ColorContext.ButtonAccent

            Accessible.name: root.mode === "folder" ? qsTr("Add the videos and their subtitles to the play queue")
                                                    : qsTr("Add the subtitles")

            onClicked: root.submit()
        }
    ]
}
