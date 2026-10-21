#!/usr/bin/env bash
#
# Regenerates every raster file of the Vireo brand from the SVG artwork in
# modules/gui/qt/redesign/assets/brand/ (vireo-icon.svg, vireo-icon-small.svg for
# 16-24 px, Inter-SemiBold.ttf for the installer wordmark):
#
#   share/icons/vireo.ico                                  exe, installer, shortcuts (10 sizes, 16..256)
#   modules/gui/qt/redesign/assets/brand/png/vireo-N.png   Qt window, tray and About icons (16..256)
#   extras/package/win32/NSIS/vireo_branding.bmp           NSIS welcome/finish panel (164 x 314)
#   extras/package/win32/msi/vireo_bannrbmp.bmp            MSI dialog banner (494 x 58)
#   build-win64/brand-preview/                             previews at 16/20/24/32/48/256 + sheet (git-ignored)
#
#   bash extras/redesign/make-icons.sh
#
# The rasteriser is Qt6 Svg in the Linux test container (the same image as
# linux-tests.sh; the Windows host has no SVG tool). The container compiles
# extras/redesign/make-icons.cpp and runs it; nothing else is touched.
# Every file is written through a temporary name and renamed, then read back and validated
# (PNG signature, decodes, expected size; every .ico entry present and equal to the image
# rendered for it, 16-24 px from the small artwork; BMP header); the script exits non-zero otherwise.
# Re-running on unchanged artwork changes no file.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/linux-common.sh"

PREVIEW="build-win64/brand-preview"
mkdir -p "$REPO/$PREVIEW"

docker run --rm -e LC_ALL=C.UTF-8 -v "$REPO_MOUNT":/vlc -w /vlc "$IMAGE" bash -c '
    set -e
    g++ -std=c++17 -fPIC -O1 extras/redesign/make-icons.cpp -o /tmp/make-icons \
        $(pkg-config --cflags --libs Qt6Svg Qt6Gui Qt6Core)
    /tmp/make-icons /vlc /vlc/'"$PREVIEW"'
'

# Independent check on the host of what the container wrote: PNG signature, BMP/ICO header.
fail=0
check() { [ "$(head -c "${#2}" "$REPO/$1" 2>/dev/null)" = "$2" ] || { echo "make-icons.sh: $1 is not a valid file ($3)" >&2; fail=1; }; }
for f in "$REPO"/modules/gui/qt/redesign/assets/brand/png/vireo-*.png; do
    [ "$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')" = "89504e47" ] || { echo "make-icons.sh: $f is not a PNG" >&2; fail=1; }
done
check extras/package/win32/NSIS/vireo_branding.bmp BM BMP
check extras/package/win32/msi/vireo_bannrbmp.bmp BM BMP
[ "$(head -c 4 "$REPO/share/icons/vireo.ico" | od -An -tx1 | tr -d ' \n')" = "00000100" ] || { echo "make-icons.sh: share/icons/vireo.ico is not an icon" >&2; fail=1; }
exit $fail
