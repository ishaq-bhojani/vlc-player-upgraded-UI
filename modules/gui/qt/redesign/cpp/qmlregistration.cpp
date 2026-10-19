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

#include "qmlregistration.hpp"

#include <memory>

#include <QQmlEngine>
#include <QJSEngine>

#include "currentmediafavorite.hpp"
#include "effectscontroller.hpp"
#include "mlfavoritebackend.hpp"
#include "mlrecentaudiomodel.hpp"
#include "pinnavigation.hpp"
#include "settingsmodel.hpp"

#include "../../maininterface/mainctx.hpp"
#include "../../qt.hpp"

namespace redesign
{

/*
 * Every C++ type of the "VLC.Redesign" module 1.0, in registration order:
 *   CurrentMediaFavorite   creatable type (Favorite control-bar item)
 *   MLRecentAudioModel     creatable type ("Listen Again" row of Home)
 *   Effects                singleton, EffectsController (live audio/video effects)
 *   PinNavigation          singleton (rail pin navigation helpers)
 *   SettingItem            uncreatable, returned by RedesignSettings.item()
 *   RedesignSettings       singleton, SettingsModel (not "Settings": that would
 *                          clash with QtCore.Settings)
 * plus, only when the interface has a media library, the default backend
 * factory of CurrentMediaFavorite (MLFavoriteBackend), and the
 * qmlRegisterModule/qmlProtectModule pair of the URI.
 * New redesign C++ types are registered here, never in mainui.cpp.
 */
void registerQmlTypes(MainCtx* ctx)
{
    qt_intf_t* intf = ctx->getIntf();

    const char* uri = "VLC.Redesign";
    const int versionMajor = 1;
    const int versionMinor = 0;

    // @uri VLC.Redesign
    qmlRegisterType<CurrentMediaFavorite>(uri, versionMajor, versionMinor, "CurrentMediaFavorite");
    qmlRegisterType<MLRecentAudioModel>(uri, versionMajor, versionMinor, "MLRecentAudioModel");
    qmlRegisterSingletonType<EffectsController>(uri, versionMajor, versionMinor, "Effects",
        [intf](QQmlEngine*, QJSEngine*) { return new EffectsController(intf->p_player, VLC_OBJECT(intf)); });
    qmlRegisterSingletonType<PinNavigation>(uri, versionMajor, versionMinor, "PinNavigation",
        [](QQmlEngine*, QJSEngine*) { return new PinNavigation; });
    // not "Settings": that would clash with QtCore.Settings
    qmlRegisterUncreatableType<SettingItem>(uri, versionMajor, versionMinor, "SettingItem",
        "SettingItem is returned by RedesignSettings.item()");
    qmlRegisterSingletonType<SettingsModel>(uri, versionMajor, versionMinor, "RedesignSettings",
        [intf](QQmlEngine*, QJSEngine*) { return new SettingsModel(VLC_OBJECT(intf)); });
    if (ctx->hasMediaLibrary()) {
        CurrentMediaFavorite::setDefaultBackendFactory([ml = ctx->getMediaLibrary()] {
            return std::make_unique<MLFavoriteBackend>(ml);
        });
    }

    qmlRegisterModule(uri, versionMajor, versionMinor);
    qmlProtectModule(uri, versionMajor);
}

void clearQmlTypes()
{
    CurrentMediaFavorite::setDefaultBackendFactory({});
}

} // namespace redesign
