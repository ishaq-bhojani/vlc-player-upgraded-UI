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
#ifndef VLC_QT_REDESIGN_QMLREGISTRATION_HPP
#define VLC_QT_REDESIGN_QMLREGISTRATION_HPP

class MainCtx;

namespace redesign
{

/**
 * Registers the types of the "VLC.Redesign" QML module and sets up the
 * redesign factories that need the main context (e.g. the favorite backend of
 * the media library, only when one is loaded). Called by MainUI::registerQMLTypes
 * after the stock modules were registered.
 */
void registerQmlTypes(MainCtx* ctx);

/**
 * Undoes what registerQmlTypes set up outside of the QML type registry. Called
 * by MainUI::clearQMLTypes before the registrations are cleared.
 */
void clearQmlTypes();

} // namespace redesign

#endif
