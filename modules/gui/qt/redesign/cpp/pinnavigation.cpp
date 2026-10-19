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

#include "pinnavigation.hpp"
#include "pinlogic.hpp"

QVariant PinNavigation::mlItemId(const QString& serialized) const
{
    const auto id = pinlogic::parseMlItemId(serialized);
    if (!id)
        return {};
    return QVariant::fromValue(*id);
}

QString PinNavigation::serializeMlItemId(const QVariant& id) const
{
    if (!id.canConvert<MLItemId>())
        return {};
    const MLItemId item = id.value<MLItemId>();
    return item.isValid() ? item.toString() : QString();
}
