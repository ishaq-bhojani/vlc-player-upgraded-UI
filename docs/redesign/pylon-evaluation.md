# Evaluation of "Pylon" (github.com/MeowKusTrue/Pylon) vs. continuing VLC Reborn

Reviewed: clone at commit `8e06dea` (v1.9.9), read-only. Nothing was built, run or executed. All paths below are relative to the Pylon repo root unless stated. Line numbers refer to that commit.

Short version: Pylon is a real, working, unusually polished WPF/libVLC 3 music-and-video player that matches the Figma look very closely. It is also a single-author, AI-assisted, two-day-old code base (33 commits, each commit a whole release) built on the wrong engine and with the wrong scope for your goal. It re-implements the Figma *look*, but it contains almost none of the spec §11 "designer intent" features and none of VLC's depth. It is a good source of ideas, not a base.

---

## 1. Architecture

**Layout.** One WPF app project `Pylon/` (62 `.cs`, 8 `.xaml`, ~17.1 k lines), one test console project `tests/Checks/`, a Python relay `relay/party-relay.py`, installer scripts, `build.ps1`. Flat folder, no sub-namespaces, single namespace `Pylon`. Target `net10.0-windows10.0.19041.0`, self-contained x64 (`Pylon/Pylon.csproj:6-24`). Deps: LibVLCSharp.WPF 3.10.2, VideoLAN.LibVLC.Windows **3.0.24**, Velopack, QRCoder, SharpVectors.

**UI construction.** Hybrid, and mostly code-behind:
- XAML only for the shell: `MainWindow.xaml` (318 lines), `Theme.xaml` (548, styles/tokens), `LibraryPanel.xaml`, `SettingsWindow.xaml`, `DialogWindow.xaml`, two palette dictionaries `Colors.Dark.xaml` / `Colors.Light.xaml`.
- Everything else is built in C#: the settings pages are generated from a C# schema (`Settings.cs:359+`, `Opt`/`Section`/`Category` records, rendered by `OptView.cs`); every dialog (`DialogWindow.xaml.cs`, 561 lines of `new Border{...}`), the effects panel (`EffectsPanel.cs`), onboarding (`OnboardingWindow.cs`), context menus (`MainWindow.xaml.cs:3365+`, `ShowMenu`).
- Custom-drawn controls (`Controls.cs`: `SeekBar`, `VolumeBar`, `Icon`), a software visualizer/scene renderer (`Scene.cs`, `Spectrum.cs`), a spring-animation engine (`Motion.cs`).

**Separation of concerns.** There is **no MVVM** — no view models, no bindings to speak of, no DI. State lives in static classes (`Settings`, `Library`, `L`, `Hotkeys`, `ThemeManager`) and in fields of the window. The player logic is in the window class:
- `Pylon/MainWindow.xaml.cs` is **3,962 lines / 214 KB / ~250 methods** — a textbook god class. It owns the libVLC engine, queue/shuffle, crossfade, sleep timer, casting, party/remote servers, tray, media session, Discord, Last.fm hooks, menus, the OSD, fullscreen/mini-player layout, and a ~335-line `#if DEBUG` UI-snapshot harness (`MainWindow.xaml.cs:3612-3947`).
- Second tier of big files: `Settings.cs` 772 lines (schema + engine-arg builder + persistence in one static class), `LibraryPanel.xaml.cs` 760, `LyricsView.cs` 894, `YtDlp.cs` 528, `OtherPlayer.cs` 511, `Scene.cs` 501.
- Satellite classes (`Waveform`, `SeekPreviewer`, `AudioChain`, `Subtitles`, `Updater`, `Remote`, `CastServer`, `Party`) are reasonably self-contained and small, so the codebase is *modular at the edges* but the core is monolithic.

**Threading around libVLC.** This is the best-engineered part and clearly informed by real libVLC pitfalls:
- libVLC events are marshalled to the dispatcher and guarded against stale players: `MainWindow.xaml.cs:285-288` (`mp.EndReached += ... Dispatcher.BeginInvoke(() => { if (mp == _mp) ... })`), with an explicit comment "never call back into libVLC from there".
- Blocking `Stop()` is pushed off the UI thread (`:423`, `:582`); the seek-preview and waveform code avoid calling libVLC from its callbacks (`SeekPreviewer.cs:34-47`, `Waveform.cs:79`).
- Engine reload recreates `LibVLC` + `MediaPlayer`, stops/disposes the old player and delays disposing the old `LibVLC` by 4 s via `Task.Delay(4000).ContinueWith(...)` (`:238-271`) — a timing hack, but it is commented.
- Weaknesses: ~22 `async void` handlers in `MainWindow` (mitigated by a global safety net, see §2), static `HttpClient`s scattered in 21 places, UI-thread dispatch via `Dispatcher.Invoke` inside the phone-remote HTTP handler (`Remote.cs:75`).

