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
import QtQuick
import QtTest
import VLC.Redesign

TestCase {
    name: "ControlOverflow"

    function test_nothingHidden() {
        compare(ControlOverflow.kinds([]), [])
    }

    function test_hiddenControlsKeepTheOrderOfTheBar() {
        compare(ControlOverflow.kinds(["qrc:/qt/qml/VLC/Redesign/player/controls/SubtitlePopupButton.qml",
                                       "file:///x/controls/AudioPopupButton.qml",
                                       "qrc:/a/FullscreenButton.qml"]),
                ["subtitles", "audio", "fullscreen"])
    }

    function test_everyControlOfTheVireoBarHasAnEntry() {
        compare(ControlOverflow.kinds(["ConeVolumeSlider.qml", "SubtitlePopupButton.qml", "AudioPopupButton.qml",
                                       "SidebarButton.qml", "QueueButton.qml", "FullscreenButton.qml"]),
                ["mute", "subtitles", "audio", "settings", "queue", "fullscreen"])
    }

    function test_controlsWithoutEntryAreLeftOut() {
        compare(ControlOverflow.kinds(["SeekBarWidget.qml", "PlayPillButton.qml"]), [])
    }

    function test_noEntryTwice() {
        compare(ControlOverflow.kinds(["QueueButton.qml", "QueueButton.qml"]), ["queue"])
    }
}
