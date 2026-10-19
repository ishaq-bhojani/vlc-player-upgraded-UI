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

#include <QTest>
#include <QCoreApplication>
#include <QSettings>
#include <QTemporaryDir>
#include <memory>

#include "dialogs/toolbar/controlbar_profile.hpp"
#include "dialogs/toolbar/controlbar_profile_model.hpp"
#include "player/control_list_model.hpp"
#include "player/player_controlbar_model.hpp"
#include "redesign/cpp/rebornprofile.hpp"

namespace
{
constexpr int PLAYER = PlayerControlbarModel::Videoplayer;
constexpr int STOCK_PROFILES = 5; // Default, Minimalist, One-liner, Simplest, Classic
const QLatin1String SEEDED {"redesign/RebornProfileSeeded"};
}

/**
 * Selection rules of redesign::ensureRebornProfile / leaveRebornProfile. The model is created
 * with redesign == false (the constructor only needs the settings): its deferred initialisation
 * inserts the stock defaults, then the functions under test are called directly.
 *
 * ONE model serves all tests: ControlbarProfileModel::generateUniqueName keeps a `static` lambda
 * that captures `this` of the first instance, a second instance would use a dangling pointer.
 * init() brings the model back to the stock state instead.
 */
class TestRedesignRebornProfile : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;
    std::unique_ptr<QSettings> m_settings;
    std::unique_ptr<ControlbarProfileModel> m_model;

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        m_settings = std::make_unique<QSettings>(m_dir.filePath("test.ini"), QSettings::IniFormat);
        m_model = std::make_unique<ControlbarProfileModel>(m_settings.get(), nullptr, false);
        QCoreApplication::processEvents(); // the deferred reload / insertDefaults
        QCOMPARE(m_model->rowCount(), STOCK_PROFILES);
    }

    void cleanupTestCase()
    {
        m_model.reset();
        m_settings.reset();
    }

    // the state of a first start: the stock profiles, the first one selected and untouched
    void init()
    {
        while (m_model->rowCount() > STOCK_PROFILES)
        {
            m_model->setSelectedProfile(m_model->rowCount() - 1);
            m_model->deleteSelectedProfile();
        }

        const std::unique_ptr<ControlbarProfile> stock(
            ControlbarProfileModel::generateProfileFromStyle(ControlbarProfileModel::Style::DEFAULT_STYLE));
        for (const int id : { int(PlayerControlbarModel::Videoplayer), int(PlayerControlbarModel::Audioplayer),
                              int(PlayerControlbarModel::Miniplayer) })
            m_model->getProfile(0)->setModelData(id, stock->getModelData(id));

        m_model->setSelectedProfile(0);
        m_settings->remove(SEEDED);
        QCOMPARE(m_model->rowCount(), STOCK_PROFILES);
    }

    void freshSelectsReborn()
    {
        redesign::ensureRebornProfile(m_model.get(), m_settings.get());

        QCOMPARE(m_model->rowCount(), STOCK_PROFILES + 1);
        QCOMPARE(m_model->selectedProfile(), STOCK_PROFILES);
        QCOMPARE(m_model->currentModel()->name(), redesign::rebornProfileName());
        QVERIFY(m_settings->value(SEEDED).toBool());

        // one row: previous, play, next, seek bar | volume ... fullscreen
        const auto row = m_model->currentModel()->getModelData(PLAYER);
        QCOMPARE(row[0], (QVector<int>{ ControlListModel::PREVIOUS_BUTTON, ControlListModel::PLAY_BUTTON,
                                         ControlListModel::NEXT_BUTTON, ControlListModel::REDESIGN_SEEKBAR }));
        QVERIFY(row[1].isEmpty());
        QCOMPARE(row[2], (QVector<int>{ ControlListModel::VOLUME, ControlListModel::REDESIGN_SUBTITLE_POPUP,
                                         ControlListModel::REDESIGN_AUDIO_POPUP, ControlListModel::REDESIGN_SIDEBAR_BUTTON,
                                         ControlListModel::PLAYLIST_BUTTON, ControlListModel::FULLSCREEN_BUTTON }));
    }

    void untouchedStockChoiceIsReplaced()
    {
        // Classic Style (index 4), not touched
        m_model->setSelectedProfile(STOCK_PROFILES - 1);
        redesign::ensureRebornProfile(m_model.get(), m_settings.get());
        QCOMPARE(m_model->selectedProfile(), STOCK_PROFILES);
    }

    void customisedSelectionIsKept()
    {
        m_model->getProfile(0)->setModelData(PLAYER, { QVector<int>{ ControlListModel::STOP_BUTTON },
                                                       QVector<int>{}, QVector<int>{} });
        redesign::ensureRebornProfile(m_model.get(), m_settings.get());

        QCOMPARE(m_model->rowCount(), STOCK_PROFILES + 1); // appended
        QCOMPARE(m_model->selectedProfile(), 0);           // but not selected
        QCOMPARE(m_model->getProfile(STOCK_PROFILES)->name(), redesign::rebornProfileName());
    }

    void addedOnce()
    {
        redesign::ensureRebornProfile(m_model.get(), m_settings.get());
        m_model->setSelectedProfile(0);
        redesign::ensureRebornProfile(m_model.get(), m_settings.get());

        QCOMPARE(m_model->rowCount(), STOCK_PROFILES + 1);
        QCOMPARE(m_model->selectedProfile(), 0); // the user's choice is not overridden again
    }

    void leavingTheRedesignSelectsTheFirstProfile()
    {
        redesign::ensureRebornProfile(m_model.get(), m_settings.get());
        QCOMPARE(m_model->selectedProfile(), STOCK_PROFILES);

        redesign::leaveRebornProfile(m_model.get());

        QCOMPARE(m_model->selectedProfile(), 0);
        QCOMPARE(m_model->rowCount(), STOCK_PROFILES + 1); // the profile is kept
    }

    void leavingKeepsAnotherSelection()
    {
        redesign::ensureRebornProfile(m_model.get(), m_settings.get());
        m_model->setSelectedProfile(2);

        redesign::leaveRebornProfile(m_model.get());

        QCOMPARE(m_model->selectedProfile(), 2);
    }

    void savedWithTheModel()
    {
        redesign::ensureRebornProfile(m_model.get(), m_settings.get());

        // the profile is on disk (array indexes start at 1), so it is there after a restart
        m_settings->sync();
        QCOMPARE(m_settings->value("ControlbarProfileModel/Profiles/6/Name").toString(), redesign::rebornProfileName());
        QCOMPARE(m_settings->value("ControlbarProfileModel/SelectedProfile").toInt(), STOCK_PROFILES);
    }
};

QTEST_GUILESS_MAIN(TestRedesignRebornProfile)
#include "test_redesign_reborn_profile.moc"
