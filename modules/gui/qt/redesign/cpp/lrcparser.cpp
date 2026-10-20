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

#include "lrcparser.hpp"

#include <algorithm>

#include <QRegularExpression>
#include <QStringDecoder>

namespace redesign
{

namespace
{

// "mm:ss", "mm:ss.f", "mm:ss.ff", "mm:ss.fff" (or ':' before the fraction)
const QRegularExpression& stampRegex()
{
    static const QRegularExpression re(
        QStringLiteral("^(\\d{1,3}):(\\d{1,2})(?:[.:](\\d{1,3}))?$"));
    return re;
}

const QRegularExpression& offsetRegex()
{
    static const QRegularExpression re(
        QStringLiteral("^\\[offset:\\s*([+-]?\\d{1,9})\\s*\\]"),QRegularExpression::CaseInsensitiveOption);
    return re;
}

bool parseStamp(const QString& tag, qint64* ms)
{
    const QRegularExpressionMatch m = stampRegex().match(tag);
    if (!m.hasMatch())
        return false;
    const qint64 minutes = m.captured(1).toLongLong();
    const qint64 seconds = m.captured(2).toLongLong();
    if (seconds >= 60)
        return false;
    qint64 fraction = 0;
    const QString f = m.captured(3);
    if (!f.isEmpty()) {
        fraction = f.toLongLong();
        // "5" is 500 ms, "50" is 500 ms, "500" is 500 ms
        for (int i = f.size(); i < 3; ++i)
            fraction *= 10;
    }
    *ms = (minutes * 60 + seconds) * 1000 + fraction;
    return true;
}

QString stripWordStamps(const QString& text)
{
    static const QRegularExpression re(QStringLiteral("<\\d{1,3}:\\d{1,2}(?:[.:]\\d{1,3})?>"));
    QString out = text;
    out.remove(re);
    return out;
}

} // namespace

QVector<LrcLine> parseLrc(const QString& content)
{
    QVector<LrcLine> result;
    qint64 offset = 0;

    const QStringList rawLines = content.split(QRegularExpression(QStringLiteral("\\r\\n|\\n|\\r")));
    bool first = true;
    for (QString line : rawLines) {
        if (first) {
            first = false;
            if (line.startsWith(QChar(0xFEFF)))
                line.remove(0, 1);
        }
        line = line.trimmed();

        // the leading time stamps, with or without blanks between them
        QVector<qint64> stamps;
        int pos = 0;
        while (pos < line.size()) {
            int p = pos;
            while (p < line.size() && line[p].isSpace())
                ++p;
            if (p >= line.size() || line[p] != QLatin1Char('['))
                break;
            const int end = line.indexOf(QLatin1Char(']'), p + 1);
            if (end < 0)
                break;
            qint64 value = 0;
            if (!parseStamp(line.mid(p + 1, end - p - 1), &value))
                break;
            stamps.append(value);
            pos = end + 1;
        }

        if (stamps.isEmpty()) {
            // a line without time stamp: the tags ([ti:], [ar:], ...) live here, only [offset:]
            // is of any use
            const QRegularExpressionMatch m = offsetRegex().match(line);
            if (m.hasMatch())
                offset = m.captured(1).toLongLong();
            continue;
        }

        // what follows the stamps is the text, even if it starts with a "[Chorus]"
        QString text = stripWordStamps(line.mid(pos)).trimmed();
        if (text.size() > kMaxLrcLineChars)
            text.truncate(kMaxLrcLineChars);

        for (const qint64 stamp : stamps) {
            if (result.size() >= kMaxLrcLines)
                break;
            result.append({stamp, text});
        }
        if (result.size() >= kMaxLrcLines)
            break;
    }

    // [offset:] may come after the lines: applied once the whole file is read
    if (offset != 0) {
        for (LrcLine& l : result)
            l.timeMs = std::max<qint64>(0, l.timeMs - offset);
    }

    std::stable_sort(result.begin(), result.end(),
                     [](const LrcLine& a, const LrcLine& b) { return a.timeMs < b.timeMs; });
    return result;
}

int lineIndexAt(const QVector<LrcLine>& lines, qint64 ms)
{
    // first line after ms, minus one
    const auto it = std::upper_bound(lines.cbegin(), lines.cend(), ms,
                                     [](qint64 value, const LrcLine& l) { return value < l.timeMs; });
    return int(it - lines.cbegin()) - 1;
}

QString decodeLrc(const QByteArray& data)
{
    QByteArray bytes = data;
    if (bytes.startsWith("\xEF\xBB\xBF"))
        bytes.remove(0, 3);

    QStringDecoder utf8(QStringDecoder::Utf8, QStringDecoder::Flag::Stateless);
    const QString text = utf8.decode(bytes);
    if (!utf8.hasError())
        return text;
    return QString::fromLatin1(bytes);
}

} // namespace redesign
