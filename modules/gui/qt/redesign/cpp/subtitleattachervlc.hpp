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
#ifndef VLC_QT_REDESIGN_SUBTITLEATTACHERVLC_HPP
#define VLC_QT_REDESIGN_SUBTITLEATTACHERVLC_HPP

#include "subtitleattacher.hpp"

struct qt_intf_t;

namespace redesign
{

/**
 * The player and the main play queue of the interface, as SubtitleAttacher needs them:
 *
 *  - addToCurrent: PlayerController::AddAssociatedMedia(SPU_ES, mrl, select, notify (the OSD
 *    message), false), the call the stock "Add subtitle file" uses. It fails while the player has
 *    no input.
 *  - queueUrls: the URI of every item of the main playlist, read with the playlist locked.
 *  - addToQueueItem: input_item_AddSlave(item, input_item_slave_New(mrl, SLAVE_TYPE_SPU,
 *    SLAVE_PRIORITY_USER)) on the input item of that playlist entry, which makes every later
 *    playback of the item load the file; when the item is the media being played now, the file is
 *    added to the player as well, and selected.
 */
SubtitleEnvironment makeVlcSubtitleEnvironment(qt_intf_t* intf);

} // namespace redesign

#endif
