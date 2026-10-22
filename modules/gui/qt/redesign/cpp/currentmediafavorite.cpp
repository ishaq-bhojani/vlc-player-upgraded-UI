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
#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include "currentmediafavorite.hpp"

#include <QUrl>

namespace
{
CurrentMediaFavorite::BackendFactory& defaultFactory()
{
    static CurrentMediaFavorite::BackendFactory factory;
    return factory;
}
}

void CurrentMediaFavorite::setDefaultBackendFactory(BackendFactory factory)
{
    defaultFactory() = std::move(factory);
}

CurrentMediaFavorite::CurrentMediaFavorite(QObject* parent)
    : QObject(parent)
{
    if (defaultFactory())
        m_backend = defaultFactory()();
}

void CurrentMediaFavorite::setBackend(std::unique_ptr<FavoriteBackend> backend)
{
    m_backend = std::move(backend);
    refresh();
}

void CurrentMediaFavorite::setMrl(const QString& mrl)
{
    if (mrl == m_mrl)
        return;
    m_mrl = mrl;
    emit mrlChanged();
    refresh();
}

void CurrentMediaFavorite::setState(bool available, bool favorite)
{
    if (available == m_available && favorite == m_favorite)
        return;
    m_available = available;
    m_favorite = favorite;
    emit stateChanged();
}

// forgets the answers still in flight and asks the backend about the current mrl
void CurrentMediaFavorite::refresh()
{
    const quint64 generation = ++m_generation;
    m_setPending = false;
    setState(false, false);

    if (!m_backend || m_mrl.isEmpty())
        return;

    // only local files can be in the library as such; streams (http, rtsp, ...) never are
    if (QUrl(m_mrl).scheme().compare(QLatin1String("file"), Qt::CaseInsensitive) != 0)
        return;

    m_backend->lookup(m_mrl, [this, generation](std::optional<bool> favorite)
    {
        if (generation != m_generation)
            return;
        setState(favorite.has_value(), favorite.value_or(false));
    });
}

void CurrentMediaFavorite::toggle()
{
    // one change at a time: a click while the previous one is in flight is dropped
    if (!m_available || !m_backend || m_setPending)
        return;

    const bool wanted = !m_favorite;
    const quint64 generation = m_generation;

    m_setPending = true;
    setState(true, wanted);

    m_backend->set(m_mrl, wanted, [this, generation, wanted](bool ok)
    {
        if (generation != m_generation)
            return;
        m_setPending = false;
        if (!ok)
            setState(true, !wanted);
    });
}
