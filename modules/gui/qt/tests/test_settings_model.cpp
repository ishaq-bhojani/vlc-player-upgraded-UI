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

#include <cstdlib>
#include <limits>
#include <memory>

#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include <vlc/vlc.h>
#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_messages.h>
#include <vlc_plugin.h>

#include "../../../../lib/libvlc_internal.h"

#include "../redesign/cpp/settingsmodel.hpp"

// msg_Err() of SettingsModel names the module (declared extern in vlc_messages.h)
const char vlc_module_name[] = "test_settings_model";

/**
 * SettingsModel against a real libvlc instance whose configuration file is a temporary one
 * (--config), so that the configuration of the user is neither read nor written.
 */
class TestSettingsModel : public QObject
{
    Q_OBJECT

private:
    //! starts a libvlc instance on the temporary configuration file
    void startVlc()
    {
        const QByteArray configArg = "--config=" + m_configFile.toUtf8();
        const char* argv[] = {"--no-ignore-config", configArg.constData()};
        m_vlc = libvlc_new(2, argv);
        QVERIFY(m_vlc);
        m_model = std::make_unique<SettingsModel>(VLC_OBJECT(m_vlc->p_libvlc_int));
    }

    void stopVlc()
    {
        m_model.reset();
        if (m_vlc)
            libvlc_release(m_vlc);
        m_vlc = nullptr;
    }

    static qlonglong cfgInt(const char* key) { return config_GetInt(key); }

    static QVariantMap choiceAt(const SettingItem* item, int index)
    {
        return item->choices().at(index).toMap();
    }

private slots:
    void initTestCase()
    {
        // the options are declared by the plugins (qt, ...), which libvlc has to find
        setenv("VLC_PLUGIN_PATH", TOP_BUILDDIR"/modules", 1);
        setenv("VLC_LIB_PATH", TOP_BUILDDIR"/modules", 1);
    }

    void init()
    {
        m_dir = std::make_unique<QTemporaryDir>();
        QVERIFY(m_dir->isValid());
        // other directories libvlc may write to
        qputenv("XDG_CONFIG_HOME", m_dir->filePath("xdg-config").toUtf8());
        qputenv("XDG_CACHE_HOME", m_dir->filePath("xdg-cache").toUtf8());
        qputenv("XDG_DATA_HOME", m_dir->filePath("xdg-data").toUtf8());
        m_configFile = m_dir->filePath("vlcrc");
        // an existing file: VLC looks for a legacy configuration when there is none
        QFile file(m_configFile);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.close();
        startVlc();
    }

    void cleanup()
    {
        stopVlc();
        m_dir.reset();
    }

    void unknownKeyIsNull()
    {
        QVERIFY(m_model->item("no-such-key") == nullptr);
        QVERIFY(m_model->item(QString()) == nullptr);
    }

    void sameObjectPerKey()
    {
        SettingItem* item = m_model->item("qt-pip-mode");
        QVERIFY(item);
        QCOMPARE(m_model->item("qt-pip-mode"), item);
        QVERIFY(m_model->item("qt-start-minimized") != item);
    }

    void boolRoundTrip()
    {
        SettingItem* item = m_model->item("qt-pip-mode");
        QVERIFY(item);
        QCOMPARE(item->type(), SettingItem::Bool);
        QCOMPARE(item->key(), QString("qt-pip-mode"));
        QCOMPARE(item->defaultValue(), QVariant(true));
        QCOMPARE(item->value(), QVariant(true));
        QVERIFY(!item->text().isEmpty());

        QSignalSpy changed(item, &SettingItem::valueChanged);
        item->setValue(false);
        QCOMPARE(cfgInt("qt-pip-mode"), qlonglong(0));
        QCOMPARE(item->value(), QVariant(false));
        QCOMPARE(changed.count(), 1);

        // writing the value that is already there is not a change
        item->setValue(false);
        QCOMPARE(changed.count(), 1);

        // setValue saves the configuration file by itself (before the instance ends)
        QFile saved(m_configFile);
        QVERIFY(saved.open(QIODevice::ReadOnly));
        QVERIFY(saved.readAll().contains("\nqt-pip-mode=0"));
        saved.close();

        // a fresh instance sees it
        stopVlc();
        startVlc();
        QCOMPARE(cfgInt("qt-pip-mode"), qlonglong(0));
        SettingItem* again = m_model->item("qt-pip-mode");
        QVERIFY(again);
        QCOMPARE(again->value(), QVariant(false));
    }

