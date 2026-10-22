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
# include <config.h>
#endif

#include "waveformvlc.hpp"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <vector>

#include <QUrl>

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_input_item.h>
#include <vlc_objects.h>
#include <vlc_player.h>
#include <vlc_variables.h>

namespace redesign
{

namespace
{

//! no sample for this long (the input is stuck): the decode fails
constexpr std::chrono::seconds kStallTimeout{60};

//! what the smem callbacks write to; they run on the input thread
struct Sink
{
    PeaksAccumulator* acc = nullptr;
    CancelToken* token = nullptr;
    std::vector<int16_t> buffer;
    std::atomic_bool bad{false};      //!< unexpected format, or the accumulator is full
    std::atomic<uint64_t> samples{0};
};

struct PlayerState
{
    CancelToken* token = nullptr;
    std::atomic_bool started{false};
    std::atomic_bool stopped{false};  //!< back to STOPPED after having been started
    std::atomic_bool error{false};
    std::atomic_bool tooLong{false};  //!< the reported length is above the cap
};

void prerender(void* data, uint8_t** pcm, size_t size)
{
    Sink* sink = static_cast<Sink*>(data);
    // never empty: smem treats a null buffer as an error, and a block can be empty
    sink->buffer.resize(std::max<size_t>((size + 1) / 2, 1));
    *pcm = reinterpret_cast<uint8_t*>(sink->buffer.data());
}

void postrender(void* data, uint8_t* pcm, unsigned channels, unsigned /*rate*/, unsigned samples,
                unsigned bitsPerSample, size_t /*size*/, vlc_tick_t /*pts*/)
{
    Sink* sink = static_cast<Sink*>(data);
    if (channels != 1 || bitsPerSample != 16) {
        sink->bad = true;
        sink->token->notify();
        return;
    }
    sink->acc->append(reinterpret_cast<const int16_t*>(pcm), samples);
    sink->samples += samples;
    if (sink->acc->exceeded()) {
        sink->bad = true;
        sink->token->notify();
    }
}

void onStateChanged(vlc_player_t*, enum vlc_player_state state, void* data)
{
    PlayerState* ps = static_cast<PlayerState*>(data);
    if (state != VLC_PLAYER_STATE_STOPPED)
        ps->started = true;
    else if (ps->started)
        ps->stopped = true;
    ps->token->notify();
}

void onErrorChanged(vlc_player_t*, enum vlc_player_error error, void* data)
{
    PlayerState* ps = static_cast<PlayerState*>(data);
    if (error != VLC_PLAYER_ERROR_NONE) {
        ps->error = true;
        ps->token->notify();
    }
}

void onLengthChanged(vlc_player_t*, vlc_tick_t length, void* data)
{
    // VLC_TICK_INVALID: unknown, the sample cap of the accumulator is the backstop
    PlayerState* ps = static_cast<PlayerState*>(data);
    if (length != VLC_TICK_INVALID && length > vlc_tick_from_sec(kWaveformMaxSeconds)) {
        ps->tooLong = true;
        ps->token->notify();
    }
}

class VlcWaveformDecoder final : public WaveformDecoder
{
public:
    explicit VlcWaveformDecoder(vlc_object_t* obj) : m_obj(obj) {}

