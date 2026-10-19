# Settings map

Maps every Settings control to a VLC config key or an `EffectsController` method. Spec: sections 6 and 11.4.

**Keys verified against source twice.** The first pass (Task 3) found each key's `add_*` declaration in `src/`, `modules/` or `include/` (declaration file and line are in `notes`) and rejected obsolete (`add_obsolete_*`) options. Task 30 Step 0 repeated the check by script on 2026-10-19: every key in the third column was matched against all `add_*` declarations of the tree, none is obsolete, and none is missing, so no row moved to "Dropped (no backend)". 27 filter keys (`sharpen-sigma`, `gradfun-radius`, `grain-variance`, `croppadd-*`, `extract-component`, `colorthres-*`, `gradient-*`, `posterize-level`, `sepia-intensity`, `compressor-*`, `stereowiden-*`) are declared through a prefix macro or a name table, so they were checked by reading their declarations. The `qt.cpp:N` line numbers had drifted by 7 lines (the fork's `qt-redesign` option) and were corrected. `vlc.exe -H --advanced` was not run (no build is launched in this environment); `SettingsModel` (Task 30) reports an unknown key at run time with `msg_Err`, and its tests check a handful of keys against a real libvlc instance.

Provenance tags in `notes`:

- `Figma (<png>)`: the control is drawn in that PNG; the label is copied from the PNG.
- `PROVISIONAL (upstream prefs)`: the export shows only the General, Audio and Subtitles pages plus effect panels, so rows for the other pages are built from the upstream simple preferences (`modules/gui/qt/dialogs/preferences/sprefs_*.ui` and `simple_preferences.cpp`) and grouped by hand into the 13 pages. They are a starting set, not a Figma-confirmed list; the owner should review them when the missing Figma frames are available.

Column `notes`: the word `restart` marks keys that are read only at startup or at module creation (a restart banner is needed); `next playback` marks keys that apply to the next media. The restart classification is a judgement from where each option is read, not from a build; it was not confirmed against a build. `SettingsModel` (`modules/gui/qt/redesign/cpp/settingsmodel.cpp`) keeps its own list of the keys marked `restart`; change both together. Anything not marked applies immediately.

Types: `toggle` (bool), `choice`, `number`, `slider`, `path`, `text`, `color`, `font`, `hotkey`. `EffectsController` method names are proposed names for Task 31; the persisted keys are the config keys listed.

190 rows (176 bound to a verified config key). Pages follow the sidebar order: General, Interface, Privacy, Controls, Playback, Video, Audio, Subtitles, Library, Network, Performance, Recording, Extensions.

