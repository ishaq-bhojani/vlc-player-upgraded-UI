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
#ifndef VLC_QT_REDESIGN_SETTINGSBRIDGE_HPP
#define VLC_QT_REDESIGN_SETTINGSBRIDGE_HPP

#include <functional>

#include <QObject>
#include <QString>
#include <QVariantList>

class ColorSchemeModel;
class QWindow;

/**
 * What the settings modal needs from C++ that QML can not reach: the color scheme
 * (ColorSchemeModel has no writable property, only a C++ setter), the VLC key string of a key
 * press (the conversion of the QWidgets hotkey dialog, util/vlchotkeyconverter), and the native
 * file and folder dialogs (the static Qt has no QtQuick.Dialogs). The QML singleton
 * `SettingsBridge` of VLC.Redesign.
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
    //! gives the window the dialogs are children of (MainCtx::intfMainWindow); null: no parent
    using WindowProvider = std::function<QWindow*()>;

    explicit SettingsBridge(ColorSchemeModel* colorScheme, WindowProvider window = {},
                            QObject* parent = nullptr);

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

    /**
     * The file:// URL of a local path, as QUrl::fromLocalFile makes it: "C:\Music" and "C:/Music"
     * give "file:///C:/Music", "/home/me/Music" gives "file:///home/me/Music", a network path
     * "\\server\share\a" (or "//server/share/a") gives "file://server/share/a". The parts are
     * percent-encoded ("/a#b" gives "file:///a%23b"). The spaces around are dropped, a string that
     * already is a URL (scheme://...) is kept as it is, an empty one gives "". The folder model of the
     * media library wants a URL, the settings pages have a path.
     */
    Q_INVOKABLE QString localFileUrl(const QString& path) const;

    /**
     * The native folder dialog, a child of the main window and modal to it. The native path of
     * the folder chosen, "" if the user cancelled. `startDir` is where it opens (a native path,
     * may be empty or not exist).
     */
    Q_INVOKABLE QString pickFolder(const QString& title, const QString& startDir) const;

    /**
     * The native "open file" dialog, as pickFolder(). `filter` is a Qt name filter
     * ("Text files (*.txt)", empty for all files). `startDir` may be a file.
     */
    Q_INVOKABLE QString pickFile(const QString& title, const QString& startDir,
                                 const QString& filter = QString()) const;

    /**
     * The native "save file" dialog (the file may not exist yet), as pickFolder(): for the
     * options that name a file to write (the log file).
     */
    Q_INVOKABLE QString pickSaveFile(const QString& title, const QString& startDir,
                                     const QString& filter = QString()) const;

signals:
    void colorSchemeIndexChanged();

private:
    ColorSchemeModel* m_colorScheme;
    WindowProvider m_window;
};

#endif
