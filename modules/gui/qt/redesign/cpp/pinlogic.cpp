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

#include "pinlogic.hpp"

#include <vlc_common.h>
#include <vlc_input_item.h>
#include <vlc_media_source.h>

namespace pinlogic
{

std::optional<DirectoryTree> makeDirectoryTree(const QUrl& url, const QString& name)
{
    if (!url.isValid() || url.isEmpty())
        return std::nullopt;

    // same construction as StandardPathModel (network/standardpathmodel.cpp, addItem)
    const QByteArray mrl = url.toString().toUtf8();
    const QByteArray label = name.toUtf8();
    input_item_t* inputItem = input_item_NewDirectory(mrl.constData(), label.constData(), ITEM_LOCAL);
    if (!inputItem)
        return std::nullopt;

    DirectoryTree result;
    result.item = SharedInputItem(inputItem, false);

    vlc_media_tree_t* tree = vlc_media_tree_New();
    if (!tree)
        return std::nullopt;
    result.tree = MediaTreePtr(tree, false);
    {
        MediaTreeLocker lock{result.tree};
        vlc_media_tree_Add(result.tree.get(), &(result.tree->root), inputItem);
    }
    return result;
}

std::optional<MLItemId> parseMlItemId(const QString& serialized)
{
    const MLItemId id = MLItemId::fromString(QStringView(serialized));
    if (!id.isValid())
        return std::nullopt;
    return id;
}

}
