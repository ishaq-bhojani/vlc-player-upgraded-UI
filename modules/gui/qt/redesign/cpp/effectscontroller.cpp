/*****************************************************************************
 * Copyright (C) 2026 Vireo contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Derived from Pylon (github.com/MeowKusTrue/Pylon): see effectscontroller.hpp.
 * Derived from VLC (dialogs/extended/extended_panels.cpp).
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
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

#include "effectscontroller.hpp"

#include <algorithm>
#include <cstdlib>

#include <QLocale>

#include <vlc_common.h>
#include <vlc_aout.h>
#include <vlc_configuration.h>
#include <vlc_player.h>
#include <vlc_variables.h>
#include <vlc_vout.h>

#include "../../../../audio_filter/equalizer_presets.h"

namespace {

constexpr int BAND_COUNT = EQZ_BANDS_MAX;
constexpr float BAND_MIN = -20.f;
constexpr float BAND_MAX = 20.f;
constexpr int SAVE_DELAY_MS = 500;

const char* const CUSTOM_PRESET = "custom";

constexpr const char* COMPRESSOR_KEYS[] = {
    "rms-peak", "attack", "release", "threshold", "ratio", "knee", "makeup-gain"
};
constexpr const char* SPATIALIZER_KEYS[] = { "roomsize", "width", "wet", "dry", "damp" };
constexpr const char* STEREOWIDEN_KEYS[] = { "delay", "feedback", "crossfeed", "dry-mix" };
constexpr const char* ADJUST_KEYS[] = { "contrast", "brightness", "hue", "saturation", "gamma" };

template <typename T, size_t N>
constexpr int count(T (&)[N]) { return int(N); }

QString configString(const char* name)
{
    if (!config_FindConfig(name))
        return {};
    char* psz = config_GetPsz(name);
    QString str = QString::fromUtf8(psz);
    free(psz);
    return str;
}

void putString(const char* name, const QString& value)
{
    if (config_FindConfig(name))
        config_PutPsz(name, value.toUtf8().constData());
}

float configFloat(const char* name, float fallback)
{
    return config_FindConfig(name) ? config_GetFloat(name) : fallback;
}

void putFloat(const char* name, float value)
{
    if (config_FindConfig(name))
        config_PutFloat(name, value);
}

QString formatBands(const QVariantList& bands)
{
    QStringList parts;
    for (const QVariant& band : bands)
        parts << QLocale::c().toString(double(band.toFloat()), 'f', 1);
    return parts.join(' ');
}

QVariantList parseBands(const QString& str)
{
    QVariantList bands;
    for (const QString& part : str.split(' ', Qt::SkipEmptyParts)) {
        bool ok = false;
        const double value = QLocale::c().toDouble(part, &ok);
        bands << (ok ? value : 0.0);
    }
    return bands;
}

int presetIndex(const QString& name)
{
    for (int i = 0; i < NB_PRESETS; ++i)
        if (name.compare(QLatin1String(preset_list[i]), Qt::CaseInsensitive) == 0)
            return i;
    return -1;
}

QVariantList presetBands(int index)
{
    QVariantList bands;
    for (int i = 0; i < BAND_COUNT; ++i)
        bands << double(index >= 0 && i < eqz_preset_10b[index].i_band ? eqz_preset_10b[index].f_amp[i] : 0.f);
    return bands;
}

/** A held output; the player is not locked (vlc_player_aout_Hold / vout_Hold do not need it). */
struct AoutRef
{
    explicit AoutRef(vlc_player_t* player)
        : aout(player ? vlc_player_aout_Hold(player) : nullptr) {}
    ~AoutRef() { if (aout) aout_Release(aout); }
    AoutRef(const AoutRef&) = delete;
    AoutRef& operator=(const AoutRef&) = delete;

    vlc_object_t* object() const { return aout ? VLC_OBJECT(aout) : nullptr; }
    audio_output_t* aout;
};

