# Shared host-side setup for the native Linux runners (linux-tests.sh,
# qml-smoke.sh). Sourced, not executed. Sets IMAGE, REPO, REPO_MOUNT, VOLUME
# and provides linux_prepare_volume. The caller's NAME (script name) is used in
# messages.
#
# One build volume per source tree; see the header of linux-tests.sh.

IMAGE="registry.videolan.org/vlc-debian-unstable:20260611225331"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Docker Desktop wants a Windows-form path for bind mounts when run from Git Bash.
if REPO_MOUNT="$(cd "$REPO" && pwd -W 2>/dev/null)"; then :; else REPO_MOUNT="$REPO"; fi
# Git Bash would otherwise rewrite /vlc, /build, ... in docker arguments.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

# One build volume per source tree. ninja decides what is up to date from file
# mtimes, so sharing a build directory between two checkouts would silently
# reuse the other tree's objects.
VOLUME="${VLC_LINUX_VOLUME:-vlc-reborn-linux-build-$(printf '%s' "$REPO_MOUNT" | sha1sum | cut -c1-10)}"

linux_prepare_volume() {
    local name="${1:-linux-common.sh}"
    # CRLF shell scripts / patches cannot be used in the Linux container;
    # .gitattributes forces LF.
    # (tr, not grep: Git Bash's grep drops the CR from its pattern.)
    if [ -n "$(head -c 200 "$REPO/buildsystem/gen-vlc-about.py" | tr -dc '\r')" ]; then
        echo "$name: the working tree has CRLF line endings (core.autocrlf)." >&2
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
}
