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

#include "subtitleattachervlc.hpp"

#include <cstdlib>

#include <vlc_common.h>
#include <vlc_es.h>
#include <vlc_input_item.h>
#include <vlc_player.h>
#include <vlc_playlist.h>

#include "../../player/player_controller.hpp"
#include "../../playlist/playlist_controller.hpp"
#include "../../qt.hpp"

namespace redesign
{

namespace
{

QString uriOf(input_item_t* media)
{
    char* uri = media ? input_item_GetURI(media) : nullptr;
    const QString text = uri ? QString::fromUtf8(uri) : QString();
    free(uri);
    return text;
}

} // namespace

SubtitleEnvironment makeVlcSubtitleEnvironment(qt_intf_t* intf)
{
    SubtitleEnvironment env;

    env.addToCurrent = [intf](const QString& mrl, bool select, bool notify)
    {
        PlayerController* player = intf->p_mainPlayerController;
        return player && player->AddAssociatedMedia(SPU_ES, mrl, select, notify, false) == VLC_SUCCESS;
    };

    env.queueUrls = [intf]()
    {
        QStringList urls;
        vlc_playlist_t* playlist = intf->p_playlist;
        if (!playlist)
            return urls;

        vlc::playlist::vlc_playlist_locker lock {playlist};
        const size_t count = vlc_playlist_Count(playlist);
        urls.reserve(static_cast<qsizetype>(count));
        for (size_t i = 0; i < count; ++i)
            urls.append(uriOf(vlc_playlist_item_GetMedia(vlc_playlist_Get(playlist, i))));
        return urls;
    };

    env.addToQueueItem = [intf](int index, const QString& mrl)
    {
        vlc_playlist_t* playlist = intf->p_playlist;
        if (!playlist || index < 0)
            return false;

        bool isCurrent = false;
        {
            // The slave belongs to the input item: the lock is only needed to reach the item.
            // The player is not called under it (the playlist and the player share their lock).
            vlc::playlist::vlc_playlist_locker lock {playlist};
            if (static_cast<size_t>(index) >= vlc_playlist_Count(playlist))
                return false;

            input_item_t* media = vlc_playlist_item_GetMedia(vlc_playlist_Get(playlist, index));
            input_item_slave_t* slave = input_item_slave_New(qtu(mrl), SLAVE_TYPE_SPU, SLAVE_PRIORITY_USER);
            if (!slave)
                return false;
            if (input_item_AddSlave(media, slave) != VLC_SUCCESS)
            {
                input_item_slave_Delete(slave);
                return false;
            }
            isCurrent = (media == vlc_player_GetCurrentMedia(vlc_playlist_GetPlayer(playlist)));
        }

        // the media is playing now: its input was created before the slave existed, so it is added to it
        // as well and shown (the user chose it)
        if (isCurrent)
            intf->p_mainPlayerController->AddAssociatedMedia(SPU_ES, mrl, true, true, false);
        return true;
    };

    return env;
}

} // namespace redesign
