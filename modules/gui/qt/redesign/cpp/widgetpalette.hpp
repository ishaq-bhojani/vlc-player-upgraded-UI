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
#ifndef VLC_QT_REDESIGN_WIDGETPALETTE_HPP
#define VLC_QT_REDESIGN_WIDGETPALETTE_HPP

#include <functional>

#include <QColor>
#include <QPalette>

#include "../../style/colorcontext.hpp"

namespace redesign
{

/** Colour lookup with the signature of SystemPalette::getColor. */
using ColorLookup = std::function<QColor(ColorContext::ColorSet, ColorContext::ColorSection,
                                         ColorContext::ColorName, ColorContext::ColorState)>;

/**
 * Builds the QPalette used by the QWidgets dialogs and native menus from the
 * redesign colours:
 *   Window/WindowText  Window/Bg/Primary, Window/Fg/Primary
 *   Base/Text          View/Bg/Secondary, View/Fg/Primary
 *   Button/ButtonText  ButtonStandard/Bg/Primary, ButtonStandard/Fg/Primary
 *   Highlight/HighlightedText  ButtonAccent/Bg/Primary, ButtonAccent/Fg/Primary
 *   ToolTipBase/ToolTipText    Tooltip/Bg/Primary, Tooltip/Fg/Primary
 * The Disabled group takes the text colours from the Disabled state.
 */
QPalette toWidgetPalette(const ColorLookup& lookup);

/**
 * Applies the palette to the application. Needs a QApplication.
 *
 * With a lookup it installs toWidgetPalette(lookup). With an empty lookup (the
 * theme provider supplies its own colours, e.g. High Contrast) it restores the
 * palette the application had before the redesign (remembered by the first
 * call of installFusionStyle() or applyWidgetPalette()), so the system colours
 * stay in charge.
 */
void applyWidgetPalette(const ColorLookup& lookup);

/**
 * Makes Fusion the application style, the one style whose widgets follow the
 * QPalette completely. Returns false if Fusion is not available.
 */
bool installFusionStyle();

} // namespace redesign

#endif // VLC_QT_REDESIGN_WIDGETPALETTE_HPP
