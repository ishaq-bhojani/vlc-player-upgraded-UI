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
#include <QMetaObject>

#include "../medialibrary/mlqmltypes.hpp"
#include "../redesign/cpp/pinnavigation.hpp"

// PinNavigation::networkTree builds a NetworkTreeItem, which belongs to the network module that
// this test does not link: it is covered by test_redesign_pin_logic (the tree) and the build.
QVariant PinNavigation::networkTree(const QUrl&, const QString&) const
{
    return {};
}

/**
 * The methods are called through the QObject, like QML does with the singleton instance.
 */
class TestRedesignPinNavigation : public QObject
{
    Q_OBJECT

private slots:
    void invokablesAreRegistered()
    {
        PinNavigation nav;
        const QMetaObject* meta = nav.metaObject();
        QVERIFY(meta->indexOfMethod("networkTree(QUrl,QString)") >= 0);
        QVERIFY(meta->indexOfMethod("mlItemId(QString)") >= 0);
        QVERIFY(meta->indexOfMethod("serializeMlItemId(QVariant)") >= 0);
    }

    void mlItemIdRoundTrip()
    {
        PinNavigation nav;
        const QString stored = MLItemId(42, VLC_ML_PARENT_PLAYLIST).toString();

        QVariant id;
        QVERIFY(QMetaObject::invokeMethod(&nav, "mlItemId", Q_RETURN_ARG(QVariant, id),
                                          Q_ARG(QString, stored)));
        QVERIFY(id.isValid());
        QVERIFY(id.canConvert<MLItemId>());
        QCOMPARE(id.value<MLItemId>(), MLItemId(42, VLC_ML_PARENT_PLAYLIST));

        QString back;
        QVERIFY(QMetaObject::invokeMethod(&nav, "serializeMlItemId", Q_RETURN_ARG(QString, back),
                                          Q_ARG(QVariant, id)));
        QCOMPARE(back, stored);
    }

    void invalidInput()
    {
        PinNavigation nav;

        QVariant id = QVariant::fromValue(MLItemId(1, VLC_ML_PARENT_PLAYLIST));
        QVERIFY(QMetaObject::invokeMethod(&nav, "mlItemId", Q_RETURN_ARG(QVariant, id),
                                          Q_ARG(QString, "nonsense")));
        QVERIFY(!id.isValid());

        QString s = "x";
        QVERIFY(QMetaObject::invokeMethod(&nav, "serializeMlItemId", Q_RETURN_ARG(QString, s),
                                          Q_ARG(QVariant, QVariant())));
        QVERIFY(s.isEmpty());
        QVERIFY(QMetaObject::invokeMethod(&nav, "serializeMlItemId", Q_RETURN_ARG(QString, s),
                                          Q_ARG(QVariant, QVariant::fromValue(MLItemId()))));
        QVERIFY(s.isEmpty());
    }
};

QTEST_GUILESS_MAIN(TestRedesignPinNavigation)
#include "test_redesign_pin_navigation.moc"
