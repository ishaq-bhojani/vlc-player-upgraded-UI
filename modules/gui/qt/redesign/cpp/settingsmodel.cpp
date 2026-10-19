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

#include "settingsmodel.hpp"

#include <vlc_messages.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QVariantMap>

#include <cfloat>
#include <algorithm>
#include <cmath>
#include <cstdlib>

namespace
{

//! the keys marked `restart` in docs/redesign/settings-map.md (column notes): read only at
//! startup or when a module is created. Change both together.
const char* const restartKeys[] = {
    "qt-accent-color",
    "file-logging",
    "logfile",
    "log-verbose",
    "qt-system-tray",
    "qt-start-minimized",
    "embedded-video",
    "video-deco",
    "one-instance",
    "video",
    "vout",
    "audio",
    "aout",
    "media-library",
    "qt-compositor",
    "lua",
};

//! a float of the configuration as the number the user typed, not its float neighbour
//! (0.35f is 0.3499999940395355 as a double)
double floatToDouble(float value)
{
    return QString::number(value, 'g', 7).toDouble();
}

QVariantMap choice(const QVariant& value, const QString& label)
{
    return QVariantMap{{QStringLiteral("value"), value}, {QStringLiteral("label"), label}};
}

QString translated(const char* text)
{
    return text ? QString::fromUtf8(vlc_gettext(text)) : QString();
}

bool isIntegerClass(int type)
{
    return CONFIG_CLASS(type) == CONFIG_ITEM_INTEGER;
}

bool isStringClass(int type)
{
    return CONFIG_CLASS(type) == CONFIG_ITEM_STRING;
}

} // namespace

// SettingItem

SettingItem::SettingItem(vlc_object_t* obj, module_config_t* config, const QVariantList& labels,
                         bool requiresRestart, QObject* parent)
    : QObject(parent)
    , m_obj(obj)
    , m_config(config)
    , m_key(QString::fromUtf8(config->psz_name))
    , m_text(translated(config->psz_text))
    , m_longText(translated(config->psz_longtext))
    , m_requiresRestart(requiresRestart)
{
    switch (config->i_type)
    {
    case CONFIG_ITEM_BOOL:
        m_type = Bool;
        break;
    case CONFIG_ITEM_FLOAT:
        m_type = Float;
        break;
    case CONFIG_ITEM_KEY:
        m_type = Hotkey;
        break;
    case CONFIG_ITEM_LOADFILE:
    case CONFIG_ITEM_SAVEFILE:
    case CONFIG_ITEM_DIRECTORY:
        m_type = Path;
        break;
    default:
        m_type = isIntegerClass(config->i_type) ? Integer : String;
        break;
    }

    // enumerations: the item's own list or a module list (both are read without loading any
    // plugin and make the item a Choice), else the labels of choice-labels.json for an integer
    // that is an enumeration without a list. Any other integer or string option may have an
    // enumerator in its plugin: asking would load the plugin, so that is left to choices().
    const bool canEnumerate = m_type == Integer
        || (m_type == String && config->i_type != CONFIG_ITEM_PASSWORD
            && config->i_type != CONFIG_ITEM_FONT);
    if (canEnumerate && (config->list_count > 0 || config->i_type == CONFIG_ITEM_MODULE))
    {
        m_choices = readChoices();
        m_choicesResolved = true;
    }
    else if (canEnumerate && m_type == Integer && !labels.isEmpty())
    {
        m_choices = labels;
        m_choicesResolved = true;
    }
    else if (!canEnumerate)
    {
        m_choicesResolved = true;
    }
    if (!m_choices.isEmpty())
        m_type = Choice;

    // a range exists when the option declared one
    if (m_type == Integer)
    {
        if (config->min.i != INT64_MIN)
            m_min = qlonglong(config->min.i);
        if (config->max.i != INT64_MAX)
            m_max = qlonglong(config->max.i);
    }
    else if (m_type == Float)
    {
        if (config->min.f > -FLT_MAX)
            m_min = floatToDouble(config->min.f);
        if (config->max.f < FLT_MAX)
            m_max = floatToDouble(config->max.f);
    }
}

bool SettingItem::storesInteger() const
{
    return isIntegerClass(m_config->i_type) || m_config->i_type == CONFIG_ITEM_BOOL;
}

bool SettingItem::storesFloat() const
{
    return m_config->i_type == CONFIG_ITEM_FLOAT;
}

bool SettingItem::storesString() const
{
    return isStringClass(m_config->i_type);
}

QVariantList SettingItem::choices() const
{
    if (!m_choicesResolved)
    {
        // the plugin that declares the option may be loaded by this
        m_choices = readChoices();
        m_choicesResolved = true;
    }
    return m_choices;
}

QVariantList SettingItem::readChoices() const
{
    QVariantList list;
    const QByteArray name = m_key.toUtf8();

    if (storesInteger() && m_config->i_type != CONFIG_ITEM_BOOL)
    {
        int64_t* values = nullptr;
        char** texts = nullptr;
        const ssize_t count = config_GetIntChoices(name.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            list.append(choice(qlonglong(values[i]), QString::fromUtf8(texts[i])));
            free(texts[i]);
        }
        free(values);
        free(texts);
    }
    else if (storesString())
    {
        char** values = nullptr;
        char** texts = nullptr;
        const ssize_t count = config_GetPszChoices(name.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            list.append(choice(QString::fromUtf8(values[i]), QString::fromUtf8(texts[i])));
            free(values[i]);
            free(texts[i]);
        }
        free(values);
        free(texts);
    }
    return list;
}

