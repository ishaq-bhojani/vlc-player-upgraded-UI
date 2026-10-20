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
#ifndef VLC_QT_REDESIGN_SETTINGSBRIDGE_HPP
#define VLC_QT_REDESIGN_SETTINGSBRIDGE_HPP

#include <QObject>
#include <QString>
#include <QVariantList>

class ColorSchemeModel;

/**
 * The two things the settings modal needs from the upstream code that QML can not reach: the
 * color scheme (ColorSchemeModel has no writable property, only a C++ setter) and the VLC key
 * string of a key press (the conversion of the QWidgets hotkey dialog, util/vlchotkeyconverter).
 * The QML singleton `SettingsBridge` of VLC.Redesign.
 */
class SettingsBridge : public QObject
{
    Q_OBJECT

    /**
     * [{text, kind}] in the rows of the ColorSchemeModel; `text` is its translated name and `kind`
     * "system", "light" or "dark": the pages map the buttons Light / Dark / System to a row by
     * `kind`, never by position.
     */
    Q_PROPERTY(QVariantList colorSchemes READ colorSchemes CONSTANT)

    //! the row of the ColorSchemeModel in use (ColorSchemeModel::currentIndex); writing it
    //! switches the interface and is saved with the main window settings
    Q_PROPERTY(int colorSchemeIndex READ colorSchemeIndex WRITE setColorSchemeIndex NOTIFY colorSchemeIndexChanged)

public:
    explicit SettingsBridge(ColorSchemeModel* colorScheme, QObject* parent = nullptr);

    QVariantList colorSchemes() const;
    int colorSchemeIndex() const;
    void setColorSchemeIndex(int index);

    /**
     * The VLC key of a key press, in the syntax of the configuration ("Ctrl+q", "Space",
     * "Alt+Left"); `key` and `modifiers` are Qt::Key and Qt::KeyboardModifiers of the QML key
     * event, `text` its text. "" for a key that is only a modifier (Shift, Ctrl, Alt, Meta) or
     * that has no VLC name.
     */
    Q_INVOKABLE QString hotkeyFromKeyEvent(int key, int modifiers, const QString& text) const;

signals:
    void colorSchemeIndexChanged();

private:
    ColorSchemeModel* m_colorScheme;
};

#endif
