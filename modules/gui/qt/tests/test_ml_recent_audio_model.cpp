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
# include "config.h"
#endif

#include "../redesign/cpp/mlrecentaudiomodel.hpp"
#include "vlc_stub_modules.hpp"

#include <algorithm>
#include <atomic>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include <QCoreApplication>
#include <QSet>
#include <QTest>

namespace {

/**
 * The playback history of the stubbed medialibrary: the media of the history,
 * most recent first. The stub serves it through vlc_ml_list of the audio and
 * video history (list and count), like the real medialibrary does, and clears
 * it on vlc_ml_clear_history.
 */
class FakeHistory
{
public:
    struct Entry
    {
        int64_t id;
        vlc_ml_media_type_t type;
        const char *title;
    };

    void add(int64_t id, vlc_ml_media_type_t type, const char *title)
    {
        std::lock_guard<std::mutex> lock(m_lock);
        m_entries.insert(m_entries.begin(), Entry{id, type, title});
    }

    // number of count queries of the audio history so far: every (re)load of the model
    // starts with one
    int audioCountQueries() const { return m_audioCountQueries; }

    void clear()
    {
        std::lock_guard<std::mutex> lock(m_lock);
        m_entries.clear();
    }

    void install(VLCTestingEnv &env)
    {
        env.mlList = [this](int query, const vlc_ml_query_params_t *params, va_list args) -> int
        {
            switch (query)
            {
            case VLC_ML_COUNT_AUDIO_HISTORY:
                ++m_audioCountQueries;
                *va_arg(args, size_t *) = filtered(VLC_ML_MEDIA_TYPE_AUDIO, nullptr).size();
                return VLC_SUCCESS;
            case VLC_ML_COUNT_VIDEO_HISTORY:
                *va_arg(args, size_t *) = filtered(VLC_ML_MEDIA_TYPE_VIDEO, nullptr).size();
                return VLC_SUCCESS;
            case VLC_ML_LIST_AUDIO_HISTORY:
                *va_arg(args, vlc_ml_media_list_t **) = makeList(filtered(VLC_ML_MEDIA_TYPE_AUDIO, params));
                return VLC_SUCCESS;
            case VLC_ML_LIST_VIDEO_HISTORY:
                *va_arg(args, vlc_ml_media_list_t **) = makeList(filtered(VLC_ML_MEDIA_TYPE_VIDEO, params));
                return VLC_SUCCESS;
            default:
                return VLC_EGENERIC;
            }
        };
        env.mlControl = [this](int query, va_list) -> int
        {
            if (query != VLC_ML_CLEAR_HISTORY)
                return VLC_EGENERIC;
            clear();
            return VLC_SUCCESS;
        };
    }

private:
    std::vector<Entry> filtered(vlc_ml_media_type_t type, const vlc_ml_query_params_t *params)
    {
        std::lock_guard<std::mutex> lock(m_lock);
        std::vector<Entry> res;
        for (const Entry &entry : m_entries)
            if (entry.type == type)
                res.push_back(entry);
        if (params && params->i_offset > 0)
            res.erase(res.begin(), res.begin() + std::min<size_t>(params->i_offset, res.size()));
        if (params && params->i_nbResults > 0 && res.size() > params->i_nbResults)
            res.resize(params->i_nbResults);
        return res;
    }

    // allocated like the medialibrary does: vlc_ml_release frees it
    static vlc_ml_media_list_t *makeList(const std::vector<Entry> &entries)
    {
        auto *list = static_cast<vlc_ml_media_list_t *>(
            calloc(1, sizeof(vlc_ml_media_list_t) + entries.size() * sizeof(vlc_ml_media_t)));
        list->i_nb_items = entries.size();
        for (size_t i = 0; i < entries.size(); ++i)
        {
            vlc_ml_media_t &media = list->p_items[i];
            media.i_id = entries[i].id;
            media.i_type = entries[i].type;
            media.i_subtype = entries[i].type == VLC_ML_MEDIA_TYPE_AUDIO ? VLC_ML_MEDIA_SUBTYPE_ALBUMTRACK
                                                                         : VLC_ML_MEDIA_SUBTYPE_UNKNOWN;
            media.psz_title = strdup(entries[i].title);
            media.psz_filename = strdup(entries[i].title);

            // MLMedia reads the main file for the mrl
            auto *files = static_cast<vlc_ml_file_list_t *>(
                calloc(1, sizeof(vlc_ml_file_list_t) + sizeof(vlc_ml_file_t)));
            files->i_nb_items = 1;
            files->p_items[0].psz_mrl = strdup(("file:///fake/" + std::to_string(entries[i].id)).c_str());
            files->p_items[0].i_type = VLC_ML_FILE_TYPE_MAIN;
            files->p_items[0].b_present = true;
            media.p_files = files;
        }
        return list;
    }

