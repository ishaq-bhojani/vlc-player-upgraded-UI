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
#ifndef VLC_QT_REDESIGN_PALETTE_HPP
#define VLC_QT_REDESIGN_PALETTE_HPP

#include <functional>

#include <QColor>
#include <QVector>

#include "colorcontext.hpp"

namespace redesign
{

using ColorSink = std::function<void(ColorContext::ColorSet, ColorContext::ColorSection,
                                     ColorContext::ColorName, ColorContext::ColorState, QColor)>;

struct AccentShades
{
    QColor base, hover, pressed, onAccent;
};

/** Default accent: Table C of docs/redesign/tokens.md (orange). */
QColor defaultAccent();

/** The 9 accent swatches, in Figma order (Table C, "Applied accent hex"). */
QVector<QColor> accentSwatches();

/**
 * Parses the qt-accent-color value: "default" gives the fallback, a valid
 * color name or "#rrggbb" gives that color, anything else gives the fallback.
 */
QColor parseAccent(const char* value, QColor fallback);

/**
 * Resolves the qt-accent-color setting for the redesign: "system" gives the
 * system accent (Qt >= 6.6, needs a QGuiApplication), otherwise parseAccent();
 * an unsupported or invalid value gives defaultAccent(). light is base.lighter(150).
 */
void accentFromSetting(const char* value, QColor& base, QColor& light);

/** WCAG 2.x contrast ratio, from 1 to 21. */
double contrastRatio(QColor a, QColor b);

/** Qt::black or Qt::white, whichever contrasts more with the accent. */
QColor onAccentColor(QColor accent);

/** hover = base.lighter(115), pressed = base.darker(115). */
AccentShades accentShades(QColor base);

/** Calls the sink once for every slot of Table B (dark or light column). */
void fillPalette(const ColorSink& sink, bool dark, const AccentShades& accent);

} // namespace redesign

#endif // VLC_QT_REDESIGN_PALETTE_HPP
