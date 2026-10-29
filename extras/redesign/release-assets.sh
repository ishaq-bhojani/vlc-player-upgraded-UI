#!/usr/bin/env bash
#
# Assembles the assets of a Vireo release from a finished build.
#
#   extras/redesign/release-assets.sh <tag> <build_number> <repository> <vlc_win64_dir> <installer> <out_dir>
#
#   tag            the git tag of the release, v<major>.<minor>.<patch>[-suffix] (v0.1.0-rc1)
#   build_number   the redesign_build_number the build was made with (1..65535)
#   repository     <owner>/<name> on GitHub: the installer URL of the status file
#   vlc_win64_dir  the installed tree (container: /build/win64-meson/vlc-win64)
#   installer      the NSIS installer of that build (vireo-<version>-win64.exe)
#   out_dir        where the assets are written (created; emptied first)
#
# Writes into <out_dir>:
#   vireo-<version>-win64.exe          the installer (copied)
#   vireo-<version>-win64.exe.asc      its update signature (make-status.sh)
#   vireo-<version>-win64-portable.zip the installed tree with an empty "portable"
#                                      folder: settings stay next to vireo.exe
#   status-win-x64, status-win-x64.asc the signed update status file (make-status.sh)
#   SHA256SUMS                         of every file above
#
# The status file points at
#   https://github.com/<repository>/releases/download/<tag>/<installer>
# and its notes are the release notes file <notes> if RELEASE_NOTES_FILE is set, else
# "Vireo <version>". Signing needs UPDATE_GPG_KEY / UPDATE_GPG_PASSPHRASE (see
# make-status.sh); RELEASE_ASSETS_UNSIGNED=1 skips the status file and the signatures
# (a dry run without the secrets).

set -euo pipefail

die() { echo "release-assets.sh: $*" >&2; exit 1; }

[ "$#" -eq 6 ] || { sed -n '3,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64; }

TAG="$1"
BUILD="$2"
REPOSITORY="$3"
TREE="$4"
INSTALLER="$5"
OUT="$6"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# v0.1.0-rc1 -> 0.1.0: the release version of the installer name (meson option
# redesign_release_version, three numbers)
[[ "$TAG" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)(-[0-9A-Za-z.]+)?$ ]] \
    || die "tag must be v<major>.<minor>.<patch>[-suffix] (got '$TAG')"
VERSION="${BASH_REMATCH[1]}"
[[ "$REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "repository must be <owner>/<name> (got '$REPOSITORY')"
[ -f "$TREE/vireo.exe" ] || die "no vireo.exe in $TREE"
[ -f "$INSTALLER" ] || die "installer not found: $INSTALLER"
NAME="$(basename "$INSTALLER")"
[ "$NAME" = "vireo-$VERSION-win64.exe" ] \
    || die "the installer is $NAME, the tag asks for vireo-$VERSION-win64.exe (redesign_release_version?)"

rm -rf "$OUT"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

cp "$INSTALLER" "$OUT/$NAME"

# --- portable zip ------------------------------------------------------------
ZIP="vireo-$VERSION-win64-portable.zip"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
DIR="$STAGE/vireo-$VERSION"
cp -a "$TREE" "$DIR"
# an empty "portable" folder next to vireo.exe keeps the settings there (src/win32/dirs.c)
mkdir -p "$DIR/portable"
touch "$DIR/portable/.keep"
# the SDK files are for developers, not for a player
rm -rf "$DIR/sdk"
(cd "$STAGE" && zip -q -r -9 "$OUT/$ZIP" "vireo-$VERSION")

# --- status file and signatures ------------------------------------------------
if [ "${RELEASE_ASSETS_UNSIGNED:-}" = "1" ]; then
    echo "release-assets.sh: RELEASE_ASSETS_UNSIGNED=1, no status file and no signatures" >&2
else
    NOTES="${RELEASE_NOTES_FILE:-}"
    if [ -z "$NOTES" ]; then
        NOTES="$STAGE/notes.txt"
        printf 'Vireo %s\n' "$VERSION" > "$NOTES"
    fi
    URL="https://github.com/$REPOSITORY/releases/download/$TAG/$NAME"
    bash "$HERE/make-status.sh" "$BUILD" "$URL" "$NOTES" "$OUT" "$OUT/$NAME"
fi

(cd "$OUT" && sha256sum -- * | grep -v ' SHA256SUMS$' > SHA256SUMS)
ls -l "$OUT"
