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
#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include "redesign.hpp"

#include <vlc_variables.h>

#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>

namespace redesign
{

bool isEnabled(vlc_object_t* obj)
{
    return var_InheritBool(obj, "qt-redesign");
}

FirstRun firstRunFor(bool redesignEnabled)
{
    return redesignEnabled ? FirstRun::Onboarding : FirstRun::Stock;
}

QUrl rootQmlUrl(bool enabled)
{
    return QUrl(enabled
        ? QStringLiteral("qrc:/qt/qml/VLC/Redesign/RedesignInterface.qml")
        : QStringLiteral("qrc:/qt/qml/VLC/MainInterface/MainInterface.qml"));
}

bool installAppFont(const QStringList& fontFiles, const QString& family)
{
    // do not touch the application font unless every file is usable
    for (const QString& file : fontFiles)
    {
        const int id = QFontDatabase::addApplicationFont(file);
        if (id < 0)
        {
            qWarning("redesign: failed to load font %s", qUtf8Printable(file));
            return false;
        }
        if (!QFontDatabase::applicationFontFamilies(id).contains(family))
        {
            qWarning("redesign: font %s does not provide the family %s",
                     qUtf8Printable(file), qUtf8Printable(family));
            return false;
        }
    }

    // keep the size the platform chose, only the family changes
    QFont font = QGuiApplication::font();
    font.setFamily(family);
    QGuiApplication::setFont(font);
    return true;
}

bool installAppFont()
{
    // font family, see docs/redesign/tokens.md ("Font")
    return installAppFont({
        QStringLiteral(":/redesign/fonts/Inter-Regular.ttf"),
        QStringLiteral(":/redesign/fonts/Inter-Medium.ttf"),
        QStringLiteral(":/redesign/fonts/Inter-SemiBold.ttf"),
    }, QStringLiteral("Inter"));
}

} // namespace redesign