struct VoutRef
{
    explicit VoutRef(vlc_player_t* player)
        : vout(player ? vlc_player_vout_Hold(player) : nullptr) {}
    ~VoutRef() { if (vout) vout_Release(vout); }
    VoutRef(const VoutRef&) = delete;
    VoutRef& operator=(const VoutRef&) = delete;

    vlc_object_t* object() const { return vout ? VLC_OBJECT(vout) : nullptr; }
    vout_thread_t* vout;
};

bool hasVar(vlc_object_t* obj, const char* name, int varClass)
{
    return obj && (var_Type(obj, name) & VLC_VAR_CLASS) == varClass;
}

void liveFloat(vlc_object_t* obj, const char* name, float value)
{
    if (hasVar(obj, name, VLC_VAR_FLOAT))
        var_SetFloat(obj, name, value);
}

void liveString(vlc_object_t* obj, const char* name, const QString& value)
{
    if (hasVar(obj, name, VLC_VAR_STRING))
        var_SetString(obj, name, value.toUtf8().constData());
}

const char* chainName(bool audio) { return audio ? "audio-filter" : "video-filter"; }

} // namespace

EffectsController::EffectsController(vlc_player_t* player, vlc_object_t* obj, QObject* parent)
    : QObject(parent)
    , m_player(player)
    , m_obj(obj)
{
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(SAVE_DELAY_MS);
    connect(&m_saveTimer, &QTimer::timeout, this, [this] {
        if (m_obj)
            config_SaveConfigFile(m_obj);
    });
}

void EffectsController::scheduleSave()
{
    if (m_obj)
        m_saveTimer.start();
}

/* filter chains *************************************************************/

bool EffectsController::filterEnabled(Chain chain, const char* filter) const
{
    const QString list = configString(chainName(chain == Chain::Audio));
    return list.split(':', Qt::SkipEmptyParts).contains(QLatin1String(filter));
}

bool EffectsController::setFilterEnabled(Chain chain, const char* filter, bool enabled)
{
    const bool audio = chain == Chain::Audio;
    QStringList list = configString(chainName(audio)).split(':', Qt::SkipEmptyParts);
    const bool present = list.contains(QLatin1String(filter));
    if (present == enabled)
        return false;

    if (!enabled)
        list.removeAll(QLatin1String(filter));
    else if (audio && !strcmp(filter, "equalizer"))
        list.prepend(QLatin1String(filter)); // same order as aout_EnableFilter
    else
        list.append(QLatin1String(filter));
    const QString result = list.join(':');
    putString(chainName(audio), result);

    if (audio) {
        // the only call that rebuilds the audio filters
        if (m_player)
            vlc_player_aout_EnableFilter(m_player, filter, enabled);
    } else {
        VoutRef vout(m_player);
        liveString(vout.object(), "video-filter", result);
    }
    scheduleSave();
    return true;
}

/* equalizer *****************************************************************/

bool EffectsController::equalizerEnabled() const
{
    return filterEnabled(Chain::Audio, "equalizer");
}

void EffectsController::setEqualizerEnabled(bool enabled)
{
    if (setFilterEnabled(Chain::Audio, "equalizer", enabled))
        emit equalizerEnabledChanged();
}

QStringList EffectsController::equalizerPresets() const
{
    QStringList names;
    for (int i = 0; i < NB_PRESETS; ++i)
        names << QString::fromLatin1(preset_list[i]);
    return names;
}

QString EffectsController::equalizerPreset() const
{
    const QString name = configString("equalizer-preset");
    return name.isEmpty() ? QStringLiteral("flat") : name;
}

QString EffectsController::equalizerPresetLabel(const QString& name) const
{
    const int index = presetIndex(name);
    return index >= 0 ? QString::fromUtf8(vlc_gettext(preset_list_text[index])) : name;
}

void EffectsController::setPresetName(const QString& name)
{
    if (equalizerPreset() == name)
        return;
    putString("equalizer-preset", name);
    emit equalizerPresetChanged();
}

void EffectsController::setEqualizerPreset(const QString& name)
{
    if (name == QLatin1String(CUSTOM_PRESET)) {
        // not a preset of the filter: only remembered, the running filter keeps its bands
        setPresetName(name);
        scheduleSave();
    } else {
        applyEqualizerPreset(name);
    }
}

