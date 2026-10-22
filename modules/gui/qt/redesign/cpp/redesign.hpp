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
#ifndef VLC_QT_REDESIGN_HPP
#define VLC_QT_REDESIGN_HPP

#include <vlc_common.h>

#include <QString>
#include <QUrl>
#include <QStringList>

namespace redesign
{

/**
 * Returns whether the Vireo redesign is enabled (the "qt-redesign"
 * option, true by default). Every redesign behaviour is gated by this.
 */
bool isEnabled(vlc_object_t* obj);

/**
 * What the first run (option "qt-privacy-ask") shows: the QWidgets wizard of
 * the stock interface, or the onboarding of the redesign.
 */
enum class FirstRun
{
    Stock,
    Onboarding,
};

/**
 * The first run to show for the redesign being enabled or not. The wizard has
 * a Modern/Classic layout page that makes no sense in the redesign, so the
 * redesign never gets it.
 */
FirstRun firstRunFor(bool redesignEnabled);

/**
 * Whether the interface follows the layout options of the stock interface (qt-menubar,
 * qt-titlebar, qt-pin-controls). The redesign does not: a profile shared with a stock run can
 * hold "Classic" there, and the shell has its own layout.
 */
bool readsStockLayoutOptions(bool redesignEnabled);

/**
 * URL of the root QML item of the interface: the redesign root window if
 * enabled, else the stock MainInterface.qml.
 */
QUrl rootQmlUrl(bool enabled);

/**
 * Loads the bundled redesign font (Inter Regular, Medium and SemiBold from
 * the ":/redesign/fonts" resources) and makes it the application font, keeping
 * the size of the current application font. Needs a QGuiApplication.
 *
 * Returns false (after logging) and leaves the application font untouched if
 * any file fails to load or does not provide the expected family.
 */
bool installAppFont();

/**
 * Same as installAppFont(), for the given font files and family. Exposed so
 * the failure path can be tested.
 */
bool installAppFont(const QStringList& fontFiles, const QString& family);

} // namespace redesign

#endif // VLC_QT_REDESIGN_HPP
