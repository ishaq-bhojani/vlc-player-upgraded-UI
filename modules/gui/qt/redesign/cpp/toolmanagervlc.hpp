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
#ifndef REDESIGN_TOOLMANAGERVLC_HPP
#define REDESIGN_TOOLMANAGERVLC_HPP

#include <memory>

#include "toolmanager.hpp"

struct vlc_object_t;

namespace redesign
{

//! the ToolFetcher of the application: reads the https URL through VLC's stream layer
//! (its own TLS with certificate verification), on the calling worker thread
std::unique_ptr<ToolFetcher> makeVlcToolFetcher(vlc_object_t* obj);

//! the ToolManager of the application: bundled manifest, VLC fetcher, tools in
//! <user data dir>/vlc-reborn/tools. Returns nullptr when the user data directory is unknown.
ToolManager* createToolManager(vlc_object_t* obj);

} // namespace redesign

#endif
