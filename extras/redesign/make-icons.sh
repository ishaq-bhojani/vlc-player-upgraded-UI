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
