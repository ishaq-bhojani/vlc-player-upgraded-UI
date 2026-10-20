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
#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include "settingsbridge.hpp"

#include <vlc_common.h>
#include <vlc_actions.h>

#include <QDir>
#include <QFileDialog>
#include <QKeyEvent>
#include <QRegularExpression>
#include <QUrl>
#include <QVariantMap>
#include <QWindow>

#include "../../util/color_scheme_model.hpp"
#include "../../util/vlchotkeyconverter.hpp"

SettingsBridge::SettingsBridge(ColorSchemeModel* colorScheme, WindowProvider window, QObject* parent)
    : QObject(parent)
    , m_colorScheme(colorScheme)
    , m_window(std::move(window))
{
    if (m_colorScheme)
        connect(m_colorScheme, &ColorSchemeModel::currentChanged,
                this, &SettingsBridge::colorSchemeIndexChanged);
}

QVariantList SettingsBridge::colorSchemes() const
{
    QVariantList list;
    if (!m_colorScheme)
        return list;

    const auto schemes = m_colorScheme->getSchemes();
    for (const ColorSchemeModel::Item& item : schemes)
    {
        QString kind = QStringLiteral("system");
        if (item.scheme == ColorSchemeModel::Day)
            kind = QStringLiteral("light");
        else if (item.scheme == ColorSchemeModel::Night)
            kind = QStringLiteral("dark");
        list.append(QVariantMap{{QStringLiteral("text"), item.text}, {QStringLiteral("kind"), kind}});
    }
    return list;
}

int SettingsBridge::colorSchemeIndex() const
{
    return m_colorScheme ? m_colorScheme->currentIndex() : 0;
}

void SettingsBridge::setColorSchemeIndex(int index)
{
    if (m_colorScheme)
        m_colorScheme->setCurrentIndex(index);
}

QString SettingsBridge::hotkeyFromKeyEvent(int key, int modifiers, const QString& text) const
{
    switch (key)
    {
    case Qt::Key_unknown:
    case Qt::Key_Shift:
    case Qt::Key_Control:
    case Qt::Key_Meta:
    case Qt::Key_Alt:
    case Qt::Key_AltGr:
        return QString();
    default:
        break;
    }

    // the same conversion as KeyInputDialog (preferences_widgets.cpp)
    QKeyEvent event(QEvent::KeyPress, key, Qt::KeyboardModifiers(modifiers), text);
    const int vlcKey = qtEventToVLCKey(&event);
    // a key without a VLC name is only its modifiers
    if ((unsigned(vlcKey) & ~unsigned(KEY_MODIFIER)) == 0)
        return QString();
    return VLCKeyToString(unsigned(vlcKey), false);
}

namespace
{

//! runs the dialog as a child of `parent` (modal to it) and returns the chosen path, "" if none
QString runDialog(QFileDialog& dialog, QWindow* parent)
{
    if (parent)
    {
        // the dialog is a widget, the main window is not: give it a native window to put the
        // main window as its transient parent
        dialog.setAttribute(Qt::WA_NativeWindow, true);
        dialog.winId();
        if (QWindow* handle = dialog.windowHandle())
            handle->setTransientParent(parent);
        dialog.setWindowModality(Qt::WindowModal);
    }

    if (dialog.exec() != QDialog::Accepted || dialog.selectedFiles().isEmpty())
        return QString();
    return QDir::toNativeSeparators(dialog.selectedFiles().first());
}

} // namespace

QString SettingsBridge::localFileUrl(const QString& path) const
{
    const QString text = path.trimmed();
    if (text.isEmpty())
        return QString();

    // "scheme://": already a URL (a single letter is a drive, "C://x" is a path)
    static const QRegularExpression urlScheme(QStringLiteral("^[a-zA-Z][a-zA-Z0-9+.-]+://"));
    if (urlScheme.match(text).hasMatch())
        return text;

    // fromLocalFile only turns the native separators into slashes, and the native ones are those of
    // the host: the path of the user (Windows) is converted here, whatever the host is
    QString slashes = text;
    slashes.replace(QLatin1Char('\\'), QLatin1Char('/'));
    return QUrl::fromLocalFile(slashes).toString(QUrl::FullyEncoded);
}

QString SettingsBridge::pickFolder(const QString& title, const QString& startDir) const
{
    QFileDialog dialog(nullptr, title, startDir);
    dialog.setFileMode(QFileDialog::Directory);
    dialog.setOption(QFileDialog::ShowDirsOnly, true);
    return runDialog(dialog, m_window ? m_window() : nullptr);
}

QString SettingsBridge::pickFile(const QString& title, const QString& startDir,
                                 const QString& filter) const
{
    QFileDialog dialog(nullptr, title, startDir, filter);
    dialog.setFileMode(QFileDialog::ExistingFile);
    return runDialog(dialog, m_window ? m_window() : nullptr);
}

QString SettingsBridge::pickSaveFile(const QString& title, const QString& startDir,
                                     const QString& filter) const
{
    QFileDialog dialog(nullptr, title, startDir, filter);
    dialog.setFileMode(QFileDialog::AnyFile);
    dialog.setAcceptMode(QFileDialog::AcceptSave);
    return runDialog(dialog, m_window ? m_window() : nullptr);
}
