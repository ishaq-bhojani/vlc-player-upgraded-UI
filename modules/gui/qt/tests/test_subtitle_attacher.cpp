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

#include <QDir>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include <QThreadPool>

#include <algorithm>
#include <deque>

#include "../redesign/cpp/subtitleattacher.hpp"

namespace
{

// The media library: a table, and the calls it received. Answers at once unless `defer` is set,
// in which case the answers wait in `pending` until the test runs them (a slow ML thread).
struct FakeLibrary
{
    QHash<QString, QStringList> subtitles; // media mrl -> saved subtitle files
    bool addSucceeds = true;
    bool defer = false;
    QStringList lookups;                   // the mrls asked for, in order
    QList<QPair<QString, QString>> adds;   // (media, subtitle) saved, in order
    std::deque<std::function<void()>> pending;

    void answer(std::function<void()> fn)
    {
        if (defer)
            pending.push_back(std::move(fn));
        else
            fn();
    }

    void flush()
    {
        while (!pending.empty())
        {
            auto fn = std::move(pending.front());
            pending.pop_front();
            fn();
        }
    }
};

class FakeStore : public SubtitleStore
{
public:
    explicit FakeStore(FakeLibrary* library) : m_library(library) {}

    void subtitles(const QString& mrl, std::function<void(QStringList)> done) override
    {
        m_library->lookups.append(mrl);
        const QStringList result = m_library->subtitles.value(mrl);
        m_library->answer([done = std::move(done), result] { done(result); });
    }

    void add(const QString& mrl, const QString& subtitle, std::function<void(bool)> done) override
    {
        m_library->adds.append({mrl, subtitle});
        const bool ok = m_library->addSucceeds;
        m_library->answer([done = std::move(done), ok] { done(ok); });
    }

private:
    FakeLibrary* m_library;
};

// The player and the play queue.
struct FakePlayer
{
    QString current;                       // address of the media being played
    QStringList queue;                     // the play queue
    QStringList slaves;                    // the subtitle files the item being played has
    bool ready = true;                     // the player takes subtitles
    QList<QPair<QString, bool>> added;     // (subtitle, select) given to the media being played
    QList<bool> notified;                  // the notify flag of each of them
    QList<QPair<int, QString>> queueAdds;  // (index, subtitle) given to queue items

    SubtitleEnvironment environment()
    {
        SubtitleEnvironment env;
        env.addToCurrent = [this](const QString& mrl, bool select, bool notify)
        {
            if (!ready)
                return false;
            added.append({mrl, select});
            notified.append(notify);
            slaves.append(mrl); // the player puts what it is given in the item
            return true;
        };
        env.currentSlaves = [this] { return slaves; };
        env.queueUrls = [this] { return queue; };
        env.addToQueueItem = [this](int index, const QString& mrl)
        {
            if (index < 0 || index >= queue.size())
                return false;
            queueAdds.append({index, mrl});
            if (queue[index] == current)
                slaves.append(mrl);
            return true;
        };
        return env;
    }
};

QStringList addedSubtitles(const FakePlayer& player)
{
    QStringList list;
    for (const auto& entry : player.added)
        list.append(entry.first);
    return list;
}

}

class TestSubtitleAttacher : public QObject
{
    Q_OBJECT

private slots:
    // the saved subtitles come back: each is added once, silently, and the last one saved is shown
    void storedSubtitlesAreAttachedOnce()
    {
        FakeLibrary library;
        library.subtitles["file:///v/a.mkv"] = {"file:///v/a.en.srt", "file:///v/a.fr.srt"};
        FakePlayer player;
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        attacher.onInputChanged(true, "file:///v/a.mkv");

        // the library answered, but the input has not loaded the slaves of its item yet
        QCOMPARE(library.lookups, QStringList{"file:///v/a.mkv"});
        QVERIFY(player.added.isEmpty());

        attacher.onPlaying();
        QCOMPARE(addedSubtitles(player), (QStringList{"file:///v/a.en.srt", "file:///v/a.fr.srt"}));
        QCOMPARE(player.added[0].second, false);
        QCOMPARE(player.added[1].second, true);
        QCOMPARE(player.notified, (QList<bool>{false, false}));

        // nothing more happens by itself, nor when the state changes again (pause, play)
        attacher.onPlaying();
        attacher.onPlaying();
        QCOMPARE(player.added.size(), 2);
    }

