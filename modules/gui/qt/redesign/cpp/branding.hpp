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
#ifndef VLC_QT_REDESIGN_BRANDING_HPP
#define VLC_QT_REDESIGN_BRANDING_HPP

#include <QString>

/*
 * Product name of the fork, from the meson option "redesign_product_name".
 * redesign/meson.build passes it to every target that includes this header
 * as -DREDESIGN_PRODUCT_NAME="...". There is deliberately no fallback value,
 * so a target that forgets the define fails to build instead of silently
 * showing another name. Values: docs/redesign/branding.md.
 */
#ifndef REDESIGN_PRODUCT_NAME
# error "REDESIGN_PRODUCT_NAME is not defined, see modules/gui/qt/redesign/meson.build"
#endif

namespace redesign
{

/**
 * Name of the product shown instead of "VLC media player" when the redesign
 * is enabled (window title, About, tray, update texts). Not translated.
 * Callers must only use it when redesign::isEnabled(); stock mode
 * (qt-redesign=false) keeps the upstream name.
 */
inline QString productName()
{
    return QString::fromUtf8(REDESIGN_PRODUCT_NAME);
}

/** Project website, also the source link of the About dialog. */
inline QString productWebsite()
{
    return QStringLiteral("https://github.com/ishaq-bhojani/vlc-player-upgraded-UI");
}

} // namespace redesign

#endif // VLC_QT_REDESIGN_BRANDING_HPP
