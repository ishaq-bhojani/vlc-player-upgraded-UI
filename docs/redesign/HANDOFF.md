# Vireo — handoff (2026-10-23)

Where the redesign fork stands, written when the work moved to another machine.
Branch: `redesign/main` (pushed to `origin`, github.com/ishaq-bhojani/vlc-player-upgraded-UI).
Plan: `docs/superpowers/plans/2026-10-16-vlc-redesign.md`. Spec:
`docs/superpowers/specs/2026-10-16-vlc-redesign-design.md`.

## The project in one paragraph

A distributed fork of VLC 4.0's Qt/QML interface, redesigned after the Figma community
file "VLC Redesign (Community)". Windows 10/11 only, solo and part-time. The product is
now called **Vireo** ("built on VLC media player", not affiliated with VideoLAN), ships
as `vireo.exe` with its own icon (concept "1 Concave play", orange `#D37918` on
`#1B1B1B`), its own `%APPDATA%\vireo` profile, its own registry names and installer
identity, and its own update channel signed with the owner's key. New code lives in the
`VLC.Redesign` module (`modules/gui/qt/redesign/`); upstream edits stay small and are
logged in `docs/redesign/upstream-touchpoints.md`. `qt-redesign=false` still gives the
stock VLC interface.

## How the work is run

- Subagent-driven development: one implementer per task, then a task review, fix
  rounds, a scoped re-review, and a whole-branch review at the end. Sonnet/Haiku
  subagents only.
- Commits are local and made with a temporary git index, then `git reset -q -- <paths>`,
  so concurrent agents never commit each other's staged files.
- Gates: `bash extras/redesign/linux-tests.sh` (comment lint + Qt tests in Docker),
  `bash extras/redesign/qml-smoke.sh` (type-load of every `VLC.Redesign` file),
  `bash extras/redesign/dev-build.sh [--tests] [--installer]` (win64 build in Docker).
  See `docs/redesign/building.md` and `docs/redesign/testing.md`.
- Never launch the app against the real profile. Owner previews are copies of
  `build-win64/win64-meson/vlc-win64` with an empty `portable` folder next to `vireo.exe`.
- Pushing, signing and anything with credentials are the owner's decisions.

## Done (plan tasks)

1, 1b, 1c, 1d, 2, 3, 4–13, 13b (rebrand to Vireo), 14 (update channel), 16–25, 25b, 29–34,
34b, 34c, 35 (onboarding), 36, 37, 46, 47, 52, 56, 57, and the polish tasks 21c–21h.

Latest work, all reviewed:

- **13b, rebrand.** Vireo name, icon, exe, manifest, mutex/IPC, About text; NSIS and MSI
  share no registry key, ProgID, GUID or folder with stock VLC; Vireo's own README and
  release notes in the installer (VLC credits kept as `VLC-AUTHORS.txt` /
  `VLC-THANKS.txt`); installer refuses VLC's folder; release version 0.1.0 used for
  the installer name and upgrade checks; the NSIS installer now builds in the image
  (`dev-build.sh --installer`). Installer side panel: fixed BGR colour bug (the mark was
  blue) and added sharp panels for 100–200% scaling chosen at runtime
  (`NSIS/helpers/vireo_panels.nsh`).
- **35, onboarding.** Replaces VLC's first-run wizard in redesign mode: theme cards
  (desktop-window miniatures, System/Light/Dark), accent swatches applied live, essential
  shortcuts, privacy, media folders. The Modern/Classic layout chooser is hidden in
  Advanced preferences, and stale `qt-titlebar`/`qt-menubar` values no longer affect
  Vireo. The accent colour no longer needs a restart.
- **21h, QWidgets dialogs.** `RedesignWidgetStyle` (Fusion proxy) for the stock dialogs
  reachable from Settings → Advanced…: readable buttons in every state, visible
  checkboxes, radios and field borders, accent default button, keyboard-only focus
  rings, a cleaned-up Media Library folder table.

## State at handoff

