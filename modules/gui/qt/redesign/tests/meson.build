# VLC Reborn: unit tests of the redesign. See ../meson.build for the hook points.
# Entered from inside upstream's `if qtest_qt6_dep.found()` block, so qtest_qt6_dep,
# redesign_qrc, qt_include_dir and the final qt_link_args are available.
# Paths are relative to modules/gui/qt/redesign/tests/; the test sources still
# live in modules/gui/qt/tests/ ('../../tests/').

vlc_tests += {
    'name': 'test_qt_redesign_option',
    'sources': files(
        '../../tests/vlc_stub_modules.cpp',
        '../../tests/test_redesign_option.cpp',
        '../cpp/redesign.hpp',
        '../cpp/redesign.cpp'
    ),
    'moc_sources': files(
        '../../tests/test_redesign_option.cpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_with': [libvlccore, libvlc],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep],
}

vlc_tests += {
    'name': 'test_qt_redesign_palette',
    'sources': files(
        '../../tests/test_redesign_palette.cpp',
        '../../style/redesignpalette.hpp',
        '../../style/redesignpalette.cpp'
    ),
    'moc_sources': files(
        '../../tests/test_redesign_palette.cpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qtest_qt6_dep],
}

vlc_tests += {
    'name': 'test_qt_current_media_favorite',
    'sources': files(
        '../../tests/test_current_media_favorite.cpp',
        '../cpp/currentmediafavorite.hpp',
        '../cpp/currentmediafavorite.cpp'
    ),
    'moc_sources': files(
        '../../tests/test_current_media_favorite.cpp'
    ),
    'moc_headers': files(
        '../cpp/currentmediafavorite.hpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qtest_qt6_dep],
}

vlc_tests += {
    'name': 'test_qt_redesign_widget_palette',
    'sources': files(
        '../../tests/test_redesign_widget_palette.cpp',
        '../cpp/widgetpalette.hpp',
        '../cpp/widgetpalette.cpp',
        '../../style/redesignpalette.hpp',
        '../../style/redesignpalette.cpp'
    ),
    'moc_sources': files(
        '../../tests/test_redesign_widget_palette.cpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qtest_qt6_dep],
}

vlc_tests += {
    'name': 'test_qt_redesign_font',
    'sources': [files(
        '../../tests/test_redesign_font.cpp',
        '../cpp/redesign.hpp',
        '../cpp/redesign.cpp'
    ), redesign_qrc],
    'moc_sources': files(
        '../../tests/test_redesign_font.cpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_with': [libvlccore],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qtest_qt6_dep],
}

vlc_tests += {
    'name': 'test_qt_redesign_branding',
    'sources': files(
        '../../tests/test_redesign_branding.cpp',
        '../cpp/branding.hpp'
    ),
    'moc_sources': files(
        '../../tests/test_redesign_branding.cpp'
    ),
    'suite': ['qt'],
    'cpp_args': redesign_branding_cppargs,
    'include_directories' : qt_include_dir,
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qtest_qt6_dep],
}

vlc_tests += {
    'name': 'test_qt_redesign_pin_logic',
    'sources': files(
        '../../tests/test_redesign_pin_logic.cpp',
        '../cpp/pinlogic.hpp',
        '../cpp/pinlogic.cpp'
    ),
    'moc_sources': files(
        '../../tests/test_redesign_pin_logic.cpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_with': [libvlccore],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep],
}

vlc_tests += {
    'name': 'test_qt_redesign_pin_navigation',
    'sources': files(
        '../../tests/test_redesign_pin_navigation.cpp',
        '../cpp/pinlogic.hpp',
        '../cpp/pinlogic.cpp',
        '../cpp/pinnavigation.hpp',
        '../cpp/pinnavigation.cpp'
    ),
    'moc_sources': files(
        '../../tests/test_redesign_pin_navigation.cpp'
    ),
    'moc_headers': files(
        '../cpp/pinnavigation.hpp',
        '../../medialibrary/mlqmltypes.hpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_with': [libvlccore],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep],
}

vlc_tests += {
    'name': 'test_qt_redesign_reborn_profile',
    'sources': files(
        '../../tests/test_redesign_reborn_profile.cpp',
        '../cpp/rebornprofile.hpp',
        '../cpp/rebornprofile.cpp',
        '../../dialogs/toolbar/controlbar_profile_model.hpp',
        '../../dialogs/toolbar/controlbar_profile_model.cpp',
        '../../dialogs/toolbar/controlbar_profile.hpp',
        '../../dialogs/toolbar/controlbar_profile.cpp',
        '../../player/player_controlbar_model.hpp',
        '../../player/player_controlbar_model.cpp',
        '../../player/control_list_model.hpp',
        '../../player/control_list_model.cpp'
    ),
    'moc_sources': files(
        '../../tests/test_redesign_reborn_profile.cpp'
    ),
    'moc_headers': files(
        '../../dialogs/toolbar/controlbar_profile_model.hpp',
        '../../dialogs/toolbar/controlbar_profile.hpp',
        '../../player/player_controlbar_model.hpp',
        '../../player/control_list_model.hpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_with': [libvlccore],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep],
}

# MLRecentAudioModel against the stubbed medialibrary (a fake playback history,
# see FakeHistory in tests/test_ml_recent_audio_model.cpp). Same sources as
# test_qt_ml_model (modules/gui/qt/meson.build) plus the media/audio models.
vlc_tests += {
    'name': 'test_qt_ml_recent_audio_model',
    'sources': files(
        '../../tests/test_ml_recent_audio_model.cpp',
        '../../tests/vlc_stub_modules.cpp',
        '../cpp/mlrecentaudiomodel.hpp',
        '../cpp/mlrecentaudiomodel.cpp',
        '../../util/base_model.cpp',
        '../../util/vlctick.cpp',
        '../../medialibrary/mlbasemodel.cpp',
        '../../medialibrary/medialib.cpp',
        '../../medialibrary/mlthreadpool.cpp',
        '../../medialibrary/mlmediamodel.cpp',
        '../../medialibrary/mlaudiomodel.cpp',
        '../../medialibrary/mlaudio.cpp',
        '../../medialibrary/mlvideo.cpp',
        '../../medialibrary/mlhelper.cpp',
        '../../playlist/playlist_controller.cpp',
        '../../playlist/playlist_item.cpp',
    ),
    'moc_sources': files(
        '../../tests/test_ml_recent_audio_model.cpp'
    ),
    'moc_headers': files(
        '../cpp/mlrecentaudiomodel.hpp',
        '../../tests/vlc_stub_modules.cpp',
        '../../util/base_model.hpp',
        '../../util/listcache.hpp',
        '../../util/locallistcacheloader.hpp',
        '../../util/vlctick.hpp',
        '../../medialibrary/mlqmltypes.hpp',
        '../../medialibrary/mlbasemodel.hpp',
        '../../medialibrary/mlmediamodel.hpp',
        '../../medialibrary/mlaudiomodel.hpp',
        '../../medialibrary/medialib.hpp',
        '../../medialibrary/mlthreadpool.hpp',
        '../../playlist/playlist_controller.hpp',
        '../../playlist/playlist_item.hpp',
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_with': [libvlccore, libvlc],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep],
}

# EffectsController against a libvlc instance without playback (no aout/vout):
# the configuration side of every setter. Own throwaway --config, see the test.
vlc_tests += {
    'name': 'test_qt_effects_controller',
    'sources': files(
        '../../tests/test_effects_controller.cpp',
        '../cpp/effectscontroller.hpp',
        '../cpp/effectscontroller.cpp'
    ),
    'moc_sources': files(
        '../../tests/test_effects_controller.cpp'
    ),
    'moc_headers': files(
        '../cpp/effectscontroller.hpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_with': [libvlccore, libvlc],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep],
}

# SettingsModel against a real libvlc instance on a throwaway --config (the user's
# configuration is never read or written); the options come from the plugins of the build.
vlc_tests += {
    'name': 'test_qt_settings_model',
    'sources': [files(
        '../../tests/test_settings_model.cpp',
        '../cpp/settingsmodel.hpp',
        '../cpp/settingsmodel.cpp'
    ), redesign_qrc],
    'moc_sources': files(
        '../../tests/test_settings_model.cpp'
    ),
    'moc_headers': files(
        '../cpp/settingsmodel.hpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_with': [libvlccore, libvlc],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep],
}

# ShortcutsModel against a real libvlc instance on a throwaway --config: the key actions
# come from the core module, the writes go to the throwaway file.
vlc_tests += {
    'name': 'test_qt_shortcuts_model',
    'sources': files(
        '../../tests/test_shortcuts_model.cpp',
        '../cpp/shortcutsmodel.hpp',
        '../cpp/shortcutsmodel.cpp'
    ),
    'moc_sources': files(
        '../../tests/test_shortcuts_model.cpp'
    ),
    'moc_headers': files(
        '../cpp/shortcutsmodel.hpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_with': [libvlccore, libvlc],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep],
}
