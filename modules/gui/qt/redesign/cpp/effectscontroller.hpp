/*****************************************************************************
 * Copyright (C) 2026 VLC Reborn contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Derived from Pylon (github.com/MeowKusTrue/Pylon): the ideas of the live
 * apply rules (a slider move never rebuilds the filter chain, only enabling or
 * disabling a filter does), the filter order (equalizer first) and the
 * "custom" preset state after a manual band edit. Derived from VLC
 * (dialogs/extended/extended_panels.cpp): the aout/vout variable handling.
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
#ifndef VLC_QT_REDESIGN_EFFECTSCONTROLLER_HPP
#define VLC_QT_REDESIGN_EFFECTSCONTROLLER_HPP

#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

typedef struct vlc_object_t vlc_object_t;
typedef struct vlc_player_t vlc_player_t;

/**
 * Live audio and video effects (equalizer, compressor, spatializer, stereo
 * widener, video adjust, crop) for the redesigned UI. The QML singleton
 * `Effects` of VLC.Redesign.
 *
 * Every setter writes the value to the configuration (so it is used by the
 * next playback and saved to the profile) and, when the player has an audio
 * or video output, to the running output as well (so the change is heard or
 * seen at once). Without an output, only the configuration is written.
 *
 * Live apply rules (the ones of extended_panels.cpp, plus Pylon's):
 *  - enabling or disabling a filter is the only thing that touches the filter
 *    chain (aout_EnableFilter / the vout "video-filter" variable);
 *  - a parameter change (band, preamp, compressor, ...) only sets variables of
 *    the running output, it never rebuilds the chain.
 *
 * The maps (`compressor`, `spatializer`, `stereoWiden`, `videoAdjust`) are
 * keyed by the option name without the filter prefix, e.g. `compressor`:
 * `rms-peak`, `attack`, `release`, `threshold`, `ratio`, `knee`,
 * `makeup-gain`; `spatializer`: `roomsize`, `width`, `wet`, `dry`, `damp`;
 * `stereoWiden`: `delay`, `feedback`, `crossfeed`, `dry-mix`; `videoAdjust`:
 * `contrast`, `brightness`, `hue`, `saturation`, `gamma`. Reading gives all
 * keys; writing merges the given keys (unknown keys are ignored) and values
 * out of the range of the option are clamped by the configuration.
 */
class EffectsController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool equalizerEnabled READ equalizerEnabled WRITE setEqualizerEnabled NOTIFY equalizerEnabledChanged FINAL)
    //! ids of the presets of audio_filter/equalizer_presets.h, in order ("flat", "classical", ...)
    Q_PROPERTY(QStringList equalizerPresets READ equalizerPresets CONSTANT FINAL)
    //! one of equalizerPresets, or "custom" once a band was edited by hand
    Q_PROPERTY(QString equalizerPreset READ equalizerPreset WRITE setEqualizerPreset NOTIFY equalizerPresetChanged FINAL)
    //! 10 values in dB
    Q_PROPERTY(QVariantList equalizerBands READ equalizerBands WRITE setEqualizerBands NOTIFY equalizerBandsChanged FINAL)
    Q_PROPERTY(double equalizerPreamp READ equalizerPreamp WRITE setEqualizerPreamp NOTIFY equalizerPreampChanged FINAL)
    Q_PROPERTY(bool twoPass READ twoPass WRITE setTwoPass NOTIFY twoPassChanged FINAL)

    Q_PROPERTY(bool compressorEnabled READ compressorEnabled WRITE setCompressorEnabled NOTIFY compressorEnabledChanged FINAL)
    Q_PROPERTY(QVariantMap compressor READ compressor WRITE setCompressor NOTIFY compressorChanged FINAL)
    Q_PROPERTY(bool spatializerEnabled READ spatializerEnabled WRITE setSpatializerEnabled NOTIFY spatializerEnabledChanged FINAL)
    Q_PROPERTY(QVariantMap spatializer READ spatializer WRITE setSpatializer NOTIFY spatializerChanged FINAL)
    Q_PROPERTY(bool stereoWidenEnabled READ stereoWidenEnabled WRITE setStereoWidenEnabled NOTIFY stereoWidenEnabledChanged FINAL)
    Q_PROPERTY(QVariantMap stereoWiden READ stereoWiden WRITE setStereoWiden NOTIFY stereoWidenChanged FINAL)

    Q_PROPERTY(bool videoAdjustEnabled READ videoAdjustEnabled WRITE setVideoAdjustEnabled NOTIFY videoAdjustEnabledChanged FINAL)
    Q_PROPERTY(QVariantMap videoAdjust READ videoAdjust WRITE setVideoAdjust NOTIFY videoAdjustChanged FINAL)

