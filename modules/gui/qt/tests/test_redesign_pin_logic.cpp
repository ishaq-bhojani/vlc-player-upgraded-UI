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

#include <vlc_common.h>
#include <vlc_input_item.h>
#include <vlc_media_source.h>

#include "../redesign/cpp/pinlogic.hpp"

class TestRedesignPinLogic : public QObject
{
    Q_OBJECT

private slots:
    void emptyUrlHasNoTree()
    {
        QVERIFY(!pinlogic::makeDirectoryTree(QUrl(), "x"));
        QVERIFY(!pinlogic::makeDirectoryTree(QUrl(""), "x"));
    }

    void localDirectoryTree()
    {
        const auto directory = pinlogic::makeDirectoryTree(QUrl("file:///C:/x"), "Movies");
        QVERIFY(directory);
        QVERIFY(directory->tree);
        QVERIFY(directory->item);
        QCOMPARE(QString::fromUtf8(directory->item->psz_uri), QString("file:///C:/x"));
        QCOMPARE(QString::fromUtf8(directory->item->psz_name), QString("Movies"));
        QCOMPARE(int(directory->item->i_type), int(ITEM_TYPE_DIRECTORY));

        // the item is the only child of the root of the tree, as the network browser expects
        MediaTreePtr tree = directory->tree;
        MediaTreeLocker lock{tree};
        vlc_media_tree_t* t = tree.get();
        QCOMPARE(t->root.i_children, 1);
        QCOMPARE(t->root.pp_children[0]->p_item, directory->item.get());
    }

    void mlItemIdRoundTrip()
    {
        const MLItemId id(42, VLC_ML_PARENT_PLAYLIST);
        const auto parsed = pinlogic::parseMlItemId(id.toString());
        QVERIFY(parsed);
        QCOMPARE(*parsed, id);
        QCOMPARE(parsed->toString(), id.toString());
    }

    void invalidMlItemId()
    {
        QVERIFY(!pinlogic::parseMlItemId(""));
        QVERIFY(!pinlogic::parseMlItemId("42"));
        QVERIFY(!pinlogic::parseMlItemId("VLC_ML_PARENT_PLAYLIST - abc"));
        QVERIFY(!pinlogic::parseMlItemId("VLC_ML_PARENT_PLAYLIST - 0"));
        QVERIFY(!pinlogic::parseMlItemId("a - b - c"));
    }
};

QTEST_GUILESS_MAIN(TestRedesignPinLogic)
#include "test_redesign_pin_logic.moc"
