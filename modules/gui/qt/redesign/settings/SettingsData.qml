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
pragma Singleton
import QtQml

/**
 * @brief What the pages of the settings modal show: the 13 pages in the order of the sidebar and,
 * for each, its rows in the order of docs/redesign/settings-map.md.
 *
 * Pure data (no C++ type is used here), so the search and the Advanced sections share it and a
 * test can load it. A row is an object with a `kind`:
 * - "setting"      a VLC configuration item: `key`, `hint` (see ControlChooser.controlFor())
 * - "accent"       the accent swatches, `key` is "qt-accent-color"
 * - "theme"        Light / Dark / System (not a configuration item)
 * - "shortcuts"    the entry to the keyboard shortcuts page
 * - "advancedLink" opens the Advanced section of the page
 * - "equalizer"    the equalizer panel (the keys in `keys`)
 * - "effectToggle" a filter switched with Effects: `prop` (the Effects property), `probe` (a
 *                  configuration key of the filter: no such key, no plugin, no row)
 * - "effectSlider" a parameter of an Effects filter: `group` (the Effects map), `name` (its key
 *                  there) and `key` (the configuration item that gives the range and the default)
 * - "filterToken"  a video filter in the `key` list (video-filter): `token`
 * - "replayGain"   the Replay gain choice (None, Track, Album, Measured): the mode `key` plus the
 *                  redesign's flag, through MeasuredGain
 * - "libraryFolders", "extensions", "toolConsent": the three rows that are not configuration items
 * Every row has an `id` (unique in its page, used to scroll to the row of a search result) and a
 * `title` (the label of the rows that are not configuration items).
 *
 * The keys of the rows are the "curated" keys: the Advanced section of a page lists the other
 * options of its VLC subcategories (`subcats`, vlc_config_subcat numbers, include/vlc_plugin.h).
 */
