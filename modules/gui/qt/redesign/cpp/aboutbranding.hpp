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
#ifndef VLC_QT_REDESIGN_ABOUTBRANDING_HPP
#define VLC_QT_REDESIGN_ABOUTBRANDING_HPP

class QLabel;
class QTextEdit;

namespace redesign
{

/**
 * Brands the widgets of the About dialog (help.cpp, AboutDialog) when the
 * redesign is enabled: the title ("<name> - built on VLC"), the description
 * (built on VLC, link to the source, Inter font credit) and the licence page,
 * which gets the text of the Inter font licence (SIL OFL, :/redesign/fonts/OFL.txt)
 * appended. Call it after the stock texts were set.
 */
void applyAboutBranding(QLabel* title, QLabel* description, QTextEdit* licensePage);

} // namespace redesign

#endif // VLC_QT_REDESIGN_ABOUTBRANDING_HPP
