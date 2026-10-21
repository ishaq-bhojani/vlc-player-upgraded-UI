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
#include "rebornprofile.hpp"

#include <QSettings>
#include <QVector>
#include <array>
#include <memory>

#include "dialogs/toolbar/controlbar_profile.hpp"
#include "dialogs/toolbar/controlbar_profile_model.hpp"
#include "player/control_list_model.hpp"
#include "player/player_controlbar_model.hpp"

namespace redesign
{

namespace
{

constexpr QLatin1String SETTINGS_KEY_SEEDED {"redesign/RebornProfileSeeded"};

using Controls = QVector<int>;

bool isStockContent(const ControlbarProfile* profile)
{
    static constexpr ControlbarProfileModel::Style stockStyles[] = {
        ControlbarProfileModel::Style::DEFAULT_STYLE,
        ControlbarProfileModel::Style::MINIMALIST_STYLE,
        ControlbarProfileModel::Style::ONE_LINER_STYLE,
        ControlbarProfileModel::Style::SIMPLEST_STYLE,
        ControlbarProfileModel::Style::CLASSIC_STYLE
    };

    for (const auto style : stockStyles)
    {
        const std::unique_ptr<ControlbarProfile> stock(ControlbarProfileModel::generateProfileFromStyle(style));
        if (stock && *stock == *profile)
            return true;
    }
    return false;
}

bool isRebornProfile(const ControlbarProfile* profile)
{
    // the name (it may have a " (n)" suffix) or, when renamed, an untouched layout
    if (profile->name().startsWith(rebornProfileName()))
        return true;

    ControlbarProfile reborn;
    injectRebornModel(&reborn);
    return reborn == *profile;
}

} // anonymous namespace

QString rebornProfileName()
{
    return QStringLiteral("Vireo");
}

void injectRebornModel(ControlbarProfile* profile)
{
    using L = ControlListModel;

    const Controls seekRow { L::PREVIOUS_BUTTON, L::PLAY_BUTTON, L::NEXT_BUTTON, L::REDESIGN_SEEKBAR };
    const Controls rightRow { L::VOLUME, L::REDESIGN_SUBTITLE_POPUP, L::REDESIGN_AUDIO_POPUP,
                              L::REDESIGN_SIDEBAR_BUTTON, L::PLAYLIST_BUTTON, L::FULLSCREEN_BUTTON };

    profile->setModelData(PlayerControlbarModel::Videoplayer, { seekRow, Controls{}, rightRow });
    profile->setModelData(PlayerControlbarModel::Audioplayer, { seekRow, Controls{}, rightRow });
    profile->setModelData(PlayerControlbarModel::Miniplayer,
                          { Controls{ L::ARTWORK_INFO },
                            Controls{ L::PREVIOUS_BUTTON, L::PLAY_BUTTON, L::NEXT_BUTTON },
                            Controls{ L::VOLUME, L::PLAYER_SWITCH_BUTTON } });
}

void ensureRebornProfile(ControlbarProfileModel* model, QSettings* settings)
{
    if (settings->value(SETTINGS_KEY_SEEDED, false).toBool())
        return;

    const bool selectIt = !model->currentModel() || isStockContent(model->currentModel());

    bool present = false;
    for (int i = 0; i < model->rowCount() && !present; ++i)
        present = isRebornProfile(model->getProfile(i));

    if (!present)
    {
        const auto profile = model->newProfile(rebornProfileName());
        if (profile)
        {
            injectRebornModel(profile);
            profile->resetDirty();

            if (selectIt)
                model->setSelectedProfile(model->rowCount() - 1);
        }
    }

    settings->setValue(SETTINGS_KEY_SEEDED, true);
    // the profile only exists on disk once the model is saved
    model->save(false);
}

void leaveRebornProfile(ControlbarProfileModel* model)
{
    const auto selected = model->currentModel();
    if (selected && model->selectedProfile() != 0 && isRebornProfile(selected))
        model->setSelectedProfile(0);
}

} // namespace redesign
