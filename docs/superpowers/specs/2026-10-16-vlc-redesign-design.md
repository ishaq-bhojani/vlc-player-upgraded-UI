# VLC Redesign — Design Spec

- **Date:** 2026-10-16
- **Status:** Draft, awaiting review
- **Design source:** Figma "VLC Redesign (Community)" — https://www.figma.com/design/eC0K7svcmp8c5LAM0PJiQo/VLC-Redesign--Community-?node-id=0-1
- **Codebase:** VLC `4.0.0-dev` fork (`origin` = ishaq-bhojani/vlc-player-upgraded-UI, `upstream` = videolan/vlc)

## 1. Goal and constraints

Ship a Windows build of VLC 4 whose Qt interface implements the Figma redesign, and distribute it to other users.

| Constraint | Decision |
|---|---|
| Purpose | A distributed fork with installers, a self-hosted update channel, and ongoing merges of upstream security fixes |
| Platform | Windows 10/11 x64 only. Linux may follow later; macOS is out of scope because it uses a separate Cocoa interface |
| Capacity | One developer, part-time (about 15–20 h/week) |
| Strategy | **Re-skin first, then restructure** (approach A). New screens go in **new files, not edits to upstream files** wherever practical (rule from approach C) |

### Success criteria
1. v0.1 public beta (about month 4): the existing layout re-skinned with the new palette, accent, font, icons, control bar and mini player; distributed as a signed installer with working updates.
2. v1.0 (about month 13): the Figma window layout, Home, library, player, settings, effects, onboarding and dialogs implemented.
3. A monthly upstream merge takes **≤ 1 working session** and never requires reworking redesign code beyond the files listed in `docs/redesign/upstream-touchpoints.md`.
4. No regression in keyboard navigation, High Contrast mode, or 100–200% display scaling compared with upstream.

### Non-goals
- The skins2, macOS and ncurses interfaces.
- Redesigning screens absent from Figma: media info, convert/stream, VLM, EPG, messages, plugins, the advanced preferences tree. They receive the palette in Release 1 and otherwise stay as they are.
- Contributing upstream to VideoLAN.
- MSI installer, crash reporting, telemetry.

## 2. Figma inventory → codebase mapping

The Figma file has about 60 frames at 1920×1080 and a component page.

| Figma frames | Current implementation | Treatment | Release |
|---|---|---|---|
| Palette, type, accent swatches (Onboarding) | `style/systempalette.cpp`, `VLCStyle.qml`, `qt-accent-color` option | New palette functions; Figma orange as the default accent | R1 |
| Icons (component page) | Icon font from `pixmaps/icons/*.svg` via `makeIconFont.py` | Replace glyphs under the same names; add new ones | R1 |
| Player – customize (×9) | QML `dialogs/toolbar/qml` + C++ control-bar models | Re-skin plus about 8 new control items | R1 |
| Mini player card | `player/qml/MiniPlayer.qml`, `PIPPlayer.qml` | Re-skin (R1), floating card in the new window (R2) | R1/R2 |
| Context menus, dropdowns | Native `QMenu` | Palette + Fusion style | R1 |
| Player (×7), Player – Music (×2), hide UI, Light | `MainInterface.qml` switches between `Player.qml` and `MainDisplay.qml` | New window shell in `VLC.Redesign` | R2 |
| Library grid/list, Home ("Continue Watching", "Listen Again", "Frequently Visited Folders") | `medialibrary/qml`, `network/qml` | New views on top of existing ML models | R2 |
| Settings (19 frames, 13 pages) incl. EQ / compressor / spatializer / stereo widener | QWidgets `dialogs/preferences`, `dialogs/extended` | QML modal + C++ bridges | R3 |
| Onboarding (×11) | QWidgets `dialogs/firstrun` | QML flow | R3 |
| New playlist, Open network stream, Add subtitles (×4), Keyboard shortcuts | QWidgets dialogs | QML dialogs | R3 |
| Waveform seek bar (Player – Music) | Does not exist | New feature | R4 |

## 3. Architecture and isolation from upstream

### Branches
- `master` mirrors `upstream/master` and is never edited.
- All work happens on `redesign/main`, with feature branches off it.
- Releases are built from a **pinned, tested upstream commit**. `upstream/master` is merged monthly, and immediately for security advisories. When VideoLAN creates a `4.0.x` stable branch, the fork switches to following it.

