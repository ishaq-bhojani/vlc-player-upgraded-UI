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

#include "measuredgain.hpp"

#include <algorithm>
#include <cmath>
#include <initializer_list>

#include <QFileInfo>
#include <QSet>
#include <QSettings>

#include <vlc_common.h>
#include <vlc_interface.h>

namespace redesign
{

namespace
{

const char SETTINGS_KEY_MEASURED[] = "redesign/measuredLoudness";

const QSet<QString>& audioExtensions()
{
    static const QSet<QString> extensions = [] {
        QSet<QString> set;
        for (const char* extension : {EXTENSIONS_AUDIO_CSV})
            set.insert(QString::fromLatin1(extension));
        return set;
    }();
    return extensions;
}

} // namespace

QString replayGainChoice(bool measured, const QString& mode)
{
    return (measured && mode == QLatin1String("track")) ? QStringLiteral("measured") : mode;
}

bool isLocalAudioFile(const QUrl& url)
{
    if (!url.isValid() || url.scheme() != QLatin1String("file"))
        return false;
    const QString file = url.toLocalFile();
    if (file.isEmpty())
        return false;
    return audioExtensions().contains(QFileInfo(file).suffix().toLower());
}

bool needsMeasuredGain(bool enabled, const QString& mode, const QUrl& url, const ReplayGainInfo& tags)
{
    return enabled && mode == QLatin1String("track") && isLocalAudioFile(url) && !tags.any();
}

float measuredOutputGain(float measuredDb, float peak, const MeasuredGainSettings& settings)
{
    float target = std::isfinite(measuredDb) ? measuredDb : 0.f;
    target += settings.preampDb;
    if (settings.peakProtection) {
        // as replay_gain_CalcMultiplier() does for a tag: a missing or invalid peak counts as 1.0
        const float effectivePeak = (std::isfinite(peak) && peak > 0.f) ? std::min(peak, 1.f) : 1.f;
        target = std::min(target, -20.f * std::log10(effectivePeak));
    }
    return settings.userGain * std::pow(10.f, (target - settings.defaultGainDb) / 20.f);
}

MeasuredGain::MeasuredGain(std::unique_ptr<MeasuredGainBackend> backend, WaveformEnvironment env,
                           QSettings* settings, QObject* parent)
    : QObject(parent)
    , m_backend(std::move(backend))
    , m_settings(settings)
    , m_provider(std::move(env))
{
    if (!m_settings)
        m_settings = new QSettings(this); // child of this: deleted with it
    m_enabled = m_settings->value(QLatin1String(SETTINGS_KEY_MEASURED), false).toBool();

    // the analysis ended (or the file was found to be unanalysable): decide again
    connect(&m_provider, &WaveformProvider::peaksChanged, this, &MeasuredGain::refresh);
    connect(&m_provider, &WaveformProvider::failedChanged, this, &MeasuredGain::refresh);
}

MeasuredGain::~MeasuredGain()
{
    // leave the audio output the way it was found; nobody is told (the object is going away)
    release(/*notify*/ false);
}

QString MeasuredGain::choice() const
{
    return replayGainChoice(m_enabled, m_backend->settings().mode);
}

void MeasuredGain::setChoice(const QString& choice)
{
    static const QSet<QString> choices = {QStringLiteral("none"), QStringLiteral("track"),
                                          QStringLiteral("album"), QStringLiteral("measured")};
    if (!choices.contains(choice))
        return;
    const bool measured = choice == QLatin1String("measured");
    m_backend->setReplayGainMode(measured ? QStringLiteral("track") : choice);
    // the order matters little: setEnabled() decides again against the mode that is now set
    if (m_enabled != measured) {
        m_enabled = measured;
        m_settings->setValue(QLatin1String(SETTINGS_KEY_MEASURED), m_enabled);
        m_settings->sync();
        emit enabledChanged();
    }
    emit choiceChanged();
    refresh();
}

void MeasuredGain::setEnabled(bool enabled)
{
    if (enabled == m_enabled)
        return;
    m_enabled = enabled;
    m_settings->setValue(QLatin1String(SETTINGS_KEY_MEASURED), m_enabled);
    m_settings->sync();
    emit enabledChanged();
    emit choiceChanged();
    refresh();
}

void MeasuredGain::refresh()
{
    // the provider's signals and the calls below can come back here: handle one at a time
    if (m_refreshing) {
        m_again = true;
        return;
    }
    m_refreshing = true;
    do {
        m_again = false;
        decide();
    } while (m_again);
    m_refreshing = false;
}

void MeasuredGain::decide()
{
    // the default: nothing to look at, so the player is not even asked
    if (!m_enabled) {
        m_provider.setUrl(QUrl());
        release();
        return;
    }

    const MeasuredGainBackend::Media media = m_backend->currentMedia();
    const MeasuredGainSettings settings = m_backend->settings();

    if (!needsMeasuredGain(m_enabled, settings.mode, media.url, media.tags)) {
        m_provider.setUrl(QUrl()); // stops the analysis if one runs
        release();
        return;
    }

    // the gain of a media never stays on another one
    if (m_appliedUrl != media.url)
        release();
    m_provider.setUrl(media.url);

    // The tags are only known once the input runs: before that the file may still turn out to
    // have a gain of its own, which VLC then applies and this one must not be added to.
    if (media.settled && m_provider.ready() && m_provider.url() == media.url)
        apply(media.url, settings);
}

void MeasuredGain::apply(const QUrl& url, const MeasuredGainSettings& settings)
{
    const float factor = measuredOutputGain(float(m_provider.gainDb()), float(m_provider.peak()), settings);
    // nothing to do when the output already has this gain for this media (a refresh caused by a
    // change of metadata or info); a media change on the player thread removes the gain, which
    // outputGain() reports, so a replay of the same file is levelled again
    if (m_appliedUrl != url || m_backend->outputGain() != std::optional<float>(factor))
        m_backend->setOutputGain(factor);
    m_appliedUrl = url;
    if (!m_active || m_gainDb != m_provider.gainDb()) {
        m_active = true;
        m_gainDb = m_provider.gainDb();
        emit activeChanged();
    }
}

void MeasuredGain::release(bool notify)
{
    m_backend->setOutputGain(std::nullopt);
    m_appliedUrl = QUrl();
    if (m_active) {
        m_active = false;
        m_gainDb = 0.0;
        if (notify)
            emit activeChanged();
    }
}

} // namespace redesign
