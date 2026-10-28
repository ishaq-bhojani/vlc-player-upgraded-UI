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

// The segments of the address bar of the library (library/ViewHeader.qml) from a History path.
QtObject {
    /**
     * One crumb per prefix of `viewPath`: [{label, path}], `path` the prefix to navigate to.
     *
     * `labels` maps a segment to its name. A segment it does not know is shown as it is; one it
     * maps to "" is a step of the page tree with no page of its own (the "base" of the videos,
     * the "all" tab of a page that has others): it gets no crumb, the next crumb includes it.
     */
    function crumbs(viewPath: var, labels: var): var {
        const path = Array.from(viewPath ?? [])
        const names = labels ?? {}
        const out = []
        for (let i = 0; i < path.length; ++i) {
            const segment = path[i]
            const label = Object.prototype.hasOwnProperty.call(names, segment) ? names[segment] : segment
            if (label === "")
                continue
            out.push({label: label, path: path.slice(0, i + 1)})
        }
        return out
    }
}