### New module `VLC.Redesign` (`modules/gui/qt/redesign/`)
```
redesign/
  shell/       RedesignInterface.qml, TitleBar, Rail, LibraryPanel, Stage, state machine
  library/     Home, grid/list views, breadcrumbs
  player/      ControlBar, MusicView, MiniPlayerCard, new control-bar items
  settings/    SettingsModal, pages, SettingRow + generic controls, Onboarding
  dialogs/     NewPlaylist, OpenNetworkStream, AddSubtitles, KeyboardShortcuts
  components/  buttons, toggles, cards, menus
  theme/       RedesignStyle.qml (singleton: spacing, radii, type, motion)
  cpp/         settingsmodel.*, effectscontroller.*, shortcutsmodel.*
```
VideoLAN's C++ models and controllers are reused unchanged: `MainCtx`, `PlayerController`, `MainPlaylistController`, the ML models, `History`, the control-bar profile models and the `FSM` helper.

### Upstream touchpoints (the only upstream files edited)
Every edit is listed in `docs/redesign/upstream-touchpoints.md` with its purpose.

| File | Change |
|---|---|
| `maininterface/mainui.cpp` (~line 167) | Load `qrc:/qt/qml/VLC/Redesign/RedesignInterface.qml` when `qt-redesign` is true |
| `qt.cpp` | Register the `qt-redesign` bool (default true) and change the `qt-accent-color` default |
| `style/systempalette.cpp` (~line 390) | When `qt-redesign` is on, call `makeRedesignDark/Light/SystemPalette()` from the new `style/redesignpalette.cpp` |
| `style/VLCStyle.qml` | R1 only: a handful of radius/height values |
| `meson.build` | One appended block registering `VLC.Redesign` and the new C++ files. The fork builds with Meson only (`build.sh -m`), so `Makefile.am` is not edited |
| `pixmaps/icons/*.svg`, `VLCIcons.json`, generated `VLCIcons.ttf` / `vlcicons.*` | Icon replacement through the generator only |
| `src/misc/update.c`, `include/vlc_pgpkey.h` | Fork status URL and public key (§7) |
| `extras/package/win32/NSIS/*` | Product name, icons and branding (§7) |

**Rule:** a change to an upstream file of more than about 30 lines becomes a new file in `VLC.Redesign` instead. `qt-redesign=false` must always fall back to the stock upstream UI. This is the escape hatch and the regression baseline.

## 4. Main window and navigation (Release 2)

```
┌ TitleBar (reuses VLC's CSD title bar: drag, snap layouts, window buttons) ┐
├ Rail ┬ LibraryPanel ┬────────── Stage ──────────────────────────┤
│ icons│ back/fwd,    │ video  |  music cover  |  library grid     │
│ ⇄    │ breadcrumb,  │                           [MiniPlayer card]│
│labels│ sort/search  │                                            │
├──────┴──────────────┴────────────────────────────────────────────┤
└ ControlBar (seek, transport, volume, customizable slots) ┘
```

- **Rail:** collapses to icons only or expands with labels. Items: Home, Videos, Music, Network, Playlists, Recent, Add. They map to the existing `History` page names (`home`, `video`, `music`, `network`, …), so menus and deep links keep working.
- **LibraryPanel:** a resizable drawer. It shows the current page as a compact list beside the video, or hands the full grid/list view to the Stage when browsing.
- **Window states**, built on `util/qml/FSM`:

| State | Stage shows | MainCtx mode |
|---|---|---|
| Browse | Library grid/list; playback continues in the floating MiniPlayer card | `MAINDISPLAY` |
| Watch | Video or music cover; LibraryPanel optionally docked | `PLAYER` |
| Immersive | Video only; UI hides automatically (hide UI, fullscreen) | `PLAYER` + fullscreen / `MINIMAL` |

  `MainCtx` stays the single source of truth for the mode. The shell keeps both views in one tree instead of swapping Loaders.
- **Video placement:** with the DirectComposition compositor, `VideoSurface` can be placed in any rectangle, the same as the existing PiP player (`maininterface/compositor.cpp` ~line 300).
- **Fallback:** when `MainCtx.canShowVideoPIP` is false (no depth buffer, Windows 7 compositor, `qt-pip-mode` off), Watch mode shows the panel as an overlay on the video, and the MiniPlayer card shows cover art instead of live video.
- **Home sections:**
  - Continue Watching: video with saved progress.
  - Listen Again: recent audio.
  - Frequently Visited Folders: recent folders / ML entry points.
  
  Each uses existing ML models, sorts and filters. A new C++ query is added only if no existing model can supply a section, and that is recorded as a plan task.
- **Music view:** large cover art with a standard seek bar until the waveform lands (R4).
- **Waveform (R4):**
  - A background libvlc decode of the current track into about 1000 peak buckets, cached on disk by media ID, and drawn as a QML `Shape` with the progress overlay.
  - It falls back to the standard seek bar for streams and while the scan is running.
- **Keyboard navigation:** uses VLC's `Navigation.*` attached properties throughout.

