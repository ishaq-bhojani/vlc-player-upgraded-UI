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
import QtTest
import VLC.Redesign

TestCase {
    name: "MediaText"

    function test_folderName() {
        compare(MediaText.folderName("file:///C:/Videos/Shows/S01/a.mp4"), "S01")
        compare(MediaText.folderName("https://example.org/live/a.m3u8"), "")
        compare(MediaText.folderName(""), "")
    }

    function test_folderNameDecodesAndIgnoresQuery() {
        compare(MediaText.folderName("file:///home/me/My%20Shows/a.mp4"), "My Shows")
        compare(MediaText.folderName("file:///home/me/Shows/a.mp4?x=1#t"), "Shows")
        compare(MediaText.folderName("file:///a.mp4"), "")
    }

    function test_titleText() {
        compare(MediaText.titleText("", "", "https://x.org/a%20b.mp4"), "a b.mp4")
        compare(MediaText.titleText("T", "N", "u"), "T")
    }

    function test_titleTextFallbackOrder() {
        compare(MediaText.titleText("", "N", "https://x.org/a.mp4"), "N")
        compare(MediaText.titleText("  ", "", "file:///C:/V/a.mp4"), "a.mp4")
        compare(MediaText.titleText("", "", ""), "")
        // malformed escape must not throw
        compare(MediaText.titleText("", "", "https://x.org/100%.mp4"), "100%.mp4")
    }

    function test_captionText() {
        compare(MediaText.captionText("Song", "", "", ""), "Song")
        compare(MediaText.captionText("Song", "", "", "  "), "Song")
        compare(MediaText.captionText("Song", "", "", "Artist"), "Song - Artist")
        compare(MediaText.captionText("", "", "file:///C:/Music/a%20b.mp3", ""), "a b.mp3")
        compare(MediaText.captionText("", "", "", "Artist"), "Artist")
        compare(MediaText.captionText("", "", "", ""), "")
    }

    function test_captionTextNoDuplicateArtist() {
        compare(MediaText.captionText("", "", "file:///C:/Music/Artist%20-%20Song.mp3", "Artist"), "Artist - Song.mp3")
        compare(MediaText.captionText("Artist - Song", "", "", "ARTIST"), "Artist - Song")
        compare(MediaText.captionText("ARTIST - Song", "", "", " artist "), "ARTIST - Song")
        // a mere prefix or substring of the title is not the artist
        compare(MediaText.captionText("Dance Mix", "", "", "Dan"), "Dance Mix - Dan")
        compare(MediaText.captionText("Mr Dan - Song", "", "", "Dan"), "Mr Dan - Song - Dan")
    }

    // a stand-in for VLCTick / VLCDuration
    function tick(seconds, valid) {
        return { valid: function () { return valid !== false }, toSeconds: function () { return seconds } }
    }

    function test_durationTextTruncates() {
        compare(MediaText.durationText(tick(0)), "")
        compare(MediaText.durationText(tick(6)), "00:06")
        compare(MediaText.durationText(tick(19)), "00:19")
        compare(MediaText.durationText(tick(125)), "02:05")
        compare(MediaText.durationText(tick(3725)), "01:02:05")
    }

    function test_durationTextUnknownIsEmpty() {
        compare(MediaText.durationText(tick(-1)), "")
        compare(MediaText.durationText(tick(30, false)), "")
        compare(MediaText.durationText(null), "")
        compare(MediaText.durationText(undefined), "")
        compare(MediaText.durationText({}), "")
        compare(MediaText.durationShortText(tick(0)), "")
        compare(MediaText.durationLongText(tick(-1)), "")
        compare(MediaText.durationLongText(null), "")
    }

    function test_durationShortText() {
        compare(MediaText.durationShortText(tick(19)), "00:19")
        compare(MediaText.durationShortText(tick(3599)), "59:59")
        compare(MediaText.durationShortText(tick(3725)), "1h02")
        compare(MediaText.durationShortText(tick(36000 + 59 * 60 + 59)), "10h59")
    }

    function test_durationLongText() {
        compare(MediaText.durationLongText(tick(19)), "19 sec")
        compare(MediaText.durationLongText(tick(65)), "1 min 5 sec")
        compare(MediaText.durationLongText(tick(3725)), "1 h 2 min")
    }
}
