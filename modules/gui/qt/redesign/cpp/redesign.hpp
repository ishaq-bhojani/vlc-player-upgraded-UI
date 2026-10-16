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
#ifndef VLC_QT_REDESIGN_HPP
#define VLC_QT_REDESIGN_HPP

#include <vlc_common.h>

namespace redesign
{

/**
 * Returns whether the VLC Reborn redesign is enabled (the "qt-redesign"
 * option, true by default). Every redesign behaviour is gated by this.
 */
bool isEnabled(vlc_object_t* obj);

} // namespace redesign

#endif // VLC_QT_REDESIGN_HPP
