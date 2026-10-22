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
#ifndef VLC_QT_REDESIGN_PINLOGIC_HPP
#define VLC_QT_REDESIGN_PINLOGIC_HPP

#include <optional>

#include <QString>
#include <QUrl>

#include "medialibrary/mlqmltypes.hpp"
#include "network/vlcmediasourcewrapper.hpp"
#include "util/shared_input_item.hpp"

/**
 * Plain C++ part of PinNavigation (no Qt meta-object types), so that it is unit tested.
 */
namespace pinlogic
{

//! a media tree whose only node is a directory, like the entries of StandardPathModel
struct DirectoryTree
{
    MediaTreePtr tree;
    SharedInputItem item;
};

/**
 * Tree of the directory `url` (named `name`) that the network browser can list.
 * `nullopt` for an empty or invalid url, or when the tree can not be created.
 */
std::optional<DirectoryTree> makeDirectoryTree(const QUrl& url, const QString& name);

//! `nullopt` when `serialized` (MLItemId::toString() format) is not a valid id
std::optional<MLItemId> parseMlItemId(const QString& serialized);

}

#endif
