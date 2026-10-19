# Shared in-container steps of the native Linux runners. Sourced by the script
# that runs inside the container (the repository is mounted at /vlc, the build
# volume at /build). Defines B (build dir) and linux_lock_configure_compile.

B=/build/linux

# $1: script name for messages. Takes the per-volume lock (held by fd 9 until
# the container exits), configures the build directory on the first run and
# compiles (all default targets: bin/vlc, the plugins, the tests).
linux_lock_configure_compile() {
    local name="$1"

    # Serialize runs on this volume (setup, compile and test all use /build/linux).
    exec 9>/build/.lock
    if ! flock -n 9; then
        echo "==> another Linux runner uses this build volume; $name waits..."
        flock 9
    fi

    git config --global --add safe.directory /vlc   # meson/version scripts call git

    # --- configure (first run only) ------------------------------------------
    # Options of upstream's native meson CI job (debian-meson in
    # extras/ci/gitlab-ci.yml) minus coverage; -Dqt=enabled turns a missing Qt
    # into an error instead of silently building without the GUI and its tests.
    if [ ! -f "$B/build.ninja" ]; then
        echo "==> meson setup (first run)"
        rm -rf "$B"
        meson setup "$B" /vlc -Dextra_checks=true -Dqt=enabled
    fi

    # --- build ---------------------------------------------------------------
    echo "==> meson compile"
    meson compile -C "$B"
}
