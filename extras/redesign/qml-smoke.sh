#!/usr/bin/env bash
#
# QML runtime smoke test for Vireo (native Linux, offscreen, in Docker).
#
#   extras/redesign/qml-smoke.sh [--seconds N] [--media PATH]
#
# The unit tests compile the C++ but QML type/property/binding errors only show
# when the interface actually loads. This starts the Qt interface of the Linux
# build (same image, per-tree build volume and flock as linux-tests.sh) twice,
# for N seconds each (default 15):
#
#   1. redesign on (--qt-redesign, passed explicitly),
#   2. with --no-qt-redesign (the stock interface),
#
# and scans the captured logs for QML diagnostics. The startup run only loads what
# the root item needs; the Settings modal, dialogs and other pages load on demand
# and would never be seen. So the redesign run also carries a type-load pass: a
# probe (qml-typeload.cpp, compiled in the container and injected with LD_PRELOAD)
# loads EVERY file of the VLC.Redesign module as a Component in a second QML engine
# of the same process, once the interface registered its types, and reports each
# file that does not reach Component.Ready (see "Type-load pass" below).
# Nothing touches the host: the
# run happens in a container whose HOME/XDG_* point to a fresh temp dir, the
# repository is mounted read-only, there is no network and no access to the
# host display (QT_QPA_PLATFORM=offscreen on a virtual X server, dummy
# audio/video output). Never launch the
# Windows vlc.exe for this: it writes to the real %APPDATA%\vlc.
#
#   --seconds N   how long each run is allowed to live (default 15)
#   --media PATH  also open this file (a path inside the repository, e.g.
#                 test/samples/meta.mp3 or test/samples/slaves/t.mp4)
#
# Exit status: 0 clean, 1 errors, 2 a run did not start (or quit by itself
# before the N seconds were up) and there are no errors, 3 the type-load probe
# did not compile (nothing was run), 64 usage.
#
# Verdict:
#
#   error    redesign run: any diagnostic naming our code
#            (qrc:/qt/qml/VLC/Redesign/...), and any ReferenceError, TypeError,
#            "is not a type", "Cannot assign", "Unable to assign", "module ...
#            is not installed", "Binding loop", "qml loading", "no root item",
#            "unable to create main interface", "no suitable compositor" or
#            qt "generic error" line that
#            the stock run does not also have (new in redesign).
#            stock run: the patterns above.
#   warning  any other QML/Qt diagnostic (upstream's own noise, or identical in
#            both runs); printed, not fatal.
#
#   env      the two messages caused by the missing Qt 6 SVG image plugin in the
#            image ("Error decoding: ....svg: Unsupported image format",
#            "ImageHelper: svg image plugin is not found."): printed separately
#            as "env:", counted in neither errors nor warnings.
#
# Summary lines: typeload: N files, R ready, S skipped (ML-only), E errors
#                redesign: N errors, M warnings; stock: N errors, M warnings; env: R + S SVG-plugin lines
#
# Type-load pass: every file listed in the built VLC/Redesign/qmldir (that is the
# sources and singletons of redesign/meson.build) is loaded as a Component
# (Component.Ready is the pass criterion, nothing is instantiated). Every file that
# fails is an error of the redesign run, whatever its message. Also an error: a
# .qml file under modules/gui/qt/redesign that the module does not list (it would
# not be in the resources, so it would be neither shipped nor checked), and a probe
# that printed no result (needs the interface to be up, so ~8 s or more per run).
# Files that use media library types, which this image does not register, may
# fail ONLY with one of the types that MainUI::registerQMLTypes registers just with
# a media library ("MLFolderModel is not a type"; the names are read from those
# registrations), "module VLC.MediaLibrary is not installed" or a "Type ...
# unavailable" cascade, and are then printed as "skipped (ML-only)"; the list of
# files is ML_ONLY below. The second engine has the app's registered types and
# import path but not its image providers: enough for a load check.
#
# Full logs are kept in the container only; the matching lines are printed.
# Set QML_SMOKE_FULL_LOG=1 to print the complete logs as well.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/linux-common.sh"   # IMAGE, REPO, REPO_MOUNT, VOLUME