    // one change of input, one attach: a second media gets its own, the first is not repeated
    void oncePerInputChange()
    {
        FakeLibrary library;
        library.subtitles["file:///v/a.mkv"] = {"file:///v/a.srt"};
        library.subtitles["file:///v/b.mkv"] = {"file:///v/b.srt"};
        FakePlayer player;
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        attacher.onInputChanged(true, "file:///v/a.mkv");
        attacher.onPlaying();
        player.slaves.clear(); // another media: another item
        attacher.onInputChanged(true, "file:///v/b.mkv");
        attacher.onPlaying();
        QCOMPARE(addedSubtitles(player), (QStringList{"file:///v/a.srt", "file:///v/b.srt"}));

        // the same media played again from a new queue entry is a new input: attached again, once
        attacher.onInputChanged(false, QString());
        player.slaves.clear();
        attacher.onInputChanged(true, "file:///v/b.mkv");
        attacher.onPlaying();
        attacher.onPlaying();
        QCOMPARE(addedSubtitles(player),
                 (QStringList{"file:///v/a.srt", "file:///v/b.srt", "file:///v/b.srt"}));
    }

    // the library answers late: only the answer for the media now playing counts
    void lateAnswerOfPreviousMediaIsDropped()
    {
        FakeLibrary library;
        library.defer = true;
        library.subtitles["file:///v/a.mkv"] = {"file:///v/a.srt"};
        library.subtitles["file:///v/b.mkv"] = {"file:///v/b.srt"};
        FakePlayer player;
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        attacher.onInputChanged(true, "file:///v/a.mkv");
        attacher.onInputChanged(true, "file:///v/b.mkv");
        QVERIFY(player.added.isEmpty()); // nothing is waited for
        library.flush();
        attacher.onPlaying();

        QCOMPARE(addedSubtitles(player), QStringList{"file:///v/b.srt"});
    }

    // the media stopped before the library answered
    void answerAfterStopIsDropped()
    {
        FakeLibrary library;
        library.defer = true;
        library.subtitles["file:///v/a.mkv"] = {"file:///v/a.srt"};
        FakePlayer player;
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        attacher.onInputChanged(true, "file:///v/a.mkv");
        attacher.onInputChanged(false, QString());
        library.flush();
        attacher.onPlaying();

        QVERIFY(player.added.isEmpty());
    }

    // no media library: nothing is looked up, nothing is added
    void nothingWithoutLibrary()
    {
        FakePlayer player;
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());

        QVERIFY(!attacher.hasStore());
        attacher.onInputChanged(true, "file:///v/a.mkv");
        attacher.onPlaying();

