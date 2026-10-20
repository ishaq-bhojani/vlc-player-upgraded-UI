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

import VLC.MainInterface
import VLC.Playlist
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets
import VLC.Redesign

/**
 * @brief The "Open network stream" dialog: an address field, and the addresses played lately.
 *
 * Play (or Enter) appends the address to the play queue and plays it, see `submit`. The address is
 * what StreamUrl.normalize makes of the text, so "example.org/a.m3u8" is played as
 * "https://example.org/a.m3u8"; Play is disabled while there is nothing to play.
 *
 * It works without a media library. The recent addresses come from the media library and are a
 * separate component (RecentStreams.qml) that is loaded only with one, because it names types that
 * are not registered without. The dialog itself remembers nothing.
 *
 * It does not host itself anywhere: DialogHost.qml creates it and opens it.
 */
RedesignModalDialog {
    id: root

    // Properties

    //! the address field, to fill it (e.g. with the clipboard)
    property alias text: urlField.text

    //! what the text plays as ("" when there is nothing)
    readonly property string url: StreamUrl.normalize(urlField.text)

    readonly property bool valid: StreamUrl.isValid(urlField.text)

    // Functions

    //! Plays `url`, an address that is already normalized, and closes. The one way out of the
    //! dialog that plays something: anything that has to treat some addresses differently (websites
    //! played through a helper tool) takes the address here.
    function submit(url) {
        MainPlaylistController.append([url], true)
        root.close()
    }

    //! plays the text of the field if it is valid, else nothing happens
    function playText() {
        if (!root.valid)
            return
        root.submit(root.url)
    }

    // Settings

    title: qsTr("Open network stream")
    bodyWidth: VLCStyle.dp(480, VLCStyle.scale)

    // the field gets the keyboard each time the dialog opens
    onAboutToShow: urlField.forceActiveFocus()

    // Children

    Text {
        Layout.fillWidth: true

        text: qsTr("Enter the address of a stream or of a file on the network.")

        color: root.colorContext.fg.secondary
        font.pixelSize: VLCStyle.fontSize_small
        wrapMode: Text.WordWrap
    }

    Widgets.TextFieldExt {
        id: urlField

        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)

        focus: true
        selectByMouse: true
        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText

        radius: RedesignStyle.radiusM

        placeholderText: qsTr("https://example.org/stream.m3u8")

        Accessible.role: Accessible.EditableText
        Accessible.name: qsTr("Stream address")
        Accessible.description: qsTr("The address to play, for example https://example.org/stream.m3u8")

        // A pasted block of text plays its first line: the field keeps that line only.
        onTextEdited: {
            if (/[\r\n\u2028\u2029]/.test(urlField.text))
                urlField.text = StreamUrl.firstLine(urlField.text)
        }

        // Enter plays, only when there is something to play
        onAccepted: root.playText()
    }

    // the recent addresses: only with a media library
    Loader {
        id: recentLoader

        Layout.fillWidth: true

        active: MainCtx.mediaLibraryAvailable

        // by name: the file names types of the media library (see RecentStreams.qml)
        source: "RecentStreams.qml"

        // nothing to show while the library has no address
        visible: status === Loader.Ready && (item?.count ?? 0) > 0
    }

    Connections {
        target: recentLoader.item

        // a click puts the address in the field (the keys stay in the list), a double click or
        // Enter plays it
        function onSelected(address) {
            urlField.text = address
        }

        function onActivated(address) {
            root.submit(StreamUrl.normalize(address))
        }
    }

    footerItems: [
        Widgets.ButtonExt {
            text: qsTr("Cancel")

            onClicked: root.close()
        },

        Widgets.ButtonExt {
            id: playButton

            text: qsTr("Play")

            enabled: root.valid
            font.bold: true

            colorContext.colorSet: ColorContext.ButtonAccent

            Accessible.name: qsTr("Play the stream")

            onClicked: root.playText()
        }
    ]
}
