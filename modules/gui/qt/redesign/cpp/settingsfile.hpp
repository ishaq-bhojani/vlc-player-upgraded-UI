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
#ifndef VLC_QT_REDESIGN_SETTINGSFILE_HPP
#define VLC_QT_REDESIGN_SETTINGSFILE_HPP

#ifdef HAVE_CONFIG_H
# include "config.h"   /* REDESIGN_USER_DIR_NAME */
#endif

/*
 * Organisation and application name of the QSettings file of the Qt interface.
 * On Windows the file is <config dir>/<organisation>/<application>.ini, and the
 * config dir is %APPDATA%/<meson option redesign_user_dir> (src/win32/dirs.c), so the
 * organisation is that folder name and the file never lands in a stock VLC's
 * %APPDATA%/vlc. Other platforms keep upstream's names. Every QSettings of the
 * interface (qt.cpp, profile_selector.cpp) must use these two.
 */
namespace redesign
{

#if defined(_WIN32) && defined(REDESIGN_USER_DIR_NAME)
inline constexpr const char settingsOrganization[] = REDESIGN_USER_DIR_NAME;
inline constexpr const char settingsApplication[] = REDESIGN_USER_DIR_NAME "-qt-interface";
#else
inline constexpr const char settingsOrganization[] = "vlc";
inline constexpr const char settingsApplication[] = "vlc-qt-interface";
#endif

} // namespace redesign

#endif // VLC_QT_REDESIGN_SETTINGSFILE_HPP
