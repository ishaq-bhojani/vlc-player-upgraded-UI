#!/usr/bin/env bash
#
# Reproducible Windows dev build for Vireo.
#
#   extras/redesign/dev-build.sh [--release] [--tests] [--installer]
#
# Cross-builds VLC (x86_64, mingw-w64) inside the official VideoLAN Debian
# container, then copies the installed tree and the Qt test executables to
# build-win64/ so they can be run natively on Windows.
#
#   --release   release build type (build.sh -r -i none: -r alone would also run
#               upstream's meson dist and MSI packaging, which needs WiX; the
#               NSIS installer comes from --installer, as for a dev build)
#   --tests     after building, run extras/redesign/run-tests.sh
#   --installer also build the NSIS installer (needs makensis, in the image):
#               build-win64/installer/vireo-<release version>-win64.exe
#
# Layout:
#   source tree      bind-mounted at /vlc  (read by the container)
#   build tree       docker named volume   mounted at /build (fast; NTFS
#                    bind mounts are far too slow for a full VLC build)
#   output on host   build-win64/win64-meson/vlc-win64/vireo.exe
#                    build-win64/win64-meson/tests/*.exe
#                    build-win64/installer/vireo-<version>-win64.exe   (--installer)
#
# Environment: MCONFIGFLAGS is passed to the meson setup of build.sh, e.g.
#   MCONFIGFLAGS="-Dredesign_build_number=3" extras/redesign/dev-build.sh
#
# Requires Docker Desktop (WSL2 backend). Run from Git Bash or WSL.

set -euo pipefail

IMAGE="registry.videolan.org/vlc-debian-win64-posix:20260611225331"
ARCH_DIR="win64-meson"
# Last upstream commit that touched contribs before this fork; its prebuilt
# contribs are published and known to work with this image.
PINNED_CONTRIB_SHA="c45a62bed8f1b2b98994b13770bdea67f95d2a52"

RELEASE=0
TESTS=0
INSTALLER=0
for arg in "$@"; do
    case "$arg" in
        --release) RELEASE=1 ;;
        --tests)   TESTS=1 ;;
        --installer) INSTALLER=1 ;;
        -h|--help) sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "dev-build.sh: unknown option '$arg'" >&2; exit 2 ;;
    esac
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Docker Desktop wants a Windows-form path for bind mounts when run from Git Bash.
if REPO_MOUNT="$(cd "$REPO" && pwd -W 2>/dev/null)"; then :; else REPO_MOUNT="$REPO"; fi
# Git Bash would otherwise rewrite /vlc, /build, ... in docker arguments.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

VOLUME="vlc-reborn-build"
BUILD_FLAGS="-m -p -a x86_64"
if [ "$RELEASE" = 1 ]; then
    VOLUME="vlc-reborn-build-release"
    BUILD_FLAGS="-r -i none $BUILD_FLAGS"
fi

OUT="$REPO/build-win64"
mkdir -p "$OUT"

# CRLF shell scripts cannot run in the Linux container; .gitattributes forces LF.
if head -c 200 "$REPO/extras/package/win32/build.sh" | LC_ALL=C grep -q $'\r'; then
    echo "dev-build.sh: the working tree has CRLF line endings (core.autocrlf)." >&2
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

echo "==> Building in $IMAGE (volume: $VOLUME, flags: $BUILD_FLAGS)"
docker run --rm \
    -e BUILD_FLAGS="$BUILD_FLAGS" \
    -e WANT_TESTS="$TESTS" \
    -e WANT_INSTALLER="$INSTALLER" \
    -e PINNED_CONTRIB_SHA="$PINNED_CONTRIB_SHA"     -e MCONFIGFLAGS="${MCONFIGFLAGS:-}" \
    -e VLC_PREBUILT_CONTRIBS_URL="${VLC_PREBUILT_CONTRIBS_URL:-}" \
    -v "$VOLUME":/build \
    -v "$REPO_MOUNT":/vlc \
    -w /build \
    "$IMAGE" \
    bash /vlc/extras/redesign/container-build.sh

echo "==> Copying build output to $OUT/$ARCH_DIR"
rm -rf "$OUT/$ARCH_DIR"
mkdir -p "$OUT/$ARCH_DIR"
TAR_ITEMS="vlc-win64"
[ "$TESTS" = 1 ] && TAR_ITEMS="vlc-win64 tests-out"
docker run --rm -v "$VOLUME":/build:ro "$IMAGE" \
    tar -C "/build/$ARCH_DIR" -cf - $TAR_ITEMS \
    | tar -C "$OUT/$ARCH_DIR" -xf -
if [ "$TESTS" = 1 ]; then mv "$OUT/$ARCH_DIR/tests-out" "$OUT/$ARCH_DIR/tests"; fi

if [ "$INSTALLER" = 1 ]; then
    echo "==> Copying the installer to $OUT/installer"
    rm -rf "$OUT/installer"
    mkdir -p "$OUT/installer"
    docker run --rm -v "$VOLUME":/build:ro "$IMAGE" \
        tar -C "/build/$ARCH_DIR" -cf - installer-out \
        | tar -C "$OUT/installer" --strip-components=1 -xf -
    [ "$(ls "$OUT"/installer/vireo-*-win64.exe 2>/dev/null | wc -l)" = 1 ] \
        || { echo "expected exactly one installer in $OUT/installer" >&2; exit 1; }
    echo "==> Installer: $(ls "$OUT"/installer/vireo-*-win64.exe)"
fi

test -f "$OUT/$ARCH_DIR/vlc-win64/vireo.exe" || { echo "vireo.exe missing from output" >&2; exit 1; }
echo "==> Built: $OUT/$ARCH_DIR/vlc-win64/vireo.exe"

if [ "$TESTS" = 1 ]; then
    echo "==> Running tests"
    bash "$REPO/extras/redesign/run-tests.sh"
fi
