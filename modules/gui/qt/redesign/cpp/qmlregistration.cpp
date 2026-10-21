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
#include <QWindow>
#include <QJSEngine>

#include "currentmediafavorite.hpp"
#include "effectscontroller.hpp"
#include "measuredgain.hpp"
#include "measuredgainvlc.hpp"
#include "mlfavoritebackend.hpp"
#include "mlrecentaudiomodel.hpp"
#include "mlsubtitlestore.hpp"
#include "pinnavigation.hpp"
#include "settingsbridge.hpp"
#include "settingsmodel.hpp"
#include "shortcutsmodel.hpp"
#include "sidecarlyrics.hpp"
#include "subtitleattacher.hpp"
#include "subtitleattachervlc.hpp"
#include "toolmanagervlc.hpp"
#include "waveform.hpp"
#include "waveformvlc.hpp"

#include "../../maininterface/mainctx.hpp"
#include "../../player/player_controller.hpp"
#include "../../qt.hpp"

namespace redesign
{

// ControlChooser.qml (redesign/settings) mirrors SettingItem::Type as numbers: keep them in step
static_assert(SettingItem::Bool == 0 && SettingItem::Integer == 1 && SettingItem::Float == 2
              && SettingItem::String == 3 && SettingItem::Choice == 4 && SettingItem::Path == 5
              && SettingItem::Hotkey == 6,
              "SettingItem::Type changed: update ControlChooser.type in redesign/settings/ControlChooser.qml");

namespace
{

/**
 * The measured loudness of this interface: made once (a child of the MainCtx), wired to the
 * player controller. It decides again when the media, the state or the metadata of the player
 * change. Only created for the redesign (see registerQmlTypes); never in mainui.cpp.
 */
MeasuredGain* measuredGainOf(MainCtx* ctx)
{
    if (MeasuredGain* existing = ctx->findChild<MeasuredGain*>(QString(), Qt::FindDirectChildrenOnly))
        return existing;

    qt_intf_t* intf = ctx->getIntf();
    auto* measured = new MeasuredGain(makeVlcMeasuredGainBackend(intf->p_player, VLC_OBJECT(intf)),
                                      makeVlcWaveformEnvironment(VLC_OBJECT(intf)), nullptr, ctx);
    if (PlayerController* player = intf->p_mainPlayerController) {
        QObject::connect(player, &PlayerController::inputChanged, measured, &MeasuredGain::refresh);
        QObject::connect(player, &PlayerController::playingStateChanged, measured, &MeasuredGain::refresh);
        QObject::connect(player, &PlayerController::currentMetaChanged, measured, &MeasuredGain::refresh);
        QObject::connect(player, &PlayerController::infoChanged, measured, &MeasuredGain::refresh);
    }
    measured->refresh();
    return measured;
}

/**
 * The subtitle tools of this interface: made once (a child of the MainCtx), wired to the player
 * controller, so that the subtitles saved in the media library for a media are added to it
 * whenever it starts, with no QML that mentions the type. The library store only exists when the
 * interface has a media library. Only created for the redesign (see registerQmlTypes); never in
 * mainui.cpp.
 */
SubtitleAttacher* subtitleAttacherOf(MainCtx* ctx)
{
    if (SubtitleAttacher* existing = ctx->findChild<SubtitleAttacher*>(QString(), Qt::FindDirectChildrenOnly))
        return existing;

    qt_intf_t* intf = ctx->getIntf();
    auto* attacher = new SubtitleAttacher(ctx);
    attacher->setEnvironment(makeVlcSubtitleEnvironment(intf));
    if (ctx->hasMediaLibrary())
        attacher->setStore(std::make_unique<MLSubtitleStore>(ctx->getMediaLibrary()));

    if (PlayerController* player = intf->p_mainPlayerController) {
        QObject::connect(player, &PlayerController::inputChanged, attacher, [attacher, player](bool hasInput) {
            attacher->onInputChanged(hasInput, hasInput ? QString::fromUtf8(player->getUrl().toEncoded()) : QString());
        });
        // the saved subtitles are added once the media plays: its input has loaded the slaves of its item
        QObject::connect(player, &PlayerController::playingStateChanged, attacher,
                         [attacher](PlayerController::PlayingState state) {
            if (state == PlayerController::PLAYING_STATE_PLAYING || state == PlayerController::PLAYING_STATE_PAUSED)
                attacher->onPlaying();
        });
        if (!player->getUrl().isEmpty()) {
            attacher->onInputChanged(true, QString::fromUtf8(player->getUrl().toEncoded()));
            const PlayerController::PlayingState state = player->getPlayingState();
            if (state == PlayerController::PLAYING_STATE_PLAYING || state == PlayerController::PLAYING_STATE_PAUSED)
                attacher->onPlaying();
        }
    }
    return attacher;
}

} // namespace

/*
 * Every C++ type of the "VLC.Redesign" module 1.0, in registration order:
 *   CurrentMediaFavorite   creatable type (Favorite control-bar item)
 *   MLRecentAudioModel     creatable type ("Listen Again" row of Home)
 *   SidecarLyrics          creatable type (the .lrc file next to a local audio file)
 *   Effects                singleton, EffectsController (live audio/video effects)
 *   PinNavigation          singleton (rail pin navigation helpers)
 *   SettingItem            uncreatable, returned by RedesignSettings.item()
 *   RedesignSettings       singleton, SettingsModel (not "Settings": that would
 *                          clash with QtCore.Settings)
 *   SettingsBridge         singleton, the color scheme and the key strings of the settings
 *                          modal (what QML can not reach in the upstream code)
 *   ShortcutsModel         singleton, the keyboard shortcuts page (call reload() when it opens)
 *   SubtitleAttacher       singleton, subtitle files added to the playing media and the queue, saved
 *                          in the media library and brought back at playback; also created at start
 *                          when the redesign is on (the playback listener must work with no QML that
 *                          mentions it, a child of MainCtx)
 *   ToolManager            singleton, verified yt-dlp / ffmpeg downloads (consent, pinned manifest)
 *   WaveformProvider       creatable type, the peaks of a file:// url (seek bar waveform, loudness)
 *   MeasuredGain           singleton, the measured loudness (Settings > Audio > Replay gain
 *                          "Measured"); also created at start when the redesign is on, because it
 *                          must work with no QML that mentions it (a child of MainCtx)
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
    qmlRegisterType<SidecarLyrics>(uri, versionMajor, versionMinor, "SidecarLyrics");
    qmlRegisterSingletonType<EffectsController>(uri, versionMajor, versionMinor, "Effects",
        [intf](QQmlEngine*, QJSEngine*) { return new EffectsController(intf->p_player, VLC_OBJECT(intf)); });
    qmlRegisterSingletonType<PinNavigation>(uri, versionMajor, versionMinor, "PinNavigation",
        [](QQmlEngine*, QJSEngine*) { return new PinNavigation; });
    // not "Settings": that would clash with QtCore.Settings
    qmlRegisterUncreatableType<SettingItem>(uri, versionMajor, versionMinor, "SettingItem",
        "SettingItem is returned by RedesignSettings.item()");
    qmlRegisterSingletonType<SettingsModel>(uri, versionMajor, versionMinor, "RedesignSettings",
        [intf](QQmlEngine*, QJSEngine*) { return new SettingsModel(VLC_OBJECT(intf)); });
    qmlRegisterSingletonType<SettingsBridge>(uri, versionMajor, versionMinor, "SettingsBridge",
        [ctx](QQmlEngine*, QJSEngine*) {
            return new SettingsBridge(ctx->getColorScheme(), [ctx] {
                return ctx->property("intfMainWindow").value<QWindow*>();
            });
        });
    qmlRegisterSingletonType<ShortcutsModel>(uri, versionMajor, versionMinor, "ShortcutsModel",
        [intf](QQmlEngine*, QJSEngine*) { return new ShortcutsModel(VLC_OBJECT(intf)); });
    qmlRegisterSingletonType<SubtitleAttacher>(uri, versionMajor, versionMinor, "SubtitleAttacher",
        [ctx](QQmlEngine*, QJSEngine*) {
            SubtitleAttacher* attacher = subtitleAttacherOf(ctx);
            QQmlEngine::setObjectOwnership(attacher, QQmlEngine::CppOwnership);
            return attacher;
        });
    qmlRegisterSingletonType<ToolManager>(uri, versionMajor, versionMinor, "ToolManager",
        [intf](QQmlEngine*, QJSEngine*) { return createToolManager(VLC_OBJECT(intf)); });
    WaveformProvider::setDefaultEnvironment([intf] { return makeVlcWaveformEnvironment(VLC_OBJECT(intf)); });
    qmlRegisterType<WaveformProvider>(uri, versionMajor, versionMinor, "WaveformProvider");
    qmlRegisterSingletonType<MeasuredGain>(uri, versionMajor, versionMinor, "MeasuredGain",
        [ctx](QQmlEngine*, QJSEngine*) {
            MeasuredGain* measured = measuredGainOf(ctx);
            QQmlEngine::setObjectOwnership(measured, QQmlEngine::CppOwnership);
            return measured;
        });
    if (ctx->isRedesign()) {
        measuredGainOf(ctx);
        subtitleAttacherOf(ctx);
    }
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
    WaveformProvider::setDefaultEnvironment({});
}

} // namespace redesign
