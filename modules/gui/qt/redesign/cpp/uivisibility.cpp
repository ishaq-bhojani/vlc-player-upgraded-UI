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
# include "config.h"
#endif

#include "uivisibility.hpp"

UiVisibility::UiVisibility(QObject* parent)
    : QObject(parent)
{
}

UiVisibility* UiVisibility::instance()
{
    // created on first use, lives until the process ends (QML holds it with CppOwnership)
    static UiVisibility* const shared = new UiVisibility();
    return shared;
}

void UiVisibility::setHidden(bool hidden)
{
    if (m_hidden == hidden)
        return;
    m_hidden = hidden;
    emit hiddenChanged(m_hidden);
}

void UiVisibility::toggle()
{
    setHidden(!m_hidden);
}
