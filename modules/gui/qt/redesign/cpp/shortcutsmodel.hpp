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
#ifndef VLC_QT_REDESIGN_SHORTCUTSMODEL_HPP
#define VLC_QT_REDESIGN_SHORTCUTSMODEL_HPP

#include <vlc_common.h>
#include <vlc_configuration.h>

#include <QAbstractListModel>
#include <QHash>
#include <QString>
#include <QStringList>
#include <QVector>

/**
 * The keyboard shortcuts of VLC, one row per action, as the redesigned settings page
 * lists them. The actions are the configuration items of type CONFIG_ITEM_KEY of the core
 * module (the source of the KeySelectorControl of the preferences dialog): "key-play-pause",
 * and for most of them the global variant "global-key-play-pause".
 *
 * Hotkeys are the strings the configuration stores, in VLC key syntax ("Space", "Ctrl+q").
 * An action can hold several keys, separated by a tab ("Space\tMedia Play Pause"); an empty
 * string is "no hotkey". Hotkeys are compared as stored (case sensitive), each key of a value
 * on its own, and an empty hotkey never conflicts.
 *
 * An action declared without text (key-projection-toggle) is listed too, with its configuration
 * key as label.
 *
 * Reads go to the live configuration; assign() writes it and saves the configuration file.
 */
class ShortcutsModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles
    {
        //! the configuration key of the action, e.g. "key-play-pause"
        ActionKeyRole = Qt::UserRole + 1,
        //! translated psz_text of the action; the configuration key if the action has no text
        LabelRole,
        //! the keys of the action, VLC key syntax
        HotkeyRole,
        //! the keys of the global variant ("global-key-*"), "" if it has none or no keys
        GlobalHotkeyRole,
        //! the configuration key of the global variant, "" if the action has none
        GlobalKeyRole,
    };
    Q_ENUM(Roles)

    explicit ShortcutsModel(vlc_object_t* obj, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    /**
     * The label of the first action (other than actionKey) that already uses one of the keys of
     * hotkey in the scope (global or not), "" if none or if hotkey is empty.
     */
    Q_INVOKABLE QString conflictFor(const QString& actionKey, const QString& hotkey,
                                    bool global) const;

    /**
     * Gives the action the hotkey in the scope. Every key of hotkey is first taken away from
     * the other actions of the scope that use it (an action left without key has ""), then the
     * value of the action is replaced by hotkey (repeated keys stored once); "" removes the keys of the action. The
     * configuration is written and saved, dataChanged is emitted for every row that changed.
     * Does nothing (msg_Err) for an unknown action, or for global on an action without
     * global variant.
     */
    Q_INVOKABLE void assign(const QString& actionKey, const QString& hotkey, bool global);

    /**
     * Makes the views read the configuration again (modelReset). The model does not follow a
     * change made behind its back (the QWidgets preferences, another settings page): call this
     * when the page that shows it opens.
     */
    Q_INVOKABLE void reload();

private:
    struct Action
    {
        QString key;
        QString label;
        QString globalKey;
    };

    //! "Space\tMedia Play Pause" -> ["Space", "Media Play Pause"]
    static QStringList splitKeys(const QString& value);
    static QString configValue(const QString& key);
    //! the configuration key an action keeps its hotkey in for the scope, "" if there is none
    static QString scopeKey(const Action& action, bool global);

    vlc_object_t* m_obj;
    QVector<Action> m_actions;
};

#endif
