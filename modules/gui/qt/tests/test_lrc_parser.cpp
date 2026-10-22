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

#include <QTest>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QDir>
#include <QFile>
#include <QUrl>
#include <QVariantMap>

#include <vlc_common.h>
#include <vlc_tick.h>

#include "../redesign/cpp/lrcparser.hpp"
#include "../redesign/cpp/sidecarlyrics.hpp"

using redesign::parseLrc;
using redesign::lineIndexAt;
using redesign::decodeLrc;

class TestLrcParser : public QObject
{
    Q_OBJECT

private:
    static void writeFile(const QString& path, const QByteArray& data)
    {
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(data);
    }

private slots:
    void simpleStamp()
    {
        const auto lines = parseLrc("[01:02.50]Hello");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].timeMs, qint64(62500));
        QCOMPARE(lines[0].text, QString("Hello"));
    }

    void twoStampsOnOneLine()
    {
        const auto lines = parseLrc("[00:10.00][00:20.00]Chorus");
        QCOMPARE(lines.size(), 2);
        QCOMPARE(lines[0].timeMs, qint64(10000));
        QCOMPARE(lines[1].timeMs, qint64(20000));
        QCOMPARE(lines[0].text, QString("Chorus"));
        QCOMPARE(lines[1].text, QString("Chorus"));
    }

    void sortedByTime()
    {
        const auto lines = parseLrc("[00:30.00]c\n[00:10.00]a\n[00:20.00]b");
        QCOMPARE(lines.size(), 3);
        QCOMPARE(lines[0].text, QString("a"));
        QCOMPARE(lines[1].text, QString("b"));
        QCOMPARE(lines[2].text, QString("c"));
    }

    void sameTimeKeepsFileOrder()
    {
        const auto lines = parseLrc("[00:10.00]first\n[00:10.00]second");
        QCOMPARE(lines.size(), 2);
        QCOMPARE(lines[0].text, QString("first"));
        QCOMPARE(lines[1].text, QString("second"));
    }

    void offsetPositiveShiftsEarlier()
    {
        const auto lines = parseLrc("[offset:500]\n[00:10.00]a\n[00:20.00]b");
        QCOMPARE(lines.size(), 2);
        QCOMPARE(lines[0].timeMs, qint64(9500));
        QCOMPARE(lines[1].timeMs, qint64(19500));
    }

    void offsetNegativeShiftsLater()
    {
        const auto lines = parseLrc("[offset:-500]\n[00:10.00]a");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].timeMs, qint64(10500));
    }

    void offsetAfterTheLinesStillApplies()
    {
        const auto lines = parseLrc("[00:10.00]a\n[offset:+250]");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].timeMs, qint64(9750));
    }

    void offsetNeverGoesBelowZero()
    {
        const auto lines = parseLrc("[offset:5000]\n[00:01.00]a");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].timeMs, qint64(0));
    }

    void metadataTagsIgnored()
    {
        const auto lines = parseLrc("[ar:Artist]\n[ti:Title]\n[al:Album]\n[by:Me]\n[length:03:00]\n[00:05.00]Text");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].text, QString("Text"));
    }

    void linesWithoutStampsSkipped()
    {
        const auto lines = parseLrc("just text\n\n[00:05.00]Text\nmore text");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].text, QString("Text"));
    }

    void crlfAndCrLineEndings()
    {
        auto lines = parseLrc("[00:01.00]a\r\n[00:02.00]b\r\n");
        QCOMPARE(lines.size(), 2);
        QCOMPARE(lines[0].text, QString("a"));
        QCOMPARE(lines[1].text, QString("b"));
        lines = parseLrc("[00:01.00]a\r[00:02.00]b");
        QCOMPARE(lines.size(), 2);
        QCOMPARE(lines[1].text, QString("b"));
    }

    void stampWithEmptyTextIsKeptAsEmptyLine()
    {
        // an empty line ends the previous line (instrumental break)
        const auto lines = parseLrc("[00:01.00]a\n[00:05.00]\n[00:09.00]b");
        QCOMPARE(lines.size(), 3);
        QCOMPARE(lines[1].timeMs, qint64(5000));
        QVERIFY(lines[1].text.isEmpty());
    }

    void stampWithoutCentiseconds()
    {
        const auto lines = parseLrc("[01:02]a");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].timeMs, qint64(62000));
    }

    void stampFractionDigits()
    {
        QCOMPARE(parseLrc("[00:01.5]a")[0].timeMs, qint64(1500));
        QCOMPARE(parseLrc("[00:01.50]a")[0].timeMs, qint64(1500));
        QCOMPARE(parseLrc("[00:01.567]a")[0].timeMs, qint64(1567));
        QCOMPARE(parseLrc("[00:01.05]a")[0].timeMs, qint64(1050));
    }

    void minutesAboveSixty()
    {
        QCOMPARE(parseLrc("[75:00.00]a")[0].timeMs, qint64(75 * 60 * 1000));
    }

    void malformedStampIgnored()
    {
        QVERIFY(parseLrc("[1:xx]a").isEmpty());
        QVERIFY(parseLrc("[00:75.00]a").isEmpty());   // seconds out of range
        QVERIFY(parseLrc("[00:01.0000]a").isEmpty()); // too many fraction digits
        QVERIFY(parseLrc("[:01.00]a").isEmpty());
        QVERIFY(parseLrc("[00:01.00a").isEmpty());    // never closed
        QVERIFY(parseLrc("[bad][00:10.00]a").isEmpty());  // the stamps are at the start of the line
        // a bad group after a good stamp is part of the text
        const auto lines = parseLrc("[00:10.00][bad]Hi");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].timeMs, qint64(10000));
        QCOMPARE(lines[0].text, QString("[bad]Hi"));
    }

    void blanksBetweenStamps()
    {
        const auto lines = parseLrc("[00:01.00] [00:02.00]   text");
        QCOMPARE(lines.size(), 2);
        QCOMPARE(lines[0].timeMs, qint64(1000));
        QCOMPARE(lines[1].timeMs, qint64(2000));
        QCOMPARE(lines[0].text, QString("text"));
        QCOMPARE(lines[1].text, QString("text"));
    }

    void bracketGroupAfterStampsIsText()
    {
        auto lines = parseLrc("[00:10.00][Chorus] la la");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].text, QString("[Chorus] la la"));
        lines = parseLrc("[00:10.00] [Chorus] la");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].text, QString("[Chorus] la"));
        // a stamp after the text is text too
        lines = parseLrc("[00:10.00]a [00:20.00] b");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].text, QString("a [00:20.00] b"));
    }

    void tagsOnlyOnLinesWithoutStamps()
    {
        // metadata and offset after a stamp are text, they change nothing
        const auto lines = parseLrc("[00:05.00][offset:500]x\n[00:06.00][ti:Hello]y");
        QCOMPARE(lines.size(), 2);
        QCOMPARE(lines[0].timeMs, qint64(5000));
        QCOMPARE(lines[0].text, QString("[offset:500]x"));
        QCOMPARE(lines[1].text, QString("[ti:Hello]y"));
    }

    void metadataTagsBeforeTheStampsAreSkipped()
    {
        auto lines = parseLrc("[ti:X][00:01.00]Hello");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].timeMs, qint64(1000));
        QCOMPARE(lines[0].text, QString("Hello"));
        lines = parseLrc("[ar:A] [by:B][length:03:00][00:02.00]Hi");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].timeMs, qint64(2000));
        QCOMPARE(lines[0].text, QString("Hi"));
        // an unknown group before the stamps: not a lyric line
        QVERIFY(parseLrc("[ti:X][bad][00:01.00]Hello").isEmpty());
    }

    void offsetBeforeTheStampsIsAppliedOnce()
    {
        const auto lines = parseLrc("[offset:500][00:02.00]Hi\n[00:04.00]Yo");
        QCOMPARE(lines.size(), 2);
        QCOMPARE(lines[0].timeMs, qint64(1500));
        QCOMPARE(lines[0].text, QString("Hi"));
        QCOMPARE(lines[1].timeMs, qint64(3500));
    }

    void longTextIsCut()
    {
        const QString text(redesign::kMaxLrcLineChars + 500, QChar('x'));
        const auto lines = parseLrc("[00:01.00]" + text);
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].text.size(), redesign::kMaxLrcLineChars);
        // exactly at the limit: kept whole
        const QString exact(redesign::kMaxLrcLineChars, QChar('y'));
        QCOMPARE(parseLrc("[00:01.00]" + exact)[0].text, exact);
    }

    void lineCountAtTheCapIsKept()
    {
        QString big;
        for (int i = 0; i < redesign::kMaxLrcLines; ++i)
            big += QString("[%1:00.00]x\n").arg(i % 100, 2, 10, QChar('0'));
        QCOMPARE(parseLrc(big).size(), redesign::kMaxLrcLines);
    }

    void textIsTrimmedAndKeepsInnerBrackets()
    {
        const auto lines = parseLrc("[00:01.00]   a [b] c  ");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].text, QString("a [b] c"));
    }

    void wordTimestampsStripped()
    {
        const auto lines = parseLrc("[00:01.00]<00:01.00>Hel<00:01.50>lo");
        QCOMPARE(lines.size(), 1);
        QCOMPARE(lines[0].text, QString("Hello"));
    }

    void leadingBomIgnored()
    {
        const auto lines = parseLrc(QString(QChar(0xFEFF)) + "[00:01.00]a");
        QCOMPARE(lines.size(), 1);
    }

    void lineCountIsCapped()
    {
        QString big;
        for (int i = 0; i < redesign::kMaxLrcLines + 500; ++i)
            big += QString("[%1:00.00]x\n").arg(i % 100, 2, 10, QChar('0'));
        QCOMPARE(parseLrc(big).size(), redesign::kMaxLrcLines);
    }

    void lineIndexAtBoundaries()
    {
        const auto lines = parseLrc("[00:10.00]a\n[00:20.00]b\n[00:30.00]c");
        QCOMPARE(lineIndexAt(lines, 0), -1);
        QCOMPARE(lineIndexAt(lines, 9999), -1);
        QCOMPARE(lineIndexAt(lines, 10000), 0);   // exact stamp
        QCOMPARE(lineIndexAt(lines, 15000), 0);   // between stamps
        QCOMPARE(lineIndexAt(lines, 20000), 1);
        QCOMPARE(lineIndexAt(lines, 29999), 1);
        QCOMPARE(lineIndexAt(lines, 99999999), 2); // after the last
        QCOMPARE(lineIndexAt({}, 1000), -1);
    }

    void lineIndexAtDuplicateStampsGivesLast()
    {
        const auto lines = parseLrc("[00:10.00]a\n[00:10.00]b");
        QCOMPARE(lineIndexAt(lines, 10000), 1);
    }

    void decodeUtf8()
    {
        const QString expected = QString::fromUtf8("caf\xC3\xA9");
        QCOMPARE(decodeLrc(expected.toUtf8()), expected);
    }

    void decodeUtf8WithBom()
    {
        const QString s = decodeLrc(QByteArray("\xEF\xBB\xBF[00:01.00]caf\xC3\xA9"));
        QVERIFY(!s.startsWith(QChar(0xFEFF)));
        QCOMPARE(parseLrc(s).size(), 1);
        QCOMPARE(parseLrc(s)[0].text, QString::fromUtf8("caf\xC3\xA9"));
    }

    void decodeLatin1Fallback()
    {
        // 0xE9 alone is not valid UTF-8
        const QString s = decodeLrc(QByteArray("[00:01.00]caf\xE9"));
        QCOMPARE(parseLrc(s)[0].text, QString::fromUtf8("caf\xC3\xA9"));
    }

    // ----- SidecarLyrics

    void sidecarFindsLrcNextToMedia()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        writeFile(dir.filePath("song.mp3"), "x");
        writeFile(dir.filePath("song.lrc"), "[00:01.00]one\n[00:02.00]two\n");

        SidecarLyrics lyrics;
        QSignalSpy spy(&lyrics, &SidecarLyrics::availableChanged);
        QVERIFY(!lyrics.available());
        lyrics.setMedia(QUrl::fromLocalFile(dir.filePath("song.mp3")));
        QVERIFY(lyrics.available());
        QCOMPARE(spy.count(), 1);
        const QVariantList lines = lyrics.lines();
        QCOMPARE(lines.size(), 2);
        QCOMPARE(lines[0].toMap().value("timeMs").toLongLong(), qint64(1000));
        QCOMPARE(lines[1].toMap().value("text").toString(), QString("two"));
        QCOMPARE(lyrics.indexAt(1500), 0);
        QCOMPARE(lyrics.indexAt(500), -1);

        // a media without lyrics clears them
        lyrics.setMedia(QUrl::fromLocalFile(dir.filePath("other.mp3")));
        QVERIFY(!lyrics.available());
        QVERIFY(lyrics.lines().isEmpty());
        QCOMPARE(lyrics.indexAt(1500), -1);
    }

    void sidecarUppercaseExtension()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        writeFile(dir.filePath("song.flac"), "x");
        writeFile(dir.filePath("song.LRC"), "[00:01.00]one");

        SidecarLyrics lyrics;
        lyrics.setMedia(QUrl::fromLocalFile(dir.filePath("song.flac")));
        QVERIFY(lyrics.available());
    }

    void sidecarMixedCaseExtension()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        writeFile(dir.filePath("song.ogg"), "x");
        writeFile(dir.filePath("song.Lrc"), "[00:01.00]one");

        SidecarLyrics lyrics;
        lyrics.setMedia(QUrl::fromLocalFile(dir.filePath("song.ogg")));
        QVERIFY(lyrics.available());
    }

    void sidecarNonAsciiPath()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString name = QString::fromUtf8("Música é");
        writeFile(dir.filePath(name + ".mp3"), "x");
        writeFile(dir.filePath(name + ".lrc"), "[00:01.00]café");

        SidecarLyrics lyrics;
        lyrics.setMedia(QUrl::fromLocalFile(dir.filePath(name + ".mp3")));
        QVERIFY(lyrics.available());
        QCOMPARE(lyrics.lines()[0].toMap().value("text").toString(), QString::fromUtf8("café"));
    }

    void sidecarBaseNameWithDots()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        writeFile(dir.filePath("a.b.mp3"), "x");
        writeFile(dir.filePath("a.lrc"), "[00:01.00]wrong");
        writeFile(dir.filePath("a.b.lrc"), "[00:01.00]right");

        SidecarLyrics lyrics;
        lyrics.setMedia(QUrl::fromLocalFile(dir.filePath("a.b.mp3")));
        QVERIFY(lyrics.available());
        QCOMPARE(lyrics.lines()[0].toMap().value("text").toString(), QString("right"));
    }

    void sidecarNotForRemoteUrls()
    {
        SidecarLyrics lyrics;
        lyrics.setMedia(QUrl("http://example.com/song.mp3"));
        QVERIFY(!lyrics.available());
        lyrics.setMedia(QUrl("smb://host/share/song.mp3"));
        QVERIFY(!lyrics.available());
        lyrics.setMedia(QUrl());
        QVERIFY(!lyrics.available());
    }

    void sidecarLatin1Fallback()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        writeFile(dir.filePath("song.mp3"), "x");
        writeFile(dir.filePath("song.lrc"), "[00:01.00]caf\xE9");

        SidecarLyrics lyrics;
        lyrics.setMedia(QUrl::fromLocalFile(dir.filePath("song.mp3")));
        QVERIFY(lyrics.available());
        QCOMPARE(lyrics.lines()[0].toMap().value("text").toString(), QString::fromUtf8("caf\xC3\xA9"));
    }

    void sidecarTooBigIgnored()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        writeFile(dir.filePath("song.mp3"), "x");
        QByteArray big = "[00:01.00]a\n";
        big += QByteArray(SidecarLyrics::maxFileSize, ' ');
        writeFile(dir.filePath("song.lrc"), big);

        SidecarLyrics lyrics;
        lyrics.setMedia(QUrl::fromLocalFile(dir.filePath("song.mp3")));
        QVERIFY(!lyrics.available());
    }

    void sidecarExactlyAtTheSizeLimitIsRead()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        writeFile(dir.filePath("song.mp3"), "x");
        QByteArray data = "[00:01.00]a\n";
        data += QByteArray(SidecarLyrics::maxFileSize - data.size(), ' ');
        QCOMPARE(qint64(data.size()), SidecarLyrics::maxFileSize);
        writeFile(dir.filePath("song.lrc"), data);

        SidecarLyrics lyrics;
        lyrics.setMedia(QUrl::fromLocalFile(dir.filePath("song.mp3")));
        QVERIFY(lyrics.available());
    }

    void sidecarOneByteOverTheSizeLimitIgnored()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        writeFile(dir.filePath("song.mp3"), "x");
        QByteArray data = "[00:01.00]a\n";
        data += QByteArray(SidecarLyrics::maxFileSize + 1 - data.size(), ' ');
        writeFile(dir.filePath("song.lrc"), data);

        SidecarLyrics lyrics;
        lyrics.setMedia(QUrl::fromLocalFile(dir.filePath("song.mp3")));
        QVERIFY(!lyrics.available());
    }

    void sidecarWithoutAnyLineIsNotAvailable()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        writeFile(dir.filePath("song.mp3"), "x");
        writeFile(dir.filePath("song.lrc"), "[ti:Only metadata]\nplain text\n");

        SidecarLyrics lyrics;
        lyrics.setMedia(QUrl::fromLocalFile(dir.filePath("song.mp3")));
        QVERIFY(!lyrics.available());
    }

    void sidecarDirectoryNamedLrcIgnored()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        QVERIFY(QDir(dir.path()).mkdir("song.lrc"));
        SidecarLyrics lyrics;
        lyrics.setMedia(QUrl::fromLocalFile(dir.filePath("song.mp3")));
        QVERIFY(!lyrics.available());
    }

    void sidecarTimeConversion()
    {
        // Player.time is a VLCTime: ticks (VLC_TICK_0 based, 1 tick, so this does not tell the
        // offset apart) converted to milliseconds; 62.5 s into the track
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        writeFile(dir.filePath("song.lrc"), "[00:10.00]a\n[01:02.50]b");
        SidecarLyrics lyrics;
        lyrics.setMedia(QUrl::fromLocalFile(dir.filePath("song.mp3")));
        QVERIFY(lyrics.available());

        QCOMPARE(lyrics.indexAtTime(VLCTime(VLC_TICK_0 + VLC_TICK_FROM_MS(62499))), 0);
        QCOMPARE(lyrics.indexAtTime(VLCTime(VLC_TICK_0 + VLC_TICK_FROM_MS(62500))), 1);
        QCOMPARE(lyrics.indexAtTime(VLCTime(VLC_TICK_0 + VLC_TICK_FROM_MS(5000))), -1);
        QCOMPARE(lyrics.indexAtTime(VLCTime(VLC_TICK_INVALID)), -1);
    }
};

QTEST_GUILESS_MAIN(TestLrcParser)
#include "test_lrc_parser.moc"