    void integerWithRange()
    {
        // no range declared: unbounded
        SettingItem* jump = m_model->item("short-jump-size");
        QVERIFY(jump);
        QCOMPARE(jump->type(), SettingItem::Integer);
        QCOMPARE(jump->defaultValue().toLongLong(), qlonglong(10));
        QVERIFY(!jump->min().isValid());
        QVERIFY(!jump->max().isValid());
        QVERIFY(jump->choices().isEmpty());

        // add_integer_with_range( "qt-max-volume", 125, 60, 300, ...)
        SettingItem* volume = m_model->item("qt-max-volume");
        QVERIFY(volume);
        QCOMPARE(volume->type(), SettingItem::Integer);
        QCOMPARE(volume->min().toLongLong(), qlonglong(60));
        QCOMPARE(volume->max().toLongLong(), qlonglong(300));

        volume->setValue(200);
        QCOMPARE(cfgInt("qt-max-volume"), qlonglong(200));
        QCOMPARE(volume->value().toLongLong(), qlonglong(200));
    }

    void integerValidation()
    {
        SettingItem* volume = m_model->item("qt-max-volume");
        QVERIFY(volume);
        QSignalSpy changed(volume, &SettingItem::valueChanged);

        // out of range: the configuration clamps, and the value that is held is what counts
        volume->setValue(1000);
        QCOMPARE(volume->value().toLongLong(), qlonglong(300));
        QCOMPARE(cfgInt("qt-max-volume"), qlonglong(300));
        QCOMPARE(changed.count(), 1);

        // the same request again changes nothing, and does not rewrite the file
        QVERIFY(QFile::remove(m_configFile));
        volume->setValue(1000);
        QCOMPARE(changed.count(), 1);
        QVERIFY(!QFile::exists(m_configFile));

        // not an integer: ignored
        volume->setValue("abc");
        volume->setValue(QVariant());
        QCOMPARE(volume->value().toLongLong(), qlonglong(300));
        QCOMPARE(cfgInt("qt-max-volume"), qlonglong(300));
        QCOMPARE(changed.count(), 1);
        QVERIFY(!QFile::exists(m_configFile));
    }

    void floatValidation()
    {
        SettingItem* opacity = m_model->item("qt-opacity");
        QVERIFY(opacity);
        QSignalSpy changed(opacity, &SettingItem::valueChanged);

        opacity->setValue(0.01);
        QCOMPARE(opacity->value().toDouble(), 0.1);
        QCOMPARE(changed.count(), 1);

        // not a finite number: ignored, nothing is saved
        QVERIFY(QFile::remove(m_configFile));
        opacity->setValue("abc");
        opacity->setValue(std::numeric_limits<double>::quiet_NaN());
        opacity->setValue(std::numeric_limits<double>::infinity());
        opacity->setValue(-std::numeric_limits<double>::infinity());
        QCOMPARE(opacity->value().toDouble(), 0.1);
        QCOMPARE(changed.count(), 1);
        QVERIFY(!QFile::exists(m_configFile));

        // huge but finite: clamped by the configuration, not undefined
        opacity->setValue(1e300);
        QCOMPARE(opacity->value().toDouble(), 1.0);
        QCOMPARE(changed.count(), 2);
    }

    void floatWithRange()
    {
        // add_float_with_range( "qt-opacity", 1., 0.1, 1., ...)
        SettingItem* opacity = m_model->item("qt-opacity");
        QVERIFY(opacity);
        QCOMPARE(opacity->type(), SettingItem::Float);
        QCOMPARE(opacity->defaultValue().toDouble(), 1.0);
        QCOMPARE(opacity->min().toDouble(), 0.1);
        QCOMPARE(opacity->max().toDouble(), 1.0);

        opacity->setValue(0.35);
        QVERIFY(qFuzzyCompare(config_GetFloat("qt-opacity"), 0.35f));
        QCOMPARE(opacity->value().toDouble(), 0.35);
    }

