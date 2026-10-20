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

#include "measuredgainvlc.hpp"

#include <atomic>
#include <cstdlib>

#include <QByteArray>

#include <vlc_common.h>
#include <vlc_aout.h>
#include <vlc_configuration.h>
#include <vlc_input_item.h>
#include <vlc_player.h>
#include <vlc_replay_gain.h>
#include <vlc_variables.h>

namespace redesign
{

namespace
{

//! the variable of the audio output that carries the gain (see measuredgainvlc.hpp)
constexpr const char* kGainVar = "gain";
constexpr const char* kModeVar = "audio-replay-gain-mode";

//! Gives the audio output its own gain back. Always looks at the output (a variable lookup): no
//! flag decides whether there is something to clear, because a flag consumed by the media change
//! before the variable exists would leave a variable created after it behind. Safe from any
//! thread (the variables are locked); the player is not needed to be locked for
//! vlc_player_aout_Hold().
void clearGain(vlc_player_t* player)
{
    audio_output_t* aout = vlc_player_aout_Hold(player);
    if (!aout)
        return;
    if (var_Type(aout, kGainVar) != 0) {
        var_Destroy(aout, kGainVar);
        var_TriggerCallback(aout, kModeVar);
    }
    aout_Release(aout);
}

class VlcMeasuredGainBackend final : public MeasuredGainBackend
{
public:
    VlcMeasuredGainBackend(vlc_player_t* player, vlc_object_t* obj)
        : m_player(player)
        , m_obj(obj)
    {
        static const struct vlc_player_cbs cbs = [] {
            struct vlc_player_cbs c = {};
            c.on_current_media_changed = onCurrentMediaChanged;
            return c;
        }();
        vlc_player_Lock(m_player);
        m_listener = vlc_player_AddListener(m_player, &cbs, this);
        vlc_player_Unlock(m_player);
        if (!m_listener)
            // vlc_object_Log with a module name: msg_Warn needs the vlc_module_name of a plugin, which
            // the unit test of this file (an executable) does not have
            vlc_object_Log(m_obj, VLC_MSG_WARN, "redesign", __FILE__, __LINE__, __func__,
                    "measured loudness: cannot listen to the player; the gain of a track is taken "
                    "back by the next refresh of the media instead of at once");
    }

    ~VlcMeasuredGainBackend() override
    {
        vlc_player_Lock(m_player);
        if (m_listener)
            vlc_player_RemoveListener(m_player, m_listener);
        vlc_player_Unlock(m_player);
    }

    Media currentMedia() override
    {
        Media media;
        vlc_player_Lock(m_player);
        if (input_item_t* item = vlc_player_GetCurrentMedia(m_player)) {
            if (char* uri = input_item_GetURI(item)) {
                media.url = QUrl(QString::fromUtf8(uri)); // as PlayerController.url does
                free(uri);
            }
            // the tags of the file
            vlc_mutex_lock(&item->lock);
            audio_replay_gain_t rg = {};
            if (item->p_meta)
                vlc_replay_gain_CopyFromMeta(&rg, item->p_meta);
            vlc_mutex_unlock(&item->lock);
            media.tags.trackGain = rg.pb_gain[AUDIO_REPLAY_GAIN_TRACK];
            media.tags.albumGain = rg.pb_gain[AUDIO_REPLAY_GAIN_ALBUM];

            // what the demuxer put on the audio stream (an MP3 header, an MP4 atom, FLAC...)
            const size_t tracks = vlc_player_GetAudioTrackCount(m_player);
            for (size_t i = 0; i < tracks; ++i) {
                const struct vlc_player_track* track = vlc_player_GetAudioTrackAt(m_player, i);
                if (track && track->selected) {
                    media.tags.trackGain |= track->fmt.audio_replay_gain.pb_gain[AUDIO_REPLAY_GAIN_TRACK];
                    media.tags.albumGain |= track->fmt.audio_replay_gain.pb_gain[AUDIO_REPLAY_GAIN_ALBUM];
                }
            }
        }
        const enum vlc_player_state state = vlc_player_GetState(m_player);
        media.settled = state == VLC_PLAYER_STATE_PLAYING || state == VLC_PLAYER_STATE_PAUSED;
        vlc_player_Unlock(m_player);
        return media;
    }

    MeasuredGainSettings settings() override
    {
        MeasuredGainSettings s;
        char* mode = nullptr;
        if (audio_output_t* aout = vlc_player_aout_Hold(m_player)) {
            // the mode in use: the output reads its own variable, made from the configuration
            // when it was created
            mode = var_GetString(aout, kModeVar);
            aout_Release(aout);
        }
        if (!mode)
            mode = var_InheritString(m_obj, kModeVar);
        if (mode) {
            s.mode = QString::fromUtf8(mode);
            free(mode);
        }
        s.preampDb = var_InheritFloat(m_obj, "audio-replay-gain-preamp");
        s.defaultGainDb = var_InheritFloat(m_obj, "audio-replay-gain-default");
        s.peakProtection = var_InheritBool(m_obj, "audio-replay-gain-peak-protection");
        s.userGain = var_InheritFloat(m_obj, kGainVar);
        return s;
    }

    void setReplayGainMode(const QString& mode) override
    {
        const QByteArray value = mode.toUtf8();
        config_PutPsz(kModeVar, value.constData());
        config_SaveConfigFile(m_obj);
        // the running output keeps the value it was created with: tell it, which also
        // computes the gain of what plays again
        if (audio_output_t* aout = vlc_player_aout_Hold(m_player)) {
            var_SetString(aout, kModeVar, value.constData());
            aout_Release(aout);
        }
    }

    void setOutputGain(std::optional<float> factor) override
    {
        if (!factor) {
            clearGain(m_player);
            return;
        }
        audio_output_t* aout = vlc_player_aout_Hold(m_player);
        if (!aout)
            return;
        // If a media change on the player thread runs before the variable exists, it clears nothing
        // and the gain set below plays on the new media until the refresh that the change of media
        // causes (MeasuredGain::refresh(), from PlayerController::inputChanged) takes it back. That
        // refresh is the self-heal, and it works because the clear never depends on a flag: it
        // always removes the variable if there is one.
        if (var_Type(aout, kGainVar) == 0) {
            // DOINHERIT: the variable is born with the value the option has (the user's own gain),
            // not with 0.0, which would mute the output if the decoder triggers the replay gain
            // between the creation and the set below
            var_Create(aout, kGainVar, VLC_VAR_FLOAT | VLC_VAR_DOINHERIT);
        }
        var_SetFloat(aout, kGainVar, *factor);
        var_TriggerCallback(aout, kModeVar);
        aout_Release(aout);
    }

    std::optional<float> outputGain() override
    {
        std::optional<float> value;
        if (audio_output_t* aout = vlc_player_aout_Hold(m_player)) {
            if (var_Type(aout, kGainVar) != 0)
                value = float(var_GetFloat(aout, kGainVar));
            aout_Release(aout);
        }
        return value;
    }

private:
    //! player thread, player locked, before the new input exists: the gain of the track that
    //! ends does not stay for the next one
    static void onCurrentMediaChanged(vlc_player_t* player, input_item_t*, void* data)
    {
        (void)data;
        clearGain(player);
    }

    vlc_player_t* m_player;
    vlc_object_t* m_obj;
    vlc_player_listener_id* m_listener = nullptr;
};

} // namespace

std::unique_ptr<MeasuredGainBackend> makeVlcMeasuredGainBackend(vlc_player_t* player, vlc_object_t* obj)
{
    return std::make_unique<VlcMeasuredGainBackend>(player, obj);
}

} // namespace redesign
