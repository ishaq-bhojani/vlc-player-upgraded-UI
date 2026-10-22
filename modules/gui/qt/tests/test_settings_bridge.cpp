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

#include <QSignalSpy>
#include <QTest>
#include <QVariantMap>

#include "../redesign/cpp/settingsbridge.hpp"
#include "../util/color_scheme_model.hpp"

/**
 * SettingsBridge: the VLC key string of a key press, and the color scheme with a real
 * ColorSchemeModel. The file dialogs (pickFolder, pickFile) are native dialogs: owner check.
 */
class TestSettingsBridge : public QObject
{
    Q_OBJECT

private:
    QString key(int qtKey, Qt::KeyboardModifiers modifiers = Qt::NoModifier,
                const QString& text = QString()) const
    {
        SettingsBridge bridge(nullptr);
        return bridge.hotkeyFromKeyEvent(qtKey, int(modifiers), text);
    }

private slots:
    void hotkeyLetters()
    {
        QCOMPARE(key(Qt::Key_Q, Qt::ControlModifier, "q"), QString("Ctrl+q"));
        // Qt reports the upper case letter, VLC stores the lower case one
        QCOMPARE(key(Qt::Key_A, Qt::NoModifier, "a"), QString("a"));
        QCOMPARE(key(Qt::Key_Z, Qt::ControlModifier | Qt::ShiftModifier, "Z"), QString("Ctrl+Shift+z"));
    }

    void hotkeyNamedKeys()
    {
        QCOMPARE(key(Qt::Key_Space, Qt::NoModifier, " "), QString("Space"));
        QCOMPARE(key(Qt::Key_Left, Qt::AltModifier), QString("Alt+Left"));
        QCOMPARE(key(Qt::Key_Return), QString("Enter"));
    }

    void hotkeyFunctionKeys()
    {
        QCOMPARE(key(Qt::Key_F5), QString("F5"));
        QCOMPARE(key(Qt::Key_F11), QString("F11"));
        QCOMPARE(key(Qt::Key_F12, Qt::ShiftModifier), QString("Shift+F12"));
    }

    void loneModifiersAndUnknownGiveNothing()
    {
        QCOMPARE(key(Qt::Key_Shift, Qt::ShiftModifier), QString());
        QCOMPARE(key(Qt::Key_Control, Qt::ControlModifier), QString());
        QCOMPARE(key(Qt::Key_Alt, Qt::AltModifier), QString());
        QCOMPARE(key(Qt::Key_Meta, Qt::MetaModifier), QString());
        QCOMPARE(key(Qt::Key_AltGr), QString());
        QCOMPARE(key(Qt::Key_unknown), QString());
    }

    void keyWithoutVlcNameGivesNothing()
    {
        // no entry in the table of util/vlchotkeyconverter.cpp: only the modifiers would be left
        QCOMPARE(key(Qt::Key_Kana_Lock), QString());
        QCOMPARE(key(Qt::Key_Kana_Lock, Qt::ControlModifier), QString());
    }

    void localFileUrlDrivePaths()
    {
        SettingsBridge bridge(nullptr);
        QCOMPARE(bridge.localFileUrl("C:\\Music\\Albums"), QString("file:///C:/Music/Albums"));
        QCOMPARE(bridge.localFileUrl("C:/My Music"), QString("file:///C:/My%20Music"));
        QCOMPARE(bridge.localFileUrl("c:\\"), QString("file:///c:/"));
    }

    void localFileUrlPosixPaths()
    {
        SettingsBridge bridge(nullptr);
        QCOMPARE(bridge.localFileUrl("/home/me/Music"), QString("file:///home/me/Music"));
        QCOMPARE(bridge.localFileUrl("/a#b"), QString("file:///a%23b"));
        QCOMPARE(bridge.localFileUrl("  /home/me  "), QString("file:///home/me"));
    }

    void localFileUrlNetworkPaths()
    {
        SettingsBridge bridge(nullptr);
        // UNC: the server is the host of the URL, not a path segment
        QCOMPARE(bridge.localFileUrl("\\\\server\\share"), QString("file://server/share"));
        QCOMPARE(bridge.localFileUrl("\\\\server\\share\\My Music\\a#b"),
                 QString("file://server/share/My%20Music/a%23b"));
        QCOMPARE(bridge.localFileUrl("//server/share/Music"), QString("file://server/share/Music"));
        // only the server: no path
        QCOMPARE(bridge.localFileUrl("\\\\server"), QString("file://server"));
    }

    void localFileUrlKeepsUrlsAndEmpty()
    {
        SettingsBridge bridge(nullptr);
        QCOMPARE(bridge.localFileUrl("file:///home/me"), QString("file:///home/me"));
        QCOMPARE(bridge.localFileUrl("smb://host/share"), QString("smb://host/share"));
        QCOMPARE(bridge.localFileUrl(""), QString());
        QCOMPARE(bridge.localFileUrl("   "), QString());
    }

    void colorSchemeKinds()
    {
        ColorSchemeModel model;
        SettingsBridge bridge(&model);

        const QVariantList schemes = bridge.colorSchemes();
        QCOMPARE(schemes.size(), model.rowCount(QModelIndex()));
        // by kind, whatever the order of the rows
        const auto kindOf = [&](int row) { return schemes.at(row).toMap().value("kind").toString(); };
        const auto items = model.getSchemes();
        for (int row = 0; row < items.size(); ++row)
        {
            QCOMPARE(schemes.at(row).toMap().value("text").toString(), items.at(row).text);
            const QString expected = items.at(row).scheme == ColorSchemeModel::Day ? "light"
                                     : items.at(row).scheme == ColorSchemeModel::Night ? "dark"
                                                                                       : "system";
            QCOMPARE(kindOf(row), expected);
        }
        QStringList kinds;
        for (int row = 0; row < schemes.size(); ++row)
            kinds << kindOf(row);
        kinds.sort();
        QCOMPARE(kinds, QStringList({"dark", "light", "system"}));
    }

    void colorSchemeIndexRoundTrip()
    {
        ColorSchemeModel model;
        SettingsBridge bridge(&model);
        QSignalSpy changed(&bridge, &SettingsBridge::colorSchemeIndexChanged);

        QCOMPARE(bridge.colorSchemeIndex(), model.currentIndex());

        const int other = model.currentIndex() == 2 ? 1 : 2;
        bridge.setColorSchemeIndex(other);
        QCOMPARE(bridge.colorSchemeIndex(), other);
        QCOMPARE(model.currentIndex(), other);
        QCOMPARE(changed.count(), 1);

        // the same row again changes nothing
        bridge.setColorSchemeIndex(other);
        QCOMPARE(changed.count(), 1);

        // the model's own change is seen too
        model.setCurrentIndex(0);
        QCOMPARE(bridge.colorSchemeIndex(), 0);
        QCOMPARE(changed.count(), 2);
    }

    void withoutModelNothingBreaks()
    {
        SettingsBridge bridge(nullptr);
        QVERIFY(bridge.colorSchemes().isEmpty());
        QCOMPARE(bridge.colorSchemeIndex(), 0);
        bridge.setColorSchemeIndex(2);
        QCOMPARE(bridge.colorSchemeIndex(), 0);
    }
};

QTEST_GUILESS_MAIN(TestSettingsBridge)
#include "test_settings_bridge.moc"