SECONDS_PER_RUN=15
MEDIA=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        --seconds) SECONDS_PER_RUN="${2:?--seconds needs a value}"; shift 2 ;;
        --media)   MEDIA="${2:?--media needs a path}"; shift 2 ;;
        *) echo "qml-smoke.sh: unknown argument: $1" >&2; exit 64 ;;
    esac
done
case "$SECONDS_PER_RUN" in
    ''|*[!0-9]*|0) echo "qml-smoke.sh: --seconds must be a positive integer" >&2; exit 64 ;;
esac
if [ -n "$MEDIA" ]; then
    MEDIA="${MEDIA#./}"
    case "$MEDIA" in
        /*|*..*) echo "qml-smoke.sh: --media must be a path inside the repository" >&2; exit 64 ;;
    esac
    [ -f "$REPO/$MEDIA" ] || { echo "qml-smoke.sh: no such file in the repository: $MEDIA" >&2; exit 64; }
fi

linux_prepare_volume qml-smoke.sh

echo "==> QML smoke test in $IMAGE (volume: $VOLUME, source: $REPO_MOUNT, ${SECONDS_PER_RUN}s per run)"
# The script below runs in the container. /vlc is read-only: the build writes
# to /build only, and the smoke test must not write anywhere but its temp HOME.
# No network. (The lock/compile helper is the one linux-tests.sh uses.)
docker run --rm -i \
    --network none \
    -e SMOKE_SECONDS="$SECONDS_PER_RUN" \
    -e SMOKE_MEDIA="$MEDIA" \
    -e QML_SMOKE_FULL_LOG="${QML_SMOKE_FULL_LOG:-}" \
    -e QML_SMOKE_QUICK_BACKEND="${QML_SMOKE_QUICK_BACKEND:-}" \
    -v "$VOLUME":/build \
    -v "$REPO_MOUNT":/vlc:ro \
    -w /build \
    "$IMAGE" \
    bash -s <<'CONTAINER_EOF'
set -euo pipefail

source /vlc/extras/redesign/linux-container-common.sh   # B, linux_lock_configure_compile
linux_lock_configure_compile qml-smoke.sh

[ -x "$B/bin/vlc" ] || { echo "qml-smoke.sh: $B/bin/vlc was not built" >&2; exit 2; }
[ -f "$B/modules/libqt_plugin.so" ] || { echo "qml-smoke.sh: the qt plugin was not built" >&2; exit 2; }

ROOT="$(mktemp -d /tmp/qml-smoke.XXXXXX)"
XVFB_PID=""
trap '[ -z "$XVFB_PID" ] || kill "$XVFB_PID" 2>/dev/null; rm -rf "$ROOT"' EXIT

# The qt module initializes Xlib (vlc_xlib_init) before Qt starts, so it needs an
# X server even though Qt itself runs on the offscreen platform. A virtual one,
# inside the container (no access to any host display).
# (</dev/null: this script itself is read from stdin by bash -s.)
Xvfb :77 -screen 0 1280x800x24 -nolisten tcp </dev/null >"$ROOT/xvfb.log" 2>&1 &
XVFB_PID=$!
export DISPLAY=:77
for _ in $(seq 50); do [ -S /tmp/.X11-unix/X77 ] && break; sleep 0.1; done

# --- type-load probe ----------------------------------------------------------
# Files that name media library types (the image has no libmedialibrary, so
# MainUI::registerQMLTypes does not register them) and are only loaded behind
# MainCtx.mediaLibraryAvailable. Derived with
#   grep -rl 'VLC.MediaLibrary' modules/gui/qt/redesign --include=*.qml
# minus shell/RedesignInterface.qml (it only names the module in a URL/comment and
# loads at startup) and confirmed by the run itself: every other file must reach
# Component.Ready, and these may only fail with a missing type or module.
ML_ONLY=(
    dialogs/NewPlaylistDialog.qml
    dialogs/RecentStreams.qml
    library/HomeContent.qml
    settings/LibraryFolders.qml
    shell/MainMenuRecent.qml
)
QMLDIR="$B/modules/gui/qt/VLC/Redesign/qmldir"
[ -f "$QMLDIR" ] || { echo "qml-smoke.sh: $QMLDIR was not generated" >&2; exit 2; }
# The module is flat: genqrc.py puts every file at qrc:/qt/qml/VLC/Redesign/<basename>,
# so the probe loads by basename. typeload.list = the files the module ships, from
# the lines "Name 1.0 File.qml" and "singleton Name 1.0 File.qml" of the built qmldir
# (any other line than module/prefer/empty is reported); typeload.ondisk =
# "basename<TAB>path below redesign/" of the tree, to show paths.
# (LC_ALL=C for sort, comm and uniq: one collation, whatever the image locale.)
: > "$ROOT/typeload.problems"
QMLDIR_RE='^(singleton )?[A-Za-z0-9_]+ [0-9]+\.[0-9]+ [A-Za-z0-9_]+\.qml$'
{ grep -E "$QMLDIR_RE" "$QMLDIR" || true; } | awk '{ print $NF }' | LC_ALL=C sort > "$ROOT/typeload.list"
grep -vE "$QMLDIR_RE|^(module|prefer) |^[[:space:]]*$" "$QMLDIR" | while IFS= read -r l; do
    echo "typeload: unrecognised line in the built VLC/Redesign/qmldir: $l" >> "$ROOT/typeload.problems"
done || true
[ -s "$ROOT/typeload.list" ] || echo "typeload: the built VLC/Redesign/qmldir lists no QML file" >> "$ROOT/typeload.problems"
(cd /vlc/modules/gui/qt/redesign && find . -name '*.qml' | sed 's|^\./||' | awk -F/ '{ print $NF "\t" $0 }' | LC_ALL=C sort) > "$ROOT/typeload.ondisk"
LC_ALL=C cut -f1 "$ROOT/typeload.ondisk" | LC_ALL=C sort -u > "$ROOT/typeload.ondisk.names"
# two files with one basename would shadow each other in the flat module
LC_ALL=C cut -f1 "$ROOT/typeload.ondisk" | LC_ALL=C uniq -d | while IFS= read -r f; do
    echo "typeload: $f exists more than once below redesign/ (the module is flat, one would shadow the other)" >> "$ROOT/typeload.problems"
done
# a .qml file of the tree that the module does not list is never shipped nor loaded
LC_ALL=C comm -13 "$ROOT/typeload.list" "$ROOT/typeload.ondisk.names" | while IFS= read -r f; do
    echo "typeload: $(awk -F'\t' -v f="$f" '$1 == f { print $2; exit }' "$ROOT/typeload.ondisk") is not listed in the VLC.Redesign module (redesign/meson.build); it is neither shipped nor checked" >> "$ROOT/typeload.problems"
done
LC_ALL=C comm -23 "$ROOT/typeload.list" "$ROOT/typeload.ondisk.names" | while IFS= read -r f; do
    echo "typeload: the module lists $f but the tree has no such file" >> "$ROOT/typeload.problems"
done
: > "$ROOT/typeload.mlonly"
for f in "${ML_ONLY[@]}"; do
    if [ -f "/vlc/modules/gui/qt/redesign/$f" ]; then
        basename "$f" >> "$ROOT/typeload.mlonly"
    else
        echo "typeload: ML_ONLY names $f, which is not a file of the tree (update ML_ONLY in qml-smoke.sh)" >> "$ROOT/typeload.problems"
    fi
done
# The QML names that exist only with a media library: every qmlRegister*() of the
# VLC.MediaLibrary block of MainUI::registerQMLTypes (the first string argument).
sed -n '/const char\* uri = "VLC\.MediaLibrary"/,/qmlProtectModule/p' /vlc/modules/gui/qt/maininterface/mainui.cpp \
    | grep -E '^[[:space:]]*qmlRegister.*"[A-Za-z0-9_]+"' | sed -E 's/^[^"]*"([A-Za-z0-9_]+)".*$/\1/' > "$ROOT/typeload.mltypes"
if [ "$(wc -l < "$ROOT/typeload.mltypes")" -lt 10 ]; then
    echo "typeload: found only $(wc -l < "$ROOT/typeload.mltypes") media library type registrations in maininterface/mainui.cpp (did MainUI::registerQMLTypes change? fix the extraction in qml-smoke.sh)" >> "$ROOT/typeload.problems"
fi
# The probe is compiled here (the image has g++ and the Qt 6 development files)
# and injected into the redesign run only. It lives in /vlc/extras/redesign, is
# never part of the VLC build and changes nothing in the product.
echo "==> type-load probe: g++ qml-typeload.cpp ($(wc -l < "$ROOT/typeload.list" | tr -d ' ') QML files listed)"
PROBE_SECONDS=$SECONDS
if ! g++ -std=c++17 -fPIC -shared -O1 -Wall $(pkg-config --cflags Qt6Qml Qt6Core) \
        /vlc/extras/redesign/qml-typeload.cpp -o "$ROOT/libqml-typeload.so" \
        $(pkg-config --libs Qt6Qml Qt6Core); then
    echo "qml-smoke.sh: the type-load probe did not compile (exit 3)" >&2
    exit 3
fi
PROBE_SECONDS=$((SECONDS - PROBE_SECONDS))

# run_vlc NAME [vlc args...]  ->  $ROOT/NAME.log, $ROOT/NAME.rc, $ROOT/NAME.home
# RUN_PRELOAD=lib (optional): LD_PRELOAD for vlc itself (the type-load probe).
run_vlc() {
    local name="$1"; shift
    local home="$ROOT/$name.home"
    mkdir -p "$home/config" "$home/data" "$home/cache" "$ROOT/$name.run"
    chmod 700 "$ROOT/$name.run"   # XDG_RUNTIME_DIR must be private (Qt warns otherwise)
    local rc=0
    echo "==> run '$name': vlc $* (${SMOKE_SECONDS}s)"
    # Everything VLC and Qt could write goes below $home. VLC_*_PATH make the
    # build-tree vlc find its plugins, vlc-qt-check and vlc-preparser.
    # --qt-compositor=dummy: the x11 compositor crashes on the offscreen
    # platform (xcb_flush on a connection Qt does not own); the compositor only
    # matters for video embedding, not for the QML that is checked here.
    env HOME="$home" XDG_CONFIG_HOME="$home/config" XDG_DATA_HOME="$home/data" \
        XDG_CACHE_HOME="$home/cache" XDG_RUNTIME_DIR="$ROOT/$name.run" LANG=C.UTF-8 LC_ALL=C.UTF-8 \
        QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
        ${QML_SMOKE_QUICK_BACKEND:+QT_QUICK_BACKEND=$QML_SMOKE_QUICK_BACKEND} \
        VLC_PLUGIN_PATH="$B/modules" VLC_LIB_PATH="$B/modules" VLC_LIBEXEC_PATH="$B/modules" \
        PATH="$B/bin:$PATH" \
        timeout -k 10 "$SMOKE_SECONDS" \
        ${RUN_PRELOAD:+env LD_PRELOAD="$RUN_PRELOAD" QML_TYPELOAD_LIST="$ROOT/typeload.list" QML_TYPELOAD_ML_ONLY="$ROOT/typeload.mlonly" QML_TYPELOAD_ML_TYPES="$ROOT/typeload.mltypes"} \
        "$B/bin/vlc" \
            -I qt --verbose=2 --no-qt-privacy-ask \
            --qt-compositor=dummy --aout=dummy --vout=dummy --no-video-title-show \
            --no-plugins-cache --no-metadata-network-access \
            "$@" ${SMOKE_MEDIA:+"/vlc/$SMOKE_MEDIA"} \
        </dev/null >"$ROOT/$name.log" 2>&1 || rc=$?
    echo "$rc" >"$ROOT/$name.rc"
}

RUN_PRELOAD="$ROOT/libqml-typeload.so" run_vlc redesign --qt-redesign
run_vlc stock --no-qt-redesign

# --- analysis -----------------------------------------------------------------
# What counts as a QML/Qt diagnostic: every warning/error the qt module logs
# (Qt's messages, QML ones included, arrive as "[qt] qt generic warning|error:"),
# plus any stray line naming a qrc/QML location. VLC debug lines never count.
DIAG_RE='generic (warning|error):|qrc:|\.qml:[0-9]+|^qml:'
# The failure patterns of the brief.
FAIL_RE='ReferenceError|TypeError|is not a type|Cannot assign|Unable to assign|module ".*" is not installed|Binding loop|unable to create main interface|no root item|unexpected type of qml root item|no suitable compositor|qml loading'
OURS_RE='VLC/Redesign'
# Environmental, never counted as warning or error, printed as "env:" lines:
# the container image ships no Qt 6 SVG image plugin (only libqsvg for Qt 5), so
# every SVG fails to decode here. Anchored to exactly the two messages Qt and
# ImageHelper produce for that.
ENV_RE='generic warning: \(default\) (qrc:[^ ]+:[0-9]+:[0-9]+: QML [^:]+: )?Error decoding: [^ ]+\.svg: Unsupported image format$|generic warning: \(default\) ImageHelper: svg image plugin is not found\.$'

# norm: strip what differs between runs (VLC object pointers).
norm() { sed -E 's/^\[[0-9a-f]+\] //; s/0x[0-9a-f]+/0xPTR/g'; }
count() { wc -l < "$1" | tr -d ' '; }

: > "$ROOT/notstarted"
for name in redesign stock; do
    log="$ROOT/$name.log"
    rc="$(cat "$ROOT/$name.rc")"
    # 124/137/143 = still running when timeout stopped it (the expected end).
    # 0 = vlc quit by itself inside the window, i.e. it did not run N seconds.
    case "$rc" in
        124|137|143) ;;
        0) echo "!! run '$name': vlc quit by itself (status 0) before the ${SMOKE_SECONDS}s were up"; echo "$name" >> "$ROOT/notstarted" ;;
        *) echo "!! run '$name' exited with status $rc (crash or startup failure)"; echo "$name" >> "$ROOT/notstarted" ;;
    esac
    if ! grep -aq 'using interface module "qt"' "$log"; then
        echo "!! run '$name': the Qt interface did not start (no 'using interface module \"qt\"' in the log)"
        echo "$name" >> "$ROOT/notstarted"
    fi
    { grep -avE ' debug: |TYPELOAD ' "$log" | grep -aE "$DIAG_RE" | norm | sort -u; } > "$ROOT/$name.alldiag" || true
    { grep -aE "$ENV_RE" "$ROOT/$name.alldiag" || true; } > "$ROOT/$name.env"
    { grep -avE "$ENV_RE" "$ROOT/$name.alldiag" || true; } > "$ROOT/$name.diag"
done

# Redesign run. Error: the line names our code (VLC/Redesign), or it is a
# failure-pattern / qt error line that the stock run does not have (new).
# Warning: everything else (upstream noise present in both runs).
: > "$ROOT/redesign.errors"; : > "$ROOT/redesign.warnings"
while IFS= read -r line; do
    if printf '%s\n' "$line" | grep -aqE "$OURS_RE"; then
        echo "$line" >> "$ROOT/redesign.errors"
    elif printf '%s\n' "$line" | grep -aqE "$FAIL_RE| generic error:" \
            && ! grep -aqxF -- "$line" "$ROOT/stock.diag"; then
        echo "$line" >> "$ROOT/redesign.errors"
    else
        echo "$line" >> "$ROOT/redesign.warnings"
    fi
done < "$ROOT/redesign.diag"

# Type-load pass: its result lines are in the redesign log (TYPELOAD lines).
# Every failing file is an error of the redesign run, as is a missing result.
{ grep -a 'TYPELOAD ' "$ROOT/redesign.log" || true; } | sed -E 's/^.*TYPELOAD /TYPELOAD /' > "$ROOT/typeload.out"
tl_summary="$(grep -a '^TYPELOAD summary ' "$ROOT/typeload.out" | tail -n 1 || true)"
# (the probe names files by basename; show the path below redesign/)
{ grep -a '^TYPELOAD error ' "$ROOT/typeload.out" || true; } | sed 's/^TYPELOAD error //' |
    awk -F '\t' 'NR == FNR { path[$1] = $2; next }
                 { name = $0; sub(/: .*/, "", name); rest = substr($0, length(name) + 1)
                   print "typeload: " ((name in path) ? path[name] : name) rest }' \
        "$ROOT/typeload.ondisk" - >> "$ROOT/redesign.errors"
