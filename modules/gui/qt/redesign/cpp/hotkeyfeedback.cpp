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
# include "config.h"
#endif

#include "hotkeyfeedback.hpp"

#include <QKeyEvent>

#include <vlc_actions.h>

#include "shortcutsmodel.hpp"
#include "../../util/vlchotkeyconverter.hpp"

HotkeyFeedback::HotkeyFeedback(vlc_object_t* obj, QObject* parent)
    : QObject(parent)
    , m_shortcuts(new ShortcutsModel(obj, this))
{
}

HotkeyFeedback::~HotkeyFeedback() = default;

QString HotkeyFeedback::describe(int qtKey, int qtModifiers) const
{
    // as MainCtx::sendHotkey builds it (no text): the same VLC key the hotkeys receive
    QKeyEvent event(QEvent::KeyPress, qtKey, Qt::KeyboardModifiers(qtModifiers));
    const int vlcKey = qtEventToVLCKey(&event);
    // a key without a VLC name is only its modifiers
    if ((unsigned(vlcKey) & ~unsigned(KEY_MODIFIER)) == 0)
        return QString();

    // the configuration stores the untranslated syntax ("Ctrl+Right"); the toast shows the
    // translated one
    const QString stored = VLCKeyToString(unsigned(vlcKey), false);
    if (stored.isEmpty())
        return QString();

    for (int row = 0; row < m_shortcuts->rowCount(); ++row)
    {
        const QModelIndex index = m_shortcuts->index(row);
        const QString actionKey = index.data(ShortcutsModel::ActionKeyRole).toString();
        // an action can hold several keys, tab separated ("Space\tMedia Play Pause")
        const QStringList keys = m_shortcuts->hotkeyFor(actionKey).split(QLatin1Char('\t'), Qt::SkipEmptyParts);
        if (!keys.contains(stored))
            continue;
        const QString label = index.data(ShortcutsModel::LabelRole).toString();
        //: the shortcut toast: the keys that were pressed, then the action they run
        return tr("%1 — %2").arg(VLCKeyToString(unsigned(vlcKey), true), label);
    }
    return QString();
}
