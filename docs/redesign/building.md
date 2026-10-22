# Building Vireo on Windows

Vireo is Windows-only. It is built on Windows by cross-compiling (mingw-w64)
inside VideoLAN's official Debian container, and the result is run natively on
the Windows host.

## Prerequisites

- Windows 10/11 with **Docker Desktop** using the **WSL2 backend**.
- Git Bash (or a WSL shell) to run the scripts.
- Docker resources: 8 GB RAM or more and as many cores as you can spare.
- About 25 GB of free disk for the Docker volume plus the copied output.
- Network access on the first build. These are downloaded once:
  - the container image `registry.videolan.org/vlc-debian-win64-posix:20260611225331`
    (a few GB);
  - VLC's prebuilt contribs (~650 MB) and the small host tools that
    `extras/tools/bootstrap` fetches.

Line endings: the source tree is bind-mounted into a Linux container, so shell
scripts and patches must be LF on disk. `.gitattributes` enforces that even with
`core.autocrlf=true`. If a checkout predates it, run
`git rm --cached -r -q . && git reset --hard` once (`dev-build.sh` detects this
and tells you).

## Full build

```bash
bash extras/redesign/dev-build.sh            # debugoptimized build
bash extras/redesign/dev-build.sh --tests    # ... and build + run the Qt tests
bash extras/redesign/dev-build.sh --release  # release build, separate volume (untested, see below)
```

What it does:

1. Creates the Docker named volume `vlc-reborn-build` (`vlc-reborn-build-release`
   for `--release`), mounted at `/build`. The build tree lives there because a
   build on a bind-mounted NTFS directory is extremely slow. The repository is
   bind-mounted at `/vlc`.
2. Runs `extras/redesign/container-build.sh` in the container, which calls
   `/vlc/extras/package/win32/build.sh -m -p -a x86_64` (`-r` for release) from
   `/build`, then `meson install`.
3. Copies the install tree to `build-win64/win64-meson/vlc-win64/` on the host
   (git-ignored).

Result: `build-win64/win64-meson/vlc-win64/vireo.exe`; double-click it or run it
from a terminal. It uses your normal VLC profile (`%APPDATA%\vlc`).

Timing on a 12-core / 31 GB machine: about 11 minutes for a build from an empty
volume (image already pulled; includes the ~650 MB contribs download), about 1.5
minutes for a re-run with nothing changed. The volume keeps the contribs, tools and object files, so
re-runs are incremental. To start from scratch: `docker volume rm vlc-reborn-build`.

### Workarounds the script applies

The image and the prebuilt contribs are what upstream CI uses, but upstream CI
does not build win64 with meson in this image, so `container-build.sh` works
around a few things without touching upstream code (each is commented in the
script):

- **Prebuilt contribs URL**: `build.sh -p` falls back to a `-latest` tarball that
  404s. The script uses the per-commit tarball that upstream CI publishes
  (`artifacts.videolan.org/vlc/win64/...`), computed with
  `extras/ci/get-contrib-sha.sh`, else a pinned known-good commit. Override with
  `VLC_PREBUILT_CONTRIBS_URL`.
- **`wine` shim**: the image's wine is 32-bit only, so meson's cross "sanity
  check" (which runs a win64 exe through `exe_wrapper`) can never pass; the shim
  lets that one check succeed and forwards everything else to wine.
- **Qt private headers**: the image's native Qt tools are 6.8.0 but the contribs
  ship 6.8.3, so meson looks for private headers in `.../6.8.0/...` and
  `qt.cpp` fails to compile. The 6.8.3 include directories are added via
  `CPPFLAGS`.
- **Link flags**: `--allow-multiple-definition` (duplicate `libssp` in the FLAC
  plugin) and `-static-libstdc++` (plugins are loaded with
  `LOAD_LIBRARY_SEARCH_SYSTEM32`, so `libstdc++-6.dll` cannot be found next to
  `vireo.exe`).
- `-Dnsis=disabled` (the NSIS helper does not link for x86_64) and the MinGW
  runtime DLLs (`libgcc_s_seh-1`, `libssp-0`, `libwinpthread-1`) are copied into
  `vlc-win64/`, since `meson install` does not.

`--release` passes `build.sh -r`, which also asks for an installer package
(`meson dist`, NSIS, MSI). That path has not been exercised here and is expected
to need more work; use the default debugoptimized build for development.

## Fork options and cached values

The fork's meson options (`redesign_product_name`, `redesign_release_version`,
`redesign_update_url`, `redesign_build_number`; defaults in `meson_options.txt`) are
stored by meson in the build directory, so a build directory that was configured
before a default changed keeps the old value.

