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
import QtQuick.Window

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Style
import VLC.Util
import VLC.Redesign

/**
 * @brief The now-playing view of media without video: a large rounded artwork over a blurred
 * copy of itself, and the caption "<title> - <artist>" below it.
 *
 * The Stage loads it while the shell shows the media (watch, immersive) and there is no video.
 * Without artwork the artwork square shows the album placeholder and the backdrop is plain.
 * The view is not focusable; the keys are handled by the shell.
 *
 * Synced lyrics (LyricsPanel), when the media has some, take the right half of a wide view (the
 * artwork and the caption are centered in the left half) or the lower part of a tall one. A view
 * too small for them stays as without lyrics.
 */
Item {
    id: root

    // Properties

    // the artwork is a real image (not the placeholder)
    readonly property bool hasArtwork: !!(Player.artwork && Player.artwork.toString()) && !root._artworkFailed

    readonly property url artworkSource: hasArtwork ? VLCAccessImage.uri(Player.artwork)
                                                    : VLCStyle.noArtAlbumCover

    // "<title> - <artist>" (see MediaText.captionText)
    readonly property string caption: MediaText.captionText(Player.title, Player.name,
                                                            Player.url.toString(), Player.artist)

    // part of the smaller side of the view that the artwork takes
    readonly property real artworkFraction: 0.6

    readonly property real _margin: RedesignStyle.spacingXL

    // Where the lyrics are: "side" (right half of a wide view), "below" (lower part of a tall
    // view) or "none" (no lyrics, or no room for them)
    readonly property string lyricsPlacement: {
        if (!lyricsPanel.available)
            return "none"
        if (root.width >= root.height * 1.3 && root.width / 2 >= RedesignStyle.panelWidthMin)
            return "side"
        if (root.width < root.height * 1.3 && root.height * (1 - root.lyricsArtworkShare) >= root.lyricsMinHeight)
            return "below"
        return "none"
    }

    // share of the height that the artwork and the caption keep when the lyrics are below them
    readonly property real lyricsArtworkShare: 0.5

    // the lyrics are not shown when they would have less room than this
    readonly property real lyricsMinHeight: RedesignStyle.panelWidthMin / 2

    // the area of the artwork and the caption (the whole view without lyrics)
    readonly property real _artAreaWidth: root.lyricsPlacement === "side" ? root.width / 2 : root.width
    readonly property real _artAreaHeight: root.lyricsPlacement === "below"
                                           ? root.height * root.lyricsArtworkShare : root.height

    // the artwork of the current media could not be loaded (gone, broken): the placeholder is shown
    property bool _artworkFailed: false

    // The artwork never overflows: it is a fraction of the smaller side, and it leaves room for
    // the caption and the margins, whatever the size of the view.
    readonly property real artworkSide: Math.max(0, Math.min(
        Math.min(root._artAreaWidth, root._artAreaHeight) * root.artworkFraction,
        root._artAreaWidth - 2 * root._margin,
        root._artAreaHeight - captionLabel.implicitHeight - RedesignStyle.spacingL - 2 * root._margin))

    // Decode size of the artwork: never 0 (which would decode the full image) and quantized, so
    // that resizing the view does not decode the cover again (and re-trigger the blur) at each step
    readonly property int _decodeSize: Math.max(64, Helpers.alignUp(
        root.artworkSide * (MainCtx.effectiveDevicePixelRatio(Window.window) || 1.0), 64))

    // Settings

    clip: true

    // a new media has its own artwork
    Connections {
        target: Player

        function onCurrentMetaChanged() {
            root._artworkFailed = false
        }
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

    // The backdrop. Same usage as the background of the audio player (Player.qml): the blur needs
    // the shader pipeline (`available`), without it the plain background above is what is seen.
    Widgets.DualKawaseBlur {
        id: blurredBackground

        // Six pass is free here since the intermediate layers are released by unsetting `live`
        // (see `liveTimer`)
        mode: Widgets.DualKawaseBlur.Mode.SixPass
        radius: 2

        // turned off when everything settles (`liveTimer`), which releases the intermediate layers
        live: true

        // destination and source aspect ratios
        readonly property real dar: parent.width / Math.max(1, parent.height)
        readonly property real sar: (_texture && _texture.implicitHeight > 0)
                                    ? (_texture.implicitWidth / _texture.implicitHeight) : 1

        readonly property Item _texture: artwork.sourceTextureProviderItem

        anchors.centerIn: parent
        width: (sar < dar) ? parent.width : parent.height * sar
        height: (sar < dar) ? parent.width / sar : parent.height

        visible: available && root.hasArtwork

        source: root.hasArtwork ? textureProviderIndirection : null

        postprocess: true
        tint: theme.palette.isDark ? "black" : "white"
        tintStrength: 0.5
        backgroundColor: theme.bg.primary

        // The window clips the content anyway, this saves video memory
        viewportRect: Qt.rect((width - parent.width) / 2, (height - parent.height) / 2,
                              parent.width, parent.height)

        sourceTextureProviderObserver.onTextureChanged: {
            liveTimer.transientTurnOnLive()
        }

        TextureProviderIndirection {
            id: textureProviderIndirection

            // As in Player.qml: `QSGTextureView` works around a Qt bug that breaks the
            // sampling of mipmapped textures, and costs virtually nothing
            source: artwork.sourceTextureProviderItem
        }

        Component.onCompleted: {
            // The layers depend on the size of the effect: while the view is resized, `live` is
            // turned on for a moment, then off again
            widthChanged.connect(liveTimer, liveTimer.transientTurnOnLive)
            heightChanged.connect(liveTimer, liveTimer.transientTurnOnLive)

            // in case the observer never signals a texture change
            liveTimer.transientTurnOnLive()
        }

        Timer {
            id: liveTimer

            repeat: false
            interval: VLCStyle.duration_humanMoment

            function transientTurnOnLive() {
                if (!blurredBackground.sourceTextureIsValid)
                    return
                blurredBackground.live = true
                liveTimer.restart()
            }

            onTriggered: {
                blurredBackground.live = false
            }
        }
    }

    Widgets.ImageExt {
        id: artwork

        // artwork and caption together are centered in their area
        x: (root._artAreaWidth - width) / 2
        y: Math.max(root._margin, (root._artAreaHeight - root.artworkSide - RedesignStyle.spacingL
                                   - captionLabel.implicitHeight) / 2)

        width: root.artworkSide
        height: root.artworkSide

        radius: RedesignStyle.radiusL
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        source: root.artworkSource
        sourceSize: Qt.size(root._decodeSize, root._decodeSize)

        onStatusChanged: {
            if (status === Image.Error)
                root._artworkFailed = true
        }

        Accessible.role: Accessible.Graphic
        Accessible.name: root.caption || qsTr("Cover")
    }

    Text {
        id: captionLabel

        anchors {
            top: artwork.bottom
            topMargin: RedesignStyle.spacingL
            horizontalCenter: artwork.horizontalCenter
        }

        width: Math.max(0, root._artAreaWidth - 2 * root._margin)

        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
        text: root.caption
        font.pixelSize: VLCStyle.fontSize_xlarge
        color: theme.fg.primary
    }

    LyricsPanel {
        id: lyricsPanel

        visible: root.lyricsPlacement !== "none"

        x: root.lyricsPlacement === "side" ? root.width / 2 : root._margin
        y: root.lyricsPlacement === "side" ? root._margin : root._artAreaHeight
        width: root.lyricsPlacement === "side" ? root.width / 2 - root._margin
                                               : Math.max(0, root.width - 2 * root._margin)
        height: Math.max(0, root.lyricsPlacement === "side" ? root.height - 2 * root._margin
                                                            : root.height - root._artAreaHeight - root._margin)
    }
}