    std::atomic<int> m_audioCountQueries { 0 };
    std::mutex m_lock;
    std::vector<Entry> m_entries;
};

} // namespace

class TestMLRecentAudioModel : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        m_env = std::make_unique<VLCTestingEnv>();
        QVERIFY(m_env->init());
    }

    void cleanupTestCase()
    {
        m_env->mlList = nullptr;
        m_env->mlControl = nullptr;
        m_env.reset();
    }

    void init()
    {
        m_history = std::make_unique<FakeHistory>();
        m_history->install(*m_env);
        m_medialib = std::make_unique<MediaLib>(m_env->intf, nullptr);
        m_model = std::make_unique<MLRecentAudioModel>();
        m_model->classBegin();
        m_model->setMl(m_medialib.get());
        m_model->componentComplete();
    }

    void cleanup()
    {
        m_model.reset();
        m_medialib.reset();
        m_env->mlList = nullptr;
        m_env->mlControl = nullptr;
        m_history.reset();
    }

    // 2 audio and 1 video in the history: the model only lists the audio ones
    void testOnlyAudioHistory()
    {
        QTRY_VERIFY(!m_model->loading());
        QCOMPARE(m_model->rowCount(), 0);

        m_history->add(1, VLC_ML_MEDIA_TYPE_AUDIO, "first song");
        m_history->add(2, VLC_ML_MEDIA_TYPE_VIDEO, "a movie");
        m_history->add(3, VLC_ML_MEDIA_TYPE_AUDIO, "second song");
        notifyHistoryChanged();

        QTRY_COMPARE(m_model->rowCount(), 2);

        QSet<int64_t> ids;
        for (int row = 0; row < m_model->rowCount(); ++row)
            ids.insert(mediaId(row));
        QCOMPARE(ids, (QSet<int64_t>{1, 3}));

        // most recent first
        QCOMPARE(mediaId(0), int64_t(3));
        QCOMPARE(m_model->data(m_model->index(0), MLMediaModel::MEDIA_TITLE).toString(),
                 QStringLiteral("second song"));
    }

    // clearing the history empties the model once the history-changed event arrives
    void testClearHistory()
    {
        m_history->add(1, VLC_ML_MEDIA_TYPE_AUDIO, "first song");
        m_history->add(2, VLC_ML_MEDIA_TYPE_AUDIO, "second song");
        notifyHistoryChanged();
        QTRY_COMPARE(m_model->rowCount(), 2);

        QCOMPARE(vlc_ml_clear_history(vlc_ml_instance_get(m_env->intf), VLC_ML_HISTORY_TYPE_GLOBAL),
                 VLC_SUCCESS);
        notifyHistoryChanged();

        QTRY_COMPARE(m_model->rowCount(), 0);
    }

    // an added media is not in the history: it must not reload the model (a library scan
    // adds many media, each would reset the model)
    void testMediaAddedDoesNotReload()
    {
        m_history->add(1, VLC_ML_MEDIA_TYPE_AUDIO, "first song");
        notifyHistoryChanged();
        QTRY_COMPARE(m_model->rowCount(), 1);
        QTRY_VERIFY(!m_model->loading());

        const int queries = m_history->audioCountQueries();

        vlc_ml_media_t media {};
        media.i_id = 42;
        for (vlc_ml_media_type_t type : { VLC_ML_MEDIA_TYPE_VIDEO, VLC_ML_MEDIA_TYPE_AUDIO })
        {
            media.i_type = type;
            vlc_ml_event_t event {};
            event.i_type = VLC_ML_EVENT_MEDIA_ADDED;
            event.creation.p_media = &media;
            m_env->sendMLEvent(event);
        }

        // let a (wrong) reset reach the loader
        QTest::qWait(200);
        QCOMPARE(m_history->audioCountQueries(), queries);
        QCOMPARE(m_model->rowCount(), 1);
    }

private:
    int64_t mediaId(int row) const
    {
        return m_model->data(m_model->index(row), MLMediaModel::MEDIA_ID).value<MLItemId>().id;
    }

    void notifyHistoryChanged()
    {
        vlc_ml_event_t event {};
        event.i_type = VLC_ML_EVENT_HISTORY_CHANGED;
        m_env->sendMLEvent(event);
    }

    std::unique_ptr<VLCTestingEnv> m_env;
    std::unique_ptr<FakeHistory> m_history;
    std::unique_ptr<MediaLib> m_medialib;
    std::unique_ptr<MLRecentAudioModel> m_model;
};

QTEST_GUILESS_MAIN(TestMLRecentAudioModel)
#include "test_ml_recent_audio_model.moc"
