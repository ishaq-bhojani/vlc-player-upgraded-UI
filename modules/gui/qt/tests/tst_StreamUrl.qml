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
import QtTest
import VLC.Redesign

TestCase {
    name: "StreamUrl"

    // one backslash
    readonly property string bs: String.fromCharCode(92)

    function test_emptyAndBlank() {
        compare(StreamUrl.normalize(""), "")
        compare(StreamUrl.normalize("   "), "")
        compare(StreamUrl.normalize("\t\r\n "), "")
        compare(StreamUrl.isValid(""), false)
        compare(StreamUrl.isValid("  \n "), false)
    }

    function test_trims() {
        compare(StreamUrl.normalize("  rtsp://cam/1 "), "rtsp://cam/1")
        compare(StreamUrl.normalize("\thttps://example.org/a.m3u8\n"), "https://example.org/a.m3u8")
    }

    // no scheme and a dot: https is assumed
    function test_addsHttpsWithDot() {
        compare(StreamUrl.normalize("example.org/a.m3u8"), "https://example.org/a.m3u8")
        compare(StreamUrl.normalize("  www.example.org "), "https://www.example.org")
        compare(StreamUrl.normalize("example.org:8080/live.ts"), "https://example.org:8080/live.ts")
    }

    // no scheme and no dot: left unchanged
    function test_noDotUnchanged() {
        compare(StreamUrl.normalize("hello"), "hello")
        compare(StreamUrl.normalize("localhost:8080/x"), "localhost:8080/x")
    }

    function test_knownSchemesKept() {
        const urls = [
            "http://example.org/a",
            "https://example.org/a",
            "rtsp://cam/1",
            "rtmp://example.org/live",
            "udp://@239.0.0.1:1234",
            "rtp://@239.0.0.1:5004",
            "mms://example.org/stream",
            "smb://server/share/a.mkv",
            "ftp://example.org/a.mp4",
            "sftp://example.org/a.mp4",
            "file:///C:/media/a.mp4"
        ]
        for (const url of urls)
            compare(StreamUrl.normalize(url), url)
    }

    // the known schemes without "//" are kept too, not given an https
    function test_knownSchemesWithoutSlashes() {
        const urls = [
            "udp:@239.0.0.1:1234",
            "rtp:@239.0.0.1:5004",
            "file:/media/a.mp4",
            "RTSP:cam.example.org/1",
            "magnet:?xt=urn:btih:abc.def"
        ]
        for (const url of urls)
            compare(StreamUrl.normalize(url), url)
        // a host with a port is not a scheme
        compare(StreamUrl.normalize("example.org:8080/a"), "https://example.org:8080/a")
        compare(StreamUrl.normalize("fileserver.local/a.mp4"), "https://fileserver.local/a.mp4")
    }

    // a scheme is recognised whatever its case, and is not given a second one
    function test_schemeCaseInsensitive() {
        compare(StreamUrl.normalize("HTTP://Example.org/A"), "HTTP://Example.org/A")
    }

    // a local path is not a web address even though it has a dot
    function test_localPathsUnchanged() {
        compare(StreamUrl.normalize("C:" + bs + "media" + bs + "a.mp4"), "C:" + bs + "media" + bs + "a.mp4")
        compare(StreamUrl.normalize("C:/media/a.mp4"), "C:/media/a.mp4")
        compare(StreamUrl.normalize(bs + bs + "server" + bs + "share" + bs + "a.mp4"),
                bs + bs + "server" + bs + "share" + bs + "a.mp4")
        compare(StreamUrl.normalize("/home/me/a.mp4"), "/home/me/a.mp4")
    }

    // a pasted block of text: the first line that has something in it
    function test_multiLineUsesFirstNonEmptyLine() {
        compare(StreamUrl.normalize("\n\n  example.org/a.m3u8 \r\nhttps://other.org/b"), "https://example.org/a.m3u8")
        compare(StreamUrl.normalize("rtsp://cam/1\nrtsp://cam/2"), "rtsp://cam/1")
        // the line and paragraph separators (what a text field makes of a line break) too
        compare(StreamUrl.normalize("\u2028 rtsp://cam/1\u2029rtsp://cam/2"), "rtsp://cam/1")
        compare(StreamUrl.normalize(" \n \n"), "")
    }

    function test_isValid() {
        compare(StreamUrl.isValid("example.org/a.m3u8"), true)
        compare(StreamUrl.isValid("hello"), true)
        compare(StreamUrl.isValid(" rtsp://cam/1 "), true)
        compare(StreamUrl.isValid(undefined), false)
        compare(StreamUrl.isValid(null), false)
    }
}
