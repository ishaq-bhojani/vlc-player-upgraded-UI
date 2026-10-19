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

#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QTest>
#include <QtPlugin>

#include "../redesign/cpp/redesign.hpp"

#if defined(QT_STATIC) && defined(Q_OS_WIN)
// the static win64 Qt only links the native platform plugin
Q_IMPORT_PLUGIN(QWindowsIntegrationPlugin)
#endif

class TestRedesignFont : public QObject
{
    Q_OBJECT

private slots:
    void fontLoads()
    {
        const QFont before = QGuiApplication::font();

        QVERIFY(redesign::installAppFont());

        QCOMPARE(QGuiApplication::font().family(), QStringLiteral("Inter"));
        // only the family changes, not the size the platform chose
        QCOMPARE(QGuiApplication::font().pointSizeF(), before.pointSizeF());
        QCOMPARE(QGuiApplication::font().pixelSize(), before.pixelSize());
    }

    void allWeightsAreBundled()
    {
        QVERIFY(redesign::installAppFont());

        QVERIFY(QFontDatabase::families().contains(QStringLiteral("Inter")));
        const QStringList styles = QFontDatabase::styles(QStringLiteral("Inter"));
        QVERIFY2(styles.contains(QStringLiteral("Regular")), qPrintable(styles.join(',')));
        QVERIFY2(styles.contains(QStringLiteral("Medium")), qPrintable(styles.join(',')));
        QVERIFY2(styles.contains(QStringLiteral("SemiBold")), qPrintable(styles.join(',')));
    }

    void missingFileKeepsSystemFont()
    {
        const QFont before = QGuiApplication::font();

        QTest::ignoreMessage(QtWarningMsg, QRegularExpression("redesign: failed to load font"));
        QVERIFY(!redesign::installAppFont(
            {QStringLiteral(":/redesign/fonts/Inter-Regular.ttf"),
             QStringLiteral(":/redesign/fonts/does-not-exist.ttf")},
            QStringLiteral("Inter")));

        QCOMPARE(QGuiApplication::font(), before);
    }

    void wrongFamilyKeepsSystemFont()
    {
        const QFont before = QGuiApplication::font();

        QTest::ignoreMessage(QtWarningMsg, QRegularExpression("does not provide the family"));
        QVERIFY(!redesign::installAppFont(
            {QStringLiteral(":/redesign/fonts/Inter-Regular.ttf")},
            QStringLiteral("NotInter")));

        QCOMPARE(QGuiApplication::font(), before);
    }
};

int main(int argc, char* argv[])
{
#if defined(QT_STATIC) && defined(Q_OS_WIN)
    // no offscreen platform plugin in the static win64 Qt; the native one
    // creates no window here, it only provides the font database
    qputenv("QT_QPA_PLATFORM", "windows");
#endif
    QGuiApplication app(argc, argv);
    TestRedesignFont test;
    return QTest::qExec(&test, argc, argv);
}
#include "test_redesign_font.moc"