QVariantList EffectsController::equalizerBands() const
{
    QVariantList bands = parseBands(configString("equalizer-bands"));
    if (bands.isEmpty()) // never edited: the bands of the preset, as the filter loads them
        return presetBands(presetIndex(equalizerPreset()));
    while (bands.size() < BAND_COUNT)
        bands << 0.0;
    return bands.mid(0, BAND_COUNT);
}

double EffectsController::equalizerPreamp() const
{
    return configFloat("equalizer-preamp", 12.f);
}

void EffectsController::writeBands(const QVariantList& input)
{
    QVariantList bands;
    for (int i = 0; i < BAND_COUNT; ++i) {
        const float value = i < input.size() ? input.at(i).toFloat() : 0.f;
        bands << double(std::clamp(value, BAND_MIN, BAND_MAX));
    }
    const QString str = formatBands(bands);
    putString("equalizer-bands", str);

    AoutRef aout(m_player);
    liveString(aout.object(), "equalizer-bands", str);

    emit equalizerBandsChanged();
    scheduleSave();
}

void EffectsController::setEqualizerBands(const QVariantList& bands)
{
    writeBands(bands);
    setPresetName(QLatin1String(CUSTOM_PRESET));
}

void EffectsController::setEqualizerBand(int index, double db)
{
    if (index < 0 || index >= BAND_COUNT)
        return;
    QVariantList bands = equalizerBands();
    bands[index] = db;
    setEqualizerBands(bands);
}

void EffectsController::setEqualizerPreamp(double db)
{
    putFloat("equalizer-preamp", float(db));
    AoutRef aout(m_player);
    liveFloat(aout.object(), "equalizer-preamp", configFloat("equalizer-preamp", float(db)));
    emit equalizerPreampChanged();
    scheduleSave();
}

void EffectsController::applyEqualizerPreset(const QString& name)
{
    const int index = presetIndex(name);
    if (index < 0)
        return;

    const QString id = QString::fromLatin1(preset_list[index]);
    const QVariantList bands = presetBands(index);
    putString("equalizer-preset", id);
    putFloat("equalizer-preamp", eqz_preset_10b[index].f_preamp);

    {
        // the filter loads the table of the preset when this variable is set; the
        // rounded bands and the preamp are set right after, like the configuration
        AoutRef aout(m_player);
        liveString(aout.object(), "equalizer-preset", id);
        liveFloat(aout.object(), "equalizer-preamp", eqz_preset_10b[index].f_preamp);
    }
    writeBands(bands);

    emit equalizerPresetChanged();
    emit equalizerPreampChanged();
}

bool EffectsController::twoPass() const
{
    return config_FindConfig("equalizer-2pass") && config_GetInt("equalizer-2pass") != 0;
}

void EffectsController::setTwoPass(bool enabled)
{
    if (config_FindConfig("equalizer-2pass"))
        config_PutInt("equalizer-2pass", enabled);
    AoutRef aout(m_player);
    if (hasVar(aout.object(), "equalizer-2pass", VLC_VAR_BOOL))
        var_SetBool(aout.object(), "equalizer-2pass", enabled);
    emit twoPassChanged();
    scheduleSave();
}

/* float parameters of a filter *********************************************/

QVariantMap EffectsController::readFloats(const char* prefix, const char* const* keys, int n) const
{
    QVariantMap map;
    for (int i = 0; i < n; ++i) {
        const QByteArray name = QByteArray(prefix) + keys[i];
        if (config_FindConfig(name.constData()))
            map.insert(QLatin1String(keys[i]), double(config_GetFloat(name.constData())));
    }
    return map;
}

