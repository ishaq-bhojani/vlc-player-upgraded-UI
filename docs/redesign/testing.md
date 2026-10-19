# Testing VLC Reborn

Three scripts, three jobs:

| You want to... | Use |
| --- | --- |
| Run unit tests / QML tests (every plan step that says "Run `meson test ...`") | `bash extras/redesign/linux-tests.sh [TEST_NAME...]` |
| Check that the QML loads without errors (after any QML change, before reporting DONE) | `bash extras/redesign/qml-smoke.sh` (see [QML runtime smoke test](#qml-runtime-smoke-test)) |
| Build the Windows app for a manual "Dev build:" check | `bash extras/redesign/dev-build.sh` (see [building.md](building.md)) |

The win64 cross-build cannot run most Qt tests (the win64 Qt contrib has no
`Qt6QuickTest`, and the tests that start a libvlc instance need static modules,
which the core only loads on ELF targets). Upstream runs them natively on Linux
in the CI image, and `linux-tests.sh` does the same on your machine.

Mapping for plan steps:

```text
meson test -C build-win64/win64-meson X     ->  bash extras/redesign/linux-tests.sh X
meson test -C build-win64/win64-meson        ->  bash extras/redesign/linux-tests.sh
```

## linux-tests.sh

```bash
bash extras/redesign/linux-tests.sh                    # whole "qt" suite
bash extras/redesign/linux-tests.sh tst_FSM            # only that test
bash extras/redesign/linux-tests.sh tst_FSM base_model_test
```

It runs in `registry.videolan.org/vlc-debian-unstable:20260611225331` (the image
upstream's `debian-meson` CI job uses; Qt 6.10.2 with QuickTest, meson 1.11):

1. creates the Docker named volume for this source tree (see below; build tree
   at `/build/linux`; the repository is bind-mounted at `/vlc`);
2. first run only: `meson setup /build/linux /vlc -Dextra_checks=true -Dqt=enabled`
   (upstream's options minus coverage; `-Dqt=enabled` makes a missing Qt a hard
   error rather than a silent GUI-less build with no Qt tests);
3. `meson compile -C /build/linux`;
4. `QT_QPA_PLATFORM=offscreen meson test -C /build/linux --suite qt --print-errorlogs`,
   or, when names are given, `meson test ... NAME...` (no `--suite`, so exactly
   those tests run).

There is no explicit `meson setup --reconfigure` on later runs: meson/ninja
regenerate the build files by themselves when a `meson.build` or
`meson_options.txt` changed. The exit status is meson test's (non-zero on a
failure, on an unknown test name, or on a build error), and the final
`Ok: N  Fail: M ...` summary is printed. `VLC_TEST_TIMEOUT` (default 60) is
forwarded to the container.

### One volume per source tree

The volume is named `vlc-reborn-linux-build-<10 hex digits>`, where the digits
are the start of the SHA-1 of the repository's Windows path, so every git
worktree gets its own build directory (printed on every run as `volume: ...`).
ninja decides what is up to date from file mtimes; sharing one build directory
between two checkouts would silently reuse the other tree's objects and report
the wrong result. Consequence: the first run in each new worktree is a full
build (~4.5 min), and each volume takes several GB of disk. Remove the volumes
of worktrees you no longer use with `docker volume rm <name>` (list them with
`docker volume ls | grep vlc-reborn-linux-build`); the next run in that tree
reconfigures and rebuilds from scratch.

To pick the volume yourself (for example to keep a throwaway build), set
`VLC_LINUX_VOLUME`:

```bash
VLC_LINUX_VOLUME=my-vlc-build bash extras/redesign/linux-tests.sh tst_FSM
```

Concurrent runs that use the same volume are serialized: the script holds
`flock /build/.lock` inside the volume for the whole setup/compile/test, so a
second invocation prints `another Linux runner uses this build volume; ...
waits...` and continues when the first has finished. `qml-smoke.sh` takes the
same lock, so it never races a test run. Runs on different
volumes (different worktrees) run in parallel.

### Timing (12 cores, 31 GB, image already pulled)

| Run | Time |
| --- | --- |
| Image pull (once) | ~6 min |
| First run in a worktree, empty volume (configure + 2401-step build + tests) | ~4.5 min |
| Re-run, nothing changed, single test | ~9 s |
| Re-run after touching one Qt source file, single test | ~16 s |

### Tests in the `qt` suite

| Name | Kind |
| --- | --- |
| `base_model_test`, `test_qt_ml_model`, `test_qt_navigation_model`, `test_qt_renderer_manager`, `test_qt_thread_runner`, `test_qt_dialog_model` | C++ (QtTest), `vlc_tests` entries |
| `tst_FSM` | QML (QtQuickTest, run by the `qml_test` executable) |

All 7 pass on unmodified upstream code (Ok: 7, Fail: 0).

Known upstream failures: none so far.

### If the script says the tree has CRLF line endings

The container reads the working tree directly, and CRLF breaks the Python and
shell helper scripts (`env: 'python3\r': No such file or directory`).
`.gitattributes` makes git write LF, but a checkout created before it existed
(or by a tool that ignored it) keeps CRLF. Re-checkout once:
`git rm --cached -r -q . && git reset --hard` (only safe with no local changes).

## QML runtime smoke test

```bash
bash extras/redesign/qml-smoke.sh                      # 15 s per run
bash extras/redesign/qml-smoke.sh --seconds 30
bash extras/redesign/qml-smoke.sh --media test/samples/meta.mp3   # also open a file
QML_SMOKE_FULL_LOG=1 bash extras/redesign/qml-smoke.sh            # print the whole logs
```

`linux-tests.sh` compiles the C++, but a wrong QML type, property or binding
only shows when the interface actually loads. `qml-smoke.sh` loads it. It shares
the image, the per-tree build volume and the flock with `linux-tests.sh`
(`extras/redesign/linux-common.sh` and `linux-container-common.sh` are the
shared parts), builds all default targets (`bin/vlc`, the qt plugin), and then
starts the Qt interface of the build tree twice for N seconds: once with the
redesign (`--qt-redesign`, passed explicitly), once with `--no-qt-redesign`. Both runs use
`QT_QPA_PLATFORM=offscreen`, a virtual X server (Xvfb, the qt module calls
`vlc_xlib_init`), `--qt-compositor=dummy` (the x11 compositor crashes on the
offscreen platform), dummy audio/video output and `--no-qt-privacy-ask`.

**Never start the Windows `vlc.exe` to check QML.** It writes to the real
`%APPDATA%\vlc`. The smoke test cannot touch it: it runs in a container with
`HOME` and `XDG_*` pointing to a fresh temp directory, the repository mounted
read-only, no network and no access to the host display or profile. The script
lists what each run wrote below that temp directory (Qt/QML caches, fontconfig,
the Mesa shader cache, `vlc-qt-interface.conf`).

### Reading the summary

```text
redesign: 2 errors, 2 warnings; stock: 0 errors, 2 warnings; env: 2 + 3 SVG-plugin lines
```

* **error** (exit status 1): a diagnostic that names our code
  (`qrc:/qt/qml/VLC/Redesign/...`), or a `ReferenceError`, `TypeError`, `is not a
  type`, `Cannot assign`, `Unable to assign`, `module ... is not installed`,
  `Binding loop`, `qml loading`, `no root item`, `unable to create main
  interface`, `no suitable compositor` or other Qt `generic error` line in the redesign run that the
  stock run does not have. In the stock run, the patterns above are errors too.
* **warning**: any other QML/Qt diagnostic, printed so you can see it. Upstream's
  own noise, identical in both runs, lands here. Currently known and harmless in
  this container: `propagateSizeHints()` and `unknown Qt platform: offscreen`.
* **env**: `Error decoding: ... .svg: Unsupported image format` and `ImageHelper:
  svg image plugin is not found.` are printed as `env:` lines and counted in
  neither errors nor warnings: the Linux image has no Qt 6 SVG image plugin (only
  the Qt 5 one, which cannot be used), so every SVG fails to decode here. Real
  SVG problems (bad file, wrong path) are invisible to this test.
* **a run did not start** (exit status 2 when there are no errors): `vlc`
  crashed, or quit by itself before the N seconds were up (status 0 is not
  "ran until stopped"), or the log has no `using interface module "qt"`. The
  last 25 log lines are printed.

Exit status: 0 clean, 1 errors, 2 a run did not start, 64 usage error.

The container compiles the live working tree, so an error in a file you did not
touch may be another agent's work in progress: report it, do not fix it.
A run takes about 45 s (nothing to compile, 2 x 15 s); raise `--seconds` on a
slow machine.

Compare the redesign line with the stock line: a new redesign error with a clean
stock run is ours. The matching log lines are printed under each count.

### What it cannot catch

* Anything visual: layout, colours, clipping, animations. Offscreen rendering is
  not screenshotted. Use the "Dev build:" manual check for those.
* Windows-only code paths: DirectComposition, CSD/title bar integration, the
  Windows compositor choice, Win32 theme code, `#ifdef _WIN32` QML/C++.
* Video embedding (the dummy compositor is used) and anything needing audio or
  video hardware.
* **The media library.** The Linux image has no `libmedialibrary`, so the
  `VLC.MediaLibrary` QML types (`MLRecentVideoModel`, `MLFolderModel`, ...) are
  not registered (`MainUI::registerQMLTypes` only registers them when a media
  library exists). QML that uses them unconditionally fails to load here, and
  the load aborts at the first such error, so QML that is created after it is
  not exercised in that run. Such an error is reported as an error, whether or
  not the same QML would load on Windows: decide that case by hand.
* Only the code reached within N seconds is exercised: pages, dialogs and
  popups that need a click are not opened.

## Adding a C++ test

Add an entry to `vlc_tests` in `modules/gui/qt/redesign/tests/meson.build`
(never in `modules/gui/qt/meson.build`; that file only carries the hook that
enters this one, see the header of `modules/gui/qt/redesign/meson.build`).
The file is entered from inside upstream's `if qtest_qt6_dep.found()` block.
Paths are relative to `modules/gui/qt/redesign/tests/`, so the test sources in
`modules/gui/qt/tests/` are `'../../tests/...'` and the redesign sources
`'../cpp/...'`:

```meson
vlc_tests += {
    'name': 'test_qt_my_thing',
    'sources': files('../../tests/test_my_thing.cpp'),   # plus the sources under test
    'moc_sources': files('../../tests/test_my_thing.cpp'),  # if it has Q_OBJECT; 'moc_headers' for headers
    'suite': ['qt'],
    'link_with': [libvlccore],
    'link_args': qt_link_args,
    'dependencies': [qt6_dep, qt_extra_deps, qtest_qt6_dep],
}
```

`qtest_qt6_dep` is defined by upstream just before the hook, which sits inside the block that holds the
other QtTest-based entries. Tests that need a libvlc instance with fake modules
use `tests/vlc_stub_modules.cpp` (see `test_qt_ml_model`). Valid keys are listed
in `test/meson.build`. Without `'suite': ['qt']` the test does not run under
`linux-tests.sh` without names. Run it with
`bash extras/redesign/linux-tests.sh test_qt_my_thing`.

## Adding a QML test

1. Put the file in `modules/gui/qt/tests/` (`tst_*.qml`, a `TestCase` from
   `QtTest`).
2. Add it to `qml_tests` in `modules/gui/qt/redesign/meson.build` (paths are
   relative to `modules/gui/qt/redesign/`; upstream's own entries stay in
   `modules/gui/qt/meson.build`):

   ```meson
   qml_tests += {
       'tst_MyThing': files('../tests/tst_MyThing.qml'),
   }
   ```

   A `test()` in the `qt` suite is generated for each entry, run through
   `qml_test`.
3. `qml_test` links the QML modules in `qmllibs`, so a test can only import
   modules built into it (e.g. `VLC.Util`). Add any new module it needs to
   `qmllibs`.
4. Run it with `bash extras/redesign/linux-tests.sh tst_MyThing`.

`run-tests.sh` / `dev-build.sh --tests` (win64) pick up `vlc_tests` entries too,
but several of them are excluded there (see [building.md](building.md)); the
Linux runner is the authority for pass/fail.
