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
#ifndef VLC_QT_REDESIGN_MLSUBTITLESTORE_HPP
#define VLC_QT_REDESIGN_MLSUBTITLESTORE_HPP

#include <QObject>
#include <QPointer>

#include "subtitleattacher.hpp"

class MediaLib;

/**
 * SubtitleStore on top of the media library: the subtitle files of a media are its files of type
 * VLC_ML_FILE_TYPE_SUBTITLE (vlc_ml_media_add_external_mrl writes them, vlc_ml_get_media reads
 * them). The work runs on the ML thread (MediaLib::runOnMLThread), the answers come back on the Qt
 * thread; the Qt thread never waits for the library.
 */
class MLSubtitleStore : public SubtitleStore
{
public:
    explicit MLSubtitleStore(MediaLib* ml);

    void subtitles(const QString& mrl, std::function<void(QStringList)> done) override;
    void add(const QString& mrl, const QString& subtitle, std::function<void(bool)> done) override;

private:
    QPointer<MediaLib> m_ml;
    // task owner: MediaLib does not run the UI callback of a destroyed owner,
    // so `done` is never called once this store is gone
    QObject m_owner;
};

#endif