- `dev-build.sh` (win64): `build.sh` deletes `meson-private` and runs `meson setup`
  again on every run, so the options always start from the defaults of
  `meson_options.txt`. Pass a different value through `MCONFIGFLAGS`
  (e.g. `-Dredesign_build_number=3`), never by editing the volume.
- `linux-tests.sh` and `qml-smoke.sh` (native Linux, `linux-container-common.sh`):
  the build directory is configured once and reused, so before every build the
  script compares each cached `redesign_*` option with the default declared in
  `meson_options.txt` (it parses that file, so there is one source) and runs
  `meson configure -D...` for the ones that differ; the line `==> meson configure
  (cached fork options differ ...)` is printed when it did. These runners never set
  a `redesign_*` option themselves; to try a non-default value in the Linux tree run
  `meson configure` by hand and expect the next run to put the default back.
- The Docker volumes keep their old names (`vlc-reborn-build`,
  `vlc-reborn-linux-build-<hash>`): renaming them would throw away the 25 GB of
  contribs and objects they hold. They are internal and never shipped.

## Qt-plugin-only rebuild (fast iteration)

UI work only touches `modules/gui/qt`, so rebuilding just the Qt plugin takes
seconds to a couple of minutes instead of a full build. It reuses the build volume
and writes the result straight into the host install tree through the `/vlc`
bind mount:

```bash
export MSYS_NO_PATHCONV=1    # Git Bash: stop it rewriting /vlc and /build
IMAGE=registry.videolan.org/vlc-debian-win64-posix:20260611225331

docker run --rm -v vlc-reborn-build:/build -v "$(pwd -W)":/vlc -w /build "$IMAGE" bash -c '
    export PATH=/build/extras/tools/build/bin:$PATH   # the meson that configured the tree
    meson compile -C /build/win64-meson qt_plugin
    x86_64-w64-mingw32-strip -o /vlc/build-win64/win64-meson/vlc-win64/plugins/gui/libqt_plugin.dll \
        /build/win64-meson/modules/libqt_plugin.dll'
```

That is `meson compile -C build-win64/win64-meson qt_plugin` followed by copying
`libqt_plugin.dll` into `vlc-win64/plugins/gui/`. Run `vireo.exe` again to pick it up.
The container's build tree is the one in the Docker volume, not
`build-win64/win64-meson/`, which only holds the copied output.

## Running the tests

```bash
bash extras/redesign/dev-build.sh --tests   # build (incl. test executables) + run
bash extras/redesign/run-tests.sh           # run only, against the last build
bash extras/redesign/run-tests.sh thread    # only tests whose name contains "thread"
```

The win64 binaries cannot run inside the Linux container, so
`dev-build.sh --tests` builds the test executables there (the meson `qt` suite:
`test_qt_*`, `base_model_test`) and copies them to `build-win64/win64-meson/tests/`.
`run-tests.sh` runs them natively on Windows with `QT_QPA_PLATFORM=offscreen`,
`vlc-win64` on `PATH` (for `libvlc.dll` / `libvlccore.dll`) and `VLC_PLUGIN_PATH`
set, and writes each Qt Test report to a temp file (stdout of the static Qt test
executables is not captured on Windows). It also runs
`qml_test.exe -input <file>.qml` for each `qml_tests` entry of
`modules/gui/qt/meson.build` (upstream) and `modules/gui/qt/redesign/meson.build`
(redesign; its `../tests/x.qml` paths are resolved relative to that file) once a
`qml_test.exe` exists, and fails if `qml_test.exe` exists but no entry is found.
`RUN_TESTS_LIST_QML=1 bash extras/redesign/run-tests.sh` only lists the
discovered QML tests.

It prints a final `N passed, M failed` line and exits non-zero on any failure.

### Tests that are excluded

Listed with reasons in the `EXCLUDED` array of `run-tests.sh` (upstream code is
not patched):

| Test | Reason |
| --- | --- |
| `test_qt_navigation_model` | Does not link: its meson entry has no `link_args`, so with the static win64 Qt the zlib/pcre2 symbols are missing. |
| `test_qt_dialog_model`, `test_qt_ml_model`, `test_qt_renderer_manager` | They register fake modules through `vlc_static_modules`, which the core only loads on ELF targets (`src/modules/bank.c`), so the test environment cannot start on Windows. They are still compiled, which makes them a build check. |
| `tst_FSM` (`qml_test`) | The win64 Qt contrib does not ship `Qt6QuickTest`, so meson never defines the `qml_test` target. |
