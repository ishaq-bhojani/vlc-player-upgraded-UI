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
#ifndef REDESIGN_MEASUREDGAIN_HPP
#define REDESIGN_MEASUREDGAIN_HPP

#include <memory>
#include <optional>

#include <QObject>
#include <QString>
#include <QUrl>

#include "waveform.hpp"

class QSettings;

namespace redesign
{

//! The replay gain values that the playing media brings with it (tags, the stream of the demuxer).
struct ReplayGainInfo
{
    bool trackGain = false;
    bool albumGain = false;

    bool any() const { return trackGain || albumGain; }
};

//! What the decision and the amplification need from the configuration of VLC
struct MeasuredGainSettings
{
    QString mode = QStringLiteral("none"); //!< audio-replay-gain-mode: "none", "track" or "album"
    float preampDb = 0.f;                  //!< audio-replay-gain-preamp
    float defaultGainDb = -7.f;            //!< audio-replay-gain-default (the gain of a stream without any)
    bool peakProtection = true;            //!< audio-replay-gain-peak-protection
    float userGain = 1.f;                  //!< gain (Audio gain, a factor), which the output multiplies in
};

//! the entry of the "Replay gain" choice for the flag and the mode of VLC: "measured" when the flag is
//! on and the mode is "track", else the mode itself
QString replayGainChoice(bool measured, const QString& mode);

//! true for a file:// url (a network share is one) whose extension is an audio one
bool isLocalAudioFile(const QUrl& url);

/**
 * The decision: does the media get the gain of its measured loudness? Only when the user chose
 * "Measured" (`enabled`, and the replay gain mode of VLC is "track": Measured is that mode plus
 * the flag), the media is a local audio file, and it brings no replay gain of its own, whatever
 * its source (tags, a header of the file): such a file already has its level.
 */
bool needsMeasuredGain(bool enabled, const QString& mode, const QUrl& url, const ReplayGainInfo& tags);

/**
 * The value of the "gain" variable of the audio output that makes an untagged track play
 * `measuredDb` louder (plus the pre-amp of the user), as VLC does it for a tagged one:
 *  - the replay gain of VLC is `10^(default/20)` for a stream without gain, times "gain"; so the
 *    variable is `userGain * 10^((target - default)/20)` and the product is `userGain * 10^(target/20)`;
 *  - peak protection: `target` is limited so that `peak * gain` stays at or below full scale,
 *    like the one of VLC for tags (no peak, or an invalid one: 1.0).
 * `peak` is the largest sample of the file in [0, 1].
 */
float measuredOutputGain(float measuredDb, float peak, const MeasuredGainSettings& settings);

/**
 * What MeasuredGain needs from the player and the audio output: a seam, so the logic is
 * testable without audio. The VLC implementation is in measuredgainvlc.hpp. All calls come from
 * the GUI thread.
 */
class MeasuredGainBackend
{
public:
    struct Media
    {
        QUrl url;                //!< of the current media, empty without
        ReplayGainInfo tags;
        //! the input is running (playing or paused): its streams exist, so `tags` can be trusted
        bool settled = false;
    };

    virtual ~MeasuredGainBackend() = default;
    virtual Media currentMedia() = 0;
    //! the live settings; the mode is the one the audio output uses (its variable, else the configuration)
    virtual MeasuredGainSettings settings() = 0;
    //! "none", "track" or "album": stored in the configuration and set on the audio output at once
    virtual void setReplayGainMode(const QString& mode) = 0;
    /**
     * Sets the "gain" variable of the audio output (see measuredOutputGain()) and has it
     * applied to what plays; nullopt gives the output back its own gain (the configuration).
     * The volume of the user is never touched.
     */
    virtual void setOutputGain(std::optional<float> factor) = 0;
    //! the gain this backend set and that is still on the output, nullopt if none (it is gone
    //! when the media changed in the meantime): lets MeasuredGain skip a call that changes nothing
    virtual std::optional<float> outputGain() = 0;
};

/**
 * Measured loudness: the replay gain of the files that have none, from the analysis the waveform
 * does anyway (the level of the whole file, WaveformProvider::gainDb()).
 *
 * It watches the current media of the player (refresh() is called when it, its state or its
 * metadata change) and, if needsMeasuredGain(), asks the waveform queue for the file (a cache
 * hit is instant, the first play of a file takes the time of the analysis, about a second for a
 * song, since it decodes much faster than real time), then sets the gain of the audio output
 * through the backend. The gain follows the file: it is taken back when another media starts, when
 * the file turns out to have tags, and when the option is switched off. It does not depend on the
 * waveform seek bar or its setting.
 *
 * Known limits:
 *  - Replay gain that a decoder carries inside the stream (Vorbis comments of a Vorbis stream in a
 *    container other than Ogg: modules/codec/vorbis.c fills the gain of the decoder, which neither
 *    the item meta nor the track format shows) is invisible here, so such a file may be levelled
 *    twice.
 *  - The peak used for peak protection is that of the 8 kHz mono decode, which reads lower than the
 *    true peak: a boost of a quiet track may clip slightly.
 */
class MeasuredGain : public QObject
{
    Q_OBJECT

    //! "Measured" is chosen in Settings > Audio > Replay gain; stored in the QSettings group
    //! "redesign", key "measuredLoudness"
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged FINAL)
    //! The "Replay gain" choice of Settings > Audio: "none", "track", "album" or "measured"
    //! ("measured" is the mode "track" of VLC with `enabled`). Writing it sets the mode of VLC
    //! (configuration and the running audio output) and `enabled`.
    Q_PROPERTY(QString choice READ choice WRITE setChoice NOTIFY choiceChanged FINAL)
    //! a measured gain is applied to the current media
    Q_PROPERTY(bool active READ active NOTIFY activeChanged FINAL)
    //! the measured gain of the current media in dB (before the pre-amp and the peak limit), 0 when not active
    Q_PROPERTY(double gainDb READ gainDb NOTIFY activeChanged FINAL)

public:
    /**
     * @param backend   the player and the audio output
     * @param env       how the file is analysed (the waveform environment of the application)
     * @param settings  where `enabled` is stored; not owned. nullptr: a default QSettings()
     */
    MeasuredGain(std::unique_ptr<MeasuredGainBackend> backend, WaveformEnvironment env,
                 QSettings* settings = nullptr, QObject* parent = nullptr);
    ~MeasuredGain() override;

    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    QString choice() const;
    void setChoice(const QString& choice);
    bool active() const { return m_active; }
    double gainDb() const { return m_gainDb; }

    //! decides again for the current media; call it when the media, the state, the metadata or
    //! the replay gain mode changed
    Q_INVOKABLE void refresh();

signals:
    void enabledChanged();
    void choiceChanged();
    void activeChanged();

private:
    void decide();
    void apply(const QUrl& url, const MeasuredGainSettings& settings);
    //! takes the measured gain back (the output gets its own)
    void release(bool notify = true);

    std::unique_ptr<MeasuredGainBackend> m_backend;
    QSettings* m_settings = nullptr;
    WaveformProvider m_provider;
    bool m_enabled = false;
    bool m_active = false;
    double m_gainDb = 0.0;
    QUrl m_appliedUrl; //!< the media the applied gain belongs to
    bool m_refreshing = false;
    bool m_again = false;
};

} // namespace redesign

#endif