| page | label | VLC config key or EffectsController method | type | notes |
|---|---|---|---|---|
| General | Interface language | Windows registry value `HKCU\Software\VideoLAN\VLC\Lang` (not a config key) | choice {auto + language codes} | Figma (Settings - global.png). restart. Written by `SPrefsPanel::saveLang` (`simple_preferences.cpp`); language list at `simple_preferences.cpp:85-146`. "auto" deletes the value. Task 30 (SettingsModel) needs a special-case setter for this row, because `config_Put*` cannot reach the registry |
| General | Theme (Dark / Light / System) | `MainCtx::colorScheme` (QSettings `MainWindow/color-scheme-index`) | choice {Dark, Light, System} | Figma (Settings - global.png). not a config key. Index 0 = System, 1 = Day (Light), 2 = Night (Dark); Figma shows Dark, Light, System in that order. `maininterface/mainctx.cpp` lines 336 and 497; needs Qt >= 6.8 for `setColorScheme` |
| General | Accent color | `qt-accent-color` | choice {9 swatches} | Figma (Settings - global.png). restart. Stored as `#RRGGBB`, or `default`, or `system` (Qt >= 6.6). Swatch list: tokens.md Table C. Read once in `SystemPalette::componentComplete`; Task 5 may make it live. `modules/gui/qt/qt.cpp:487` |
| General | Show confirmation and error dialogs | `qt-error-dialogs` | toggle | Figma (Settings - global.png). `modules/gui/qt/qt.cpp:444` |
| General | Check for updates automatically | `qt-updates-notif` | toggle | Figma (Settings - global.png). only compiled with `UPDATE_CHECK`; the fork replaces the update source in Task 14. Interval key `qt-updates-days` (not in Figma). `modules/gui/qt/qt.cpp:406` |
| General | Save a log | `file-logging` | toggle | Figma (Settings - global.png). restart (the logger module is opened at startup). `modules/logger/file.c:239` |
| General | Log file | `logfile` | path (save file) | Figma (Settings - global.png). restart. `modules/logger/file.c:240` |
| General | Log details | `log-verbose` | choice {Default -1, Info, Error, Warning, Debug} | Figma (Settings - global.png). restart. Figma shows "Errors only" = Error (`VLC_MSG_ERR`). Choice list is `verbosity_values` in the file below. `modules/logger/file.c:243` |
| General | Advanced Options > | (link) | button | Figma (Settings - global.png). opens the Advanced section of this page; subcategories in the last table |
| Interface | Show system tray icon | `qt-system-tray` | toggle | PROVISIONAL (upstream prefs). restart. `modules/gui/qt/qt.cpp:368` |
| Interface | Close to system tray | `qt-close-to-system-tray` | toggle | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:479` |
| Interface | Show notifications | `qt-notification` | choice {never, minimized, always} | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:370` |
| Interface | Start minimized | `qt-start-minimized` | toggle | PROVISIONAL (upstream prefs). restart. `modules/gui/qt/qt.cpp:375` |
| Interface | Pause when minimized | `qt-pause-minimized` | toggle | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:377` |
| Interface | Resize window to video size | `qt-video-autoresize` | toggle | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:391` |
| Interface | Embed video in the main window | `embedded-video` | toggle | PROVISIONAL (upstream prefs). restart. `src/libvlc-module.c:1683` |
| Interface | Window decorations | `video-deco` | toggle | PROVISIONAL (upstream prefs). restart. The redesign shell draws its own title bar; confirm in R2 whether this row stays. `src/libvlc-module.c:1767` |
| Interface | Show controls in fullscreen | `qt-fs-controller` | toggle | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:395` |
| Interface | Fullscreen controls reveal distance | `qt-fs-sensitivity` | number (px) | PROVISIONAL (upstream prefs). spec 11.1 fixes 80 px; this key is the existing equivalent. `modules/gui/qt/qt.cpp:466` |
| Interface | Raise window on playback | `qt-auto-raise` | choice {never, video, audio, audio or video} | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:469` |
| Interface | Allow only one instance | `one-instance` | toggle | PROVISIONAL (upstream prefs). restart. Windows only (`_WIN32`). `src/libvlc-module.c:2166` |
| Interface | Enqueue items into the playlist in one-instance mode | `playlist-enqueue` | toggle | PROVISIONAL (upstream prefs). Windows only. `src/libvlc-module.c:2173` |
| Interface | One instance when started from file manager | `one-instance-when-started-from-file` | toggle | PROVISIONAL (upstream prefs). Windows only. `src/libvlc-module.c:2171` |
| Interface | Window opacity | `qt-opacity` | slider 0.1-1.0 | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:380` |
| Interface | Fullscreen controller opacity | `qt-fs-opacity` | slider 0.1-1.0 | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:382` |
| Interface | Interface scale | `qt-interface-scale` | slider 0.3-3.0 (-1 = automatic) | PROVISIONAL (upstream prefs). applied live through `MainCtx::setIntfUserScaleFactor` as well. `modules/gui/qt/qt.cpp:387` |
| Interface | Maximum volume | `qt-max-volume` | number % (60-300) | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:464` |
| Interface | Picture-in-picture mode | `qt-pip-mode` | toggle | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:483` |
| Interface | Show background cone | `qt-bgcone` | toggle | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:458` |
| Privacy | Allow metadata network access | `metadata-network-access` | toggle | PROVISIONAL (upstream prefs). same option as the first-run wizard. `src/libvlc-module.c:2196` |
| Privacy | Save recently played items | `save-recentplay` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1926` |
| Privacy | Forward cookies to the server | `http-forward-cookies` | toggle | PROVISIONAL (upstream prefs). `modules/access/http/access.c:298` |
| Privacy | Ask about privacy on first run | `qt-privacy-ask` | internal flag, not shown | PROVISIONAL (upstream prefs). Onboarding clears it (spec section 6). Declared at `modules/gui/qt/qt.cpp:449` |
| Controls | Mouse wheel (vertical) action | `hotkeys-y-wheel-mode` | choice | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2276` |
| Controls | Mouse wheel (horizontal) action | `hotkeys-x-wheel-mode` | choice | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2279` |
| Controls | Disable volume keys | `qt-disable-volume-keys` | toggle | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:418` |
| Controls | Volume step | `volume-step` | number | PROVISIONAL (upstream prefs). applies to keys and wheel. `src/libvlc-module.c:1617` |
| Controls | Extra-short jump size | `extrashort-jump-size` | number (s) | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2765` |
| Controls | Medium jump size | `medium-jump-size` | number (s) | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2769` |
| Controls | Long jump size | `long-jump-size` | number (s) | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2771` |
| Controls | Keyboard shortcuts | `key-play-pause` | hotkey list (ShortcutsModel) | PROVISIONAL (upstream prefs). every `add_key` option (115 declarations in the tree, mostly `SUBCAT_INTERFACE_HOTKEYS`) is edited through `ShortcutsModel`; `key-play-pause` is the verified example. Task 32 (ShortcutsModel) enumerates the rest from the config list at run time. `src/libvlc-module.c:2592` |
| Playback | Skip interval | `short-jump-size` | choice {10, 15} | MANDATORY ROW (brief). Figma "Forward 10s/15s" (spec 5). Value is seconds; upstream default 10; the UI restricts the integer to 10 or 15. Declared at `src/libvlc-module.c:2767` |
| Playback | Pause on last frame of the item | `play-and-pause` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2159` |
| Playback | Resume playback position | `restore-playback-pos` | choice {never, ask, always} | PROVISIONAL (upstream prefs). values `pi_restore_playback_values`. `src/libvlc-module.c:1928` |
| Playback | Restore playback state (tracks, speed) | `restore-playback-states` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1932` |
| Playback | Start paused | `start-paused` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2161` |
| Playback | Autostart playlist | `playlist-autostart` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2162` |
| Playback | Loop all | `loop` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2150` |
| Playback | Repeat current item | `repeat` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2153` |
| Playback | Random order | `random` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2147` |
| Playback | Exit after playback | `play-and-exit` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2156` |
| Playback | Default playback speed | `rate` | slider | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1914` |
| Playback | Fast seek | `input-fast-seek` | toggle | PROVISIONAL (upstream prefs). seek to nearest keyframe. `src/libvlc-module.c:1911` |
| Playback | Preferred video quality for adaptive streams | `preferred-resolution` | choice {Best available -1, Full HD 1080, HD 720, SD 576, Low 360, Very low 240} | PROVISIONAL (Pylon harvest A, `docs/redesign/pylon-harvest.md`; not in Figma). next playback. The key declares an integer list (`pi_prefres`), so `SettingsModel` already returns the labels. `src/libvlc-module.c:1889` |
| Video | Enable video | `video` | toggle | PROVISIONAL (upstream prefs). restart. `src/libvlc-module.c:1673` |
| Video | Start in fullscreen | `fullscreen` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1677` |
| Video | Always on top | `video-on-top` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1698` |
| Video | Video output module | `vout` | choice (module list) | PROVISIONAL (upstream prefs). restart. `src/libvlc-module.c:1788` |
| Video | Hardware decoding | `dec-dev` | choice (module list) | PROVISIONAL (upstream prefs). next playback. `src/libvlc-module.c:2056` |
| Video | Deinterlacing | `deinterlace` | choice {off, automatic, on} | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1775` |
| Video | Deinterlace mode | `deinterlace-mode` | choice | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1779` |
| Video | Default aspect ratio | `aspect-ratio` | text | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1753` |
| Video | Scale video to the window | `autoscale` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1756` |
| Video | Fullscreen display number | `qt-fullscreen-screennumber` | choice (screens) | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:452` |
| Video | Show media title on video start | `video-title-show` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1705` |
| Video | Title position | `video-title-position` | choice | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1715` |
| Video | Title display time (ms) | `video-title-timeout` | number | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1712` |
| Video | On-screen display | `osd` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1808` |
| Video | Hide mouse cursor after (ms) | `mouse-hide-timeout` | number | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1720` |
| Video | Snapshot folder | `snapshot-path` | path (folder) | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1723` |
| Video | Snapshot prefix | `snapshot-prefix` | text | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1724` |
| Video | Snapshot format | `snapshot-format` | choice | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1726` |
| Video | Sequential snapshot numbers | `snapshot-sequential` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1731` |
| Video | Upscaling mode (Direct3D11) | `d3d11-upscale-mode` | choice {linear, point, processor, super} | PROVISIONAL (Pylon harvest A, `docs/redesign/pylon-harvest.md`; not in Figma). next playback. Windows only, read when the Direct3D11 display is opened (module `direct3d11`). String list `ppsz_upscale_mode` gives the labels (Linear Sampler, Point Sampler, Video Processor, Super Resolution). `modules/video_output/win32/direct3d11.cpp:96` |
| Video | HDR output mode (Direct3D11) | `d3d11-hdr-mode` | choice {auto, never, always, generate} | PROVISIONAL (Pylon harvest A, `docs/redesign/pylon-harvest.md`; not in Figma). next playback. Windows only, read when the Direct3D11 display is opened. The upstream label "Never out HDR" is a typo of "Never output HDR": show it as "Never output HDR". `modules/video_output/win32/direct3d11.cpp:99` |
| Video | Effects: Hue | `hue` | slider -180..180 | Figma (Property 1=expanded*.png). EffectsController.setVideoAdjust("hue"). Filter `adjust` (`video-filter` list). `modules/video_filter/adjust.c:78` |
| Video | Effects: Brightness | `brightness` | slider 0..2 | Figma (Property 1=expanded*.png). EffectsController.setVideoAdjust("brightness"). `modules/video_filter/adjust.c:75` |
| Video | Effects: Contrast | `contrast` | slider 0..2 | Figma (Property 1=expanded*.png). EffectsController.setVideoAdjust("contrast"). `modules/video_filter/adjust.c:72` |
| Video | Effects: Saturation | `saturation` | slider 0..3 | Figma (Property 1=expanded*.png). EffectsController.setVideoAdjust("saturation"). `modules/video_filter/adjust.c:81` |
| Video | Effects: Gamma | `gamma` | slider 0.01..10 | Figma (Property 1=expanded*.png). EffectsController.setVideoAdjust("gamma"). `modules/video_filter/adjust.c:84` |
| Video | Effects: Sharpen Sigma | `sharpen-sigma` | slider 0..2 | Figma (Property 1=expanded*.png). filter `sharpen`. `modules/video_filter/sharpen.c:70` |
| Video | Effects: Banding Removal Radius | `gradfun-radius` | slider | Figma (Property 1=expanded*.png). filter `gradfun`. `modules/video_filter/gradfun.c:61` |
| Video | Effects: Film Grain Variance | `grain-variance` | slider | Figma (Property 1=expanded*.png). filter `grain`. `modules/video_filter/grain.c:67` |
| Video | Effects: Crop Top | `croppadd-croptop` | number px | Figma (Property 1=expanded*.png). EffectsController.setCrop; filter `croppadd`. Figma also has a link toggle between Top/Bottom and Left/Right (UI only). `modules/video_filter/croppadd.c:84` |
| Video | Effects: Crop Bottom | `croppadd-cropbottom` | number px | Figma (Property 1=expanded*.png). filter `croppadd`. `modules/video_filter/croppadd.c:86` |
| Video | Effects: Crop Left | `croppadd-cropleft` | number px | Figma (Property 1=expanded*.png). filter `croppadd`. `modules/video_filter/croppadd.c:88` |
| Video | Effects: Crop Right | `croppadd-cropright` | number px | Figma (Property 1=expanded*.png). filter `croppadd`. `modules/video_filter/croppadd.c:90` |
| Video | Effects: Color Extraction (colour) | `extract-component` | color (RGB integer) | Figma (Property 1=expanded*.png). toggle = `extract` in the `video-filter` list; colour = this key. `modules/video_filter/extract.c:72` |
| Video | Effects: Color Threshold (colour) | `colorthres-color` | color | Figma (Property 1=expanded*.png). toggle = `colorthres` in `video-filter`. `modules/video_filter/colorthres.c:73` |
| Video | Effects: Color Threshold: Saturation | `colorthres-saturationthres` | slider | Figma (Property 1=expanded*.png). `modules/video_filter/colorthres.c:75` |
| Video | Effects: Color Threshold: Similarity | `colorthres-similaritythres` | slider | Figma (Property 1=expanded*.png). `modules/video_filter/colorthres.c:77` |
| Video | Effects: Gradient mode | `gradient-mode` | choice | Figma (Property 1=expanded*.png). toggle = `gradient` in `video-filter`. `modules/video_filter/gradient.c:84` |
| Video | Effects: Color (gradient) | `gradient-color` | toggle | Figma (Property 1=expanded*.png). `modules/video_filter/gradient.c:89` |
| Video | Effects: Cartoon | `gradient-cartoon` | toggle | Figma (Property 1=expanded*.png). `modules/video_filter/gradient.c:91` |
| Video | Effects: Posterize level | `posterize-level` | slider 2..256 | Figma (Property 1=expanded*.png). toggle = `posterize` in `video-filter`. `modules/video_filter/posterize.c:71` |
| Video | Effects: Sepia Intensity | `sepia-intensity` | slider 0..255 | Figma (Property 1=expanded*.png). toggle = `sepia` in `video-filter`. `modules/video_filter/sepia.c:68` |
| Video | Effects: Negate Colors | `video-filter` list contains `invert` | toggle | Figma (Property 1=expanded*.png). module `invert` (`modules/video_filter/invert.c`, shortcut "invert"); no own key |
| Audio | Enable audio | `audio` | toggle | PROVISIONAL (upstream prefs). restart. `src/libvlc-module.c:1613` |
| Audio | Audio output module | `aout` | choice (module list) | PROVISIONAL (upstream prefs). restart. `src/libvlc-module.c:1651` |
| Audio | Output device | `mmdevice-audio-device` | choice | PROVISIONAL (upstream prefs). Windows MMDevice; live device list comes from `AudioDeviceModel`. `modules/audio_output/mmdevice.c:1584` |
| Audio | Passthrough (S/PDIF, HDMI) | `mmdevice-passthrough` | choice | PROVISIONAL (upstream prefs). `modules/audio_output/mmdevice.c:1580` |
| Audio | Preferred audio language | `audio-language` | text | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1867` |
| Audio | Remember volume | `volume-save` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1620` |
| Audio | Replay gain mode | `audio-replay-gain-mode` | choice | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1640` |
| Audio | Replay gain preamp (dB) | `audio-replay-gain-preamp` | number (float, dB, default 0) | PROVISIONAL (Pylon harvest A, `docs/redesign/pylon-harvest.md`; not in Figma). applied to the next track (read per input in `src/input/replay_gain.c:138`). `src/libvlc-module.c:1643` |
| Audio | Default replay gain (dB) | `audio-replay-gain-default` | number (float, dB, default -7) | PROVISIONAL (Pylon harvest A, `docs/redesign/pylon-harvest.md`; not in Figma). gain used for streams without replay gain information; applied to the next track. `src/libvlc-module.c:1645` |
| Audio | Time stretching | `audio-time-stretch` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1621` |
| Audio | Visualization | `audio-visual` | choice (module list) | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1662` |
| Audio | Audio desynchronization (ms) | `audio-desync` | number | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1635` |
| Audio | Stereo mode | `stereo-mode` | choice | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1631` |
| Audio | Dolby Surround | `force-dolby-surround` | choice | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1628` |
| Audio | Effects: Equalizer | `EffectsController.equalizerEnabled` (`audio-filter` list contains `equalizer`) | toggle | Figma (Settings - audio.png). filter list key `audio-filter` verified at `src/libvlc-module.c:1659` |
| Audio | Effects: Equalizer preset | `equalizer-preset` | choice (presets from `audio_filter/equalizer_presets.h`) | Figma (Settings - audio.png). EffectsController.setEqualizerPreset. `modules/audio_filter/equalizer.c:84` |
| Audio | Effects: Equalizer bands (60 Hz, 170 Hz, 310 Hz, 600 Hz, 1 KHz, 3 KHz, 6 KHz, 12 KHz, 14 KHz, 16 KHz) | `equalizer-bands` | ten sliders -20..20 dB | Figma (Settings - audio.png). EffectsController.setEqualizerBand(i, dB). Stored as one space-separated string. Figma labels match the upstream band list. `modules/audio_filter/equalizer.c:87` |
| Audio | Effects: Equalizer preamp | `equalizer-preamp` | slider dB | Figma (Settings - audio.png). EffectsController.setEqualizerPreamp. Figma shows "Preamp 12.0 dB". `modules/audio_filter/equalizer.c:93` |
| Audio | Effects: Two-pass | `equalizer-2pass` | toggle | Figma (Settings - audio.png). `modules/audio_filter/equalizer.c:89` |
| Audio | Effects: Equalizer expand/collapse ("Close Equalizer") | (UI only) | disclosure | Figma (Settings - audio.png). no backend, state is not persisted |
| Audio | Effects: Compressor toggle | `EffectsController.compressorEnabled` (`audio-filter` contains `compressor`) | toggle | Figma (Property 1=expanded*.png). module `compressor` (`modules/audio_filter/compressor.c`) |
| Audio | Effects: Compressor: RMS / Peak (Figma label reads "FM5 / Peak") | `compressor-rms-peak` | slider 0..1, default 0.2 | Figma (Property 1=expanded*.png). Defaults match Figma (0.2, 25.0 ms, 100.0 ms, -11.0 dB, 4.0:1, 5.0 dB, 7.0 dB). `modules/audio_filter/compressor.c:55` |
| Audio | Effects: Compressor: Attack | `compressor-attack` | slider 1.5..400 ms, default 25 | Figma (Property 1=expanded*.png). Defaults match Figma (0.2, 25.0 ms, 100.0 ms, -11.0 dB, 4.0:1, 5.0 dB, 7.0 dB). `modules/audio_filter/compressor.c:56` |
| Audio | Effects: Compressor: Release | `compressor-release` | slider 2..800 ms, default 100 | Figma (Property 1=expanded*.png). Defaults match Figma (0.2, 25.0 ms, 100.0 ms, -11.0 dB, 4.0:1, 5.0 dB, 7.0 dB). `modules/audio_filter/compressor.c:57` |
| Audio | Effects: Compressor: Threshold | `compressor-threshold` | slider -30..0 dB, default -11 | Figma (Property 1=expanded*.png). Defaults match Figma (0.2, 25.0 ms, 100.0 ms, -11.0 dB, 4.0:1, 5.0 dB, 7.0 dB). `modules/audio_filter/compressor.c:58` |
| Audio | Effects: Compressor: Ratio | `compressor-ratio` | slider 1..20, default 4 | Figma (Property 1=expanded*.png). Defaults match Figma (0.2, 25.0 ms, 100.0 ms, -11.0 dB, 4.0:1, 5.0 dB, 7.0 dB). `modules/audio_filter/compressor.c:59` |
| Audio | Effects: Compressor: Knee Radius | `compressor-knee` | slider 1..10 dB, default 5 | Figma (Property 1=expanded*.png). Defaults match Figma (0.2, 25.0 ms, 100.0 ms, -11.0 dB, 4.0:1, 5.0 dB, 7.0 dB). `modules/audio_filter/compressor.c:60` |
| Audio | Effects: Compressor: Makeup Gain | `compressor-makeup-gain` | slider 0..24 dB, default 7 | Figma (Property 1=expanded*.png). Defaults match Figma (0.2, 25.0 ms, 100.0 ms, -11.0 dB, 4.0:1, 5.0 dB, 7.0 dB). `modules/audio_filter/compressor.c:61` |
| Audio | Effects: Spatial audio | `EffectsController.spatializerEnabled` (`audio-filter` contains `spatializer`) | toggle | Figma (Settings - audio.png). PROVISIONAL: the Figma toggle name is "Spatial audio"; backend assumed to be the `spatializer` module |
| Audio | Effects: Spatial audio mode | `EffectsController.spatialMode` | choice {Headphone virtualization} | Figma (Settings - audio.png). PROVISIONAL: only one option is visible in the export. Candidate backend: module `headphone` (`modules/audio_filter/channel_mixer/headphone.c`, keys `headphone-dim`, `headphone-compensate`). Owner to confirm the list |
| Audio | Effects: Spatializer: Size | `spatializer-roomsize` | slider 0..1.1 (Figma shows 0..10) | Figma (Property 1=expanded*.png). scale the key range to the Figma display range in the control. `modules/audio_filter/spatializer/spatializer.cpp:79` |
| Audio | Effects: Spatializer: Width | `spatializer-width` | slider 0..1 (Figma 0..10) | Figma (Property 1=expanded*.png). scale the key range to the Figma display range in the control. `modules/audio_filter/spatializer/spatializer.cpp:81` |
| Audio | Effects: Spatializer: Wet | `spatializer-wet` | slider 0..1 (Figma 0..10) | Figma (Property 1=expanded*.png). scale the key range to the Figma display range in the control. `modules/audio_filter/spatializer/spatializer.cpp:83` |
| Audio | Effects: Spatializer: Dry | `spatializer-dry` | slider 0..1 (Figma 0..10) | Figma (Property 1=expanded*.png). scale the key range to the Figma display range in the control. `modules/audio_filter/spatializer/spatializer.cpp:85` |
| Audio | Effects: Spatializer: Damp | `spatializer-damp` | slider 0..1 (Figma 0..10) | Figma (Property 1=expanded*.png). scale the key range to the Figma display range in the control. `modules/audio_filter/spatializer/spatializer.cpp:87` |
| Audio | Effects: Stereo widening toggle | `EffectsController.stereoWideningEnabled` (`audio-filter` contains `stereo_widen`) | toggle | Figma (Settings - audio.png). module `stereo_widen` (`modules/audio_filter/stereo_widen.c`) |
| Audio | Effects: Stereo widening: Delay Time | `stereowiden-delay` | slider 1..100 ms, default 20 | Figma (Property 1=expanded*.png). Figma shows 20.0 ms. `modules/audio_filter/stereo_widen.c:84` |
| Audio | Effects: Stereo widening: Feedback Gain | `stereowiden-feedback` | slider 0..0.9, default 0.3 | Figma (Property 1=expanded*.png). Figma shows "0.2 %" (display unit differs). `modules/audio_filter/stereo_widen.c:86` |
| Audio | Effects: Stereo widening: Crossfeed | `stereowiden-crossfeed` | slider 0..0.8, default 0.3 | Figma (Property 1=expanded*.png). Figma shows "0.3 %". `modules/audio_filter/stereo_widen.c:88` |
| Audio | Effects: Stereo widening: Dry Mix | `stereowiden-dry-mix` | slider 0..1, default 0.8 | Figma (Property 1=expanded*.png). Figma shows "0.8 %". `modules/audio_filter/stereo_widen.c:90` |
| Subtitles | Subtitle Track | `sub-track` | number | Figma (Subtitles.png). Figma shows "1". `src/libvlc-module.c:1864` |
| Subtitles | Subtitle Language | `sub-language` | text (language code) | Figma (Subtitles.png). `src/libvlc-module.c:1870` |
| Subtitles | Subtitle Track Delay | `sub-delay` | slider -10 s..+10 s with numeric field | Figma (Subtitles.png). unit is 1/10 s: Figma "-4.000 s" = -40. The live per-playback delay is a player property; this key is the default. `src/libvlc-module.c:1814` |
| Subtitles | Subtitle Speed (fps) | `sub-fps` | slider + numeric field | Figma (Subtitles.png). Figma shows "1.000 fps"; upstream default 0.0 means "use the media frame rate". `src/libvlc-module.c:1813` |
| Subtitles | Embedded Sub Format | `subsdec-formatted` | toggle | Figma (Subtitles.png). PROVISIONAL mapping: nearest key is "Formatted Subtitles" (subtitle text formatting on/off); Figma label differs. Owner to confirm. `modules/codec/subsusf.c:54` |
| Subtitles | Subtitle Font | `freetype-font` | font | Figma (Subtitles.png). `modules/text_renderer/freetype/freetype.c:141` |
| Subtitles | Text Color | `freetype-color` | color (#RRGGBB) | Figma (Subtitles.png). Figma sample "#B8B8B8". `modules/text_renderer/freetype/freetype.c:156` |
| Subtitles | Outline Color | `freetype-outline-color` | color (#RRGGBB) | Figma (Subtitles.png). Figma sample "#0C0C0C". `modules/text_renderer/freetype/freetype.c:173` |
| Subtitles | Open Advanced Settings | (link) | button | Figma (Subtitles.png). opens the Advanced section of this page |
| Subtitles | Enable subtitles | `spu` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1804` |
| Subtitles | Subtitle text encoding | `subsdec-encoding` | choice | PROVISIONAL (upstream prefs). `modules/codec/subsdec.c:189` |
| Subtitles | Text size (%) | `sub-text-scale` | slider 10-500 | PROVISIONAL (upstream prefs). spec 11.3 Relative/Precise size. `freetype-rel-fontsize` is obsolete, do not use. `src/libvlc-module.c:1830` |
| Subtitles | Outline thickness | `freetype-outline-thickness` | choice | PROVISIONAL (upstream prefs). `modules/text_renderer/freetype/freetype.c:176` |
| Subtitles | Bold text | `freetype-bold` | toggle | PROVISIONAL (upstream prefs). `modules/text_renderer/freetype/freetype.c:160` |
| Subtitles | Text opacity | `freetype-opacity` | slider 0-255 | PROVISIONAL (upstream prefs). `modules/text_renderer/freetype/freetype.c:151` |
| Subtitles | Shadow opacity | `freetype-shadow-opacity` | slider 0-255 | PROVISIONAL (upstream prefs). upstream wizard toggles 0/128. `modules/text_renderer/freetype/freetype.c:181` |
| Subtitles | Background opacity | `freetype-background-opacity` | slider 0-255 | PROVISIONAL (upstream prefs). upstream wizard toggles 0/128. `modules/text_renderer/freetype/freetype.c:163` |
| Subtitles | Subtitle position (margin) | `sub-margin` | number px | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1828` |
| Subtitles | Secondary subtitle alignment | `secondary-sub-alignment` | choice | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1839` |
| Subtitles | Secondary subtitle margin | `secondary-sub-margin` | number px | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1844` |
| Subtitles | Auto-detect subtitle files | `sub-autodetect-file` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1817` |
| Subtitles | Subtitle file matching | `sub-autodetect-fuzzy` | choice {0..4} | PROVISIONAL (upstream prefs). integer enumeration; label overrides in spec 11.4 (0 "Don't auto-detect" ... 4 "Exact video name"). `src/libvlc-module.c:1819` |
| Subtitles | Subtitle search folders | `sub-autodetect-path` | text (comma list) | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1826` |
| Library | Enable media library | `media-library` | toggle | PROVISIONAL (upstream prefs). restart. `src/libvlc-module.c:2179` |
| Library | Scan new media automatically (preparse) | `auto-preparse` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2184` |
| Library | Library folders | `MLFoldersModel` (existing media library folders model) | folder list | PROVISIONAL (upstream prefs). Not a config key; spec section 6 reuses the existing model |
| Network | HTTP proxy | `http-proxy` | text | PROVISIONAL (upstream prefs). declared under `#ifdef _WIN32` (obsolete on other platforms), so valid for this fork. `src/libvlc-module.c:1961` |
| Network | User agent | `http-user-agent` | text | PROVISIONAL (upstream prefs). `modules/access/http/access.c:304` |
| Network | Referrer | `http-referrer` | text | PROVISIONAL (upstream prefs). `modules/access/http/access.c:300` |
| Network | Reconnect dropped HTTP streams | `http-reconnect` | toggle | PROVISIONAL (upstream prefs). `modules/access/http.c:72` |
| Network | Connection timeout (ms) | `ipv4-timeout` | number | PROVISIONAL (upstream prefs). `src/libvlc-module.c:1943` |
| Network | RTSP over TCP | `rtsp-tcp` | toggle | PROVISIONAL (upstream prefs). live555 module. `modules/access/live555.cpp:112` |
| Network | Network discovery services | `services-discovery` | text (module list) | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2211` |
| Network | Download website playback tools (yt-dlp, ffmpeg) | `ToolManager.consentGiven` (QSettings group `redesign`, key `toolsConsent`; not a config key) | toggle | Task 52, spec 12.1. Default off. Turning it on is the consent of the first-use dialog (`redesign/dialogs/ToolConsentDialog.qml`): the tools are then downloaded from their GitHub releases and verified against `redesign/tools/tools.json`. The key is stored by `ToolManager` (`redesign/cpp/toolmanager.cpp`) in the same store as the QML `Settings { category: "redesign" }` of the rail and the pins (`vlc-qt-interface.conf` is separate: this is the default `QSettings()` of the application, organisation `redesign::productName()`). `qt.cpp` has no new key. |
| Performance | File caching (ms) | `file-caching` | number | PROVISIONAL (upstream prefs). next playback. `src/libvlc-module.c:1998` |
| Performance | Network caching (ms) | `network-caching` | number | PROVISIONAL (upstream prefs). next playback. `src/libvlc-module.c:2010` |
| Performance | Disc caching (ms) | `disc-caching` | number | PROVISIONAL (upstream prefs). next playback. `src/libvlc-module.c:2006` |
| Performance | Live capture caching (ms) | `live-caching` | number | PROVISIONAL (upstream prefs). next playback. `src/libvlc-module.c:2002` |
| Performance | Decoder threads | `avcodec-threads` | number | PROVISIONAL (upstream prefs). next playback. `modules/codec/avcodec/avcodec.c:128` |
| Performance | Skip loop filter | `avcodec-skiploopfilter` | choice | PROVISIONAL (upstream prefs). next playback. `modules/codec/avcodec/avcodec.c:120` |
| Performance | Direct rendering | `avcodec-dr` | toggle | PROVISIONAL (upstream prefs). next playback. `modules/codec/avcodec/avcodec.c:107` |
| Performance | Preload MKV files in the same folder | `mkv-preload-local-dir` | toggle | PROVISIONAL (upstream prefs). `modules/demux/mkv/mkv.cpp:69` |
| Performance | Repair AVI files | `avi-index` | choice | PROVISIONAL (upstream prefs). `modules/demux/avi/avi.c:85` |
| Performance | Smooth scrolling | `qt-smooth-scrolling` | toggle | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:473` |
| Performance | Backdrop blur | `qt-backdrop-blur` | toggle | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:481` |
| Performance | Qt compositor | `qt-compositor` | choice | PROVISIONAL (upstream prefs). restart. `modules/gui/qt/qt.cpp:398` |
| Recording | Recording folder | `input-record-path` | path (folder) | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2027` |
| Recording | Record in native format | `input-record-native` | toggle | PROVISIONAL (upstream prefs). `src/libvlc-module.c:2029` |
| Extensions | Autoload extensions | `qt-autoload-extensions` | toggle | PROVISIONAL (upstream prefs). `modules/gui/qt/qt.cpp:455` |
| Extensions | Lua interpreter | `lua` | toggle | PROVISIONAL (upstream prefs). restart. `modules/lua/vlc.c:658` |
| Extensions | Last.fm user name | `lastfm-username` | text | PROVISIONAL (upstream prefs). audioscrobbler module. `modules/misc/audioscrobbler.c:135` |
| Extensions | Last.fm password | `lastfm-password` | password | PROVISIONAL (upstream prefs). audioscrobbler module; stored in plain config by upstream, flag in review. `modules/misc/audioscrobbler.c:137` |
| Extensions | Installed extensions list | `ExtensionsManager` (existing) | list | PROVISIONAL (upstream prefs). Not a config key |

