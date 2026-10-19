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
#ifndef VLC_QT_REDESIGN_PINNAVIGATION_HPP
#define VLC_QT_REDESIGN_PINNAVIGATION_HPP

#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariant>

/**
 * Builds the navigation properties that the upstream views expect for a pinned item, from
 * what PinStore stores (strings): the `tree` of the network browser and the `parentId` of
 * the playlist view. The QML singleton PinNavigation of VLC.Redesign.
 */
class PinNavigation : public QObject
{
    Q_OBJECT

public:
    explicit PinNavigation(QObject* parent = nullptr) : QObject(parent) {}

    /** `tree` for `History.push(["network", "browse"], {tree})`; invalid for an empty or invalid url. */
    Q_INVOKABLE static QVariant networkTree(const QUrl& url, const QString& name);

    /** `parentId` of the playlist view from the stored string; invalid when it is not an ML id. */
    Q_INVOKABLE static QVariant mlItemId(const QString& serialized);

    /** String to store in a playlist pin for an MLItemId (a model's `id` role); empty if invalid. */
    Q_INVOKABLE static QString serializeMlItemId(const QVariant& id);
};

#endif
