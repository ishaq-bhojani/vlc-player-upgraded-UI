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
