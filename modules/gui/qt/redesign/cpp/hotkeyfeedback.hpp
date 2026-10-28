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
#ifndef VLC_QT_REDESIGN_HOTKEYFEEDBACK_HPP
#define VLC_QT_REDESIGN_HOTKEYFEEDBACK_HPP

#include <vlc_common.h>

#include <QObject>
#include <QString>

class ShortcutsModel;

/**
 * The text of the shortcut toast (shell/ShortcutToast.qml): which action a key press sent as a
 * hotkey (MainCtx::hotkeySent) runs.
 *
 * The key press is turned into the VLC key syntax the way the hotkeys and the shortcuts page do
 * (qtEventToVLCKey, VLCKeyToString), then looked up in the key actions of the core
 * (ShortcutsModel, read live: a key changed in the settings is named at once).
 */
class HotkeyFeedback : public QObject
{
    Q_OBJECT

public:
    explicit HotkeyFeedback(vlc_object_t* obj, QObject* parent = nullptr);
    ~HotkeyFeedback() override;

    /**
     * "<keys> — <action>" for a key that a hotkey action holds ("Space — Play/Pause",
     * "Ctrl+Right — Medium forward jump"; the keys with their translated names), "" for a key
     * that no action holds or a modifier alone.
     */
    Q_INVOKABLE QString describe(int qtKey, int qtModifiers) const;

private:
    ShortcutsModel* m_shortcuts;
};

#endif // VLC_QT_REDESIGN_HOTKEYFEEDBACK_HPP
