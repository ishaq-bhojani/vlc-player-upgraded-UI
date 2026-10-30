/*****************************************************************************
 * Copyright (C) 2026 Vireo contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
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
# include <config.h>
#endif

#include <cstdio>
#include <cstdlib>
#include <memory>

#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include <vlc/vlc.h>
#include <vlc_common.h>
#include <vlc_configuration.h>

#include "../../../../lib/libvlc_internal.h"
#include "../../../audio_filter/equalizer_presets.h"

#include "../redesign/cpp/effectscontroller.hpp"

namespace {

QString cfgString(const char* name)
{
    char* psz = config_GetPsz(name);
    const QString str = QString::fromUtf8(psz);
    free(psz);
    return str;
}

/** The bands of a preset the way the controller writes them: "%.1f" joined by spaces. */
QString presetBandString(int index)
{
    QStringList parts;
    for (int i = 0; i < eqz_preset_10b[index].i_band; ++i) {
        char buf[32];
        snprintf(buf, sizeof(buf), "%.1f", double(eqz_preset_10b[index].f_amp[i]));
        parts << QString::fromLatin1(buf);
    }
    return parts.join(' ');
}

int presetIndexOf(const char* name)
{
    for (int i = 0; i < NB_PRESETS; ++i)
        if (!strcmp(preset_list[i], name))
            return i;
    return -1;
}

} // namespace

