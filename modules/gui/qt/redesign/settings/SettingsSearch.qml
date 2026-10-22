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
pragma Singleton
import QtQml

/**
 * @brief The search of the settings modal, apart from the modal so that it can be tested.
 *
 * The index is [{page, label, description}] (plus any field the caller wants back, e.g. the id of
 * the row to scroll to); `page` is an id of SettingsData.pages.
 */
QtObject {
    /**
     * The entries of `index` whose label or description contains `query` (case-insensitive
     * substring; the query is trimmed). An empty query matches nothing.
     *
     * Ordered page-first, in the order of the sidebar; inside a page the order of `index` is
     * kept, and an entry of a page that is not in the sidebar comes last. The entries are
     * returned as they are.
     */
    function filter(index: var, query: var): var {
        const wanted = String(query ?? "").trim().toLowerCase()
        if (wanted.length === 0 || !index)
            return []

        const matches = index.filter(entry =>
            String(entry.label ?? "").toLowerCase().includes(wanted)
            || String(entry.description ?? "").toLowerCase().includes(wanted))

        // one bucket per page of the sidebar, then the unknown pages: a plain sort would have to
        // be stable to keep the order inside a page
        const ids = SettingsData.pageIds
        const result = []
        for (const id of ids) {
            for (const entry of matches) {
                if (entry.page === id)
                    result.push(entry)
            }
        }
        for (const entry of matches) {
            if (!ids.includes(entry.page))
                result.push(entry)
        }
        return result
    }
}
