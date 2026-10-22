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
#include <QBoxLayout>
#include <QCheckBox>
#include <QComboBox>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGridLayout>
#include <QGroupBox>
#include <QStyledItemDelegate>
#include <QScreen>
#include <QHash>
#include <QHeaderView>
#include <QImage>
#include <QLabel>
#include <QLineEdit>
#include <QPainter>
#include <QProxyStyle>
#include <QPushButton>
#include <QRadioButton>
#include <QSpinBox>
#include <QStyleOption>
#include <QTableWidget>
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
redesign::ColorLookup makeLookup(bool dark, QColor accent = redesign::defaultAccent())
{
    auto colors = std::make_shared<QHash<quint64, QColor>>();
    redesign::fillPalette(
        [colors](C::ColorSet set, C::ColorSection section, C::ColorName name, C::ColorState state, QColor color) {
            colors->insert(key(set, section, name, state), color);
        },
        dark, redesign::accentShades(accent));
    return [colors](C::ColorSet set, C::ColorSection section, C::ColorName name, C::ColorState state) {
        auto it = colors->constFind(key(set, section, name, state));
        if (it == colors->constEnd())
            it = colors->constFind(key(set, section, name, C::Normal));
        return it == colors->constEnd() ? QColor(Qt::magenta) : *it;
    };
}

double contrast(const QColor& a, const QColor& b)
{
    return redesign::contrastRatio(a, b);
}

// Same shape as the stock MLFoldersEditor (a QTableWidget of the same class
// name, which the redesign style looks for), filled like newRow() does.
class MLFoldersEditor : public QTableWidget
{
    Q_OBJECT

public:
    MLFoldersEditor() : QTableWidget(0, 3)
    {
        setHorizontalHeaderLabels({QStringLiteral("Path"), QStringLiteral("Remove"), QStringLiteral("Reload")});
        horizontalHeader()->setMinimumSectionSize(100);
        horizontalHeader()->setSectionResizeMode(0, QHeaderView::Stretch);
        horizontalHeader()->setFixedHeight(24);
        for (const char* path : {"C:\\Users\\Pc\\Videos", "C:\\Users\\Pc\\Music"}) {
            const int row = rowCount();
            setRowCount(row + 1);
            setItem(row, 0, new QTableWidgetItem(QString::fromLatin1(path)));
            for (int col : {1, 2}) {
                auto* cell = new QWidget(this);
                auto* layout = new QBoxLayout(QBoxLayout::LeftToRight, cell);
                auto* button = new QPushButton(col == 1 ? QStringLiteral("-") : QStringLiteral("\u27F3"), cell);
                button->setFixedSize(18, 18);
                layout->addWidget(button, Qt::AlignCenter);
                setCellWidget(row, col, cell);
            }
        }
    }
};

QDir previewDir()
{
    QString path = qEnvironmentVariable("VIREO_PREVIEW_DIR");
    if (path.isEmpty())
        path = QDir::tempPath() + QStringLiteral("/vireo-brand-preview");
    QDir dir(path);
    dir.mkpath(QStringLiteral("."));
    return dir;
}