class TestEffectsController : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        setenv("VLC_PLUGIN_PATH", TOP_BUILDDIR"/modules", 0);
        setenv("VLC_LIB_PATH", TOP_BUILDDIR"/modules", 0);

        // a throwaway profile: the configuration of the user is neither read nor written
        QVERIFY(m_dir.isValid());
        m_configPath = m_dir.filePath("vlcrc");
        const QByteArray configArg = "--config=" + m_configPath.toUtf8();
        const char* argv[] = {"--ignore-config", configArg.constData(), "--no-media-library"};
        m_vlc = libvlc_new(3, argv);
        QVERIFY(m_vlc);
    }

    void cleanupTestCase()
    {
        if (m_vlc)
            libvlc_release(m_vlc);
        m_vlc = nullptr;
    }

    void init()
    {
        // every case starts from the defaults the filters declare
        config_PutPsz("audio-filter", "");
        config_PutPsz("video-filter", "");
        config_PutPsz("equalizer-preset", "flat");
        config_PutPsz("equalizer-bands", "");
        config_PutFloat("equalizer-preamp", 12.f);
        config_PutInt("equalizer-2pass", 0);
        config_PutFloat("brightness", 1.f);
        config_PutFloat("contrast", 1.f);
        config_PutFloat("compressor-ratio", 4.f);
        config_PutFloat("compressor-attack", 25.f);
    }

    void presetsListed()
    {
        EffectsController fx;
        const QStringList presets = fx.equalizerPresets();
        QVERIFY(presets.contains("flat"));
        QVERIFY(presets.contains("rock"));
        QCOMPARE(presets.size(), int(NB_PRESETS));
        for (int i = 0; i < NB_PRESETS; ++i)
            QCOMPARE(presets.at(i), QString::fromLatin1(preset_list[i]));
        QCOMPARE(fx.equalizerPresetLabel("rock"), QString("Rock"));
        QCOMPARE(fx.equalizerPresetLabel("nonsense"), QString("nonsense"));
    }

    void defaultsReflectTheConfiguration()
    {
        EffectsController fx;
        QCOMPARE(fx.equalizerPreset(), QString("flat"));
        QCOMPARE(fx.equalizerBands().size(), 10);
        QCOMPARE(fx.equalizerBands().at(3).toDouble(), 0.0);
        QCOMPARE(fx.equalizerPreamp(), 12.0);
        QVERIFY(!fx.equalizerEnabled());
        QVERIFY(!fx.twoPass());
        QCOMPARE(fx.compressor().size(), 7);
        QCOMPARE(fx.spatializer().size(), 5);
        QCOMPARE(fx.stereoWiden().size(), 4);
        QCOMPARE(fx.videoAdjust().size(), 5);
    }

    void applyPresetWritesConfig()
    {
        EffectsController fx;
        QSignalSpy presetSpy(&fx, &EffectsController::equalizerPresetChanged);
        QSignalSpy bandsSpy(&fx, &EffectsController::equalizerBandsChanged);
        QSignalSpy preampSpy(&fx, &EffectsController::equalizerPreampChanged);

        fx.applyEqualizerPreset("rock");

        const int rock = presetIndexOf("rock");
        QVERIFY(rock >= 0);
        QCOMPARE(cfgString("equalizer-preset"), QString("rock"));
        QCOMPARE(cfgString("equalizer-bands"), presetBandString(rock));
        QCOMPARE(config_GetFloat("equalizer-preamp"), eqz_preset_10b[rock].f_preamp);

        QCOMPARE(fx.equalizerPreset(), QString("rock"));
        QCOMPARE(fx.equalizerBands().at(0).toDouble(), 8.0);
        QCOMPARE(fx.equalizerBands().at(2).toDouble(), -5.6);
        QCOMPARE(fx.equalizerPreamp(), double(eqz_preset_10b[rock].f_preamp));
        QCOMPARE(presetSpy.count(), 1);
        QCOMPARE(bandsSpy.count(), 1);
        QCOMPARE(preampSpy.count(), 1);
    }

    void unknownPresetIsIgnored()
    {
        EffectsController fx;
        fx.applyEqualizerPreset("rock");
        fx.applyEqualizerPreset("no-such-preset");
        QCOMPARE(cfgString("equalizer-preset"), QString("rock"));
    }

    void bandEditMakesThePresetCustom()
    {
        EffectsController fx;
        fx.applyEqualizerPreset("rock");
        fx.setEqualizerBand(4, 3.5);

        QCOMPARE(fx.equalizerPreset(), QString("custom"));
        QCOMPARE(cfgString("equalizer-preset"), QString("custom"));
        QCOMPARE(fx.equalizerBands().at(4).toDouble(), 3.5);
        // the other bands are the ones of the preset
        QCOMPARE(fx.equalizerBands().at(0).toDouble(), 8.0);
        QCOMPARE(fx.equalizerBands().at(9).toDouble(), 11.2);

        // out of range is clamped to the +-20 dB of the sliders
        fx.setEqualizerBand(0, 99.0);
        QCOMPARE(fx.equalizerBands().at(0).toDouble(), 20.0);
        // not a band
        fx.setEqualizerBand(10, 1.0);
        QCOMPARE(fx.equalizerBands().size(), 10);

        // choosing a real preset again leaves custom
        fx.setEqualizerPreset("pop");
        QCOMPARE(fx.equalizerPreset(), QString("pop"));
    }

    void enableEqualizerAddsFilter()
    {
        config_PutPsz("audio-filter", "normvol");
        EffectsController fx;
        QSignalSpy spy(&fx, &EffectsController::equalizerEnabledChanged);

        fx.setEqualizerEnabled(true);
        QVERIFY(fx.equalizerEnabled());
        QVERIFY(cfgString("audio-filter").split(':').contains("equalizer"));
        QVERIFY(cfgString("audio-filter").split(':').contains("normvol"));
        // the equalizer goes first, like aout_EnableFilter orders it
        QCOMPARE(cfgString("audio-filter"), QString("equalizer:normvol"));
        QCOMPARE(spy.count(), 1);

        fx.setEqualizerEnabled(true); // already on: nothing changes
        QCOMPARE(spy.count(), 1);

        fx.setEqualizerEnabled(false);
        QVERIFY(!fx.equalizerEnabled());
        QCOMPARE(cfgString("audio-filter"), QString("normvol"));
        QCOMPARE(spy.count(), 2);
    }

    void otherAudioFiltersToggleIndependently()
    {
        EffectsController fx;
        fx.setCompressorEnabled(true);
        fx.setSpatializerEnabled(true);
        fx.setStereoWidenEnabled(true);
        fx.setEqualizerEnabled(true);
        QCOMPARE(cfgString("audio-filter"), QString("equalizer:compressor:spatializer:stereo_widen"));
        QVERIFY(fx.compressorEnabled());
        QVERIFY(fx.spatializerEnabled());
        QVERIFY(fx.stereoWidenEnabled());

        fx.setSpatializerEnabled(false);
        QCOMPARE(cfgString("audio-filter"), QString("equalizer:compressor:stereo_widen"));
        QVERIFY(!fx.spatializerEnabled());
        QVERIFY(fx.compressorEnabled());
    }

    void bandChangesNeverTouchTheFilterChain()
    {
        // a slider drag only sets variables; only enabling/disabling edits the chain
        config_PutPsz("audio-filter", "normvol:equalizer");
        EffectsController fx;
        fx.setEqualizerBand(2, 4.0);
        fx.setEqualizerPreamp(3.0);
        fx.applyEqualizerPreset("club");
        fx.setTwoPass(true);
        fx.setCompressor({{"ratio", 8.0}});
        QCOMPARE(cfgString("audio-filter"), QString("normvol:equalizer"));
    }

    void preampAndTwoPass()
    {
        EffectsController fx;
        QSignalSpy preampSpy(&fx, &EffectsController::equalizerPreampChanged);
        QSignalSpy twoPassSpy(&fx, &EffectsController::twoPassChanged);
        fx.setEqualizerPreamp(-4.5);
        QCOMPARE(config_GetFloat("equalizer-preamp"), -4.5f);
        QCOMPARE(fx.equalizerPreamp(), -4.5);
        fx.setTwoPass(true);
        QCOMPARE(config_GetInt("equalizer-2pass"), int64_t(1));
        QVERIFY(fx.twoPass());
        QCOMPARE(preampSpy.count(), 1);
        QCOMPARE(twoPassSpy.count(), 1);
    }

    void compressorMapMergesKeys()
    {
        EffectsController fx;
        QSignalSpy spy(&fx, &EffectsController::compressorChanged);
        fx.setCompressor({{"ratio", 8.0}, {"unknown-key", 1.0}});
        QCOMPARE(config_GetFloat("compressor-ratio"), 8.f);
        QCOMPARE(config_GetFloat("compressor-attack"), 25.f); // untouched
        QCOMPARE(fx.compressor().value("ratio").toDouble(), 8.0);
        QCOMPARE(fx.compressor().value("attack").toDouble(), 25.0);
        QCOMPARE(spy.count(), 1);

        fx.setCompressor({{"unknown-key", 1.0}}); // nothing written
        QCOMPARE(spy.count(), 1);

        // the range of the option applies (ratio is 1..20)
        fx.setCompressor({{"ratio", 500.0}});
        QCOMPARE(fx.compressor().value("ratio").toDouble(), 20.0);
    }

    void spatializerAndStereoWidenWriteTheirOptions()
    {
        EffectsController fx;
        fx.setSpatializer({{"roomsize", 0.5}, {"damp", 0.25}});
        QCOMPARE(config_GetFloat("spatializer-roomsize"), 0.5f);
        QCOMPARE(config_GetFloat("spatializer-damp"), 0.25f);
        fx.setStereoWiden({{"dry-mix", 0.5}, {"delay", 40.0}});
        QCOMPARE(config_GetFloat("stereowiden-dry-mix"), 0.5f);
        QCOMPARE(config_GetFloat("stereowiden-delay"), 40.f);
        QCOMPARE(fx.stereoWiden().value("dry-mix").toDouble(), 0.5);
    }

    void videoAdjustWritesConfig()
    {
        EffectsController fx;
        QSignalSpy spy(&fx, &EffectsController::videoAdjustChanged);
        fx.setVideoAdjust({{"brightness", 1.2}});
        QCOMPARE(config_GetFloat("brightness"), 1.2f);
        QCOMPARE(config_GetFloat("contrast"), 1.f);
        QCOMPARE(spy.count(), 1);

        fx.setVideoAdjustEnabled(true);
        QVERIFY(fx.videoAdjustEnabled());
        QCOMPARE(cfgString("video-filter"), QString("adjust"));
        fx.setVideoAdjustEnabled(false);
        QCOMPARE(cfgString("video-filter"), QString());
    }

    void propertiesWorkFromTheMetaObject()
    {
        // what QML does: assignments through properties
        EffectsController fx;
        QVERIFY(fx.setProperty("videoAdjust", QVariantMap{{"brightness", 1.5}}));
        QCOMPARE(config_GetFloat("brightness"), 1.5f);
        QVERIFY(fx.setProperty("equalizerPreset", "techno"));
        QCOMPARE(cfgString("equalizer-preset"), QString("techno"));
        QVERIFY(fx.setProperty("equalizerEnabled", true));
        QVERIFY(fx.property("equalizerEnabled").toBool());
    }

    void withoutOutputsNothingCrashes()
    {
        EffectsController fx; // no player at all
        fx.setCrop(1, 2, 3, 4);
        fx.setEqualizerBands(QVariantList() << 1.0 << 2.0);
        QCOMPARE(fx.equalizerBands().size(), 10);
        QCOMPARE(fx.equalizerBands().at(1).toDouble(), 2.0);
        QCOMPARE(fx.equalizerBands().at(5).toDouble(), 0.0);
    }

    void configurationIsSavedToTheProfileAMomentLater()
    {
        EffectsController fx(nullptr, VLC_OBJECT(m_vlc->p_libvlc_int));
        fx.applyEqualizerPreset("reggae");
        QTRY_VERIFY_WITH_TIMEOUT(QFile::exists(m_configPath), 3000);
        QFile file(m_configPath);
        QVERIFY(file.open(QIODevice::ReadOnly));
        QVERIFY(file.readAll().contains("equalizer-preset=reggae"));
    }

private:
    QTemporaryDir m_dir;
    QString m_configPath;
    libvlc_instance_t* m_vlc = nullptr;
};

QTEST_GUILESS_MAIN(TestEffectsController)
#include "test_effects_controller.moc"