QtObject {
    id: root

    // Row constructors

    function s(key: string, hint: string): var {
        return { kind: "setting", id: key, key: key, hint: hint ?? "" }
    }

    function slider(key: string): var {
        return s(key, "slider")
    }

    function choice(key: string): var {
        return s(key, "choices")
    }

    function special(kind: string, title: string, extra: var): var {
        return Object.assign({ kind: kind, id: kind + ":" + title, title: title }, extra ?? {})
    }

    function toggle(prop: string, title: string, probe: string): var {
        return special("effectToggle", title, { prop: prop, probe: probe })
    }

    function param(group: string, name: string, key: string): var {
        return { kind: "effectSlider", id: key, group: group, name: name, key: key }
    }

    // Data

    //! the groups of the sidebar
    readonly property var groups: [
        { id: "app", title: qsTr("App"), pages: ["general", "interface", "privacy", "controls"] },
        { id: "media", title: qsTr("Media"), pages: ["playback", "video", "audio", "subtitles", "library"] },
        { id: "system", title: qsTr("System"), pages: ["network", "performance", "recording", "extensions"] }
    ]

    //! the pages: id, title, subcats (the VLC subcategories of the Advanced section), rows
    readonly property var pages: [
        {
            id: "general", title: qsTr("General"), subcats: [101], // SUBCAT_INTERFACE_GENERAL
            rows: [
                s("qt-error-dialogs"),
                s("qt-updates-notif"),
                s("file-logging"),
                s("logfile"),
                choice("log-verbose"),
                special("advancedLink", qsTr("Advanced options"),
                        { description: qsTr("Every other option of the general settings.") })
            ]
        },
        {
            id: "interface", title: qsTr("Interface"), subcats: [102], // SUBCAT_INTERFACE_MAIN
            rows: [
                special("theme", qsTr("Theme"), { description: qsTr("Light, dark, or the theme of the system.") }),
                { kind: "accent", id: "qt-accent-color", key: "qt-accent-color" },
                s("qt-system-tray"),
                s("qt-close-to-system-tray"),
                choice("qt-notification"),
                s("qt-start-minimized"),
                s("qt-pause-minimized"),
                s("qt-video-autoresize"),
                s("embedded-video"),
                s("video-deco"),
                s("qt-fs-controller"),
                s("qt-fs-sensitivity"),
                choice("qt-auto-raise"),
                s("one-instance"),
                s("playlist-enqueue"),
                s("one-instance-when-started-from-file"),
                slider("qt-opacity"),
                slider("qt-fs-opacity"),
                slider("qt-interface-scale"),
                s("qt-max-volume"),
                s("qt-pip-mode"),
                s("qt-bgcone")
            ]
        },
        {
            id: "privacy", title: qsTr("Privacy"), subcats: [], // no VLC subcategory is privacy specific
            rows: [
                s("metadata-network-access"),
                s("save-recentplay"),
                s("http-forward-cookies")
            ]
        },
        {
            id: "controls", title: qsTr("Controls"), subcats: [103, 104], // SUBCAT_INTERFACE_CONTROL, SUBCAT_INTERFACE_HOTKEYS
            rows: [
                choice("hotkeys-y-wheel-mode"),
                choice("hotkeys-x-wheel-mode"),
                s("qt-disable-volume-keys"),
                s("volume-step"),
                s("extrashort-jump-size"),
                s("medium-jump-size"),
                s("long-jump-size"),
                special("shortcuts", qsTr("Keyboard shortcuts"),
                        { description: qsTr("Change the keys of the player actions.") })
            ]
        },
        {
            id: "playback", title: qsTr("Playback"), subcats: [401, 701], // SUBCAT_INPUT_GENERAL, SUBCAT_PLAYLIST_GENERAL
            rows: [
                choice("short-jump-size"),
                s("play-and-pause"),
                choice("restore-playback-pos"),
                s("restore-playback-states"),
                s("start-paused"),
                s("playlist-autostart"),
                s("loop"),
                s("repeat"),
                s("random"),
                s("play-and-exit"),
                slider("rate"),
                s("input-fast-seek"),
                choice("preferred-resolution")
            ]
        },
        {
            id: "video", title: qsTr("Video"), subcats: [301, 302, 303, 306], // SUBCAT_VIDEO_GENERAL, SUBCAT_VIDEO_VOUT, SUBCAT_VIDEO_VFILTER, SUBCAT_VIDEO_SPLITTER
            rows: [
                s("video"),
                s("fullscreen"),
                s("video-on-top"),
                choice("vout"),
                choice("dec-dev"),
                choice("deinterlace"),
                choice("deinterlace-mode"),
                s("aspect-ratio"),
                s("autoscale"),
                choice("qt-fullscreen-screennumber"),
                s("video-title-show"),
                choice("video-title-position"),
                s("video-title-timeout"),
                s("osd"),
                s("mouse-hide-timeout"),
                s("snapshot-path"),
                s("snapshot-prefix"),
                choice("snapshot-format"),
                s("snapshot-sequential"),
                choice("d3d11-upscale-mode"),
                choice("d3d11-hdr-mode"),
                param("videoAdjust", "hue", "hue"),
                param("videoAdjust", "brightness", "brightness"),
                param("videoAdjust", "contrast", "contrast"),
                param("videoAdjust", "saturation", "saturation"),
                param("videoAdjust", "gamma", "gamma"),
                slider("sharpen-sigma"),
                slider("gradfun-radius"),
                slider("grain-variance"),
                s("croppadd-croptop"),
                s("croppadd-cropbottom"),
                s("croppadd-cropleft"),
                s("croppadd-cropright"),
                s("extract-component"),
                s("colorthres-color"),
                slider("colorthres-saturationthres"),
                slider("colorthres-similaritythres"),
                choice("gradient-mode"),
                s("gradient-color"),
                s("gradient-cartoon"),
                slider("posterize-level"),
                slider("sepia-intensity"),
                special("filterToken", qsTr("Negate colors"), { key: "video-filter", token: "invert" })
            ]
        },
        {
            id: "audio", title: qsTr("Audio"), subcats: [201, 202, 203, 204, 206], // SUBCAT_AUDIO_GENERAL, SUBCAT_AUDIO_AOUT, SUBCAT_AUDIO_AFILTER, SUBCAT_AUDIO_VISUAL, SUBCAT_AUDIO_RESAMPLER
            rows: [
                s("audio"),
                choice("aout"),
                choice("mmdevice-audio-device"),
                choice("mmdevice-passthrough"),
                s("audio-language"),
                s("volume-save"),
                special("replayGain", qsTr("Replay gain"),
                        { key: "audio-replay-gain-mode",
                          description: qsTr("Track and Album use the replay gain tags of a file. Measured also levels the files that have none: their loudness is measured while the file is analysed, and the volume is matched to it. The first play of a file is levelled after about a second, the next ones at once. Your volume setting is not changed.") }),
                s("audio-replay-gain-preamp"),
                s("audio-replay-gain-default"),
                s("audio-time-stretch"),
                choice("audio-visual"),
                s("audio-desync"),
                choice("stereo-mode"),
                choice("force-dolby-surround"),
                special("equalizer", qsTr("Equalizer"),
                        { description: qsTr("Presets, ten bands, preamp and two-pass."),
                          probe: "equalizer-bands",
                          keys: ["audio-filter", "equalizer-preset", "equalizer-bands",
                                 "equalizer-preamp", "equalizer-2pass"] }),
                toggle("compressorEnabled", qsTr("Compressor"), "compressor-attack"),
                param("compressor", "rms-peak", "compressor-rms-peak"),
                param("compressor", "attack", "compressor-attack"),
                param("compressor", "release", "compressor-release"),
                param("compressor", "threshold", "compressor-threshold"),
                param("compressor", "ratio", "compressor-ratio"),
                param("compressor", "knee", "compressor-knee"),
                param("compressor", "makeup-gain", "compressor-makeup-gain"),
                toggle("spatializerEnabled", qsTr("Spatial audio"), "spatializer-width"),
                param("spatializer", "roomsize", "spatializer-roomsize"),
                param("spatializer", "width", "spatializer-width"),
                param("spatializer", "wet", "spatializer-wet"),
                param("spatializer", "dry", "spatializer-dry"),
                param("spatializer", "damp", "spatializer-damp"),
                toggle("stereoWidenEnabled", qsTr("Stereo widening"), "stereowiden-delay"),
                param("stereoWiden", "delay", "stereowiden-delay"),
                param("stereoWiden", "feedback", "stereowiden-feedback"),
                param("stereoWiden", "crossfeed", "stereowiden-crossfeed"),
                param("stereoWiden", "dry-mix", "stereowiden-dry-mix")
            ]
        },
        {
            id: "subtitles", title: qsTr("Subtitles"), subcats: [305, 406], // SUBCAT_VIDEO_SUBPIC, SUBCAT_INPUT_SCODEC
            rows: [
                s("sub-track"),
                s("sub-language"),
                slider("sub-delay"),
                slider("sub-fps"),
                s("subsdec-formatted"),
                s("freetype-font"),
                choice("freetype-color"),
                choice("freetype-outline-color"),
                special("advancedLink", qsTr("Advanced options"),
                        { description: qsTr("Every other option of the subtitles and the text renderer.") }),
                s("spu"),
                choice("subsdec-encoding"),
                slider("sub-text-scale"),
                choice("freetype-outline-thickness"),
                s("freetype-bold"),
                slider("freetype-opacity"),
                slider("freetype-shadow-opacity"),
                slider("freetype-background-opacity"),
                s("sub-margin"),
                choice("secondary-sub-alignment"),
                s("secondary-sub-margin"),
                s("sub-autodetect-file"),
                choice("sub-autodetect-fuzzy"),
                s("sub-autodetect-path")
            ]
        },
        {
            id: "library", title: qsTr("Library"), subcats: [702], // SUBCAT_PLAYLIST_SD
            rows: [
                s("media-library"),
                s("auto-preparse"),
                special("libraryFolders", qsTr("Library folders"),
                        { description: qsTr("The folders the media library scans.") })
            ]
        },
        {
            id: "network", title: qsTr("Network"), subcats: [402, 603], // SUBCAT_INPUT_ACCESS, SUBCAT_ADVANCED_NETWORK
            rows: [
                s("http-proxy"),
                s("http-user-agent"),
                s("http-referrer"),
                s("http-reconnect"),
                s("ipv4-timeout"),
                s("rtsp-tcp"),
                s("services-discovery"),
                special("toolConsent", qsTr("Download website playback tools"),
                        { description: qsTr("Lets VLC Reborn download yt-dlp and ffmpeg to play and save videos from websites.") })
            ]
        },
        {
            id: "performance", title: qsTr("Performance"), subcats: [403, 404, 405, 407, 602], // SUBCAT_INPUT_DEMUX, SUBCAT_INPUT_VCODEC, SUBCAT_INPUT_ACODEC, SUBCAT_INPUT_STREAM_FILTER, SUBCAT_ADVANCED_MISC
            rows: [
                s("file-caching"),
                s("network-caching"),
                s("disc-caching"),
                s("live-caching"),
                s("avcodec-threads"),
                choice("avcodec-skiploopfilter"),
                s("avcodec-dr"),
                s("mkv-preload-local-dir"),
                choice("avi-index"),
                s("qt-smooth-scrolling"),
                s("qt-backdrop-blur"),
                choice("qt-compositor")
            ]
        },
        {
            id: "recording", title: qsTr("Recording"), subcats: [501, 502, 503, 504, 505, 507, 508, 703], // SUBCAT_SOUT_GENERAL, SUBCAT_SOUT_STREAM, SUBCAT_SOUT_MUX, SUBCAT_SOUT_ACO, SUBCAT_SOUT_PACKETIZER, SUBCAT_SOUT_VOD, SUBCAT_SOUT_RENDERER, SUBCAT_PLAYLIST_EXPORT
            rows: [
                s("input-record-path"),
                s("input-record-native")
            ]
        },
        {
            id: "extensions", title: qsTr("Extensions"), subcats: [], // Lua options are in SUBCAT_INTERFACE_MAIN (Interface)
            rows: [
                s("qt-autoload-extensions"),
                s("lua"),
                s("lastfm-username"),
                s("lastfm-password", "password"),
                special("extensions", qsTr("Installed extensions"),
                        { description: qsTr("Add-ons and extensions of the player.") })
            ]
        }
    ]

    //! the ids of the pages, in the order of the sidebar
    readonly property var pageIds: pages.map(p => p.id)

    //! { key: true } for every configuration key a row of some page shows
    readonly property var curatedKeys: {
        const keys = {}
        for (const page of pages) {
            for (const row of page.rows) {
                for (const key of rowKeys(row))
                    keys[key] = true
            }
        }
        return keys
    }

    // Functions

    /**
     * The file:// URL of a local path ("C:\Music", "C:/Music", "/home/me/Music"); the folder
     * model of the media library wants a URL. Each part is percent-encoded. A string that
     * already is a URL is kept, an empty string gives "".
     */
    function localUrl(path: string): string {
        const text = String(path ?? "").trim()
        if (text.length === 0)
            return ""
        if (/^[a-zA-Z][a-zA-Z0-9+.-]+:\/\//.test(text))
            return text
        const slashes = text.replace(/[\\]/g, "/")
        const drive = /^[a-zA-Z]:/.test(slashes) ? slashes.slice(0, 2) : ""
        const encoded = slashes.slice(drive.length).split("/").map(encodeURIComponent).join("/")
        return "file://" + (drive.length > 0 ? "/" + drive : "") + (encoded.startsWith("/") ? encoded : "/" + encoded)
    }

    //! the page object of an id, undefined if there is none
    function pageById(id: string): var {
        return pages.find(p => p.id === id)
    }

    //! the configuration keys a row covers
    function rowKeys(row: var): var {
        if (row.keys !== undefined)
            return row.keys.concat(row.key !== undefined ? [row.key] : [])
        return row.key !== undefined ? [row.key] : []
    }
}
