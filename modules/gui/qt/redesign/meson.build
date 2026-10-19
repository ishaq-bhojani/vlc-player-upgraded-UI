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
)

qt_plugin_sources += files(
    'cpp/aboutbranding.cpp',
    'cpp/aboutbranding.hpp',
    'cpp/branding.hpp',
    'cpp/redesign.cpp',
    'cpp/redesign.hpp',
    'cpp/currentmediafavorite.cpp',
    'cpp/currentmediafavorite.hpp',
    'cpp/mlfavoritebackend.cpp',
    'cpp/mlfavoritebackend.hpp',
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
    'target' : 'redesign',
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
        'shell/Rail.qml',
        'shell/RailModel.qml',
        'shell/ShellStates.qml',
    ),
    'singletons': files(
        'theme/RedesignStyle.qml',
        'util/MediaText.qml',
        'util/ReplayLogic.qml',
        'shell/PinStore.qml',
    ),
}

qml_tests += {
    'tst_MediaText': files('../tests/tst_MediaText.qml'),
    'tst_ReplayLogic': files('../tests/tst_ReplayLogic.qml'),
    'tst_RailModel': files('../tests/tst_RailModel.qml'),
    'tst_ShellStates': files('../tests/tst_ShellStates.qml'),
    'tst_PinStore': files('../tests/tst_PinStore.qml'),
}
