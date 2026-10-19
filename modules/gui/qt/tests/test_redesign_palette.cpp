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

#include <QSet>
#include <QTest>

#include "../style/redesignpalette.hpp"

using C = ColorContext;

namespace
{

quint64 key(C::ColorSet set, C::ColorSection section, C::ColorName name, C::ColorState state)
{
    return (quint64(set) << 16) + (quint64(name) << 8) + (quint64(section) << 4) + quint64(state);
}

const C::ColorSet allSets[] = {
    C::View, C::Window, C::Item, C::Badge, C::ButtonStandard, C::ButtonAccent, C::ToolButton,
    C::TabButton, C::MenuBar, C::Tooltip, C::Slider, C::ComboBox, C::SpinBox, C::TextField, C::Switch
};

struct Filled
{
    QSet<quint64> seen;
    QHash<quint64, QColor> colors;
};

Filled fill(bool dark, const redesign::AccentShades& accent)
{
    Filled f;
    redesign::fillPalette(
        [&f](C::ColorSet set, C::ColorSection section, C::ColorName name, C::ColorState state, QColor color) {
            f.seen.insert(key(set, section, name, state));
            f.colors[key(set, section, name, state)] = color;
        },
        dark, accent);
    return f;
}

} // namespace

class TestRedesignPalette : public QObject
{
    Q_OBJECT

private slots:
    void invalidAccentFallsBack()
    {
        QCOMPARE(redesign::parseAccent("#zzz", redesign::defaultAccent()), redesign::defaultAccent());
        QCOMPARE(redesign::parseAccent("banana", redesign::defaultAccent()), redesign::defaultAccent());
        QCOMPARE(redesign::parseAccent("", redesign::defaultAccent()), redesign::defaultAccent());
        QCOMPARE(redesign::parseAccent(nullptr, redesign::defaultAccent()), redesign::defaultAccent());
        QCOMPARE(redesign::parseAccent("default", QColor("#123456")), QColor("#123456"));
        QCOMPARE(redesign::parseAccent("#00ff00", redesign::defaultAccent()), QColor("#00ff00"));
        QCOMPARE(redesign::parseAccent("red", redesign::defaultAccent()), QColor(Qt::red));
    }

    void unsupportedAccentNeverReachesTheShadesInvalid()
    {
        // "system" is not a color; on Qt < 6.6 it is the unsupported value
        QVERIFY(redesign::parseAccent("system", redesign::defaultAccent()).isValid());
        QCOMPARE(redesign::parseAccent("system", redesign::defaultAccent()), redesign::defaultAccent());
        const auto shades = redesign::accentShades(QColor());
        QVERIFY(shades.base.isValid());
        QVERIFY(shades.hover.isValid());
        QVERIFY(shades.pressed.isValid());
        QVERIFY(shades.onAccent.isValid());
        const Filled f = fill(true, shades);
        QCOMPARE(f.colors.value(key(C::ButtonAccent, C::Bg, C::Primary, C::Normal)), redesign::defaultAccent());
    }

    void swatchesAreNine()
    {
        QCOMPARE(redesign::accentSwatches().size(), 9);
        QCOMPARE(redesign::accentSwatches().first(), redesign::defaultAccent());
        QCOMPARE(redesign::defaultAccent(), QColor("#D37918"));
    }

    void onAccentMeetsAA_data()
    {
        QTest::addColumn<QColor>("accent");
        const QVector<QColor> swatches = redesign::accentSwatches();
        for (int i = 0; i < swatches.size(); ++i)
            QTest::newRow(qPrintable(swatches[i].name())) << swatches[i];
    }

    void onAccentMeetsAA()
    {
        QFETCH(QColor, accent);
        const QColor on = redesign::onAccentColor(accent);
        const double ratio = redesign::contrastRatio(accent, on);
        qInfo("%s on %s: %.2f", qPrintable(on.name()), qPrintable(accent.name()), ratio);
        QVERIFY2(ratio >= 4.5, qPrintable(QStringLiteral("best of black/white on %1 is only %2")
                                              .arg(accent.name()).arg(ratio)));
    }

