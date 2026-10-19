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
pragma Singleton
import QtQuick

import VLC.MainInterface

// Design tokens of the VLC Reborn redesign (docs/redesign/tokens.md, Table D).
// PROVISIONAL: replace from tokens.md Table D
QtObject {
    id: redesignStyle

    readonly property real scale: MainCtx.intfScaleFactor

    // Spacing
    readonly property int spacingXS: MainCtx.dp(4, scale) // PROVISIONAL: replace from tokens.md Table D
    readonly property int spacingS: MainCtx.dp(8, scale) // PROVISIONAL: replace from tokens.md Table D
    readonly property int spacingM: MainCtx.dp(12, scale) // PROVISIONAL: replace from tokens.md Table D
    readonly property int spacingL: MainCtx.dp(16, scale) // PROVISIONAL: replace from tokens.md Table D
    readonly property int spacingXL: MainCtx.dp(24, scale) // PROVISIONAL: replace from tokens.md Table D

    // Corner radii
    readonly property int radiusS: MainCtx.dp(4, scale) // PROVISIONAL: replace from tokens.md Table D
    readonly property int radiusM: MainCtx.dp(6, scale) // PROVISIONAL: replace from tokens.md Table D
    readonly property int radiusL: MainCtx.dp(8, scale) // PROVISIONAL: replace from tokens.md Table D

    // Layout metrics
    readonly property int controlBarHeight: MainCtx.dp(48, scale) // PROVISIONAL: replace from tokens.md Table D
    readonly property int railWidthCollapsed: MainCtx.dp(48, scale) // PROVISIONAL: replace from tokens.md Table D
    readonly property int railWidthExpanded: MainCtx.dp(200, scale) // PROVISIONAL: replace from tokens.md Table D
    readonly property int panelWidthDefault: MainCtx.dp(320, scale) // PROVISIONAL: replace from tokens.md Table D
    readonly property int panelWidthMin: MainCtx.dp(240, scale) // PROVISIONAL: replace from tokens.md Table D
    readonly property int panelWidthMax: MainCtx.dp(560, scale) // PROVISIONAL: replace from tokens.md Table D
}
