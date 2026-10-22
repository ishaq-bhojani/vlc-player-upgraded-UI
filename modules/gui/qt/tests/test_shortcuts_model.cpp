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
#include <memory>

#include <QFile>
#include <QSet>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include <vlc/vlc.h>
#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_messages.h>

#include "../../../../lib/libvlc_internal.h"

#include "../redesign/cpp/shortcutsmodel.hpp"

// msg_Err() of ShortcutsModel names the module (declared extern in vlc_messages.h)
const char vlc_module_name[] = "test_shortcuts_model";

/**
 * ShortcutsModel against a real libvlc instance whose configuration file is a temporary one
 * (--config), so that the configuration of the user is neither read nor written.
 */
class TestShortcutsModel : public QObject
{
    Q_OBJECT

private:
    void startVlc()
    {
        const QByteArray configArg = "--config=" + m_configFile.toUtf8();
        const char* argv[] = {"--no-ignore-config", configArg.constData()};
        m_vlc = libvlc_new(2, argv);
        QVERIFY(m_vlc);
        m_model = std::make_unique<ShortcutsModel>(VLC_OBJECT(m_vlc->p_libvlc_int));
    }

    void stopVlc()
    {
        m_model.reset();
        if (m_vlc)
            libvlc_release(m_vlc);
        m_vlc = nullptr;
    }

    static QString cfg(const char* key)
    {
        char* value = config_GetPsz(key);
        const QString text = QString::fromUtf8(value);
        free(value);
        return text;
    }

    //! row of an action, -1 if there is none
    int rowOf(const QString& actionKey) const
    {
        for (int row = 0; row < m_model->rowCount(); ++row)
        {
            if (m_model->data(m_model->index(row), ShortcutsModel::ActionKeyRole).toString()
                == actionKey)
                return row;
        }
        return -1;
    }

    QVariant roleOf(const QString& actionKey, int role) const
    {
        const int row = rowOf(actionKey);
        return row < 0 ? QVariant() : m_model->data(m_model->index(row), role);
    }

    QString hotkeyOf(const QString& actionKey) const
    {
        return roleOf(actionKey, ShortcutsModel::HotkeyRole).toString();
    }

    QString globalHotkeyOf(const QString& actionKey) const
    {
        return roleOf(actionKey, ShortcutsModel::GlobalHotkeyRole).toString();
    }

    QString labelOf(const QString& actionKey) const
    {
        return roleOf(actionKey, ShortcutsModel::LabelRole).toString();
    }