## 5. Theme, icons, and the Release 1 re-skin

- **Palette:**
  - `style/redesignpalette.cpp` fills the existing `ColorContext` slots (colour set × section × name × state) with Figma values. All about 290 `theme.*` reads update automatically.
  - Dark comes from the Player frames, Light from "Player – Light", and System follows `AppsUseLightTheme` through the existing Windows theme provider.
  - `docs/redesign/tokens.md` holds the Figma-name → ColorContext-slot table.
- **Accent:**
  - `qt-accent-color` defaults to the Figma orange; the 9 onboarding swatches are offered in onboarding and in Settings → Interface.
  - Hover and pressed shades are derived from the accent.
  - Text on accent backgrounds switches between black and white to meet WCAG AA (4.5:1).
- **Hard-coded colours:** the about 45 literals outside the palette (e.g. the `PlayButton.qml` gradient) are fixed only in files Release 1 touches.
- **Typography:**
  - Bundle **Inter** (OFL), load it once, and set it as the application font, which also covers the QWidgets dialogs.
  - The font family is confirmed from Figma Inspect in Month 0. If it differs, the same approach applies with that font, provided its licence allows redistribution.
  - Size steps stay in `VLCStyle`.
- **Metrics:** `RedesignStyle.qml` holds spacing, radii and motion values for new components. R1 adjusts a few `VLCStyle` values (listed as touchpoints).
- **Icons:**
  - Exported as SVG from Figma and normalised for the generator (no overlapping shapes, viewBox equal to the size).
  - Existing glyph names are replaced in place; new glyphs are added to `VLCIcons.json`.
  - fontforge is only needed on the dev machine, since generated output is committed.
  - If the icons derive from an open set, its licence is credited in About.
- **New control-bar items** (new files): file/artist/folder/playlist name labels, Go Home, Right Sidebar, Replay, Divider, a 10s/15s skip option, and **Favorite**. The media library already exposes `b_is_favorite`, so Favorite is supported. Existing items (skip, bookmark, chapters, record, snapshot, speed, loop/shuffle, PiP, info, …) are only re-skinned.
- **QWidgets dialogs and native menus:** apply a `QPalette` built from the active redesign palette, using the Fusion style.

## 6. Settings, effects, and onboarding (Release 3)

