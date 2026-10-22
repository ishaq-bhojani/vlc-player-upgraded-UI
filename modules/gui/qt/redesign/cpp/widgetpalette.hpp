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
#include <QStyle>
#include <QVector>

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
 * The Disabled group takes the text colours from the Disabled state, lifted to
 * 3:1 against the surfaces where the token is fainter (the token is about 1.6:1
 * on the dark window; disabled text is exempt from WCAG, but unreadable).
 * BrightText is the strong text colour (ButtonStandard/Fg/Focused).
 *
 * Outline roles (WCAG 1.4.11, 3:1 against Window, Base and Button): Mid, Dark,
 * Shadow and Accent (the Highlight accent, moved towards BrightText only where
 * it fails 3:1, e.g. the default orange on the light Window). Light and
 * Midlight are quiet highlights between Window and BrightText. Disabled Mid,
 * Dark and Shadow are 2.2:1. Fusion ignores these roles for most outlines; the
 * redesign style (installFusionStyle) paints them from the palette.
 */
QPalette toWidgetPalette(const ColorLookup& lookup);

/**
 * Moves `from` towards `toward` (in RGB, in steps of 1%) until its contrast
 * ratio against every colour of `against` is at least `ratio`. Returns `from`
 * itself when it already passes, `toward` when no mix does.
 */
QColor ensureContrast(const QColor& from, const QColor& toward, const QVector<QColor>& against, double ratio);

/** What the redesign style paints for a push or tool button in one state. */
struct ButtonColors
{
    QColor fill;   ///< opaque; the window colour for a flat button at rest
    QColor border; ///< fully transparent when the button has none
    QColor text;   ///< at least 4.5:1 against fill (3:1 when disabled)
};

/**
 * Colours of a QPushButton / QToolButton for the QStyle state flags (Enabled,
 * MouseOver, Sunken, On) taken from the palette. A default button gets the
 * accent fill with the HighlightedText; every other button gets the Button
 * colour, shifted slightly towards BrightText on hover and when pressed.
 * flat is a QToolButton with auto-raise: no fill and no border until hovered.
 */
ButtonColors buttonColors(const QPalette& palette, QStyle::State state, bool isDefault, bool flat = false);

/** What the redesign style paints for a check box or a radio button. */
struct IndicatorColors
{
    QColor border; ///< at least 3:1 against Window and Base (2:1 disabled)
    QColor fill;   ///< the inside of the box
    QColor mark;   ///< tick or dot, at least 3:1 against fill
};

IndicatorColors indicatorColors(const QPalette& palette, QStyle::State state, bool checked);

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
 * Makes the redesign widget style the application style: Fusion (the one
 * style that does not draw from a table of its own) with the controls that
 * Fusion leaves nearly invisible on a dark palette painted from the palette:
 * check boxes, radio buttons, push and tool buttons, and the outlines of group
 * boxes, line edits, combo boxes, spin boxes and frames. Returns false if
 * Fusion is not available.
 */
bool installFusionStyle();

} // namespace redesign

#endif // VLC_QT_REDESIGN_WIDGETPALETTE_HPP
