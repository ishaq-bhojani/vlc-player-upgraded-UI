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
#ifndef REDESIGN_MEASUREDGAINVLC_HPP
#define REDESIGN_MEASUREDGAINVLC_HPP

#include <memory>

#include "measuredgain.hpp"

struct vlc_object_t;
struct vlc_player_t;

namespace redesign
{

/**
 * The backend of the application: the player and its audio output.
 *
 * How a gain is applied (the spike of Task 57, checked in the VLC core):
 *  - The replay gain of a stream is computed by replay_gain_CalcMultiplier() (src/input/
 *    replay_gain.c) whenever the variable "audio-replay-gain-mode" of the audio output is
 *    triggered: `10^(gain/20) * var_InheritFloat(aout, "gain")`, where the replay gain is the
 *    stream's own (tags, set when the elementary stream is added: src/input/es_out.c) or, in the
 *    mode track/album and without any, "audio-replay-gain-default". It runs from the callback
 *    of src/audio_output/volume.c on the amplifier of every stream, at any time.
 *  - "gain" (the Audio gain option) is looked up from the audio output up through its parents to
 *    the configuration, so a "gain" variable on the audio output of the player overrides the
 *    option for that output only. Setting it and triggering "audio-replay-gain-mode" changes the
 *    gain of what plays NOW, without touching the volume of the user (a separate factor of the
 *    amplifier, aout_volume_SetVolume()) or the configuration.
 *  - The variable is removed (nothing is left behind) when the gain is taken back, and when the
 *    player switches to another media (on_current_media_changed, from the player thread, before
 *    the new stream is created), so a gain never plays on the next track.
 * The other candidate mechanisms do not do this: the tags of the input item
 * (REPLAYGAIN_TRACK_GAIN in the meta of the item) are read once, when the input adds its
 * elementary streams, so they could only be set before the media starts, which the analysis
 * (or even a cache read on a worker thread) can not promise; a per-input `:gain=` option is
 * an input variable that the audio output does not inherit.
 */
std::unique_ptr<MeasuredGainBackend> makeVlcMeasuredGainBackend(vlc_player_t* player, vlc_object_t* obj);

} // namespace redesign

#endif
