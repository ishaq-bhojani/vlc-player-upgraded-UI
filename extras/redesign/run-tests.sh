#!/usr/bin/env bash
#
# Runs the Vireo Qt tests natively on the Windows host (Git Bash).
#
# The win64 build is a cross-build, so the test executables cannot run inside
# the Linux container; extras/redesign/dev-build.sh --tests builds them there
# and copies them to build-win64/win64-meson/tests/. This script runs:
#   * every test *.exe in that directory (test_qt_*, base_model_test, ...)
#     except the EXCLUDED ones below;
#   * qml_test.exe -input <file>.qml for each entry of the `qml_tests` dictionary
#     in modules/gui/qt/meson.build and modules/gui/qt/redesign/meson.build (when qml_test.exe
#     exists - see EXCLUDED).
#
# Prints "N passed, M failed" and exits non-zero if anything failed (or if no
# test could be run at all).
#
# Usage: extras/redesign/run-tests.sh [name-substring]   (filter, optional)
#        RUN_TESTS_LIST_QML=1 extras/redesign/run-tests.sh   (only list the QML tests found)

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIST="$REPO/build-win64/win64-meson"
VLC_DIR="$DIST/vlc-win64"
TESTS_DIR="$DIST/tests"
FILTER="${1:-}"
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"

# Prints the absolute (POSIX) path of every QML test file registered in a meson
# file's `qml_tests = {` / `qml_tests += {` blocks. Paths in `files('...')` are
# relative to the directory of that meson file ('tests/x.qml' or '../tests/x.qml').
qml_tests_of() { # meson-file
    local dir rel
    dir="$(dirname "$1")"
    [ -f "$1" ] || return 0
    while IFS= read -r rel; do
        echo "$(cd "$dir/$(dirname "$rel")" && pwd)/$(basename "$rel")"
    done < <(sed -En "/^qml_tests (\+)?= \{/,/^\}/ s/^[[:space:]]*'[^']*':[[:space:]]*files\('([^']*)'\).*/\1/p" "$1")
}

# The upstream entries (tst_FSM) are in modules/gui/qt/meson.build, the redesign
# ones in modules/gui/qt/redesign/meson.build; both are read.
qml_test_files() {
    qml_tests_of "$REPO/modules/gui/qt/meson.build"
    qml_tests_of "$REPO/modules/gui/qt/redesign/meson.build"
}

# RUN_TESTS_LIST_QML=1 only prints the discovered QML tests (dry listing).
if [ "${RUN_TESTS_LIST_QML:-}" = 1 ]; then qml_test_files; exit 0; fi

# Tests that cannot be built/run in this setup (upstream code is not patched).
# Format: "exe-name|reason". An excluded test is skipped; any *other* test that
# dev-build.sh failed to build (tests/UNBUILT.txt) counts as a failure.
EXCLUDED=(
    # Its meson entry (test_qt_navigation_model, modules/gui/qt/meson.build) has no `link_args`, and with
    # the static Qt of the win64 contribs the link then lacks the zlib/pcre2
    # symbols (undefined inflate*, pcre2_*_16) - it only works with a shared Qt.
    "test_qt_navigation_model.exe|does not link against the static win64 Qt contrib"
    # These tests (and test_qt_navigation_model) build their fake interface,
    # renderer-discovery and medialibrary modules into the executable via
    # `vlc_static_modules` (modules/gui/qt/tests/vlc_stub_modules.cpp). The core
    # only loads static modules on ELF targets (src/modules/bank.c), so on Windows
    # VLCTestingEnv::init() always fails ("no suitable interface module"). They
    # are still built by dev-build.sh --tests, which makes them a compile check.
    "test_qt_dialog_model.exe|needs vlc_static_modules, unsupported by the core on Windows"
    "test_qt_ml_model.exe|needs vlc_static_modules, unsupported by the core on Windows"
    "test_qt_renderer_manager.exe|needs vlc_static_modules, unsupported by the core on Windows"
    # Meson only defines the qml_test target when Qt6QuickTest is found, and the
    # prebuilt win64 Qt contrib does not ship it (upstream runs QML tests on a
    # native Linux job only). Covers all qml_tests entries (tst_FSM, tst_MediaText, tst_ReplayLogic).
    "qml_test.exe|Qt6QuickTest is not part of the win64 Qt contrib"
)

