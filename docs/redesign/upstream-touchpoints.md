# Upstream touchpoints

Edits to files that exist upstream (VLC 4.0-dev). Keep each as small as possible so
merging upstream stays cheap.

| file | lines | task | purpose |
|------|-------|------|---------|
| modules/gui/qt/qt.cpp | ~300-301 (`REDESIGN_TEXT`, `REDESIGN_LONGTEXT`), ~485 (`add_bool("qt-redesign")`) | 4 | declare the `qt-redesign` option that gates every redesign behaviour |
| modules/gui/qt/meson.build | ~202-203 (`qt_plugin_sources`), ~958-963 (`VLC.Redesign` qml module), ~1436-1452 (`test_qt_redesign_option`) | 4 | build `redesign/cpp`, register the `VLC.Redesign` QML module and its test |
| modules/gui/qt/style/systempalette.cpp | ~25-26 (includes), ~307-313 (`componentComplete`: redesign accent via `parseAccent`), ~386-396 and ~474-477, ~705-707 (new `makeRedesignPalette`, early return in `makeLightPalette`/`makeDarkPalette`), ~920-922 (`makeSystemPalette`: redesign palette from the theme provider's dark flag); 27 lines changed | 5 | when `m_redesign`, every palette comes from `redesign::fillPalette` (tokens.md Table B) and the accent from `qt-accent-color` |
| modules/gui/qt/style/systempalette.hpp | `makeRedesignPalette` declaration, `m_redesign` member; 2 lines changed | 5 | same as above |
| modules/gui/qt/meson.build | ~410-411 (`qt_plugin_sources`: `style/redesignpalette.*`), `test_qt_redesign_palette` entry after `test_qt_redesign_option` | 5 | build the redesign palette and register its test |
