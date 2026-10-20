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

// SettingsSearch and SettingsData are plain QML (no C++ type), so they run in qml_test.
TestCase {
    name: "SettingsSearch"

    readonly property var idx: [
        { page: "audio", label: "Normalize loudness", description: "" },
        { page: "video", label: "Hardware decoding", description: "Use GPU" }
    ]

    function test_brief() {
        compare(SettingsSearch.filter(idx, "gpu").map(e => e.page), ["video"])
        compare(SettingsSearch.filter(idx, "LOUD").length, 1)
        compare(SettingsSearch.filter(idx, ""), [])
    }

    function test_label_or_description() {
        // label only, description only
        compare(SettingsSearch.filter(idx, "decoding").map(e => e.page), ["video"])
        compare(SettingsSearch.filter(idx, "use gpu").map(e => e.page), ["video"])
        // a substring, not a prefix
        compare(SettingsSearch.filter(idx, "ardware").length, 1)
        compare(SettingsSearch.filter(idx, "nothing like it"), [])
    }

    function test_blank_query() {
        compare(SettingsSearch.filter(idx, "   "), [])
        compare(SettingsSearch.filter(idx, undefined), [])
        compare(SettingsSearch.filter(idx, null), [])
    }

    function test_trimmed() {
        compare(SettingsSearch.filter(idx, "  gpu ").map(e => e.page), ["video"])
    }

    function test_empty_index() {
        compare(SettingsSearch.filter([], "a"), [])
        compare(SettingsSearch.filter(undefined, "a"), [])
    }

    function test_missing_fields() {
        // an entry without description (or label) is still searched
        const partial = [{ page: "audio", label: "Volume" }, { page: "video", description: "Volume of the picture?" }]
        compare(SettingsSearch.filter(partial, "volume").length, 2)
    }

    function test_sidebar_order() {
        // the order of the sidebar, not the order of the index; the order inside a page is kept
        const entries = [
            { page: "extensions", label: "Subtitle add-on", description: "" },
            { page: "audio", label: "Subtitle delay (audio)", description: "" },
            { page: "subtitles", label: "Subtitle font", description: "" },
            { page: "general", label: "Subtitle language", description: "" },
            { page: "subtitles", label: "Subtitle size", description: "" }
        ]
        compare(SettingsSearch.filter(entries, "subtitle").map(e => e.label),
                ["Subtitle language", "Subtitle delay (audio)", "Subtitle font", "Subtitle size",
                 "Subtitle add-on"])
    }

    function test_unknown_page_last() {
        const entries = [
            { page: "nowhere", label: "Volume", description: "" },
            { page: "audio", label: "Volume", description: "" }
        ]
        compare(SettingsSearch.filter(entries, "volume").map(e => e.page), ["audio", "nowhere"])
    }

    function test_entries_are_returned_as_they_are() {
        // the caller keeps its own fields (the key to scroll to)
        const entries = [{ page: "audio", label: "Volume", description: "", rowId: "volume-save" }]
        compare(SettingsSearch.filter(entries, "vol")[0].rowId, "volume-save")
    }

    function test_page_ids_match_the_sidebar() {
        compare(SettingsData.pageIds,
                ["general", "interface", "privacy", "controls", "playback", "video", "audio",
                 "subtitles", "library", "network", "performance", "recording", "extensions"])
        // the groups cover every page once
        const grouped = SettingsData.groups.reduce((all, g) => all.concat(g.pages), [])
        compare(grouped, SettingsData.pageIds)
    }

    function test_curated_keys_shared_with_advanced() {
        // a key of a curated row (on any page) is not an Advanced key
        verify(SettingsData.curatedKeys["qt-accent-color"] === true)
        verify(SettingsData.curatedKeys["sub-autodetect-fuzzy"] === true)
        verify(SettingsData.curatedKeys["compressor-makeup-gain"] === true)
        verify(SettingsData.curatedKeys["audio-filter"] === true)
        verify(SettingsData.curatedKeys["video-filter"] === true)
        verify(SettingsData.curatedKeys["qt-privacy-ask"] !== true)
    }

    function test_every_row_has_a_unique_id_per_page() {
        for (const page of SettingsData.pages) {
            const ids = page.rows.map(r => r.id)
            compare(new Set(ids).size, ids.length, page.id)
            verify(page.title.length > 0)
        }
    }

    function test_every_setting_key_is_used_once() {
        // a curated key shown on two pages would be two rows for one option
        const seen = {}
        for (const page of SettingsData.pages) {
            for (const row of page.rows) {
                for (const key of SettingsData.rowKeys(row)) {
                    verify(seen[key] === undefined, key + " on " + page.id + " and " + seen[key])
                    seen[key] = page.id
                }
            }
        }
    }
}
