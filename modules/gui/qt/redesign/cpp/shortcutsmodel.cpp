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

#include "shortcutsmodel.hpp"

#include <vlc_messages.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>

#include <QSet>

#include <cstdlib>
#include <cstring>

namespace
{

const char globalPrefix[] = "global-";

bool isGlobalName(const char* name)
{
    return strncmp(name, globalPrefix, strlen(globalPrefix)) == 0;
}

QString translated(const char* text)
{
    // gettext("") returns the header of the catalog, not an empty string
    return (text && *text) ? QString::fromUtf8(vlc_gettext(text)) : QString();
}

} // namespace

ShortcutsModel::ShortcutsModel(vlc_object_t* obj, QObject* parent)
    : QAbstractListModel(parent)
    , m_obj(obj)
{
    // the same source as KeySelectorControl::finish(): the key items of the core module
    module_t* main = module_get_main();
    unsigned size = 0;
    module_config_t* items = module_config_get(main, &size);

    QSet<QString> globalKeys;
    for (unsigned i = 0; i < size; ++i)
    {
        const module_config_t& cfg = items[i];
        if (cfg.i_type == CONFIG_ITEM_KEY && cfg.psz_name && isGlobalName(cfg.psz_name))
            globalKeys.insert(QString::fromUtf8(cfg.psz_name));
    }

    for (unsigned i = 0; i < size; ++i)
    {
        const module_config_t& cfg = items[i];
        if (cfg.i_type != CONFIG_ITEM_KEY || !cfg.psz_name || isGlobalName(cfg.psz_name))
            continue;

        Action action;
        action.key = QString::fromUtf8(cfg.psz_name);
        action.label = translated(cfg.psz_text);
        // an action without a name (key-projection-toggle) can be neither shown nor named as
        // the owner of a conflict
        if (action.label.isEmpty())
            continue;
        const QString global = QString::fromLatin1(globalPrefix) + action.key;
        if (globalKeys.contains(global))
            action.globalKey = global;
        m_actions.append(action);
    }
    module_config_free(items);
}

int ShortcutsModel::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : m_actions.size();
}

QVariant ShortcutsModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.parent().isValid() || index.row() < 0
        || index.row() >= m_actions.size())
        return QVariant();

    const Action& action = m_actions.at(index.row());
    switch (role)
    {
    case ActionKeyRole:
        return action.key;
    case LabelRole:
    case Qt::DisplayRole:
        return action.label;
    case HotkeyRole:
        return configValue(action.key);
    case GlobalHotkeyRole:
        return action.globalKey.isEmpty() ? QString() : configValue(action.globalKey);
    case GlobalKeyRole:
        return action.globalKey;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> ShortcutsModel::roleNames() const
{
    return {
        {ActionKeyRole, "actionKey"},
        {LabelRole, "label"},
        {HotkeyRole, "hotkey"},
        {GlobalHotkeyRole, "globalHotkey"},
        {GlobalKeyRole, "globalKey"},
    };
}

QStringList ShortcutsModel::splitKeys(const QString& value)
{
    return value.split(QLatin1Char('\t'), Qt::SkipEmptyParts);
}

QString ShortcutsModel::configValue(const QString& key)
{
    char* value = config_GetPsz(key.toUtf8().constData());
    const QString text = QString::fromUtf8(value);
    free(value);
    return text;
}

QString ShortcutsModel::scopeKey(const Action& action, bool global)
{
    return global ? action.globalKey : action.key;
}

QString ShortcutsModel::conflictFor(const QString& actionKey, const QString& hotkey,
                                    bool global) const
{
    const QStringList wanted = splitKeys(hotkey);
    if (wanted.isEmpty())
        return QString();

    for (const Action& other : m_actions)
    {
        const QString key = scopeKey(other, global);
        if (other.key == actionKey || key.isEmpty())
            continue;
        const QStringList used = splitKeys(configValue(key));
        for (const QString& candidate : wanted)
        {
            if (used.contains(candidate))
                return other.label;
        }
    }
    return QString();
}

void ShortcutsModel::assign(const QString& actionKey, const QString& hotkey, bool global)
{
    int target = -1;
    for (int row = 0; row < m_actions.size(); ++row)
    {
        if (m_actions.at(row).key == actionKey)
        {
            target = row;
            break;
        }
    }
    if (target < 0)
    {
        msg_Err(m_obj, "shortcuts: no action named '%s'", qUtf8Printable(actionKey));
        return;
    }
    const QString targetKey = scopeKey(m_actions.at(target), global);
    if (targetKey.isEmpty())
    {
        msg_Err(m_obj, "shortcuts: %s has no global variant", qUtf8Printable(actionKey));
        return;
    }

    const QStringList wanted = splitKeys(hotkey);
    QVector<int> changedRows;

    // take the keys away from the other actions of the scope (only those keys)
    for (int row = 0; row < m_actions.size(); ++row)
    {
        const QString key = scopeKey(m_actions.at(row), global);
        if (row == target || key.isEmpty())
            continue;
        const QStringList used = splitKeys(configValue(key));
        QStringList kept;
        for (const QString& usedKey : used)
        {
            if (!wanted.contains(usedKey))
                kept.append(usedKey);
        }
        if (kept.size() == used.size())
            continue;
        config_PutPsz(key.toUtf8().constData(),
                      kept.join(QLatin1Char('\t')).toUtf8().constData());
        changedRows.append(row);
    }

    const QString value = wanted.join(QLatin1Char('\t'));
    if (configValue(targetKey) != value)
    {
        config_PutPsz(targetKey.toUtf8().constData(), value.toUtf8().constData());
        changedRows.append(target);
    }

    if (changedRows.isEmpty())
        return;

    // one save for the whole assignment: the file is never written with half of it
    if (config_SaveConfigFile(m_obj) != 0)
        msg_Warn(m_obj, "shortcuts: could not save the configuration file after assigning %s",
                 qUtf8Printable(actionKey));

    const int role = global ? GlobalHotkeyRole : HotkeyRole;
    for (const int row : changedRows)
    {
        const QModelIndex changed = index(row);
        emit dataChanged(changed, changed, {role});
    }
}
