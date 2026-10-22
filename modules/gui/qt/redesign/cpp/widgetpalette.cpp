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

#include "widgetstyle.hpp"
#include "../../style/redesignpalette.hpp"

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

QColor opaque(QColor c)
{
    c.setAlpha(255);
    return c;
}

QPalette::ColorGroup groupOf(QStyle::State state)
{
    return (state & QStyle::State_Enabled) ? QPalette::Active : QPalette::Disabled;
}

// Black or white, whichever reads better on the colour.
QColor blackOrWhiteOn(const QColor& fill)
{
    return redesign::contrastRatio(Qt::white, fill) > redesign::contrastRatio(Qt::black, fill) ? QColor(Qt::white)
                                                                                                : QColor(Qt::black);
}

} // anonymous namespace

QColor mixColors(const QColor& a, const QColor& b, qreal t)
{
    return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * t, a.greenF() + (b.greenF() - a.greenF()) * t,
                            a.blueF() + (b.blueF() - a.blueF()) * t);
}

QColor widgetAccent(const QPalette& p)
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 6, 0)
    const QColor accent = p.color(QPalette::Active, QPalette::Accent);
#else
    const QColor accent = p.color(QPalette::Active, QPalette::Highlight);
#endif
    return ensureContrast(accent, p.color(QPalette::Active, QPalette::BrightText),
                          {p.color(QPalette::Active, QPalette::Window), p.color(QPalette::Active, QPalette::Base)}, 3.0);
}

QColor focusRingColor(const QPalette& p, bool onDefaultButton)
{
    // the default button is filled with the accent: its ring is the strong text
    // colour, set off from the fill by a gap
    return onDefaultButton ? p.color(QPalette::Active, QPalette::BrightText) : widgetAccent(p);
}

QColor ensureContrast(const QColor& from, const QColor& toward, const QVector<QColor>& against, double ratio)
{
    auto passes = [&](const QColor& c) {
        for (const QColor& other : against)
            if (contrastRatio(c, other) < ratio)
                return false;
        return true;
    };
    for (int step = 0; step <= 100; ++step) {
        // judged as 8 bit RGB: the colour that is returned is what gets painted
        const QColor c = QColor::fromRgb(mixColors(from, toward, step / 100.0).rgb());
        if (passes(c))
            return c;
    }
    return toward;
}

ButtonColors buttonColors(const QPalette& p, QStyle::State state, bool isDefault, bool flat)
{
    const bool enabled = state & QStyle::State_Enabled;
    const bool hover = enabled && (state & QStyle::State_MouseOver);
    const bool down = enabled && (state & (QStyle::State_Sunken | QStyle::State_On));
    const QPalette::ColorGroup group = groupOf(state);
    const QColor window = p.color(group, QPalette::Window);
    const QColor strong = p.color(QPalette::Active, QPalette::BrightText);

    ButtonColors c;
    QColor preferredText;
    if (isDefault && enabled) {
        // the accent as painted: at least 3:1 against the window, also on the light scheme
        const QColor accent = widgetAccent(p);
        c.fill = down ? accent.darker(115) : hover ? accent.lighter(115) : accent;
        c.fill = opaque(QColor::fromRgb(c.fill.rgb()));
        c.border = Qt::transparent;
        preferredText = p.color(QPalette::Active, QPalette::HighlightedText);
    } else {
        const QColor button = p.color(group, QPalette::Button);
        c.fill = down ? mixColors(button, strong, 0.18) : hover ? mixColors(button, strong, 0.10) : button;
        c.border = p.color(group, QPalette::Mid);
        preferredText = (hover || down) ? strong : p.color(group, QPalette::ButtonText);
        if (flat && !hover && !down) {
            c.fill = window;
            c.border = Qt::transparent;
        } else if (flat) {
            c.border = Qt::transparent;
        }
    }
    const QColor towards = blackOrWhiteOn(c.fill);
    c.text = ensureContrast(preferredText, towards, {c.fill}, enabled ? 4.5 : 3.0);
    return c;
}