public:
    /**
     * @param player  the player whose outputs are changed live; null: configuration only
     * @param obj     any object of the libvlc instance, used to save the configuration
     *                file (a moment after the last change); null: never saved from here
     */
    explicit EffectsController(vlc_player_t* player = nullptr, vlc_object_t* obj = nullptr,
                               QObject* parent = nullptr);

    bool equalizerEnabled() const;
    void setEqualizerEnabled(bool enabled);
    QStringList equalizerPresets() const;
    QString equalizerPreset() const;
    void setEqualizerPreset(const QString& name);
    QVariantList equalizerBands() const;
    void setEqualizerBands(const QVariantList& bands);
    double equalizerPreamp() const;
    void setEqualizerPreamp(double db);
    bool twoPass() const;
    void setTwoPass(bool enabled);

    bool compressorEnabled() const;
    void setCompressorEnabled(bool enabled);
    QVariantMap compressor() const;
    void setCompressor(const QVariantMap& values);
    bool spatializerEnabled() const;
    void setSpatializerEnabled(bool enabled);
    QVariantMap spatializer() const;
    void setSpatializer(const QVariantMap& values);
    bool stereoWidenEnabled() const;
    void setStereoWidenEnabled(bool enabled);
    QVariantMap stereoWiden() const;
    void setStereoWiden(const QVariantMap& values);

    bool videoAdjustEnabled() const;
    void setVideoAdjustEnabled(bool enabled);
    QVariantMap videoAdjust() const;
    void setVideoAdjust(const QVariantMap& values);

    /** Crops the picture of the main video output, in pixels (no-op without a video output). */
    Q_INVOKABLE void setCrop(int top, int bottom, int left, int right);

    /** Sets the bands and the preamp from the preset table; unknown names are ignored. */
    Q_INVOKABLE void applyEqualizerPreset(const QString& name);

    /** Sets one band (0..9, dB) without touching the others; the preset becomes "custom". */
    Q_INVOKABLE void setEqualizerBand(int index, double db);

    /** Translated display name of a preset id; the id itself when unknown. */
    Q_INVOKABLE QString equalizerPresetLabel(const QString& name) const;

signals:
    void equalizerEnabledChanged();
    void equalizerPresetChanged();
    void equalizerBandsChanged();
    void equalizerPreampChanged();
    void twoPassChanged();
    void compressorEnabledChanged();
    void compressorChanged();
    void spatializerEnabledChanged();
    void spatializerChanged();
    void stereoWidenEnabledChanged();
    void stereoWidenChanged();
    void videoAdjustEnabledChanged();
    void videoAdjustChanged();

private:
    enum class Chain { Audio, Video };

    bool filterEnabled(Chain chain, const char* filter) const;
    //! true when the chain (configuration) changed
    bool setFilterEnabled(Chain chain, const char* filter, bool enabled);

    QVariantMap readFloats(const char* prefix, const char* const* keys, int count) const;
    //! true when a value was written
    bool writeFloats(const char* prefix, const char* const* keys, int count,
                     const QVariantMap& values, bool audio);

    void writeBands(const QVariantList& bands);
    void setPresetName(const QString& name);
    void scheduleSave();

    vlc_player_t* m_player;
    vlc_object_t* m_obj;
    QTimer m_saveTimer;
};

#endif
