# VLC Reborn: every build registration of the redesign.
#
# modules/gui/qt/meson.build only carries two hook lines (keep it that way, so
# the monthly upstream merges stay trivial). subdir() shares the parent scope,
# so this file appends to the variables of modules/gui/qt/meson.build. Paths in
# files() are relative to modules/gui/qt/redesign/.
#
# Hook 1: subdir('redesign'), inside `if qt6_dep.found()`, after qt_rcc_extra_arguments
#   is known and before the qml_modules loop and the moc/plugin targets consume
#   moc_headers, qt_plugin_sources, qml_modules and qml_tests. It registers the
#   redesign sources, the VLC.Redesign QML module, the QML tests, and the redesign
#   resource file.
# Hook 2: subdir('redesign/tests'), first line inside `if qtest_qt6_dep.found()`.
#   The unit tests need qtest_qt6_dep and the final qt_link_args, which exist only
#   after the plugin sources were collected, so they live in redesign/tests/meson.build
#   (a directory can only be entered once). QML tests need no guard of their own:
#   qml_tests is consumed under upstream's QuickTest guard.
#
# To add a source, QML file, QML test or unit test, edit this file or
# redesign/tests/meson.build, never modules/gui/qt/meson.build.

# Product name (redesign/cpp/branding.hpp): the meson option redesign_product_name
# (root meson_options.txt) reaches the code as -DREDESIGN_PRODUCT_NAME. It is
# appended to qt_cppargs, which the qt plugin consumes (modules/gui/qt/meson.build
# is not touched); targets that include branding.hpp on their own, i.e. the unit
# tests, take redesign_branding_cppargs.
redesign_branding_cppargs = [
    '-DREDESIGN_PRODUCT_NAME="' + get_option('redesign_product_name') + '"',
]
qt_cppargs += redesign_branding_cppargs

moc_headers += files(
    'cpp/currentmediafavorite.hpp',
    'cpp/effectscontroller.hpp',
    'cpp/mlrecentaudiomodel.hpp',
    'cpp/pinnavigation.hpp',
    'cpp/settingsbridge.hpp',
    'cpp/settingsmodel.hpp',
    'cpp/shortcutsmodel.hpp',
    'cpp/sidecarlyrics.hpp',
    'cpp/toolmanager.hpp',
    'cpp/waveform.hpp',
)

qt_plugin_sources += files(
    'cpp/aboutbranding.cpp',
    'cpp/aboutbranding.hpp',
    'cpp/branding.hpp',
    'cpp/lrcparser.cpp',
    'cpp/lrcparser.hpp',
    'cpp/pinlogic.cpp',
    'cpp/pinlogic.hpp',
    'cpp/pinnavigation.cpp',
    'cpp/pinnavigationnetwork.cpp',
    'cpp/pinnavigation.hpp',
    'cpp/qmlregistration.cpp',
    'cpp/qmlregistration.hpp',
    'cpp/rebornprofile.cpp',
    'cpp/rebornprofile.hpp',
    'cpp/redesign.cpp',
    'cpp/redesign.hpp',
    'cpp/settingsbridge.cpp',
    'cpp/settingsbridge.hpp',
    'cpp/settingsmodel.cpp',
    'cpp/settingsmodel.hpp',
    'cpp/shortcutsmodel.cpp',
    'cpp/shortcutsmodel.hpp',
    'cpp/sidecarlyrics.cpp',
    'cpp/sidecarlyrics.hpp',
    'cpp/toolmanager.cpp',
    'cpp/toolmanager.hpp',
    'cpp/toolmanagervlc.cpp',
    'cpp/toolmanagervlc.hpp',
    'cpp/waveform.cpp',
    'cpp/waveform.hpp',
    'cpp/waveformvlc.cpp',
    'cpp/waveformvlc.hpp',
    'cpp/currentmediafavorite.cpp',
    'cpp/currentmediafavorite.hpp',
    'cpp/effectscontroller.cpp',
    'cpp/effectscontroller.hpp',
    'cpp/mlfavoritebackend.cpp',
    'cpp/mlfavoritebackend.hpp',
    'cpp/mlrecentaudiomodel.cpp',
    'cpp/mlrecentaudiomodel.hpp',
    'cpp/widgetpalette.cpp',
    'cpp/widgetpalette.hpp',
    '../style/redesignpalette.cpp',
    '../style/redesignpalette.hpp',
)

# fonts of the redesign (:/redesign/fonts), compiled into the plugin
redesign_qrc = qt6.preprocess(
    qresources: files('assets/redesign_assets.qrc'),
    include_directories: qt_include_dir,
    dependencies: qt6_dep,
    rcc_extra_arguments: qt_rcc_extra_arguments)
qt_plugin_sources += redesign_qrc

