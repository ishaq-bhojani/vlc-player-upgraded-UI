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

#include <QHash>
#include <QSignalSpy>
#include <QTest>

#include <deque>

#include "../redesign/cpp/currentmediafavorite.hpp"

namespace
{

// In-memory library. Answers at once unless `defer` is set, in which case the
// callbacks wait in `pending` until the test runs them (a slow ML thread).
struct FakeState
{
    QHash<QString, bool> media;
    bool setSucceeds = true;
    bool defer = false;
    int setCalls = 0;
    int lookupCalls = 0;
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

class FakeBackend : public FavoriteBackend
{
public:
    explicit FakeBackend(FakeState* state) : m_state(state) {}

    void lookup(const QString& mrl, std::function<void(std::optional<bool>)> done) override
    {
        ++m_state->lookupCalls;
        std::optional<bool> result;
        if (m_state->media.contains(mrl))
            result = m_state->media.value(mrl);
        m_state->answer([done = std::move(done), result] { done(result); });
    }

    void set(const QString& mrl, bool favorite, std::function<void(bool ok)> done) override
    {
        ++m_state->setCalls;
        const bool ok = m_state->setSucceeds;
        if (ok)
            m_state->media[mrl] = favorite;
        m_state->answer([done = std::move(done), ok] { done(ok); });
    }

private:
    FakeState* m_state;
};

}

class TestCurrentMediaFavorite : public QObject
{
    Q_OBJECT

private slots:
    void unknownMrlIsUnavailable()
    {
        FakeState state; // empty library: every lookup answers nullopt
        CurrentMediaFavorite fav;
        fav.setBackend(std::make_unique<FakeBackend>(&state));
        fav.setMrl("file:///unknown.mp4");

        QVERIFY(!fav.available());
        QVERIFY(!fav.favorite());

        fav.toggle();
        QCOMPARE(state.setCalls, 0);
        QVERIFY(!fav.favorite());
    }

    void toggleFlips()
    {
        FakeState state;
        state.media["file:///a.mp4"] = false;
        CurrentMediaFavorite fav;
        fav.setBackend(std::make_unique<FakeBackend>(&state));
        fav.setMrl("file:///a.mp4");

        QVERIFY(fav.available());
        QVERIFY(!fav.favorite());

        fav.toggle();
        QVERIFY(fav.available());
        QVERIFY(fav.favorite());
        QCOMPARE(state.media.value("file:///a.mp4"), true);

        fav.toggle();
        QVERIFY(!fav.favorite());
        QCOMPARE(state.media.value("file:///a.mp4"), false);
        QCOMPARE(state.setCalls, 2);
    }

    void failedSetReverts()
    {
        FakeState state;
        state.media["file:///a.mp4"] = false;
        state.setSucceeds = false;
        CurrentMediaFavorite fav;
        fav.setBackend(std::make_unique<FakeBackend>(&state));
        fav.setMrl("file:///a.mp4");
        QVERIFY(fav.available());

        QSignalSpy spy(&fav, &CurrentMediaFavorite::stateChanged);
        fav.toggle();

        QVERIFY(!fav.favorite());
        QVERIFY(fav.available());
        QCOMPARE(state.media.value("file:///a.mp4"), false);
        QCOMPARE(spy.count(), 2); // optimistic flip, then revert
    }

    void emptyMrlIsUnavailable()
    {
        FakeState state;
        state.media[""] = true; // even a library that knows "" must not be asked
        CurrentMediaFavorite fav;
        fav.setBackend(std::make_unique<FakeBackend>(&state));
        fav.setMrl("");

        QVERIFY(!fav.available());
        QVERIFY(!fav.favorite());
        QCOMPARE(state.lookupCalls, 0);

        fav.toggle();
        QCOMPARE(state.setCalls, 0);
    }

