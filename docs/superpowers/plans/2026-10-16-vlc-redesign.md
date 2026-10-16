# VLC Redesign Implementation Plan (M0 → R4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Windows build of VLC 4 whose Qt UI implements the Figma redesign, released as v0.1 (re-skin), v0.2 (new window layout), v1.0 (settings/onboarding/dialogs) and v1.1 (waveform/polish).

**Architecture:** All new UI lives in a new QML module `VLC.Redesign` (`modules/gui/qt/redesign/`). New C++ goes in `redesign/cpp/`. It reuses VLC's existing C++ models and controllers. Upstream files are touched only at the seams listed in `docs/redesign/upstream-touchpoints.md`. The `qt-redesign` option (default `true`) gates every behaviour change; `false` must give the stock upstream UI.

**Tech Stack:**
- C++17, Qt 6 (QtQuick, QtQuick.Controls, QtTest, QuickTest), Meson.
- VideoLAN Docker image `registry.videolan.org/vlc-debian-win64-posix:20260611225331`, plus `extras/package/win32/build.sh -m`.
- GitHub Actions; NSIS; Azure Trusted Signing; GnuPG (update signatures).

**Spec:** `docs/superpowers/specs/2026-10-16-vlc-redesign-design.md`

## Global Constraints

- Platform: Windows 10/11 x64 only. Build with **Meson only** (`build.sh -m`); `Makefile.am` is never edited.
- Upstream files may be edited only if listed in `docs/redesign/upstream-touchpoints.md`. Every task that edits one adds a row (file, lines, purpose) in the same commit.
- An upstream-file edit larger than ~30 lines must become a new file under `modules/gui/qt/redesign/` instead.
- `qt-redesign=false` must always load `qrc:/qt/qml/VLC/MainInterface/MainInterface.qml` with upstream palettes and the upstream first-run wizard.
- New QML files register in the single `VLC.Redesign` block appended to `modules/gui/qt/meson.build`. New C++ files go in the Qt plugin sources there too.
- New user-visible strings use `qtr()` (C++) / `qsTr()` (QML); English is the fallback.
- No setting appears in the UI unless it maps to a real VLC config key or `EffectsController` call listed in `docs/redesign/settings-map.md`.
- Text on accent backgrounds must reach a WCAG contrast ratio ≥ 4.5:1.
- Colours, spacing and radii in new QML come from `ColorContext` / `RedesignStyle`. No literal colours in `redesign/**/*.qml`.
- Fork releases are versioned `4.0.0.<N>` internally (`VERSION_EXTRA = N`, monotonic). The public label is `vMAJOR.MINOR.PATCH` (v0.1.0 = N 1).
- Every commit ends with: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Invalid `qt-accent-color` value** (e.g. `"#zzz"`, `"banana"`): the palette uses the Figma default accent, with no invisible or black accent. Pinned in Task 5.
2. **No media library** (`MainCtx.hasMediaLibrary === false`, or ML disabled): the Rail hides Home/Videos/Music/Playlists/Recent, the shell opens on Network, and nothing throws. Pinned in Task 17.
3. **Playing something that isn't in the media library** (network stream, file outside library folders): Favorite is disabled (not hidden); the name labels show the stream title or URL; the folder label is empty for non-`file://` URLs. Pinned in Tasks 10 and 11.
4. **Setting key whose plugin isn't built or loaded:** `Settings.item(key)` returns `null`, the row is hidden, an error is logged, and the page still renders. Pinned in Task 23.
5. **`qt-redesign=false`:** the stock root QML, palette and first-run wizard are used. Pinned in Tasks 5 and 18 (C++) and Task 28.

---

## Milestone M0 — Setup (Month 1)

### Task 1: Reproducible Windows dev build

**Files:**
- Create: `extras/redesign/dev-build.sh`
- Create: `docs/redesign/building.md`

**Interfaces:**
- Produces: `extras/redesign/dev-build.sh [--release] [--tests]`.
  - Runs inside `registry.videolan.org/vlc-debian-win64-posix:20260611225331`.
  - Calls `extras/package/win32/build.sh -m -p -a x86_64` (`-r` when `--release`).
  - Output goes to `build-win64/win64-meson/`.
  - With `--tests`, also runs `meson test -C build-win64/win64-meson --suite qt` (offscreen, under `wine` from the image).

- [ ] **Step 1:** Write `dev-build.sh`.
  - Use `docker run --rm -v "$PWD":/vlc -w /vlc/build-win64 <image> ../extras/package/win32/build.sh -m -p -a x86_64`.
  - Exit non-zero on any failure (`set -euo pipefail`).
- [ ] **Step 2:** Run `bash extras/redesign/dev-build.sh` from WSL2 / Git Bash with Docker Desktop. Expected: `build-win64/win64-meson/vlc-win64/vlc.exe` exists. Copy the folder to Windows and launch `vlc.exe`; the upstream UI appears.
- [ ] **Step 3:** Run `bash extras/redesign/dev-build.sh --tests`. Expected: the meson summary shows `test_qt_*` and `tst_FSM` with `Fail: 0`.
- [ ] **Step 4:** Write `docs/redesign/building.md`. Cover:
  - prerequisites (Docker Desktop + WSL2);
  - full build;
  - Qt-plugin-only rebuild (inside the container: `meson compile -C build-win64/win64-meson qt_plugin`, then copy `libqt_plugin.dll` into `vlc-win64/plugins/gui/`);
  - running tests.
- [ ] **Step 5:** Add `build-win64/` to `.gitignore`. Commit: `build: add redesign dev build script and docs`.

### Task 2: CI on GitHub Actions

**Files:**
- Create: `.github/workflows/redesign-ci.yml`

**Interfaces:**
- Consumes: `extras/redesign/dev-build.sh --tests` (Task 1).
- Produces: a required status check named `redesign-ci / win64`.

- [ ] **Step 1:** Write the workflow.
  - Trigger: `on: [pull_request, push: {branches: [redesign/main]}]`.
  - Job `win64` with `container: registry.videolan.org/vlc-debian-win64-posix:20260611225331`.
  - Steps: checkout → `extras/package/win32/build.sh -m -p -a x86_64` → `meson test --suite qt` → `python3 buildsystem/check_qml_module.py` (args as used in `extras/ci/gitlab-ci.yml`).
  - Cache `build-win64/contrib` keyed on `contrib/src/**` hash.
- [ ] **Step 2:** Push a branch, open a draft PR against `redesign/main`. Expected: the `win64` job is green.
- [ ] **Step 3:** Enable branch protection on `redesign/main` requiring `redesign-ci / win64`. Commit: `ci: add redesign win64 workflow`.

### Task 3: Design inputs and decision records (owner: you, with the Figma account)

**Files:**
- Create: `docs/redesign/tokens.md`
- Create: `docs/redesign/settings-map.md`
- Create: `docs/redesign/upstream-touchpoints.md`
- Create: `docs/redesign/branding.md`
- Create: `modules/gui/qt/redesign/assets/figma/icons/*.svg`
- Create: `modules/gui/qt/redesign/assets/fonts/` (font files + `OFL.txt`)

**Interfaces:**
- Produces, consumed by later tasks:
  - **`tokens.md`:**
    - **Table A:** Figma colour name → hex for dark and light.
    - **Table B:** every `ColorContext` slot (ColorSet × Section × Name × State) → Figma colour name, dark and light. Covers all 15 ColorSets for Fg/Bg Primary/Secondary Normal, plus Hovered/Pressed/Focused/Disabled where Figma defines them.
    - **Table C:** the 9 onboarding accent swatches in Figma order (hex) and which one is the default.
    - **Table D:** spacing / radius / control-bar height values.
    - **Font:** family and weights.
  - **`settings-map.md`:** one row per Figma Settings control: `page | label | VLC config key or EffectsController method | type | notes`. Plus a "Dropped (no backend)" list. Include the row `Playback | Skip interval | short-jump-size | choice {10, 15} | Figma "Forward 10s/15s"`.
  - **`upstream-touchpoints.md`:** columns `file | lines | task | purpose`. Starts empty.
  - **`branding.md`:** product name, publisher, website URL, icon source files, update URL base, and the GPG key ID used for update signing.