        QVERIFY(player.added.isEmpty());
    }

    // streams are never in the library: no lookup
    void remoteMediaIsNotLookedUp()
    {
        FakeLibrary library;
        FakePlayer player;
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        attacher.onInputChanged(true, "http://example.org/a.m3u8");
        attacher.onInputChanged(true, QString());

        QVERIFY(library.lookups.isEmpty());
    }

    // a subtitle the user added while the library was answering is not added a second time
    void alreadyAttachedIsSkipped()
    {
        FakeLibrary library;
        library.defer = true;
        library.subtitles["file:///v/a.mkv"] = {"file:///v/My%20Sub.srt", "file:///v/b.srt"};
        FakePlayer player;
        player.current = "file:///v/a.mkv";
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        attacher.onInputChanged(true, "file:///v/a.mkv");
        QVERIFY(attacher.attachToCurrent(QUrl("file:///v/My Sub.srt"))); // another spelling
        library.flush();
        attacher.onPlaying();

        QCOMPARE(addedSubtitles(player), (QStringList{"file:///v/My%20Sub.srt", "file:///v/b.srt"}));
    }

    // the player was not ready: it is asked again, and nothing is added twice
    void refusedSubtitleIsRetriedOnce()
    {
        FakeLibrary library;
        library.subtitles["file:///v/a.mkv"] = {"file:///v/a.srt"};
        FakePlayer player;
        player.ready = false;
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        attacher.onInputChanged(true, "file:///v/a.mkv");
        attacher.onPlaying(); // the player is not ready
        QVERIFY(player.added.isEmpty());

        player.ready = true;
        attacher.onPlaying();
        attacher.onPlaying();

        QCOMPARE(addedSubtitles(player), QStringList{"file:///v/a.srt"});
    }

    // what was waiting for the previous media is not added to the next one
    void pendingIsDroppedWithTheInput()
    {
        FakeLibrary library;
        library.subtitles["file:///v/a.mkv"] = {"file:///v/a.srt"};
        FakePlayer player;
        player.ready = false;
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        attacher.onInputChanged(true, "file:///v/a.mkv");
        attacher.onInputChanged(true, "file:///v/other.mkv"); // nothing saved for it
        player.ready = true;
        attacher.onPlaying();

        QVERIFY(player.added.isEmpty());
    }

    // The item already has the subtitle (a queue entry that got it before, or the input read it):
    // the input does not deduplicate, so it is not added again.
    void subtitleTheItemAlreadyHasIsSkipped()
    {
        FakeLibrary library;
        library.subtitles["file:///v/a.mkv"] = {"file:///v/a.srt"};
        FakePlayer player;
        player.slaves = {"file:///v/a.srt"};
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        attacher.onInputChanged(true, "file:///v/a.mkv");
        attacher.onPlaying();

        QVERIFY(player.added.isEmpty());
    }

    // another spelling of the same address counts as present
    void presentSubtitleIsComparedByAddress()
    {
        FakeLibrary library;
        library.subtitles["file:///v/a.mkv"] = {"file:///v/My%20Sub.srt"};
        FakePlayer player;
        player.slaves = {"file:///v/My Sub.srt"};
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        attacher.onInputChanged(true, "file:///v/a.mkv");
        attacher.onPlaying();

        QVERIFY(player.added.isEmpty());
    }

    // The item lacks it: added once. The same entry played again has it (the player put it in
    // the item): no second copy.
    void secondReplayOfTheSameEntryAddsNothing()
    {
        FakeLibrary library;
        library.subtitles["file:///v/a.mkv"] = {"file:///v/a.srt"};
        FakePlayer player;
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        attacher.onInputChanged(true, "file:///v/a.mkv");
        attacher.onPlaying();
        QCOMPARE(addedSubtitles(player), QStringList{"file:///v/a.srt"});

        attacher.onInputChanged(false, QString());
        attacher.onInputChanged(true, "file:///v/a.mkv"); // the same entry: its item kept the slave
        attacher.onPlaying();
        QCOMPARE(player.added.size(), 1);
    }

    // The input re-adds the slaves of its item while it starts: when the library answers before
    // that, the check is made when the media plays, not when the answer comes.
    void slavesLoadedAfterTheAnswerAreSeen()
    {
        FakeLibrary library;
        library.subtitles["file:///v/a.mkv"] = {"file:///v/a.srt"};
        FakePlayer player;
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        attacher.onInputChanged(true, "file:///v/a.mkv"); // answered at once
        player.slaves = {"file:///v/a.srt"};              // the input loads the item's slaves
        attacher.onPlaying();

        QVERIFY(player.added.isEmpty());
    }

    // attachToPlaylist on the media being played gives the file to the player (and so to its item);
    // the later answer of the library for that media must not add it a second time
    void playlistAttachOfTheCurrentMediaIsNotRepeatedByTheLibrary()
    {
        FakeLibrary library;
        library.defer = true;
        library.subtitles["file:///v/a.mkv"] = {"file:///v/a.srt"};
        FakePlayer player;
        player.queue = {"file:///v/a.mkv", "file:///v/b.mkv"};
        player.current = "file:///v/a.mkv";
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        attacher.onInputChanged(true, "file:///v/a.mkv");
        QVariantList pairs;
        pairs << QVariantMap{{"index", 0}, {"subtitle", QUrl("file:///v/a.srt")}};
        QCOMPARE(attacher.attachToPlaylist(pairs), 1);
        library.flush();
        attacher.onPlaying();

        QCOMPARE(player.queueAdds.size(), 1);
        QVERIFY(player.added.isEmpty());
    }

    // the same with an environment that does not show the slave in the item: the attacher's own
    // memory of what it attached stops the second add
    void playlistAttachRemembersTheCurrentMedia()
    {
        FakeLibrary library;
        library.defer = true;
        library.subtitles["file:///v/a.mkv"] = {"file:///v/a.srt"};
        FakePlayer player;
        player.queue = {"file:///v/a.mkv"};
        player.current = "file:///v/a.mkv";
        SubtitleEnvironment env = player.environment();
        env.addToQueueItem = [&player](int index, const QString& mrl)
        {
            player.queueAdds.append({index, mrl});
            return true;
        };
        SubtitleAttacher attacher;
        attacher.setEnvironment(env);
        attacher.setStore(std::make_unique<FakeStore>(&library));

        attacher.onInputChanged(true, "file:///v/a.mkv");
        QVariantList pairs;
        pairs << QVariantMap{{"index", 0}, {"subtitle", QUrl("file:///v/a.srt")}};
        QCOMPARE(attacher.attachToPlaylist(pairs), 1);
        library.flush();
        attacher.onPlaying();

        QVERIFY(player.added.isEmpty());
    }

    void attachToCurrentSelectsAndSaves()
    {
        FakeLibrary library;
        FakePlayer player;
        player.current = "file:///v/a.mkv";
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));
        attacher.onInputChanged(true, "file:///v/a.mkv");

        QSignalSpy persisted(&attacher, &SubtitleAttacher::persisted);
        QVERIFY(attacher.attachToCurrent(QUrl("file:///v/a.en.srt")));

        QCOMPARE(player.added.size(), 1);
        QCOMPARE(player.added[0].first, QString("file:///v/a.en.srt"));
        QVERIFY(player.added[0].second);
        QCOMPARE(player.notified, QList<bool>{true});
        QCOMPARE(library.adds.size(), 1);
        QCOMPARE(library.adds[0].first, QString("file:///v/a.mkv"));
        QCOMPARE(library.adds[0].second, QString("file:///v/a.en.srt"));
        QCOMPARE(persisted.count(), 1);
        QCOMPARE(persisted[0][2].toBool(), true);
    }

    // a file with characters that are special in an address is given to the player encoded
    void attachToCurrentEncodesTheAddress()
    {
        FakePlayer player;
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());

        QVERIFY(attacher.attachToCurrent(QUrl::fromLocalFile("/v/a #1.srt")));
        QCOMPARE(player.added[0].first, QString("file:///v/a%20%231.srt"));
    }

    // without a library the subtitle is still added; only the saving is skipped
    void attachToCurrentWithoutLibrary()
    {
        FakePlayer player;
        player.current = "file:///v/a.mkv";
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());

        QVERIFY(attacher.attachToCurrent(QUrl("file:///v/a.srt")));
        QCOMPARE(player.added.size(), 1);
        QVERIFY(!attacher.persist(QUrl("file:///v/a.mkv"), QUrl("file:///v/a.srt")));
    }

    void attachToCurrentRefusedIsNotSaved()
    {
        FakeLibrary library;
        FakePlayer player;
        player.ready = false;
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));
        attacher.onInputChanged(true, "file:///v/a.mkv");

        QVERIFY(!attacher.attachToCurrent(QUrl("file:///v/a.srt")));
        QVERIFY(library.adds.isEmpty());
    }

    // the library says the media is not in it: reported, never blocks or fails the attach
    void persistReportsAMediaNotInTheLibrary()
    {
        FakeLibrary library;
        library.addSucceeds = false;
        FakePlayer player;
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        QSignalSpy persisted(&attacher, &SubtitleAttacher::persisted);
        QVERIFY(attacher.persist(QUrl("file:///v/a.mkv"), QUrl("file:///v/a.srt")));
        QCOMPARE(persisted.count(), 1);
        QCOMPARE(persisted[0][2].toBool(), false);
    }

    void persistIgnoresRemoteMedia()
    {
        FakeLibrary library;
        SubtitleAttacher attacher;
        attacher.setStore(std::make_unique<FakeStore>(&library));

        QVERIFY(!attacher.persist(QUrl("http://example.org/a.mkv"), QUrl("file:///v/a.srt")));
        QVERIFY(!attacher.persist(QUrl(), QUrl("file:///v/a.srt")));
        QVERIFY(!attacher.persist(QUrl("file:///v/a.mkv"), QUrl()));
        QVERIFY(library.adds.isEmpty());
    }

    void attachToPlaylistAddsAndSaves()
    {
        FakeLibrary library;
        FakePlayer player;
        player.queue = {"file:///v/a.mkv", "file:///v/b.mkv", "file:///v/c.mkv"};
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());
        attacher.setStore(std::make_unique<FakeStore>(&library));

        QVariantList pairs;
        pairs << QVariantMap{{"index", 0}, {"subtitle", QUrl("file:///v/a.srt")}};
        pairs << QVariantMap{{"index", 2}, {"subtitle", QUrl("file:///v/c.srt")},
                             {"video", QUrl("file:///v/c.mkv")}};

        QCOMPARE(attacher.attachToPlaylist(pairs), 2);
        QCOMPARE(player.queueAdds.size(), 2);
        QCOMPARE(player.queueAdds[0], qMakePair(0, QString("file:///v/a.srt")));
        QCOMPARE(player.queueAdds[1], qMakePair(2, QString("file:///v/c.srt")));
        QCOMPARE(library.adds.size(), 2);
        QCOMPARE(library.adds[0], qMakePair(QString("file:///v/a.mkv"), QString("file:///v/a.srt")));
        QCOMPARE(library.adds[1], qMakePair(QString("file:///v/c.mkv"), QString("file:///v/c.srt")));
    }

    // a bad pair is skipped and does not stop the others
    void attachToPlaylistSkipsBadPairs()
    {
        FakePlayer player;
        player.queue = {"file:///v/a.mkv", "file:///v/b.mkv"};
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());

        QVariantList pairs;
        pairs << QVariantMap{{"index", 7}, {"subtitle", QUrl("file:///v/x.srt")}};      // out of range
        pairs << QVariantMap{{"index", -1}, {"subtitle", QUrl("file:///v/x.srt")}};     // negative
        pairs << QVariantMap{{"index", 0}, {"subtitle", QUrl()}};                       // no subtitle
        pairs << QVariantMap{{"index", 0}, {"subtitle", QUrl("file:///v/a.srt")},
                             {"video", QUrl("file:///v/other.mkv")}};                   // queue changed
        pairs << QVariant(42);                                                          // not a pair
        pairs << QVariantMap{{"index", 1}, {"subtitle", QUrl("file:///v/b.srt")}};

        QCOMPARE(attacher.attachToPlaylist(pairs), 1);
        QCOMPARE(player.queueAdds.size(), 1);
        QCOMPARE(player.queueAdds[0], qMakePair(1, QString("file:///v/b.srt")));
    }

    void playlistUrls()
    {
        FakePlayer player;
        player.queue = {"file:///v/a.mkv", "file:///v/My%20Show/b.mkv"};
        SubtitleAttacher attacher;
        attacher.setEnvironment(player.environment());

        const QVariantList urls = attacher.playlistUrls();
        QCOMPARE(urls.size(), 2);
        QCOMPARE(urls[1].toUrl(), QUrl("file:///v/My%20Show/b.mkv"));
        QCOMPARE(urls[1].toUrl().toLocalFile(), QString("/v/My Show/b.mkv"));
    }

    void folderOf()
    {
        SubtitleAttacher attacher;
        // an absolute path of this system: "/v" is not one on Windows
        const QString folder = QDir(QDir::tempPath()).filePath("My Show");
        QCOMPARE(attacher.folderOf(QUrl::fromLocalFile(folder + "/b.mkv")), folder);
        QCOMPARE(attacher.folderOf(QUrl("http://example.org/a.mkv")), QString());
        QCOMPARE(attacher.folderOf(QUrl()), QString());
    }

    void extensionLists()
    {
        const QStringList videos = SubtitleAttacher::videoExtensions();
        const QStringList subtitles = SubtitleAttacher::subtitleExtensions();
        QVERIFY(videos.contains("mkv"));
        QVERIFY(videos.contains("mp4"));
        QVERIFY(!videos.contains("srt"));
        QVERIFY(subtitles.contains("srt"));
        QVERIFY(subtitles.contains("ass"));
        QVERIFY(!subtitles.contains("mkv"));
        for (const QString& ext : videos + subtitles)
        {
            QVERIFY(!ext.isEmpty());
            QVERIFY(!ext.contains('*'));
            QVERIFY(!ext.contains('.'));
            QCOMPARE(ext, ext.toLower());
        }
    }

    void listFolder()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        for (const char* name : {"S01E10.mkv", "S01E02.mkv", "s01e01.MP4", "S01E02.srt", "S01E10.en.srt",
                                 "notes.pdf", "cover.jpg"})
        {
            QFile file(dir.filePath(name));
            QVERIFY(file.open(QIODevice::WriteOnly));
        }
        QVERIFY(QDir(dir.path()).mkdir("sub"));
        QFile nested(dir.filePath("sub/S01E03.mkv")); // not looked at
        QVERIFY(nested.open(QIODevice::WriteOnly));
        QVERIFY(QDir(dir.path()).mkdir("folder.mkv")); // a folder is not a video
        nested.close();

        const SubtitleAttacher attacher;
        const QVariantMap result = attacher.listFolder(QUrl::fromLocalFile(dir.path()));

        QCOMPARE(result["error"].toString(), QString());
        QCOMPARE(result["truncated"].toBool(), false);

        QStringList videos;
        for (const QVariant& entry : result["videos"].toList())
            videos.append(entry.toMap()["name"].toString());
        // numbers compare as numbers, the case does not matter
        QCOMPARE(videos, (QStringList{"s01e01.MP4", "S01E02.mkv", "S01E10.mkv"}));

        QStringList subtitles;
        for (const QVariant& entry : result["subtitles"].toList())
            subtitles.append(entry.toMap()["name"].toString());
        QCOMPARE(subtitles, (QStringList{"S01E02.srt", "S01E10.en.srt"}));

        const QVariantMap first = result["videos"].toList().first().toMap();
        QCOMPARE(first["url"].toUrl(), QUrl::fromLocalFile(dir.filePath("s01e01.MP4")));
    }

    void listFolderIsCapped()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        for (int i = 1; i <= 5; ++i)
        {
            QFile video(dir.filePath(QString("v%1.mkv").arg(i)));
            QVERIFY(video.open(QIODevice::WriteOnly));
        }
        QFile sub(dir.filePath("v1.srt"));
        QVERIFY(sub.open(QIODevice::WriteOnly));

        const QVariantMap result = SubtitleAttacher::listFolder(dir.path(), 3);

        QCOMPARE(result["videos"].toList().size(), 3);
        QCOMPARE(result["subtitles"].toList().size(), 1);
        QCOMPARE(result["truncated"].toBool(), true);
        QCOMPARE(result["videos"].toList().first().toMap()["name"].toString(), QString("v1.mkv"));
    }

    void requestFolderAnswersLater()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        for (const char* name : {"b.mkv", "a.mkv", "a.srt"})
        {
            QFile file(dir.filePath(name));
            QVERIFY(file.open(QIODevice::WriteOnly));
        }

        SubtitleAttacher attacher;
        QSignalSpy spy(&attacher, &SubtitleAttacher::folderListed);
        const int first = attacher.requestFolder(QUrl::fromLocalFile(dir.path()));
        const int second = attacher.requestFolder(QUrl::fromLocalFile(dir.path()));
        QVERIFY(second != first);
        QCOMPARE(spy.count(), 0); // never before the call returned

        QTRY_COMPARE(spy.count(), 2);
        QList<int> ids;
        for (const auto& args : spy)
        {
            ids.append(args[0].toInt());
            const QVariantMap result = args[1].toMap();
            QCOMPARE(result["error"].toString(), QString());
            QCOMPARE(result["videos"].toList().size(), 2);
            QCOMPARE(result["videos"].toList().first().toMap()["name"].toString(), QString("a.mkv"));
            QCOMPARE(result["subtitles"].toList().size(), 1);
        }
        std::sort(ids.begin(), ids.end());
        QCOMPARE(ids, (QList<int>{first, second}));
    }

    void requestFolderErrorsAreAnswered()
    {
        SubtitleAttacher attacher;
        QSignalSpy spy(&attacher, &SubtitleAttacher::folderListed);

        const int remote = attacher.requestFolder(QUrl("http://example.org/dir"));
        QCOMPARE(spy.count(), 0);
        QTRY_COMPARE(spy.count(), 1);
        QCOMPARE(spy[0][0].toInt(), remote);
        QVERIFY(!spy[0][1].toMap()["error"].toString().isEmpty());

        const int missing = attacher.requestFolder(QUrl::fromLocalFile("/this/folder/does/not/exist"));
        QTRY_COMPARE(spy.count(), 2);
        QCOMPARE(spy[1][0].toInt(), missing);
        QVERIFY(!spy[1][1].toMap()["error"].toString().isEmpty());
    }

    // an attacher destroyed while the worker reads: the answer is dropped, nothing crashes
    void requestFolderAfterDestruction()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        {
            SubtitleAttacher attacher;
            attacher.requestFolder(QUrl::fromLocalFile(dir.path()));
        }
        QCoreApplication::processEvents();
        QThreadPool::globalInstance()->waitForDone();
        QCoreApplication::processEvents();
    }

    void listFolderErrors()
    {
        const SubtitleAttacher attacher;
        QVariantMap result = attacher.listFolder(QUrl("http://example.org/dir"));
        QVERIFY(!result["error"].toString().isEmpty());
        QVERIFY(result["videos"].toList().isEmpty());

        result = attacher.listFolder(QUrl::fromLocalFile("/this/folder/does/not/exist"));
        QVERIFY(!result["error"].toString().isEmpty());

        result = attacher.listFolder(QUrl());
        QVERIFY(!result["error"].toString().isEmpty());
    }
};

QTEST_GUILESS_MAIN(TestSubtitleAttacher)
#include "test_subtitle_attacher.moc"
