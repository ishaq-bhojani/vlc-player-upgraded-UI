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
# Before anything is built, comment-lint.sh scans the redesign sources for an
# unterminated /* comment (file:line) and stops at once if it finds one: such a file
# only fails at run time in QML, and in a page the startup run never opens.
#
# Layout:
#   source tree   bind-mounted read/write at /vlc (the build never writes there)
#   build tree    docker named volume mounted at /build (/build/linux); a build
#                 on a bind-mounted NTFS directory is far too slow. One volume
#                 per source tree: vlc-reborn-linux-build-<10 hex of the sha1 of
#                 the repository's Windows path>, so parallel git worktrees never
#                 share (and never confuse) a build directory. Override with the
#                 VLC_LINUX_VOLUME environment variable. Reset with
#                 docker volume rm <name> (the name is printed on every run).
#   concurrency   runs on the same volume are serialized (flock on /build/.lock
#                 inside the volume); a second invocation waits for the first.
#
# The build directory is configured once (meson setup). Later runs reuse it and
# need no explicit reconfigure: meson/ninja regenerate it by themselves when a
# meson.build or meson_options.txt changed, and recompile only what changed.
#
# Requires Docker Desktop (WSL2 backend). Run from Git Bash or WSL.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/linux-common.sh"   # IMAGE, REPO, REPO_MOUNT, VOLUME

case "${1:-}" in
    -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

# fail fast, before the volume and the build (a second; prints file:line)
bash "$(dirname "${BASH_SOURCE[0]}")/comment-lint.sh"

linux_prepare_volume linux-tests.sh

echo "==> Native Linux tests in $IMAGE (volume: $VOLUME, source: $REPO_MOUNT)"
# The script below runs in the container; test names arrive as $@.
docker run --rm -i \
    -e VLC_TEST_TIMEOUT="${VLC_TEST_TIMEOUT:-60}" \
    -v "$VOLUME":/build \
    -v "$REPO_MOUNT":/vlc \
    -w /build \
    "$IMAGE" \
    bash -s -- "$@" <<'CONTAINER_EOF'
set -euo pipefail

source /vlc/extras/redesign/linux-container-common.sh   # B, linux_lock_configure_compile
linux_lock_configure_compile linux-tests.sh

# --- test --------------------------------------------------------------------
echo "==> meson test"
export QT_QPA_PLATFORM=offscreen
# Names given: run exactly those; otherwise the whole qt suite.
if [ "$#" -gt 0 ]; then
    exec meson test -C "$B" --print-errorlogs "$@"
fi
exec meson test -C "$B" --suite qt --print-errorlogs
CONTAINER_EOF
