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

#include <cstdlib>

#include <QTest>
#include <QSettings>
#include <QTemporaryDir>

#include <map>
#include <string>

#include <vlc/vlc.h>
#include <vlc_common.h>

#include "../../../../lib/libvlc_internal.h"

#include "../redesign/cpp/redesign.hpp"

class TestRedesignOption : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        // the qt-redesign option is declared by the qt plugin, which has to
        // be discoverable for libvlc to accept --[no-]qt-redesign
        setenv("VLC_PLUGIN_PATH", TOP_BUILDDIR"/modules", 0);
        setenv("VLC_LIB_PATH", TOP_BUILDDIR"/modules", 0);
    }

    void defaultIsTrue()
    {
        libvlc_instance_t* vlc = libvlc_new(0, nullptr);
        QVERIFY(vlc);
        QVERIFY(redesign::isEnabled(VLC_OBJECT(vlc->p_libvlc_int)));
        libvlc_release(vlc);
    }

    void canBeDisabled()
    {
        const char* argv[] = {"--no-qt-redesign"};
        libvlc_instance_t* vlc = libvlc_new(1, argv);
        QVERIFY(vlc);
        QVERIFY(!redesign::isEnabled(VLC_OBJECT(vlc->p_libvlc_int)));
        libvlc_release(vlc);
    }

    void firstRunByMode()
    {
        // the redesign shows its onboarding, never the QWidgets wizard (which has the
        // Modern/Classic page); --no-qt-redesign keeps the wizard
        QCOMPARE(redesign::firstRunFor(true), redesign::FirstRun::Onboarding);
        QCOMPARE(redesign::firstRunFor(false), redesign::FirstRun::Stock);

        const char* argv[] = {"--no-qt-redesign"};
        libvlc_instance_t* vlc = libvlc_new(1, argv);
        QVERIFY(vlc);
        QCOMPARE(redesign::firstRunFor(redesign::isEnabled(VLC_OBJECT(vlc->p_libvlc_int))),
                 redesign::FirstRun::Stock);
        libvlc_release(vlc);
    }

    void stockLayoutOptions()
    {
        // MainCtx::loadPrefs reads qt-menubar, qt-titlebar and qt-pin-controls only when this is true
        QVERIFY(!redesign::readsStockLayoutOptions(true));
        QVERIFY(redesign::readsStockLayoutOptions(false));
    }

    void rootUrl()
    {
        QCOMPARE(redesign::rootQmlUrl(true),
                 QUrl("qrc:/qt/qml/VLC/Redesign/RedesignInterface.qml"));
        QCOMPARE(redesign::rootQmlUrl(false),
                 QUrl("qrc:/qt/qml/VLC/MainInterface/MainInterface.qml"));
    }

    void defaultOverridesSeededOnce()
    {
        // the window keeps the user's size in the redesign; stock keeps the upstream default
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        QSettings settings(dir.filePath("s.ini"), QSettings::IniFormat);
        std::map<std::string, int> written;
        const auto put = [&](const char* option, int value) { written[option] = value; };

        redesign::seedDefaults(false, &settings, put);
        QVERIFY(written.empty());
        QVERIFY(!settings.contains("redesign/DefaultsSeeded"));

        redesign::seedDefaults(true, &settings, put);
        QCOMPARE(written.size(), redesign::defaultOverrides().size());
        QCOMPARE(written["qt-video-autoresize"], 0);

        // a later start must not undo a value the user chose
        written.clear();
        redesign::seedDefaults(true, &settings, put);
        QVERIFY(written.empty());
    }
};

QTEST_GUILESS_MAIN(TestRedesignOption)
#include "test_redesign_option.moc"