cat "$ROOT/typeload.problems" >> "$ROOT/redesign.errors"
if [ -z "$tl_summary" ] && ! grep -qx redesign "$ROOT/notstarted"; then
    echo "typeload: no result from the probe ($(grep -a '^TYPELOAD notrun ' "$ROOT/typeload.out" | head -n 1 | sed 's/^TYPELOAD notrun //' || true)); the redesign run must reach the registered interface" >> "$ROOT/redesign.errors"
fi
tl_ready="$(grep -ac '^TYPELOAD ready ' "$ROOT/typeload.out" || true)"
tl_skipped="$(grep -ac '^TYPELOAD skipped-ml ' "$ROOT/typeload.out" || true)"
tl_errors="$(grep -ac '^TYPELOAD error ' "$ROOT/typeload.out" || true)"
tl_files="$(count "$ROOT/typeload.list")"

# Stock run: failure patterns are errors, the rest is upstream noise (printed).
{ grep -aE "$FAIL_RE" "$ROOT/stock.diag" || true; } > "$ROOT/stock.errors"
{ grep -avE "$FAIL_RE" "$ROOT/stock.diag" || true; } > "$ROOT/stock.warnings"

status=0
echo
tl_ms="did not report"
[ -z "$tl_summary" ] || tl_ms="loaded in ${tl_summary##* ms=} ms"
echo "---- typeload: every file of the VLC.Redesign module loaded as a Component (probe built in $PROBE_SECONDS s, $tl_ms) ----"
{ grep -a '^TYPELOAD skipped-ml ' "$ROOT/typeload.out" || true; } | sed 's/^TYPELOAD skipped-ml //' |
    awk -F '\t' 'NR == FNR { path[$1] = $2; next }
                 { print "skipped (ML-only): " (($0 in path) ? path[$0] : $0) }' "$ROOT/typeload.ondisk" -
