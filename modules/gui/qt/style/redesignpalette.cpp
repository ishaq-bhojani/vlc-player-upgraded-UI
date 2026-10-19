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
#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include "redesignpalette.hpp"

#include <algorithm>
#include <array>
#include <cmath>

namespace redesign
{

namespace
{

using C = ColorContext;

// Table A of docs/redesign/tokens.md. The accent* and onAccent entries are
// placeholders for the default accent: fillPalette() derives them from the
// active accent.
enum class T
{
    bgWindow,
    bgPanel,
    bgBar,
    bgSunken,
    bgSecondary,
    bgField,
    bgSelected,
    bgPopup,
    lineSeparator,
    textStrong,
    textHeading,
    textTitle,
    textDefault,
    textMuted,
    textFaint,
    accent,
    accentDim,
    accentTint,
    accentPressed,
    onAccent,
    volumeGreen,
    sliderNeutral,
    sliderNegative,
    statusPositiveFg,
    statusNegativeFg,
    statusPositiveBg,
    statusNegativeBg,
    statusNeutralBg,
    indicator,
    inverseSurface,
    inverseOn,
    shadowColor
};

constexpr int TokenCount = 32;

struct TokenHex { QRgb dark; QRgb light; };

constexpr TokenHex tokenHex[TokenCount] = {
    {0x0E0E0E, 0xFAFAFA}, // bgWindow
    {0x191919, 0xF2F2F2}, // bgPanel
    {0x1B1B1B, 0xEDEDED}, // bgBar
    {0x090909, 0xE9E9E9}, // bgSunken
    {0x090909, 0xFFFFFF}, // bgSecondary
    {0x151515, 0xF6F6F6}, // bgField
    {0x222222, 0xE5E5E5}, // bgSelected
    {0x181818, 0xF6F6F6}, // bgPopup
    {0x212121, 0xE0E0E0}, // lineSeparator
    {0xEAEAEA, 0x000000}, // textStrong
    {0xC6C6C6, 0x212121}, // textHeading
    {0x969696, 0x4B4B4B}, // textTitle
    {0x8F8F8F, 0x666666}, // textDefault
    {0x6B6B6B, 0x808080}, // textMuted
    {0x404040, 0xB3B3B3}, // textFaint
    {0xD37918, 0xD37918}, // accent
    {0xAB6314, 0xAB6314}, // accentDim
    {0x371F06, 0xF2E0CD}, // accentTint
    {0xB76915, 0xB76915}, // accentPressed
    {0x161616, 0x161616}, // onAccent
    {0x79A512, 0x79A512}, // volumeGreen
    {0x9D5D00, 0x9D5D00}, // sliderNeutral
    {0xC42B1C, 0xC42B1C}, // sliderNegative
    {0x00FF00, 0x00FF00}, // statusPositiveFg
    {0xFF0000, 0xFF0000}, // statusNegativeFg
    {0x008000, 0xDFF6DD}, // statusPositiveBg
    {0x800000, 0xFDE7E9}, // statusNegativeBg
    {0x808000, 0xE4DAB8}, // statusNeutralBg
    {0x666666, 0x9E9E9E}, // indicator
    {0xFFFFFF, 0x000000}, // inverseSurface
    {0x000000, 0xFFFFFF}, // inverseOn
    {0x000000, 0x000000}, // shadowColor
};

struct Ref
{
    T token;
    float alpha;
};

// Table B of docs/redesign/tokens.md, row for row.
struct Row
{
    C::ColorSet set;
    C::ColorSection section;
    C::ColorName name;
    C::ColorState state;
    Ref dark;
    Ref light;
};

const Row rows[] = {
    {C::View, C::Bg, C::Primary, C::Normal, {T::bgWindow, 1.0f}, {T::bgWindow, 1.0f}},
    {C::View, C::Bg, C::Secondary, C::Normal, {T::bgSecondary, 1.0f}, {T::bgSecondary, 1.0f}},
    {C::View, C::Fg, C::Primary, C::Normal, {T::textDefault, 1.0f}, {T::textDefault, 1.0f}},
    {C::View, C::Fg, C::Primary, C::Disabled, {T::textFaint, 1.0f}, {T::textFaint, 1.0f}},
    {C::View, C::Fg, C::Secondary, C::Normal, {T::textMuted, 1.0f}, {T::textMuted, 1.0f}},
    {C::View, C::Bg, C::Negative, C::Normal, {T::statusNegativeBg, 1.0f}, {T::statusNegativeBg, 1.0f}},
    {C::View, C::Fg, C::Negative, C::Normal, {T::statusNegativeFg, 1.0f}, {T::statusNegativeFg, 1.0f}},
    {C::View, C::Bg, C::Neutral, C::Normal, {T::statusNeutralBg, 1.0f}, {T::statusNeutralBg, 1.0f}},
    {C::View, C::Fg, C::Neutral, C::Normal, {T::accent, 1.0f}, {T::accent, 1.0f}},
    {C::View, C::Bg, C::Positive, C::Normal, {T::statusPositiveBg, 1.0f}, {T::statusPositiveBg, 1.0f}},
    {C::View, C::Fg, C::Positive, C::Normal, {T::statusPositiveFg, 1.0f}, {T::statusPositiveFg, 1.0f}},
    {C::View, C::Decoration, C::VisualFocus, C::Normal, {T::inverseSurface, 0.0f}, {T::inverseSurface, 0.0f}},
    {C::View, C::Decoration, C::VisualFocus, C::Focused, {T::inverseSurface, 1.0f}, {T::inverseSurface, 1.0f}},
    {C::View, C::Decoration, C::Border, C::Normal, {T::inverseSurface, 0.4f}, {T::inverseSurface, 0.4f}},
    {C::View, C::Decoration, C::Border, C::Focused, {T::inverseSurface, 0.7f}, {T::inverseSurface, 0.7f}},
    {C::View, C::Decoration, C::Border, C::Hovered, {T::inverseSurface, 0.7f}, {T::inverseSurface, 0.7f}},
    {C::View, C::Decoration, C::Border, C::Disabled, {T::inverseSurface, 0.0f}, {T::inverseSurface, 0.0f}},
    {C::View, C::Decoration, C::Shadow, C::Normal, {T::shadowColor, 0.22f}, {T::shadowColor, 0.22f}},
    {C::View, C::Decoration, C::Separator, C::Normal, {T::lineSeparator, 1.0f}, {T::lineSeparator, 1.0f}},
    {C::View, C::Decoration, C::Accent, C::Normal, {T::accent, 1.0f}, {T::accent, 1.0f}},
    {C::View, C::Fg, C::Link, C::Normal, {T::accent, 1.0f}, {T::accent, 1.0f}},
    {C::Window, C::Bg, C::Primary, C::Normal, {T::bgBar, 1.0f}, {T::bgBar, 1.0f}},
    {C::Window, C::Bg, C::Secondary, C::Normal, {T::bgBar, 1.0f}, {T::bgBar, 1.0f}},
    {C::Window, C::Decoration, C::Border, C::Normal, {T::lineSeparator, 1.0f}, {T::lineSeparator, 1.0f}},
    {C::Window, C::Fg, C::Primary, C::Normal, {T::textDefault, 1.0f}, {T::textDefault, 1.0f}},
    {C::Window, C::Fg, C::Secondary, C::Normal, {T::textMuted, 1.0f}, {T::textMuted, 1.0f}},
    {C::Badge, C::Bg, C::Primary, C::Normal, {T::inverseSurface, 0.8f}, {T::inverseSurface, 0.6f}},
    {C::Badge, C::Fg, C::Primary, C::Normal, {T::inverseOn, 1.0f}, {T::inverseOn, 1.0f}},
    {C::Badge, C::Bg, C::Secondary, C::Normal, {T::bgSecondary, 1.0f}, {T::bgSecondary, 1.0f}},
    {C::Badge, C::Fg, C::Secondary, C::Normal, {T::textMuted, 1.0f}, {T::textMuted, 1.0f}},
    {C::TabButton, C::Bg, C::Primary, C::Normal, {T::bgSelected, 0.0f}, {T::bgSelected, 0.0f}},
    {C::TabButton, C::Bg, C::Primary, C::Focused, {T::bgSelected, 1.0f}, {T::bgSelected, 1.0f}},
    {C::TabButton, C::Bg, C::Primary, C::Hovered, {T::bgSelected, 1.0f}, {T::bgSelected, 1.0f}},
    {C::TabButton, C::Fg, C::Primary, C::Normal, {T::textMuted, 1.0f}, {T::textMuted, 1.0f}},
    {C::TabButton, C::Fg, C::Primary, C::Focused, {T::textDefault, 1.0f}, {T::textDefault, 1.0f}},
    {C::TabButton, C::Fg, C::Primary, C::Hovered, {T::textDefault, 1.0f}, {T::textDefault, 1.0f}},
    {C::TabButton, C::Fg, C::Primary, C::Disabled, {T::textFaint, 1.0f}, {T::textFaint, 1.0f}},
    {C::TabButton, C::Fg, C::Secondary, C::Normal, {T::textDefault, 1.0f}, {T::textDefault, 1.0f}},
    {C::TabButton, C::Bg, C::Secondary, C::Normal, {T::bgSecondary, 1.0f}, {T::bgSecondary, 1.0f}},
    {C::ToolButton, C::Bg, C::Primary, C::Normal, {T::bgSunken, 0.0f}, {T::bgSunken, 0.0f}},
    {C::ToolButton, C::Bg, C::Secondary, C::Normal, {T::bgSunken, 1.0f}, {T::bgSunken, 1.0f}},
    {C::ToolButton, C::Fg, C::Primary, C::Normal, {T::textDefault, 1.0f}, {T::textDefault, 1.0f}},
    {C::ToolButton, C::Fg, C::Primary, C::Focused, {T::textStrong, 1.0f}, {T::textStrong, 1.0f}},
    {C::ToolButton, C::Fg, C::Primary, C::Hovered, {T::textStrong, 1.0f}, {T::textStrong, 1.0f}},
    {C::ToolButton, C::Fg, C::Primary, C::Disabled, {T::textFaint, 1.0f}, {T::textFaint, 1.0f}},
    {C::ToolButton, C::Fg, C::Secondary, C::Normal, {T::textStrong, 1.0f}, {T::textStrong, 1.0f}},
    {C::ToolButton, C::Decoration, C::Border, C::Normal, {T::bgSunken, 0.0f}, {T::bgSunken, 0.0f}},
    {C::ToolButton, C::Decoration, C::Border, C::Focused, {T::bgSunken, 0.0f}, {T::bgSunken, 0.0f}},
    {C::ToolButton, C::Decoration, C::Border, C::Hovered, {T::bgSunken, 0.0f}, {T::bgSunken, 0.0f}},
    {C::ToolButton, C::Decoration, C::Border, C::Disabled, {T::bgSunken, 0.0f}, {T::bgSunken, 0.0f}},
    {C::MenuBar, C::Bg, C::Primary, C::Normal, {T::bgSelected, 0.0f}, {T::bgSelected, 0.0f}},
    {C::MenuBar, C::Bg, C::Primary, C::Focused, {T::bgSelected, 1.0f}, {T::bgSelected, 1.0f}},
    {C::MenuBar, C::Bg, C::Primary, C::Hovered, {T::bgSelected, 1.0f}, {T::bgSelected, 1.0f}},
    {C::MenuBar, C::Fg, C::Primary, C::Normal, {T::textDefault, 1.0f}, {T::textDefault, 1.0f}},
    {C::MenuBar, C::Fg, C::Primary, C::Disabled, {T::textFaint, 1.0f}, {T::textFaint, 1.0f}},
    {C::MenuBar, C::Bg, C::Secondary, C::Normal, {T::bgSecondary, 1.0f}, {T::bgSecondary, 1.0f}},
    {C::MenuBar, C::Fg, C::Secondary, C::Normal, {T::textMuted, 1.0f}, {T::textMuted, 1.0f}},
    {C::Item, C::Bg, C::Primary, C::Normal, {T::bgSelected, 0.0f}, {T::bgSelected, 0.0f}},
    {C::Item, C::Bg, C::Primary, C::Focused, {T::bgSelected, 0.5f}, {T::bgSelected, 0.5f}},
    {C::Item, C::Bg, C::Primary, C::Hovered, {T::bgSelected, 0.5f}, {T::bgSelected, 0.5f}},
    {C::Item, C::Bg, C::Highlight, C::Normal, {T::bgSelected, 1.0f}, {T::bgSelected, 1.0f}},
    {C::Item, C::Bg, C::Highlight, C::Focused, {T::bgSelected, 0.8f}, {T::bgSelected, 0.8f}},
    {C::Item, C::Bg, C::Highlight, C::Hovered, {T::bgSelected, 0.8f}, {T::bgSelected, 0.8f}},
    {C::Item, C::Fg, C::Highlight, C::Normal, {T::textStrong, 1.0f}, {T::textStrong, 1.0f}},
    {C::Item, C::Fg, C::Primary, C::Normal, {T::textTitle, 1.0f}, {T::textTitle, 1.0f}},
    {C::Item, C::Fg, C::Secondary, C::Normal, {T::textMuted, 1.0f}, {T::textMuted, 1.0f}},
    {C::Item, C::Decoration, C::Indicator, C::Normal, {T::indicator, 1.0f}, {T::indicator, 1.0f}},
    {C::Item, C::Bg, C::Secondary, C::Normal, {T::bgSecondary, 1.0f}, {T::bgSecondary, 1.0f}},
    {C::ButtonAccent, C::Bg, C::Primary, C::Normal, {T::accent, 1.0f}, {T::accent, 1.0f}},
    {C::ButtonAccent, C::Bg, C::Primary, C::Pressed, {T::accentPressed, 1.0f}, {T::accentPressed, 1.0f}},
    {C::ButtonAccent, C::Bg, C::Primary, C::Disabled, {T::inverseSurface, 0.2f}, {T::inverseSurface, 0.2f}},
    {C::ButtonAccent, C::Fg, C::Primary, C::Normal, {T::onAccent, 1.0f}, {T::onAccent, 1.0f}},
    {C::ButtonAccent, C::Fg, C::Primary, C::Disabled, {T::inverseSurface, 0.3f}, {T::inverseSurface, 0.3f}},
    {C::ButtonAccent, C::Decoration, C::Border, C::Normal, {T::accent, 0.0f}, {T::accent, 0.0f}},
    {C::ButtonAccent, C::Decoration, C::Border, C::Focused, {T::accent, 0.0f}, {T::accent, 0.0f}},
    {C::ButtonAccent, C::Decoration, C::Border, C::Hovered, {T::accent, 0.0f}, {T::accent, 0.0f}},
    {C::ButtonAccent, C::Decoration, C::Border, C::Disabled, {T::accent, 0.0f}, {T::accent, 0.0f}},
    {C::ButtonAccent, C::Bg, C::Secondary, C::Normal, {T::bgSecondary, 1.0f}, {T::bgSecondary, 1.0f}},
    {C::ButtonAccent, C::Fg, C::Secondary, C::Normal, {T::textMuted, 1.0f}, {T::textMuted, 1.0f}},
    {C::ButtonStandard, C::Bg, C::Primary, C::Normal, {T::bgPanel, 1.0f}, {T::bgPanel, 1.0f}},
    {C::ButtonStandard, C::Fg, C::Primary, C::Normal, {T::textDefault, 1.0f}, {T::textDefault, 1.0f}},
    {C::ButtonStandard, C::Fg, C::Primary, C::Focused, {T::textStrong, 1.0f}, {T::textStrong, 1.0f}},
    {C::ButtonStandard, C::Fg, C::Primary, C::Hovered, {T::textStrong, 1.0f}, {T::textStrong, 1.0f}},
    {C::ButtonStandard, C::Fg, C::Primary, C::Disabled, {T::textFaint, 1.0f}, {T::textFaint, 1.0f}},
    {C::ButtonStandard, C::Decoration, C::Border, C::Normal, {T::bgPanel, 0.0f}, {T::bgPanel, 0.0f}},
    {C::ButtonStandard, C::Decoration, C::Border, C::Focused, {T::bgPanel, 0.0f}, {T::bgPanel, 0.0f}},
    {C::ButtonStandard, C::Decoration, C::Border, C::Hovered, {T::bgPanel, 0.0f}, {T::bgPanel, 0.0f}},
    {C::ButtonStandard, C::Decoration, C::Border, C::Disabled, {T::bgPanel, 0.0f}, {T::bgPanel, 0.0f}},
    {C::ButtonStandard, C::Bg, C::Secondary, C::Normal, {T::bgSecondary, 1.0f}, {T::bgSecondary, 1.0f}},
    {C::ButtonStandard, C::Fg, C::Secondary, C::Normal, {T::textMuted, 1.0f}, {T::textMuted, 1.0f}},
    {C::Tooltip, C::Bg, C::Primary, C::Normal, {T::bgPopup, 1.0f}, {T::bgPopup, 1.0f}},
    {C::Tooltip, C::Fg, C::Primary, C::Normal, {T::textStrong, 1.0f}, {T::textStrong, 1.0f}},
    {C::Tooltip, C::Bg, C::Secondary, C::Normal, {T::bgSecondary, 1.0f}, {T::bgSecondary, 1.0f}},
    {C::Tooltip, C::Fg, C::Secondary, C::Normal, {T::textMuted, 1.0f}, {T::textMuted, 1.0f}},
    {C::Slider, C::Bg, C::Primary, C::Normal, {T::bgSunken, 1.0f}, {T::bgSunken, 1.0f}},
    {C::Slider, C::Bg, C::Primary, C::Focused, {T::bgSunken, 1.0f}, {T::bgSunken, 1.0f}},
    {C::Slider, C::Bg, C::Primary, C::Hovered, {T::bgSunken, 1.0f}, {T::bgSunken, 1.0f}},
    {C::Slider, C::Bg, C::Secondary, C::Normal, {T::bgSunken, 1.0f}, {T::bgSunken, 1.0f}},
    {C::Slider, C::Fg, C::Primary, C::Normal, {T::accentTint, 1.0f}, {T::accent, 1.0f}},
    {C::Slider, C::Fg, C::Positive, C::Normal, {T::volumeGreen, 1.0f}, {T::volumeGreen, 1.0f}},
    {C::Slider, C::Fg, C::Neutral, C::Normal, {T::sliderNeutral, 1.0f}, {T::sliderNeutral, 1.0f}},
    {C::Slider, C::Fg, C::Negative, C::Normal, {T::sliderNegative, 1.0f}, {T::sliderNegative, 1.0f}},
    {C::Slider, C::Fg, C::Secondary, C::Normal, {T::textMuted, 1.0f}, {T::textMuted, 1.0f}},
    {C::ComboBox, C::Fg, C::Primary, C::Normal, {T::textDefault, 1.0f}, {T::textDefault, 1.0f}},
    {C::ComboBox, C::Bg, C::Primary, C::Normal, {T::bgPanel, 1.0f}, {T::bgPanel, 1.0f}},
    {C::ComboBox, C::Bg, C::Secondary, C::Normal, {T::bgPopup, 1.0f}, {T::bgPopup, 1.0f}},
    {C::ComboBox, C::Fg, C::Secondary, C::Normal, {T::textMuted, 1.0f}, {T::textMuted, 1.0f}},
    {C::TextField, C::Decoration, C::Border, C::Normal, {T::bgPanel, 1.0f}, {T::bgPanel, 1.0f}},
    {C::TextField, C::Decoration, C::Border, C::Focused, {T::accent, 1.0f}, {T::accent, 1.0f}},
    {C::TextField, C::Decoration, C::Border, C::Hovered, {T::textFaint, 1.0f}, {T::textFaint, 1.0f}},
    {C::TextField, C::Decoration, C::Border, C::Disabled, {T::bgPanel, 0.0f}, {T::bgPanel, 0.0f}},
    {C::TextField, C::Bg, C::Highlight, C::Normal, {T::accentTint, 1.0f}, {T::accentTint, 1.0f}},
    {C::TextField, C::Fg, C::Highlight, C::Normal, {T::textStrong, 1.0f}, {T::textStrong, 1.0f}},
    {C::TextField, C::Bg, C::Primary, C::Normal, {T::bgSunken, 1.0f}, {T::bgSunken, 1.0f}},
    {C::TextField, C::Fg, C::Primary, C::Normal, {T::textDefault, 1.0f}, {T::textDefault, 1.0f}},
    {C::TextField, C::Bg, C::Secondary, C::Normal, {T::bgSecondary, 1.0f}, {T::bgSecondary, 1.0f}},
    {C::TextField, C::Fg, C::Secondary, C::Normal, {T::textMuted, 1.0f}, {T::textMuted, 1.0f}},
    {C::SpinBox, C::Decoration, C::Border, C::Normal, {T::bgPanel, 1.0f}, {T::bgPanel, 1.0f}},
    {C::SpinBox, C::Decoration, C::Border, C::Focused, {T::accent, 1.0f}, {T::accent, 1.0f}},
    {C::SpinBox, C::Decoration, C::Border, C::Hovered, {T::textFaint, 1.0f}, {T::textFaint, 1.0f}},
    {C::SpinBox, C::Decoration, C::Border, C::Disabled, {T::bgPanel, 0.0f}, {T::bgPanel, 0.0f}},
    {C::SpinBox, C::Bg, C::Highlight, C::Normal, {T::accentTint, 1.0f}, {T::accentTint, 1.0f}},
    {C::SpinBox, C::Fg, C::Highlight, C::Normal, {T::textStrong, 1.0f}, {T::textStrong, 1.0f}},
    {C::SpinBox, C::Bg, C::Primary, C::Normal, {T::bgSunken, 1.0f}, {T::bgSunken, 1.0f}},
    {C::SpinBox, C::Fg, C::Primary, C::Normal, {T::textDefault, 1.0f}, {T::textDefault, 1.0f}},
    {C::SpinBox, C::Bg, C::Secondary, C::Normal, {T::bgSecondary, 1.0f}, {T::bgSecondary, 1.0f}},
    {C::SpinBox, C::Fg, C::Secondary, C::Normal, {T::textMuted, 1.0f}, {T::textMuted, 1.0f}},
    {C::Switch, C::Bg, C::Primary, C::Normal, {T::bgPanel, 1.0f}, {T::bgPanel, 1.0f}},
    {C::Switch, C::Fg, C::Primary, C::Normal, {T::textFaint, 1.0f}, {T::textFaint, 1.0f}},
    {C::Switch, C::Decoration, C::Border, C::Normal, {T::bgSunken, 1.0f}, {T::bgSunken, 1.0f}},
    {C::Switch, C::Bg, C::Secondary, C::Normal, {T::accentDim, 1.0f}, {T::inverseOn, 1.0f}},
    {C::Switch, C::Fg, C::Secondary, C::Normal, {T::accent, 1.0f}, {T::onAccent, 1.0f}},
    {C::Switch, C::Decoration, C::Accent, C::Normal, {T::accentTint, 1.0f}, {T::accent, 1.0f}},
};

QColor mix(const QColor& top, const QColor& under, double amount)
{
    auto channel = [=](int a, int b) { return int(std::lround(a * amount + b * (1.0 - amount))); };
    return QColor(channel(top.red(), under.red()),
                  channel(top.green(), under.green()),
                  channel(top.blue(), under.blue()));
}

double linearChannel(double c)
{
    return c <= 0.03928 ? c / 12.92 : std::pow((c + 0.055) / 1.055, 2.4);
}

double relativeLuminance(const QColor& c)
{
    return 0.2126 * linearChannel(c.redF())
         + 0.7152 * linearChannel(c.greenF())
         + 0.0722 * linearChannel(c.blueF());
}

std::array<QColor, TokenCount> resolveTokens(bool dark, const AccentShades& accent)
{
    std::array<QColor, TokenCount> colors;
    for (int i = 0; i < TokenCount; ++i)
        colors[i] = QColor::fromRgb(dark ? tokenHex[i].dark : tokenHex[i].light);

    auto set = [&](T t, const QColor& c) { colors[int(t)] = c; };
    const QColor bgWindow = colors[int(T::bgWindow)];

    set(T::accent, accent.base);
    // darker() returns an HSV colour, store it as plain 8 bit RGB
    set(T::accentPressed, QColor::fromRgb(accent.pressed.rgb()));
    set(T::onAccent, accent.onAccent);
    // Dim: 80% of the accent over the sunken surface (#AB6315 for the default
    // accent, Table A has #AB6314).
    set(T::accentDim, mix(accent.base, QColor::fromRgb(tokenHex[int(T::bgSunken)].dark), 0.8));
    if (dark) {
        // Tint: the accent at about 26% strength over black (#371F06 for the default accent).
        set(T::accentTint, mix(accent.base, Qt::black, 0.26));
    } else {
        // Tint: 20% of the accent over the window background (#F2E0CD for the default accent).
        set(T::accentTint, mix(accent.base, bgWindow, 0.2));
    }
    return colors;
}

} // anonymous namespace

QColor defaultAccent()
{
    return QColor(0xD3, 0x79, 0x18);
}

QVector<QColor> accentSwatches()
{
    // "Applied accent hex" column of Table C, in Figma order.
    return {
        QColor(0xD3, 0x79, 0x18), // Orange (default)
        QColor(0xE1, 0x50, 0x32), // Red
        QColor(0xC4, 0x9F, 0x23), // Gold
        QColor(0x19, 0xA2, 0x35), // Green
        QColor(0x19, 0xAA, 0xD4), // Teal
        QColor(0x19, 0x5D, 0xD4), // Blue
        QColor(0x8E, 0x42, 0xFF), // Purple
        QColor(0xF0, 0x52, 0xB3), // Pink
        QColor(0xAF, 0xAF, 0xAF), // Grey
    };
}

QColor parseAccent(const char* value, QColor fallback)
{
    if (!value || !qstrcmp(value, "default"))
        return fallback;
    QColor c(QString::fromUtf8(value));
    if (!c.isValid())
        return fallback;
    c.setAlpha(255);
    return c;
}

double contrastRatio(QColor a, QColor b)
{
    const double la = relativeLuminance(a);
    const double lb = relativeLuminance(b);
    return (std::max(la, lb) + 0.05) / (std::min(la, lb) + 0.05);
}

QColor onAccentColor(QColor accent)
{
    return contrastRatio(accent, Qt::black) >= contrastRatio(accent, Qt::white)
        ? QColor(Qt::black) : QColor(Qt::white);
}

AccentShades accentShades(QColor base)
{
    if (!base.isValid())
        base = defaultAccent();
    return { base, base.lighter(115), base.darker(115), onAccentColor(base) };
}

void fillPalette(const ColorSink& sink, bool dark, const AccentShades& accent)
{
    const auto colors = resolveTokens(dark, accent);
    for (const Row& row : rows) {
        const Ref& ref = dark ? row.dark : row.light;
        QColor color = colors[int(ref.token)];
        color.setAlphaF(ref.alpha);
        sink(row.set, row.section, row.name, row.state, color);
    }
}

} // namespace redesign
