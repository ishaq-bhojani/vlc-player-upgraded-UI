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
    name: "SubtitleMatch"

    // the example of the plan: the subtitle with a language suffix, the case does not matter
    function test_planExample() {
        compare(SubtitleMatch.pair(["S01E01.mkv", "S01E02.mkv"], ["s01e01.en.srt", "S01E03.srt"]),
                [{video: "S01E01.mkv", subtitle: "s01e01.en.srt"},
                 {video: "S01E02.mkv", subtitle: ""}])
    }

    function test_noSuffix() {
        compare(SubtitleMatch.pair(["Movie.mp4"], ["Movie.srt"]),
                [{video: "Movie.mp4", subtitle: "Movie.srt"}])
    }

    function test_languageSuffixCase() {
        compare(SubtitleMatch.pair(["Movie.mp4"], ["movie.EN.srt"]),
                [{video: "Movie.mp4", subtitle: "movie.EN.srt"}])
    }

    function test_threeLetterSuffix() {
        compare(SubtitleMatch.pair(["Movie.mp4"], ["Movie.eng.ass"]),
                [{video: "Movie.mp4", subtitle: "Movie.eng.ass"}])
    }

    // only 2 or 3 letters are a language: "forced" and a version number are part of the name
    function test_longerSuffixIsNotALanguage() {
        compare(SubtitleMatch.pair(["Movie.mp4"], ["Movie.forced.srt", "Movie.2.srt"]),
                [{video: "Movie.mp4", subtitle: ""}])
    }

    // dots in the name: the extension is the last one, the language the one before it
    function test_dotsInTheName() {
        compare(SubtitleMatch.pair(["Show.S01E01.1080p.mkv", "Show.S01E02.1080p.mkv"],
                                   ["Show.S01E01.1080p.en.srt", "Show.S01E02.1080p.srt"]),
                [{video: "Show.S01E01.1080p.mkv", subtitle: "Show.S01E01.1080p.en.srt"},
                 {video: "Show.S01E02.1080p.mkv", subtitle: "Show.S01E02.1080p.srt"}])
    }

    // a video whose name ends in two or three letters after a dot: the name is not cut as a language
    function test_videoNameLooksLikeLanguage() {
        compare(SubtitleMatch.pair(["A.Film.TV.mkv"], ["A.Film.TV.srt"]),
                [{video: "A.Film.TV.mkv", subtitle: "A.Film.TV.srt"}])
    }

    // a prefix is not a match: the base names are equal
    function test_prefixDoesNotMatch() {
        compare(SubtitleMatch.pair(["Show.S01E01.mkv"], ["Show.S01E01.1080p.srt", "Show.srt"]),
                [{video: "Show.S01E01.mkv", subtitle: ""}])
    }

    // two subtitles for one video: the first one of the list is taken
    function test_firstSubtitleWins() {
        compare(SubtitleMatch.pair(["a.mkv"], ["a.fr.srt", "a.en.srt"]),
                [{video: "a.mkv", subtitle: "a.fr.srt"}])
        compare(SubtitleMatch.pair(["a.mkv"], ["a.en.srt", "a.fr.srt"]),
                [{video: "a.mkv", subtitle: "a.en.srt"}])
    }

    function test_orderFollowsTheVideos() {
        compare(SubtitleMatch.pair(["b.mkv", "a.mkv"], ["a.srt", "b.srt"]),
                [{video: "b.mkv", subtitle: "b.srt"}, {video: "a.mkv", subtitle: "a.srt"}])
    }

    function test_emptyInputs() {
        compare(SubtitleMatch.pair([], ["a.srt"]), [])
        compare(SubtitleMatch.pair(["a.mkv"], []), [{video: "a.mkv", subtitle: ""}])
        compare(SubtitleMatch.pair([], []), [])
        compare(SubtitleMatch.pair(undefined, undefined), [])
    }

    // a name without extension is its own base name
    function test_noExtension() {
        compare(SubtitleMatch.pair(["clip"], ["clip.srt"]),
                [{video: "clip", subtitle: "clip.srt"}])
    }

    function test_fileName() {
        compare(SubtitleMatch.fileName("file:///C:/Videos/My%20Show/S01E01.mkv"), "S01E01.mkv")
        compare(SubtitleMatch.fileName("file:///home/me/a%23b.mkv"), "a#b.mkv")
        compare(SubtitleMatch.fileName("C:\\Videos\\a.mkv"), "a.mkv")
        compare(SubtitleMatch.fileName("/home/me/a.mkv"), "a.mkv")
        compare(SubtitleMatch.fileName("a.mkv"), "a.mkv")
        compare(SubtitleMatch.fileName("https://example.org/v/a.m3u8?x=1"), "a.m3u8")
        compare(SubtitleMatch.fileName(""), "")
    }
}
