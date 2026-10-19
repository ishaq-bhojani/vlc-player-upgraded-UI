# VLC Redesign — Design Spec

- **Date:** 2026-10-16
- **Status:** Approved 2026-10-16; revision 2 (§11) approved; **revision 3 (§12, additions from the Pylon harvest) approved in scope 2026-10-19**
- **Product name:** VLC Reborn
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
2. v1.0 (about month 19): the Figma window layout, Home, library, player, settings, effects, onboarding and dialogs, **plus the designer-intent features in §11** (watch sidebar, track popups, queue, subtitle tools) and the light/accessibility/performance pass.
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

Revision 2 adds the designer-intent scope from §11, which brings the full design to about **21 months**. Revision 3 (§12) adds about 2 months: yt-dlp playback and downloads in R3 (about +1 month) and the binge and music extras in R4 (about +1 month), so v1.0 lands around month 21 and v1.1 around month 23.

| When | Milestone | Deliverables | Ships |
|---|---|---|---|
| Month 1 | **M0 Setup** | Docker build, CI, design inputs (`tokens.md`, `settings-map.md`, `upstream-touchpoints.md`, `branding.md`) | — |
| Months 1–4 | **R1 Re-skin** | Palette, accent, Inter, icons, control-bar items, Customize Player, MiniPlayer, themed QWidgets, branding, signed installer, fork updater | **v0.1 beta** |
| Months 4–9 | **R2 Window & control bar** | Shell, Rail with pins, clickable show title + ☰ menu, LibraryPanel, Stage, hover bars, new control-bar layout (left play, thick seek bar, cone volume, subtitle/audio track popups, queue), Queue panel, Home + Recent, address bar + view modes + watched/unwatched sort, music view, cleaned right-click menu with Hide UI, shortcut feedback toast | **v0.2** |
| Months 9–13 | **R3 Settings & dialogs** | Settings model (basic + advanced on the same page, plain-word choice labels), effects, shortcuts, settings modal, onboarding with shortcuts intro, New playlist, Network stream, Add subtitles (saved per media), Keyboard shortcuts | **v0.3** |
| Months 13–17 | **R4 Watch sidebar** | Right sidebar (Subtitles / Audio / Video / Playback / Bookmarks tabs), per-show presets, sleep timer, Ctrl+B bookmarks, subtitle timeline, seek thumbnails, waveform | **v0.4** |
| Months 17–19 | **R5 Polish** | Light theme, accessibility, performance | **v1.0** |
| Months 19–21 | **R6 Extensions** | OpenSubtitles search, settings profiles, two-tone menu icon set | v1.1 |

## 10. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Name/logo or Figma export delayed | Blocks v0.1 | Both are Month 0 tasks; development continues on placeholders, but no public release until branding is done |
| Upstream VLC 4 is unreleased and moves fast | Merge conflicts, regressions | Pinned upstream commit, monthly merges, touchpoint list, `qt-redesign=false` fallback |
| Figma file is a community file; asset export and Inspect require a signed-in account; licence terms unknown | Missing exact values or licence problem | The owner duplicates the file into their own Figma account in Month 0 and checks the community licence/attribution terms |
| Side-by-side video unavailable on some machines | Degraded layout | Overlay fallback defined in §4 and covered by tests |
| Waveform requires audio analysis that VLC lacks | R4 slip | Isolated in R4; the music view works without it |
| Part-time capacity varies | Dates slip | Each release is independently shippable; scope is cut from the end of a release rather than delaying it |
| OpenSubtitles needs an API key and has terms of use | R6 feature blocked | Feature stays hidden until the user enters their own API key; the owner reviews the ToS before release |
| Subtitle timeline: VLC exposes no cue timing | Timeline limited | Supported only for external text subtitles (SRT, VTT, ASS) that we parse; embedded tracks show a notice |

## 11. Designer intent (revision 2)

Source: the designer's walkthrough of the Figma file (shared 2026-10-16). It explains *why* the screens look as they do. **Principle: keep VLC's identity (orange cone, grey/black neutrals, rectangular but slightly rounded), and put each feature where people look for it, so they never have to leave the video.** This section overrides §4–§6 where they conflict.

### 11.1 Control bar and window chrome (R2)
- **One thin row** over the bottom of the video, left to right:
  - ⏮ ▶ ⏭ — play is slightly larger than the others and **not centred**;
  - elapsed time;
  - a **thick seek bar** filling the middle;
  - total time;
  - a **cone-shaped volume slider** (triangle filling with the accent colour);
  - Subtitles, Audio, Settings (opens the watch sidebar, §11.3) and Queue buttons.
- **Track popups:**
  - **Subtitles:** subtitle tracks + "Add subtitles…".
  - **Audio:** audio tracks **and the audio output device list** (`AudioDeviceModel`).
  - **Video:** a third tab inside the same popup, with no separate button.
  - They reuse the upstream `TracksPage*` logic, restyled.