    void contrastKnownValues()
    {
        QCOMPARE(qRound(redesign::contrastRatio(Qt::black, Qt::white) * 10), 210);
        QCOMPARE(redesign::contrastRatio(Qt::white, Qt::black), redesign::contrastRatio(Qt::black, Qt::white));
        QCOMPARE(redesign::contrastRatio(Qt::red, Qt::red), 1.0);
    }

    void shadesFollowThePlan()
    {
        const auto shades = redesign::accentShades(redesign::defaultAccent());
        QCOMPARE(shades.base, redesign::defaultAccent());
        QCOMPARE(shades.hover, redesign::defaultAccent().lighter(115));
        QCOMPARE(shades.pressed, redesign::defaultAccent().darker(115));
        QCOMPARE(shades.pressed.rgb(), QColor("#B76915").rgb());
        QCOMPARE(shades.onAccent, QColor(Qt::black));
    }

    void everySlotFilled_data()
    {
        QTest::addColumn<bool>("dark");
        QTest::newRow("dark") << true;
        QTest::newRow("light") << false;
    }

    void everySlotFilled()
    {
        QFETCH(bool, dark);
        const Filled f = fill(dark, redesign::accentShades(redesign::defaultAccent()));
        for (C::ColorSet set : allSets) {
            for (C::ColorSection section : {C::Fg, C::Bg}) {
                for (C::ColorName name : {C::Primary, C::Secondary}) {
                    QVERIFY2(f.seen.contains(key(set, section, name, C::Normal)),
                             qPrintable(QStringLiteral("set %1 section %2 name %3 missing")
                                            .arg(int(set)).arg(int(section)).arg(int(name))));
                }
            }
        }
        // 133 rows of Table B of docs/redesign/tokens.md
        QCOMPARE(f.seen.size(), 133);
        for (const QColor& c : f.colors)
            QVERIFY(c.isValid());
    }

    void darkViewBackgroundMatchesTokens()
    {
        const Filled f = fill(true, redesign::accentShades(redesign::defaultAccent()));
        QCOMPARE(f.colors.value(key(C::View, C::Bg, C::Primary, C::Normal)), QColor("#0E0E0E"));
        const Filled l = fill(false, redesign::accentShades(redesign::defaultAccent()));
        QCOMPARE(l.colors.value(key(C::View, C::Bg, C::Primary, C::Normal)), QColor("#FAFAFA"));
    }

    void defaultAccentReproducesTokens()
    {
        const auto shades = redesign::accentShades(redesign::defaultAccent());
        const Filled d = fill(true, shades);
        QCOMPARE(d.colors.value(key(C::ButtonAccent, C::Bg, C::Primary, C::Normal)), QColor("#D37918"));
        QCOMPARE(d.colors.value(key(C::ButtonAccent, C::Bg, C::Primary, C::Pressed)), QColor("#B76915"));
        QCOMPARE(d.colors.value(key(C::Slider, C::Fg, C::Primary, C::Normal)), QColor("#371F06"));
        const Filled l = fill(false, shades);
        QCOMPARE(l.colors.value(key(C::TextField, C::Bg, C::Highlight, C::Normal)), QColor("#F2E0CD"));
    }

    void accentFollowsTheChosenColor()
    {
        const QColor blue = redesign::accentSwatches()[5];
        const auto shades = redesign::accentShades(blue);
        for (bool dark : {true, false}) {
            const Filled f = fill(dark, shades);
            QCOMPARE(f.colors.value(key(C::ButtonAccent, C::Bg, C::Primary, C::Normal)), blue);
            QCOMPARE(f.colors.value(key(C::View, C::Decoration, C::Accent, C::Normal)), blue);
            QCOMPARE(f.colors.value(key(C::ButtonAccent, C::Fg, C::Primary, C::Normal)), shades.onAccent);
            QCOMPARE(f.colors.value(key(C::ButtonAccent, C::Bg, C::Primary, C::Pressed)), QColor::fromRgb(shades.pressed.rgb()));
        }
    }
};

QTEST_GUILESS_MAIN(TestRedesignPalette)
#include "test_redesign_palette.moc"
