# Upstream touchpoints

Edits to files that exist upstream (VLC 4.0-dev). Keep each as small as possible so
merging upstream stays cheap.

| file | lines | task | purpose |
|------|-------|------|---------|
| modules/gui/qt/qt.cpp | ~300-301 (`REDESIGN_TEXT`, `REDESIGN_LONGTEXT`), ~485 (`add_bool("qt-redesign")`) | 4 | declare the `qt-redesign` option that gates every redesign behaviour |
| modules/gui/qt/meson.build | ~202-203 (`qt_plugin_sources`), ~958-963 (`VLC.Redesign` qml module), ~1436-1452 (`test_qt_redesign_option`) | 4 | build `redesign/cpp`, register the `VLC.Redesign` QML module and its test |