qml_modules += {
    'name' : 'VLC.Redesign',
    # not 'redesign': its resource (<target>_assets) would share the name of the font resource
    # above (redesign_assets.qrc) and the linker would keep only one of the two
    'target' : 'redesignqml',
    'outdir' : 'VLC/Redesign',
    'sources': files(
        'player/controls/MediaLabelWidget.qml',
        'player/controls/DividerWidget.qml',
        'player/controls/TitleLabelWidget.qml',
        'player/controls/ArtistLabelWidget.qml',
        'player/controls/FolderLabelWidget.qml',
        'player/controls/PlaylistLabelWidget.qml',
        'player/controls/ReplayButton.qml',
        'player/controls/FavoriteButton.qml',
        'player/controls/PlayPillButton.qml',
        'player/controls/QueueButton.qml',
        'player/controls/SeekBarWidget.qml',
        'player/controls/ConeVolumeSlider.qml',
        'player/controls/SubtitlePopupButton.qml',
        'player/controls/AudioPopupButton.qml',
        'player/controls/SidebarButton.qml',
        'settings/SettingRow.qml',
        'settings/controls/ToggleControl.qml',
        'settings/controls/DropdownControl.qml',
        'settings/controls/SliderControl.qml',
        'settings/controls/NumberControl.qml',
        'settings/controls/PathControl.qml',
        'settings/controls/TextControl.qml',
        'settings/RowFrame.qml',
        'settings/SegmentedControl.qml',
        'settings/ThemeRow.qml',
        'settings/AccentRow.qml',
        'settings/ActionRow.qml',
        'settings/EffectToggleRow.qml',
        'settings/EffectSliderRow.qml',
        'settings/FilterTokenRow.qml',
        'settings/ToolConsentRow.qml',
        'settings/LibraryFoldersRow.qml',
        'settings/LibraryFolders.qml',
        'settings/EqualizerPanel.qml',
        'settings/SettingsPage.qml',
        'settings/ShortcutsPage.qml',
        'settings/SettingsSidebar.qml',
        'settings/SettingsModal.qml',
        'settings/pages/GeneralPage.qml',
        'settings/pages/InterfacePage.qml',
        'settings/pages/PrivacyPage.qml',
        'settings/pages/ControlsPage.qml',
        'settings/pages/PlaybackPage.qml',
        'settings/pages/VideoPage.qml',
        'settings/pages/AudioPage.qml',
        'settings/pages/SubtitlesPage.qml',
        'settings/pages/LibraryPage.qml',
        'settings/pages/NetworkPage.qml',
        'settings/pages/PerformancePage.qml',
        'settings/pages/RecordingPage.qml',
        'settings/pages/ExtensionsPage.qml',
        'dialogs/ToolConsentDialog.qml',
        'library/HomeContent.qml',
        'library/HomePage.qml',
        'library/HomeSection.qml',
        'util/OnceLatch.qml',
        'util/StopDebounce.qml',
        'player/LyricsPanel.qml',
        'player/MiniPlayerCard.qml',
        'player/RedesignControlBar.qml',
        'player/MusicView.qml',
        'player/QueuePanel.qml',
        'player/ResumePrompt.qml',
        'player/TrackList.qml',
        'player/TrackPopup.qml',
        'shell/LibraryPanel.qml',
        'shell/MainMenu.qml',
        'shell/MainMenuRecent.qml',
        'shell/Rail.qml',
        'shell/RightPanel.qml',
        'shell/RedesignMenu.qml',
        'shell/RedesignMenuItem.qml',
        'shell/RedesignMenuSeparator.qml',
        'shell/RedesignInterface.qml',
        'shell/TitleBar.qml',
        'shell/RailModel.qml',
        'shell/ShellStates.qml',
        'shell/Stage.qml',
    ),
    'singletons': files(
        'theme/RedesignStyle.qml',
        'util/MediaText.qml',
        'util/ReplayLogic.qml',
        'util/CardCorner.qml',
        'util/ConeMath.qml',
        'util/TrackPopupLogic.qml',
        'util/RightPanelLogic.qml',
        'shell/PinStore.qml',
        'shell/ShellActions.qml',
        'settings/ControlChooser.qml',
        'settings/SettingsData.qml',
        'settings/SettingsOps.qml',
        'settings/SettingsSearch.qml',
    ),
}

qml_tests += {
    'tst_MediaText': files('../tests/tst_MediaText.qml'),
    'tst_ReplayLogic': files('../tests/tst_ReplayLogic.qml'),
    'tst_RailModel': files('../tests/tst_RailModel.qml'),
    'tst_ShellStates': files('../tests/tst_ShellStates.qml'),
    'tst_PinStore': files('../tests/tst_PinStore.qml'),
    'tst_ConeMath': files('../tests/tst_ConeMath.qml'),
    'tst_TrackPopupLogic': files('../tests/tst_TrackPopupLogic.qml'),
    'tst_CardCorner': files('../tests/tst_CardCorner.qml'),
    'tst_ControlChooser': files('../tests/tst_ControlChooser.qml'),
    'tst_RightPanelLogic': files('../tests/tst_RightPanelLogic.qml'),
    'tst_SettingsSearch': files('../tests/tst_SettingsSearch.qml'),
    'tst_OnceLatch': files('../tests/tst_OnceLatch.qml'),
    'tst_StopDebounce': files('../tests/tst_StopDebounce.qml'),
}