    void choiceHasLabels()
    {
        // module option: Automatic, the modules of the capability, Disable
        SettingItem* aout = m_model->item("aout");
        QVERIFY(aout);
        QCOMPARE(aout->type(), SettingItem::Choice);
        QVERIFY(!aout->choices().isEmpty());
        for (const QVariant& choice : aout->choices())
        {
            QVERIFY(choice.toMap().contains("value"));
            QVERIFY(!choice.toMap().value("label").toString().isEmpty());
        }
        QCOMPARE(choiceAt(aout, 0).value("value").toString(), QString("any"));

        // integer option with a declared list
        SettingItem* restore = m_model->item("restore-playback-pos");
        QVERIFY(restore);
        QCOMPARE(restore->type(), SettingItem::Choice);
        QVERIFY(restore->choices().size() >= 2);
        QCOMPARE(choiceAt(restore, 0).value("value").typeId(), int(QMetaType::LongLong));
        QVERIFY(!choiceAt(restore, 0).value("label").toString().isEmpty());

        // string option with a declared list
        SettingItem* mode = m_model->item("deinterlace-mode");
        QVERIFY(mode);
        QCOMPARE(mode->type(), SettingItem::Choice);
        QVERIFY(!mode->choices().isEmpty());
        QCOMPARE(mode->value().toString(), QString("auto"));
    }

    void fuzzyHasWords()
    {
        // an integer enumeration without a list in the option: the labels come from choice-labels.json
        SettingItem* fuzzy = m_model->item("sub-autodetect-fuzzy");
        QVERIFY(fuzzy);
        QCOMPARE(fuzzy->type(), SettingItem::Choice);
        QCOMPARE(fuzzy->choices().size(), 5);
        QCOMPARE(choiceAt(fuzzy, 0).value("label").toString(), QString("Don't auto-detect"));
        QCOMPARE(choiceAt(fuzzy, 1).value("label").toString(), QString("Any subtitle file"));
        QCOMPARE(choiceAt(fuzzy, 2).value("label").toString(),
                 QString("Subtitles containing the video name"));
        QCOMPARE(choiceAt(fuzzy, 3).value("label").toString(),
                 QString("Video name plus extra characters"));
        QCOMPARE(choiceAt(fuzzy, 4).value("label").toString(), QString("Exact video name"));
        for (int i = 0; i < 5; ++i)
            QCOMPARE(choiceAt(fuzzy, i).value("value").toLongLong(), qlonglong(i));

        QCOMPARE(fuzzy->defaultValue().toLongLong(), qlonglong(3));
        fuzzy->setValue(4);
        QCOMPARE(cfgInt("sub-autodetect-fuzzy"), qlonglong(4));
    }

    void stringPathAndHotkeyTypes()
    {
        SettingItem* language = m_model->item("audio-language");
        QVERIFY(language);
        QCOMPARE(language->type(), SettingItem::String);
        QVERIFY(language->choices().isEmpty());
        language->setValue("fra");
        char* stored = config_GetPsz("audio-language");
        QCOMPARE(QString::fromUtf8(stored), QString("fra"));
        free(stored);

        SettingItem* folder = m_model->item("snapshot-path");
        QVERIFY(folder);
        QCOMPARE(folder->type(), SettingItem::Path);

        SettingItem* hotkey = m_model->item("key-play-pause");
        QVERIFY(hotkey);
        QCOMPARE(hotkey->type(), SettingItem::Hotkey);
        QVERIFY(!hotkey->defaultValue().toString().isEmpty());
    }

    void resetRestoresDefault()
    {
        SettingItem* volume = m_model->item("qt-max-volume");
        QVERIFY(volume);
        QSignalSpy changed(volume, &SettingItem::valueChanged);
        volume->setValue(200);
        volume->reset();
        QCOMPARE(volume->value(), volume->defaultValue());
        QCOMPARE(cfgInt("qt-max-volume"), qlonglong(125));
        QCOMPARE(changed.count(), 2);

        SettingItem* pip = m_model->item("qt-pip-mode");
        QVERIFY(pip);
        pip->setValue(false);
        pip->reset();
        QCOMPARE(cfgInt("qt-pip-mode"), qlonglong(1));

        SettingItem* language = m_model->item("audio-language");
        QVERIFY(language);
        language->setValue("fra");
        language->reset();
        QCOMPARE(language->value().toString(), QString());
    }

