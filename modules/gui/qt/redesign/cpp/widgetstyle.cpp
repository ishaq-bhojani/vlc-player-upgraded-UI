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

#include "widgetstyle.hpp"

#include "widgetpalette.hpp"

#include <QApplication>
#include <QAbstractItemModel>
#include <QComboBox>
#include <QHeaderView>
#include <QLabel>
#include <QLayout>
#include <QPainter>
#include <QPainterPath>
#include <QProxyStyle>
#include <QPushButton>
#include <QStyleFactory>
#include <QStyleOption>
#include <QStyledItemDelegate>
#include <QTableView>

#include <cmath>
#include <cstring>

namespace redesign
{

namespace
{

QPalette::ColorGroup groupOf(QStyle::State state)
{
    return (state & QStyle::State_Enabled) ? QPalette::Active : QPalette::Disabled;
}

// Sets the palette of a style option for the duration of one draw call. The
// options are const in the QStyle API but owned by the caller for the call
// (Qt always passes a local, non-const object), so patching and restoring the
// palette is safe: the GUI thread draws serially, and copying would need one
// clone per option type.
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

// What polish() changed on a widget, kept in dynamic properties so that
// unpolish() can put it back.
constexpr const char* polishedProperty = "vireoPolished";

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
            drawButtonPanel(option, painter, button && (button->features & QStyleOptionButton::DefaultButton), false,
                            panelRadius(widget));
            return;
        }
        case PE_PanelButtonTool:
            drawButtonPanel(option, painter, false, option->state & State_AutoRaise, panelRadius(widget));
            return;
        case PE_FrameFocusRect:
            // like Fusion: only after a key press, never after a mouse click; and
            // the current cell of an item view (State_Item) is Fusion's business
            if (!(option->state & State_KeyboardFocusChange))
                return;
            if (option->state & State_Item)
                break;
            drawFocusRing(painter, QRectF(option->rect).adjusted(0, 0, -1, -1), 3, widgetAccent(option->palette));
            return;
        case PE_FrameGroupBox: {
            // Fusion paints a translucent frame here, which no palette role reaches
            const qreal dpr = painter->device()->devicePixelRatio();
            const qreal line = std::max(1.0, std::round(dpr)) / dpr;
            painter->save();
            painter->setRenderHint(QPainter::Antialiasing);
            painter->setBrush(Qt::NoBrush);
            painter->setPen(QPen(option->palette.color(groupOf(option->state), QPalette::Mid), line));
            painter->drawRoundedRect(snap(QRectF(option->rect), dpr).adjusted(line / 2, line / 2, -line / 2, -line / 2),
                                     4, 4);
            painter->restore();
            return;
        }
        case PE_FrameLineEdit:
        case PE_PanelLineEdit:
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
            if (!(option->state & State_Enabled))
                break; // the disabled ButtonText stays
            QPalette p = option->palette;
            p.setColor(QPalette::ButtonText, option->palette.color(QPalette::Active, QPalette::BrightText));
            const auto* header = qstyleoption_cast<const QStyleOptionHeader*>(option);
            if (header && (header->textAlignment & Qt::AlignLeft) && widget && inFoldersEditor(widget)) {
                QStyleOptionHeader inset(*header); // a left aligned label gets the 8 px of the paths
                inset.rect.adjust(8, 0, 0, 0);
                inset.palette = p;
                QProxyStyle::drawControl(element, &inset, painter, widget);
                return;
            }
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
        if (widget->property(polishedProperty).toBool())
            return;

