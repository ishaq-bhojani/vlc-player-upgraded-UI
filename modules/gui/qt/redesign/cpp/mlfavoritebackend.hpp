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
#ifndef VLC_QT_REDESIGN_MLFAVORITEBACKEND_HPP
#define VLC_QT_REDESIGN_MLFAVORITEBACKEND_HPP

#include <QObject>
#include <QPointer>

#include "currentmediafavorite.hpp"

class MediaLib;

/**
 * FavoriteBackend on top of the media library: lookups and writes run on the
 * ML thread (MediaLib::runOnMLThread), the answers come back on the Qt thread.
 */
class MLFavoriteBackend : public FavoriteBackend
{
public:
    explicit MLFavoriteBackend(MediaLib* ml);

    void lookup(const QString& mrl, std::function<void(std::optional<bool>)> done) override;
    void set(const QString& mrl, bool favorite, std::function<void(bool ok)> done) override;

private:
    QPointer<MediaLib> m_ml;
    // task owner: MediaLib does not run the UI callback of a destroyed owner,
    // so `done` is never called once this backend is gone
    QObject m_owner;
};

#endif
