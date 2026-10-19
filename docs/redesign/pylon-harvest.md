# Pylon harvest: what VLC Reborn can take from Pylon

Date: 2026-10-19. Companion to `docs/redesign/pylon-evaluation.md` (verdict: continue the fork, borrow ideas). This file lists the ideas and algorithms worth taking.

Method: read-only reading of the Pylon clone at commit `8e06dea`. Nothing was built, run or installed, and no network was used. Pylon paths are relative to the app project folder `Pylon/` (e.g. `Waveform.cs:44`), except `tests/Checks/...` and `relay/...`. Plan references are to `docs/superpowers/plans/2026-10-16-vlc-redesign.md` ("Task N"). Spec references are to `docs/superpowers/specs/2026-10-16-vlc-redesign-design.md`. VLC claims cite a path under `modules/` or `src/` that was grepped in this tree.

Licence note: Pylon is GPL-3.0-or-later. VLC core is GPL-2.0-or-later and libvlccore LGPL-2.1+. The fork's Qt module is `GPL-2.0-or-later`; copying Pylon code verbatim into it would need a GPL-3 compatibility decision, so the notes below describe algorithms to reimplement, not code to paste. Constants and regexes are facts of behaviour, not expression.

Counts: Section A has 19 entries. Section B has 11 candidates in group 1, 6 in group 2 and 9 in group 3. Section C has 33 rows.

---

## A. Logic to port into already-planned tasks

### A1. Task 46 "Waveform peaks provider" (and Task 47 bar)

Pylon: `Waveform.cs:27-38` (latest-request-wins gate), `:40-70` (cache + decode + reduce), `:72-90` (decode), `:93-119` (reduce), `:122-131` (WAV data-chunk finder); consumer `MainWindow.xaml.cs:3082-3096`.

What it does:
- A separate silent libVLC instance transcodes the track to mono 16-bit WAV with `:sout=#transcode{acodec=s16l,channels=1,samplerate=8000}:std{access=file,mux=wav,dst=...}` (`:74-79`). The rate drops to 2 kHz past one hour, which keeps a 10-hour book at about 144 MB of temp file (`:78`).
- It waits for end-of-stream with a timeout of `max(120 s, duration/40)` (`:87`), then stops the player off the event thread (`:88`).
- The WAV is streamed (not loaded) and split into 400 bins of equal sample count. Each bin is the RMS of its samples (`:93-114`). The result is normalised to the loudest bin and lifted with `^0.7` so quiet passages stay visible (`:118`). It also returns average loudness in dBFS (`:115`).
- The cache key is `SHA1(path | size | mtime)` (`:44`), and the cache also stores the loudness number (`:46-52`).

Why it is better than the plan:
- **RMS plus normalise plus gamma instead of raw `max|s|/32768`.** With about 1000 buckets over a 4-minute song (about 0.24 s per bucket) the peak of mastered music is near full scale in almost every bucket, so the drawn wave is a flat wall. Plan test `peakValue` pins raw peaks; keep `computePeaks` for that test, add `computeRms` for display, and store the RMS (raw, un-normalised) in the cache so display tuning can change without a rescan.
- **Cache key.** The plan keys by `sha1(url)` only, so a replaced or retagged file keeps a stale wave. Use `sha1(url | size | mtime)`.
- **Unfinished WAV header.** The sout WAV muxer's size fields are not reliable when the stream is cut; Pylon trusts the file length and finds the `data` chunk by walking chunks (`:99`, `:122-131`). The plan says only "reads the WAV PCM".
- **Latest-only worker** (`:22-38`) is stricter than "a new url cancels the running job".
- **Prefetch.** After the current track is done it scans the next queue item (`MainWindow.xaml.cs:3093-3095`). Cheap and makes track changes instant.