- **Resume prompt** ("Continue from 12:34?") appears just above the play controls, not in a far corner.
- **Title bar:**
  - the ☰ menu button, the current **show/folder name** (clickable: opens the LibraryPanel on that folder), a library sidebar toggle, then fullscreen and the window buttons;
  - the classic menu bar is removed. Its unique items move into the ☰ menu: Open file, Open folder, Network stream, Capture device, Open from clipboard, Recent media, Convert, Stream, Keyboard shortcuts, Settings, Help.
- **Immersive / fullscreen:** the top bar (with the title) and the bottom bar each appear only while the pointer is within 80 px of that edge (or on keyboard activity), and hide immediately when it leaves.
- **Right-click menu:** the upstream popup menu, restyled (R1 palette), with duplicates removed and a new **Hide UI** item (also on a shortcut). Hide UI hides both bars until toggled off or Esc.
- **Shortcut feedback:** when a hotkey fires, a toast shows the key combination together with the action name (e.g. "Ctrl+→ — Jump forward 1 min").

### 11.2 Queue and library (R2)
- The **Queue** (the play queue: plays automatically) is separate from **Playlists** (saved collections). The Queue button toggles a right-hand Queue panel (reusing upstream `PlaylistPane`). Items can be dragged from the library into it.
- **Library header:**
  - back/forward and a **clickable address bar** (each segment navigates up);
  - a view-mode button cycling **Grid → List → Details**;
  - a sort menu including **Unwatched first / Watched first** (ML `PLAYCOUNT` ascending/descending);
  - search;
  - an overflow menu (Add file, Add folder).
- **Rail additions:** **pinned items** (playlists, folders, streams pinned by the user from context menus) and **Recent**.
- **Network streams** page lists saved streams with an Add button. Pasting an `.m3u` URL opens it as a playlist (VLC already does this).

### 11.3 Watch sidebar (R4)
A right-hand sidebar (shares the right edge with the Queue panel; one is open at a time) with tabs:
- **Subtitles:**
  - subtitle delay, secondary delay and FPS as sliders with numeric fields;
  - font (`freetype-font`);
  - size as **Relative** (Smaller 50 / Small 75 / Normal 100 / Large 150 / Larger 200 % of `sub-text-scale`) or **Precise** (10–500 %);
  - outline thickness (`freetype-outline-thickness`);
  - position (`sub-margin`);
  - default subtitle language (`sub-language`).
- **Audio:**
  - audio delay;
  - default audio language (`audio-language`);
  - output device;
  - equalizer with friendly presets (icon per preset), compressor, spatializer, stereo widener (`EffectsController`).
- **Video:**
  - filter presets with preview thumbnails;
  - flip/rotate (`transform`);
  - zoom;
  - aspect ratio and crop;
  - colour adjust (brightness/contrast/saturation/hue/gamma);
  - HDR tone-mapping option where the Windows video output exposes one.
- **Playback:**
  - speed;
  - reverse;
  - **sleep timer** (off / 15 / 30 / 60 / 90 min / end of current item);
  - toggles: show subtitle timeline, show waveform on seek bar, show metadata overlay.
- **Bookmarks & chapters:** the bookmark list for the current media (ML bookmarks) and the chapter list. **Ctrl+B** adds a bookmark at the current time without opening any dialog.
- **Per-show presets:** the Subtitles and Audio tab settings (delays, size, font, outline, position, default tracks) can be saved as a named preset. A preset can be bound to a folder, and it is applied automatically when a file from that folder starts. Stored in `<user data>/vlc-reborn/presets.json`.
- **Subtitle timeline:** a strip above the control bar showing upcoming and past cues for an **external** text subtitle (SRT, VTT, ASS parsed by us). Dragging the strip shifts the subtitle delay.
- **Seek thumbnails:** hovering the seek bar shows a frame preview at that time (preparser thumbnail at a timestamp, cached).

### 11.4 Settings, subtitles, onboarding (R3)
- Each settings page shows the curated rows first, then an **Advanced** section listing every remaining option of the matching VLC subcategories on the same page, so the separate "All settings" tree is not needed for normal use. The "Advanced…" link to the QWidgets tree stays for plugin-level options.
- Choice settings show **plain-word labels**. Integer settings that are really enumerations get label overrides, e.g. `sub-autodetect-fuzzy`: 0 "Don't auto-detect", 1 "Any subtitle file", 2 "Subtitles containing the video name", 3 "Video name plus extra characters", 4 "Exact video name".
- **Add subtitles** (file / folder / playlist) **saves the association** in the media library (`vlc_ml_media_add_external_mrl`), so future playback of that episode loads it automatically.
- **Onboarding** adds a **Shortcuts** step introducing the essential hotkeys (play/pause, seek, volume, fullscreen, subtitles, Hide UI, bookmark).
- **Keyboard shortcuts** dialog is reachable directly from the ☰ menu.

