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
#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include "widgetpalette.hpp"

#include <QApplication>
#include <QStyleFactory>

namespace redesign
{

namespace
{

using C = ColorContext;

// The application palette before the redesign touched anything (the system
// colours), kept to give them back when a theme provider supplies its own.
QPalette& originalPalette()
{
    static QPalette original = QApplication::palette();
    return original;
}

} // anonymous namespace

QPalette toWidgetPalette(const ColorLookup& lookup)
{
    const QColor window = lookup(C::Window, C::Bg, C::Primary, C::Normal);
    const QColor windowText = lookup(C::Window, C::Fg, C::Primary, C::Normal);
    const QColor base = lookup(C::View, C::Bg, C::Secondary, C::Normal);
    const QColor alternateBase = lookup(C::View, C::Bg, C::Primary, C::Normal);
    const QColor text = lookup(C::View, C::Fg, C::Primary, C::Normal);
    const QColor button = lookup(C::ButtonStandard, C::Bg, C::Primary, C::Normal);
    const QColor buttonText = lookup(C::ButtonStandard, C::Fg, C::Primary, C::Normal);
    const QColor highlight = lookup(C::ButtonAccent, C::Bg, C::Primary, C::Normal);
    const QColor highlightedText = lookup(C::ButtonAccent, C::Fg, C::Primary, C::Normal);
    const QColor toolTipBase = lookup(C::Tooltip, C::Bg, C::Primary, C::Normal);
    const QColor toolTipText = lookup(C::Tooltip, C::Fg, C::Primary, C::Normal);
    const QColor placeholder = lookup(C::View, C::Fg, C::Secondary, C::Normal);
    const QColor link = lookup(C::View, C::Fg, C::Link, C::Normal);

    // The Window set only has a Normal state, so the disabled text colour is
    // the View one (the same faint tone the QML controls use).
    const QColor disabledText = lookup(C::View, C::Fg, C::Primary, C::Disabled);
    const QColor disabledButtonText = lookup(C::ButtonStandard, C::Fg, C::Primary, C::Disabled);

    // Derives Light, Midlight, Mid, Dark and Shadow from the button colour.
    QPalette palette(button);

    for (auto group : {QPalette::Active, QPalette::Inactive, QPalette::Disabled}) {
        const bool disabled = group == QPalette::Disabled;
        palette.setColor(group, QPalette::Window, window);
        palette.setColor(group, QPalette::WindowText, disabled ? disabledText : windowText);
        palette.setColor(group, QPalette::Base, base);
        palette.setColor(group, QPalette::AlternateBase, alternateBase);
        palette.setColor(group, QPalette::Text, disabled ? disabledText : text);
        palette.setColor(group, QPalette::Button, button);
        palette.setColor(group, QPalette::ButtonText, disabled ? disabledButtonText : buttonText);
        palette.setColor(group, QPalette::BrightText, text);
        palette.setColor(group, QPalette::Highlight, highlight);
        palette.setColor(group, QPalette::HighlightedText, highlightedText);
        palette.setColor(group, QPalette::ToolTipBase, toolTipBase);
        palette.setColor(group, QPalette::ToolTipText, toolTipText);
        palette.setColor(group, QPalette::PlaceholderText, placeholder);
        palette.setColor(group, QPalette::Link, link);
        palette.setColor(group, QPalette::LinkVisited, link);
    }
    return palette;
}

void applyWidgetPalette(const ColorLookup& lookup)
{
    // Remember the system palette before the first setPalette(), whatever the
    // call order (a style saved by the user skips installFusionStyle()).
    const QPalette& original = originalPalette();
    const QPalette next = lookup ? toWidgetPalette(lookup) : original;
    if (QApplication::palette() != next)
        QApplication::setPalette(next);
}

bool installFusionStyle()
{
    originalPalette(); // before the style change can alter the palette
    QStyle* fusion = QStyleFactory::create(QStringLiteral("Fusion"));
    if (!fusion)
        return false;
    QApplication::setStyle(fusion);
    return true;
}

} // namespace redesign