- Last commit: `5bfbab4` (build: reserve the installer panels for solid compression).
- Final installer built from that commit: `build-win64/installer-final/vireo-0.1.0-win64.exe`
  (not in git; rebuild with `dev-build.sh --installer` on the new machine).
- **Not yet checked on screen:** the new installer and the onboarding window. On the
  old machine both today's build and an older preview hung before showing a window while
  an installed Vireo had been running since the day before, through sleep. Likely
  environmental, but unconfirmed. First thing to do: with no other Vireo running,
  install the new build (or run a portable copy) and check the installer pages at 150%,
  the onboarding theme cards, Settings → Advanced… dialogs, and Space play/pause on a
  real video. If it still hangs, debug it (log stops right after the version lines).
- Win64 native test run: 9 Qt tests fail on mingw (effects_controller, measured_gain,
  ml_recent_audio_model, redesign_option, redesign_widget_palette, settings_model,
  subtitle_attacher, tool_manager, waveform); never baselined against pre-rebrand. The
  Linux run (54/54) is the gate.

## Next tasks, in order

1. Done 2026-10-23 on the new machine: the portable preview opened in 3 s (onboarding
   shown, no hang); the installer pages at 150% (sharp orange panel) and the refusal of
   VLC's folder were checked on screen. Not yet checked: the rest of the onboarding,
   Settings → Advanced… dialogs, Space play/pause on a real video, the finish page.
2. Done 2026-10-23: the parked items (`redesign_user_dir` must not end with `.` or a
   space, `package.mak`, MSI version note, silent-install guard). The silent guard is
   compiled but was not run: it only applies when `Software\Vireo\InstallDir` names a
   folder with `vlc.exe` (`.onInit` overwrites `/D=`).
3. Done 2026-10-28: Task 26 (library header; it reuses each page's own sort and search,
   owner decision; Ctrl+F stays "open a folder"). Checked on screen: Videos, grouping,
   group crumbs, back / forward, view modes, network folder crumbs, the panel beside a
   video. Not checked on screen: the search box filtering. Next: 27 (right-click menu +
   Hide UI, gives the onboarding a real Hide UI key), 28 (shortcut toast).
4. Task 15 (release workflow, smoke checklist), then release candidate 1 to testers,
   unsigned.
5. Task 53 (web playback via yt-dlp), 54 (downloads), R4 38–45 and 55, R5 48, R6 49–51.
6. Whole-branch review, then finish the branch.

## Owner items (open)

- Formal trademark search for "Vireo" (WIPO, class 9) before release.
- Figma designer credit and licence check (Figma Community default is CC BY 4.0).
- Review the 52 installer translations (they were changed mechanically).
- Test both installers on a clean PC and on one with stock VLC; MSI needs WiX
  (not in the build image).
- Back up the update-signing private key offline (key ID EFD2A5C7EBD62BCD; uid
  still says "VLC Reborn Updates" — keep or re-issue). GitHub secrets
  `UPDATE_GPG_KEY` and `UPDATE_GPG_PASSPHRASE` are set on the repo. Never move the
  private key through the repo or a chat.
- Code signing later (rc1 goes out unsigned).
- Windows High Contrast check of the QWidgets dialogs.
- Optional: rename the GitHub repo; decide on the `vlc-reborn-*` Docker volume names.

## Setting up the new machine

1. Clone the repo and check out `redesign/main`; add `upstream` =
   https://github.com/videolan/vlc.git.
2. Install Docker Desktop and Git for Windows (Git Bash runs the scripts); the first
   `dev-build.sh` and `linux-tests.sh` runs create the build volumes and take hours
   (full contrib + build).
3. Git Bash rewrites `/build`-style paths in `docker run` arguments; scripts handle it,
   but for manual `docker run ... tar -C /build/...` commands set `MSYS_NO_PATHCONV=1`.
4. Not in git, recreate or copy by hand if wanted: the SDD ledger, briefs and reports
   (`.superpowers/sdd/2026-10-16-vlc-redesign/` on the old machine — copy the folder
   over to keep the full per-task history), `build-win64/` previews, the update-signing
   private key (offline copy only).
