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

#include "../redesign/cpp/branding.hpp"
#include "../redesign/cpp/settingsfile.hpp"

class TestRedesignBranding : public QObject
{
    Q_OBJECT

private slots:
    void productName()
    {
        // default of the meson option redesign_product_name, see docs/redesign/branding.md
        QCOMPARE(redesign::productName(), QStringLiteral("Vireo"));
    }

    void productWebsite()
    {
        QVERIFY(redesign::productWebsite().startsWith(QStringLiteral("https://")));
    }

    void releaseVersion()
    {
        // default of the meson option redesign_release_version
        QCOMPARE(redesign::releaseVersion(), QStringLiteral("0.1.0"));
    }

    void versionTitle()
    {
        // a development build (build number 0) shows no build number
        QCOMPARE(redesign::versionTitle(QStringLiteral("Vireo"), QStringLiteral("0.1.0"), 0),
                 QStringLiteral("Vireo 0.1.0"));
        QCOMPARE(redesign::versionTitle(QStringLiteral("Vireo"), QStringLiteral("0.1.0"), 3),
                 QStringLiteral("Vireo 0.1.0 (build 3)"));
    }

    void versionSuffix()
    {
        QCOMPARE(redesign::versionSuffix(QStringLiteral("0.1.0"), 0), QStringLiteral("0.1.0"));
        QCOMPARE(redesign::versionSuffix(QStringLiteral("0.1.0"), 3), QStringLiteral("0.1.0 (build 3)"));
    }

    void builtOnLine()
    {
        const QString format = QStringLiteral("Built on VLC media player %1");
        QCOMPARE(redesign::builtOnLine(format, QStringLiteral("4.0.0-dev Otto Chriek")),
                 QStringLiteral("Built on VLC media player 4.0.0-dev Otto Chriek"));
        QCOMPARE(redesign::builtOnLine(format, QString()), QStringLiteral("Built on VLC media player"));
    }

    void settingsFileNames()
    {
        // one pair for every QSettings of the interface; on Windows the organisation is the
        // per-user folder (REDESIGN_USER_DIR_NAME), never a stock VLC's "vlc"
        const QString org = QString::fromLatin1(redesign::settingsOrganization);
        QCOMPARE(QString::fromLatin1(redesign::settingsApplication), org + QStringLiteral("-qt-interface"));
#ifdef _WIN32
        QCOMPARE(org, QStringLiteral("vireo"));
#else
        QCOMPARE(org, QStringLiteral("vlc"));
#endif
    }
};

QTEST_GUILESS_MAIN(TestRedesignBranding)
#include "test_redesign_branding.moc"