IndicatorColors indicatorColors(const QPalette& p, QStyle::State state, bool checked)
{
    const bool enabled = state & QStyle::State_Enabled;
    const bool hover = enabled && (state & QStyle::State_MouseOver);
    const QPalette::ColorGroup group = groupOf(state);
    const QColor base = p.color(group, QPalette::Base);
    const QColor accent = widgetAccent(p);
    const QColor strong = p.color(QPalette::Active, QPalette::BrightText);

    IndicatorColors c;
    c.fill = base;
    c.border = hover ? ensureContrast(p.color(group, QPalette::Mid), strong, {base}, 4.5)
                     : p.color(group, QPalette::Mid);
    c.mark = c.border;
    if (checked && enabled) {
        c.border = c.fill = accent;
        c.mark = p.color(QPalette::Active, QPalette::HighlightedText);
        // the accent can be a pale one: keep the mark readable
        c.mark = ensureContrast(c.mark, blackOrWhiteOn(accent), {accent}, 3.0);
    }
    return c;
}

QPalette toWidgetPalette(const ColorLookup& lookup)
{
    const QColor window = lookup(C::Window, C::Bg, C::Primary, C::Normal);
    const QColor windowText = lookup(C::Window, C::Fg, C::Primary, C::Normal);
    const QColor base = lookup(C::View, C::Bg, C::Secondary, C::Normal);
    const QColor text = lookup(C::View, C::Fg, C::Primary, C::Normal);
    // a visible stripe on Base for the alternating rows of the tables
    const QColor alternateBase = mixColors(base, text, 0.06);
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
    const QColor strong = lookup(C::ButtonStandard, C::Fg, C::Primary, C::Focused);

    // Borders and indicators: the redesign tokens give a hairline for the QML
    // controls, which is far below the 3:1 non-text contrast (WCAG 1.4.11) the
    // QWidgets outlines need, so derive them from the window towards the
    // strong text colour until they pass against Window, Base and Button.
    const QVector<QColor> surfaces{window, base, button};
    const QColor mid = ensureContrast(window, strong, surfaces, 3.2);
    const QColor dark = ensureContrast(mid, strong, surfaces, 4.0);
    const QColor midDisabled = ensureContrast(window, strong, {window, base}, 2.2);
    const QColor midlight = mixColors(window, strong, 0.10);
    const QColor light = mixColors(window, strong, 0.18);

    // The disabled text of the tokens is a faint tone (about 1.6:1 on the
    // dark window): disabled text is exempt from WCAG, but a disabled label
    // nobody can read looks broken, so lift it to 3:1.
    const QColor disabledText = ensureContrast(lookup(C::View, C::Fg, C::Primary, C::Disabled), strong, surfaces, 3.0);
    const QColor disabledButtonText =
        ensureContrast(lookup(C::ButtonStandard, C::Fg, C::Primary, C::Disabled), strong, surfaces, 3.0);

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
        palette.setColor(group, QPalette::BrightText, strong);
        palette.setColor(group, QPalette::Mid, disabled ? midDisabled : mid);
        palette.setColor(group, QPalette::Dark, disabled ? midDisabled : dark);
        palette.setColor(group, QPalette::Shadow, disabled ? midDisabled : mid);
        palette.setColor(group, QPalette::Midlight, midlight);
        palette.setColor(group, QPalette::Light, light);
#if QT_VERSION >= QT_VERSION_CHECK(6, 6, 0)
        // the source accent, not the contrast-adjusted one: SystemPalette reads the
        // application's Accent back (qt-accent-color=system); widgetAccent() adjusts
        // it where the style draws
        palette.setColor(group, QPalette::Accent, highlight);
#endif
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
    QStyle* style = createWidgetStyle();
    if (!style)
        return false;
    QApplication::setStyle(style);
    return true;
}

} // namespace redesign