- [ ] **Step 1:** Duplicate the Figma file into your own account. Record the community file's licence or attribution terms in `branding.md` under "Design credits".
- [ ] **Step 2:** Fill `tokens.md` Tables A–D and the font (Inspect panel / Dev Mode). Every Table B row must name a Table A colour; no empty cells.
- [ ] **Step 3:** Export every icon used in the design as SVG into `redesign/assets/figma/icons/`, named after the matching `VLCIcons.json` glyph where one exists, otherwise `rd_<name>.svg`.
- [ ] **Step 4:** Download the font family from Table D (Inter: https://github.com/rsms/inter, OFL). Put `<Family>-Regular.ttf`, `-Medium.ttf`, `-SemiBold.ttf` and `OFL.txt` in `redesign/assets/fonts/`.
- [ ] **Step 5:** Fill `settings-map.md` by checking each key with `vlc.exe -H --advanced | findstr <key>` on the Task 1 build.
- [ ] **Step 6:** Decide the product name, icon and publisher in `branding.md`. Create a dedicated GPG key for update signing: `gpg --quick-gen-key "<Product> Updates <email>" dsa2048 sign never` (the updater supports DSA/RSA public-key packets). Store the private key only as the GitHub secret `UPDATE_GPG_KEY`.
- [ ] **Step 7:** Commit: `docs: add redesign tokens, settings map, branding and touchpoint log`.

---

## Release R1 — Re-skin (Months 1–4, ships v0.1.0)

### Task 4: `qt-redesign` option and `VLC.Redesign` module skeleton

**Files:**
- Create: `modules/gui/qt/redesign/cpp/redesign.hpp`, `redesign.cpp`
- Create: `modules/gui/qt/redesign/theme/RedesignStyle.qml` (singleton)
- Modify: `modules/gui/qt/qt.cpp` (option list, next to `qt-accent-color` at ~line 480)
- Modify: `modules/gui/qt/meson.build` (append one `qml_modules += { 'name': 'VLC.Redesign', 'target': 'redesign', 'outdir': 'VLC/Redesign', 'sources': files(...), 'singletons': files('redesign/theme/RedesignStyle.qml') }` block after the `VLC.Widgets` block; add the C++ sources to the plugin sources list)
- Modify: `docs/redesign/upstream-touchpoints.md`
- Test: `modules/gui/qt/tests/test_redesign_option.cpp`

**Interfaces:**
- Produces:
  - `namespace redesign { bool isEnabled(vlc_object_t* obj); }`, which returns `var_InheritBool(obj, "qt-redesign")`.
  - Option `add_bool("qt-redesign", true, REDESIGN_TEXT, REDESIGN_LONGTEXT)`.
  - QML singleton `RedesignStyle` with `readonly property int` values from `tokens.md` Table D. Names: `spacingXS, spacingS, spacingM, spacingL, spacingXL, radiusS, radiusM, radiusL, controlBarHeight, railWidthCollapsed, railWidthExpanded, panelWidthDefault, panelWidthMin, panelWidthMax`, all through `MainCtx.dp(value, MainCtx.intfScaleFactor)`.

- [ ] **Step 1: Write the failing test.**
  ```cpp
  void TestRedesignOption::defaultIsTrue() {
      libvlc_instance_t* vlc = libvlc_new(0, nullptr);
      QVERIFY(redesign::isEnabled(VLC_OBJECT(vlc->p_libvlc_int)));
  }
  void TestRedesignOption::canBeDisabled() {
      const char* argv[] = {"--no-qt-redesign"};
      libvlc_instance_t* vlc = libvlc_new(1, argv);
      QVERIFY(!redesign::isEnabled(VLC_OBJECT(vlc->p_libvlc_int)));
  }
  ```
  Register it in `meson.build` as `test_qt_redesign_option`, following the `test_qt_dialog_model` block (link `libvlccore`, `libvlc`; sources include `tests/vlc_stub_modules.cpp`).
- [ ] **Step 2:** Run `meson test -C build-win64/win64-meson test_qt_redesign_option`. Expected: FAIL (link error, `redesign::isEnabled` undefined).
- [ ] **Step 3:** Add the option in `qt.cpp` and implement `redesign::isEnabled`. Add `RedesignStyle.qml` and the meson block.
- [ ] **Step 4:** Rerun. Expected: PASS. Also run `meson test --suite qt`; all pass.
- [ ] **Step 5:** Log `qt.cpp` and `meson.build` in touchpoints. Commit: `qt: add qt-redesign option and VLC.Redesign module`.

### Task 5: Redesign palette and accent

**Files:**
- Create: `modules/gui/qt/style/redesignpalette.hpp`, `redesignpalette.cpp`
- Modify: `modules/gui/qt/style/systempalette.cpp` (`componentComplete` ~line 307, `updatePalette` ~line 386)
- Modify: `modules/gui/qt/style/systempalette.hpp` (one `bool m_redesign` member)
- Test: `modules/gui/qt/tests/test_redesign_palette.cpp`

**Interfaces:**
- Produces (namespace `redesign`):
  ```cpp
  using ColorSink = std::function<void(ColorContext::ColorSet, ColorContext::ColorSection,
                                       ColorContext::ColorName, ColorContext::ColorState, QColor)>;
  struct AccentShades { QColor base, hover, pressed, onAccent; };
  QColor defaultAccent();                                   // tokens.md Table C default
  QVector<QColor> accentSwatches();                         // tokens.md Table C, Figma order, size 9
  QColor parseAccent(const char* value, QColor fallback);  // "default"->fallback, "#rrggbb"/named valid->color, invalid->fallback
  double contrastRatio(QColor a, QColor b);                 // WCAG 2.x relative luminance ratio
  QColor onAccentColor(QColor accent);                      // Qt::black or Qt::white, whichever has the higher contrastRatio
  AccentShades accentShades(QColor base);                   // hover = base.lighter(115), pressed = base.darker(115)
  void fillPalette(const ColorSink& sink, bool dark, const AccentShades& accent);  // every slot in tokens.md Table B
  ```
- In `SystemPalette`, when `m_redesign` (from `redesign::isEnabled`):
  - `componentComplete` computes the accent with `parseAccent(var, defaultAccent())`; the `"system"` branch stays as is.
  - `updatePalette` calls `fillPalette(sink, isDark, shades)` instead of `makeLight/DarkPalette()`. The sink wraps `setColor`.
  - For `ColorSchemeModel::System`, `isDark` comes from the theme provider (`ExternalPaletteImpl::isThemeDark()`) and `fillPalette` is always used.

- [ ] **Step 1: Write the failing tests.**
  ```cpp
  void invalidAccentFallsBack() {
      QCOMPARE(redesign::parseAccent("#zzz", redesign::defaultAccent()), redesign::defaultAccent());
      QCOMPARE(redesign::parseAccent("banana", redesign::defaultAccent()), redesign::defaultAccent());
      QCOMPARE(redesign::parseAccent("default", QColor("#123456")), QColor("#123456"));
      QCOMPARE(redesign::parseAccent("#00ff00", redesign::defaultAccent()), QColor("#00ff00"));
  }
  void swatchesAreNine() { QCOMPARE(redesign::accentSwatches().size(), 9); }
  void onAccentMeetsAA() {           // data-driven over all 9 swatches
      for (QColor c : redesign::accentSwatches())
          QVERIFY(redesign::contrastRatio(c, redesign::onAccentColor(c)) >= 4.5);
  }
  void contrastKnownValues() {
      QCOMPARE(qRound(redesign::contrastRatio(Qt::black, Qt::white) * 10), 210);
      QCOMPARE(redesign::contrastRatio(Qt::red, Qt::red), 1.0);
  }
  void everySlotFilled() {           // run for dark=true and dark=false
      QSet<quint64> seen; /* sink inserts key(set,section,name,state) */
      redesign::fillPalette(sink, dark, redesign::accentShades(redesign::defaultAccent()));
      for each ColorSet cs in ColorContext::ColorSet, for section in {Fg, Bg}:
          QVERIFY(seen.contains(key(cs, section, ColorContext::Primary, ColorContext::Normal)));
  }
  void darkViewBackgroundMatchesTokens() { /* View/Bg/Primary/Normal == tokens.md Table B hex (dark) */ }
  ```
  If any swatch fails AA with both black and white, the test reports it. Fix that swatch's hex in `tokens.md` with the designer rather than weakening the test.
- [ ] **Step 2:** Run `meson test test_qt_redesign_palette`. Expected: FAIL (undefined symbols).
- [ ] **Step 3:** Implement `redesignpalette.cpp` with values copied from `tokens.md`. Wire `SystemPalette` (≤ 30 lines changed in upstream files).
- [ ] **Step 4:** Rerun. Expected: PASS. Launch the dev build: the library and player use the Figma dark colours. `--no-qt-redesign` shows the stock colours.
- [ ] **Step 5:** Log the touchpoints. Commit: `qt: add redesign palette with accent shades`.

### Task 6: Default accent, accent setting value list, application font

**Files:**
- Create: `modules/gui/qt/redesign/assets/redesign_assets.qrc` (fonts)
- Modify: `modules/gui/qt/redesign/cpp/redesign.hpp/.cpp`
- Modify: `modules/gui/qt/qt.cpp` (call `redesign::installAppFont()` after the `QApplication` is created, only when enabled)
- Modify: `modules/gui/qt/meson.build` (add the qrc to the redesign block)
- Test: `modules/gui/qt/tests/test_redesign_font.cpp`

**Interfaces:**
- Produces: `bool redesign::installAppFont();`.
  - Loads `:/redesign/fonts/*.ttf` through `QFontDatabase::addApplicationFont`.
  - Calls `QGuiApplication::setFont(QFont(<family from tokens.md>))`.
  - Returns false (logs, keeps the system font) if any file fails to load.

- [ ] **Step 1: Write the failing test.**
  ```cpp
  void fontLoads() {
      QVERIFY(redesign::installAppFont());
      QCOMPARE(QGuiApplication::font().family(), QStringLiteral("Inter")); // or tokens.md family
  }
  ```
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement. Add `OFL.txt` to the installer's licence folder in Task 13.
- [ ] **Step 4:** Run it. Expected: PASS. The dev build shows the new font in QML and in QWidgets dialogs (e.g. Tools → Media Information).
- [ ] **Step 5:** Commit: `qt: bundle redesign font`.

### Task 7: QWidgets palette and Fusion style

**Files:**
- Create: `modules/gui/qt/redesign/cpp/widgetpalette.hpp/.cpp`
- Modify: `modules/gui/qt/qt.cpp` (~line 1455, style selection: when redesign is enabled, set the Fusion style and apply the palette once `SystemPalette` is ready; re-apply on `paletteChanged`)
- Test: `modules/gui/qt/tests/test_redesign_widget_palette.cpp`

**Interfaces:**
- Consumes: `redesign::fillPalette`, `ColorSink` (Task 5).
- Produces: `QPalette redesign::toWidgetPalette(const std::function<QColor(ColorContext::ColorSet, ColorContext::ColorSection, ColorContext::ColorName, ColorContext::ColorState)>& lookup);`.
  - `Window` = Window/Bg/Primary
  - `WindowText` = Window/Fg/Primary
  - `Base` = View/Bg/Secondary
  - `Text` = View/Fg/Primary
  - `Button` = ButtonStandard/Bg/Primary
  - `ButtonText` = ButtonStandard/Fg/Primary
  - `Highlight` = ButtonAccent/Bg/Primary
  - `HighlightedText` = ButtonAccent/Fg/Primary
  - `ToolTipBase` / `ToolTipText` from `Tooltip`
  - `Disabled` group from the `Disabled` state.

- [ ] **Step 1: Write the failing test.** Build a lookup from a `fillPalette` map and assert:
  - `toWidgetPalette(lookup).color(QPalette::Highlight) == lookup(ButtonAccent, Bg, Primary, Normal)`;
  - the same pattern for `Window` and `Text`;
  - the Disabled `Text` colour comes from the Disabled state.
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement and wire it into `qt.cpp`.
- [ ] **Step 4:** Run it. Expected: PASS. In the dev build, Preferences, Media Information and the context menus use the dark palette and accent highlight.
- [ ] **Step 5:** Log the touchpoint. Commit: `qt: theme QWidgets dialogs and menus with redesign palette`.

### Task 8: Icon set replacement

**Files:**
- Create: `extras/redesign/check_icons.py`
- Modify: `modules/gui/qt/pixmaps/icons/*.svg` (replaced from `redesign/assets/figma/icons/`)
- Modify: `modules/gui/qt/pixmaps/VLCIcons.json`; regenerate `pixmaps/VLCIcons.ttf`, `style/vlcicons.hpp`, `style/vlcicons.cpp`

**Interfaces:**
- Produces: `python3 extras/redesign/check_icons.py modules/gui/qt/pixmaps`.
  - Exits 0 only if every glyph in `VLCIcons.json` has an SVG and every SVG's `viewBox` width and height equal its `width` / `height` attributes.
  - Otherwise it prints each offending file and exits 1.
- Produces: new glyph names `rd_<name>` used by Tasks 10, 17 and 19.

- [ ] **Step 1:** Write `check_icons.py`. Run it against an untouched checkout. Expected: exit 0 (the upstream set is valid).
- [ ] **Step 2:** Copy the Figma SVGs over the same-named files and add `rd_*` entries to `VLCIcons.json`. Run `check_icons.py`. Fix the SVGs (flatten to one path, remove overlaps in Inkscape: Path → Union; set the viewBox) until it exits 0.
- [ ] **Step 3:** Regenerate with `cd modules/gui/qt/pixmaps && python3 makeIconFont.py` (requires fontforge; see the header of `makeIconFont.py`). Expected: `VLCIcons.ttf` and `style/vlcicons.*` change, with no errors.
- [ ] **Step 4:** Add `check_icons.py` to the CI workflow (Task 2) as a step. Dev build: every icon in the control bar, the side navigation and the menus renders (no empty boxes).
- [ ] **Step 5:** Log the touchpoints. Commit: `qt: replace icon set with redesign icons`.

### Task 9: Metric tweaks and hard-coded colours in touched controls

**Files:**
- Modify: `modules/gui/qt/style/VLCStyle.qml` (`button_radius`, `gridCover_radius`, `navBoxButton_radius`, control-bar height properties → values from tokens.md Table D)
- Modify: `modules/gui/qt/player/qml/controlbarcontrols/PlayButton.qml` (~line 264 gradient → `theme.accent`-based fill from `ColorContext { colorSet: ColorContext.ButtonAccent }`)
- Modify: `modules/gui/qt/player/qml/controlbarcontrols/RecordButton.qml` (literal colours → `theme.fg.negative`)

**Interfaces:**
- Consumes: ColorContext `ButtonAccent` set (Task 5).

- [ ] **Step 1:** Run `grep -nE "#[0-9a-fA-F]{6}|Qt\.rgba|\"(red|white|black)\"" PlayButton.qml RecordButton.qml` and list the hits. Expected: non-empty.
- [ ] **Step 2:** Replace the hits with `ColorContext` reads and update the `VLCStyle` values.
- [ ] **Step 3:** Rerun the grep. Expected: no hits. Dev build: the play button is a flat accent pill as in the Figma Player frame, and it follows the accent when you set `--qt-accent-color=#3b82f6`.
- [ ] **Step 4:** Log the touchpoints. Commit: `qt: align control metrics and play/record colours with redesign`.

### Task 10: Media name labels and Divider control-bar items

**Files:**
- Modify: `modules/gui/qt/player/control_list_model.hpp` (rename reserved slots: `RESERVED_0X39 → REDESIGN_DIVIDER`, `0X3A → REDESIGN_TITLE_LABEL`, `0X3B → REDESIGN_ARTIST_LABEL`, `0X3C → REDESIGN_FOLDER_LABEL`, `0X3D → REDESIGN_PLAYLIST_LABEL`, `0X3E → REDESIGN_REPLAY_BUTTON`, `0X3F → REDESIGN_FAVORITE_BUTTON`; keep the numeric values)
- Modify: `modules/gui/qt/player/qml/PlayerControlbarControls.qml` (append 7 entries; `controlPath` for these is `qrc:///qt/qml/VLC/Redesign/`)
- Create: `modules/gui/qt/redesign/player/controls/DividerWidget.qml`, `TitleLabelWidget.qml`, `ArtistLabelWidget.qml`, `FolderLabelWidget.qml`, `PlaylistLabelWidget.qml`, `ReplayButton.qml`
- Create: `modules/gui/qt/redesign/util/MediaText.qml` (singleton)
- Test: `modules/gui/qt/tests/tst_MediaText.qml`

**Interfaces:**
- Produces (singleton `MediaText`):
  - `function folderName(url: string): string`: the last directory component for `file://` URLs, `""` otherwise.
  - `function titleText(title: string, name: string, url: string): string`: the first non-empty of title, name, then the URL file name.
- `ReplayButton` calls `Player.jumpToPos(0.0)` then `Player.play()`.
- `PlaylistLabelWidget` shows the play queue position text `"<current+1>/<count>"` from `MainPlaylistController`.

- [ ] **Step 1: Write the failing QML test.**
  ```qml
  TestCase { name: "MediaText"
    function test_folderName() {
      compare(MediaText.folderName("file:///C:/Videos/Shows/S01/a.mp4"), "S01")
      compare(MediaText.folderName("https://example.org/live/a.m3u8"), "")
      compare(MediaText.folderName(""), "")
    }
    function test_titleText() {
      compare(MediaText.titleText("", "", "https://x.org/a%20b.mp4"), "a b.mp4")
      compare(MediaText.titleText("T", "N", "u"), "T")
    }
  }
  ```
  Register it as `'tst_MediaText': files('tests/tst_MediaText.qml')` in `qml_tests`. Add `Q_INIT_RESOURCE(redesign_assets)` and the redesign module resource init to `tests/qml_test.cpp` `main`.
- [ ] **Step 2:** Run `meson test tst_MediaText`. Expected: FAIL (`module "VLC.Redesign" is not installed` / `MediaText` undefined).
- [ ] **Step 3:** Implement `MediaText` and the six control files. Add the enum renames and registry entries (icons are `rd_*` glyphs from Task 8; labels are from Figma).
- [ ] **Step 4:** Rerun. Expected: PASS. Dev build: in Tools → Customize Interface, the new items appear, can be dragged into the bar, and survive a restart. Play an `https://` stream: Folder is empty, Title shows the stream name.
- [ ] **Step 5:** Log the touchpoints. Commit: `qt: add redesign label, divider and replay control-bar items`.

### Task 11: Favorite control-bar item

**Files:**
- Create: `modules/gui/qt/redesign/cpp/currentmediafavorite.hpp/.cpp`
- Create: `modules/gui/qt/redesign/player/controls/FavoriteButton.qml`
- Modify: `modules/gui/qt/maininterface/mainui.cpp` (register the QML type `CurrentMediaFavorite` in `VLC.Redesign`, next to the other `qmlRegisterType` calls)
- Test: `modules/gui/qt/tests/test_current_media_favorite.cpp`

**Interfaces:**
- Produces:
  ```cpp
  class FavoriteBackend {             // pure virtual, async via callback on the Qt thread
  public:
      virtual ~FavoriteBackend() = default;
      virtual void lookup(const QString& mrl, std::function<void(std::optional<bool>)> done) = 0; // nullopt = not in ML
      virtual void set(const QString& mrl, bool favorite, std::function<void(bool ok)> done) = 0;
  };
  class CurrentMediaFavorite : public QObject {
      Q_OBJECT
      Q_PROPERTY(QString mrl READ mrl WRITE setMrl NOTIFY mrlChanged)
      Q_PROPERTY(bool available READ available NOTIFY stateChanged)   // false when not in ML / no ML / empty mrl
      Q_PROPERTY(bool favorite READ favorite NOTIFY stateChanged)
  public:
      explicit CurrentMediaFavorite(QObject* parent = nullptr);        // uses MLFavoriteBackend if MainCtx has ML
      void setBackend(std::unique_ptr<FavoriteBackend>);               // tests
      Q_INVOKABLE void toggle();                                        // no-op when !available; reverts on failure
  };
  ```
  `MLFavoriteBackend` uses `MediaLib::runOnMLThread` with `vlc_ml_get_media_by_mrl` (`b_is_favorite`) and `vlc_ml_media_set_favorite`.
- `FavoriteButton.qml` binds `mrl: Player.url`, `enabled: fav.available`, and shows icon `rd_heart_filled` / `rd_heart` from `fav.favorite`.

- [ ] **Step 1: Write the failing tests** with a fake backend that has an in-memory `QHash<QString,bool>`:
  - `unknownMrlIsUnavailable`: the fake returns nullopt → `available == false`; `toggle()` doesn't call `set`.
  - `toggleFlips`: `{"file:///a.mp4": false}` → after `toggle()`, `favorite == true` and the fake map value is true.
  - `failedSetReverts`: the fake `set` reports `ok=false` → `favorite` returns to false and `stateChanged` is emitted twice.
  - `emptyMrlIsUnavailable`.
- [ ] **Step 2:** Run `meson test test_qt_current_media_favorite`. Expected: FAIL.
- [ ] **Step 3:** Implement the class, `MLFavoriteBackend` and `FavoriteButton.qml`, and add the control entry (Task 10's `REDESIGN_FAVORITE_BUTTON`).
- [ ] **Step 4:** Rerun. Expected: PASS. Dev build: toggle Favorite on a library file, then open Video → filter favorites (`favoriteOnly`); it's listed. On a network stream the button is visible but disabled.
- [ ] **Step 5:** Commit: `qt: add favorite control-bar item`.

### Task 12: Re-skin the Customize Player dialog and MiniPlayer

**Files:**
- Modify: `modules/gui/qt/dialogs/toolbar/qml/ToolbarEditor.qml`, `ToolbarEditorButtonList.qml`, `EditorDNDDelegate.qml` (layout: icon grid with caption under each item, as in the Figma "Player – customize" frames; radii and spacing from `RedesignStyle`)
- Modify: `modules/gui/qt/player/qml/MiniPlayer.qml` (bar height, cover radius, progress style from Figma)

**Interfaces:**
- Consumes: `RedesignStyle` (Task 4), the icons (Task 8).

- [ ] **Step 1:** Take screenshots of the current dialog and mini player in the dev build at 100% scaling; save them to `docs/redesign/screens/r1-before/`.
- [ ] **Step 2:** Apply the changes. Keep every edit inside existing components (property values and delegate layout only). If a file needs more than ~30 changed lines, copy it to `redesign/dialogs/` and point `ToolbarEditorDialog` at the copy instead.
- [ ] **Step 3:** Screenshot again into `docs/redesign/screens/r1-after/`. Compare with the Figma frames: grid layout, captions, spacing and the accent "Save" button match. Drag-and-drop between the bar and the grid still works, including dragging items out to remove them.
- [ ] **Step 4:** Log the touchpoints. Commit: `qt: re-skin control bar editor and mini player`.

### Task 13: Branding

**Files:**
- Create: `modules/gui/qt/redesign/cpp/branding.hpp` (`redesign::productName()`, `redesign::productWebsite()`)
- Modify: `meson_options.txt` (`option('redesign_product_name', type: 'string', value: '<from branding.md>')`)
- Modify: `extras/package/win32/NSIS/vlc.win32.nsi.in` (lines 6–11: `PRODUCT_NAME`, `PRODUCT_GROUP`, `PRODUCT_PUBLISHER`, `PRODUCT_WEB_SITE`; installer icon/bitmap paths)
- Modify: `share/` Windows icon files listed in `branding.md` (exe/installer `.ico`)
- Modify: each user-visible "VLC media player" string in `modules/gui/qt` (window title, About, tray tooltip) to use `redesign::productName()` when redesign is enabled

**Interfaces:**
- Produces: `QString redesign::productName();` from the meson option, passed as `-DREDESIGN_PRODUCT_NAME`.

- [ ] **Step 1:** Run `grep -rn "VLC media player" modules/gui/qt --include=*.cpp --include=*.qml`. Record the list in the commit message body.
- [ ] **Step 2:** Replace each hit with `redesign::productName()` (C++) or a `MainCtx`-exposed property (QML); keep `qtr()` around composed strings. Change the NSIS defines and icons.
- [ ] **Step 3:** Run `bash extras/redesign/dev-build.sh --release` and then `ninja -C build-win64/win64-meson package-win32-exe`. Install the resulting `.exe` on a clean Windows VM. Expected: installer, Start menu, window title, About dialog and Apps & Features all show the new name and icon. About also shows "built on VLC" and the source link, and the font licence is listed.
- [ ] **Step 4:** Log the touchpoints. Commit: `build: apply fork branding`.

### Task 14: Fork update channel

**Files:**
- Modify: `include/vlc_pgpkey.h` (replace `videolan_public_key_longid` and `videolan_public_key` with the fork key from Task 3; keep the identifiers)
- Modify: `src/misc/update.c` (~lines 78–80: `UPDATE_VLC_STATUS_URL` → `<update URL base from branding.md>/status`)
- Modify: `meson_options.txt` + root `meson.build` (~line 1009: `vlc_version_extra` from `get_option('redesign_build_number')`, default 0)
- Create: `extras/redesign/make-status.sh`

**Interfaces:**
- Produces: `extras/redesign/make-status.sh <build_number> <installer_url> <notes_file> <out_dir>`.
  - Writes `out_dir/status-win-x64` with line 1 `4.0.0.<build_number>`, line 2 `<installer_url>`, then the notes. This is the format `update.c` parses.
  - Writes the detached signature `status-win-x64.asc` with `gpg --armor --detach-sign`.
  - Signs the installer as `<installer>.asc`.
- Consumes: the GitHub secret `UPDATE_GPG_KEY`.

- [ ] **Step 1:** Run `make-status.sh 1 https://example.invalid/x.exe notes.txt out/` with a throwaway key. Then run `gpg --verify out/status-win-x64.asc out/status-win-x64`. Expected: "Good signature"; line 1 is `4.0.0.1`.
- [ ] **Step 2:** Apply the key, URL and version changes.
- [ ] **Step 3:** Build with `-Dredesign_build_number=1`. Serve `status-win-x64` built with N=2 from a test release. Launch and run Help → Check for Updates. Expected: it offers version `4.0.0.2` from the fork URL. Tamper with one byte of the status file: it then reports a signature failure and offers nothing.
- [ ] **Step 4:** Log the touchpoints. Commit: `update: point updater at fork channel with fork signing key`.

### Task 15: Release workflow and v0.1.0

**Files:**
- Create: `.github/workflows/redesign-release.yml`
- Create: `docs/redesign/smoke-checklist.md`

**Interfaces:**
- Consumes: Tasks 1, 13 and 14. Secrets: `UPDATE_GPG_KEY`, `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, plus the Trusted Signing account/profile names.
- Produces: on tag `v*.*.*`, a GitHub Release with the signed NSIS installer, a portable `.zip`, `status-win-x64` + `.asc`, and the installer `.asc`.

- [ ] **Step 1:** Write the workflow.
  - Build: `-r -i r` with `REDESIGN_MESON_FLAGS="-Dredesign_build_number=${{ github.run_number }}"`. `build.sh` resets `MCONFIGFLAGS` at ~line 506, so add one line after the `--buildtype` block (~line 520): `MCONFIGFLAGS="$MCONFIGFLAGS $REDESIGN_MESON_FLAGS"`, and log it as a touchpoint.
  - Sign `vlc.exe`, `*.dll` and the installer with `azure/trusted-signing-action`.
  - Run `make-status.sh` and upload the release assets.
- [ ] **Step 2:** Write `smoke-checklist.md` with the spec §8 manual matrix as checkboxes.
- [ ] **Step 3:** Push tag `v0.1.0-rc1` on a fork test branch. Expected: a Release with all assets; installing on Windows 10 and 11 shows no SmartScreen "unknown publisher" warning (warnings based on download reputation may still appear).
- [ ] **Step 4:** Run the smoke checklist on rc1, fix the issues, then tag `v0.1.0`. Commit: `ci: add signed release workflow and smoke checklist`.

---

## Release R2 — Window layout (Months 4–8, ships v0.2.0)

### Task 16: Shell state machine

**Files:**
- Create: `modules/gui/qt/redesign/shell/ShellStates.qml`
- Test: `modules/gui/qt/tests/tst_ShellStates.qml`

**Interfaces:**
- Produces a `ShellStates` component (uses `FSM` / `FSMState` from `VLC.Util`).
  - Inputs (properties): `bool playerView`, `bool fullscreen`, `bool minimalView`, `bool canShowVideoPIP`, `bool panelRequested`.
  - Outputs (readonly):
    - `string state` ∈ `"browse" | "watch" | "immersive"`;
    - `string panelMode` ∈ `"hidden" | "docked" | "overlay"`;
    - `bool miniPlayerShowsVideo`.
  - Rules:
    - `immersive` if `fullscreen || minimalView`, else `watch` if `playerView`, else `browse`.
    - `panelMode`: `hidden` in `immersive` or when `!panelRequested`. In `watch`, `docked` if `canShowVideoPIP`, else `overlay`. In `browse`, `docked`.
    - `miniPlayerShowsVideo = state === "browse" && canShowVideoPIP`.

- [ ] **Step 1: Write the failing test,** data-driven over these rows:

  | playerView | fullscreen | minimalView | canShowVideoPIP | panelRequested | state | panelMode | miniPlayerShowsVideo |
  |---|---|---|---|---|---|---|---|
  | false | false | false | true | true | browse | docked | true |
  | false | false | false | false | true | browse | docked | false |
  | true | false | false | true | true | watch | docked | false |
  | true | false | false | false | true | watch | overlay | false |
  | true | false | false | true | false | watch | hidden | false |
  | true | true | false | true | true | immersive | hidden | false |
  | false | false | true | true | true | immersive | hidden | false |

  Also test that toggling `fullscreen` from `watch` and back returns to `watch` with the same `panelMode`.
- [ ] **Step 2:** Run `meson test tst_ShellStates`. Expected: FAIL.
- [ ] **Step 3:** Implement with `FSM`. Inputs feed signals through property change handlers.
- [ ] **Step 4:** Run it. Expected: PASS.
- [ ] **Step 5:** Commit: `qt: add redesign shell state machine`.

### Task 17: Rail model and navigation mapping

**Files:**
- Create: `modules/gui/qt/redesign/shell/RailModel.qml`, `modules/gui/qt/redesign/shell/Rail.qml`
- Test: `modules/gui/qt/tests/tst_RailModel.qml`

**Interfaces:**
- Produces `RailModel` with:
  - `property bool hasMediaLibrary`
  - `readonly property var items`: an array of `{id, path: [..], icon, label, requiresML}` in Figma order:
    - `home ["home"]`, `video ["video"]`, `music ["music"]`, `network ["network"]`, `playlists ["video","playlists"]`, `recent ["home","recent"]`, `add` (action, `path: []`).
    - `requiresML` is true for home, video, music, playlists and recent.
  - `function visibleItems(): var`: filters out `requiresML` items when `!hasMediaLibrary`.
  - `function indexForPath(viewPath: var): int`: the longest prefix match over `visibleItems()`, `-1` if none.
  - `function defaultPath(): var`: `["home"]` with ML, `["network"]` without.
- `Rail.qml`: a collapsed/expanded rail. `expanded` is persisted with `QtCore.Settings { category: "redesign" }`. Activating an item calls `History.push(item.path)`; `add` opens `DialogsProvider.simpleOpenDialog()`.

- [ ] **Step 1: Write the failing test.**
  ```qml
  function test_noML() { rail.hasMediaLibrary = false
    compare(rail.visibleItems().map(i => i.id), ["network", "add"])
    compare(rail.defaultPath(), ["network"]) }
  function test_index() { rail.hasMediaLibrary = true
    compare(rail.items[rail.indexForPath(["video","playlists","all"])].id, "playlists")
    compare(rail.items[rail.indexForPath(["video","all"])].id, "video")
    compare(rail.indexForPath(["mlsettings"]), -1) }
  ```
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement `RailModel` and `Rail.qml`. Rail item visuals come from the Figma `sidebar` component (collapsed and expanded).
- [ ] **Step 4:** Run it. Expected: PASS.
- [ ] **Step 5:** Commit: `qt: add redesign rail`.

### Task 18: Redesign root window and loader switch

**Files:**
- Create: `modules/gui/qt/redesign/shell/RedesignInterface.qml`, `TitleBar.qml`
- Modify: `modules/gui/qt/maininterface/mainui.cpp` (~line 167, component URL)
- Modify: `modules/gui/qt/redesign/cpp/redesign.hpp/.cpp`
- Test: extend `modules/gui/qt/tests/test_redesign_option.cpp`

**Interfaces:**
- Produces: `QUrl redesign::rootQmlUrl(bool enabled);`
  - `true` → `qrc:/qt/qml/VLC/Redesign/RedesignInterface.qml`
  - `false` → `qrc:/qt/qml/VLC/MainInterface/MainInterface.qml`
- `RedesignInterface.qml`:
  - Layout per spec §4: `TitleBar` (wraps `Widgets.CSDWindowButtonSet` and `CSDTitlebarTapNDrapHandler`; shows the product name and the current page title), `Rail`, slots for `LibraryPanel`, `Stage`, `ControlBar`, and `ShellStates` bound to `MainCtx.playerView`, `Player.fullscreen`, `MainCtx.minimalView` and `MainCtx.canShowVideoPIP`.
  - It keeps the global pieces `MainInterface.qml` provides: the `GlobalShortcuts` loader, drop area (`MainPlaylistController.append(urls, true)`) and dialogs. Each is reused by instantiating the same upstream component, not by copying it.

- [ ] **Step 1: Write the failing test.**
  ```cpp
  void rootUrl() {
      QCOMPARE(redesign::rootQmlUrl(true),  QUrl("qrc:/qt/qml/VLC/Redesign/RedesignInterface.qml"));
      QCOMPARE(redesign::rootQmlUrl(false), QUrl("qrc:/qt/qml/VLC/MainInterface/MainInterface.qml"));
  }
  ```
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement `rootQmlUrl`. In `mainui.cpp`, use `redesign::rootQmlUrl(redesign::isEnabled(VLC_OBJECT(m_intf)))`. Build `RedesignInterface.qml` and `TitleBar.qml`; at this point the Stage simply hosts the upstream `MainDisplay`/`Player` pages, which Task 19 replaces.
- [ ] **Step 4:** Run it. Expected: PASS. Dev build: the new title bar and Rail appear; dragging and maximising work, including Windows 11 snap layouts on hovering maximise; dropping a file plays it; global shortcuts work. `--no-qt-redesign` gives the stock UI.
- [ ] **Step 5:** Log the touchpoint. Commit: `qt: load redesign root window behind qt-redesign`.

### Task 19: LibraryPanel, Stage, MiniPlayer card and fallback

**Files:**
- Create: `modules/gui/qt/redesign/shell/LibraryPanel.qml`, `Stage.qml`, `modules/gui/qt/redesign/player/MiniPlayerCard.qml`, `modules/gui/qt/redesign/player/ControlBar.qml`
- Modify: `modules/gui/qt/redesign/shell/RedesignInterface.qml`

**Interfaces:**
- Consumes: `ShellStates` (Task 16), `RailModel` (Task 17), the upstream page components (`VideoDisplay`, `MusicDisplay`, `BrowseDisplay`, `DiscoverDisplay`) loaded through `Widgets.PageLoader` with the same `pageModel` entries as `MainDisplay.qml` ~line 107. `mlsettings` is excluded.
- `LibraryPanel`:
  - width persisted with `Settings { category: "redesign"; property int panelWidth }`;
  - resized with `Widgets.HorizontalResizeHandle`, clamped to `RedesignStyle.panelWidthMin..Max`;
  - in `watch` it shows the current page in list mode; in `browse` it is a header strip only and the page renders in the Stage.
- `Stage`: `browse` → the page; `watch` → `VideoSurface { videoSurfaceProvider: MainCtx.videoSurfaceProvider }` or the music view (Task 22); `immersive` → video only.
- `MiniPlayerCard`: visible in `browse` while `Player.playingState !== Player.PLAYING_STATE_STOPPED`. It is draggable and snaps to the 4 corners (corner persisted). It shows the `VideoSurface` when `miniPlayerShowsVideo`, otherwise the artwork. Clicking it sets `MainCtx.playerView = true`.
- `ControlBar`: wraps the upstream `PlayerControlLayout` (the customisable bar from R1), styled per the Figma Player frame.
- `panelMode === "overlay"`: the panel is drawn above the Stage with a scrim, and closes on outside click or Esc.

- [ ] **Step 1:** Implement. Keep `Stage` free of state logic; it only reads `ShellStates` outputs.
- [ ] **Step 2:** Dev build checks, with DirectComposition (default):
  - play a video → watch with the panel docked beside live video;
  - press the library icon → browse with the video live in the card;
  - drag the card to each corner and restart → the corner persists;
  - fullscreen → immersive, controls hide automatically.
- [ ] **Step 3:** Repeat with `--qt-compositor=win7` and with `--no-qt-pip-mode`. Expected: watch shows the panel as an overlay, the card shows artwork, nothing renders black, and there are no QML errors in `--verbose=2` output.
- [ ] **Step 4:** Commit: `qt: add redesign library panel, stage, mini player card and control bar`.

### Task 20: Home page with three sections

**Files:**
- Create: `modules/gui/qt/redesign/cpp/mlrecentaudiomodel.hpp/.cpp`
- Create: `modules/gui/qt/redesign/library/HomePage.qml`, `HomeSection.qml`
- Modify: `modules/gui/qt/maininterface/mainui.cpp` (register `MLRecentAudioModel` in `VLC.Redesign`)
- Test: `modules/gui/qt/tests/test_ml_recent_audio_model.cpp`

**Interfaces:**
- Produces: `class MLRecentAudioModel : public MLAudioModel`. It mirrors `MLRecentVideoModel` (`medialibrary/mlrecentvideomodel.cpp`): its loader uses `vlc_ml_count_audio_history` / `vlc_ml_list_audio_history` and it reloads on `VLC_ML_EVENT_HISTORY_CHANGED`.
- `HomePage`: three `HomeSection`s, each a horizontal `ListView` with a title and "›" link:
  - "Continue Watching" → `MLRecentVideoModel` (progress bar from the `progress` role); link → `History.push(["video"])`.
  - "Listen Again" → `MLRecentAudioModel`; link → `["music"]`.
  - "Frequently Visited Folders" → `MLFoldersModel` (ML entry points); link → `["network"]`.
  - A section with 0 items is hidden. If all three are empty, show `Widgets.EmptyLabelButton` → "Add folders" (opens the ML folders settings).

- [ ] **Step 1: Write the failing test** following `tests/test_ml_model.cpp`'s ML fixture: add 2 audio and 1 video media to history. Expected: `rowCount() == 2`, and both rows' media IDs belong to the two audio items. Clearing history (`vlc_ml_clear_history`) gives `rowCount() == 0` after the history-changed event.
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement the model and the QML. Point the Rail `home` page at `HomePage.qml` (the redesign pageModel entry, not the upstream one).
- [ ] **Step 4:** Run it. Expected: PASS. Dev build: the sections match the Figma Home frame; a fresh profile with no history shows the empty state.
- [ ] **Step 5:** Commit: `qt: add redesign home page`.

### Task 21: Breadcrumbs, grid/list view header

**Files:**
- Create: `modules/gui/qt/redesign/library/Breadcrumbs.qml`, `ViewHeader.qml`
- Create: `modules/gui/qt/redesign/util/PathText.qml` (singleton)
- Test: `modules/gui/qt/tests/tst_PathText.qml`

**Interfaces:**
- Produces: `PathText.crumbs(viewPath: var, labels: var): var`.
  - Returns `[{label, path}]`, one per prefix of `viewPath`.
  - `labels` maps a path segment to a display name (`{"video": qsTr("Videos"), "music": qsTr("Music"), …}`).
  - Unknown segments are shown as-is.
- `ViewHeader`: back/forward (`History.previous()` / next), `Breadcrumbs`, an item count, the sort control (reuses `Widgets.SortControl`), a grid/list toggle bound to `MainCtx.gridView`, and search (reuses `Widgets.SearchBox`).

- [ ] **Step 1: Write the failing test.**
  ```qml
  compare(PathText.crumbs(["video","all"], {video:"Videos", all:"All"}),
          [{label:"Videos", path:["video"]}, {label:"All", path:["video","all"]}])
  compare(PathText.crumbs([], {}), [])
  ```
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement. Install `ViewHeader` above the pages in `Stage` / `LibraryPanel`. Upstream pages' own headers are hidden with their existing `header`-visibility properties where available; otherwise leave them and log it as a follow-up in `upstream-touchpoints.md` (no upstream edits in this task).
- [ ] **Step 4:** Run it. Expected: PASS. Dev build: navigating Videos → a group → back shows correct crumbs, and clicking a crumb navigates.
- [ ] **Step 5:** Commit: `qt: add redesign breadcrumbs and view header`.

### Task 22: Music now-playing view and v0.2.0

**Files:**
- Create: `modules/gui/qt/redesign/player/MusicView.qml`
- Modify: `modules/gui/qt/redesign/shell/Stage.qml`

**Interfaces:**
- Consumes: `Player.artwork`, `Player.title`, `Player.artist`, `Player.hasVideoOutput`.
- `Stage` shows `MusicView` in `watch` when `!Player.hasVideoOutput`:
  - large square artwork with radius `RedesignStyle.radiusL` and a blurred backdrop (`Widgets.DualKawaseBlur` of the artwork);
  - the caption "<title> - <artist>";
  - a placeholder glyph when there is no artwork.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Dev build: play an MP3 with and without embedded art; it matches the Figma "Player – Music" frame apart from the waveform.
- [ ] **Step 3:** Run `smoke-checklist.md` on a `v0.2.0-rc1` tag and fix the issues. Tag `v0.2.0`. Commit: `qt: add redesign music view`.

---

## Release R3 — Settings, onboarding, dialogs (Months 8–13, ships v1.0.0)

### Task 23: SettingsModel / SettingItem

**Files:**
- Create: `modules/gui/qt/redesign/cpp/settingsmodel.hpp/.cpp`
- Modify: `modules/gui/qt/maininterface/mainui.cpp` (register the singleton `Settings` in `VLC.Redesign`)
- Test: `modules/gui/qt/tests/test_settings_model.cpp`

**Interfaces:**
- Produces:
  ```cpp
  class SettingItem : public QObject {
      Q_OBJECT
      Q_PROPERTY(QString key READ key CONSTANT)
      Q_PROPERTY(Type type READ type CONSTANT)                  // Bool, Integer, Float, String, Choice, Path, Hotkey
      Q_PROPERTY(QVariant value READ value WRITE setValue NOTIFY valueChanged)
      Q_PROPERTY(QVariant defaultValue READ defaultValue CONSTANT)
      Q_PROPERTY(QVariant min READ min CONSTANT)
      Q_PROPERTY(QVariant max READ max CONSTANT)
      Q_PROPERTY(QVariantList choices READ choices CONSTANT)    // [{value, label}] from module_config_t list
      Q_PROPERTY(QString text READ text CONSTANT)               // translated psz_text
      Q_PROPERTY(QString longText READ longText CONSTANT)       // translated psz_longtext
      Q_PROPERTY(bool requiresRestart READ requiresRestart CONSTANT)
  public:
      enum Type { Bool, Integer, Float, String, Choice, Path, Hotkey }; Q_ENUM(Type)
      Q_INVOKABLE void reset();                                 // value = defaultValue
  };
  class SettingsModel : public QObject {
      Q_OBJECT
      Q_PROPERTY(bool restartPending READ restartPending NOTIFY restartPendingChanged)
  public:
      explicit SettingsModel(vlc_object_t* obj, QObject* parent = nullptr);
      Q_INVOKABLE SettingItem* item(const QString& key);        // nullptr + msg_Err if config_FindConfig fails; cached per key
  };
  ```
  - Type mapping: `CONFIG_ITEM_BOOL→Bool`, `INTEGER→Choice` if `list_count>0` else `Integer`, `FLOAT→Float`, `STRING`/`PASSWORD→Choice` if a list exists else `String`, `LOADFILE`/`SAVEFILE`/`DIRECTORY→Path`, `KEY→Hotkey`.
  - `setValue` writes with `config_PutInt` / `config_PutFloat` / `config_PutPsz`, calls `config_SaveConfigFile(obj)`, emits `valueChanged`, and sets `restartPending` if the item `requiresRestart`.
  - A key needs a restart when its config item is in a module listed as restart-only in `settings-map.md` (column `notes` contains `restart`).

- [ ] **Step 0:** Check every row of `docs/redesign/settings-map.md` against `vlc.exe -H --advanced` from the latest dev build. Move missing keys to "Dropped (no backend)" and commit: `docs: verify settings map against build`.
- [ ] **Step 1: Write the failing tests** (libvlc instance like `test_vlc_dialog_model.cpp`, with a temp config dir via `--config=<tmp>/vlcrc`):
  - `unknownKeyIsNull`: `item("no-such-key") == nullptr`.
  - `boolRoundTrip`: `item("qt-pip-mode")` type Bool; `setValue(false)` → `config_GetInt("qt-pip-mode") == 0`, and a fresh libvlc with the same config sees false.
  - `choiceHasLabels`: `item("short-jump-size")` type Integer, `min`/`max` from the module definition; `item("aout")` type Choice with non-empty `choices`.
  - `resetRestoresDefault`.
  - `restartFlag`: setting a restart-marked key sets `restartPending`.
  - `sameObjectPerKey`: `item("qt-pip-mode") == item("qt-pip-mode")`.
- [ ] **Step 2:** Run `meson test test_qt_settings_model`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Rerun. Expected: PASS.
- [ ] **Step 5:** Commit: `qt: add redesign settings model`.

### Task 24: EffectsController

**Files:**
- Create: `modules/gui/qt/redesign/cpp/effectscontroller.hpp/.cpp`
- Modify: `modules/gui/qt/maininterface/mainui.cpp` (register the singleton `Effects`)
- Test: `modules/gui/qt/tests/test_effects_controller.cpp`

**Interfaces:**
- Produces (singleton `Effects`):
  ```cpp
  Q_PROPERTY(bool equalizerEnabled ...)        // "audio-filter" contains "equalizer"
  Q_PROPERTY(QStringList equalizerPresets ...) // names from audio_filter/equalizer_presets.h, in order
  Q_PROPERTY(QString equalizerPreset ...)      // "equalizer-preset"
  Q_PROPERTY(QVariantList equalizerBands ...)  // 10 floats (dB), "equalizer-bands"
  Q_PROPERTY(double equalizerPreamp ...)       // "equalizer-preamp"
  Q_PROPERTY(bool twoPass ...)                 // "equalizer-2pass"
  Q_PROPERTY(bool compressorEnabled ...)  Q_PROPERTY(QVariantMap compressor ...)   // "compressor-*" keys
  Q_PROPERTY(bool spatializerEnabled ...) Q_PROPERTY(QVariantMap spatializer ...)  // "spatializer-*"
  Q_PROPERTY(bool stereoWidenEnabled ...) Q_PROPERTY(QVariantMap stereoWiden ...)  // "stereowiden-*"
  Q_PROPERTY(bool videoAdjustEnabled ...) Q_PROPERTY(QVariantMap videoAdjust ...)  // "contrast","brightness","hue","saturation","gamma"
  Q_INVOKABLE void setCrop(int top, int bottom, int left, int right);              // vout "crop-*"
  Q_INVOKABLE void applyEqualizerPreset(const QString& name);                      // sets bands + preamp from preset table
  ```
  Each setter applies `var_Set*` to `vlc_player_aout_Hold` / the main vout when present (logic ported from `dialogs/extended/extended_panels.cpp` lines ~800–1100) and always writes config. With no aout, it writes config only.

- [ ] **Step 1: Write the failing tests** (libvlc instance, no playback → no aout):
  - `presetsListed`: `equalizerPresets` contains "flat" and "rock"; the count equals `NB_PRESETS`.
  - `applyPresetWritesConfig`: `applyEqualizerPreset("rock")` → `config_GetPsz("equalizer-preset") == "rock"`, and the `"equalizer-bands"` string equals the joined `eqz_preset_10b[rock].f_amp` values (format `%.1f` with spaces).
  - `enableEqualizerAddsFilter`: `equalizerEnabled = true` → `config "audio-filter"` contains `equalizer`; `false` removes only `equalizer`, keeping other filters (e.g. a pre-set `"normvol"`).
  - `videoAdjustWritesConfig`: `videoAdjust = {brightness: 1.2}` → `config_GetFloat("brightness") == 1.2f`.
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Rerun. Expected: PASS. Dev build: while audio plays, changing the EQ band slider through a temporary QML test page changes the sound immediately.
- [ ] **Step 5:** Commit: `qt: add redesign effects controller`.

### Task 25: ShortcutsModel

**Files:**
- Create: `modules/gui/qt/redesign/cpp/shortcutsmodel.hpp/.cpp`
- Test: `modules/gui/qt/tests/test_shortcuts_model.cpp`

**Interfaces:**
- Produces a `QAbstractListModel`:
  - roles `actionKey` (e.g. `"key-play-pause"`), `label` (translated `psz_text`), `hotkey` (string, VLC key syntax), `globalHotkey` (`"global-key-*"`).
  - `Q_INVOKABLE QString conflictFor(const QString& actionKey, const QString& hotkey, bool global)`: the label of the action already using `hotkey` in the same scope, `""` if none.
  - `Q_INVOKABLE void assign(const QString& actionKey, const QString& hotkey, bool global)`: clears the conflicting action, writes config, saves.
  - Actions are enumerated from config items of type `CONFIG_ITEM_KEY` (the same source as `KeySelectorControl`).

- [ ] **Step 1: Write the failing tests:**
  - `listsActions`: `rowCount() > 50`; it contains `key-play-pause`.
  - `conflictDetected`: `conflictFor("key-stop", <current hotkey of key-play-pause>, false)` returns the play/pause label.
  - `assignClearsConflict`: after `assign`, the old action's hotkey is `""` in the model and in config.
  - `globalScopeSeparate`: the same key in a global vs local scope is not a conflict.
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run it. Expected: PASS.
- [ ] **Step 5:** Commit: `qt: add redesign shortcuts model`.

### Task 26: SettingRow and generic controls

**Files:**
- Create: `modules/gui/qt/redesign/settings/SettingRow.qml`, `controls/ToggleControl.qml`, `controls/DropdownControl.qml`, `controls/SliderControl.qml`, `controls/NumberControl.qml`, `controls/PathControl.qml`, `controls/TextControl.qml`
- Create: `modules/gui/qt/redesign/settings/ControlChooser.qml` (singleton)
- Test: `modules/gui/qt/tests/tst_ControlChooser.qml`

**Interfaces:**
- Consumes: `SettingItem.Type` (Task 23).
- Produces:
  - `ControlChooser.controlFor(type: int, hasRange: bool, hint: string): string` returns a control file name:
    - Bool → `ToggleControl.qml`
    - Choice → `DropdownControl.qml`
    - Integer/Float with `hint === "slider"` and `hasRange` → `SliderControl.qml`
    - Integer/Float otherwise → `NumberControl.qml`
    - Path → `PathControl.qml`
    - String → `TextControl.qml`
    - Hotkey → `""` (handled by the shortcuts page)
  - `SettingRow { key: string; hint: string }` looks up `Settings.item(key)`. It is `visible: item !== null`, shows `item.text`, puts `item.longText` in an info tooltip (Figma "ⓘ"), and loads the control. The control's `value` is bound to `item.value`; on edit it calls `item.value = v`.

- [ ] **Step 1: Write the failing test** covering each mapping above, including `controlFor(SettingItem.Integer, false, "slider") === "NumberControl.qml"`.
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement the chooser and the controls (visuals from the Figma `Toggle`, `Dropdown` and `Values` components).
- [ ] **Step 4:** Run it. Expected: PASS.
- [ ] **Step 5:** Commit: `qt: add redesign setting row and controls`.

### Task 27: Settings modal with 13 pages and search

**Files:**
- Create: `modules/gui/qt/redesign/settings/SettingsModal.qml`, `SettingsSidebar.qml`, `SettingsSearch.qml` (singleton)
- Create: `modules/gui/qt/redesign/settings/pages/GeneralPage.qml`, `InterfacePage.qml`, `PrivacyPage.qml`, `ControlsPage.qml`, `PlaybackPage.qml`, `VideoPage.qml`, `AudioPage.qml`, `SubtitlesPage.qml`, `LibraryPage.qml`, `NetworkPage.qml`, `PerformancePage.qml`, `RecordingPage.qml`, `ExtensionsPage.qml`
- Create: `modules/gui/qt/redesign/settings/EqualizerPanel.qml`, `ShortcutsPage.qml` (reachable from Controls)
- Test: `modules/gui/qt/tests/tst_SettingsSearch.qml`

**Interfaces:**
- Consumes: `SettingRow` (Task 26), `Effects` (Task 24), `ShortcutsModel` (Task 25), `MLFoldersModel`, the upstream extensions model, and `docs/redesign/settings-map.md` (one `SettingRow` per mapped row, in Figma order).
- Produces:
  - `SettingsSearch.filter(index: var, query: string): var`.
    - `index` is `[{page, label, description}]`; the result is the matching entries.
    - Matching is case-insensitive substring on label or description; an empty query returns `[]`.
    - Results are ordered page-first, by the sidebar order.
  - `SettingsModal`: opened from the Rail ("⚙" in the title bar menu) and from `MainCtx`'s preferences action when redesign is on.
    - The sidebar has groups App (General, Interface, Privacy, Controls), Media (Playback, Video, Audio, Subtitles, Library) and System (Network, Performance, Recording, Extensions).
    - Each page has a header and a "Reset to defaults" button that calls `reset()` on each row.
    - A restart banner shows while `Settings.restartPending`.
    - An "Advanced…" link calls `DialogsProvider.prefsDialog()` (QWidgets advanced view).
  - The Interface page shows the 9 accent swatches from `Settings.accentSwatches` and writes `qt-accent-color` as `#rrggbb`. Theme Light/Dark/System sets `MainCtx.colorScheme.currentIndex` (the existing `ColorSchemeModel`).

- [ ] **Step 1: Write the failing test.**
  ```qml
  const idx = [{page:"audio", label:"Normalize loudness", description:""},
               {page:"video", label:"Hardware decoding", description:"Use GPU"}]
  compare(SettingsSearch.filter(idx, "gpu").map(e => e.page), ["video"])
  compare(SettingsSearch.filter(idx, "LOUD").length, 1)
  compare(SettingsSearch.filter(idx, ""), [])
  ```
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement the modal, sidebar, 13 pages, `EqualizerPanel` (10 vertical sliders + preamp + preset dropdown, per the Figma "Settings – audio" frame) and `ShortcutsPage`. Add `Q_PROPERTY(QVariantList accentSwatches CONSTANT)` to `SettingsModel`, returning `redesign::accentSwatches()` as `#rrggbb` strings.
- [ ] **Step 4:** Run it. Expected: PASS. Dev build, every page:
  - each row reflects the current value;
  - changing it persists across a restart;
  - a key from a plugin missing in the build hides its row (Review Focus 4);
  - searching "subtitle" lists Subtitles rows.
- [ ] **Step 5:** Commit: `qt: add redesign settings modal`.

### Task 28: Onboarding

**Files:**
- Create: `modules/gui/qt/redesign/settings/Onboarding.qml`, `OnboardingSteps.qml`
- Modify: `modules/gui/qt/maininterface/mainctx.cpp` (~line 267: when redesign is enabled, emit a new signal `requestRedesignOnboarding()` instead of `THEDP->firstRunDialog()`)
- Modify: `modules/gui/qt/maininterface/mainctx.hpp` (declare the signal)
- Test: `modules/gui/qt/tests/tst_OnboardingSteps.qml`

**Interfaces:**
- Produces `OnboardingSteps`, a pure model:
  - `property bool hasMediaLibrary`
  - `readonly property var steps`: `["theme", "privacy", "folders", "done"]`, without `"folders"` when `!hasMediaLibrary`
  - `property int current`
  - `function next()` and `function back()`, clamped to range
  - `readonly property bool canFinish` (`current === steps.length - 1`)
- `Onboarding.qml`: a modal over the shell.
  - **theme** step: Light/Dark/System + 9 swatches, applied live.
  - **privacy** step: `metadata-network-access` and `qt-updates-notif` rows.
  - **folders** step: the `MLFoldersModel` list with add/remove.
  - **Finish:** `Settings.item("qt-privacy-ask").value = false`, then `MediaLib.reload()`, matching what `firstrunwizard.cpp` does at ~line 139.

- [ ] **Step 1: Write the failing test:**
  - `steps` with and without ML;
  - `next()` past the end stays on `"done"`; `back()` at 0 stays at 0;
  - `canFinish` only on the last step.
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement. `RedesignInterface.qml` connects `MainCtx.requestRedesignOnboarding` to open `Onboarding`.
- [ ] **Step 4:** Run it. Expected: PASS. Dev build with a fresh profile (`--config=<tmp>`): onboarding shows, Finish persists (no onboarding on the next launch), and the ML scan starts. With `--no-qt-redesign` and a fresh profile, the old QWidgets wizard shows.
- [ ] **Step 5:** Log the touchpoints. Commit: `qt: add redesign onboarding`.

### Task 29: New playlist and Open network stream dialogs

**Files:**
- Create: `modules/gui/qt/redesign/dialogs/NewPlaylistDialog.qml`, `OpenNetworkStreamDialog.qml`
- Create: `modules/gui/qt/redesign/util/StreamUrl.qml` (singleton)
- Test: `modules/gui/qt/tests/tst_StreamUrl.qml`

**Interfaces:**
- Produces: `StreamUrl.normalize(text: string): string`.
  - Trims whitespace.
  - Adds `https://` when there is no scheme and the text contains a dot (`"example.org/a.m3u8"` → `"https://example.org/a.m3u8"`).
  - Keeps known schemes (`http`, `https`, `rtsp`, `rtmp`, `udp`, `rtp`, `mms`, `smb`, `ftp`, `sftp`, `file`) as-is.
  - Returns `""` for empty or whitespace input.
  - `StreamUrl.isValid(text): bool` is `normalize(text) !== ""`.
- `NewPlaylistDialog`: a name field (Create is disabled while the trimmed name is empty). It calls `MLPlaylistListModel.create(name, initialItems)`, where `initialItems` is the selected media IDs it was opened with, or `[]`.
- `OpenNetworkStreamDialog`: a URL field plus a recent-URLs list (`MLUrlModel`). Play → `MainPlaylistController.append([StreamUrl.normalize(text)], true)`. Enter submits; Play is disabled while invalid.

- [ ] **Step 1: Write the failing test** covering each normalize rule above, plus `normalize("  rtsp://cam/1 ") === "rtsp://cam/1"` and `normalize("hello") === "hello"` (no dot → unchanged).
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement the dialogs on `VLC.Dialogs` `ModalDialog`, and route the Rail "Add" menu and the title bar menu to them.
- [ ] **Step 4:** Run it. Expected: PASS. Dev build: create a playlist (it appears under Playlists); play an `https` HLS URL.
- [ ] **Step 5:** Commit: `qt: add redesign new playlist and network stream dialogs`.

### Task 30: Add subtitles and Keyboard shortcuts dialogs

**Files:**
- Create: `modules/gui/qt/redesign/dialogs/AddSubtitlesDialog.qml`, `KeyboardShortcutsDialog.qml`
- Create: `modules/gui/qt/redesign/util/SubtitleMatch.qml` (singleton)
- Create: `modules/gui/qt/redesign/cpp/subtitleattacher.hpp/.cpp` (registered as singleton `SubtitleAttacher` in `mainui.cpp`)
- Test: `modules/gui/qt/tests/tst_SubtitleMatch.qml`

**Interfaces:**
- Produces: `SubtitleMatch.pair(videoNames: var, subtitleNames: var): var`.
  - Returns `[{video, subtitle}]`, pairing each video with the subtitle whose base name (minus extension and an optional `.lang` suffix like `.en`) equals the video's base name, case-insensitive.
  - Unmatched videos get `subtitle: ""`.
  - The order follows `videoNames`.
- `SubtitleAttacher`:
  - `Q_INVOKABLE bool attachToCurrent(const QUrl& sub)` calls `PlayerController::AddAssociatedMedia(SPU_ES, sub.toString(), true, true, false)` and returns `== VLC_SUCCESS`.
  - `Q_INVOKABLE int attachToPlaylist(const QVariantList& pairs)` takes `pairs` as `[{index: int, subtitle: QUrl}]` over the main playlist. For each pair it calls `input_item_AddSlave(item, input_item_slave_New(url, SLAVE_TYPE_SPU, SLAVE_PRIORITY_USER))` on that playlist item's `input_item_t`, and returns the number attached.
- `AddSubtitlesDialog` has three modes from the Figma frames:
  - **current file:** `attachToCurrent`;
  - **playlist:** `pair()` over the queue names, review, then `attachToPlaylist`;
  - **folder:** pick a folder, list its videos and subtitles, `pair()`, review, append the videos to the queue with `MainPlaylistController.append`, then `attachToPlaylist` on the new indices.
- `KeyboardShortcutsDialog`: the `ShortcutsModel` list with search, click-to-record, and a conflict prompt with the text `qsTr("%1 is already used by \"%2\". Replace?")`.

- [ ] **Step 1: Write the failing test.**
  ```qml
  compare(SubtitleMatch.pair(["S01E01.mkv","S01E02.mkv"], ["s01e01.en.srt","S01E03.srt"]),
          [{video:"S01E01.mkv", subtitle:"s01e01.en.srt"}, {video:"S01E02.mkv", subtitle:""}])
  ```
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement both dialogs.
- [ ] **Step 4:** Run it. Expected: PASS. Dev build: add an `.srt` to the playing video (subtitles show); remap Play/Pause to `Ctrl+P` (it works after closing, and the old binding is cleared).
- [ ] **Step 5:** Run the smoke checklist on `v1.0.0-rc1` and fix the issues. Tag `v1.0.0`. Commit: `qt: add redesign subtitles and shortcuts dialogs`.

---

## Release R4 — Polish (Months 13–15, ships v1.1.0)

### Task 31: Waveform peaks provider

**Files:**
- Create: `modules/gui/qt/redesign/cpp/waveform.hpp/.cpp`
- Modify: `modules/gui/qt/maininterface/mainui.cpp` (register `WaveformProvider`)
- Test: `modules/gui/qt/tests/test_waveform.cpp`

**Interfaces:**
- Produces:
  ```cpp
  namespace redesign {
  QVector<float> computePeaks(const int16_t* samples, size_t count, int buckets); // max |s|/32768 per bucket, size == buckets; count < buckets -> trailing zeros
  QByteArray encodePeaks(const QVector<float>&);   // little-endian float32
  QVector<float> decodePeaks(const QByteArray&);   // empty on size % 4 != 0
  }
  class WaveformProvider : public QObject {
      Q_OBJECT
      Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged)
      Q_PROPERTY(QVariantList peaks READ peaks NOTIFY peaksChanged)     // 1000 values in [0,1], empty until ready
      Q_PROPERTY(bool ready READ ready NOTIFY peaksChanged)
  };
  ```
  - `WaveformProvider` does nothing for non-`file://` URLs, which stay `ready == false`.
  - Otherwise, on a worker thread, it runs a libvlccore input with `:sout=#transcode{acodec=s16l,channels=1,samplerate=8000}:std{access=file,mux=wav,dst=<tmp>.wav}` and `:no-sout-video`. It then reads the WAV PCM, calls `computePeaks(…, 1000)`, and caches `encodePeaks` at `<userdata>/redesign/waveforms/<sha1(url)>.bin`.
  - A cache hit skips decoding. A new `url` cancels the running job.

- [ ] **Step 1: Write the failing tests:**
  - `peaksOfSilence`: all zeros → 1000 zeros.
  - `peakValue`: one sample at 16384 in bucket 3 → `peaks[3] == 0.5f`, the others 0.
  - `shortInput`: 10 samples, 1000 buckets → size 1000 with no crash.
  - `encodeRoundTrip`.
  - `decodeRejectsOddSize`.
  - `streamUrlNeverReady`: `setUrl("https://x/a.mp3")` → `ready` stays false after a 200 ms event loop.
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run it. Expected: PASS. Dev build: a 4-minute MP3 yields peaks in under 10 s on a typical machine, and replaying uses the cache (instant).
- [ ] **Step 5:** Commit: `qt: add waveform peaks provider`.

### Task 32: Waveform seek bar

**Files:**
- Create: `modules/gui/qt/redesign/player/WaveformSeekBar.qml`
- Modify: `modules/gui/qt/redesign/player/ControlBar.qml`

**Interfaces:**
- Consumes: `WaveformProvider` (Task 31), `Player.position`, `Player.jumpToPos(double)`.
- When `!Player.hasVideoOutput && provider.ready`, the control bar shows `WaveformSeekBar`:
  - drawn with QtQuick `Shape` bars (one per peak, decimated to the available width);
  - played part in the accent colour, rest in `theme.fg.secondary`;
  - click/drag seeks.
  - Otherwise the standard seek bar is shown.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Dev build: an MP3 shows the waveform after the scan, and seeking by click and drag works. A network audio stream keeps the normal bar. Video files keep the normal bar.
- [ ] **Step 3:** Commit: `qt: add waveform seek bar`.

### Task 33: Light theme, accessibility and performance pass; v1.1.0

**Files:**
- Modify: `modules/gui/qt/style/redesignpalette.cpp` (light values per the "Player – Light" frame)
- Modify: `modules/gui/qt/redesign/**/*.qml` (accessibility)
- Create: `extras/redesign/check_a11y.py`

**Interfaces:**
- Produces: `python3 extras/redesign/check_a11y.py modules/gui/qt/redesign`. It exits 1 and lists every QML item of type `*Button*`, `*Control`, `ToggleControl`, `DropdownControl`, `SliderControl` or `MouseArea` used as a button that lacks `Accessible.name` or `Accessible.role`.

- [ ] **Step 1:** Write `check_a11y.py` and run it. Expected: exit 1 with a list.
- [ ] **Step 2:** Add `Accessible.name` / `Accessible.role` and `Navigation.*` up/down/left/right wiring for each listed item. Rerun. Expected: exit 0. Add it to CI.
- [ ] **Step 3:** Tune the light palette against the Figma "Player – Light" frame. Rerun `test_qt_redesign_palette`. Expected: PASS (AA still holds).
- [ ] **Step 4:** Performance: run with `QSG_RENDER_TIMING=1` and scroll a 2,000-item video grid; record the frame times in `docs/redesign/perf.md`. Any view with sustained frames over 16 ms gets a follow-up task in that document.
- [ ] **Step 5:** Run the smoke checklist on `v1.1.0-rc1` (including Windows Narrator reading Rail, control-bar and settings items) and fix the issues. Tag `v1.1.0`. Commit: `qt: redesign light theme, accessibility and perf pass`.

---

## Recurring: monthly upstream merge (every month from M0)

- [ ] `git fetch upstream && git switch redesign/main && git merge upstream/master`
- [ ] Resolve conflicts only in files listed in `upstream-touchpoints.md`. A conflict elsewhere means an unlogged edit: log it or revert it.
- [ ] `bash extras/redesign/dev-build.sh --tests`. Expected: all pass. Push; CI green.
- [ ] For a VideoLAN security advisory: same steps immediately, then tag a patch release (Task 15 workflow).