    void streamMrlIsUnavailableWithoutLookup()
    {
        FakeState state; // knows the streams on purpose: the scheme alone must rule them out
        state.media["https://example.com/a.mp4"] = false;
        state.media["rtsp://example.com/live"] = false;
        CurrentMediaFavorite fav;
        fav.setBackend(std::make_unique<FakeBackend>(&state));

        fav.setMrl("https://example.com/a.mp4");
        QVERIFY(!fav.available());
        fav.setMrl("rtsp://example.com/live");
        QVERIFY(!fav.available());
        QCOMPARE(state.lookupCalls, 0);

        fav.toggle();
        QCOMPARE(state.setCalls, 0);

        fav.setMrl("FILE:///a.mp4"); // the scheme is case insensitive; not in the library => still unavailable
        QCOMPARE(state.lookupCalls, 1);
        QVERIFY(!fav.available());
    }

    void noBackendIsUnavailable()
    {
        CurrentMediaFavorite fav; // no default factory installed
        fav.setMrl("file:///a.mp4");
        QVERIFY(!fav.available());
        fav.toggle(); // must not crash
        QVERIFY(!fav.favorite());
    }

    void mrlChangeResetsAndLooksUpAgain()
    {
        FakeState state;
        state.media["file:///a.mp4"] = true;
        state.media["file:///b.mp4"] = false;
        CurrentMediaFavorite fav;
        fav.setBackend(std::make_unique<FakeBackend>(&state));

        QSignalSpy mrlSpy(&fav, &CurrentMediaFavorite::mrlChanged);
        fav.setMrl("file:///a.mp4");
        QVERIFY(fav.favorite());
        fav.setMrl("file:///b.mp4");
        QVERIFY(fav.available());
        QVERIFY(!fav.favorite());
        fav.setMrl("file:///b.mp4"); // same value: nothing happens
        QCOMPARE(mrlSpy.count(), 2);
        QCOMPARE(state.lookupCalls, 2);

        fav.setMrl("file:///gone.mp4");
        QVERIFY(!fav.available());
    }

    void staleLookupIsIgnored()
    {
        FakeState state;
        state.media["file:///a.mp4"] = true;
        state.media["file:///b.mp4"] = false;
        state.defer = true;
        CurrentMediaFavorite fav;
        fav.setBackend(std::make_unique<FakeBackend>(&state));

        fav.setMrl("file:///a.mp4"); // answer for a is still in flight...
        fav.setMrl("file:///b.mp4"); // ...when the media changes
        QVERIFY(!fav.available());

        state.flush(); // a answers first (true), then b (false)
        QVERIFY(fav.available());
        QVERIFY(!fav.favorite()); // the answer for a must not win
    }

    void secondToggleWhilePendingIsDropped()
    {
        FakeState state;
        state.media["file:///a.mp4"] = false;
        CurrentMediaFavorite fav;
        fav.setBackend(std::make_unique<FakeBackend>(&state));
        fav.setMrl("file:///a.mp4");

        state.defer = true;
        fav.toggle();
        fav.toggle(); // dropped: the first write has not been answered yet
        QCOMPARE(state.setCalls, 1);
        QVERIFY(fav.favorite());

        state.flush();
        fav.toggle(); // answered, a new change is possible again
        QCOMPARE(state.setCalls, 2);
    }

    void mediaChangeDuringSetDropsItsAnswer()
    {
        FakeState state;
        state.media["file:///a.mp4"] = false;
        state.media["file:///b.mp4"] = true;
        state.setSucceeds = false;
        CurrentMediaFavorite fav;
        fav.setBackend(std::make_unique<FakeBackend>(&state));
        fav.setMrl("file:///a.mp4");

        state.defer = true;
        fav.toggle();               // write for a in flight (it will fail)
        fav.setMrl("file:///b.mp4"); // current media is now b
        state.defer = false;
        state.flush();              // the failure of a's write must not touch b

        // the lookup of b was issued while deferred and has been flushed too
        QVERIFY(fav.available());
        QVERIFY(fav.favorite());
    }
};

QTEST_GUILESS_MAIN(TestCurrentMediaFavorite)
#include "test_current_media_favorite.moc"
