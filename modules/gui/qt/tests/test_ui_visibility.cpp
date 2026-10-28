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

#include <QTest>
#include <QSignalSpy>

#include "../redesign/cpp/uivisibility.hpp"

// "Hide UI" of the redesign: one flag, shared by the right-click menu (C++) and the shell (QML).
class TestUiVisibility : public QObject
{
    Q_OBJECT

private slots:
    void init()
    {
        // the instance is process wide: each test starts from shown
        UiVisibility::instance()->setHidden(false);
    }

    void defaultIsShown()
    {
        UiVisibility visibility;
        QCOMPARE(visibility.hidden(), false);
    }

    void toggleTwiceReturnsAndNotifiesTwice()
    {
        UiVisibility visibility;
        QSignalSpy spy(&visibility, &UiVisibility::hiddenChanged);

        visibility.toggle();
        QCOMPARE(visibility.hidden(), true);
        visibility.toggle();
        QCOMPARE(visibility.hidden(), false);

        QCOMPARE(spy.count(), 2);
    }

    void settingTheSameValueNotifiesOnce()
    {
        UiVisibility visibility;
        QSignalSpy spy(&visibility, &UiVisibility::hiddenChanged);

        visibility.setHidden(true);
        visibility.setHidden(true);

        QCOMPARE(spy.count(), 1);
        QCOMPARE(spy.at(0).at(0).toBool(), true);
    }

    void showingWhatIsShownDoesNothing()
    {
        // Esc in the shell always sets hidden = false
        UiVisibility visibility;
        QSignalSpy spy(&visibility, &UiVisibility::hiddenChanged);

        visibility.setHidden(false);

        QCOMPARE(spy.count(), 0);
    }

    void instanceIsOneObject()
    {
        UiVisibility* a = UiVisibility::instance();
        QVERIFY(a != nullptr);
        QCOMPARE(UiVisibility::instance(), a);

        a->toggle();
        QCOMPARE(UiVisibility::instance()->hidden(), true);
    }
};

QTEST_GUILESS_MAIN(TestUiVisibility)
#include "test_ui_visibility.moc"