Porting notes (C++ / libvlccore):
- Run the decode as a libvlccore input with `:sout=...`, `:no-sout-video`, `:no-spu`, on a worker thread. Do not call stop from an input event callback (Pylon's comment at `:88` and `SeekPreviewer.cs:175-177` record the deadlock).
- Read duration from the ML media (`i_duration`) or the preparsed item, not by blocking on a parse (`:76` blocks a worker for up to 5 s).
- Stream the WAV with `QFile` and a 64 KiB buffer, and walk the RIFF chunks to the `data` chunk.
- Cache file format: add a magic and version byte (Pylon had to re-analyse old caches after adding loudness, `:46`). Store RMS bins and the loudness float.
- For Task 47 drawing see A2.

Defects not to copy:
- The decorative fake waveform shown before the real one arrives (`Controls.cs:97-104`). Plan's "standard seek bar while scanning" is more honest.
- The in-memory dictionaries are never evicted (`:17-18`).
- Only `IOException` is caught around the decode (`:68`).
- The loudness is RMS dBFS, not LUFS (`:115`). Do not label it LUFS.

### A2. Task 47 "Waveform seek bar" (drawing details)

Pylon: `Controls.cs:154-185` (`SeekBar.OnRender`), `:187-191` (bookmarks).

What it does: bars are 2 px wide on a 5 px pitch. The bar count follows the width, and each bar samples the peaks array by nearest index. Colours are played = dim accent, unplayed = faint foreground, and everything left of the pointer is tinted while hovering (`:181`). Chapter ticks are 1 px lines (`:184`). Bookmarks are small accent "drops" hanging from the top edge (`:190`). An A-B loop is a translucent band with two edge lines (`:160-166`).

Better than / adds to the plan: the plan specifies only played/unplayed colours. Add the hover tint (it previews where a click will land), chapter ticks, bookmark drops and the A-B band, so the music bar does not lose what the normal bar shows (Task 22 draws chapter ticks).

Porting notes: for decimation take the max (or mean) of the bins covered by each bar rather than Pylon's nearest-index pick (`:180`). One `Shape` with a single path (or a `Canvas`/scene-graph node) is far cheaper than 1000 `Rectangle` delegates.

### A3. Task 45 "Seek thumbnail preview"

Pylon: `SeekPreviewer.cs:148-256`, caller `MainWindow.xaml.cs:2445-2475`.

What it does: a second silent player decodes into a 256x144 buffer (`:150`). Requests are throttled to one per 120 ms (`:192`). Frames are cached in 0.5 % buckets, at most 200 (about 30 MB) (`:239`, `:179`). The player is paused after each frame lands (`:185-189`). Hovering shows the time and, if one exists, the chapter name (`MainWindow.xaml.cs:2459`). The card may overhang the bar by 150 px at either end and is clamped (`:2450`, `:2468-2474`).

What it confirms in the plan: the 120 ms debounce, latest-only, bucket cache and non-local media skipped are all there. Pylon's 0.5 % buckets (200) versus the plan's 1 % (100): keep 1 %.

What to add:
- **Hardware decode and fast seek.** Pylon found that heavy 1440p HEVC took the CPU about 0.3 s per frame and jumped to the nearest keyframe in a fraction of that (`SeekPreviewer.cs:200-203`, with `--input-fast-seek`, `--no-avcodec-hurry-up`, `--no-drop-late-frames`). The preparser exposes exactly these: set `vlc_thumbnailer_arg.seek.speed = VLC_THUMBNAILER_SEEK_FAST` and `hw_dec = true` (`include/vlc_preparser.h:193-225`). Add both to Task 45.
- **Chapter name in the bubble**, as above.
- **Edge clamp** of the bubble with an overhang, so it never leaves the window at the bar ends.
- **Fallback path.** If the one-shot preparser request is too slow (it must open the input each time), Pylon's warm-player design is the fallback: keep one player open, seek, run until a frame near the target time arrives (`:177`), then pause. The comment at `:172` explains why (the picture does not redraw after a paused seek).

Defects not to copy: the fixed 256x144 size (`:150`) distorts non-16:9 video. Leave `height` unset or derive it from the track's SAR (Pylon does this correctly elsewhere: `Frames.cs:32-34`). `vlc_thumbnailer_output` has `crop` and takes width and height (`include/vlc_preparser.h:246-270`).

### A4. Task 37 "Add subtitles dialog" (episode matching, and a plan gap)

Pylon: `DialogWindow.xaml.cs:450-531` (dialog), `:468-480` (mapping), `:513-520` (tag extraction). Persistence and re-attach: `MainWindow.xaml.cs:3517-3521`, `:3505`, and on every play `:904-905`.

What it does: for "To this folder" each subtitle is paired with the video that has the same episode tag, else with the video whose base name is a prefix of the subtitle's name. A tag is `S01E02` or `1x02` (season and episode as integers, so `S1E2` equals `S01E02`) or, failing that, the trailing number (`:513-520`, `:475-477`). The dialog shows the resulting mapping live as `video <- subtitle`, with unmatched videos shown as a dash (`:484-495`).

Why it is better than the plan: `SubtitleMatch.pair` is exact base-name equality (after removing `.lang`). That fails for the usual case, a season folder where videos are `Show.S01E02.1080p.WEB.mkv` and subtitles are `Show - 1x02.srt` or `S01E02.en.srt`. Keep the plan's exact match as stage 1, add Pylon's tag as stage 2 and prefix as stage 3.

**Plan gap found while verifying (important).** The plan's Step 4 expects that after `vlc_ml_media_add_external_mrl` "the subtitle loads automatically" on replay. In this tree nothing consumes those entries at playback: `MediaToInputItem` builds the input item from the main file only (`modules/misc/medialibrary/entities.cpp:545-575`), and `VLC_ML_FILE_TYPE_SUBTITLE` appears only where files are stored (`medialibrary.cpp:1936`, `entities.cpp:295`). No `input_item_AddSlave` call exists in the medialibrary module or the Qt module. Pylon avoids this by re-attaching its own saved list on every play (`MainWindow.xaml.cs:904-905`). Add a step to Task 37 (or a small task before it): at play start, read the media's `VLC_ML_FILE_TYPE_SUBTITLE` files and add them with `input_item_AddSlave(... SLAVE_TYPE_SPU, SLAVE_PRIORITY_USER)`, either in `MediaToInputItem` (a small edit to an upstream file, log it in `upstream-touchpoints.md`) or in the redesign shell on `Player.inputChanged`.

Defects not to copy (all verified by reading the regexes):
- `(\d{1,2})x(\d{2,3})` has no word boundary, so `1920x1080` gives tag `20-108` (`:516`). Use `\b` or a lookaround.
- The trailing-number fallback `(\d+)\D*$` (`:518`) takes the last digit group followed only by non-digits. `Show - 02 [1080p].mkv` yields `1080`, and so does every sibling, so all subtitles bind to the first video. Strip bracketed groups and resolution/codec tokens first (Pylon already has such a cleaner for its search: `Subtitles.cs:65-74`), and require a 1-3 digit episode number.
- `int.Parse` on a long digit group can overflow (`:517`, `:519`).
- First match wins when two videos share a tag (nested season folders); show the ambiguity instead.
- Multi-episode names (`S01E01E02`, `S01E01-E02`) match only the first episode.
- The "From OpenSubtitles" drop-down is a stub that snaps back (`:457`). Do not ship a dead choice. Task 49 adds the source properly in R6.

### A5. Task 23 "Subtitle and audio track popups" (friendly audio labels)

Pylon: `MainWindow.xaml.cs:3427-3452` (`AudioTrackName`), menu `:3454-3468`.

What it does: libVLC only numbers recordings with several unnamed tracks ("Track 2", "Track 2 - [English]"). When the name is generic (regex `^\S+ \d+( - \[[^\]]*\])?$`, `:3427`), Pylon builds `Track N · AAC · stereo · 48 kHz · English · <description>` from the track's codec, channel count (1 mono, 2 stereo, 6 "5.1", 8 "7.1"), rate and language. It maps fourccs to friendly codec names (`mp4a`->AAC, `a52`->AC-3, `eac3`->E-AC-3, `dts`, `mlp/trhd`->TrueHD, `mpga/mp3`->MP3, `flac`, `opus`, `vorb`->Vorbis, raw PCM ids->PCM). A real file-provided name is kept unchanged.

Why it matters here: VLC 4 generates exactly those generic names (`src/input/es_out.c:753-779`: description, or "Track N", optionally " - [lang]"), and `TrackListModel` exposes only the display name (`modules/gui/qt/player/input_models.hpp:38-40`). The plan's popup would show "Track 1 / Track 2" for OBS and ShadowPlay recordings.

Porting notes:
- Build the label in a small redesign helper from `vlc_player_track.fmt` (`include/vlc_player.h:1396-1406`): `fmt.i_codec`, `fmt.audio.i_channels` / `i_physical_channels`, `fmt.audio.i_rate`, `fmt.psz_language`, `fmt.psz_description`. Use `vlc_fourcc_GetDescription` (`include/vlc_fourcc.h:790`) as the fallback codec name.
- Detect "generic" by `fmt.psz_description == NULL`, not by regex. Pylon's regex only works for the English word "Track"; VLC's string is translated (`_("Track")`, `es_out.c:771`).
- Expose it as a new model role (a small proxy in `redesign/cpp`), so `TrackList.qml` binds a `friendlyName` role without editing `input_models.cpp`.
- Subtitle tracks: Pylon shows the raw names (`:3470-3481`); apply the same idea (language plus "forced"/"SDH"/codec for bitmap tracks) only if time allows.

Confirms: "Add subtitles..." entry beside the tracks and output devices under the audio list (`:3460-3466`) match the plan's popup layout. Pylon's popup is a context menu that closes on choice; the plan's keep-open popup is better.

### A6. Task 31 "EffectsController" (live apply rules, tests, presets)

Pylon: `AudioChain.cs:9-14`, `:123-209`; `Effects.cs:14-60`; `EffectsPanel.cs:138-170`; `Settings.cs:141-150`, `:166-187`; tests `tests/Checks/Program.cs:126-224`.

Findings that confirm or sharpen the plan:
- **Rebuild only when the filter set changes.** Pylon keys the built chain by "equalizer + filter names + non-live parameters" and rebuilds only when that key changes (`AudioChain.cs:133-140`, `:193-195`). Equalizer bands, compressor and spatializer parameters follow their variables while running (`:142-149`). A slider drag must never cause a rebuild (it stuttered picture and sound before, per the comment). In VLC 4 use `aout_EnableFilter` (`include/vlc_aout.h:547`) only to add or remove a filter, and `var_Set*` on the running aout for parameters, as `extended_panels.cpp` does. Add this as an explicit rule and test to Task 31: changing a band value must not call `aout_EnableFilter`.
- **Filter order.** Pylon builds `normvol, compressor, spatializer|headphone, scaletempo_pitch, chorus_flanger, karaoke` with the equalizer first (`Settings.cs:141-150`, `AudioChain.cs:115`). Match this order when writing `audio-filter`.
- **Night mode** is the compressor with fixed ratio 8, threshold -30, makeup 12 (`Settings.cs:186-190`). A named "Night" preset (see A18) is a cheap win.
- **Preset behaviour.** Applying an equalizer preset copies preamp and bands into the settings; touching any band afterwards flips the preset name to "Custom" (`Effects.cs:33-50`). The panel snaps slider values to 0.5 dB steps and double-click resets a band to 0 (`EffectsPanel.cs:156,159`). The plan's `applyEqualizerPreset` has no "Custom" state; add `equalizerPreset == "custom"` on manual edit.
- **Real-audio tests.** Pylon verifies effects with the file-writing audio output (`--aout=afile --audiofile-file=<wav>`) and measures RMS: per-player gain scales a tone to 0.25 within 0.05 (`tests/Checks/Program.cs:130-152`), karaoke cancels a centred tone live (`:182`), a slider move changes level without a rebuild (`:201`). `modules/audio_output/file.c:116` provides `audiofile-file` in this tree. Add one or two such tests to Task 31 on top of the config round-trip tests (they catch "setting saved, sound unchanged").
- The libVLC-3-specific hacks (setting `audio-filter` on the player object via `var_SetChecked`, the per-player `gain` variable, `AudioChain.cs:9-88`) are not needed in VLC 4. Do not port them.

### A7. Task 5 "Redesign palette and accent" (derived accent shades)

Pylon: `App.xaml.cs:113-118`.

What it does: the accent is the only free input. `AccentDim` = accent mixed 19 % toward black (dark) / 12 % toward white (light). `AccentBright` (the tinted fill) = accent mixed 74 % toward black (dark) / 80 % toward white (light). Pylon's comment states the Figma values are exactly these mixes: `#AB6314` and `#371F06` from `#D37918`. Check: 211 x 0.81 = 171 = 0xAB and 211 x 0.26 = 55 = 0x37, so it holds.

Why it matters: `tokens.md` lists `accent-dim` (#AB6314) and `accent-tint` (#371F06) as fixed hex for the default orange only. Task 5's `AccentShades` has `base, hover, pressed, onAccent` and no dim or tint, so any of the other 8 swatches (and custom hex accents) would keep orange dim/tint on slider thumbs, toggle knobs and fills.

Port: add `dim` and `tint` to `AccentShades`, computed as above, with a test that the default accent reproduces `tokens.md` (`#AB6314`, `#371F06`) to within 1 per channel. Light theme: `tokens.md` uses "accent at 20 % over #FAFAFA" for the tint; Pylon uses an 80 % mix toward white. Keep `tokens.md` for light and use Pylon's formula only to cross-check dark.

### A8. Task 38 "Sleep timer"

Pylon: `MainWindow.xaml.cs:2656-2712`.

What it does: options Off / 15 / 30 / 45 / 60 / 90 min / "End of current item". A 1 s tick switches to a 100 ms tick in the last 10 s and ramps the volume down linearly to 0, then pauses (not stops) and restores the volume (`:2693-2711`). Changing or cancelling the timer mid-fade restores volume at once (`:2688`, `ApplyVolume`). The menu header shows the minutes left.

Why it matters: the plan's `SleepTimer` pauses at expiry with no fade (abrupt for people falling asleep) and has no volume restore rule.

Port: add the 10 s fade as a separate step in the timer; scale the player volume (`vlc_player_aout_SetVolume`) from the user's volume captured at the start of the fade, and always restore that value on pause, cancel or media change. Test with the injectable clock: at t-5 s volume is 50 % of the captured value; after expiry volume equals the captured value again; `start(0)` mid-fade restores. Do not persist the faded value.

### A9. Task 22 "Resume prompt"

Pylon: `MainWindow.xaml.cs:887-899`, timer `:122`, setting `Settings.cs:536`.

What it does: offers resume only when the saved time is over 10 s, progress is under 95 %, the item is not audio and "remember position" is on. The setting is Never / Ask / Always: Ask shows the banner, Always starts at the saved time with `:start-time=`. The banner auto-hides after 10 s.

Port: confirm the same three guards are in `ResumePrompt` (upstream `ResumeDialog` logic may use other thresholds). Settings-map row 63 (`restore-playback-pos`, never/ask/always) already matches the Pylon setting. Music exempt by default is a good rule.

### A10. Task 35 "Onboarding"

Pylon: `OnboardingWindow.cs:97-128` (welcome and folder), `:130-172` (theme), `:174-213` (preview), `:215-263` (shortcuts).

Findings:
- **Live theme preview.** The theme step shows a miniature of the app (rail, list, stage, control bar) built from the live theme tokens, so selecting Light/Dark/System or an accent updates it immediately (`:174-213`; `ThemeManager.Changed` re-renders, `:45-46`). The plan's theme step says "applied live"; a miniature preview is a cheap way to make that readable. Build it from `Rectangle`s bound to `ColorContext`.
- **Shortcut step is hard-coded** (`:217-226`), so it lies as soon as the user rebinds keys. The plan already reads keys from `ShortcutsModel` live (Task 35 Interfaces). Keep that, and treat it as a confirmed improvement.
- The folder step defaults to the Videos folder and adds it only on Next (`:76-86`). The plan's folder step should do the same and skip adding a folder that is already covered by a library root.
- Pylon's dots indicator and Back/Next footer layout match the Figma onboarding frames; reuse the layout.

### A11. Task 29 "Music now-playing view" (backdrop)

Pylon: `Backdrop.cs:9-95`.

What it does: the blurred artwork is rendered once at 160x90 with a small radius, cached as a bitmap and stretched over the window, which looks like a large blur at a fraction of the cost (`:41-44`). A new picture cross-fades over about 1 s (`:47-62`). An optional "live" mode slowly rotates and breathes the picture, and stops when the window is minimised or in light mode (`:66-93`). Settings offer Blurred cover / Cover colour / Theme colour (`Settings.cs:416`).

Port: `Widgets.DualKawaseBlur` (already in the plan) covers the blur; add (a) a cross-fade between old and new artwork on track change, (b) stop any animation when the window is hidden or occluded, (c) the "Theme colour" alternative for tracks with no artwork. Skip the rotating "live" mode (cosmetic, costs GPU).

### A12. Tasks 30, 33, 34 (and Task 3 `settings-map.md`) "Settings model, rows, modal"

Pylon: `Settings.cs:359-771` (13 pages), `SettingsWindow.xaml.cs:62-110`.

Findings:
- **Cross-check of Figma page texts.** Pylon's page titles are "Global Settings, Look & Feel, Privacy Settings, Mouse & Keyboard, Playback Preferences, Video Defaults, Audio Defaults, Subtitle Defaults, Playlists/Folders & Files, Network Connections & Security, Performance Settings, Recording/Casting & Streaming Out, Add-ons & Scripts" (`Settings.cs:361-765`), and the code comment says the strings come from the Figma file (`:281`). Use them to confirm the many `PROVISIONAL (upstream prefs)` rows in `settings-map.md`; the owner has the real Figma and should treat Pylon only as a hint.
- **Unavailable rows are hidden, not greyed.** `SettingsWindow.xaml.cs:83-84` filters them out ("greyed-out rows only confused"). The earlier evaluation read this as "disabled with an honest reason"; that is only a tooltip in `OptView.cs:60-65` that is never reached from the pages. This matches the plan (hide, list in `settings-map.md`).
- **Search** matches only the label and section heading (`:102`), in both English and the translated text (`:114`). The plan's search over descriptions as well is better; keep the bilingual match idea (match the translated and the English label).
- **Settings missing from `settings-map.md`** that Pylon exposes and VLC supports: `d3d11-upscale-mode` and `d3d11-hdr-mode` (`modules/video_output/win32/direct3d11.cpp:96-100`; Pylon `Settings.cs:179-180`), `preferred-resolution` (`src/libvlc-module.c:1889`; Pylon `:164`), `audio-replay-gain-preamp` and `audio-replay-gain-default` (`src/libvlc-module.c:1643-1645`; Pylon `Settings.cs:214-216`). Add rows to Task 3's map before Task 30 Step 0.
- **Defect, do not copy:** Pylon maps its "file name matching" choice to `sub-autodetect-fuzzy` as Exact name = 3, Any file = 4, default = 2 (`Settings.cs:234`). VLC defines 1 = any file, 2 = contains the movie name, 3 = name plus extra characters, 4 = exact (`src/libvlc-module.c:865-873`; behaviour in `src/input/subtitles.c:287-321`). Pylon's Exact and Any are swapped. The plan's spec §11.4 labels (0-4) are correct; keep them.
- **Subtitle size.** Pylon uses `freetype-rel-fontsize` presets (Smaller 20 ... Larger 6, `Settings.cs:239`), the VLC 3 approach. Spec §11.3 uses `sub-text-scale` (percent, `src/libvlc-module.c:1830`), which is better for VLC 4. Keep the spec.
- Pylon's per-page "Advanced" section sits under the same page below a divider (`SettingsWindow.xaml.cs:70-79`), the same idea as spec §11.4.

### A13. Task 32 "ShortcutsModel" (layout presets, global column)

Pylon: `Hotkeys.cs:14-77` (action list), `:79-100` (layouts), `:103-107`; dialog `DialogWindow.xaml.cs:139-200`.

Findings:
- **Layout presets.** A layout stores only the differences from the VLC defaults; user changes sit on top; "reset" returns to the layout (`Hotkeys.cs:79-107`). Shipped: "VLC-style", "YouTube-style" (J/K/L, `Space|K`), "MPC-HC-style". See B1.6 for turning this into a task. Task 32 itself needs no change except that `assign` must remember whether a key came from a layout or from the user.
- The Figma shortcuts dialog is three columns, Action | Hotkey | Global Hotkey, with a search box and an "All Fields / Action / Hotkey" filter (`DialogWindow.xaml.cs:148-160`). The plan's `hotkey` and `globalHotkey` roles cover the columns. Add the field filter to Task 37's dialog.
- **Defect:** Pylon's editor has no conflict check (its `Hotkeys.Match` is used only for dispatch, `Hotkeys.cs:141`). The plan's `conflictFor` and `assign` are an improvement.
- Global hotkeys exist natively (`modules/control/globalhotkeys/win32.c`); Pylon's `RegisterHotKey` code (`Hotkeys.cs:148-186`) is not needed.

### A14. Task 49 "OpenSubtitles search" (R6)

Pylon: `Subtitles.cs:12-95`; use `MainWindow.xaml.cs:3482-3521`.

Details to port:
- **Two searches, merged.** One by `moviehash`, one by cleaned name, because combining them narrowed the name search wrongly (`:30-35`). Show hash matches first with a mark ("made for exactly this file", `MainWindow.xaml.cs:3498`), then the rest by download count, capped at 20.
- **Parameter order.** The API wants query parameters and the language list sorted alphabetically or it redirects (`:29-30`). Add a test that the request URL sorts them.
- **Query cleaning.** Replace `. _ [ ] ( )` with spaces and cut everything from the first release token onward (`\d{3,4}p`, `4k`, `x264/x265`, `h.264/265`, `hevc`, `av1`, `web-dl/webrip`, `bluray`, `brrip`, `hdtv`, `aac/ac3/dts`, `ddp5.1`, `hdr`, `10bit`, `proper`, `repack`; `:65-74`).
- **Hash** is the standard OpenSubtitles hash and matches the plan's description (`:77-94`).
- **Quota.** Free downloads run out daily; Pylon shows the same "couldn't download" line for that (`MainWindow.xaml.cs:3514-3516`). The plan should surface the quota case separately, using the API's error body.
- The plan's "user's own API key" decision is right. Do not copy Pylon's committed consumer key (`:15`).
- Pylon saves next to the video as `<name>.<lang>.srt` (`:60`); the plan saves to a chosen folder and then calls `SubtitleAttacher.persist`, which is the safer choice (read-only media folders).
- `/download` may need an authenticated token for the user's quota; Pylon sends only the API key (`:55`). Check the current API terms before the owner reviews them.

### A15. Task 42 "Per-show presets" (store intro-end per folder here)

Pylon: `Library.cs:63` (`IntroEnds`, series folder -> ms), `MainWindow.xaml.cs:3278-3284` (mark), `:3203-3209`.

Pylon stores one number per series folder. Task 42's `PresetStore` already binds presets to folders, so add the pseudo-key `introEndMS` to the preset values and let B1.1 (Skip Intro) read it. This avoids a second per-folder store. Pylon's data model also confirms the "longest-prefix folder" lookup is unnecessary for it (exact folder key); keep the plan's longest-prefix rule, which is better for nested season folders.

### A16. Task 43 "Bookmarks and chapters tab"

Pylon: `MainWindow.xaml.cs:2580-2660`.

Confirms: Ctrl+B adds an unnamed bookmark at the current time with an OSD line, bookmarks sort by time, rename and delete exist, and bookmark/chapter ticks are drawn on the seek bar (`:2594-2606`). "Previous chapter" restarts the current chapter first if more than 3 s in (`:2615`), the same behaviour as previous track; apply it in the chapter list's jump.

Difference: Pylon stores bookmarks per path in its own JSON, so they work for any local file. The plan stores them in the ML (`vlc_ml_media_add_bookmark`, `include/vlc_media_library.h:1222`) and refuses files outside the library ("Bookmarks need the file to be in your library"). Consider a fallback store in `presets.json`-style JSON for non-library files; otherwise the shortcut silently does nothing for the most common non-library case (a file opened from Explorer).

### A17. Task 14 "Fork update channel" (UX only)

Pylon: `Updater.cs:63-83`, `:87-95`, `:102-165`; "what's new" after update at `MainWindow.xaml.cs:1444`.

Take the UX, not the mechanism: a daily check at most (`:88-93`), an opt-out switch (`Settings.cs:369`), a progress model with stages (downloading / assembling / installing) and a smoothed speed (0.6 old + 0.4 new, sampled every 0.5 s, `:116-121`), and a "what's new" note after the update restarts. The release notes can come from the signed status file. Do not copy: delta updates through Velopack (see B3.7), or the silent run of a downloaded setup after only a `StartsWith("https://github.com/")` check (`:81`, `:164`).

### A18. Task 50 "Settings profiles"

Pylon: `AppServices.cs:67-87`.

Pylon's "profiles" are not restart-based: `Apply(name)` first resets every key any profile touches to default and then layers the chosen profile's key/value pairs (Movies, Music, Night; `:74-76`, `:79-86`). That works live for keys that do not need a restart.

Port: ship three read-only starter profiles with Task 50 (Movies, Music, Night = compressor night mode + normaliser + dark), applied through `RedesignSettings` for non-restart keys, and use the plan's file-swap-and-restart only for keys flagged `restart`. Use the same reset-then-layer rule so profiles do not accumulate leftovers.

### A19. Tasks 10 and 29 "Name labels / music caption" (untagged files)

Pylon: `Library.cs:181-187`; test `tests/Checks/Program.cs:43-45`.

For a file with no title tag, derive "Artist - Title" from the file name: strip a leading track number (`^\d{1,3}[\s.\-_]+(?=\D)`), turn `_` into spaces, split on the first of ` - `, ` – ` or ` — ` (artist is the left side). If the tag title is real, leave it alone. Use it for the music view caption and the file-name label when metadata is empty. The three checks in the test are a ready test list.

---

## B. Pylon features VLC Reborn does not have and VLC does not provide

Effort is in the plan's terms: S up to 1 week, M 1-3 weeks, L over 3 weeks, at part-time pace.

### B1. Group 1: high value, low risk

| # | Feature | Pylon files | User value | Effort | Dependencies / risks / fit |
|---|---|---|---|---|---|
| 1.1 | **Skip Intro button and optional auto-skip**. A chapter named intro/opening/OP (or a per-folder "intro ends here" mark) shows "Skip Intro" over the video | `MainWindow.xaml.cs:3192-3209`, `:3236-3263`, `:3278-3284`; `Settings.cs:553`; `Library.cs:63` | Series watchers skip 90 s of titles with one click | S | Needs chapter names (`ChapterListModel`) and the folder store from Task 42 (A15). Name matching must stay strict (Pylon uses exact match for short tokens like "op"/"ed", substring only for names longer than 3 characters, `:3197-3198`). Auto-skip off by default. Fit: a button on the right of the ResumePrompt band; no new screen. R4 |
| 1.2 | **Next Episode** at the end (or at the end-credits chapter), natural order within the folder | `MainWindow.xaml.cs:3212-3235`, `:3250-3256`, `:971`; `Settings.cs:552` | Binge viewing without building a playlist | S | VLC does not enqueue siblings when one file is opened (verify with `playlist-autostart` behaviour). Use Windows natural sort (`StrCmpLogicalW`, `:3225`) or `QCollator` with numeric mode. Only when the file was opened alone, not from a queue. Same band as 1.1. R4 |
| 1.3 | **Sidecar lyrics: `.lrc` (later enhanced LRC and TTML)** feeding the existing lyrics view | `Lyrics.cs:130-138` (order: `.ttml`, `.lrc`), `:313-368` (LRC: multiple stamps per line, `[offset:]`, translation lines, `<mm:ss>` word tags), `:228-285` (TTML) | Music view shows synced lyrics for local libraries, not only for MP3s with embedded SYLT | S for `.lrc` line-level; M with TTML | VLC 4 here already has the view: `modules/gui/qt/player/qml/LyricsFlickable.qml` and embedded SYLT/USLT (`player_controller.cpp:195-258`, `modules/demux/mpeg/es.c:590-660`), so only a sidecar loader is new. Local files, low risk. Check that VLC's subtitle auto-detect does not load `.lrc/.ttml` as subtitles for music (Pylon needed `:no-sub-autodetect-file`, `MainWindow.xaml.cs:903`). Fit: Music view, Task 29. R4 |
| 1.4 | **Measured loudness ("Replay gain: Measured")** for untagged files, from the waveform pass | `Waveform.cs:115`; `MainWindow.xaml.cs:3289-3300` (gain to about -18 dBFS RMS, limited to -12 dB / +4 dB) | Even volume across a mixed library | S after Task 46 | VLC applies replay gain only from tags (`src/audio_output/volume.c:142`, options `src/libvlc-module.c:1640-1647`). Needs a spike on how to inject a per-item gain (an `audio_replay_gain_t` on the stream or a per-input volume factor). RMS is not LUFS and has no K-weighting; keep peak protection (`audio-replay-gain-peak-protection`). Fit: Settings > Audio. R4 |
| 1.5 | **Default-player card**: shows "N of M formats open in <app>" and one button that opens the Windows Default apps page | `ShellRegistration.cs:205-222` (status via `AssocQueryString`), `FileTypesDialog.cs:44-110` (card), deep link `ms-settings:defaultapps?registeredAppUser=Pylon` (`:109-110`) | A distributed fork is asked "how do I make it the default?" | S | The installer already registers Capabilities (`extras/package/win32/NSIS/vlc.win32.nsi.in:357-359`) and extensions (`helpers/extensions.nsh`). `registeredAppUser` must equal the `RegisteredApplications` name, so update it with Task 13's rename. **Do not copy `MakeDefault`**: it deletes `UserChoice` / `UserChoiceLatest` keys and rewrites class defaults (`ShellRegistration.cs:236-245`), a hash-protected Windows setting; it can break associations and trips security tools. Fit: Settings > Library. R3 |
| 1.6 | **Keyboard layout presets** (VLC, YouTube-style, MPC-HC-style) | `Hotkeys.cs:79-107`; `Settings.cs:515-516`; check `tests/Checks/Program.cs:119` | People arrive with muscle memory from other players | S | Needs Task 32. VLC `key-*` options hold one binding each (verify), so Pylon's `A|B` alternatives (`Hotkeys.cs:81`) may have to be dropped. Offer the preset as a choice in Onboarding's shortcuts step. R3 |
| 1.7 | **Quick Convert dialog with friendly presets, plus "Save A-B loop as clip"** | `Converter.cs:19-69`, `ConvertDialog.cs`, `MainWindow.xaml.cs:3078-3080` | Spec §11.1 puts Convert in the menu, but the stock wizard is hard for casual users | M | Uses `stream_out/transcode` with `:start-time/:stop-time`, so nothing new in the core. Pylon records encoder facts worth keeping: use `acodec=mp3` (mpga is MP2), GIF needs 20 fps, x264 is 10-bit only in that build (`Converter.cs:17-18, 21, 27`), re-verify against the fork's contribs. Fit: the ☰ menu's Convert entry opens this instead of the QWidgets wizard (keep the wizard as "Advanced"). R6 |
| 1.8 | **Pause while another app plays sound** | `Desktop.cs:147-173`; `MainWindow.xaml.cs:349-371` | Video call or notification-heavy workflow without touching the player | S | Polls other audio sessions' peak meter (threshold 0.01) on the default device and resumes 3 s after quiet. False positives (system dings; the system-sounds session is skipped, `:163`). Default off. Fit: Settings > Playback. R6 |
| 1.9 | **"Never remember items matching" patterns** | `Library.cs:196-204`; `Settings.cs:506` | Private content stays out of Continue Watching and recents | S | VLC has only the global switch `save-recentplay` (`src/libvlc-module.c:1926`). Needs a hook where playback is recorded to the ML history (verify where). Fit: Settings > Privacy. R6 |
| 1.10 | **Theme variants**: OLED black, Midnight, Nord, Sepia as token-override presets | `App.xaml.cs:93-101` | Cheap personalisation | S | Overrides about 15 tokens over `fillPalette`. Each needs a WCAG run like Task 5's test. Fit: Settings > Interface > Theme. R5-R6 |
| 1.11 | **Contact sheet** (4x4 frames with times and file info saved as PNG) | `Frames.cs:79-124` | Low; handy for sharing or cataloguing | S | Reuses the thumbnail pipeline of Task 45. Low priority. R6 |

### B2. Group 2: valuable but needs care (services, keys, security)

| # | Feature | Pylon files | User value | Effort | Dependencies / risks / fit |
|---|---|---|---|---|---|
| 2.1 | **Website playback through yt-dlp** (YouTube, Twitch, ~1,800 sites), playlist and channel expansion | `YtDlp.cs:13-80` (resolve, format sort `res,vcodec:avc1,acodec:m4a` for hardware decode), `:32-46` (playlists), `:167-199` (install), `:204-211` (daily `-U`), `:137` (JS runtime), `:146` (cookies); separate audio via `AddSlave` (`MainWindow.xaml.cs:798`) | "Paste a link and it plays" is the most-requested thing VLC no longer does well | M | This tree has no YouTube script (`share/lua/playlist/` has vimeo, dailymotion, soundcloud, twitch...). **Security**: Pylon downloads `yt-dlp.exe` from the GitHub "latest" URL and runs it with no checksum or signature check (`YtDlp.cs:176-195`) and lets it self-update daily; adopt instead: pin a version and SHA-256 in the fork's signed status file (Task 14), download over HTTPS from the release tag URL only after explicit consent, verify before first run, run with `--ignore-config`, no background `-U` (update through the status file). The JS runtime is found on `PATH` (`:137`); pin or ship one rather than trusting `PATH`. `--cookies-from-browser` reads browser cookies; keep it off, disclose it. Site ToS and takedown risk sit with the user's use, but ship it as an opt-in add-on, not default. Fit: Open network stream dialog (Task 36). R6 |
| 2.2 | **LRCLIB online lyrics lookup** (opt-in) | `Lyrics.cs:205-219` (exact match then search, closest duration within 5 s, plain-text fallback), cache `:177-178`, negative cache 7 days `:151` | Lyrics for untagged local music | S-M | Sends artist, title, album, length to a third party. Pylon defaults it on (`Settings.cs:446`); the fork should default off, say so in Privacy, and send a descriptive User-Agent. Review LRCLIB terms. Builds on 1.3. R6 |
| 2.3 | **Windows media session (SMTC)**: metadata and artwork in the volume flyout, lock screen and Bluetooth devices; scrubber | `MediaSession.cs:1-101` | Expected on Windows 11 | M | Not present in this tree (no SMTC code; only `WM_APPCOMMAND` media keys, `modules/gui/qt/maininterface/mainctx_win32.cpp:47-52`). Technical risk: Pylon uses the C# WinRT projection; the fork builds with mingw-w64, so a spike is needed on raw `ISystemMediaTransportControlsInterop` COM. R5-R6 |
| 2.4 | **Phone remote with QR code** | `Remote.cs:1-119`; QR via QRCoder (MIT) | Control playback from the couch | M | VLC already ships a web interface with a mobile page (`share/lua/intf/http.lua`, `share/lua/http/mobile.html`); the gap is one-click start, QR pairing and safe defaults. Pylon's server binds all interfaces (`Remote.cs:28`), uses a 48-bit key in the URL path (`:17`) over plain HTTP, and runs state-changing commands on GET (`:65-69`). Do better: random key of at least 128 bits, bind only while the dialog is open, require a header or POST for commands, rate-limit. VLC's `requests/browse.json` lists the file system; disable it. Windows Firewall prompt on first use. R6 |
| 2.5 | **Modern Last.fm scrobbling** (web authorisation, no password in the app) | `LastFm.cs:129-145` (token, browser approval, session), `:174-175` (md5 signature) | Scrobbling that still works | M | VLC has the legacy submission plugin (`modules/misc/audioscrobbler.c`, protocol 1.2, username and password options `:135-138`); see C. A rewrite needs the fork's own Last.fm API key and secret (Pylon commits both, `LastFm.cs:120`; do not copy), and ToS review. R6 |
| 2.6 | **Discord Rich Presence** | `Discord.cs:1-99` (local pipe, no SDK) | Niche but visible | S | Needs the fork's own Discord application ID and images; no network from the app (local pipe). Default off; says what you watch on your profile. R6 |

### B3. Group 3: not recommended

| # | Feature | Pylon files | Why not |
|---|---|---|---|
| 3.1 | Word-by-word lyric animations (16 styles) and the Spicy Lyrics API | `LyricsView.cs` (894 lines), `SpicyLyrics.cs:10-26` | Large (L), scope drift, and it depends on a third-party API called with a publishable key embedded in the client. If wanted later, highlight words from enhanced-LRC tags only (S) |
| 3.2 | Watch Together over the internet | `Party.cs`, `relay/party-relay.py` | Needs a hosted relay (operations, abuse and privacy duty: the host's stream copy sits on the operator's server, no per-guest auth, see evaluation §6). L plus ongoing cost |
| 3.3 | Spotify import, Spotify remote, YouTube Music radio, "Radio by this song" | `Spotify.cs`, `OtherPlayer.cs`, `YtDlp.cs:319-447` | Unofficial `youtubei` calls with a hard-coded request context, Spotify developer-mode limits, ToS exposure, scope drift from "redesign VLC" |
| 3.4 | Custom visualizers and spectrum | `Scene.cs`, `Spectrum.cs` (WASAPI process loopback) | L, cosmetic. VLC has visualization modules (see C); expose those first |
| 3.5 | Crossfade between songs | `MainWindow.xaml.cs` crossfade block (from `:369`), `AudioChain.cs:60-88` | Two simultaneous players and per-player gain tricks specific to libVLC 3. VLC 4 has no gapless/crossfade support to build on. L, niche |
| 3.6 | DirectSound/WASAPI output choice, `--audio-resampler=none` | `AudioChain.cs:90-95`, `Settings.cs:220-226`, `TODO.md` | libVLC-3-only. This tree has only the WASAPI shared output (`modules/audio_output/mmdevice.c`, no DirectSound, no exclusive) and the soxr resampler is a contrib (`contrib/src/soxr/rules.mak:6`; Pylon's official libVLC 3 build lacked it). Instead run a 44.1 to 48 kHz seek-and-sync listening test in the smoke checklist |
| 3.7 | Velopack delta updates and installer | `Updater.cs`, `build.ps1`, `.github/workflows/release.yml` | Replaces the NSIS and PGP-status-file pipeline (Tasks 13-15). Integrity is a hash on the same release, and the README promises signing that no workflow performs (evaluation §6). Revisit only if installer download size becomes a real complaint |
| 3.8 | Icaros shell-thumbnail installer | `FileTypesDialog.cs:116-133` | Downloads a third-party installer and starts it unverified |
| 3.9 | Ambient blurred video backdrop, "live" rotating backgrounds | `MainWindow.xaml.cs:1845-1925` (snapshot every 2 s into a blur), `Backdrop.cs:66-93` | Cosmetic, not in the Figma player frame, ongoing GPU cost |

Also checked and not applicable: Pylon's own tray/popup code, single-instance pipe (`AppServices.cs:8-65`) and Weblate flow. VLC has the first two natively (see C) and the fork uses Qt `.ts`.

---

## C. Pylon features VLC already has natively (UI exposure only)

| # | Feature | VLC module / source | Where to expose |
|---|---|---|---|
| 1 | Chromecast and renderers | `modules/stream_out/chromecast/cast.cpp`; discovery in `modules/services_discovery/microdns.c`, `upnp.cpp`, `avahi.c`; Qt `modules/gui/qt/util/renderer_manager.cpp`; control item `RENDERER_BUTTON` (`player/control_list_model.hpp:81`) | Task 12 re-skin of the existing button; also in the ☰ menu (Task 20) |
| 2 | UPnP / mDNS / SAP network discovery | `modules/services_discovery/upnp.cpp`, `microdns.c`, `sap.c` | Network page (Rail "Network", Task 17) |
| 3 | Podcasts | `modules/services_discovery/podcast.c`; Qt `modules/gui/qt/dialogs/podcast/` | New small task: restyle the podcast entry on the Network page |
| 4 | Internet radio | `modules/services_discovery/radio.c` (radio-browser.info; Pylon had to replace libVLC 3's empty Icecast list, `Network.cs:65-81`) | Network page; same small task |
| 5 | 360 video | `modules/video_output/opengl/{display.c,renderer.c,vout_helper.c}`, `win32/sensors.cpp` | Nothing to build. Optional polish: Pylon's inertial "fling" after a drag (`ViewAngles.cs:45-52`) |
| 6 | Equalizer, compressor, spatializer, stereo widener, pitch, karaoke, chorus, normaliser | `modules/audio_filter/{equalizer.c,equalizer_presets.h,compressor.c,spatializer/,stereo_widen.c,scaletempo.c (scaletempo_pitch, meson.build:118),karaoke.c,chorus_flanger.c,normvol.c}`; Qt panels `dialogs/extended/extended_panels.cpp:1411` | Tasks 31 and 40. Figma has the first four; Pylon adds a "Voice and Pitch" card (`EffectsPanel.cs:70`): new small task to add pitch, karaoke, chorus and normaliser rows to the Audio tab |
| 7 | Audio visualizations | `modules/visualization/{goom.c,projectm.cpp,glspectrum.c,visual/,vsxu.cpp}`; option `audio-visual` (`src/libvlc-module.c:1662`) | Music view (Task 29) or Audio tab as a choice; settings-map row exists |
| 8 | Lua extensions | `modules/lua/`, `share/lua/{extensions,playlist,sd,meta,intf}` | Settings > Extensions (Task 34) |
| 9 | Bookmarks | `include/vlc_media_library.h:1222`; Qt `dialogs/bookmarks/bookmarks.cpp` | Task 43 |
| 10 | Chapters, titles | `modules/gui/qt/player/input_models.hpp` (`ChapterListModel`) | Tasks 22 (ticks) and 43 |
| 11 | A-B loop | `include/vlc_player.h:818` (`vlc_player_SetAtoBLoop`); control item `ATOB_BUTTON` | New small task: A-B band and markers on the seek bar (A2) and a Playback-tab row |
| 12 | Record and snapshot | `include/vlc_player.h:922`; `modules/stream_out/record.c`; items `RECORD_BUTTON`, `SNAPSHOT_BUTTON` | Task 12 re-skin; folder settings in settings-map |
| 13 | Time-shift buffer | option `input-timeshift-path` (`src/libvlc-module.c:2032`) | Settings > Playback advanced |
| 14 | Transcode / convert / stream | `modules/stream_out/{transcode/,standard.c,duplicate.c}`; Qt `dialogs/sout/` | ☰ menu Convert and Stream (Task 20); friendlier front end is B1.7 |
| 15 | Subtitle auto-detect and fuzziness | `src/input/subtitles.c:223-321` | Settings > Subtitles with plain-word labels (spec §11.4) |
| 16 | D3D11 upscaling (linear, point, video processor, Super Resolution) and HDR (auto, never, always, generate from SDR) | `modules/video_output/win32/direct3d11.cpp:72-100`, `d3d11_scaler.cpp` | Settings > Video and the Video tab (Task 41); **missing from `settings-map.md`** |
| 17 | Hardware decoding | `modules/codec/avcodec/{d3d11va.c,dxva2.c}` | Settings > Performance (map row `dec-dev`) |
| 18 | Preferred video quality for adaptive streams | `src/libvlc-module.c:1889` (`preferred-resolution`) | Settings > Playback; missing from `settings-map.md` |
| 19 | Replay gain mode, preamp, default gain | `src/libvlc-module.c:1640-1647`, `src/audio_output/volume.c` | Settings > Audio; preamp/default missing from `settings-map.md` |
| 20 | Audio output devices; S/PDIF and HDMI passthrough | `modules/audio_output/mmdevice.c:1580-1584` (`mmdevice-passthrough`, `mmdevice-audio-device`) | Task 23 (device list in the Audio tab); Settings > Audio advanced |
| 21 | Last.fm scrobbling (legacy) | `modules/misc/audioscrobbler.c` (protocol 1.2, `lastfm-username`, `lastfm-password`, `:24`, `:135-138`) | Settings > Privacy or Extensions; modern auth is B2.5 |
| 22 | Song recognition (Chromaprint and AcoustID) | `modules/misc/fingerprinter.c`, `modules/misc/webservices/acoustid.c`, Qt `dialogs/fingerprint/` | New small task: "Identify song" in the track context menu. Verify the Windows contribs build Chromaprint and decide where the AcoustID key comes from (`psz_apikey`, `acoustid.c:161`) |
| 23 | Cover art and metadata fetch | `share/lua/meta/art/{00_musicbrainz.lua,03_lastfm.lua}`, `modules/meta_engine/folder.c`; privacy switch `metadata-network-access` | Settings > Privacy (map row exists) |
| 24 | Synced lyrics (embedded SYLT/USLT) | `modules/gui/qt/player/qml/LyricsFlickable.qml`, `player_controller.cpp:195-258` | Task 29 music view should host it; sidecar `.lrc` is B1.3 |
| 25 | Global hotkeys | `modules/control/globalhotkeys/win32.c` | Task 32 `globalHotkey` column |
| 26 | Media keys and taskbar thumbnail buttons | `mainctx_win32.cpp:47-52` (`WM_APPCOMMAND`), `:685-697` (`ThumbBarAddButtons`) | Nothing to do |
| 27 | System tray, track-change notification, pause when minimised, single instance | `modules/gui/qt/qt.cpp:366-375`; `one-instance` (`src/libvlc-module.c:2166`) | Settings > Interface (map rows exist) |
| 28 | Web interface | `share/lua/intf/http.lua`, `share/lua/http/` | B2.4 |
| 29 | Resume position (never/ask/always) | `restore-playback-pos` | Task 22; map row 63 |
| 30 | File associations and "Capabilities" registration | `extras/package/win32/NSIS/helpers/extensions.nsh`, `vlc.win32.nsi.in:357-359` | B1.5 adds the in-app card |
| 31 | Network proxy, user agent, referrer, cookies forwarding | `http-proxy`, `http-user-agent`, `http-referrer`, `http-forward-cookies` | Settings > Network (map rows exist) |
| 32 | Equalizer presets | `modules/audio_filter/equalizer_presets.h` | Task 31 |
| 33 | Media library albums, artists, genres, history | `modules/misc/medialibrary/` | Tasks 17, 25, 26 |

Not native: sleep timer, skip intro, next episode in folder, pause on other audio, the SMTC media session, YouTube-style website playback, phone-remote pairing, quick-convert presets, layout presets. These are in A and B.

---

## Recommended additions

Ordered by value per effort. "Release" is the suggested slot. Items 1-8 are the cut for the next plan revision. Items 9-11 are next in line.

1. **Attach library-stored subtitles at playback start.** Scope: when a library item starts, add its `VLC_ML_FILE_TYPE_SUBTITLE` files as input slaves (fixes a gap in Task 37 where the saved association is never read back, see A4). Effort S. Release R3, before Task 37's Step 4.
2. **Skip Intro and Next Episode.** Scope: a button band over the video for chapter-named intros and per-folder intro marks stored in `PresetStore` (`introEndMS`), and next-file-in-folder at the end; auto-skip option off by default. Effort S (each of the two is S, together about 1.5 weeks). Release R4, after Task 42.
3. **Sidecar `.lrc` lyrics in the music view.** Scope: load `<name>.lrc` (stamps, offset tag, translation lines) into the existing `LyricsFlickable` list when the file has no embedded lyrics. Effort S. Release R4 (with the music view from Task 29 already in place).
4. **Friendly audio track labels.** Scope: a label helper over `vlc_player_track.fmt` ("Track 2 · AAC · stereo · 48 kHz · English") exposed as a model role for the Task 23 popup. Effort S. Release R2 (can ship inside Task 23).
5. **Measured loudness from the waveform pass.** Scope: store RMS loudness with the waveform cache and apply a clamped gain toward -18 dBFS for untagged files, as a "Replay gain: Measured" choice. Effort S after Task 46 (spike on gain injection first). Release R4.
6. **Default-player card.** Scope: Settings > Library card that reads the effective default per extension with `AssocQueryString` and opens `ms-settings:defaultapps?registeredAppUser=<name>`. Effort S. Release R3 (after Task 13's rename).
7. **Keyboard layout presets.** Scope: VLC / YouTube-style / MPC-HC-style presets on top of `ShortcutsModel`, offered in Settings > Controls and the Onboarding shortcuts step. Effort S. Release R3 (with Task 32).
8. **Website playback through yt-dlp (opt-in add-on).** Scope: resolver for pasted web-page URLs with a pinned, SHA-256-verified yt-dlp downloaded with consent into the user profile, `--ignore-config`, no self-update, audio as slave, playlist expansion. Effort M. Release R6.
9. **Windows media session (SMTC).** Scope: title, artist, artwork and a scrubber in the Windows flyout and lock screen; spike mingw-w64 COM first. Effort M. Release R5-R6.
10. **Quick Convert dialog and "Save A-B clip".** Scope: preset-based front end over the transcode chain, with start/stop-time. Effort M. Release R6.
11. **Phone remote with QR pairing.** Scope: one-click start of a LAN-only, token-protected remote page (not the stock Lua browse endpoints). Effort M. Release R6.

Plan amendments that need no new task (details in A): derived accent dim/tint (Task 5), RMS plus size/mtime cache key plus WAV-length rule (Task 46), hardware decode and fast seek for thumbnails (Task 45), episode-tag matching with the corrected regexes (Task 37), no-rebuild rule and afile audio tests (Task 31), sleep-timer fade (Task 38), missing `settings-map.md` keys (Task 3).
