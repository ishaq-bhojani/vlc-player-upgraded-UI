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
#ifndef VLC_QT_REDESIGN_MLLIBRARYMEDIA_HPP
#define VLC_QT_REDESIGN_MLLIBRARYMEDIA_HPP

#include <QByteArray>
#include <QString>
#include <QUrl>

#include <vlc_media_library.h>

#include "../../medialibrary/mlhelper.hpp"
#include "../../qt.hpp"

namespace redesign
{

/**
 * Looks a file of the media library up by its address. To call on the ML thread only (it queries
 * the library).
 *
 * Only a file of the library counts: vlc_ml_get_media_by_mrl also matches the rows made by Open
 * Network (vlc_ml_new_stream) and other external media, whose files are all external. The ML
 * stores percent-encoded mrls, while the mrl may reach us as QUrl::toString() output of the player
 * URL (decoded spaces, ...): it is tried as given, then in its fully encoded form.
 *
 * Returns null when there is no such media or it is not a library file.
 */
inline ml_unique_ptr<vlc_ml_media_t> findLibraryMedia(vlc_medialibrary_t* ml, const QString& mrl)
{
    ml_unique_ptr<vlc_ml_media_t> media {vlc_ml_get_media_by_mrl(ml, qtu(mrl))};
    if (!media)
    {
        const QByteArray encoded = QUrl(mrl).toEncoded();
        if (!encoded.isEmpty() && encoded != mrl.toUtf8())
            media.reset(vlc_ml_get_media_by_mrl(ml, encoded.constData()));
    }
    if (!media)
        return media;

    if (media->p_files)
    {
        for (const vlc_ml_file_t& file : ml_range_iterate<vlc_ml_file_t>(media->p_files))
        {
            if (!file.b_external)
                return media;
        }
    }
    media.reset();
    return media;
}

} // namespace redesign

#endif
