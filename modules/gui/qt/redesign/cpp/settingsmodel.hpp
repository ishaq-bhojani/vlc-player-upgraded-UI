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
#ifndef VLC_QT_REDESIGN_SETTINGSMODEL_HPP
#define VLC_QT_REDESIGN_SETTINGSMODEL_HPP

#include <vlc_common.h>
#include <vlc_configuration.h>

#include <QHash>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariant>
#include <QVariantList>

class SettingsModel;

/**
 * One VLC configuration item (module_config_t), as the redesigned settings pages see it.
 * Reads go to the live configuration; a write goes to the configuration, is saved to the
 * configuration file, and notifies valueChanged.
 */
class SettingItem : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString key READ key CONSTANT)
    Q_PROPERTY(Type type READ type CONSTANT)
    //! for a Path: "directory", "loadfile" (a file to read) or "savefile" (a file to write), else ""
    Q_PROPERTY(QString pathKind READ pathKind CONSTANT)
    Q_PROPERTY(QVariant value READ value WRITE setValue NOTIFY valueChanged)
    Q_PROPERTY(QVariant defaultValue READ defaultValue CONSTANT)
    //! lower bound; invalid (undefined in QML) when the option declares no range
    Q_PROPERTY(QVariant min READ min CONSTANT)
    //! upper bound; invalid (undefined in QML) when the option declares no range
    Q_PROPERTY(QVariant max READ max CONSTANT)
    /**
     * [{value, label}] for a Choice, else empty. Options with a static list, module options and
     * labelled enumerations (choice-labels.json) are known from the start and decide `type`.
     * For any other integer or string option the first read asks the plugin that declares the
     * option for an enumerator (a device list...), which MAY LOAD THAT PLUGIN (a DLL load on
     * the calling thread). `type` does not change in that case: it stays Integer or String
     * while `choices` may be non-empty.
     */
    Q_PROPERTY(QVariantList choices READ choices CONSTANT)
    //! translated psz_text
    Q_PROPERTY(QString text READ text CONSTANT)
    //! translated psz_longtext
    Q_PROPERTY(QString longText READ longText CONSTANT)
    Q_PROPERTY(bool requiresRestart READ requiresRestart CONSTANT)

public:
    enum Type { Bool, Integer, Float, String, Choice, Path, Hotkey };
    Q_ENUM(Type)

    /**
     * \param config an item of the configuration (config_FindConfig), valid as long as the
     *               module bank is
     * \param labels [{value, label}] overriding the choices of an integer item, or empty
     */
    SettingItem(vlc_object_t* obj, module_config_t* config, const QVariantList& labels,
                bool requiresRestart, QObject* parent = nullptr);

    QString key() const { return m_key; }
    Type type() const { return m_type; }
    QString pathKind() const { return m_pathKind; }
    QVariant value() const;
    void setValue(const QVariant& value);
    QVariant defaultValue() const;
    QVariant min() const { return m_min; }
    QVariant max() const { return m_max; }
    QVariantList choices() const;
    QString text() const { return m_text; }
    QString longText() const { return m_longText; }
    bool requiresRestart() const { return m_requiresRestart; }

    //! value = defaultValue
    Q_INVOKABLE void reset();

signals:
    void valueChanged();

private:
    //! reads the choices of the item from the configuration (lists, module lists, enumerators)
    QVariantList readChoices() const;
    bool storesInteger() const;
    bool storesFloat() const;
    bool storesString() const;

    vlc_object_t* m_obj;
    module_config_t* m_config;
    QString m_key;
    QString m_text;
    QString m_longText;
    Type m_type = String;
    QString m_pathKind;
    QVariant m_min;
    QVariant m_max;
    mutable QVariantList m_choices;
    mutable bool m_choicesResolved = false;
    bool m_requiresRestart = false;
};

/**
 * The QML singleton RedesignSettings (module VLC.Redesign): gives access to the VLC
 * configuration items by key.
 */
class SettingsModel : public QObject
{
    Q_OBJECT

    //! true once an item that needs a restart was changed
    Q_PROPERTY(bool restartPending READ restartPending NOTIFY restartPendingChanged)

    /**
     * The 9 accent colors of Settings > Interface, as "#rrggbb" strings in Figma order (the first
     * is the default). A swatch is stored as the value of "qt-accent-color" unchanged.
     */
    Q_PROPERTY(QVariantList accentSwatches READ accentSwatches CONSTANT)

public:
    explicit SettingsModel(vlc_object_t* obj, QObject* parent = nullptr);

    /**
     * The item of a configuration key, the same object for every call. nullptr (and msg_Err)
     * if there is no such key, e.g. the plugin that declares it is not loaded.
     *
     * Keys must come from keysInSubcategory() or from docs/redesign/settings-map.md, never from
     * user input: config_FindConfig also finds obsolete options, which are accepted here.
     */
    Q_INVOKABLE SettingItem* item(const QString& key);

    /**
     * True if the configuration has an item with this key, i.e. item() would not be null. Unlike
     * item() it logs nothing and creates nothing: a page uses it to leave out the rows of the
     * options that its build does not have (a Windows-only option on Linux, a missing plugin).
     */
    Q_INVOKABLE bool hasItem(const QString& key) const;

    /**
     * Every non-obsolete, non-private key whose item sits under the VLC subcategory
     * (a vlc_config_subcat value), in declaration order: the core options first, then the
     * options of the plugins.
     */
    Q_INVOKABLE QStringList keysInSubcategory(int subcategory) const;

    bool restartPending() const { return m_restartPending; }

    QVariantList accentSwatches() const;

    //! keys marked `restart` in docs/redesign/settings-map.md
    static bool keyRequiresRestart(const QString& key);

signals:
    void restartPendingChanged();

private:
    //! choice-labels.json: key -> [{value, label}]
    QVariantList labelsFor(const QString& key) const;

    vlc_object_t* m_obj;
    QHash<QString, SettingItem*> m_items;
    QHash<QString, QVariantList> m_labels;
    bool m_restartPending = false;
};

#endif