    //! rows covered by the dataChanged signals recorded by the spy
    static QSet<int> changedRows(const QSignalSpy& spy)
    {
        QSet<int> rows;
        for (const QList<QVariant>& args : spy)
        {
            const int first = args.at(0).toModelIndex().row();
            const int last = args.at(1).toModelIndex().row();
            for (int row = first; row <= last; ++row)
                rows.insert(row);
        }
        return rows;
    }

private slots:
    void initTestCase()
    {
        // the options are declared by the core, which libvlc has to find
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

    void listsActions()
    {
        QVERIFY(m_model->rowCount() > 50);
        QVERIFY(rowOf("key-play-pause") >= 0);

        QVERIFY(!hotkeyOf("key-play-pause").isEmpty());
        QCOMPARE(hotkeyOf("key-play-pause"), cfg("key-play-pause"));
        QVERIFY(!labelOf("key-play-pause").isEmpty());
        QCOMPARE(roleOf("key-play-pause", ShortcutsModel::GlobalKeyRole).toString(),
                 QString("global-key-play-pause"));
        QCOMPARE(globalHotkeyOf("key-play-pause"), cfg("global-key-play-pause"));

        // the global variants are not rows of their own
        QCOMPARE(rowOf("global-key-play-pause"), -1);
        for (int i = 0; i < m_model->rowCount(); ++i)
        {
            const QModelIndex index = m_model->index(i);
            const QString key = m_model->data(index, ShortcutsModel::ActionKeyRole).toString();
            QVERIFY2(key.startsWith("key-"), qPrintable(key));
            QVERIFY2(!m_model->data(index, ShortcutsModel::LabelRole).toString().isEmpty(),
                     qPrintable(key));
        }

        const QHash<int, QByteArray> names = m_model->roleNames();
        QCOMPARE(names.value(ShortcutsModel::ActionKeyRole), QByteArray("actionKey"));
        QCOMPARE(names.value(ShortcutsModel::LabelRole), QByteArray("label"));
        QCOMPARE(names.value(ShortcutsModel::HotkeyRole), QByteArray("hotkey"));
        QCOMPARE(names.value(ShortcutsModel::GlobalHotkeyRole), QByteArray("globalHotkey"));
    }

    void conflictDetected()
    {
        const QString hotkey = hotkeyOf("key-play-pause");
        QVERIFY(!hotkey.isEmpty());
        QCOMPARE(m_model->conflictFor("key-stop", hotkey, false), labelOf("key-play-pause"));

        // the action itself is not its own conflict
        QCOMPARE(m_model->conflictFor("key-play-pause", hotkey, false), QString());
        // a key nobody uses
        QCOMPARE(m_model->conflictFor("key-stop", "Ctrl+Alt+Shift+F11", false), QString());
        // unknown action: the label of whoever uses the key
        QCOMPARE(m_model->conflictFor("no-such-action", hotkey, false),
                 labelOf("key-play-pause"));
        // a value of several keys (outside Windows the default of key-play-pause) conflicts when
        // any of its keys does
        QCOMPARE(m_model->conflictFor("key-stop", "Ctrl+Alt+Shift+F11\tSpace", false),
                 labelOf("key-play-pause"));
    }

    void invalidParentHasNoRows()
    {
        QVERIFY(m_model->rowCount() > 0);
        QCOMPARE(m_model->rowCount(m_model->index(0)), 0);
    }

    void actionWithoutTextIsListed()
    {
        // declared with an empty psz_text: listed as upstream does, labelled with its key
        QVERIFY(rowOf("key-projection-toggle") >= 0);
        QCOMPARE(labelOf("key-projection-toggle"), QString("key-projection-toggle"));
        QVERIFY(hotkeyOf("key-projection-toggle").isEmpty());

        m_model->assign("key-projection-toggle", "Ctrl+Alt+Shift+F11", false);
        QCOMPARE(cfg("key-projection-toggle"), QString("Ctrl+Alt+Shift+F11"));
        QCOMPARE(m_model->conflictFor("key-stop", "Ctrl+Alt+Shift+F11", false),
                 QString("key-projection-toggle"));
    }

    void emptyHotkeyNeverConflicts()
    {
        // several actions have no hotkey by default (e.g. the global ones: KEY_UNSET)
        QVERIFY(globalHotkeyOf("key-stop").isEmpty());
        QVERIFY(globalHotkeyOf("key-play-pause").isEmpty());
        QCOMPARE(m_model->conflictFor("key-stop", "", true), QString());
        QCOMPARE(m_model->conflictFor("key-stop", "", false), QString());

        // two actions without a local hotkey do not conflict either
        m_model->assign("key-stop", "", false);
        m_model->assign("key-play-pause", "", false);
        QVERIFY(hotkeyOf("key-stop").isEmpty());
        QVERIFY(hotkeyOf("key-play-pause").isEmpty());
        QCOMPARE(m_model->conflictFor("key-stop", "", false), QString());
        QCOMPARE(m_model->conflictFor("key-play-pause", "", false), QString());
    }

    void caseSensitive()
    {
        // as stored: "Space" is not "space"
        // (the default is "Space", plus "Media Play Pause" outside Windows)
        QVERIFY(hotkeyOf("key-play-pause").split('\t').contains("Space"));
        QCOMPARE(m_model->conflictFor("key-stop", "space", false), QString());
        QCOMPARE(m_model->conflictFor("key-stop", "Space", false), labelOf("key-play-pause"));
    }

    void assignClearsConflict()
    {
        const QString hotkey = hotkeyOf("key-play-pause");
        QVERIFY(!hotkey.isEmpty());
        QVERIFY(hotkeyOf("key-stop") != hotkey);
        const int playRow = rowOf("key-play-pause");
        const int stopRow = rowOf("key-stop");

        QSignalSpy changed(m_model.get(), &QAbstractItemModel::dataChanged);
        m_model->assign("key-stop", hotkey, false);

        QCOMPARE(hotkeyOf("key-play-pause"), QString());
        QCOMPARE(cfg("key-play-pause"), QString());
        QCOMPARE(hotkeyOf("key-stop"), hotkey);
        QCOMPARE(cfg("key-stop"), hotkey);

        // a signal for both rows, for the local hotkey
        for (const QList<QVariant>& args : changed)
            QCOMPARE(args.at(2).value<QList<int>>(), QList<int>{ShortcutsModel::HotkeyRole});
        const QSet<int> rows = changedRows(changed);
        QVERIFY(rows.contains(playRow));
        QVERIFY(rows.contains(stopRow));
        QCOMPARE(rows.size(), 2);

        // the new owner is the one that conflicts now
        QCOMPARE(m_model->conflictFor("key-play-pause", hotkey, false), labelOf("key-stop"));

        // saved by itself (before the instance ends)
        QFile saved(m_configFile);
        QVERIFY(saved.open(QIODevice::ReadOnly));
        const QByteArray content = saved.readAll();
        saved.close();
        QVERIFY(content.contains("\nkey-stop=" + hotkey.toUtf8() + "\n"));
        QVERIFY(!content.contains("\nkey-play-pause=" + hotkey.toUtf8() + "\n"));

        // a fresh instance sees it
        stopVlc();
        startVlc();
        QCOMPARE(cfg("key-play-pause"), QString());
        QCOMPARE(cfg("key-stop"), hotkey);
        QCOMPARE(hotkeyOf("key-play-pause"), QString());
        QCOMPARE(hotkeyOf("key-stop"), hotkey);
    }

    void assignOneKeyOfSeveral()
    {
        // the scenario of the brief: Space moves from play/pause to stop, whatever the
        // platform default
        config_PutPsz("key-play-pause", "Space\tMedia Play Pause");
        QCOMPARE(m_model->conflictFor("key-stop", "Space", false), labelOf("key-play-pause"));
        m_model->assign("key-stop", "Space", false);
        QCOMPARE(hotkeyOf("key-play-pause"), QString("Media Play Pause"));
        QCOMPARE(cfg("key-play-pause"), QString("Media Play Pause"));
        QCOMPARE(hotkeyOf("key-stop"), QString("Space"));
    }

    void duplicateKeysAreStoredOnce()
    {
        m_model->assign("key-stop", "Ctrl+Alt+Shift+F11\tCtrl+Alt+Shift+F11", false);
        QCOMPARE(hotkeyOf("key-stop"), QString("Ctrl+Alt+Shift+F11"));
        QCOMPARE(cfg("key-stop"), QString("Ctrl+Alt+Shift+F11"));
    }

    void assignWithoutConflictChangesOneRow()
    {
        QSignalSpy changed(m_model.get(), &QAbstractItemModel::dataChanged);
        m_model->assign("key-stop", "Ctrl+Alt+Shift+F11", false);
        QCOMPARE(hotkeyOf("key-stop"), QString("Ctrl+Alt+Shift+F11"));
        QCOMPARE(cfg("key-stop"), QString("Ctrl+Alt+Shift+F11"));
        QCOMPARE(changedRows(changed), QSet<int>{rowOf("key-stop")});
        QCOMPARE(changed.first().at(2).value<QList<int>>(),
                 QList<int>{ShortcutsModel::HotkeyRole});

        // assigning what the action already has changes nothing
        changed.clear();
        m_model->assign("key-stop", "Ctrl+Alt+Shift+F11", false);
        QCOMPARE(changed.count(), 0);
    }

    void reloadResetsTheModel()
    {
        // a change made behind the model's back (the QWidgets preferences) is read again
        const int rows = m_model->rowCount();
        config_PutPsz("key-stop", "Ctrl+Alt+Shift+F10");
        QSignalSpy reset(m_model.get(), &QAbstractItemModel::modelReset);
        QMetaObject::invokeMethod(m_model.get(), "reload");
        QCOMPARE(reset.count(), 1);
        QCOMPARE(m_model->rowCount(), rows);
        QCOMPARE(hotkeyOf("key-stop"), QString("Ctrl+Alt+Shift+F10"));
    }

    void assignEmptyClears()
    {
        QVERIFY(!hotkeyOf("key-play-pause").isEmpty());
        const QString stop = hotkeyOf("key-stop");
        QVERIFY(!stop.isEmpty());
        m_model->assign("key-play-pause", "", false);
        QCOMPARE(hotkeyOf("key-play-pause"), QString());
        QCOMPARE(cfg("key-play-pause"), QString());
        // nobody else lost a key
        QCOMPARE(hotkeyOf("key-stop"), stop);
    }

    void globalScopeSeparate()
    {
        // the local key of play/pause is not a conflict in the global scope, and vice versa
        const QString local = hotkeyOf("key-play-pause");
        QVERIFY(!local.isEmpty());
        QCOMPARE(m_model->conflictFor("key-stop", local, true), QString());

        m_model->assign("key-stop", "Ctrl+Alt+Shift+F11", true);
        QCOMPARE(globalHotkeyOf("key-stop"), QString("Ctrl+Alt+Shift+F11"));
        QCOMPARE(cfg("global-key-stop"), QString("Ctrl+Alt+Shift+F11"));
        QVERIFY(hotkeyOf("key-stop") != QString("Ctrl+Alt+Shift+F11"));
        QCOMPARE(hotkeyOf("key-stop"), cfg("key-stop"));

        QCOMPARE(m_model->conflictFor("key-play-pause", "Ctrl+Alt+Shift+F11", false),
                 QString());
        QCOMPARE(m_model->conflictFor("key-play-pause", "Ctrl+Alt+Shift+F11", true),
                 labelOf("key-stop"));

        // assigning the local key of play/pause globally clears nobody's local key
        const QString stopLocal = hotkeyOf("key-stop");
        m_model->assign("key-pause", local, true);
        QCOMPARE(globalHotkeyOf("key-pause"), local);
        QCOMPARE(hotkeyOf("key-play-pause"), local);
        QCOMPARE(hotkeyOf("key-stop"), stopLocal);
    }

    void assignGlobalClearsGlobalConflict()
    {
        m_model->assign("key-stop", "Ctrl+Alt+Shift+F11", true);
        QSignalSpy changed(m_model.get(), &QAbstractItemModel::dataChanged);
        m_model->assign("key-pause", "Ctrl+Alt+Shift+F11", true);
        QCOMPARE(globalHotkeyOf("key-stop"), QString());
        QCOMPARE(cfg("global-key-stop"), QString());
        QCOMPARE(globalHotkeyOf("key-pause"), QString("Ctrl+Alt+Shift+F11"));
        QCOMPARE(cfg("global-key-pause"), QString("Ctrl+Alt+Shift+F11"));
        QCOMPARE(changedRows(changed), (QSet<int>{rowOf("key-stop"), rowOf("key-pause")}));
        for (const QList<QVariant>& args : changed)
            QCOMPARE(args.at(2).value<QList<int>>(),
                     QList<int>{ShortcutsModel::GlobalHotkeyRole});
    }

    void severalKeysAreSeparate()
    {
        // VLC stores several keys of an action separated by a tab
        config_PutPsz("key-stop", "Ctrl+Alt+Shift+F10\tCtrl+Alt+Shift+F11");
        QCOMPARE(hotkeyOf("key-stop"), QString("Ctrl+Alt+Shift+F10\tCtrl+Alt+Shift+F11"));

        const QString stop = labelOf("key-stop");
        QCOMPARE(m_model->conflictFor("key-pause", "Ctrl+Alt+Shift+F11", false), stop);
        QCOMPARE(m_model->conflictFor("key-pause", "Ctrl+Alt+Shift+F10", false), stop);
        // not a substring match
        QCOMPARE(m_model->conflictFor("key-pause", "Ctrl+Alt+Shift+F1", false), QString());
        QCOMPARE(m_model->conflictFor("key-pause", "F11", false), QString());

        // taking one key leaves the other with its action
        m_model->assign("key-pause", "Ctrl+Alt+Shift+F11", false);
        QCOMPARE(hotkeyOf("key-stop"), QString("Ctrl+Alt+Shift+F10"));
        QCOMPARE(cfg("key-stop"), QString("Ctrl+Alt+Shift+F10"));
        QCOMPARE(hotkeyOf("key-pause"), QString("Ctrl+Alt+Shift+F11"));
    }

    void onboardingActionsExist()
    {
        // the actions of the essentials of OnboardingSteps.qml are real actions of the core
        for (const char* action : {"key-play-pause", "key-jump-short", "key-jump+short", "key-vol-up",
                                   "key-vol-down", "key-toggle-fullscreen", "key-subtitle-track",
                                   "key-intf-show", "key-set-bookmark1"})
            QVERIFY2(rowOf(action) >= 0, action);
        // the 10 second jumps are the short ones (the medium ones jump a minute)
        QVERIFY(!hotkeyOf("key-jump-short").isEmpty());
        QVERIFY(!hotkeyOf("key-jump+short").isEmpty());
    }

    void hotkeyForReadsLive()
    {
        // the onboarding card reads its keys by action, live
        QCOMPARE(m_model->hotkeyFor("key-play-pause"), hotkeyOf("key-play-pause"));
        QVERIFY(!m_model->hotkeyFor("key-vol-up").isEmpty());
        m_model->assign("key-vol-up", "Ctrl+Alt+Shift+F9", false);
        QCOMPARE(m_model->hotkeyFor("key-vol-up"), QString("Ctrl+Alt+Shift+F9"));
        QCOMPARE(m_model->hotkeyFor("no-such-action"), QString());
        QCOMPARE(m_model->hotkeyFor("global-key-play-pause"), QString());
    }

    void unknownActionIsIgnored()
    {
        QSignalSpy changed(m_model.get(), &QAbstractItemModel::dataChanged);
        const QString before = cfg("key-play-pause");
        m_model->assign("no-such-action", "Space", false);
        m_model->assign("global-key-play-pause", "Space", false);
        m_model->assign("", "Space", false);
        QCOMPARE(changed.count(), 0);
        QCOMPARE(cfg("key-play-pause"), before);
    }

private:
    std::unique_ptr<QTemporaryDir> m_dir;
    QString m_configFile;
    libvlc_instance_t* m_vlc = nullptr;
    std::unique_ptr<ShortcutsModel> m_model;
};

QTEST_GUILESS_MAIN(TestShortcutsModel)
#include "test_shortcuts_model.moc"