    void restartFlag()
    {
        QSignalSpy pending(m_model.get(), &SettingsModel::restartPendingChanged);
        QVERIFY(!m_model->restartPending());

        // applies immediately
        SettingItem* pip = m_model->item("qt-pip-mode");
        QVERIFY(pip);
        QVERIFY(!pip->requiresRestart());
        pip->setValue(false);
        QVERIFY(!m_model->restartPending());
        QCOMPARE(pending.count(), 0);

        // read at startup (marked `restart` in docs/redesign/settings-map.md)
        SettingItem* minimized = m_model->item("qt-start-minimized");
        QVERIFY(minimized);
        QVERIFY(minimized->requiresRestart());
        minimized->setValue(true);
        QVERIFY(m_model->restartPending());
        QCOMPARE(pending.count(), 1);

        // it stays pending, and is signalled once
        SettingItem* aout = m_model->item("aout");
        QVERIFY(aout);
        aout->setValue("none");
        QVERIFY(m_model->restartPending());
        QCOMPARE(pending.count(), 1);
    }

    void restartKeys()
    {
        for (const char* key : {"aout", "vout", "audio", "video", "qt-compositor", "lua",
                                "media-library", "qt-accent-color", "file-logging", "logfile"})
            QVERIFY2(SettingsModel::keyRequiresRestart(key), key);
        for (const char* key : {"qt-pip-mode", "short-jump-size", "sub-autodetect-fuzzy",
                                "file-caching", "audio-replay-gain-preamp"})
            QVERIFY2(!SettingsModel::keyRequiresRestart(key), key);
    }

    void privateKeyIsReachable()
    {
        // declared with change_private(): hidden from the lists, but onboarding writes it
        SettingItem* ask = m_model->item("qt-privacy-ask");
        QVERIFY(ask);
        QCOMPARE(ask->type(), SettingItem::Bool);
        ask->setValue(false);
        QCOMPARE(cfgInt("qt-privacy-ask"), qlonglong(0));
    }

    void subcategoryKeys()
    {
        // "sub-autodetect-fuzzy" is declared by the core under SUBCAT_VIDEO_SUBPIC
        const QStringList subpic = m_model->keysInSubcategory(SUBCAT_VIDEO_SUBPIC);
        QVERIFY(subpic.contains("sub-autodetect-fuzzy"));
        QVERIFY(subpic.contains("sub-autodetect-file"));
        QVERIFY(!subpic.contains("qt-pip-mode"));
        QVERIFY(subpic.indexOf("sub-autodetect-file") < subpic.indexOf("sub-autodetect-fuzzy"));

        // the text subtitle decoder (a plugin) is under SUBCAT_INPUT_SCODEC
        QVERIFY(m_model->keysInSubcategory(SUBCAT_INPUT_SCODEC).contains("subsdec-encoding"));

        // no obsolete key: gradient has `add_obsolete_integer("gradient-type")`
        const QStringList vfilter = m_model->keysInSubcategory(SUBCAT_VIDEO_VFILTER);
        QVERIFY(vfilter.contains("gradient-mode"));
        QVERIFY(!vfilter.contains("gradient-type"));

        // no private key, declaration order
        const QStringList main = m_model->keysInSubcategory(SUBCAT_INTERFACE_MAIN);
        QVERIFY(main.contains("qt-pip-mode"));
        QVERIFY(!main.contains("qt-privacy-ask"));
        QVERIFY(main.indexOf("qt-system-tray") < main.indexOf("qt-notification"));

        // every key is a usable item
        for (const QString& key : subpic)
            QVERIFY2(m_model->item(key), qPrintable(key));

        QVERIFY(m_model->keysInSubcategory(SUBCAT_UNKNOWN).isEmpty());
        QVERIFY(m_model->keysInSubcategory(-12345).isEmpty());
    }

private:
    std::unique_ptr<QTemporaryDir> m_dir;
    QString m_configFile;
    libvlc_instance_t* m_vlc = nullptr;
    std::unique_ptr<SettingsModel> m_model;
};

QTEST_GUILESS_MAIN(TestSettingsModel)
#include "test_settings_model.moc"
