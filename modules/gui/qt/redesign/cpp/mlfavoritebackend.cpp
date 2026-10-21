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

#include "mlfavoritebackend.hpp"

#include <QByteArray>
#include <QUrl>

#include <vlc_media_library.h>

#include "../../medialibrary/medialib.hpp"
#include "../../medialibrary/mlhelper.hpp"
#include "../../qt.hpp"
#include "mllibrarymedia.hpp"

namespace
{
// lookups and writes of a backend run one after the other, so a lookup issued after a
// write never reads the flag from before it
constexpr const char* mlQueue = "redesign-current-media-favorite";

// Only a file of the library can be a favorite from here: redesign::findLibraryMedia (shared with
// the subtitle store) skips the rows made by Open Network and other external media.
ml_unique_ptr<vlc_ml_media_t> findMedia(vlc_medialibrary_t* ml, const QString& mrl)
{
    return redesign::findLibraryMedia(ml, mrl);
}
}

MLFavoriteBackend::MLFavoriteBackend(MediaLib* ml)
    : m_ml(ml)
{
}

void MLFavoriteBackend::lookup(const QString& mrl, std::function<void(std::optional<bool>)> done)
{
    if (!m_ml)
    {
        done(std::nullopt);
        return;
    }

    struct Ctx
    {
        std::optional<bool> favorite;
    };

    // the ML callback only captures copies, never `this`
    m_ml->runOnMLThread<Ctx>(&m_owner,
    // ML thread
    [mrl](vlc_medialibrary_t* ml, Ctx& ctx)
    {
        const auto media = findMedia(ml, mrl);
        if (media)
            ctx.favorite = media->b_is_favorite;
    },
    // Qt thread
    [done = std::move(done)](quint64, Ctx& ctx)
    {
        done(ctx.favorite);
    },
    mlQueue);
}

void MLFavoriteBackend::set(const QString& mrl, bool favorite, std::function<void(bool ok)> done)
{
    if (!m_ml)
    {
        done(false);
        return;
    }

    struct Ctx
    {
        bool ok = false;
    };

    m_ml->runOnMLThread<Ctx>(&m_owner,
    // ML thread
    [mrl, favorite](vlc_medialibrary_t* ml, Ctx& ctx)
    {
        const auto media = findMedia(ml, mrl);
        if (!media)
            return;
        ctx.ok = (vlc_ml_media_set_favorite(ml, media->i_id, favorite) == VLC_SUCCESS);
    },
    // Qt thread
    [done = std::move(done)](quint64, Ctx& ctx)
    {
        done(ctx.ok);
    },
    mlQueue);
}
