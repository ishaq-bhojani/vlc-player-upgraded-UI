# Vireo

**Vireo** is a media player for Windows 10 and 11 with a redesigned interface, built on
[VLC media player](https://www.videolan.org/vlc/).

It keeps what makes VLC great, the engine that plays almost anything, and gives it a new
look: a library with a clickable address bar, a player that gets out of the way, a clean
settings window and a first-run introduction.

Vireo is an independent project. It is **not affiliated with or endorsed by VideoLAN**. The
playback engine, the codecs and the plugins are VLC's.

> **Status:** early test builds. Release candidates are on the
> [Releases page](https://github.com/ishaq-bhojani/vlc-player-upgraded-UI/releases).

## Features

- A library for videos, music and folders: grid, list and details views, sorting
  (including *Unwatched first*), search, grouping, and back and forward navigation.
- A home page with *Continue Watching*, *Listen Again* and your frequent folders.
- A player with a thick seek bar, subtitle and audio track pop-ups, a queue panel, a
  waveform for music, and lyrics.
- Fullscreen bars that stay out of the way, **Hide UI** (Ctrl+H), and a toast that names
  each keyboard shortcut you press.
- Settings in plain language, with themes and accent colours; the full VLC preferences
  are still available under *Advanced*.
- Plays what VLC plays. Vireo can be installed next to VLC: it has its own folder, its own
  settings (`%APPDATA%\vireo`) and its own update channel, and never touches VLC's.

## Install

Download the latest build from the
[Releases page](https://github.com/ishaq-bhojani/vlc-player-upgraded-UI/releases):

- `vireo-<version>-win64.exe`: the installer.
- `vireo-<version>-win64-portable.zip`: no installation; settings stay in the folder.

Builds are not code-signed yet, so Windows SmartScreen may warn you ("More info", then
"Run anyway"). To check a download, compare it with `SHA256SUMS` from the same release.

## Build from source

Vireo is cross-compiled in VideoLAN's Docker image, on Windows with Docker Desktop and
Git Bash:

```bash
bash extras/redesign/dev-build.sh              # builds build-win64/win64-meson/vlc-win64/vireo.exe
bash extras/redesign/dev-build.sh --installer  # also the installer
bash extras/redesign/linux-tests.sh            # the Qt and QML tests
```

See [docs/redesign/building.md](docs/redesign/building.md) and
[docs/redesign/testing.md](docs/redesign/testing.md). The repository is a fork of VLC:
Vireo's code lives in `modules/gui/qt/redesign/`, and its few changes to VLC's own files are
listed in [docs/redesign/upstream-touchpoints.md](docs/redesign/upstream-touchpoints.md).

## Report a problem

Please use the [issue tracker of this project](https://github.com/ishaq-bhojani/vlc-player-upgraded-UI/issues),
not VideoLAN's: they do not support Vireo.

## License and credits

Vireo is released under the **GNU GPL, version 2 or later** ([COPYING](COPYING)), like VLC.
libVLC and libvlccore are under the LGPL, version 2.1 or later ([COPYING.LIB](COPYING.LIB)).

Vireo exists thanks to the [VideoLAN](https://www.videolan.org/) project and the many
volunteers who build VLC media player ([AUTHORS](AUTHORS), [THANKS](THANKS)). "VLC" and
"VideoLAN" are trademarks of their owners. The interface follows the Figma community file
*VLC Redesign*; further credits are in
[docs/redesign/THIRD-PARTY.md](docs/redesign/THIRD-PARTY.md).
