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
#ifndef VLC_QT_REDESIGN_WIDGETSTYLE_HPP
#define VLC_QT_REDESIGN_WIDGETSTYLE_HPP

#include <QStyle>

namespace redesign
{

/**
 * Creates the style of the redesign for the QWidgets dialogs: Fusion (the one
 * style that does not draw from a table of its own), with the controls that
 * Fusion leaves nearly invisible on the redesign palette painted from the
 * palette roles (see widgetpalette.hpp): check boxes, radio buttons, push and
 * tool buttons, the outlines of line edits, combo boxes, spin boxes, group
 * boxes and frames, the table header, and the focus rings.
 *
 * It also tidies a few stock widgets when it polishes them (the Media Library
 * folder table and its buttons, and it hides the "Force window style" choice of
 * Advanced preferences: that choice would replace this style). unpolish()
 * undoes the table and button changes.
 *
 * Returns nullptr if Fusion is not available. The caller owns the style (pass
 * it to QApplication::setStyle).
 */
QStyle* createWidgetStyle();

} // namespace redesign

#endif // VLC_QT_REDESIGN_WIDGETSTYLE_HPP