### 11.5 Extensions (R6)
- **OpenSubtitles:** "Search online" in Add subtitles (search by file hash and name). It needs the user's own API key, entered in Settings → Subtitles; without a key the option is hidden.
- **Settings profiles:** named profiles bundling settings and the control-bar layout. Switching profiles requires a restart.
- **Two-tone icon set:** grey + accent two-tone icons for non-clickable menu icons (via `ColorizedSvgIcon` colour keys); the monochrome icon font stays everywhere else. Needs the designer's SVGs.

### 11.6 Not adopted
- A centred play button: the designer explicitly rejects it.
- Full user customisation beyond the existing Customize Player editor and profiles.

## 12. Additions from the Pylon harvest (revision 3)

Source: `docs/redesign/pylon-evaluation.md` and `docs/redesign/pylon-harvest.md`. Scope approved by the owner on 2026-10-19. Logic ported from Pylon (GPL-3.0) is marked in each file's header as "GPL-3.0-or-later; derived from Pylon (github.com/MeowKusTrue/Pylon)"; the distributed fork is therefore effectively GPL-3.0 (permitted: VLC's Qt interface is GPL-2.0-or-later). Pylon defects listed in the harvest are not copied.

### 12.1 Website playback and downloads with yt-dlp (R3)
- **Opt-in.** The first time a website link is opened or Download is pressed, a consent dialog explains: VLC Reborn will download yt-dlp (and ffmpeg for downloads) from their official GitHub releases into `<user data>/vlc-reborn/tools/` (sizes shown); the user is responsible for respecting each site's terms and copyright. Declining keeps the feature off; Settings → Network can enable it later.
- **Pinned and verified tools.** A manifest compiled into the app (`modules/gui/qt/redesign/tools/tools.json`) lists, per tool, the exact version, the release-tag asset URL (never a "latest" URL) and its SHA-256. A download is verified before first use; a mismatch deletes the file and reports an error. Tools never self-update (`yt-dlp -U` is not used); new versions arrive with app updates. Processes are started with an argument list (no shell) and `--ignore-config`.
- **Playback.** An `http(s)` link that is not a direct media/playlist file (by extension or content type) is resolved with yt-dlp (`-J`). Format sort `res,vcodec:avc1,acodec:m4a`, capped at the "Maximum web quality" setting (default 1080p). Separate audio is attached as an input slave. A playlist or channel link expands into the Queue (entries resolved when they start). Entry points: Open network stream dialog, dropping a link on the window, pasting with Ctrl+V.
- **Download.** A Download button (Open network stream dialog; context menu of a web item in the Queue) with quality choice Best / 1080p / 720p / Audio only (m4a). Saves to the "Download folder" setting (default `%USERPROFILE%\Videos\VLC Reborn`); ffmpeg merges streams. Progress, cancel, "Play" and "Show in folder" appear in a Downloads section of the Queue panel.
- **Not included:** browser-cookie import (off; may be offered later as an advanced setting with disclosure), song recognition (fpcalc/AcoustID).

### 12.2 Binge pack (R4)
- **Skip Intro.** When the current chapter's name is an intro token — exact, case-insensitive match for `op`, substring match for `intro`, `opening` — or the playback time is before a per-folder "intro ends at" mark (stored in the per-show preset store, §11.3), a "Skip Intro" button appears next to the play controls (same band as the resume prompt) and jumps to the chapter end / mark. "Auto-skip intros" setting, off by default.
- **Next Episode.** When a local file was opened on its own (Queue holds only it), during an end-credits chapter (exact `ed`, substring `credits`, `ending`) or the last 30 s, a "Next episode: <name>" card with a 10 s countdown appears; Cancel dismisses it for this file. Next = the following video file in the same folder by natural sort (numeric-aware, case-insensitive). Setting "Offer next episode", on by default.

### 12.3 Music extras (R4)
- **Sidecar lyrics.** For audio items without embedded synced lyrics, a `<same base name>.lrc` next to the file is parsed (multiple timestamps per line, `[offset:+/-ms]`, metadata tags ignored) and shown in the redesign music view's lyrics panel, highlighting the current line. Embedded lyrics (upstream `Player.syltLyrics`) take precedence. `.lrc` files are never loaded as subtitles.
- **Measured loudness.** The waveform pass (§11.3) also computes RMS loudness; the gain to reach −18 dBFS RMS, clamped to −12 … +4 dB, is cached with the waveform. With Settings → Audio → Replay gain = "Measured", items without replay-gain tags play with that gain (peak protection kept); tagged items keep their tags.
