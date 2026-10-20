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
#ifndef REDESIGN_WAVEFORMVLC_HPP
#define REDESIGN_WAVEFORMVLC_HPP

#include <memory>

#include "waveform.hpp"

struct vlc_object_t;

namespace redesign
{

/**
 * The decoder of the application. It plays the file in a private vlc_player of libvlccore whose
 * stream output is `transcode{acodec=s16l,channels=1,samplerate=8000}` into the `smem` module
 * (no temp file; no-time-sync, so it decodes as fast as the CPU allows instead of in real time).
 * With a stream output the player opens neither an audio nor a video output (and its audio
 * output module is forced to the dummy one), so nothing is played or shown. decode() blocks
 * the calling worker thread, and ends the playback when the token is cancelled.
 */
std::unique_ptr<WaveformDecoder> makeVlcWaveformDecoder(vlc_object_t* obj);

//! the environment of the application: the cache in <user data dir>/vlc-reborn/waveforms
//! and the decoder above. Without a user data directory there is no cache.
WaveformEnvironment makeVlcWaveformEnvironment(vlc_object_t* obj);

} // namespace redesign

#endif