bool EffectsController::writeFloats(const char* prefix, const char* const* keys, int n,
                                    const QVariantMap& values, bool audio)
{
    AoutRef aout(audio ? m_player : nullptr);
    VoutRef vout(audio ? nullptr : m_player);
    vlc_object_t* live = audio ? aout.object() : vout.object();

    bool written = false;
    for (int i = 0; i < n; ++i) {
        const auto it = values.constFind(QLatin1String(keys[i]));
        if (it == values.constEnd())
            continue;
        const QByteArray name = QByteArray(prefix) + keys[i];
        if (!config_FindConfig(name.constData()))
            continue;
        config_PutFloat(name.constData(), it->toFloat());
        // the configuration clamps to the range of the option: set the output to what it holds
        liveFloat(live, name.constData(), config_GetFloat(name.constData()));
        written = true;
    }
    if (written)
        scheduleSave();
    return written;
}

/* compressor, spatializer, stereo widener ***********************************/

bool EffectsController::compressorEnabled() const { return filterEnabled(Chain::Audio, "compressor"); }

void EffectsController::setCompressorEnabled(bool enabled)
{
    if (setFilterEnabled(Chain::Audio, "compressor", enabled))
        emit compressorEnabledChanged();
}

QVariantMap EffectsController::compressor() const
{
    return readFloats("compressor-", COMPRESSOR_KEYS, count(COMPRESSOR_KEYS));
}

void EffectsController::setCompressor(const QVariantMap& values)
{
    if (writeFloats("compressor-", COMPRESSOR_KEYS, count(COMPRESSOR_KEYS), values, true))
        emit compressorChanged();
}

bool EffectsController::spatializerEnabled() const { return filterEnabled(Chain::Audio, "spatializer"); }

void EffectsController::setSpatializerEnabled(bool enabled)
{
    if (setFilterEnabled(Chain::Audio, "spatializer", enabled))
        emit spatializerEnabledChanged();
}

QVariantMap EffectsController::spatializer() const
{
    return readFloats("spatializer-", SPATIALIZER_KEYS, count(SPATIALIZER_KEYS));
}

void EffectsController::setSpatializer(const QVariantMap& values)
{
    if (writeFloats("spatializer-", SPATIALIZER_KEYS, count(SPATIALIZER_KEYS), values, true))
        emit spatializerChanged();
}

bool EffectsController::stereoWidenEnabled() const { return filterEnabled(Chain::Audio, "stereo_widen"); }

void EffectsController::setStereoWidenEnabled(bool enabled)
{
    if (setFilterEnabled(Chain::Audio, "stereo_widen", enabled))
        emit stereoWidenEnabledChanged();
}

QVariantMap EffectsController::stereoWiden() const
{
    return readFloats("stereowiden-", STEREOWIDEN_KEYS, count(STEREOWIDEN_KEYS));
}

void EffectsController::setStereoWiden(const QVariantMap& values)
{
    if (writeFloats("stereowiden-", STEREOWIDEN_KEYS, count(STEREOWIDEN_KEYS), values, true))
        emit stereoWidenChanged();
}

/* video *********************************************************************/

bool EffectsController::videoAdjustEnabled() const { return filterEnabled(Chain::Video, "adjust"); }

void EffectsController::setVideoAdjustEnabled(bool enabled)
{
    if (setFilterEnabled(Chain::Video, "adjust", enabled))
        emit videoAdjustEnabledChanged();
}

QVariantMap EffectsController::videoAdjust() const
{
    return readFloats("", ADJUST_KEYS, count(ADJUST_KEYS));
}

void EffectsController::setVideoAdjust(const QVariantMap& values)
{
    if (writeFloats("", ADJUST_KEYS, count(ADJUST_KEYS), values, false))
        emit videoAdjustChanged();
}

void EffectsController::setCrop(int top, int bottom, int left, int right)
{
    VoutRef vout(m_player);
    vlc_object_t* obj = vout.object();
    if (!obj)
        return;
    const struct { const char* name; int value; } edges[] = {
        { "crop-top", top }, { "crop-bottom", bottom }, { "crop-left", left }, { "crop-right", right },
    };
    for (const auto& edge : edges)
        if (hasVar(obj, edge.name, VLC_VAR_INTEGER))
            var_SetInteger(obj, edge.name, std::max(edge.value, 0));
}
