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
#ifndef VLC_QT_REDESIGN_UIVISIBILITY_HPP
#define VLC_QT_REDESIGN_UIVISIBILITY_HPP

#include <QObject>

/**
 * "Hide UI" of the redesign: whether the bars of the player are hidden.
 *
 * One flag for the process. The right-click menu (menus/menus.cpp, C++) toggles it through
 * instance(); the shell (ShellStates.uiHidden, QML singleton "UiVisibility") follows it, and
 * sets it back to false on Esc. Ctrl+H toggles it.
 */
class UiVisibility : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool hidden READ hidden WRITE setHidden NOTIFY hiddenChanged FINAL)

public:
    explicit UiVisibility(QObject* parent = nullptr);

    /// the instance the menu and the shell share
    static UiVisibility* instance();

    bool hidden() const { return m_hidden; }
    void setHidden(bool hidden);

    Q_INVOKABLE void toggle();

signals:
    void hiddenChanged(bool hidden);

private:
    bool m_hidden = false;
};

#endif // VLC_QT_REDESIGN_UIVISIBILITY_HPP
