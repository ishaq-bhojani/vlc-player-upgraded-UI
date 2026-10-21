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
        '../cpp/settingsmodel.cpp',
        '../../style/redesignpalette.hpp',
        '../../style/redesignpalette.cpp'
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

# ToolManager (yt-dlp / ffmpeg downloads) with a fake ToolFetcher: no network, no libvlc, the
# tools and the settings live in a temporary directory.
vlc_tests += {
    'name': 'test_qt_tool_manager',
    'sources': [files(
        '../../tests/test_tool_manager.cpp',
        '../cpp/toolmanager.hpp',
        '../cpp/toolmanager.cpp'
    ), redesign_qrc],
    'moc_sources': files(
        '../../tests/test_tool_manager.cpp'
    ),
    'moc_headers': files(
        '../cpp/toolmanager.hpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qtest_qt6_dep],
}

# LRC parser and SidecarLyrics (lyrics next to the media), against temporary directories
vlc_tests += {
    'name': 'test_qt_lrc_parser',
    'sources': files(
        '../../tests/test_lrc_parser.cpp',
        '../cpp/lrcparser.hpp',
        '../cpp/lrcparser.cpp',
        '../cpp/sidecarlyrics.hpp',
        '../cpp/sidecarlyrics.cpp',
        '../../util/vlctick.cpp'
    ),
    'moc_sources': files(
        '../../tests/test_lrc_parser.cpp'
    ),
    'moc_headers': files(
        '../cpp/sidecarlyrics.hpp',
        '../../util/vlctick.hpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_with': [libvlccore],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep],
}

# WaveformProvider (waveform peaks for the seek bar and the loudness measurement): the pure
# part and the provider against a fake decoder, plus the real decoder (libvlccore: transcode +
# smem, a private vlc_player, no output device) on a libvlc instance with a throwaway --config.
vlc_tests += {
    'name': 'test_qt_waveform',
    'sources': files(
        '../../tests/test_waveform.cpp',
        '../cpp/waveform.hpp',
        '../cpp/waveform.cpp',
        '../cpp/waveformvlc.hpp',
        '../cpp/waveformvlc.cpp'
    ),
    'moc_sources': files(
        '../../tests/test_waveform.cpp'
    ),
    'moc_headers': files(
        '../cpp/waveform.hpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_with': [libvlccore, libvlc],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep],
}

# MeasuredGain (replay gain from the measured loudness of files that have none): the decision,
# the value handed to the audio output and the logic against a fake player and decoder, plus the
# VLC backend on a real player whose audio output is the dummy one or the "file" one (the level of
# what is played is measured on the written samples: a gain set during playback must change it).
vlc_tests += {
    'name': 'test_qt_measured_gain',
    'sources': files(
        '../../tests/test_measured_gain.cpp',
        '../cpp/measuredgain.hpp',
        '../cpp/measuredgain.cpp',
        '../cpp/measuredgainvlc.hpp',
        '../cpp/measuredgainvlc.cpp',
        '../cpp/waveform.hpp',
        '../cpp/waveform.cpp',
        '../cpp/waveformvlc.hpp',
        '../cpp/waveformvlc.cpp'
    ),
    'moc_sources': files(
        '../../tests/test_measured_gain.cpp'
    ),
    'moc_headers': files(
        '../cpp/measuredgain.hpp',
        '../cpp/waveform.hpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_with': [libvlccore, libvlc],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep],
}

# SettingsBridge: the VLC key string of a key press and the color scheme, with the real
# ColorSchemeModel and key converter of the Qt interface (the native file dialogs are not tested).
vlc_tests += {
    'name': 'test_qt_settings_bridge',
    'sources': files(
        '../../tests/test_settings_bridge.cpp',
        '../cpp/settingsbridge.hpp',
        '../cpp/settingsbridge.cpp',
        '../../util/color_scheme_model.hpp',
        '../../util/color_scheme_model.cpp',
        '../../util/vlchotkeyconverter.hpp',
        '../../util/vlchotkeyconverter.cpp'
    ),
    'moc_sources': files(
        '../../tests/test_settings_bridge.cpp'
    ),
    'moc_headers': files(
        '../cpp/settingsbridge.hpp',
        '../../util/color_scheme_model.hpp',
        '../../util/vlchotkeyconverter.hpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_with': [libvlccore],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep],
}

# SubtitleAttacher (subtitle files added to the playing media and the queue, brought back from the
# media library at playback, folder listing) against a fake library and player: no libvlc instance.
vlc_tests += {
    'name': 'test_qt_subtitle_attacher',
    'sources': files(
        '../../tests/test_subtitle_attacher.cpp',
        '../cpp/subtitleattacher.hpp',
        '../cpp/subtitleattacher.cpp'
    ),
    'moc_sources': files(
        '../../tests/test_subtitle_attacher.cpp'
    ),
    'moc_headers': files(
        '../cpp/subtitleattacher.hpp'
    ),
    'suite': ['qt'],
    'include_directories' : qt_include_dir,
    'link_with': [libvlccore],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep],
}
