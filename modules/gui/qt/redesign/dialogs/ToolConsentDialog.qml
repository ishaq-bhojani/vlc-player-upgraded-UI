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

import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets
import VLC.Redesign

/**
 * @brief The consent dialog of the website features (spec 12.1): Vireo downloads yt-dlp (and
 * ffmpeg for downloads) from their official GitHub releases, after the user agreed.
 *
 * The sizes come from the manifest (ToolManager.downloadSize). "Allow" stores the consent
 * (ToolManager.consentGiven) and starts the installation of the tools (ToolManager.ensure);
 * "Not now" only closes: the feature stays off, Settings > Network can enable it later.
 *
 * The owner opens it with open() the first time a website link is played or Download is pressed.
 * It does not host itself anywhere: the shell that plays web links creates it.
 */
RedesignModalDialog {
    id: root

    // Properties

    // ffmpeg is needed too (downloads merge the audio and the video streams); playback needs yt-dlp only
    property bool needsFfmpeg: false

    // the tools to install, in the order of the text
    readonly property var tools: needsFfmpeg ? ["yt-dlp", "ffmpeg"] : ["yt-dlp"]

    // Signals

    // the user allowed the downloads, the installation of `tools` is started
    signal allowed()

    // the user declined
    signal declined()

    // Functions

    function formatSize(bytes) {
        if (bytes <= 0)
            return ""
        return qsTr("%1 MB").arg(Math.max(1, Math.round(bytes / 1048576)))
    }

    function toolLine(name) {
        const size = formatSize(ToolManager.downloadSize(name))
        return size !== "" ? qsTr("%1 (%2)").arg(name).arg(size) : name
    }

    function allow() {
        ToolManager.consentGiven = true
        for (const name of tools)
            ToolManager.ensure(name)
        root.close()
        allowed()
    }

    function decline() {
        root.close()
        declined()
    }

    // Settings

    title: qsTr("Download helper tools?")
    bodyWidth: VLCStyle.dp(420, VLCStyle.scale)

    // Esc counts as "Not now"
    onRejected: declined()

    // Children

    Text {
        Layout.fillWidth: true

        text: qsTr("To play and download videos from websites, Vireo downloads %1 from their official GitHub releases into your user data folder (vireo/tools). The files are checked against a fixed checksum before they are used.").arg(root.tools.join(qsTr(" and ")))

        color: root.colorContext.fg.primary
        font.pixelSize: VLCStyle.fontSize_normal
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.tools

        Text {
            required property string modelData

            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.margin_normal

            text: "• " + root.toolLine(modelData)

            color: root.colorContext.fg.primary
            font.pixelSize: VLCStyle.fontSize_normal
            font.bold: true
        }
    }

    Text {
        Layout.fillWidth: true

        text: qsTr("You are responsible for respecting the terms of each website and copyright law. If you decline, the feature stays off; you can turn it on later in Settings, Network.")

        color: root.colorContext.fg.secondary
        font.pixelSize: VLCStyle.fontSize_small
        wrapMode: Text.WordWrap
    }

    footerItems: [
        Widgets.ButtonExt {
            id: notNowButton

            text: qsTr("Not now")

            onClicked: root.decline()
        },

        Widgets.ButtonExt {
            id: allowButton

            text: qsTr("Allow")

            focus: true
            font.bold: true

            colorContext.colorSet: ColorContext.ButtonAccent

            onClicked: root.allow()
        }
    ]
}