## Dropped (no backend)

Controls with no usable backend. They are not shown in the UI (spec: no fake switches).

| Control | Reason |
|---|---|
| Developer mode (General, Figma) | No VLC option matches. The nearest, `qt-verbose` (verbose Qt logging, `qt.cpp:477`), is not obviously the same. Owner to decide; dropped until then. |
| Subtitle Duration Factor (Subtitles, Figma) | No option exists (`sub-duration-factor` is not declared anywhere in `src/` or `modules/`). |
| Default Preset dropdown (Subtitles, Figma) | Per-show presets are a redesign feature (spec 11.3, stored in `presets.json`, Release 4), not a VLC option. Hidden until then. |
| Equalizer "Close Equalizer" (Audio, Figma) | UI-only disclosure; listed above as UI only, no persistence. |
| Link-pair buttons between Top/Bottom and Left/Right crop fields (Figma effect panel) | UI-only convenience, no option. |
| "Menu bar" row (`qt-menubar`) | The classic menu bar is removed in the redesign shell (spec 11.1); items move into the menu button. |
| "Show title bar" / "Pin controls" rows (`qt-titlebar`, `qt-pin-controls`) | The redesign shell fixes the title bar and control bar layout (spec section 4). |
| Skin selection (`skins2-last`, `intf` = skins2) | skins2 is a non-goal (spec section 1). |
| Options of audio output modules that do not exist on Windows (alsa, oss, jack, kai, auhal, pulse) | Not available on Windows. |

