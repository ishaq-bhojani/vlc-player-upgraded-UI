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

import VLC.Redesign

/**
 * @brief What the pages of the settings modal do with the rows of SettingsData: is a row there,
 * is it changed, put it back to its default, the entries of the search, the keys of an Advanced
 * section.
 *
 * It works on the data of the rows and not on the delegates: a page shows only the rows in view
 * (a ListView), but "Reset to defaults" and the search are about all of them. It needs the C++
 * singletons of the qt plugin (RedesignSettings, Effects, SettingsBridge, ToolManager), so it is
 * not loaded by qml_test: the pure part is SettingsData and SettingsSearch.
 */
QtObject {
    id: root

    // Functions

    //! the SettingItem of a key, null if the build has no such option
    function item(key: string): var {
        return RedesignSettings.item(key)
    }

    //! true if the build has the option `key` (nothing is logged for a missing one)
    function hasKey(key: string): bool {
        return RedesignSettings.hasItem(key)
    }

    //! true if the row has something to show in this build: its option exists (its plugin is there)
    function present(row: var): bool {
        switch (row.kind) {
        case "setting":
        case "accent":
        case "effectSlider":
        case "filterToken":
            return hasKey(row.key)
        case "effectToggle":
        case "equalizer":
            return hasKey(row.probe)
        default:
            return true
        }
    }

    //! the title of a row: the name of its option, or the title of a row that is none
    function titleOf(row: var): string {
        if (row.kind === "setting" || row.kind === "accent" || row.kind === "effectSlider") {
            const setting = item(row.key)
            return setting ? setting.text : ""
        }
        return row.title ?? ""
    }

    //! the long description of a row (the search looks into it)
    function descriptionOf(row: var): string {
        if (row.kind === "setting" || row.kind === "accent" || row.kind === "effectSlider") {
            const setting = item(row.key)
            return setting ? setting.longText : ""
        }
        return row.description ?? ""
    }

    //! true if the two values are the same setting value (numbers compare as numbers)
    function same(a: var, b: var): bool {
        if (typeof a === "number" || typeof b === "number")
            return Math.abs(Number(a) - Number(b)) < 1e-9
        return String(a ?? "") === String(b ?? "")
    }

    //! the row of the ColorSchemeModel for "light", "dark" or "system", -1 if there is none
    function schemeIndex(kind: string): int {
        return SettingsBridge.colorSchemes.findIndex(scheme => scheme.kind === kind)
    }

    //! the filters of a configuration value ("invert:sharpen")
    function filterList(value: var): var {
        return String(value ?? "").split(":").filter(name => name.length > 0)
    }

    //! true if the filter `token` is in the list of the option `key` (video-filter)
    function hasFilter(key: string, token: string): bool {
        const setting = item(key)
        return setting !== null && filterList(setting.value).includes(token)
    }

    //! puts `token` in the list of the option `key`, or takes it out
    function setFilter(key: string, token: string, on: bool) {
        const setting = item(key)
        if (!setting)
            return
        const list = filterList(setting.value).filter(name => name !== token)
        if (on)
            list.push(token)
        setting.value = list.join(":")
    }

    //! true if the value of the row differs from its default
    function isChanged(row: var): bool {
        switch (row.kind) {
        case "setting":
        case "accent": {
            const setting = item(row.key)
            return setting !== null && !same(setting.value, setting.defaultValue)
        }
        case "theme":
            return SettingsBridge.colorSchemeIndex !== schemeIndex("system")
        case "effectToggle":
            return Effects[row.prop] === true
        case "effectSlider": {
            const setting = item(row.key)
            const current = Effects[row.group][row.name]
            return setting !== null && current !== undefined && !same(current, setting.defaultValue)
        }
        case "equalizer":
            return Effects.equalizerEnabled || Effects.twoPass || Effects.equalizerPreset !== "flat"
                   || Effects.equalizerPreamp !== 0 || Effects.equalizerBands.some(db => db !== 0)
        case "filterToken":
            return hasFilter(row.key, row.token)
        case "toolConsent":
            return ToolManager.consentGiven
        default:
            return false
        }
    }

    //! puts the row back to its default
    function reset(row: var) {
        switch (row.kind) {
        case "setting":
        case "accent": {
            const setting = item(row.key)
            if (setting)
                setting.reset()
            break
        }
        case "theme":
            SettingsBridge.colorSchemeIndex = schemeIndex("system")
            break
        case "effectToggle":
            Effects[row.prop] = false
            break
        case "effectSlider": {
            const setting = item(row.key)
            if (setting) {
                const values = {}
                values[row.name] = setting.defaultValue
                Effects[row.group] = values
            }
            break
        }
        case "equalizer":
            Effects.applyEqualizerPreset("flat")
            Effects.twoPass = false
            Effects.equalizerEnabled = false
            break
        case "filterToken":
            setFilter(row.key, row.token, false)
            break
        case "toolConsent":
            ToolManager.consentGiven = false
            break
        }
    }

    //! the rows of a page the build has
    function presentRows(page: var): var {
        return page.rows.filter(present)
    }

    //! how many rows of the page are not at their default
    function changedCount(page: var): int {
        return presentRows(page).filter(isChanged).length
    }

    //! puts every row of the page (not its Advanced section) back to its default
    function resetPage(page: var) {
        for (const row of presentRows(page)) {
            if (isChanged(row))
                reset(row)
        }
    }

    /**
     * The index of the search: [{page, label, description, rowId}] for every page (rowId "") and
     * every row of the pages the build has. Built when the user searches, not when the modal
     * opens.
     */
    function searchIndex(): var {
        const index = []
        for (const page of SettingsData.pages) {
            index.push({ page: page.id, label: page.title, description: "", rowId: "" })
            for (const row of presentRows(page)) {
                const label = titleOf(row)
                if (label.length > 0)
                    index.push({ page: page.id, label: label, description: descriptionOf(row), rowId: row.id })
            }
        }
        return index
    }

    /**
     * The keys of the Advanced section of a page: the options of its VLC subcategories that no
     * page shows as a row, without the keyboard shortcuts (they have their own page). It makes an
     * item per key: call it when the section is opened.
     */
    function advancedKeys(page: var): var {
        const keys = []
        const seen = {}
        for (const subcategory of page.subcats) {
            for (const key of RedesignSettings.keysInSubcategory(subcategory)) {
                if (SettingsData.curatedKeys[key] === true || seen[key] === true)
                    continue
                seen[key] = true
                const setting = item(key)
                if (setting !== null && setting.type !== ControlChooser.type.Hotkey)
                    keys.push(key)
            }
        }
        return keys
    }
}
