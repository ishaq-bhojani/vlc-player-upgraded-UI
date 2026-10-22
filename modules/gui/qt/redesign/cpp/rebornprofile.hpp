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
#ifndef VLC_QT_REDESIGN_REBORNPROFILE_HPP
#define VLC_QT_REDESIGN_REBORNPROFILE_HPP

#include <QString>

class ControlbarProfile;
class ControlbarProfileModel;
class QSettings;

namespace redesign
{

/** Name of the control bar profile of the redesign (spec 11.1). */
QString rebornProfileName();

/**
 * Fills `profile` with the layout of the "Vireo" profile, one row:
 * previous, play, next, seek bar | volume, subtitles, audio, settings, queue, fullscreen.
 * The seek bar is in the left group: it fills the free width of the row there, a centre group of
 * PlayerControlLayout never grows.
 */
void injectRebornModel(ControlbarProfile* profile);

/**
 * Redesign enabled. Adds the Vireo profile once (the flag `redesign/RebornProfileSeeded`
 * of `settings`, outside of the group of the profile model) and saves the model. It becomes the
 * selected profile only if the current selection is untouched stock content (a style of the
 * model, or no profile was saved before); a profile the user customised or chose stays selected.
 * If the user deleted the profile it is not added back.
 */
void ensureRebornProfile(ControlbarProfileModel* model, QSettings* settings);

/**
 * Redesign disabled. The profile is kept, but is not the selected one: a stock interface must not
 * show the redesign-only items. Selects the first profile instead.
 */
void leaveRebornProfile(ControlbarProfileModel* model);

} // namespace redesign

#endif // VLC_QT_REDESIGN_REBORNPROFILE_HPP