// The widgets of the owner's screenshots: indicators, then the outlined controls.
QImage renderControls(bool dark)
{
    QWidget panel;
    panel.setPalette(redesign::toWidgetPalette(makeLookup(dark)));
    panel.setAutoFillBackground(true);
    auto* layout = new QVBoxLayout(&panel);

    auto row = [&](std::initializer_list<QWidget*> widgets) {
        auto* line = new QHBoxLayout;
        for (QWidget* w : widgets)
            line->addWidget(w);
        line->addStretch();
        layout->addLayout(line);
    };
    auto box = [&](const QString& text, bool checked, bool enabled) {
        auto* b = new QCheckBox(text);
        b->setChecked(checked);
        b->setEnabled(enabled);
        return b;
    };
    auto radio = [&](const QString& text, bool checked, bool enabled) {
        auto* b = new QRadioButton(text);
        b->setAutoExclusive(false);
        b->setChecked(checked);
        b->setEnabled(enabled);
        return b;
    };
    row({box(QStringLiteral("Allow metadata network access"), false, true),
         box(QStringLiteral("Checked"), true, true)});
    // a mouse click leaves the box focused but draws no ring; Tab moves the
    // focus to the next one, with a ring
    auto* clicked = box(QStringLiteral("Clicked with the mouse (no ring)"), false, true);
    auto* tabbed = box(QStringLiteral("Reached with Tab (ring)"), false, true);
    row({clicked, tabbed});
    row({box(QStringLiteral("Enable the Media Library"), true, false),
         box(QStringLiteral("Disabled"), false, false)});
    row({radio(QStringLiteral("Radio"), false, true), radio(QStringLiteral("Selected"), true, true),
         radio(QStringLiteral("Disabled"), false, false), radio(QStringLiteral("Disabled on"), true, false)});

    auto* edit = new QLineEdit(QStringLiteral("Line edit"));
    auto* combo = new QComboBox;
    combo->addItems({QStringLiteral("Combo box"), QStringLiteral("Other")});
    auto* spin = new QSpinBox;
    spin->setValue(42);
    auto* disabledEdit = new QLineEdit(QStringLiteral("Disabled"));
    disabledEdit->setEnabled(false);
    row({edit, combo, spin, disabledEdit});

    auto* group = new QGroupBox(QStringLiteral("Group box"));
    auto* inner = new QVBoxLayout(group);
    inner->addWidget(new QLabel(QStringLiteral("Preferences")));
    layout->addWidget(group);

    panel.resize(panel.sizeHint().expandedTo(QSize(560, 0)));
    panel.show();
    if (!QTest::qWaitForWindowExposed(&panel))
        qWarning("the control sheet was not exposed");
    panel.activateWindow();
    if (!QTest::qWaitForWindowActive(&panel))
        qWarning("the control sheet was not activated");
    QTest::mouseClick(clicked, Qt::LeftButton);
    QTest::keyClick(&panel, Qt::Key_Tab);
    return panel.grab().toImage();
}

// Every button state, drawn with the style through QStyleOption (hover and
// pressed cannot be produced on a real widget without a mouse).
QImage renderButtons(bool dark, qreal dpr)
{
    const QPalette palette = redesign::toWidgetPalette(makeLookup(dark));
    QStyle* style = QApplication::style();
    struct StateColumn { const char* name; QStyle::State state; };
    const StateColumn columns[] = {
        {"normal", QStyle::State_Enabled},
        {"hover", QStyle::State_Enabled | QStyle::State_MouseOver},
        {"pressed", QStyle::State_Enabled | QStyle::State_MouseOver | QStyle::State_Sunken},
        {"focus", QStyle::State_Enabled | QStyle::State_HasFocus | QStyle::State_KeyboardFocusChange},
        {"disabled", QStyle::State_None},
    };
    const int cellW = 120, cellH = 44, labelW = 90, headH = 22;
    QImage image(QSize(labelW + cellW * 5, headH + cellH * 4) * dpr, QImage::Format_ARGB32_Premultiplied);
    image.setDevicePixelRatio(dpr);
    image.fill(palette.color(QPalette::Window));
    QPainter painter(&image);
    painter.setPen(palette.color(QPalette::WindowText));
    painter.setFont(QApplication::font());
    const char* rowNames[] = {"Back / Cancel", "Next / OK", "Tool (flat)", "Tool"};
    for (int c = 0; c < 5; ++c)
        painter.drawText(QRect(labelW + c * cellW, 0, cellW, headH), Qt::AlignCenter, QString::fromLatin1(columns[c].name));
    for (int r = 0; r < 4; ++r) {
        painter.setPen(palette.color(QPalette::WindowText));
        painter.drawText(QRect(4, headH + r * cellH, labelW - 4, cellH), Qt::AlignVCenter, QString::fromLatin1(rowNames[r]));
        for (int c = 0; c < 5; ++c) {
            const QRect rect(labelW + c * cellW + 6, headH + r * cellH + 2, cellW - 12, cellH - 4);
            if (r < 2) {
                QStyleOptionButton opt;
                opt.palette = palette;
                opt.rect = rect;
                opt.text = r == 0 ? QStringLiteral("< Back") : QStringLiteral("Next >");
                opt.state = columns[c].state;
                if (r == 1)
                    opt.features = QStyleOptionButton::DefaultButton;
                style->drawControl(QStyle::CE_PushButton, &opt, &painter, nullptr);
            } else {
                QStyleOptionToolButton opt;
                opt.palette = palette;
                opt.rect = rect.adjusted(30, 0, -30, 0);
                opt.text = QStringLiteral("-");
                opt.toolButtonStyle = Qt::ToolButtonTextOnly;
                opt.arrowType = Qt::NoArrow;
                opt.state = columns[c].state | (r == 2 ? QStyle::State_AutoRaise : QStyle::State_Raised);
                opt.features = QStyleOptionToolButton::None;
                // what CC_ToolButton paints: the panel, then the label
                style->drawPrimitive(QStyle::PE_PanelButtonTool, &opt, &painter, nullptr);
                style->drawControl(QStyle::CE_ToolButtonLabel, &opt, &painter, nullptr);
            }
        }
    }
    return image;
}

} // namespace

