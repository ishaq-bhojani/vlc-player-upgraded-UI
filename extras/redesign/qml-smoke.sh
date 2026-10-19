#!/usr/bin/env bash
#
# QML runtime smoke test for VLC Reborn (native Linux, offscreen, in Docker).
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
# and scans the captured logs for QML diagnostics. Nothing touches the host: the
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
# before the N seconds were up) and there are no errors, 64 usage.
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
# Summary line:  redesign: N errors, M warnings; stock: N errors, M warnings
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

# run_vlc NAME [vlc args...]  ->  $ROOT/NAME.log, $ROOT/NAME.rc, $ROOT/NAME.home
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
        timeout -k 10 "$SMOKE_SECONDS" "$B/bin/vlc" \
            -I qt --verbose=2 --no-qt-privacy-ask \
            --qt-compositor=dummy --aout=dummy --vout=dummy --no-video-title-show \
            --no-plugins-cache --no-metadata-network-access \
            "$@" ${SMOKE_MEDIA:+"/vlc/$SMOKE_MEDIA"} \
        </dev/null >"$ROOT/$name.log" 2>&1 || rc=$?
    echo "$rc" >"$ROOT/$name.rc"
}

run_vlc redesign --qt-redesign
run_vlc stock --no-qt-redesign

# --- analysis -----------------------------------------------------------------
# What counts as a QML/Qt diagnostic: every warning/error the qt module logs
# (Qt's messages, QML ones included, arrive as "[qt] qt generic warning|error:"),
# plus any stray line naming a qrc/QML location. VLC debug lines never count.
DIAG_RE='generic (warning|error):|qrc:|\.qml:[0-9]+|^qml:'
# The failure patterns of the brief.
FAIL_RE='ReferenceError|TypeError|is not a type|Cannot assign|Unable to assign|module ".*" is not installed|Binding loop|unable to create main interface|no root item|unexpected type of qml root item|no suitable compositor|qml loading'
OURS_RE='VLC/Redesign'

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
    { grep -avE ' debug: ' "$log" | grep -aE "$DIAG_RE" | norm | sort -u; } > "$ROOT/$name.diag" || true
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

# Stock run: failure patterns are errors, the rest is upstream noise (printed).
{ grep -aE "$FAIL_RE" "$ROOT/stock.diag" || true; } > "$ROOT/stock.errors"
{ grep -avE "$FAIL_RE" "$ROOT/stock.diag" || true; } > "$ROOT/stock.warnings"

status=0
for name in redesign stock; do
    echo
    echo "---- $name: $(count "$ROOT/$name.errors") error line(s) ----"
    cat "$ROOT/$name.errors"
    echo "---- $name: $(count "$ROOT/$name.warnings") warning line(s) ----"
    cat "$ROOT/$name.warnings"
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
echo "redesign: $(count "$ROOT/redesign.errors") errors, $(count "$ROOT/redesign.warnings") warnings; stock: $(count "$ROOT/stock.errors") errors, $(count "$ROOT/stock.warnings") warnings"
exit "$status"
CONTAINER_EOF