**Settings/state persistence.** `settings.json` = flat `Dictionary<string,string>` (all values stringly-typed; `Settings.cs:42-80`), 500 ms debounced, written through a temp file + atomic `File.Move`. `library.json` holds folders, playlists, history, bookmarks, subtitle associations, pins, etc., same atomic-write pattern (`Library.cs:110-122`). There is **no media database** (no SQLite, no media-library equivalent of VLC's ML): the library is folder scans + tag reads + JSON. Both files live in `%AppData%\Pylon`. Playlists/history in one JSON blob will not scale to large libraries the way VLC 4's ML does.

**Settings model.** ~212 option definitions in 13 categories with an "Advanced" section per category. They map to libVLC 3 command-line args (`Settings.cs:200-290`) and a *handful* trigger an engine restart. This is a curated subset, not VLC's preference tree; a free-text "Additional command line options" row (`general.cmdline`) is the escape hatch. Unsupported options are shown disabled with an honest reason (24 `.Off(...)` rows, e.g. `Settings.cs:400-403, 560, 769 "VLC Lua extensions need the original Qt interface"`).

## 2. Code quality

**Better than the "AI-generated in two days" prior would suggest.** Observations:

*Good*
- Error handling is deliberate: exceptions are caught by type (`catch (Exception e) when (e is IOException or UnauthorizedAccessException)` is the dominant style). Only **2** empty `catch { }`/`catch (Exception) { }` blocks in the whole project; 118 `catch` sites total.
- A global safety net: `ErrorLog.Install` (`App.xaml.cs:47-77`) handles dispatcher/task/domain exceptions, de-duplicates bursts, writes `errors.log` and shows an OSD line instead of crashing. Honest about the downside ("fatal ... can't be stopped"). `Settings`/`Library` saves are atomic.
- Resource lifetimes: `LibVLC`/`MediaPlayer` are disposed on close and engine reload (`:218-231`, `:258-264`); `SeekPreviewer : IDisposable` frees its unmanaged buffer; `Waveform` disposes `Media`/`MediaPlayer` with `using`.
- Comments explain *why* and record measurements (e.g. the audio-resampler rationale, `Settings.cs:218-226`, with SNR numbers) — rare and valuable.
- Localisation is real: `L.T()` everywhere, `lang/en.json` + `ru.json` of 1,201 keys each, with a CI check that keys and `{0}` placeholders match (`tests/Checks/Program.cs`, "translations" block).

*Concerns*
- **God class + code-behind UI** (see §1); hard to review, hard to merge, no seams for unit tests.
- **Zero `TODO`/`FIXME` in source** while a Russian `TODO.md` lists real unfixed items (e.g. ".lrc/.ttml read without own try", lyrics regression history). The "known issues" live out of band.
- **Magic numbers** are common (`Task.Delay(4000)`, `Thread.Sleep(25)` polling loops at `MainWindow.xaml.cs:1912`, `Frames.cs:52`, hard-coded pixel sizes/hex colours). `DialogWindow.xaml.cs` hardcodes hex brushes (`Brush("#C6C6C6")`, `#6B6B6B`, `#222222`, lines ~517-531) that bypass the theme tokens and will not follow light/OLED/Nord themes.
- **Duplication**: the two seek handlers (`MainWindow.xaml.cs:111-112`) are copy-pasted; three hand-rolled TCP/HTTP servers (`Remote.cs`, `CastServer.cs`, OAuth listener in `OtherPlayer.cs`) each parse requests by splitting the first line on spaces and reading one 2-4 KB buffer; download-with-progress is copied three times (`YtDlp.cs:166-199`, `Ffmpeg.cs:20-52`, `Updater.cs:140-158`).
- **A stub in UI**: the Add-Subtitles dialog's origin drop-down offers "From OpenSubtitles (needs an account)" but immediately snaps back to "From computer" — `origin.SelectionChanged += (_, _) => origin.SelectedIndex = 0; // only local files for now` (`DialogWindow.xaml.cs:455`). Online subtitles exist, but via a separate menu item (`MainWindow.xaml.cs:3485`).
- **Signs of AI provenance**: every commit carries `Co-Authored-By: Claude Opus 5.5` (33/33), commit messages are release-note style, changelog is bilingual and verbose. But the code is *not* the typical unreviewed-AI pattern (no placeholder logic, no dead scaffolding, consistent style, tested claims with measurements). The author is evidently iterating against a running app, with a debug-only screenshot harness (`PYLON_SNAP`).
- Plain-text secrets: web-interface password and proxy password stored in `settings.json` and passed as libVLC command-line args (`Settings.cs:~239 --http-password`, `--http-proxy-pwd`); Spotify token in `spotify-token.txt` (`OtherPlayer.cs:35`).

## 3. Tests, CI, release automation

- `tests/Checks/Program.cs`, 243 lines. **Not a test framework** — a hand-rolled `Check(name, bool)` console app returning exit code 1. About 25-30 checks: TTML/LRC/Spicy lyrics parsing, filename → artist/title, "Add to Music" copy semantics, proxy-string building, artist transliteration, lyric colour readability, default-player format list, language-file key/placeholder parity, shortcut-layout uniqueness, and four **real libVLC audio tests** (effects chain rebuilds, per-player gain RMS via the `afile` module, live effect switch, equalizer slider w/o rebuild, "seeking keeps sync" — skipped unless a VB-Cable device exists).
- What is **not** tested: the entire UI, `MainWindow` logic (queue, crossfade, resume), `Library` scanning, `Updater`, `Party`/`Remote`/`CastServer`, `YtDlp`, settings persistence round-trips, Spotify/Last.fm/Discord, the relay. No coverage measurement.
- CI: `.github/workflows/ci.yml` — on push to `main` and PRs: `dotnet build -c Release` then `dotnet run --project tests/Checks`. Windows runner only. Note: this repo's default branch must be `main` for CI to trigger on push.
- Release: `.github/workflows/release.yml` on tag `v*.*.*` → `build.ps1` (publish R2R, generate libVLC plugin cache, Velopack `vpk pack`, Inno Setup "bridge" installer) → `vpk upload github`; release notes extracted from `CHANGELOG.md`. This is a clean, minimal pipeline. **No code signing step exists** (see §6).

## 4. Feature reality check

Legend: **Real** = implemented end-to-end in code I read; **Partial**; **Absent**; **Stub**.

### Spec §11 / README items, sampled (≈20)

| # | Feature | Verdict | Evidence |
|---|---|---|---|
| 1 | Waveform seek bar | **Real** (audio only) | `Waveform.cs`: libVLC transcodes to 8 kHz mono WAV via `sout`, reduced to 400 RMS bins, disk-cached by (path,size,mtime) hash, also yields a LUFS-style loudness for replay-gain. Falls back to plain bar. Matches your R4 design almost exactly. Not for video. |
| 2 | Seek thumbnails | **Real** | `SeekPreviewer.cs`: second silent `MediaPlayer` with video callbacks into a 256x144 `WriteableBitmap`, 120 ms throttle, 0.5 % cache buckets, ≤200 frames (~30 MB), pauses after frame lands. |
| 3 | Track popups (subs / audio) | **Partial** | They are styled **context menus**, not the popup in §11.1: `AudioMenuItems()` lists tracks (with a descriptive "Track 2 · AAC · stereo · 48 kHz · English" label builder) + "Output Device" submenu from `Settings.AudioDevices` + Mute + Effects (`MainWindow.xaml.cs:3441-3453`); `SubtitleMenuItems()` lists tracks + Add Subtitles + Find Online (`:3470`). **No Video tab**; video options live in the Effects panel. |
| 4 | Audio output device list | **Real** | `:3450` and `Settings.AudioDevices` (`:96`); chosen before playback to avoid libVLC clock issues (`:277-281`). |
| 5 | Queue vs Playlists | **Real** | `LibraryPanel.Section { Home, Videos, Music, Network, Playlists, History, Queue }` (`LibraryPanel.xaml.cs:58`); queue toggle on control bar (`ListBtn`), separate saved `Playlists` in `library.json`. |
| 6 | Watch sidebar with Subtitles/Audio/Video/Playback/Bookmarks tabs | **Absent** | There is an **Effects & Filters** panel with only *Audio* and *Video* tabs (`EffectsPanel.cs:46-58`). No sub-delay/size/outline sliders, no Playback tab, no Bookmarks tab in a sidebar, no "Default Preset" dropdown or "Open Advanced Settings" as in the Figma `Subtitles.png`. Subtitle appearance is only in Settings → Subtitles (applied via engine restart). `grep` for "Default Preset"/"Duration Factor" returns nothing. |
| 7 | Bookmarks & chapters | **Real** | Ctrl+B (`Hotkeys.cs:34`), bookmark list in a menu, marks on the seek bar (`MainWindow.xaml.cs:2588-2650`). Menu not tab. |
| 8 | Sleep timer | **Real** | 15/30/45/60/90 min/end-of-item with fade-out (`:2665-2690`); in a menu, not the Playback tab. |
| 9 | Per-show presets (named presets bound to folders) | **Absent** | No `presets.json`, no preset concept for subtitles/audio. Only a per-series *intro end* (`LibraryData.IntroEnds`, `Library.cs:63`) and per-track lyric offsets. |
| 10 | Subtitle timeline strip | **Absent** | No SRT/ASS parser or timeline view anywhere. |
| 11 | Add subtitles to folder w/ matching | **Real** | `DialogWindow.AddSubtitles` (`:450-531`): "To this file / To this folder", pairs files by `S01E02`/`1x02`/trailing-number tag then name prefix, shows the mapping, persists to `Library.Data.Subtitles` and re-attaches via `media.AddSlave` on every play (`MainWindow.xaml.cs:903-905`). Simpler than your ML-backed design but functionally what §11.4 asks. |
| 12 | OpenSubtitles online search | **Real** | `Subtitles.cs`: hash + name search, download next to the video. Uses a baked-in consumer API key. |
| 13 | Equalizer / compressor / spatializer / karaoke / pitch | **Real** | `Effects.cs`, `EffectsPanel.cs`, `AudioChain.cs`, args built in `Settings.EngineArgs`; verified by 3 audio checks in `tests/Checks`. 10-band EQ with presets, live slider updates without chain rebuild. |
| 14 | Settings pages incl. Advanced sections | **Real, curated** | 13 categories, ~212 options, Advanced section per page, search box (`SettingsWindow`). Not "every VLC option". |
| 15 | Onboarding | **Real, 3 steps** | Welcome → theme/accent → shortcuts (`OnboardingWindow.cs:71`). Includes the Shortcuts step your §11.4 wants. |
| 16 | Library header: breadcrumbs, back/fwd, grid/list/details, sort incl. Unwatched first | **Partial** | Breadcrumbs + back/forward + asc/desc sort by name + search (`LibraryPanel.xaml.cs:214-236`). No grid/list/details cycle, no watched-state sort. |
| 17 | Pinned items on rail | **Real** (folders only) | `Library.Data.Pinned` (`LibraryPanel.xaml.cs:97-158`). |
| 18 | Hide UI | **Real** | `ToggleMinimal` bound to Ctrl+\ (`Hotkeys.cs:20`). Not the "80 px from edge" immersive reveal; uses a timer-based hide. |
| 19 | Shortcut feedback toast with key combo | **Partial** | OSD toast with action text exists (`osd.enable`); it does not show the key combination. |
| 20 | Resume prompt above the play controls | **Real** | `ResumeBanner` (`MainWindow.xaml.cs:896`). |

### README claims, sampled

| Claim | Verdict | Evidence |
|---|---|---|
| Auto-update | **Real** | Velopack delta updates from GitHub Releases, with fallback for old Inno installs (`Updater.cs`). **Unsigned** — see §6. |
| Chromecast / "Stream to TV" | **Real but thin** | Chromecast = libVLC `RendererDiscoverer` + `SetRenderer` (`MainWindow.xaml.cs:2210-2235`), i.e. what any libVLC app gets for free; "Stream to TV/phone" = libVLC `sout=http{mux=ts}` + a landing page (`CastServer.cs`). |
| Phone remote | **Real** | `Remote.cs`: tiny TCP server on all interfaces, random 6-byte key in URL, JSON API, embedded HTML page. |
| Watch Together over internet | **Real, hosted by author** | `Party.cs` + `relay/party-relay.py`. Default server `https://party-pylon.hubcore.org` is baked into settings (`Settings.cs:479`). |
| Lyrics (TTML/LRC/LRCLIB/Spicy), 9+ lyric animations, visualizers | **Real, large** | `Lyrics.cs`, `SpicyLyrics.cs`, `LyricsView.cs` (894 lines), `Scene.cs`, `Spectrum.cs` (WASAPI process-loopback). This is where most of the code mass goes. |
| yt-dlp websites, Spotify import, YouTube-Music radio, Last.fm, Discord, AcoustID | **Real** | `YtDlp.cs` (528), `Spotify.cs`, `OtherPlayer.cs` (media-session remote for other players), `LastFm.cs`, `Discord.cs` (named-pipe RPC), `Recognize.cs`. Scope drift, see §8. |
| Convert / record / A-B clips | **Real, minimal** | `Converter.cs` + `ConvertDialog.cs` (small presets over libVLC `transcode`); not VLC's Convert/Stream wizard. |
| Radio / podcasts / UPnP | **Real** | Network section, radio-browser.info, RSS. |
| 360° video, RTX Video | **Real** | `ViewAngles.cs`; libVLC flags. |

Net: of the ~20 feature items in your spec that Pylon could plausibly cover, **about 11 are real, 4 partial, 4 absent**; the absent/partial ones are precisely the designer-intent features (watch sidebar, per-show presets, subtitle timeline, video tab in track popup) that distinguish your spec from "the Figma screenshots".

## 5. Fidelity to the Figma design

I compared Pylon's `docs/screenshots/*.png` with the Figma exports in `scratchpad/figma-zip/`.

| Screen | Verdict | Notes |
|---|---|---|
| Player shell (title bar, rail, library panel, control bar) — `music.png` vs `Player.png` | **Close** | Same layout: cone-like logo, `⋯`, sidebar toggle, folder crumb, centered title, 7-icon rail, back/forward + breadcrumb + `⋯` + pop-out, sort + search, thick seek bar with orange fill, cone volume slider, waveform/subs/settings/queue icons on the right. Differences: Pylon adds ±15 s buttons and stop; play button is a grey pill (Figma: orange pill) in the paused/playing state shown; list-view toggle missing from the library header. |
| Music view (blurred cover backdrop) | **Close** | Matches the Figma music mock (large rounded cover, caption under it, colour-bleed backdrop). |
| Effects & Filters — `fx.png` vs `Property 1=expanded*.png` | **Close** | Right panel with Audio/Video segmented tabs, collapsible Equalizer/Compressor/Spatializer cards with ON/OFF pills, orange 10-band EQ. Pylon's card visuals are very near the Figma expanded states. |
| Settings (Global Settings) — `settings.png` vs `Settings - global.png` | **Close** | Same sidebar groups (App/Media/System), same 13 pages, same Appearance/Startup/Diagnostics sections, theme segment, 9 accent swatches, "Advanced Options >" bar. Small drifts: Pylon is a lighter grey overall (Figma is nearly black), icon set (Phosphor) differs slightly from Figma's, spacing denser. The shipped screenshot even shows the updates toggle greyed out (a build-state artefact). |
| Onboarding — `onb.png` | **Close** | Theme step with preview, Light/Dark/System cards, accent row; Back/Next and dots as in Figma. Selection ring is orange vs Figma's purple focus ring on the card (`Frame 151.png`) — a deliberate recolour. |
| Subtitles / watch sidebar (`Subtitles.png`) | **Divergent / missing** | Figma shows a right-hand panel with tabs *Playback / Video / Audio / Subtitles*, Defaults + Synchronization sliders + Appearance + "Default Preset" + "Open Advanced Settings". Pylon has no such panel. |
| Right-click menu (`right-click menu.png`) | **Not verified visually** (no Pylon screenshot); code builds styled `ContextMenu`s with icons and shortcut hints (`MainWindow.xaml.cs:3365+`), so likely close. |
| Light theme | **Close** (`light.png`) and extended with OLED/Midnight/Nord/Sepia (beyond Figma). |

Fonts: the theme requests `Inter, Segoe UI` (`Theme.xaml:5`) but **no font file is bundled** (`Assets/` has Icons, FileIcons, pylon.ico only) — on machines without Inter installed, the UI silently falls back to Segoe UI and loses fidelity. (Your fork bundles the redesign font; that is already better.)

Overall fidelity of *what it ships*: high (4-4.5/5). Fidelity of the *designer-intent features*: low.

## 6. Security and privacy

**Network contacts** (README privacy policy matches the code I sampled): GitHub (updates, yt-dlp, ffmpeg, Icaros installer, fpcalc), LRCLIB, ListenBrainz, Spicy Lyrics, Deezer/Spotify APIs, iTunes, AcoustID/Cover Art Archive, OpenSubtitles, Last.fm, radio-browser.info, YouTube/YouTube Music (unofficial `youtubei` endpoints with hardcoded request context, `YtDlp.cs:339`), Discord (local IPC), and the **author's relay**. No telemetry/analytics code found; README states none. Lyrics lookup is **on by default** and sends artist/title/album/length to three third parties.

**Relay (`relay/party-relay.py`)** — what it is: a ~230-line asyncio HTTP server (stdlib only) that lets a host's Pylon upload an endless MPEG-TS stream (`POST /r/<room>/host/stream?key=K`) and JSON state, and lets guests `GET /r/<room>/stream.ts` and send `toggle`/`seek` commands. **Yes, it runs a server** — but only on the operator's VPS, not on user machines; the app is a client of it. Auth model:
- Host auth = a 96-bit random key the host picks; "the first key a room is created with owns it" (docstring). A 40-bit random room id (`Party.cs:~37`) is the only secret for guests. There is no per-guest auth: anyone who learns the room URL can pause/seek everyone and pull the stream.
- `Access-Control-Allow-Origin: *`, no rate limiting beyond `MAX_ROOMS=200` and a per-guest backlog cap, no TLS in the script (expects nginx/Caddy in front). Room squatting by guessing active room ids is impractical (40 bits) but trivially DoS-able.
- **Privacy**: the default relay is hard-coded to `party-pylon.hubcore.org` (`Settings.cs:479`), run by the author on a personal VPS that also fronts a VPN (see `relay/deploy.ps1` header: "the VPN's front door"). A host who uses Watch Together sends their **unencrypted-at-rest MPEG-TS copy of what they play** to that server; the operator can see it. It is configurable, but the default is a third-party server. `deploy.ps1` also commits the author's server IP and describes the Cloudflare/certbot token location.

**Local servers.** Phone Remote and Stream-to-TV bind `IPAddress.Any` on random ports with plain HTTP (`Remote.cs:27`, `CastServer.cs:38`). The remote is guarded by a 48-bit key in the URL path; the cast stream (`http://host:port/stream.ts`) has **no auth at all** (anyone on the LAN who finds the port can read it). Fine for a home LAN, weak for shared/public Wi-Fi.

**Auto-update integrity.** Velopack checks package hashes from `releases.win.json` that live on the *same* GitHub release as the packages, i.e. integrity but not authenticity. The README promises Authenticode signing via SignPath ("Only binaries built by GitHub Actions ... are signed"), but **neither `release.yml`, `build.ps1` nor the installer scripts contain any signing step** (`grep -i signpath|signtool|signParams` finds nothing). A compromise of the single maintainer's GitHub account = code execution on every installed copy. The legacy Inno-bridge path downloads and silently runs `…-setup-win-x64.exe` after only a `StartsWith("https://github.com/")` check (`Updater.cs:84-86, 160`).

**yt-dlp / ffmpeg / Icaros / fpcalc handling.** All are downloaded on demand over HTTPS from GitHub "latest" URLs into `%LocalAppData%\Pylon\tools` and executed with **no checksum or signature verification** (`YtDlp.cs:176`, `Ffmpeg.cs:30`, `Recognize.cs:96`, `FileTypesDialog.cs:123-126` — the Icaros installer is started as-is). yt-dlp then self-updates daily with `-U` in the background (`YtDlp.cs:209`). Each download is user-triggered (consent prompt), which is good; the trust model is "GitHub is not compromised". Optional `--cookies-from-browser` is off by default and documented.

**Secrets in the repo** (all intended to ship in a desktop client, but all committed in plain text and un-rotatable without a release): Last.fm API key **and shared secret** (`LastFm.cs:16`), OpenSubtitles consumer key (`Subtitles.cs:16`), Spicy Lyrics built-in key (`SpicyLyrics.cs:26`), AcoustID key (`Recognize.cs:16`), Discord client id, Spotify client id (public PKCE client). No private credentials (passwords, tokens) found. Users' own secrets (web-interface password, proxy password, Spotify token) are stored unencrypted on disk.

**Overall:** no malware-like behaviour, no hidden telemetry, honest privacy page; but unsigned update channel, unverified binary downloads, an unauthenticated LAN stream, and a default third-party relay are real weaknesses for a distributed product.

## 7. Licensing / compliance

- **GPL-3.0** `LICENSE` (full text, 35 KB); `Pylon.csproj` copyright "GPL-3.0-or-later". Third-party notices (`THIRD-PARTY-NOTICES.md`) list libVLC (LGPL-2.1+), LibVLCSharp, SharpVectors, Phosphor (MIT), QRCoder (MIT), yt-dlp (Unlicense). The notices and licence are copied into every build output (`Pylon.csproj:39-40`). libVLC is shipped as replaceable DLLs, which satisfies the LGPL.
- Omissions/risks: **Velopack** and Inno Setup are not listed in the notices; **Inter** is referenced but not shipped (so no font licence issue, but also a fidelity issue); the **ffmpeg GPL build** is downloaded rather than shipped (OK); the libVLC plugins include GPL modules, so the combined distribution being GPL is correct.
- **Figma design licence**: the app is a derivative of Juxtopposed's community file; the README credits it prominently and links the file, but I found **no statement of the Figma file's own licence** and no written permission. Your project has the same exposure (see `docs/redesign/branding.md`).
- **VLC trademarks**: `README.md` ends with a non-affiliation disclaimer. The app logo is its own "P-shaped pylon" (`docs/brand/README.md`), not the cone; the Figma title-bar icon resembles the cone but the shipped one is Pylon's. Cleaner than a fork that must remove VLC branding. The README says "redesigned VLC interface" in the product description and "Play in VLC" appears on the cast page (`vlc://` link) — descriptive use.
- Music-service scope has **ToS/legal risk** the project does not discuss: unofficial YouTube Music API calls (`YtDlp.cs:339`) and playing Spotify playlists via YouTube sources.

## 8. Maintainability and bus factor

- **One author** (MeowKusTrue). 33 commits between 2026-10-14 16:30 and 2026-10-16 13:00 (~44 hours), each commit one released version (e.g. `8e06dea` adds ~1,067 lines to 17 files; the initial commit is 7,271 lines). All 33 are co-authored by Claude Opus 5.5. No branches, PR history, issue links, tags beyond versions, `CONTRIBUTING`, `CODEOWNERS` or architecture doc in the tree. Release cadence of up to 3 versions/day is not a maintainable pace for a reviewer.
- **Changelog honesty** is a strength: `CHANGELOG.md` records fixes with measurements; `TODO.md` (Russian) lists unfixed bugs and rejected approaches (e.g. WASAPI "решено: остаёмся на DirectSound", with SNR numbers). Docs are in Russian first, English second, with the TODO and relay deploy notes Russian-only: another barrier for you.
- **Working in it**: to contribute you would navigate a 4 k-line code-behind class, no tests for UI, strings as English keys, statics everywhere. The author is responsive in the sense of shipping fast, but acceptance of a 5-page restructure PR (e.g. adding a watch sidebar, which fundamentally touches `MainWindow` layout) is untested; with a god class, merge conflicts with a fast-moving single author are almost certain.
- **Windows/libVLC 3 only**; the author documents libVLC 3 limitations as dead ends (no soxr, no exclusive WASAPI) and the TODO suggests moving to libmpv — a potential future rewrite.
- **Scope drift**: later versions (1.4-1.9) are mostly music-streaming/lyrics/visualizer/Spotify/Discord/radio features (~half the code mass), moving away from "redesign VLC". The project is becoming a Spotify-style music player that happens to play video.

## 9. Gap vs. your goal (VLC Reborn)

**What you would lose by adopting Pylon instead of your VLC 4 fork:**
- The **VLC 4 engine** (libVLC 4 / new input, new video outputs, new media library, preparser, clock model). Pylon is libVLC **3.0.24** through LibVLCSharp, and its own TODO documents engine-level dead ends it cannot fix (resampler, WASAPI).
- **Full VLC feature set**: Pylon has no Lua extensions/interfaces (explicitly disabled: `Settings.cs:769`), no VLM, no full convert/stream wizard (only preset-based `Converter`), no media information/codec dialogs, no capture-device UI, no advanced preferences tree (only ~212 curated options + a raw command-line row), no playlist formats/EPG/messages window, no skins, no `vlc://` CLI parity, no Qt/QML plugin architecture, no cross-platform path (Windows-only WPF).
- **The ML-backed library** (VLC 4's media library with play counts, bookmarks, thumbnails, watched state): Pylon uses JSON files and folder scans.
- **Upstream security fixes** — you would inherit libVLC via NuGet instead (arguably easier) but lose control of the plugin set.
- Your **spec's architecture** (isolation from upstream, monthly merge discipline, `upstream-touchpoints.md`) has no analogue.

**What you would gain:**
- A running, polished Windows app today: the Figma look nearly pixel-matched, a nice spring-motion system, themes, 2 languages, a working updater/installer pipeline, waveform seek bar, seek thumbnails, EQ/effects with live sliders, lyrics, a phone remote, Add-subtitles-to-folder matching, onboarding, a sleep timer and bookmarks.
- A much smaller code base (17 k lines vs. VLC's ~1 M), fast iteration (no C++/Qt/QML build), and ready-made solutions to libVLC-3 gotchas that are still relevant as reference.
- But you **would not gain** the designer-intent features that are the point of §11 (watch sidebar, per-show presets, subtitle timeline, video tab) — you would build them yourself, in a single-author WPF god class.

**Reusable ideas for your fork (no code copy needed; check GPL compat — both are GPL, so code reuse is legally possible):**
1. Waveform pipeline (`Waveform.cs`): `sout=#transcode{acodec=s16l,channels=1,samplerate=8000}:std{access=file,mux=wav}` + 400-bin RMS reduction + hash-keyed cache; also derives loudness for replay gain. Maps directly to your R4 waveform plan.
2. Seek thumbnails via a second silent player with video callbacks and a throttled bucket cache (`SeekPreviewer.cs`), including the "libVLC doesn't redraw after seek while paused" workaround.
3. Add-subtitles-to-folder episode matching regex (`DialogWindow.xaml.cs:517-529`).
4. Friendly audio track label builder (`AudioTrackName`, `MainWindow.xaml.cs:3411-3437`).
5. The Figma-derived settings schema texts/layout (`Settings.cs:359+`) as a cross-check for your `settings-map.md`.
6. The honest "disabled with reason" pattern for options libVLC can't do.
7. The ErrorLog safety net pattern and atomic-write persistence.

---

## Verdict

| Dimension | Score (1-5) | One-line justification |
|---|---|---|
| Architecture | **2** | Clean libVLC threading and satellite modules, but a 3,962-line code-behind god class, static state, no MVVM, no media DB. |
| Code quality | **3.5** | Typed catches, atomic saves, global safety net, "why" comments and measurements; marred by duplication, hardcoded brushes, magic numbers, one visible stub, and plain-text secrets. |
| Tests | **2** | ~30 console checks (lyrics, strings, real libVLC audio) run in CI, but no UI/integration coverage, no framework, nothing for updater, servers or library. |
| Feature completeness | **3** | Broad and mostly real (~11/20 of your spec's items real), with huge music extras; the §11 differentiators (watch sidebar, presets, timeline, video tab) and all of VLC's depth are missing. |
| Figma fidelity | **4** | Very close on shell, music view, effects panel, settings, onboarding, themes; missing the Subtitles/Playback sidebar and the Inter font is not bundled. |
| Security | **2.5** | No telemetry and an honest privacy page, but unsigned updates despite claiming signing, unverified downloaded executables, unauthenticated LAN stream, default third-party relay, committed API secrets. |
| Maintainability | **2** | One author, 33 AI-co-authored release-per-commit changes in ~44 hours, Russian-first docs, god class, pace that outruns review; high bus-factor risk. |

### Recommendation

**(C) Continue the VLC fork, optionally borrowing ideas.** Not (A), and (B) only in a very narrow sense (see below).

Main reasons:
1. **Wrong foundation for your stated goal.** You want VLC 4 with every VLC feature, restyled. Pylon is libVLC 3 with a curated subset and explicitly drops Lua extensions, VLM, convert/stream, the advanced prefs tree, capture and the VLC 4 library. Adopting it means abandoning the product definition in spec §1.
2. **It does not implement the part of the design you care most about.** Pylon reproduces the Figma screenshots well (that part you already have in progress), but not the designer-intent features: no watch sidebar tabs, per-show presets, subtitle timeline, or video tab. You would still have to build all of §11, inside a monolithic window class by a single author who ships daily.
3. **Maintainability and trust risk.** Single maintainer, 44-hour history, AI-co-authored release-per-commit, no review process, an update channel that promises signing but does not sign, and downloaded executables with no verification. Contributing upstream would mean racing a fast-moving author in a 4 k-line file.
4. **Scope has drifted** toward music-streaming features (Spotify/YouTube Music/Discord/Last.fm/visualizers) that are off-spec and carry ToS exposure.
5. **The useful value is portable.** Waveform extraction, seek thumbnails, subtitle-to-folder episode matching, audio track labels and the settings text/layout cross-check can be reimplemented in your Qt/QML stack from the descriptions above in a few days; there is no need to inherit the rest.

When (B) makes sense: only if you decided to drop VLC 4/Qt and target a Windows-only libVLC-3 product quickly; then forking (not contributing) is the right move because merge-ability with the author's pace and god class is poor.

Suggested follow-ups for your plan: (a) add a "reference: Pylon" note to R4 for the waveform and seek-thumbnail tasks; (b) check the licence of the Figma community file before wide distribution (affects both projects); (c) consider bundling Inter (already done in your fork) as a differentiator in visual fidelity.
