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

#include <QApplication>
#include <QHash>
#include <QTest>

#include "../redesign/cpp/widgetpalette.hpp"
#include "../style/redesignpalette.hpp"

using C = ColorContext;

namespace
{

quint64 key(C::ColorSet set, C::ColorSection section, C::ColorName name, C::ColorState state)
{
    return (quint64(set) << 16) + (quint64(name) << 8) + (quint64(section) << 4) + quint64(state);
}

// A lookup over fillPalette() output, with the same fallback as
// SystemPalette::getColor: Disabled/Hovered/... falls back to Normal.
redesign::ColorLookup makeLookup(bool dark)
{
    auto colors = std::make_shared<QHash<quint64, QColor>>();
    redesign::fillPalette(
        [colors](C::ColorSet set, C::ColorSection section, C::ColorName name, C::ColorState state, QColor color) {
            colors->insert(key(set, section, name, state), color);
        },
        dark, redesign::accentShades(redesign::defaultAccent()));
    return [colors](C::ColorSet set, C::ColorSection section, C::ColorName name, C::ColorState state) {
        auto it = colors->constFind(key(set, section, name, state));
        if (it == colors->constEnd())
            it = colors->constFind(key(set, section, name, C::Normal));
        return it == colors->constEnd() ? QColor(Qt::magenta) : *it;
    };
}

} // namespace

class TestRedesignWidgetPalette : public QObject
{
    Q_OBJECT

private slots:
    // Must stay the only test calling applyWidgetPalette(): the restore point
    // is captured by its first call in the process.
    void applyThenEmptyRestoresTheOriginalPalette()
    {
        const QPalette before = QApplication::palette();

        // no installFusionStyle() first: the saved-style path
        redesign::applyWidgetPalette(makeLookup(true));
        QCOMPARE(QApplication::palette().color(QPalette::Highlight),
                 makeLookup(true)(C::ButtonAccent, C::Bg, C::Primary, C::Normal));
        QVERIFY(QApplication::palette() != before);

        redesign::applyWidgetPalette(redesign::ColorLookup());
        QVERIFY(QApplication::palette() == before);

        // and applying again after a restore works
        redesign::applyWidgetPalette(makeLookup(false));
        QCOMPARE(QApplication::palette().color(QPalette::Window),
                 makeLookup(false)(C::Window, C::Bg, C::Primary, C::Normal));
        redesign::applyWidgetPalette(redesign::ColorLookup());
        QVERIFY(QApplication::palette() == before);
    }

    void roleMapping_data()
    {
        QTest::addColumn<bool>("dark");
        QTest::newRow("dark") << true;
        QTest::newRow("light") << false;
    }

    void roleMapping()
    {
        QFETCH(bool, dark);
        const auto lookup = makeLookup(dark);
        const QPalette p = redesign::toWidgetPalette(lookup);

        for (auto group : {QPalette::Active, QPalette::Inactive, QPalette::Disabled}) {
            QCOMPARE(p.color(group, QPalette::Window), lookup(C::Window, C::Bg, C::Primary, C::Normal));
            QCOMPARE(p.color(group, QPalette::Base), lookup(C::View, C::Bg, C::Secondary, C::Normal));
            QCOMPARE(p.color(group, QPalette::Button), lookup(C::ButtonStandard, C::Bg, C::Primary, C::Normal));
            QCOMPARE(p.color(group, QPalette::Highlight), lookup(C::ButtonAccent, C::Bg, C::Primary, C::Normal));
            QCOMPARE(p.color(group, QPalette::HighlightedText), lookup(C::ButtonAccent, C::Fg, C::Primary, C::Normal));
            QCOMPARE(p.color(group, QPalette::ToolTipBase), lookup(C::Tooltip, C::Bg, C::Primary, C::Normal));
            QCOMPARE(p.color(group, QPalette::ToolTipText), lookup(C::Tooltip, C::Fg, C::Primary, C::Normal));
        }
        QCOMPARE(p.color(QPalette::Active, QPalette::WindowText), lookup(C::Window, C::Fg, C::Primary, C::Normal));
        QCOMPARE(p.color(QPalette::Active, QPalette::Text), lookup(C::View, C::Fg, C::Primary, C::Normal));
        QCOMPARE(p.color(QPalette::Active, QPalette::ButtonText), lookup(C::ButtonStandard, C::Fg, C::Primary, C::Normal));
        QCOMPARE(p.color(QPalette::Inactive, QPalette::Text), lookup(C::View, C::Fg, C::Primary, C::Normal));
    }

    void highlightFollowsTheAccent()
    {
        const QColor blue = redesign::accentSwatches()[5];
        auto colors = std::make_shared<QHash<quint64, QColor>>();
        redesign::fillPalette(
            [colors](C::ColorSet set, C::ColorSection section, C::ColorName name, C::ColorState state, QColor color) {
                colors->insert(key(set, section, name, state), color);
            },
            true, redesign::accentShades(blue));
        const QPalette p = redesign::toWidgetPalette(
            [colors](C::ColorSet set, C::ColorSection section, C::ColorName name, C::ColorState state) {
                return colors->value(key(set, section, name, state), colors->value(key(set, section, name, C::Normal)));
            });
        QCOMPARE(p.color(QPalette::Highlight), blue);
    }

    void disabledTextComesFromTheDisabledState()
    {
        for (bool dark : {true, false}) {
            const auto lookup = makeLookup(dark);
            const QPalette p = redesign::toWidgetPalette(lookup);
            const QColor disabled = lookup(C::View, C::Fg, C::Primary, C::Disabled);
            QCOMPARE(p.color(QPalette::Disabled, QPalette::Text), disabled);
            QCOMPARE(p.color(QPalette::Disabled, QPalette::WindowText), disabled);
            QCOMPARE(p.color(QPalette::Disabled, QPalette::ButtonText),
                     lookup(C::ButtonStandard, C::Fg, C::Primary, C::Disabled));
            QVERIFY(p.color(QPalette::Disabled, QPalette::Text) != p.color(QPalette::Active, QPalette::Text));
        }
    }

    void everyRoleIsOpaqueOrDefined()
    {
        // the palette must never hand a widget the "missing color" magenta
        const QPalette p = redesign::toWidgetPalette(makeLookup(true));
        for (auto group : {QPalette::Active, QPalette::Inactive, QPalette::Disabled}) {
            for (auto role : {QPalette::Window, QPalette::WindowText, QPalette::Base, QPalette::Text,
                              QPalette::Button, QPalette::ButtonText, QPalette::Highlight,
                              QPalette::HighlightedText, QPalette::ToolTipBase, QPalette::ToolTipText,
                              QPalette::PlaceholderText, QPalette::Link}) {
                QVERIFY(p.color(group, role).isValid());
                QVERIFY(p.color(group, role) != QColor(Qt::magenta));
            }
        }
    }
};

QTEST_MAIN(TestRedesignWidgetPalette)
#include "test_redesign_widget_palette.moc"