## Advanced section: VLC subcategories per page (spec 11.4)

After the curated rows each page lists every remaining option of these `SUBCAT_*` values (enum in `include/vlc_plugin.h:174-216`, mapping helpers in `include/vlc_config_cat.h`). `SUBCAT_HIDDEN` and `SUBCAT_UNKNOWN` are never shown. Each subcategory is assigned to exactly one page so an option cannot appear twice; the assignment is PROVISIONAL.

| page | subcategories | declared at |
|---|---|---|
| General | SUBCAT_INTERFACE_GENERAL | `src/libvlc-module.c:2239` |
| Interface | SUBCAT_INTERFACE_MAIN | `modules/gui/qt/qt.cpp:359` |
| Privacy | (none: no VLC subcategory is privacy specific; page has curated rows only) | n/a |
| Controls | SUBCAT_INTERFACE_CONTROL, SUBCAT_INTERFACE_HOTKEYS | `src/libvlc-module.c:2268, 2273` |
| Playback | SUBCAT_INPUT_GENERAL, SUBCAT_PLAYLIST_GENERAL | `src/libvlc-module.c:1848, 2145` |
| Video | SUBCAT_VIDEO_GENERAL, SUBCAT_VIDEO_VOUT, SUBCAT_VIDEO_VFILTER, SUBCAT_VIDEO_SPLITTER | `src/libvlc-module.c:1670, 1787, 1791` |
| Audio | SUBCAT_AUDIO_GENERAL, SUBCAT_AUDIO_AOUT, SUBCAT_AUDIO_AFILTER, SUBCAT_AUDIO_VISUAL, SUBCAT_AUDIO_RESAMPLER | `src/libvlc-module.c:1610-1665` |
| Subtitles | SUBCAT_VIDEO_SUBPIC, SUBCAT_INPUT_SCODEC | `src/libvlc-module.c:1800; modules/codec/subsdec.c` |
| Library | SUBCAT_PLAYLIST_SD | `src/libvlc-module.c:2210` |
| Network | SUBCAT_INPUT_ACCESS, SUBCAT_ADVANCED_NETWORK | `include/vlc_plugin.h:196, 212` |
| Performance | SUBCAT_INPUT_DEMUX, SUBCAT_INPUT_VCODEC, SUBCAT_INPUT_ACODEC, SUBCAT_INPUT_STREAM_FILTER, SUBCAT_ADVANCED_MISC | `src/libvlc-module.c:2045-2104` |
| Recording | SUBCAT_SOUT_GENERAL, SUBCAT_SOUT_STREAM, SUBCAT_SOUT_MUX, SUBCAT_SOUT_ACO, SUBCAT_SOUT_PACKETIZER, SUBCAT_SOUT_VOD, SUBCAT_SOUT_RENDERER, SUBCAT_PLAYLIST_EXPORT | `src/libvlc-module.c:2065-2099` |
| Extensions | (none of its own: Lua and extension options sit in SUBCAT_INTERFACE_MAIN (`modules/lua/vlc.c:656`), already listed under Interface; the page shows only the extensions manager) | n/a |
