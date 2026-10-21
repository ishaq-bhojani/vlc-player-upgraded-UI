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

#include "mlsubtitlestore.hpp"

#include <QUrl>

#include <vlc_media_library.h>

#include "mllibrarymedia.hpp"
#include "../../medialibrary/medialib.hpp"
#include "../../qt.hpp"

namespace
{
// reads and writes of the store run one after the other, so a lookup issued after a write
// never reads the files from before it
constexpr const char* mlQueue = "redesign-subtitle-store";

//! the saved subtitle files of a library media (its files of the subtitle type)
QStringList subtitleFilesOf(const vlc_ml_media_t* media)
{
    QStringList list;
    if (!media->p_files)
        return list;
    for (const vlc_ml_file_t& file : ml_range_iterate<vlc_ml_file_t>(media->p_files))
    {
        if (file.i_type == VLC_ML_FILE_TYPE_SUBTITLE && file.psz_mrl)
            list.append(QString::fromUtf8(file.psz_mrl));
    }
    return list;
}
}

MLSubtitleStore::MLSubtitleStore(MediaLib* ml)
    : m_ml(ml)
{
}

void MLSubtitleStore::subtitles(const QString& mrl, std::function<void(QStringList)> done)
{
    if (!m_ml)
    {
        done({});
        return;
    }

    struct Ctx
    {
        QStringList files;
    };

    // the ML callback only captures copies, never `this`
    m_ml->runOnMLThread<Ctx>(&m_owner,
    // ML thread
    [mrl](vlc_medialibrary_t* ml, Ctx& ctx)
    {
        const auto media = redesign::findLibraryMedia(ml, mrl);
        if (media)
            ctx.files = subtitleFilesOf(media.get());
    },
    // Qt thread
    [done = std::move(done)](quint64, Ctx& ctx)
    {
        done(ctx.files);
    },
    mlQueue);
}

void MLSubtitleStore::add(const QString& mrl, const QString& subtitle, std::function<void(bool)> done)
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
    [mrl, subtitle](vlc_medialibrary_t* ml, Ctx& ctx)
    {
        const auto media = redesign::findLibraryMedia(ml, mrl);
        if (!media)
            return;

        // already saved (in either spelling of the address): nothing to write
        const QByteArray wanted = QUrl(subtitle).toEncoded();
        for (const QString& saved : subtitleFilesOf(media.get()))
        {
            if (QUrl(saved).toEncoded() == wanted)
            {
                ctx.ok = true;
                return;
            }
        }

        ctx.ok = (vlc_ml_media_add_external_mrl(ml, media->i_id, qtu(subtitle),
                                                VLC_ML_FILE_TYPE_SUBTITLE) == VLC_SUCCESS);
    },
    // Qt thread
    [done = std::move(done)](quint64, Ctx& ctx)
    {
        done(ctx.ok);
    },
    mlQueue);
}