        if (auto* table = qobject_cast<QTableView*>(widget); table && isClass(table, "MLFoldersEditor")) {
            // row numbers, grid lines and a cramped row height make the
            // folder list look like a spreadsheet
            table->setProperty("vireoHeader", !table->verticalHeader()->isHidden());
            table->setProperty("vireoRowHeight", table->verticalHeader()->defaultSectionSize());
            table->setProperty("vireoGrid", table->showGrid());
            table->setProperty("vireoAlternating", table->alternatingRowColors());
            table->setProperty("vireoHighlight", table->horizontalHeader()->highlightSections());
            table->setProperty(polishedProperty, true);
            table->verticalHeader()->hide();
            table->verticalHeader()->setDefaultSectionSize(36);
            table->setShowGrid(false);
            table->setAlternatingRowColors(true);
            table->horizontalHeader()->setHighlightSections(false);
            table->setItemDelegateForColumn(0, new FolderPathDelegate(table));
            // the Path header lines up with the paths (CE_HeaderLabel adds the same
            // 8 px); Remove and Reload stay centred over their buttons
            if (QAbstractItemModel* model = table->model()) {
                table->setProperty("vireoHeaderAlign", model->headerData(0, Qt::Horizontal, Qt::TextAlignmentRole));
                model->setHeaderData(0, Qt::Horizontal, int(Qt::AlignVCenter | Qt::AlignLeft), Qt::TextAlignmentRole);
            }
        } else if (auto* button = qobject_cast<QPushButton*>(widget)) {
            polishFolderButton(button);
        } else if (auto* combo = qobject_cast<QComboBox*>(widget);
                   combo && combo->objectName() == QLatin1String("stylesCombo")) {
            // "Force window style" would replace this style (and, once
            // cancelled, restore the native one): the redesign has one style
            combo->setProperty(polishedProperty, true);
            combo->hide();
            if (QWidget* parent = combo->parentWidget())
                if (auto* label = parent->findChild<QLabel*>(QStringLiteral("stylesLabel")))
                    label->hide();
        }
    }

    void unpolish(QWidget* widget) override
    {
        if (widget->property(polishedProperty).toBool()) {
            if (auto* table = qobject_cast<QTableView*>(widget)) {
                table->verticalHeader()->setHidden(!table->property("vireoHeader").toBool());
                table->verticalHeader()->setDefaultSectionSize(table->property("vireoRowHeight").toInt());
                table->setShowGrid(table->property("vireoGrid").toBool());
                table->setAlternatingRowColors(table->property("vireoAlternating").toBool());
                table->horizontalHeader()->setHighlightSections(table->property("vireoHighlight").toBool());
                if (QAbstractItemModel* model = table->model())
                    model->setHeaderData(0, Qt::Horizontal, table->property("vireoHeaderAlign"), Qt::TextAlignmentRole);
                if (auto* delegate = dynamic_cast<FolderPathDelegate*>(table->itemDelegateForColumn(0))) {
                    table->setItemDelegateForColumn(0, nullptr);
                    delete delegate;
                }
            } else if (auto* button = qobject_cast<QPushButton*>(widget)) {
                if (button->property("vireoLayout").toBool() && button->parentWidget()->layout())
                    button->parentWidget()->layout()->setAlignment(button, Qt::Alignment());
                button->setText(button->property("vireoText").toString());
                button->setMinimumSize(button->property("vireoMin").toSize());
                button->setMaximumSize(button->property("vireoMax").toSize());
                if (QWidget* cell = button->parentWidget(); cell && cell->layout() && inFoldersEditor(button)) {
                    cell->layout()->setContentsMargins(button->property("vireoMargins").value<QMargins>());
                    cell->layout()->setAlignment(button, Qt::Alignment());
                }
            } else if (widget->objectName() == QLatin1String("stylesCombo")) {
                widget->show();
                if (QWidget* parent = widget->parentWidget())
                    if (auto* label = parent->findChild<QLabel*>(QStringLiteral("stylesLabel")))
                        label->show();
            }
            widget->setProperty(polishedProperty, false);
        }
        QProxyStyle::unpolish(widget);
    }

    using QProxyStyle::polish;
    using QProxyStyle::unpolish;