QVariant SettingItem::value() const
{
    const QByteArray name = m_key.toUtf8();
    if (m_config->i_type == CONFIG_ITEM_BOOL)
        return config_GetInt(name.constData()) != 0;
    if (storesInteger())
        return qlonglong(config_GetInt(name.constData()));
    if (storesFloat())
        return floatToDouble(config_GetFloat(name.constData()));

    char* str = config_GetPsz(name.constData());
    const QString value = QString::fromUtf8(str);
    free(str);
    return value;
}

QVariant SettingItem::defaultValue() const
{
    if (m_config->i_type == CONFIG_ITEM_BOOL)
        return m_config->orig.i != 0;
    if (storesInteger())
        return qlonglong(m_config->orig.i);
    if (storesFloat())
        return floatToDouble(m_config->orig.f);
    return QString::fromUtf8(m_config->orig.psz ? m_config->orig.psz : "");
}

void SettingItem::setValue(const QVariant& newValue)
{
    const QByteArray name = m_key.toUtf8();
    const QVariant before = value();

    if (m_config->i_type == CONFIG_ITEM_BOOL)
    {
        config_PutInt(name.constData(), newValue.toBool() ? 1 : 0);
    }
    else if (storesInteger())
    {
        bool ok = false;
        const qlonglong integer = newValue.toLongLong(&ok);
        if (!ok)
        {
            msg_Err(m_obj, "settings: '%s' is not an integer value for %s",
                    qUtf8Printable(newValue.toString()), name.constData());
            return;
        }
        config_PutInt(name.constData(), integer);
    }
    else if (storesFloat())
    {
        bool ok = false;
        const double number = newValue.toDouble(&ok);
        if (!ok || !std::isfinite(number))
        {
            msg_Err(m_obj, "settings: '%s' is not a number for %s",
                    qUtf8Printable(newValue.toString()), name.constData());
            return;
        }
        // the configuration clamps to the range of the option, but the cast must be defined
        config_PutFloat(name.constData(), float(std::clamp(number, -double(FLT_MAX), double(FLT_MAX))));
    }
    else
    {
        config_PutPsz(name.constData(), newValue.toString().toUtf8().constData());
    }

    // the configuration clamps to the range of the option: compare what it holds now
    if (value() == before)
        return;

    if (config_SaveConfigFile(m_obj) != 0)
        msg_Warn(m_obj, "settings: could not save the configuration file after changing %s",
                 name.constData());
    emit valueChanged();
}

void SettingItem::reset()
{
    setValue(defaultValue());
}

// SettingsModel

SettingsModel::SettingsModel(vlc_object_t* obj, QObject* parent)
    : QObject(parent)
    , m_obj(obj)
{
    // {"key": [[value, "label"], ...]}
    QFile file(QStringLiteral(":/redesign/settings/choice-labels.json"));
    if (!file.open(QIODevice::ReadOnly))
    {
        msg_Err(m_obj, "settings: cannot read the choice labels");
        return;
    }
    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &error);
    if (!document.isObject())
    {
        msg_Err(m_obj, "settings: choice labels: %s", qUtf8Printable(error.errorString()));
        return;
    }
    const QJsonObject keys = document.object();
    for (auto it = keys.begin(); it != keys.end(); ++it)
    {
        QVariantList labels;
        for (const QJsonValue& entry : it.value().toArray())
        {
            const QJsonArray pair = entry.toArray();
            if (pair.size() == 2)
                labels.append(choice(qlonglong(pair.at(0).toInteger()), pair.at(1).toString()));
        }
        m_labels.insert(it.key(), labels);
    }
}

bool SettingsModel::keyRequiresRestart(const QString& key)
{
    for (const char* restartKey : restartKeys)
    {
        if (key == QLatin1String(restartKey))
            return true;
    }
    return false;
}

QVariantList SettingsModel::labelsFor(const QString& key) const
{
    return m_labels.value(key);
}

SettingItem* SettingsModel::item(const QString& key)
{
    const auto cached = m_items.constFind(key);
    if (cached != m_items.constEnd())
        return cached.value();

    const QByteArray name = key.toUtf8();
    module_config_t* config = key.isEmpty() ? nullptr : config_FindConfig(name.constData());
    if (!config)
    {
        msg_Err(m_obj, "settings: no configuration item named '%s'", name.constData());
        return nullptr;
    }

    auto* item = new SettingItem(m_obj, config, labelsFor(key), keyRequiresRestart(key), this);
    connect(item, &SettingItem::valueChanged, this, [this, item] {
        if (item->requiresRestart() && !m_restartPending)
        {
            m_restartPending = true;
            emit restartPendingChanged();
        }
    });
    m_items.insert(key, item);
    return item;
}

QStringList SettingsModel::keysInSubcategory(int subcategory) const
{
    QStringList keys;
    if (subcategory == SUBCAT_UNKNOWN || subcategory == SUBCAT_HIDDEN)
        return keys;

    size_t count = 0;
    module_t** modules = module_list_get(&count);
    if (!modules)
        return keys;

    // the core options first, then the plugins in the order of the module bank
    for (const bool core : {true, false})
    {
        for (size_t i = 0; i < count; ++i)
        {
            if (module_is_main(modules[i]) != core)
                continue;

            unsigned size = 0;
            module_config_t* items = module_config_get(modules[i], &size);
            int current = SUBCAT_UNKNOWN;
            for (unsigned j = 0; j < size; ++j)
            {
                const module_config_t& cfg = items[j];
                if (cfg.i_type == CONFIG_SUBCATEGORY)
                    current = int(cfg.value.i);
                else if (CONFIG_ITEM(cfg.i_type) && current == subcategory && cfg.psz_name)
                    keys.append(QString::fromUtf8(cfg.psz_name));
            }
            module_config_free(items);
        }
    }
    module_list_free(modules);
    return keys;
}