echo "typeload: $tl_files files, $tl_ready ready, $tl_skipped skipped (ML-only), $tl_errors errors"
for name in redesign stock; do
    echo
    echo "---- $name: $(count "$ROOT/$name.errors") error line(s) ----"
    cat "$ROOT/$name.errors"
    echo "---- $name: $(count "$ROOT/$name.warnings") warning line(s) ----"
    cat "$ROOT/$name.warnings"
    echo "---- $name: env: $(count "$ROOT/$name.env") line(s) (no Qt 6 SVG plugin in the image, not counted) ----"
    cat "$ROOT/$name.env"
    if [ -n "${QML_SMOKE_FULL_LOG:-}" ]; then
        echo "---- $name: full log ----"
        cat -v "$ROOT/$name.log"
    elif grep -qx "$name" "$ROOT/notstarted"; then
        echo "---- $name: last 25 log lines ----"
        tail -n 25 "$ROOT/$name.log" | cat -v
    fi
    [ "$(count "$ROOT/$name.errors")" -eq 0 ] || status=1
done
if [ "$status" -eq 0 ] && [ -s "$ROOT/notstarted" ]; then status=2; fi

echo
echo "---- isolation: files written below each run's temp HOME (count per directory) ----"
for name in redesign stock; do
    echo "[$name] $(find "$ROOT/$name.home" -type f | wc -l | tr -d ' ') file(s):"
    (cd "$ROOT/$name.home" && find . -type f | sed -E 's|/[^/]*$||' | sort | uniq -c)
done
echo "(the container saw only: /vlc read-only, /build, its own /tmp; no network)"
echo
echo "redesign: $(count "$ROOT/redesign.errors") errors, $(count "$ROOT/redesign.warnings") warnings; stock: $(count "$ROOT/stock.errors") errors, $(count "$ROOT/stock.warnings") warnings; env: $(count "$ROOT/redesign.env") + $(count "$ROOT/stock.env") SVG-plugin lines"
exit "$status"
CONTAINER_EOF
