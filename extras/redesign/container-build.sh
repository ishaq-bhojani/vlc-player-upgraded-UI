#!/usr/bin/env bash
#
# Runs INSIDE the vlc-debian-win64-posix container; called by dev-build.sh.
# Source tree is at /vlc, the (persistent) build tree at /build (cwd).
#
# Environment: BUILD_FLAGS (build.sh flags), WANT_TESTS (0/1),
#              PINNED_CONTRIB_SHA, optional VLC_PREBUILT_CONTRIBS_URL.

set -euo pipefail

B=/build/win64-meson

git config --global --add safe.directory /vlc

# --- prebuilt contribs ------------------------------------------------------
# build.sh -p falls back to a "latest" tarball that 404s for 4.0. Upstream CI
# publishes contribs per contrib-relevant commit (extras/ci/gitlab-ci.yml): use
# the one for the newest commit touching contribs, else the pinned commit this
# fork branched from. Override with VLC_PREBUILT_CONTRIBS_URL.
if [ -z "${VLC_PREBUILT_CONTRIBS_URL:-}" ]; then
    base=https://artifacts.videolan.org/vlc/win64/vlc-contrib-x86_64-w64-mingw32
    for sha in "$(cd /vlc && extras/ci/get-contrib-sha.sh win64 || true)" "$PINNED_CONTRIB_SHA"; do
        [ -n "$sha" ] || continue
        if curl -sfIL --retry 5 --retry-all-errors "$base-$sha.tar.zst" >/dev/null; then
            export VLC_PREBUILT_CONTRIBS_URL="$base-$sha.tar.zst"
            break
        fi
    done
fi
echo "prebuilt contribs: ${VLC_PREBUILT_CONTRIBS_URL:-<none found, contribs will be built from source>}"

# --- wine shim --------------------------------------------------------------
# build.sh -m registers `wine` as meson's exe_wrapper, and meson runs a
# "sanity check" executable through it. This image only ships a 32-bit wine
# ("Bad EXE format" for x86_64 binaries), so that check can never pass. Nothing
# else in the build needs to *run* a win64 binary (plugins.dat is skipped in
# cross builds and tests are run on the Windows host), so let the sanity check
# succeed and hand everything else (e.g. 32-bit WiX tools) to the real wine.
SHIM=/tmp/redesign-shim
mkdir -p "$SHIM"
cat > "$SHIM/wine" <<'SHIM_EOF'
#!/bin/sh
case "$1" in
    */meson-private/sanity_check_for_*_cross.exe) exit 0 ;;
esac
exec /usr/bin/wine "$@"
SHIM_EOF
chmod +x "$SHIM/wine"
export PATH="$SHIM:$PATH"

# --- Qt private headers -----------------------------------------------------
# The image's native Qt tools (/opt/tools, hence the qmake6 wrapper that meson
# uses) are Qt 6.8.0 while the contribs ship Qt 6.8.3 (the contrib patches
# tolerate that skew). Meson builds the private-header include paths from the
# *qmake* version (include/QtGui/6.8.0/...), which do not exist, so
# <rhi/qrhi.h>, "private/qquickitem_p.h" etc. are not found and qt.cpp then fails
# to compile on Windows. Add the real 6.8.3 private include directories.
qt_major=$(sed -n 's/^QTBASE_VERSION_MAJOR *:= *//p' /vlc/contrib/src/main.mak)
qt_full=$(sed -n 's/^QTBASE_VERSION *:= *.*)\(\.[0-9]*\)$/'"$qt_major"'\1/p' /vlc/contrib/src/main.mak)
qt_inc=/build/contrib/x86_64-w64-mingw32/include
qt_private=""
for m in Core Gui Qml Quick QuickControls2 QuickTemplates2 QuickLayouts QmlModels QmlCore Widgets Test Svg SvgWidgets OpenGL; do
    qt_private="$qt_private -I$qt_inc/Qt$m/$qt_full -I$qt_inc/Qt$m/$qt_full/Qt$m"
done
export CPPFLAGS="${CPPFLAGS:-}$qt_private"

# --- duplicate libssp (FLAC) ------------------------------------------------
# With --prefer-static meson resolves flac.pc's "-lssp" to libssp.a while the
# build also passes -lssp (-> libssp.dll.a), so libflac_plugin.dll fails with
# "multiple definition of __stack_chk_fail". Both are the same code; tolerate it.
export LDFLAGS="${LDFLAGS:-} -Wl,--allow-multiple-definition"

# --- libstdc++ --------------------------------------------------------------
# vlc.exe calls SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_SYSTEM32) and
# plugins are loaded with LOAD_LIBRARY_SEARCH_SYSTEM32 (src/win32/plugin.c), so a
# plugin's DLL dependencies are only found if already loaded (libvlccore.dll
# pulls in libgcc/libssp/libwinpthread) or in System32. libstdc++-6.dll is
# neither, so every C++ plugin (including Qt) would fail with error 126. Link it
# statically, as upstream does for its clang builds.
export LDFLAGS="$LDFLAGS -static-libstdc++"

# --- no installers ----------------------------------------------------------
# The NSIS helper plugin (nsProcess.dll) is built whenever makensis exists and
# does not link for x86_64 (32-bit symbol names in its .def). Dev builds do not
# make installers, so turn it off.
export MCONFIGFLAGS="${MCONFIGFLAGS:-} -Dnsis=disabled"

# --- build + install --------------------------------------------------------
/vlc/extras/package/win32/build.sh $BUILD_FLAGS
# The build directory was configured with the meson from extras/tools (newer
# than the image's /usr/bin/meson), so use that one from here on.
export PATH="/build/extras/tools/build/bin:$PATH"
rm -rf "$B/vlc-win64"   # no stale files from earlier builds
meson install -C "$B" --strip --no-rebuild

# meson install does not ship the MinGW runtime DLLs (the NSIS/WiX packaging
# does), but vlc.exe, the plugins and the test executables need them at run time.
for dll in /usr/lib/gcc/x86_64-w64-mingw32/14-posix/{libgcc_s_seh-1,libssp-0}.dll \
           /usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll; do
    cp "$dll" "$B/vlc-win64/"
done

# --- test executables -------------------------------------------------------
# They are build_by_default:false, so build every executable that a test of the
# "qt" suite runs (test_qt_*, base_model_test, qml_test) and stage them.
if [ "${WANT_TESTS:-0}" = 1 ]; then
    targets=$(meson introspect "$B" --tests | python3 -c '
import json, sys
seen = []
for t in json.load(sys.stdin):
    if any(s == "qt" or s.endswith(":qt") for s in t["suite"]):
        if t["cmd"][0] not in seen:
            seen.append(t["cmd"][0])
print("\n".join(seen))')
    [ -n "$targets" ] || { echo "no qt tests found in meson introspection" >&2; exit 1; }
    rel=$(for t in $targets; do realpath --relative-to="$B" "$t"; done)
    # -k 0: keep going, so one test that cannot link (see run-tests.sh) does not
    # hide the others.
    ninja -C "$B" -k 0 $rel || echo "some test executables failed to build (continuing)" >&2
    rm -rf "$B/tests-out"
    mkdir -p "$B/tests-out"
    : > "$B/tests-out/UNBUILT.txt"
    for t in $targets; do
        if [ -f "$t" ]; then cp "$t" "$B/tests-out/"; else basename "$t" >> "$B/tests-out/UNBUILT.txt"; fi
    done
    echo "unbuilt test executables: $(tr '\n' ' ' < "$B/tests-out/UNBUILT.txt")"
fi