class TestRedesignWidgetPalette : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        // what the app does in redesign mode (qt.cpp)
        QVERIFY(redesign::installFusionStyle());
    }

    // Must stay the only test calling applyWidgetPalette(): the restore point
    // is captured by its first call in the process.
    void applyThenEmptyRestoresTheOriginalPalette()
    {
        const QPalette before = QApplication::palette();

        redesign::applyWidgetPalette(makeLookup(true));
#if QT_VERSION >= QT_VERSION_CHECK(6, 6, 0)
        // the application palette keeps the source accent: SystemPalette reads it
        // back for qt-accent-color=system, a contrast-adjusted one would feed back
        QCOMPARE(QApplication::palette().color(QPalette::Accent), redesign::defaultAccent());
#endif
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
            // the token's faint tone, lifted to 3:1 where it would be unreadable
            const QColor window = p.color(QPalette::Active, QPalette::Window);
            QCOMPARE(p.color(QPalette::Disabled, QPalette::WindowText), p.color(QPalette::Disabled, QPalette::Text));
            QVERIFY(contrast(p.color(QPalette::Disabled, QPalette::Text), window) >= 3.0);
            QVERIFY(contrast(p.color(QPalette::Disabled, QPalette::ButtonText), p.color(QPalette::Active, QPalette::Button)) >= 3.0);
            QVERIFY(p.color(QPalette::Disabled, QPalette::Text) != p.color(QPalette::Active, QPalette::Text));
            QVERIFY(lookup(C::View, C::Fg, C::Primary, C::Disabled) != lookup(C::View, C::Fg, C::Primary, C::Normal));
        }
    }

    void borderRolesHaveNonTextContrast_data()
    {
        QTest::addColumn<bool>("dark");
        QTest::addColumn<QColor>("accent");
        for (bool dark : {true, false}) {
            const QVector<QColor> swatches = redesign::accentSwatches();
            for (int i = 0; i < swatches.size(); ++i)
                QTest::addRow("%s-accent%d", dark ? "dark" : "light", i) << dark << swatches[i];
        }
    }

    // WCAG 1.4.11: 3:1 for the parts of a control needed to see it
    void borderRolesHaveNonTextContrast()
    {
        QFETCH(bool, dark);
        QFETCH(QColor, accent);
        const QPalette p = redesign::toWidgetPalette(makeLookup(dark, accent));
        for (auto group : {QPalette::Active, QPalette::Inactive}) {
            const QColor window = p.color(group, QPalette::Window);
            const QColor base = p.color(group, QPalette::Base);
            const QColor button = p.color(group, QPalette::Button);
            for (auto role : {QPalette::Mid, QPalette::Dark, QPalette::Shadow}) {
                const QColor c = p.color(group, role);
                QVERIFY2(contrast(c, window) >= 3.0, qPrintable(QStringLiteral("role %1 vs Window %2").arg(int(role)).arg(contrast(c, window))));
                QVERIFY2(contrast(c, base) >= 3.0, qPrintable(QStringLiteral("role %1 vs Base %2").arg(int(role)).arg(contrast(c, base))));
            }
            QVERIFY(contrast(p.color(group, QPalette::Mid), button) >= 3.0);
            QVERIFY(contrast(p.color(group, QPalette::Dark), button) >= 3.0);
            // the decorative highlights stay between the window and the strong text
            QVERIFY(contrast(p.color(group, QPalette::Light), window) > contrast(p.color(group, QPalette::Midlight), window));
            QVERIFY(contrast(p.color(group, QPalette::Midlight), window) > 1.05);
        }
        // disabled outlines are exempt from 1.4.11, but must not vanish
        const QColor midDisabled = p.color(QPalette::Disabled, QPalette::Mid);
        QVERIFY(contrast(midDisabled, p.color(QPalette::Disabled, QPalette::Window)) >= 2.0);
        QVERIFY(contrast(midDisabled, p.color(QPalette::Disabled, QPalette::Base)) >= 2.0);
        QVERIFY(midDisabled != p.color(QPalette::Active, QPalette::Mid));
        // the palette keeps the source accent (never the adjusted one, see
        // applyThenEmptyRestoresTheOriginalPalette); the style paints widgetAccent()
#if QT_VERSION >= QT_VERSION_CHECK(6, 6, 0)
        QCOMPARE(p.color(QPalette::Accent), accent);
#endif
        QCOMPARE(p.color(QPalette::Highlight), accent);
        const QColor painted = redesign::widgetAccent(p);
        QVERIFY(contrast(painted, p.color(QPalette::Window)) >= 3.0);
        QVERIFY(contrast(painted, p.color(QPalette::Base)) >= 3.0);
        // the default button's ring is inside its accent fill
        QVERIFY(contrast(redesign::focusRingColor(p, true), painted) >= 4.5);
        QVERIFY(contrast(redesign::focusRingColor(p, false), p.color(QPalette::Window)) >= 3.0);
    }

    void indicatorsAreVisibleInEveryState_data()
    {
        borderRolesHaveNonTextContrast_data();
    }

    void indicatorsAreVisibleInEveryState()
    {
        QFETCH(bool, dark);
        QFETCH(QColor, accent);
        const QPalette p = redesign::toWidgetPalette(makeLookup(dark, accent));
        const QColor window = p.color(QPalette::Window);
        const QColor base = p.color(QPalette::Base);
        for (bool checked : {false, true}) {
            for (QStyle::State extra : {QStyle::State_None, QStyle::State_MouseOver, QStyle::State_Sunken}) {
                const auto c = redesign::indicatorColors(p, QStyle::State_Enabled | extra, checked);
                QVERIFY(contrast(c.border, window) >= 3.0);
                QVERIFY(contrast(c.border, base) >= 3.0);
                if (checked)
                    QVERIFY(contrast(c.mark, c.fill) >= 3.0);
            }
            // disabled: outline and tick both stay above 2:1
            const auto d = redesign::indicatorColors(p, QStyle::State_None, checked);
            QVERIFY(contrast(d.border, window) >= 2.0);
            QVERIFY(contrast(d.border, base) >= 2.0);
            QVERIFY(contrast(d.mark, d.fill) >= 2.0);
        }
        // checked differs from unchecked
        QVERIFY(redesign::indicatorColors(p, QStyle::State_Enabled, true).fill
                != redesign::indicatorColors(p, QStyle::State_Enabled, false).fill);
    }

    void buttonStatesAreReadable_data()
    {
        borderRolesHaveNonTextContrast_data();
    }

    void buttonStatesAreReadable()
    {
        QFETCH(bool, dark);
        QFETCH(QColor, accent);
        const QPalette p = redesign::toWidgetPalette(makeLookup(dark, accent));
        const QStyle::State states[] = {QStyle::State_Enabled,
                                        QStyle::State_Enabled | QStyle::State_MouseOver,
                                        QStyle::State_Enabled | QStyle::State_Sunken,
                                        QStyle::State_Enabled | QStyle::State_On,
                                        QStyle::State_Enabled | QStyle::State_HasFocus,
                                        QStyle::State_None};
        for (bool isDefault : {false, true}) {
            for (bool flat : {false, true}) {
                for (QStyle::State state : states) {
                    const auto c = redesign::buttonColors(p, state, isDefault, flat);
                    const bool enabled = state & QStyle::State_Enabled;
                    const QString what = QStringLiteral("default=%1 flat=%2 state=%3 text %4 on fill %5")
                                             .arg(isDefault).arg(flat).arg(int(state)).arg(c.text.name(), c.fill.name());
                    QVERIFY2(contrast(c.text, c.fill) >= (enabled ? 4.5 : 3.0), qPrintable(what));
                    QCOMPARE(c.fill.alpha(), 255);
                }
            }
        }
        // the normal button is outlined at 3:1 against the window
        const auto normal = redesign::buttonColors(p, QStyle::State_Enabled, false);
        QVERIFY(contrast(normal.border, p.color(QPalette::Window)) >= 3.0);
        // hover is a subtle shift of the button colour, not a light grey wash
        const auto hover = redesign::buttonColors(p, QStyle::State_Enabled | QStyle::State_MouseOver, false);
        QVERIFY(hover.fill != normal.fill);
        QVERIFY(contrast(hover.fill, normal.fill) < 1.5);
        // the default button wears the accent fill
        const auto def = redesign::buttonColors(p, QStyle::State_Enabled, true);
        QCOMPARE(def.fill, QColor::fromRgb(redesign::widgetAccent(p).rgb()));
        QVERIFY(contrast(def.fill, p.color(QPalette::Window)) >= 3.0); // also on the light scheme
        const auto defHover = redesign::buttonColors(p, QStyle::State_Enabled | QStyle::State_MouseOver, true);
        QVERIFY(defHover.fill != def.fill);
        // a disabled default button is a plain disabled button
        QCOMPARE(redesign::buttonColors(p, QStyle::State_None, true).fill,
                 redesign::buttonColors(p, QStyle::State_None, false).fill);
    }

    void usesFusionNotTheNativeStyle()
    {
        // Fusion paints from the palette; windows11 and windowsvista draw
        // check boxes, buttons and borders from tables of their own
        const auto* proxy = qobject_cast<QProxyStyle*>(QApplication::style());
        QVERIFY(proxy);
        QCOMPARE(proxy->baseStyle()->name().toLower(), QStringLiteral("fusion"));
    }

    void renderChecksAndWritePngs_data()
    {
        QTest::addColumn<bool>("dark");
        QTest::newRow("dark") << true;
        QTest::newRow("light") << false;
    }

    // Looks at pixels: the outline of an indicator must stand out from the
    // background around it. The PNGs are for the human reviewer.
    void renderChecksAndWritePngs()
    {
        QFETCH(bool, dark);
        const QString name = dark ? QStringLiteral("dark") : QStringLiteral("light");
        const QPalette p = redesign::toWidgetPalette(makeLookup(dark));

        QVERIFY(renderControls(dark).save(previewDir().filePath(QStringLiteral("checkbox-%1.png").arg(name))));

        // the unchecked box alone: the strongest pixel in the indicator area
        QWidget probe;
        probe.setPalette(p);
        probe.setAutoFillBackground(true);
        auto* box = new QCheckBox(QString(), &probe);
        probe.resize(80, 40);
        box->move(8, 8);
        probe.show();
        QVERIFY(QTest::qWaitForWindowExposed(&probe));
        const QImage one = probe.grab().toImage();
        double best = 0;
        for (int y = 0; y < one.height(); ++y)
            for (int x = 0; x < one.width(); ++x)
                best = qMax(best, contrast(QColor(one.pixel(x, y)), p.color(QPalette::Window)));
        QVERIFY2(best >= 3.0, qPrintable(QStringLiteral("strongest indicator pixel only %1:1 on the window").arg(best)));

        QVERIFY(renderButtons(dark, QGuiApplication::primaryScreen()->devicePixelRatio()).save(previewDir().filePath(QStringLiteral("buttons-%1.png").arg(name))));

        // the wizard page: a title, the "+" button (16 px in the .ui file) and the table
        QWidget page;
        page.setPalette(p);
        page.setAutoFillBackground(true);
        auto* grid = new QGridLayout(&page);
        grid->addWidget(new QLabel(QStringLiteral("Folders scanned by the Media Library")), 0, 0);
        auto* add = new QPushButton(QStringLiteral("+"));
        add->setMaximumSize(16, 16);
        grid->addWidget(add, 0, 1);
        auto* table = new MLFoldersEditor;
        grid->addWidget(table, 1, 0, 1, 2);
        page.resize(620, 240);
        page.show();
        QVERIFY(QTest::qWaitForWindowExposed(&page));
        QVERIFY(!table->verticalHeader()->isVisible());
        QVERIFY(!table->showGrid());
        QVERIFY(table->verticalHeader()->defaultSectionSize() >= 30);
        QWidget* removeButton = table->cellWidget(0, 1)->findChild<QPushButton*>();
        QVERIFY(removeButton);
        QVERIFY(removeButton->width() >= 24 && removeButton->height() >= 24);
        QCOMPARE(add->text(), QStringLiteral("Add folder\u2026"));
        // sized to its label (not stretched), standard height, at the right edge
        QVERIFY(add->width() < 220 && add->width() > 80);
        QCOMPARE(add->height(), 32);
        QVERIFY(add->geometry().right() > page.width() - 30);
        // the Path header is left aligned, Remove and Reload stay centred
        QVERIFY(table->model()->headerData(0, Qt::Horizontal, Qt::TextAlignmentRole).toInt() & Qt::AlignLeft);
        QVERIFY(dynamic_cast<QStyledItemDelegate*>(table->itemDelegateForColumn(0)));
        QVERIFY(page.grab().toImage().save(previewDir().filePath(QStringLiteral("mlfolders-%1.png").arg(name))));
    }

    // The "+" of the first run wizard and of Advanced preferences is a 16 px
    // button; beside a folder table the redesign style turns it into a label
    void addFolderButtonGetsALabel()
    {
        QWidget page;
        auto* layout = new QVBoxLayout(&page);
        auto* add = new QPushButton(QStringLiteral("+"));
        add->setMaximumSize(16, 16);
        add->setToolTip(QStringLiteral("Add scanned folder"));
        auto* other = new QPushButton(QStringLiteral("+")); // not beside a folder table in its own page
        QWidget elsewhere;
        other->setParent(&elsewhere);
        other->setMaximumSize(16, 16);
        layout->addWidget(add);
        layout->addWidget(new MLFoldersEditor);
        page.show();
        elsewhere.show();
        QVERIFY(QTest::qWaitForWindowExposed(&page));
        QCOMPARE(add->text(), QStringLiteral("Add scanned folder"));
        QVERIFY(add->maximumWidth() > 100);
        QVERIFY(add->height() >= 24);
        QCOMPARE(other->text(), QStringLiteral("+"));
    }

    // The ring of a focused check box label only follows keyboard focus (as in
    // Fusion): a click must not leave one
    void focusRingOnlyAfterTab()
    {
        const QPalette p = redesign::toWidgetPalette(makeLookup(true));
        const QColor ring = redesign::widgetAccent(p);
        auto countRing = [&](const QImage& image) {
            int n = 0;
            for (int y = 0; y < image.height(); ++y)
                for (int x = 0; x < image.width(); ++x)
                    n += QColor(image.pixel(x, y)).rgb() == ring.rgb();
            return n;
        };
        QWidget page;
        page.setPalette(p);
        page.setAutoFillBackground(true);
        auto* layout = new QVBoxLayout(&page);
        auto* first = new QCheckBox(QStringLiteral("First"));
        auto* second = new QCheckBox(QStringLiteral("Second"));
        layout->addWidget(first);
        layout->addWidget(second);
        page.show();
        QVERIFY(QTest::qWaitForWindowExposed(&page));
        page.activateWindow();
        QVERIFY(QTest::qWaitForWindowActive(&page));
        // twice, so that the box is unchecked again (a checked box is filled with the ring colour)
        QTest::mouseClick(first, Qt::LeftButton);
        QTest::mouseClick(first, Qt::LeftButton);
        QVERIFY(first->hasFocus());
        QVERIFY(!first->isChecked());
        QCOMPARE(countRing(page.grab().toImage()), 0);
        QTest::keyClick(&page, Qt::Key_Tab);
        QVERIFY(second->hasFocus());
        QVERIFY(countRing(page.grab().toImage()) > 20);
    }

    // The default (accent) button's keyboard focus: a ring in the strong text
    // colour, then a gap of window colour, then the accent fill
    void defaultButtonFocusIsVisible_data()
    {
        QTest::addColumn<bool>("dark");
        QTest::newRow("dark") << true;
        QTest::newRow("light") << false;
    }

    void defaultButtonFocusIsVisible()
    {
        QFETCH(bool, dark);
        const QPalette p = redesign::toWidgetPalette(makeLookup(dark));
        QImage image(QSize(120, 44), QImage::Format_ARGB32_Premultiplied);
        image.fill(p.color(QPalette::Window));
        QPainter painter(&image);
        QStyleOptionButton opt;
        opt.palette = p;
        opt.rect = QRect(0, 0, 120, 44);
        opt.text = QStringLiteral("Next >");
        opt.features = QStyleOptionButton::DefaultButton;
        opt.state = QStyle::State_Enabled | QStyle::State_HasFocus | QStyle::State_KeyboardFocusChange;
        QApplication::style()->drawControl(QStyle::CE_PushButton, &opt, &painter, nullptr);
        painter.end();
        const int y = 22;
        const QColor ring = redesign::focusRingColor(p, true);
        const QColor fill = redesign::widgetAccent(p);
        QVERIFY(contrast(ring, fill) >= 4.5);
        // the body fills the rect; 2 px of fill, then the 2 px ring, then fill again
        QCOMPARE(QColor(image.pixel(1, y)).rgb(), fill.rgb());
        QCOMPARE(QColor(image.pixel(2, y)).rgb(), ring.rgb());
        QCOMPARE(QColor(image.pixel(3, y)).rgb(), ring.rgb());
        QCOMPARE(QColor(image.pixel(8, y)).rgb(), fill.rgb());
        // without keyboard focus there is no ring
        image.fill(p.color(QPalette::Window));
        QPainter again(&image);
        opt.state = QStyle::State_Enabled | QStyle::State_HasFocus;
        QApplication::style()->drawControl(QStyle::CE_PushButton, &opt, &again, nullptr);
        again.end();
        QCOMPARE(QColor(image.pixel(2, y)).rgb(), fill.rgb());
    }

    // A push button's drawn body fills its rect (no inset swallowing the hit
    // area), default or not
    void buttonBodyFillsItsRect()
    {
        const QPalette p = redesign::toWidgetPalette(makeLookup(true));
        for (bool isDefault : {false, true}) {
            QImage image(QSize(120, 44), QImage::Format_ARGB32_Premultiplied);
            image.fill(Qt::magenta);
            QPainter painter(&image);
            QStyleOptionButton opt;
            opt.palette = p;
            opt.rect = QRect(0, 0, 120, 44);
            opt.state = QStyle::State_Enabled;
            if (isDefault)
                opt.features = QStyleOptionButton::DefaultButton;
            QApplication::style()->drawControl(QStyle::CE_PushButtonBevel, &opt, &painter, nullptr);
            painter.end();
            // from the middle of the left edge down the middle column: the first and
            // last pixel that is not the magenta background
            int top = -1, bottom = -1;
            for (int y = 0; y < image.height(); ++y) {
                if (QColor(image.pixel(60, y)).rgb() != QColor(Qt::magenta).rgb()) {
                    if (top < 0)
                        top = y;
                    bottom = y;
                }
            }
            QVERIFY(top >= 0 && top <= 1);
            QVERIFY(bottom >= 42);
        }
    }

    // The outlines Fusion draws itself must come out of the Mid redirect visible
    void fusionOutlinesAreVisible_data()
    {
        QTest::addColumn<bool>("dark");
        QTest::newRow("dark") << true;
        QTest::newRow("light") << false;
    }

    void fusionOutlinesAreVisible()
    {
        QFETCH(bool, dark);
        const QPalette p = redesign::toWidgetPalette(makeLookup(dark));
        QWidget panel;
        panel.setPalette(p);
        panel.setAutoFillBackground(true);
        auto* layout = new QVBoxLayout(&panel);
        QList<QWidget*> controls;
        auto* group = new QGroupBox(QStringLiteral("Group"));
        (new QVBoxLayout(group))->addWidget(new QLabel(QStringLiteral("inside")));
        controls << new QLineEdit(QStringLiteral("text")) << new QComboBox << new QSpinBox << group;
        for (QWidget* w : controls)
            layout->addWidget(w);
        panel.show();
        QVERIFY(QTest::qWaitForWindowExposed(&panel));
        controls.first()->clearFocus(); // a focused line edit is outlined in the accent
        const QImage image = panel.grab().toImage();
        const qreal dpr = image.devicePixelRatio();
        for (QWidget* w : controls) {
            // the left edge of the control, on its middle row (a group box:
            // a little lower, below its title)
            const int y = int((w->geometry().center().y() + (qobject_cast<QGroupBox*>(w) ? 10 : 0)) * dpr);
            double best = 0;
            const int left = int(w->geometry().left() * dpr);
            for (int x = left; x < left + 8; ++x)
                best = qMax(best, contrast(QColor(image.pixel(x, y)), p.color(QPalette::Window)));
            QVERIFY2(best >= 2.9, qPrintable(QStringLiteral("%1: strongest outline pixel %2:1")
                                                .arg(QString::fromLatin1(w->metaObject()->className())).arg(best)));
        }
    }

    // Combo boxes (editable or not), line edits and spin boxes are drawn with the
    // same frame height
    void fieldFramesShareTheirHeight()
    {
        const QPalette p = redesign::toWidgetPalette(makeLookup(true));
        QWidget panel;
        panel.setPalette(p);
        panel.setAutoFillBackground(true);
        auto* layout = new QVBoxLayout(&panel);
        auto* edit = new QLineEdit(QStringLiteral("text"));
        auto* combo = new QComboBox;
        combo->addItems({QStringLiteral("Combo box"), QStringLiteral("Other")});
        auto* editable = new QComboBox;
        editable->setEditable(true);
        editable->addItems({QStringLiteral("Editable"), QStringLiteral("Other")});
        auto* spin = new QSpinBox;
        const QList<QWidget*> fields{edit, combo, editable, spin};
        for (QWidget* w : fields)
            layout->addWidget(w);
        panel.show();
        QVERIFY(QTest::qWaitForWindowExposed(&panel));
        edit->clearFocus();
        const QImage image = panel.grab().toImage();
        const qreal dpr = image.devicePixelRatio();
        auto frameHeight = [&](QWidget* w) {
            // rows at the widget's horizontal middle (the arrows are right of it) that
            // are outline coloured: first to last
            const int x = int((w->geometry().left() + w->geometry().width() / 3) * dpr);
            int top = -1, bottom = -1;
            const int y0 = int(w->geometry().top() * dpr) - 4, y1 = int(w->geometry().bottom() * dpr) + 4;
            for (int y = y0; y <= y1; ++y) {
                if (contrast(QColor(image.pixel(x, y)), p.color(QPalette::Window)) >= 2.5 && top < 0)
                    top = y;
                if (contrast(QColor(image.pixel(x, y)), p.color(QPalette::Window)) >= 2.5 && top >= 0 && y > top + 4)
                    bottom = y;
            }
            return (bottom - top + 1) / dpr;
        };
        const qreal reference = frameHeight(edit);
        QVERIFY(reference > 15);
        for (QWidget* w : fields) {
            QVERIFY2(qAbs(frameHeight(w) - reference) <= 1.0,
                     qPrintable(QStringLiteral("%1 frame %2 px, line edit %3 px")
                                    .arg(QString::fromLatin1(w->metaObject()->className()))
                                    .arg(frameHeight(w)).arg(reference)));
        }
    }

    // The style hides these by object name: the names must exist in the .ui
    void styleComboNamesExistInThePreferencesUi()
    {
        const QString path = QFileInfo(QStringLiteral(__FILE__)).dir().filePath(QStringLiteral("../dialogs/preferences/sprefs_interface.ui"));
        QFile ui(path);
        if (!ui.open(QIODevice::ReadOnly))
            QSKIP("the source tree is not reachable from this test binary");
        const QByteArray text = ui.readAll();
        QVERIFY2(text.contains("name=\"stylesCombo\""), "sprefs_interface.ui lost stylesCombo: redesign hides it by that name");
        QVERIFY2(text.contains("name=\"stylesLabel\""), "sprefs_interface.ui lost stylesLabel: redesign hides it by that name");
    }

    // qt-accent-color=system reads the system accent, not the redesign accent that
    // the application palette holds after the palette is applied
    void systemAccentIsNotReadBackFromTheRedesignPalette()
    {
#if QT_VERSION >= QT_VERSION_CHECK(6, 6, 0)
        const QColor system = redesign::systemAccent();
        redesign::applyWidgetPalette(makeLookup(true, redesign::accentSwatches()[5]));
        QCOMPARE(redesign::systemAccent(), system);
        QColor base, light;
        redesign::accentFromSetting("system", base, light);
        QCOMPARE(base, system);
        redesign::applyWidgetPalette(redesign::ColorLookup());
#else
        QSKIP("QPalette::Accent needs Qt 6.6");
#endif
    }

    // Advanced preferences must not offer another style: it would replace this one
    void styleChoiceIsHiddenInAdvancedPreferences()
    {
        QWidget page;
        auto* layout = new QHBoxLayout(&page);
        auto* label = new QLabel(QStringLiteral("Force window style:"));
        label->setObjectName(QStringLiteral("stylesLabel"));
        auto* combo = new QComboBox;
        combo->setObjectName(QStringLiteral("stylesCombo"));
        combo->addItems({QStringLiteral("Fusion"), QStringLiteral("Windows")});
        label->setBuddy(combo);
        layout->addWidget(label);
        layout->addWidget(combo);
        page.show();
        QVERIFY(QTest::qWaitForWindowExposed(&page));
        QVERIFY(!combo->isVisible());
        QVERIFY(!label->isVisible());
        // unpolish (a style change) shows them again
        QApplication::style()->unpolish(combo);
        QVERIFY(!combo->isHidden());
        QApplication::style()->polish(combo);
        QVERIFY(combo->isHidden());
    }

    void unpolishRestoresTheFolderTable()
    {
        QWidget page;
        auto* layout = new QVBoxLayout(&page);
        auto* add = new QPushButton(QStringLiteral("+"));
        add->setMaximumSize(16, 16);
        auto* table = new MLFoldersEditor;
        layout->addWidget(add);
        layout->addWidget(table);
        page.show();
        QVERIFY(QTest::qWaitForWindowExposed(&page));
        QVERIFY(table->verticalHeader()->isHidden());
        QApplication::style()->unpolish(table);
        QApplication::style()->unpolish(add);
        QVERIFY(!table->verticalHeader()->isHidden());
        QVERIFY(table->showGrid());
        QCOMPARE(add->text(), QStringLiteral("+"));
        QCOMPARE(add->maximumSize(), QSize(16, 16));
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
