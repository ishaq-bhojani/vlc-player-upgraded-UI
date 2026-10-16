#!/usr/bin/env bash
#
# Native Linux unit/QML test runner for VLC Reborn.
#
#   extras/redesign/linux-tests.sh [TEST_NAME...]
#
# Builds VLC natively (meson, x86_64 Linux) inside VideoLAN's official
# vlc-debian-unstable CI image and runs the meson "qt" test suite there. This is
# the runner for every "meson test ..." step of the redesign plan: the win64
# cross-build (dev-build.sh) cannot run most Qt tests (no Qt6QuickTest in the
# win64 contribs, libvlc-instance tests need static modules, ELF only).
#
#   (no arguments)   run the whole qt suite
#   TEST_NAME...     run only these tests (e.g. tst_FSM base_model_test)
#
# The exit status is meson test's. Tests run with QT_QPA_PLATFORM=offscreen.
#
# Layout:
#   source tree   bind-mounted read/write at /vlc (the build never writes there)
#   build tree    docker named volume vlc-reborn-linux-build, mounted at /build
#                 (/build/linux); a build on a bind-mounted NTFS directory is far
#                 too slow. Reset with: docker volume rm vlc-reborn-linux-build
#
# The build directory is configured once (meson setup). Later runs reuse it and
# need no explicit reconfigure: meson/ninja regenerate it by themselves when a
# meson.build or meson_options.txt changed, and recompile only what changed.
#
# Requires Docker Desktop (WSL2 backend). Run from Git Bash or WSL.

set -euo pipefail

IMAGE="registry.videolan.org/vlc-debian-unstable:20260611225331"
VOLUME="vlc-reborn-linux-build"

case "${1:-}" in
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Docker Desktop wants a Windows-form path for bind mounts when run from Git Bash.
if REPO_MOUNT="$(cd "$REPO" && pwd -W 2>/dev/null)"; then :; else REPO_MOUNT="$REPO"; fi
# Git Bash would otherwise rewrite /vlc, /build, ... in docker arguments.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

# CRLF shell scripts / patches cannot be used in the Linux container;
# .gitattributes forces LF.
# (tr, not grep: Git Bash's grep drops the CR from its pattern.)
if [ -n "$(head -c 200 "$REPO/buildsystem/gen-vlc-about.py" | tr -dc '\r')" ]; then
    echo "linux-tests.sh: the working tree has CRLF line endings (core.autocrlf)." >&2
    echo "Make sure .gitattributes is present, then re-checkout:" >&2
    echo "  git rm --cached -r -q . && git reset --hard" >&2
    exit 1
fi

docker volume create "$VOLUME" >/dev/null
# A fresh volume is root-owned, but the image builds as the unprivileged
# "videolan" user. (The marker file makes the volume non-empty, otherwise Docker
# re-copies the image's root-owned /build over the chown on the next mount.)
docker run --rm --user root -v "$VOLUME":/build "$IMAGE" \
    sh -c 'chown videolan:videolan /build && touch /build/.vlc-reborn'

echo "==> Native Linux tests in $IMAGE (volume: $VOLUME)"
# The script below runs in the container; test names arrive as $@.
docker run --rm -i \
    -e VLC_TEST_TIMEOUT="${VLC_TEST_TIMEOUT:-60}" \
    -v "$VOLUME":/build \
    -v "$REPO_MOUNT":/vlc \
    -w /build \
    "$IMAGE" \
    bash -s -- "$@" <<'CONTAINER_EOF'
set -euo pipefail

B=/build/linux
git config --global --add safe.directory /vlc   # meson/version scripts call git

# --- configure (first run only) ----------------------------------------------
# Options of upstream's native meson CI job (debian-meson in
# extras/ci/gitlab-ci.yml) minus coverage; -Dqt=enabled turns a missing Qt
# into an error instead of silently building without the GUI and its tests.
if [ ! -f "$B/build.ninja" ]; then
    echo "==> meson setup (first run)"
    rm -rf "$B"
    meson setup "$B" /vlc -Dextra_checks=true -Dqt=enabled
fi

# --- build -------------------------------------------------------------------
echo "==> meson compile"
meson compile -C "$B"

# --- test --------------------------------------------------------------------
echo "==> meson test"
export QT_QPA_PLATFORM=offscreen
# Names given: run exactly those; otherwise the whole qt suite.
if [ "$#" -gt 0 ]; then
    exec meson test -C "$B" --print-errorlogs "$@"
fi
exec meson test -C "$B" --suite qt --print-errorlogs
CONTAINER_EOF