### C++ bridges (in `redesign/cpp/`)
- **`SettingsModel`:**
  - `Settings.item(key)` returns a `SettingItem` with `type`, `value`, `min`/`max`, `choices` (from the module config list), `text`/`longtext` (VLC's translated config strings) and `requiresRestart`.
  - Reads and writes go through `config_Get*` / `config_Put*`; each write saves the config file.
  - Unknown keys log an error and render nothing.
- **`EffectsController`:**
  - Live audio and video effects: equalizer bands and presets (reusing `audio_filter/equalizer_presets.h`), compressor, spatializer, stereo widener, video adjust (colours), crop.
  - The logic is ported from `dialogs/extended/extended_panels.cpp`. It applies `var_Set*` to the current aout/vout and saves to config.
  - When no output exists, it writes config only.
- **`ShortcutsModel`:** a QML model for hotkeys, ported from `KeySelectorControl`, including conflict detection.

### Settings modal
- A searchable sidebar with App / Media / System groups and 13 pages: General, Interface, Privacy, Controls, Playback, Video, Audio, Subtitles, Library, Network, Performance, Recording, Extensions.
- Pages are declarative lists of `SettingRow { key: "…" }`. The control (toggle, dropdown, slider, number, path, text) is chosen from `SettingItem.type`.
- Changes apply immediately. Each page has "Reset to defaults", and a restart banner appears when any changed item has `requiresRestart`.
- Search filters over page names and setting text and descriptions.
- **No fake switches:** `docs/redesign/settings-map.md` maps every Figma control to a VLC config key or effects call. Controls with no backend are dropped from the UI and listed in that doc.
- Library folders use the existing ML folders model; Extensions use the existing extensions manager.
- An "Advanced…" link opens the existing QWidgets advanced preferences, themed in R1.

### Onboarding
- Shown instead of the QWidgets first-run wizard when `qt-redesign` is on, using the same trigger (`qt-privacy-ask`).
- Steps: theme and accent → privacy (network metadata access, update checks — same options as the current wizard) → library folders → finish.
- All writes go through `SettingsModel`. Finishing clears `qt-privacy-ask`, exactly as the current wizard does.

### Dialogs
New playlist, Open network stream, Add subtitles (to file / playlist / folder), and Keyboard shortcuts as QML dialogs built on the existing `dialogs/dialogs/qml` modal infrastructure. They call the existing controllers (`MainPlaylistController`, ML playlist APIs, player subtitle APIs).

### Translations
Config-derived labels are already translated. New strings use `qtr()` and fall back to English until translated.

## 7. Build, release, and distribution

- **Dev build:**
  - VideoLAN's Docker image `registry.videolan.org/vlc-debian-win64-posix` (tag pinned in `extras/ci/gitlab-ci.yml`), run through Docker Desktop / WSL2, plus `extras/package/win32/build.sh` with prebuilt contribs.
  - Day-to-day UI work rebuilds only the Qt plugin.
- **CI (GitHub Actions, same image):**
  - On pull request: win64 build, `buildsystem/check_qml_module.py`, C++ QTest and QML Quick Test.
  - On tag: signed NSIS installer plus portable zip, published to GitHub Releases.
- **Branding (blocks first public release):** "VLC" and the cone are VideoLAN trademarks. The fork ships under its own product name and icon ("*Name* — built on VLC"), applied to the NSIS installer, window title, About dialog and executable metadata. The name is chosen in Month 0.
- **Updates:**
  - `src/misc/update.c` points at the fork's status file hosted on GitHub Releases; `include/vlc_pgpkey.h` embeds the fork's own public key.
  - Status files are signed in the release workflow; the private key lives only in CI secrets.
  - Users are never offered official VLC builds.
- **Code signing:** Azure Trusted Signing, or an OV certificate if identity validation for Trusted Signing isn't possible. Applied to `vlc.exe`, the DLLs and the installer.
- **GPL:** the repository stays public, licence files ship unchanged, and the installer and About dialog link to the source.
- **Upstream merges:** monthly merge of `upstream/master` → `redesign/main`, with CI and the smoke checklist passing before any release. Security advisories are merged and released immediately.

## 8. Testing

- **C++ QTest:**
  - `SettingsModel`: type mapping, read/write round trip, unknown key, restart flag.
  - `EffectsController`: config-only mode, preset load.
  - `ShortcutsModel`: conflict detection.
  - Redesign palette: every accent swatch passes WCAG AA on-accent contrast in dark and light.
  - New control-bar items: registered and constructible.
- **QML Quick Test** (same pattern as `tests/tst_FSM.qml`):
  - shell state transitions (Browse ↔ Watch ↔ Immersive, PiP fallback);
  - Rail ↔ History page mapping;
  - SettingRow control selection.
- **Manual smoke checklist (every release):**
  - Windows 10 and 11;
  - 100/150/200% display scaling;
  - light / dark / High Contrast;
  - keyboard-only navigation;
  - dcomp and win7 compositors;
  - local video, music and a network stream;
  - `qt-redesign=false` fallback;
  - key screens compared side by side with Figma exports.

## 9. Timeline (part-time, about 15–20 h/week, includes about 20% buffer)

| When | Milestone | Deliverables | Ships |
|---|---|---|---|
| Month 1 | **M0 Setup** | Docker/WSL build, GitHub Actions CI, product name/icon, Figma asset export (icons, font confirmation, colour values), `tokens.md`, `settings-map.md`, `upstream-touchpoints.md` | — |
| Months 1–4 | **R1 Re-skin** | Palettes + accent + Inter + icons; control bar + Customize Player + new control items; MiniPlayer re-skin; QWidgets palette; branding; signed installer; fork updater | **v0.1 beta**, about month 4 |
| Months 4–8 | **R2 Window layout** | `VLC.Redesign` shell, Rail, LibraryPanel, Stage, states and fallback; Home sections; grid/list views; music view | **v0.2**, about month 8 |
| Months 8–13 | **R3 Settings & dialogs** | SettingsModel, EffectsController, ShortcutsModel; settings modal (13 pages); onboarding; 4 dialogs | **v1.0**, about month 13 |
| Months 13–15 | **R4 Polish** | Waveform seek bar; light theme polish; accessibility pass; performance | v1.1 |

## 10. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Name/logo or Figma export delayed | Blocks v0.1 | Both are Month 0 tasks; development continues on placeholders, but no public release until branding is done |
| Upstream VLC 4 is unreleased and moves fast | Merge conflicts, regressions | Pinned upstream commit, monthly merges, touchpoint list, `qt-redesign=false` fallback |
| Figma file is a community file; asset export and Inspect require a signed-in account; licence terms unknown | Missing exact values or licence problem | The owner duplicates the file into their own Figma account in Month 0 and checks the community licence/attribution terms |
| Side-by-side video unavailable on some machines | Degraded layout | Overlay fallback defined in §4 and covered by tests |
| Waveform requires audio analysis that VLC lacks | R4 slip | Isolated in R4; the music view works without it |
| Part-time capacity varies | Dates slip | Each release is independently shippable; scope is cut from the end of a release rather than delaying it |
