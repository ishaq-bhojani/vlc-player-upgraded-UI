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
#include <QHeaderView>
#include <QLayout>
#include <QPainter>
#include <QPainterPath>
#include <QProxyStyle>
#include <QPushButton>
#include <QStyledItemDelegate>
#include <QStyleFactory>
#include <QStyleOption>
#include <QTableView>

#include <cstring>

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

QColor mixColors(const QColor& a, const QColor& b, qreal t)
{
    return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * t, a.greenF() + (b.greenF() - a.greenF()) * t,
                            a.blueF() + (b.blueF() - a.blueF()) * t);
}

QColor opaque(QColor c)
{
    c.setAlpha(255);
    return c;
}

QColor accentOf(const QPalette& p)
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 6, 0)
    return p.color(QPalette::Active, QPalette::Accent);
#else
    return p.color(QPalette::Active, QPalette::Highlight);
#endif
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

QColor ensureContrast(const QColor& from, const QColor& toward, const QVector<QColor>& against, double ratio)
{
    auto passes = [&](const QColor& c) {
        for (const QColor& other : against)
            if (contrastRatio(c, other) < ratio)
                return false;
        return true;
    };
    for (int step = 0; step <= 100; ++step) {
        const QColor c = mixColors(from, toward, step / 100.0);
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
        const QColor accent = p.color(QPalette::Active, QPalette::Highlight);
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
    const QColor accent = accentOf(p);
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
    const QColor accent = ensureContrast(highlight, strong, {window, base}, 3.0);

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
        palette.setColor(group, QPalette::Accent, accent);
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

namespace
{

// Sets the palette of a style option for the duration of one draw call. The
// options are const in the QStyle API but owned by the caller for the call, so
// patching and restoring the palette is safe (the GUI thread draws serially).
class PaletteScope
{
public:
    PaletteScope(const QStyleOption* option, const QPalette& palette)
        : m_option(const_cast<QStyleOption*>(option)), m_saved(option->palette)
    {
        m_option->palette = palette;
    }
    ~PaletteScope() { m_option->palette = m_saved; }
    PaletteScope(const PaletteScope&) = delete;
    PaletteScope& operator=(const PaletteScope&) = delete;

private:
    QStyleOption* m_option;
    QPalette m_saved;
};

bool isClass(const QObject* object, const char* name)
{
    return object && std::strcmp(object->metaObject()->className(), name) == 0;
}

// The folder table of the Media Library (first run wizard and Advanced
// preferences) and the buttons that sit in or next to it.
bool inFoldersEditor(const QWidget* w)
{
    for (const QWidget* a = w->parentWidget(); a; a = a->parentWidget())
        if (isClass(a, "MLFoldersEditor"))
            return true;
    return false;
}

bool besideFoldersEditor(const QWidget* w)
{
    const QWidget* parent = w->parentWidget();
    if (!parent)
        return false;
    for (const QObject* child : parent->children())
        if (isClass(child, "MLFoldersEditor"))
            return true;
    return false;
}

// Path column of the folder table: vertically centred like the buttons next
// to it, 8 px of left padding, the normal Text colour.
class FolderPathDelegate : public QStyledItemDelegate
{
public:
    using QStyledItemDelegate::QStyledItemDelegate;

    void paint(QPainter* painter, const QStyleOptionViewItem& option, const QModelIndex& index) const override
    {
        QStyleOptionViewItem opt(option);
        initStyleOption(&opt, index);
        opt.displayAlignment = Qt::AlignVCenter | Qt::AlignLeft;
        opt.rect.adjust(8, 0, 0, 0);
        for (auto group : {QPalette::Active, QPalette::Inactive})
            opt.palette.setColor(group, QPalette::Text, option.palette.color(group, QPalette::Text));
        const QWidget* widget = option.widget;
        QStyle* style = widget ? widget->style() : QApplication::style();
        style->drawControl(QStyle::CE_ItemViewItem, &opt, painter, widget);
    }
};

/**
 * Fusion with the controls that its palette handling leaves unreadable on the
 * redesign colours. Fusion draws every outline in window().darker(140), which
 * is nearly black on the dark window and cannot be set through the palette
 * (Mid, Dark and Shadow are not used for it), and it derives button fills and
 * the check mark from its own table. So the indicators and buttons are painted
 * here from the palette roles, and the outlines of the controls Fusion paints
 * itself are redirected by handing it a window colour that darkens to Mid.
 */
class RedesignWidgetStyle : public QProxyStyle
{
public:
    RedesignWidgetStyle() : QProxyStyle(QStringLiteral("Fusion")) {}

    void drawPrimitive(PrimitiveElement element, const QStyleOption* option, QPainter* painter,
                       const QWidget* widget) const override
    {
        switch (element) {
        case PE_IndicatorCheckBox:
        case PE_IndicatorRadioButton:
            drawIndicator(element == PE_IndicatorRadioButton, option, painter);
            return;
        case PE_PanelButtonCommand: {
            const auto* button = qstyleoption_cast<const QStyleOptionButton*>(option);
            drawButtonPanel(option, painter, button && (button->features & QStyleOptionButton::DefaultButton), false);
            return;
        }
        case PE_PanelButtonTool:
            drawButtonPanel(option, painter, false, option->state & State_AutoRaise);
            return;
        case PE_FrameFocusRect:
            drawFocusRing(option, painter, option->rect.adjusted(0, 0, -1, -1), 3);
            return;
        case PE_FrameLineEdit:
        case PE_PanelLineEdit:
        case PE_FrameGroupBox:
        case PE_Frame:
        case PE_FrameTabWidget: {
            PaletteScope scope(option, outlinePalette(option));
            QProxyStyle::drawPrimitive(element, option, painter, widget);
            return;
        }
        default:
            break;
        }
        QProxyStyle::drawPrimitive(element, option, painter, widget);
    }

    void drawControl(ControlElement element, const QStyleOption* option, QPainter* painter,
                     const QWidget* widget) const override
    {
        switch (element) {
        case CE_PushButtonLabel:
        case CE_ToolButtonLabel: {
            const auto* button = qstyleoption_cast<const QStyleOptionButton*>(option);
            const bool isDefault = button && (button->features & QStyleOptionButton::DefaultButton);
            const ButtonColors colors = buttonColors(option->palette, option->state, isDefault,
                                                     element == CE_ToolButtonLabel && (option->state & State_AutoRaise));
            QPalette p = option->palette;
            for (auto group : {QPalette::Active, QPalette::Inactive, QPalette::Disabled}) {
                p.setColor(group, QPalette::ButtonText, colors.text);
                p.setColor(group, QPalette::WindowText, colors.text);
            }
            PaletteScope scope(option, p);
            QProxyStyle::drawControl(element, option, painter, widget);
            return;
        }
        case CE_HeaderSection: {
            const auto* header = qstyleoption_cast<const QStyleOptionHeader*>(option);
            if (header && header->orientation == Qt::Horizontal) {
                // flat section with a line below, no heavy separators
                const QPalette::ColorGroup group = groupOf(option->state);
                QColor fill = option->palette.color(group, QPalette::Button);
                if (option->state & (State_MouseOver | State_Sunken))
                    fill = mixColors(fill, option->palette.color(QPalette::Active, QPalette::BrightText), 0.08);
                painter->fillRect(option->rect, fill);
                painter->fillRect(QRect(option->rect.left(), option->rect.bottom(), option->rect.width(), 1),
                                  option->palette.color(group, QPalette::Mid));
                return;
            }
            break;
        }
        case CE_HeaderLabel: {
            QPalette p = option->palette;
            for (auto group : {QPalette::Active, QPalette::Inactive, QPalette::Disabled})
                p.setColor(group, QPalette::ButtonText, option->palette.color(QPalette::Active, QPalette::BrightText));
            PaletteScope scope(option, p);
            QProxyStyle::drawControl(element, option, painter, widget);
            return;
        }
        default:
            break;
        }
        QProxyStyle::drawControl(element, option, painter, widget);
    }

    void drawComplexControl(ComplexControl control, const QStyleOptionComplex* option, QPainter* painter,
                            const QWidget* widget) const override
    {
        if (control == CC_ComboBox || control == CC_SpinBox || control == CC_GroupBox) {
            PaletteScope scope(option, outlinePalette(option));
            QProxyStyle::drawComplexControl(control, option, painter, widget);
            return;
        }
        QProxyStyle::drawComplexControl(control, option, painter, widget);
    }

    void polish(QWidget* widget) override
    {
        QProxyStyle::polish(widget);
        if (auto* table = qobject_cast<QTableView*>(widget); table && isClass(table, "MLFoldersEditor")) {
            // row numbers, grid lines and a cramped row height make the
            // folder list look like a spreadsheet
            table->verticalHeader()->hide();
            table->verticalHeader()->setDefaultSectionSize(36);
            table->setShowGrid(false);
            table->setAlternatingRowColors(true);
            table->horizontalHeader()->setHighlightSections(false);
            if (!dynamic_cast<FolderPathDelegate*>(table->itemDelegateForColumn(0)))
                table->setItemDelegateForColumn(0, new FolderPathDelegate(table));
        } else if (auto* button = qobject_cast<QPushButton*>(widget)) {
            const bool inside = inFoldersEditor(button);
            const bool beside = !inside && besideFoldersEditor(button);
            const QString text = button->text();
            if ((inside || beside) && (text == QLatin1String("-") || text == QStringLiteral("⟳"))) {
                button->setFixedSize(28, 28); // the stock 18 px is below a usable hit area
                if (inside && button->parentWidget()->layout()) {
                    // the cell layout passes Qt::AlignCenter as the stretch factor, so the
                    // button sits off centre inside the default margins
                    button->parentWidget()->layout()->setContentsMargins(0, 0, 0, 0);
                    button->parentWidget()->layout()->setAlignment(button, Qt::AlignCenter);
                }
                if (button->toolTip().isEmpty())
                    button->setToolTip(button->accessibleName());
            } else if (beside && text == QLatin1String("+")) {
                // a labelled button instead of a 16 px "+"
                const QString label = button->toolTip().isEmpty()
                                          ? QCoreApplication::translate("redesign", "Add folder\u2026")
                                          : button->toolTip();
                button->setText(label);
                button->setMinimumSize(0, 28);
                button->setMaximumSize(QWIDGETSIZE_MAX, QWIDGETSIZE_MAX);
            }
        }
    }

    using QProxyStyle::polish;

private:
    static QPalette outlinePalette(const QStyleOption* option)
    {
        // Fusion outline = window.darker(140); give it a window that darkens to Mid
        QPalette p = option->palette;
        const QColor mid = p.color(groupOf(option->state), QPalette::Mid);
        for (auto group : {QPalette::Active, QPalette::Inactive, QPalette::Disabled})
            p.setColor(group, QPalette::Window, mid.lighter(140));
        return p;
    }

    void drawFocusRing(const QStyleOption* option, QPainter* painter, const QRect& rect, qreal radius) const
    {
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        painter->setBrush(Qt::NoBrush);
        painter->setPen(QPen(accentOf(option->palette), 2));
        painter->drawRoundedRect(QRectF(rect).adjusted(1, 1, -1, -1), radius, radius);
        painter->restore();
    }

    void drawButtonPanel(const QStyleOption* option, QPainter* painter, bool isDefault, bool flat) const
    {
        const ButtonColors colors = buttonColors(option->palette, option->state, isDefault, flat);
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        // 2 px of room all round for the focus ring
        const QRectF body = QRectF(option->rect).adjusted(2, 2, -2, -2);
        const bool hasBorder = colors.border.alpha() > 0;
        painter->setBrush(colors.fill);
        painter->setPen(hasBorder ? QPen(colors.border, 1) : Qt::NoPen);
        painter->drawRoundedRect(hasBorder ? body.adjusted(0.5, 0.5, -0.5, -0.5) : body, 5, 5);
        painter->restore();
        if ((option->state & State_HasFocus) && (option->state & State_KeyboardFocusChange)
            && (option->state & State_Enabled))
            drawFocusRing(option, painter, option->rect, 7);
    }

    void drawIndicator(bool radio, const QStyleOption* option, QPainter* painter) const
    {
        const bool checked = option->state & (State_On | State_NoChange);
        const IndicatorColors colors = indicatorColors(option->palette, option->state, checked);
        const qreal side = qMin(option->rect.width(), option->rect.height());
        const QRectF box(option->rect.center().x() - side / 2.0 + 0.5, option->rect.center().y() - side / 2.0 + 0.5,
                         side - 1, side - 1);
        const qreal border = 1.5;
        const QRectF body = box.adjusted(border / 2, border / 2, -border / 2, -border / 2);

        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        painter->setBrush(colors.fill);
        painter->setPen(QPen(colors.border, border));
        if (radio)
            painter->drawEllipse(body);
        else
            painter->drawRoundedRect(body, 3, 3);

        painter->setBrush(Qt::NoBrush);
        if (checked && radio) {
            painter->setPen(Qt::NoPen);
            painter->setBrush(colors.mark);
            painter->drawEllipse(box.center(), side * 0.2, side * 0.2);
        } else if (checked && (option->state & State_NoChange)) {
            painter->setPen(QPen(colors.mark, 2, Qt::SolidLine, Qt::RoundCap));
            painter->drawLine(QPointF(box.left() + side * 0.28, box.center().y()),
                              QPointF(box.right() - side * 0.28, box.center().y()));
        } else if (checked) {
            QPainterPath tick;
            tick.moveTo(box.left() + side * 0.24, box.top() + side * 0.54);
            tick.lineTo(box.left() + side * 0.44, box.top() + side * 0.72);
            tick.lineTo(box.left() + side * 0.78, box.top() + side * 0.30);
            painter->setPen(QPen(colors.mark, 2, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
            painter->drawPath(tick);
        }
        painter->restore();
    }
};

} // anonymous namespace

bool installFusionStyle()
{
    originalPalette(); // before the style change can alter the palette
    if (!QStyleFactory::keys().contains(QStringLiteral("Fusion"), Qt::CaseInsensitive))
        return false;
    QApplication::setStyle(new RedesignWidgetStyle);
    return true;
}

} // namespace redesign