[ -d "$TESTS_DIR" ] || { echo "run-tests.sh: $TESTS_DIR not found; run extras/redesign/dev-build.sh --tests first" >&2; exit 2; }

native_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }

in_list() { # needle, then list entries (matched up to the first '|')
    local needle="$1" entry; shift
    for entry in "$@"; do [ "${entry%%|*}" = "$needle" ] && return 0; done
    return 1
}
reason() { local e; for e in "${EXCLUDED[@]}"; do [ "${e%%|*}" = "$1" ] && echo "${e#*|}"; done; }

# --- environment -------------------------------------------------------------
# libvlc.dll / libvlccore.dll and the MinGW runtime live next to vlc.exe.
export PATH="$VLC_DIR:$PATH"
export QT_QPA_PLATFORM=offscreen

export VLC_PLUGIN_PATH="$(native_path "$VLC_DIR/plugins")"
RESULTS="$(mktemp)"

# --- runner ------------------------------------------------------------------
passed=0
failed=0
failures=()

run_one() { # label cmd...
    local label="$1"; shift
    if [ -n "$FILTER" ] && [[ "$label" != *"$FILTER"* ]]; then return; fi
    echo "=== $label"
    # Qt Test output does not reach the console with this static Qt build, so
    # have it write its report to a file and show it afterwards.
    : > "$RESULTS"
    if timeout "$TEST_TIMEOUT" "$@" -o "$(native_path "$RESULTS"),txt"; then
        grep -E '^(Totals|FAIL|XFAIL)' "$RESULTS"
        echo "--- PASS $label"
        passed=$((passed + 1))
    else
        local rc=$?
        cat "$RESULTS"
        echo "--- FAIL $label (exit $rc)"
        failed=$((failed + 1))
        failures+=("$label")
    fi
}

if [ -s "$TESTS_DIR/UNBUILT.txt" ]; then
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        if in_list "$name" "${EXCLUDED[@]}"; then
            echo "=== SKIP $name ($(reason "$name"))"
        else
            echo "--- FAIL ${name%.exe} (not built)"
            failed=$((failed + 1)); failures+=("${name%.exe} (not built)")
        fi
    done < "$TESTS_DIR/UNBUILT.txt"
fi

for exe in "$TESTS_DIR"/*.exe; do
    [ -e "$exe" ] || continue
    name="$(basename "$exe")"
    [ "$name" = "qml_test.exe" ] && continue
    if in_list "$name" "${EXCLUDED[@]}"; then echo "=== SKIP $name ($(reason "$name"))"; continue; fi
    run_one "${name%.exe}" "$exe"
done

QML_TEST="$TESTS_DIR/qml_test.exe"
if [ -e "$QML_TEST" ] && ! in_list qml_test.exe "${EXCLUDED[@]}"; then
    mapfile -t QML_FILES < <(qml_test_files)
    if [ "${#QML_FILES[@]}" -eq 0 ]; then
        echo "--- FAIL qml_tests (qml_test.exe exists but no qml_tests entry was found in the meson files)"
        failed=$((failed + 1)); failures+=("qml_tests (none discovered)")
    fi
    for qml in "${QML_FILES[@]}"; do
        run_one "$(basename "$qml" .qml)" "$QML_TEST" -input "$(native_path "$qml")"
    done
else
    echo "=== SKIP QML tests ($(reason qml_test.exe))"
fi

rm -f "$RESULTS"
echo
if [ "$failed" -gt 0 ]; then printf 'FAILED: %s\n' "${failures[@]}"; fi
echo "$passed passed, $failed failed"
if [ "$failed" -gt 0 ] || [ "$((passed + failed))" -eq 0 ]; then exit 1; fi