    DecodeResult decode(const QString& localFile, PeaksAccumulator& acc, CancelToken& cancel) override
    {
        Sink sink;
        sink.acc = &acc;
        sink.token = &cancel;
        PlayerState state;
        state.token = &cancel;

        vlc_object_t* holder = createWaveformHolder(m_obj);
        if (!holder)
            return DecodeResult::Failed;

        const DecodeResult result = play(holder, localFile, sink, state, cancel);

        vlc_object_delete(holder);
        return result;
    }

private:
    DecodeResult play(vlc_object_t* holder, const QString& localFile, Sink& sink, PlayerState& state,
              CancelToken& cancel)
    {
        const QByteArray uri = QUrl::fromLocalFile(localFile).toEncoded();
        input_item_t* item = input_item_New(uri.constData(), nullptr);
        if (!item)
            return DecodeResult::Failed;

        // decoded as fast as possible (no-time-sync) to mono 8 kHz s16, handed to the callbacks
        const QByteArray sout = QByteArrayLiteral(
            ":sout=#transcode{acodec=s16l,channels=1,samplerate=8000}:smem{"
            "audio-prerender-callback=") + QByteArray::number(qulonglong(uintptr_t(&prerender)))
            + ",audio-postrender-callback=" + QByteArray::number(qulonglong(uintptr_t(&postrender)))
            + ",audio-data=" + QByteArray::number(qulonglong(uintptr_t(&sink)))
            + ",no-time-sync}"; // a bool option of the chain syntax is switched off with "no-"
        input_item_AddOption(item, sout.constData(), VLC_INPUT_OPTION_TRUSTED);
        input_item_AddOption(item, ":no-sout-video", VLC_INPUT_OPTION_TRUSTED);
        input_item_AddOption(item, ":no-sout-spu", VLC_INPUT_OPTION_TRUSTED);
        input_item_AddOption(item, ":no-sub-autodetect-file", VLC_INPUT_OPTION_TRUSTED);

        vlc_player_t* player = vlc_player_New(holder, VLC_PLAYER_LOCK_NORMAL);
        if (!player) {
            input_item_Release(item);
            return DecodeResult::Failed;
        }

        static const struct vlc_player_cbs cbs = [] {
            struct vlc_player_cbs c = {};
            c.on_state_changed = onStateChanged;
            c.on_error_changed = onErrorChanged;
            c.on_length_changed = onLengthChanged;
            return c;
        }();

        vlc_player_Lock(player);
        vlc_player_listener_id* listener = vlc_player_AddListener(player, &cbs, &state);
        const bool started = listener != nullptr
                             && vlc_player_SetCurrentMedia(player, item) == VLC_SUCCESS
                             && vlc_player_Start(player) == VLC_SUCCESS;
        vlc_player_Unlock(player);

        bool stalled = false;
        if (started) {
            auto lastProgress = std::chrono::steady_clock::now();
            uint64_t lastSamples = 0;
            for (;;) {
                cancel.waitUntil([&] { return state.stopped.load() || state.error.load() || sink.bad.load()
                                              || state.tooLong.load(); },
                                 std::chrono::seconds(1));
                if (cancel.cancelled() || state.stopped || state.error || sink.bad || state.tooLong)
                    break;
                const auto now = std::chrono::steady_clock::now();
                const uint64_t samples = sink.samples.load();
                if (samples != lastSamples) {
                    lastSamples = samples;
                    lastProgress = now;
                } else if (now - lastProgress > kStallTimeout) {
                    stalled = true;
                    break;
                }
            }
        }

        // stop (asynchronous), forget the listener; the delete waits for the input thread to end,
        // after which no callback can run any more
        vlc_player_Lock(player);
        if (listener)
            vlc_player_RemoveListener(player, listener);
        vlc_player_Stop(player);
        vlc_player_Unlock(player);
        vlc_player_Delete(player);
        input_item_Release(item);

        if (cancel.cancelled())
            return DecodeResult::Interrupted;
        if (!started || state.error || state.tooLong || sink.bad)
            return DecodeResult::Failed;
        // a stall or a stop without reaching the end is transient: not remembered
        return (!stalled && state.stopped) ? DecodeResult::Ok : DecodeResult::Interrupted;
    }

    vlc_object_t* m_obj;
};

} // namespace

vlc_object_t* createWaveformHolder(vlc_object_t* parent)
{
    // The player (and so its input) is created below this object, which only carries variables
    // that the player and the input inherit:
    //  - aout/vout: vlc_player_New() loads the audio output module of the configuration (aout_New),
    //    so it is the dummy one and the device of the user is never opened; no vout is asked for.
    //  - restore-playback-pos / restore-playback-states: a new input calls
    //    vlc_player_input_RestoreMlStates() (src/player/input.c:1321, src/player/medialib.c), which
    //    for a video of the media library can seek to the saved position or select the saved
    //    tracks. The analysis must start at 0 and must not touch the states of the user.
    vlc_object_t* holder = static_cast<vlc_object_t*>(vlc_object_create(parent, sizeof(vlc_object_t)));
    if (!holder)
        return nullptr;
    var_Create(holder, "aout", VLC_VAR_STRING);
    var_SetString(holder, "aout", "dummy");
    var_Create(holder, "vout", VLC_VAR_STRING);
    var_SetString(holder, "vout", "dummy");
    var_Create(holder, "restore-playback-pos", VLC_VAR_INTEGER);
    var_SetInteger(holder, "restore-playback-pos", VLC_PLAYER_RESTORE_PLAYBACK_POS_NEVER);
    var_Create(holder, "restore-playback-states", VLC_VAR_BOOL);
    var_SetBool(holder, "restore-playback-states", false);
    return holder;
}

std::unique_ptr<WaveformDecoder> makeVlcWaveformDecoder(vlc_object_t* obj)
{
    return std::make_unique<VlcWaveformDecoder>(obj);
}

WaveformEnvironment makeVlcWaveformEnvironment(vlc_object_t* obj)
{
    WaveformEnvironment env;
    char* userDir = config_GetUserDir(VLC_USERDATA_DIR);
    if (userDir) {
        env.cacheDir = QString::fromUtf8(userDir) + QStringLiteral("/vireo/waveforms");
        free(userDir);
    }
    env.makeDecoder = [obj] { return makeVlcWaveformDecoder(obj); };
    return env;
}

} // namespace redesign
