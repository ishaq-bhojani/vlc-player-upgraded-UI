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

#include <memory>

#include <QTemporaryDir>
#include <QTest>

#include <vlc/vlc.h>
#include <vlc_common.h>
#include <vlc_configuration.h>

#include "../../../../lib/libvlc_internal.h"

#include "../redesign/cpp/hotkeyfeedback.hpp"

// msg_Err() of ShortcutsModel names the module (declared extern in vlc_messages.h)
const char vlc_module_name[] = "test_hotkey_feedback";

// The text of the shortcut toast: "<keys> — <action>" for a key that a hotkey action holds.
class TestHotkeyFeedback : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        // a configuration file of its own: the default keys of the core
        const QByteArray configArg = "--config=" + m_dir.filePath("vlcrc").toUtf8();
        const char* argv[] = {"--no-ignore-config", configArg.constData()};
        m_vlc = libvlc_new(2, argv);
        QVERIFY(m_vlc);
        m_feedback = std::make_unique<HotkeyFeedback>(VLC_OBJECT(m_vlc->p_libvlc_int));
    }

    void cleanupTestCase()
    {
        m_feedback.reset();
        if (m_vlc)
            libvlc_release(m_vlc);
    }

    void spaceIsPlayPause()
    {
        const QString text = m_feedback->describe(Qt::Key_Space, Qt::NoModifier);
        QVERIFY2(text.startsWith(QStringLiteral("Space — ")), qPrintable(text));
        QVERIFY2(text.contains(QStringLiteral("Play/Pause")), qPrintable(text));
    }

    void anUnboundKeyHasNoText()
    {
        QCOMPARE(m_feedback->describe(Qt::Key_F13, Qt::NoModifier), QString());
        // a modifier alone is no hotkey
        QCOMPARE(m_feedback->describe(Qt::Key_Control, Qt::ControlModifier), QString());
    }

    void aComboWithCtrl()
    {
        const QString text = m_feedback->describe(Qt::Key_Right, Qt::ControlModifier);
        QVERIFY2(text.startsWith(QStringLiteral("Ctrl+Right — ")), qPrintable(text));
        QVERIFY2(text.contains(QStringLiteral("Medium forward jump")), qPrintable(text));
    }

    void followsAChangeOfTheConfiguration()
    {
        // the keys are read live: F13 given to play/pause names it at once
        config_PutPsz("key-play-pause", "F13");
        const QString text = m_feedback->describe(Qt::Key_F13, Qt::NoModifier);
        config_PutPsz("key-play-pause", "Space");
        QVERIFY2(text.startsWith(QStringLiteral("F13 — ")), qPrintable(text));
        QVERIFY2(text.contains(QStringLiteral("Play/Pause")), qPrintable(text));
    }

private:
    QTemporaryDir m_dir;
    libvlc_instance_t* m_vlc = nullptr;
    std::unique_ptr<HotkeyFeedback> m_feedback;
};

QTEST_GUILESS_MAIN(TestHotkeyFeedback)
#include "test_hotkey_feedback.moc"
