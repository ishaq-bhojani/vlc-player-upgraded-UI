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
#ifndef VLC_QT_REDESIGN_SYSTEMPALETTEGLUE_HPP
#define VLC_QT_REDESIGN_SYSTEMPALETTEGLUE_HPP

/* The pieces of SystemPalette that belong to the redesign, kept out of
 * style/systempalette.cpp so that the upstream file stays close to upstream. */

#include <QColor>
#include <QString>

#include "redesign.hpp"
#include "widgetpalette.hpp"
#include "../../style/redesignpalette.hpp"

namespace redesign
{

/** Fills the palette (SystemPalette::setColor) with the Table B colours. */
template <class Palette>
void fillSystemPalette(Palette& palette, bool dark, const QColor& accent)
{
    fillPalette([&palette](ColorContext::ColorSet set, ColorContext::ColorSection section,
                           ColorContext::ColorName name, ColorContext::ColorState state, QColor color) {
        palette.setColor(set, section, name, state, color);
    }, dark, accentShades(accent));
}

/**
 * Themes the QWidgets dialogs and native menus with the palette of the main
 * window (the "themePalette" instance). When a theme provider (e.g. High
 * Contrast) owns the colours the system palette is restored instead.
 */
template <class Palette>
void syncWidgetPalette(Palette& palette, bool providerColors)
{
    if (palette.objectName() != QLatin1String("themePalette"))
        return;
    if (providerColors)
        applyWidgetPalette(ColorLookup());
    else
        applyWidgetPalette([&palette](ColorContext::ColorSet set, ColorContext::ColorSection section,
                                      ColorContext::ColorName name, ColorContext::ColorState state) {
            return palette.getColor(set, section, name, state);
        });
}

} // namespace redesign

#endif // VLC_QT_REDESIGN_SYSTEMPALETTEGLUE_HPP