private:
    void polishFolderButton(QPushButton* button) const
    {
        const bool inside = inFoldersEditor(button);
        const bool beside = !inside && besideFoldersEditor(button);
        const QString text = button->text();
        const bool glyph = text == QLatin1String("-") || text == QStringLiteral("⟳");
        if (!(inside || beside) || !(glyph || (beside && text == QLatin1String("+"))))
            return;

        button->setProperty("vireoText", text);
        button->setProperty("vireoMin", button->minimumSize());
        button->setProperty("vireoMax", button->maximumSize());
        button->setProperty(polishedProperty, true);
        if (glyph) {
            button->setFixedSize(32, 32); // the stock 18 px is below a usable hit area
            if (button->toolTip().isEmpty())
                button->setToolTip(button->accessibleName());
            if (inside && button->parentWidget()->layout()) {
                // the cell layout passes Qt::AlignCenter as the stretch factor, so the
                // button sits off centre inside the default margins
                QLayout* layout = button->parentWidget()->layout();
                button->setProperty("vireoMargins", QVariant::fromValue(layout->contentsMargins()));
                layout->setContentsMargins(0, 0, 0, 0);
                layout->setAlignment(button, Qt::AlignCenter);
            }
        } else {
            // a labelled button instead of a 16 px "+"
            const QString label = button->toolTip().isEmpty()
                                      ? QCoreApplication::translate("redesign", "Add folder…")
                                      : button->toolTip();
            button->setText(label);
            // as wide as its label plus padding, 32 px high, at the right edge
            const QSize size(button->fontMetrics().horizontalAdvance(label) + 40, 32);
            button->setMinimumSize(size);
            button->setMaximumSize(size);
            if (QLayout* layout = button->parentWidget()->layout()) {
                button->setProperty("vireoLayout", true);
                layout->setAlignment(button, Qt::AlignRight | Qt::AlignVCenter);
            }
        }
    }

    static QPalette outlinePalette(const QStyleOption* option)
    {
        // Fusion outline = window.darker(140); give it a window that darkens to Mid
        QPalette p = option->palette;
        const QColor mid = p.color(groupOf(option->state), QPalette::Mid);
        for (auto group : {QPalette::Active, QPalette::Inactive, QPalette::Disabled})
            p.setColor(group, QPalette::Window, mid.lighter(140));
        return p;
    }

    // `v` rounded to a device pixel
    static qreal snap(qreal v, qreal dpr) { return std::round(v * dpr) / dpr; }

    static QRectF snap(const QRectF& r, qreal dpr)
    {
        return QRectF(QPointF(snap(r.left(), dpr), snap(r.top(), dpr)),
                      QPointF(snap(r.right(), dpr), snap(r.bottom(), dpr)));
    }

    static void drawFocusRing(QPainter* painter, const QRectF& rect, qreal radius, const QColor& color)
    {
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        painter->setBrush(Qt::NoBrush);
        painter->setPen(QPen(color, 2));
        painter->drawRoundedRect(rect.adjusted(1, 1, -1, -1), radius, radius);
        painter->restore();
    }

    // Fusion also paints a combo box as a button panel: it gets the radius of the
    // line edits and spin boxes next to it
    static qreal panelRadius(const QWidget* widget) { return qobject_cast<const QComboBox*>(widget) ? 2 : 5; }

    // The body fills the whole rect. The focus ring is drawn over it: on the border
    // (accent) of a normal button, and on the accent filled default button inside
    // the fill, 2 px in, in the text colour of the button (4.5:1 against the fill).
    void drawButtonPanel(const QStyleOption* option, QPainter* painter, bool isDefault, bool flat, qreal radius) const
    {
        const ButtonColors colors = buttonColors(option->palette, option->state, isDefault, flat);
        const qreal dpr = painter->device()->devicePixelRatio();
        const qreal line = std::max(1.0, std::round(dpr)) / dpr; // one device pixel
        const QRectF body = snap(QRectF(option->rect), dpr);
        const bool hasBorder = colors.border.alpha() > 0;
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        painter->setBrush(colors.fill);
        painter->setPen(hasBorder ? QPen(colors.border, line) : Qt::NoPen);
        painter->drawRoundedRect(hasBorder ? body.adjusted(line / 2, line / 2, -line / 2, -line / 2) : body, radius,
                                 radius);
        painter->restore();
        if ((option->state & State_HasFocus) && (option->state & State_KeyboardFocusChange)
            && (option->state & State_Enabled)) {
            if (isDefault)
                drawFocusRing(painter, body.adjusted(2, 2, -2, -2), radius, focusRingColor(option->palette, true));
            else
                drawFocusRing(painter, body, radius, focusRingColor(option->palette, false));
        }
    }

    void drawIndicator(bool radio, const QStyleOption* option, QPainter* painter) const
    {
        const bool checked = option->state & (State_On | State_NoChange);
        const IndicatorColors colors = indicatorColors(option->palette, option->state, checked);
        const qreal dpr = painter->device()->devicePixelRatio();
        const qreal side = snap(qMin(option->rect.width(), option->rect.height()) - 1, dpr);
        const QRectF box(snap(option->rect.center().x() + 0.5 - side / 2.0, dpr),
                         snap(option->rect.center().y() + 0.5 - side / 2.0, dpr), side, side);
        // border of 1.5 logical px, at least 2 device pixels, so that the stroke
        // lies on whole device pixels
        const qreal border = std::max(2.0, std::round(1.5 * dpr)) / dpr;
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

QStyle* createWidgetStyle()
{
    if (!QStyleFactory::keys().contains(QStringLiteral("Fusion"), Qt::CaseInsensitive))
        return nullptr;
    return new RedesignWidgetStyle;
}

} // namespace redesign
