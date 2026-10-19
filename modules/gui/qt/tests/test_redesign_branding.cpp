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

#include <QTest>

#include "../redesign/cpp/branding.hpp"

class TestRedesignBranding : public QObject
{
    Q_OBJECT

private slots:
    void productName()
    {
        // default of the meson option redesign_product_name, see docs/redesign/branding.md
        QCOMPARE(redesign::productName(), QStringLiteral("VLC Reborn"));
    }

    void productWebsite()
    {
        QVERIFY(redesign::productWebsite().startsWith(QStringLiteral("https://")));
    }
};

QTEST_GUILESS_MAIN(TestRedesignBranding)
#include "test_redesign_branding.moc"
