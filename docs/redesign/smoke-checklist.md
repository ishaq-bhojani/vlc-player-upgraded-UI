# Vireo release smoke checklist

Run it on every release candidate before its tag without a suffix is pushed (spec §8). Copy
it into the release's tracking issue and tick the boxes there; a failed box blocks the
release until it is fixed or accepted by the owner (write down why).

Release: `v_____` &nbsp; Build number (4.0.0.N): `____` &nbsp; Tester: `________` &nbsp; Date: `__________`

## 0. Before testing

- [ ] The GitHub Release has the assets: `vireo-<version>-win64.exe` and `.exe.asc`, `vireo-<version>-win64-portable.zip`, `status-win-x64` and `status-win-x64.asc`, `SHA256SUMS`.
- [ ] `sha256sum -c SHA256SUMS` passes on the downloaded files.
- [ ] A release candidate (`-rc`) is marked pre-release; a final release is marked latest.

## 1. Machines

Test on both. Use a clean user profile (or `portable` mode) unless a step says otherwise.

- [ ] Windows 10 (22H2)
- [ ] Windows 11 (24H2 or later)

## 2. Install, update, uninstall

- [ ] The installer starts; SmartScreen may warn (rc1 is not Authenticode-signed: "More info" → "Run anyway").
- [ ] The installer pages are sharp at 100 %, 150 % and 200 % (welcome panel, header icon).
- [ ] Installing into a stock VLC folder is refused with a message (choose `C:\Program Files\VideoLAN\VLC` on the folder page).
- [ ] With stock VLC installed: both players keep their own folder, Start menu entries, file associations and settings (`%APPDATA%\vlc` and `%APPDATA%\vireo`).
- [ ] The portable zip runs from any folder and writes nothing to `%APPDATA%\vireo`.
- [ ] Help → Check for updates on the previous release offers this one (final releases only: a pre-release is not "latest"), the log says `Status file authenticated`, and the download is verified.
- [ ] The uninstaller removes Vireo; "Delete preferences and cache" removes `%APPDATA%\vireo` only.

## 3. Display scaling

At each scaling, open the library, play a video, open Settings and a dialog.

- [ ] 100 %
- [ ] 150 %
- [ ] 200 %

## 4. Themes

- [ ] Light
- [ ] Dark
- [ ] Windows High Contrast (the QML shell and the QWidgets dialogs of Settings → Advanced…: text, borders, focus rings visible)

## 5. Keyboard only

No mouse for the whole section.

- [ ] Tab reaches the rail, the library header, the page, the control bar; the focus ring is always visible.
- [ ] Space plays and pauses; the shortcut toast names the action.
- [ ] Ctrl+H hides the bars while a video plays; Esc and Ctrl+H bring them back.
- [ ] Ctrl+P opens Settings; Esc closes it.
- [ ] The onboarding (fresh profile) can be finished with the keyboard.

## 6. Compositors

Set with `--qt-compositor=<name>` (or Settings → Advanced…, Interface → Qt).

- [ ] `dcomp` (the default on Windows 10/11): video, transparency of the window, Hide UI.
- [ ] `win7`: the same.

## 7. Media

- [ ] A local video (also: seek, subtitles, audio track, fullscreen and back).
- [ ] Music (the music view with artwork, the queue).
- [ ] A network stream (Menu → Network stream…, an `https` URL).
- [ ] The library: add a folder, Videos (group, sort, Unwatched first, view modes), the panel beside a playing video, Browse folders.

## 8. Stock interface fallback

- [ ] `vireo.exe --no-qt-redesign` (or `qt-redesign` off in Advanced preferences) shows the stock VLC interface and plays a video.

## 9. Design

- [ ] Home, Videos, the player, Settings and the onboarding compared side by side with the Figma exports (`docs/redesign/figma-svg`); differences are filed or accepted.

## Result

- [ ] Every box above is ticked, or the failure is filed and accepted by the owner.
- [ ] Tag the final release (no suffix) on the same commit as the tested candidate.
