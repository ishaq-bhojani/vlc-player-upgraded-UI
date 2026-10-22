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
#ifndef VLC_QT_REDESIGN_MLRECENTAUDIOMODEL_HPP
#define VLC_QT_REDESIGN_MLRECENTAUDIOMODEL_HPP

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "medialibrary/mlaudiomodel.hpp"

/**
 * The audio tracks of the playback history of the media library, most recent
 * first (the "Listen Again" row of the Home page). Audio counterpart of
 * MLRecentVideoModel: same loader shape, with vlc_ml_count_audio_history /
 * vlc_ml_list_audio_history, and a reset on VLC_ML_EVENT_HISTORY_CHANGED.
 */
class MLRecentAudioModel : public MLAudioModel
{
    Q_OBJECT

public:
    explicit MLRecentAudioModel(QObject *parent = nullptr);

    virtual ~MLRecentAudioModel() = default;

protected: // MLBaseModel implementation
    std::unique_ptr<MLListCacheLoader> createMLLoader() const override;

protected: // MLAudioModel reimplementation
    void onVlcMlEvent(const MLEvent &event) override;

private:
    struct Loader : public MLListCacheLoader::MLOp
    {
        using MLListCacheLoader::MLOp::MLOp;

        size_t count(vlc_medialibrary_t *ml, const vlc_ml_query_params_t *queryParams) const override;

        std::vector<std::unique_ptr<MLItem>> load(vlc_medialibrary_t *ml, const vlc_ml_query_params_t *queryParams) const override;

        std::unique_ptr<MLItem> loadItemById(vlc_medialibrary_t *ml, MLItemId itemId) const override;
    };
};

#endif // VLC_QT_REDESIGN_MLRECENTAUDIOMODEL_HPP
