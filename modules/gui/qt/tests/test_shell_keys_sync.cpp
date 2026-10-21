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

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>
#include <QStringList>
#include <QTest>

namespace
{

//! "Shift+Ctrl+P" and "ctrl+shift+p" -> "ctrl+shift+p" (the same rule as ShellKeys.normalize)
QString normalize(const QString& hotkey)
{
    QString rest = hotkey.trimmed().toLower();
    QStringList modifiers;
    static const QRegularExpression modifier(QStringLiteral("^(ctrl|alt|shift|meta)\\+(.+)$"));
    for (;;)
    {
        const QRegularExpressionMatch found = modifier.match(rest);
        if (!found.hasMatch())
            break;
        modifiers.append(found.captured(1));
        rest = found.captured(2);
    }
    modifiers.sort();
    modifiers.append(rest);
    return modifiers.join(QLatin1Char('+'));
}

// the source tree: this file is in modules/gui/qt/tests/ (tried as given, and from the build root)
QString qtSourceDir()
{
    const QString here = QFileInfo(QStringLiteral(__FILE__)).absolutePath();
    for (const QString& candidate : {here, QDir::current().absoluteFilePath(QFileInfo(QStringLiteral(__FILE__)).path())})
    {
        if (QFileInfo::exists(candidate + QStringLiteral("/../redesign/util/ShellKeys.qml")))
            return QDir::cleanPath(candidate + QStringLiteral("/.."));
    }
    return QString();
}

QString readFile(const QString& path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? QString::fromUtf8(file.readAll()) : QString();
}

}

/*
 * Keeps util/ShellKeys.qml (the keys the window takes before the hotkeys, which the shortcuts
 * page warns about) in step with the stock shortcuts the redesign still loads
 * (menus/qml/GlobalShortcuts.qml): every key literal of that file must be listed.
 */
class TestShellKeysSync : public QObject
{
    Q_OBJECT

private slots:
    void everyStockShortcutIsListed()
    {
        const QString root = qtSourceDir();
        if (root.isEmpty())
            QSKIP("the sources are not reachable from the test's working directory");

        const QString shortcuts = readFile(root + QStringLiteral("/menus/qml/GlobalShortcuts.qml"));
        const QString shellKeys = readFile(root + QStringLiteral("/redesign/util/ShellKeys.qml"));
        QVERIFY2(!shortcuts.isEmpty(), "GlobalShortcuts.qml not found");
        QVERIFY2(!shellKeys.isEmpty(), "ShellKeys.qml not found");

        QSet<QString> listed;
        static const QRegularExpression listedKey(QStringLiteral("key:\\s*\"([^\"]+)\""));
        for (auto it = listedKey.globalMatch(shellKeys); it.hasNext();)
            listed.insert(normalize(it.next().captured(1)));
        QVERIFY(listed.size() > 10);

        QStringList literals;
        static const QRegularExpression single(QStringLiteral("\\bsequence\\s*:\\s*\"([^\"]+)\""));
        for (auto it = single.globalMatch(shortcuts); it.hasNext();)
            literals.append(it.next().captured(1));
        static const QRegularExpression many(QStringLiteral("\\bsequences\\s*:\\s*\\[([^\\]]*)\\]"));
        static const QRegularExpression quoted(QStringLiteral("\"([^\"]+)\""));
        for (auto it = many.globalMatch(shortcuts); it.hasNext();)
        {
            for (auto q = quoted.globalMatch(it.next().captured(1)); q.hasNext();)
                literals.append(q.next().captured(1));
        }
        QVERIFY2(literals.size() > 15, "no key literal found in GlobalShortcuts.qml: did its syntax change?");

        QStringList missing;
        for (const QString& literal : literals)
        {
            if (!listed.contains(normalize(literal)))
                missing.append(literal);
        }
        QVERIFY2(missing.isEmpty(), qPrintable(QStringLiteral("not in ShellKeys.qml: ") + missing.join(QLatin1String(", "))));
    }
};

QTEST_GUILESS_MAIN(TestShellKeysSync)
#include "test_shell_keys_sync.moc"
