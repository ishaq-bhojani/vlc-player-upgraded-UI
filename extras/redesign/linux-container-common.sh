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

    # --- cached fork options -------------------------------------------------
    # meson keeps an option's value in the build directory, so a volume configured
    # before a default of meson_options.txt changed (product name, release
    # version, update URL) keeps the old value and the tests that check the
    # default fail. These runners never set a redesign_* option themselves, so
    # every cached redesign_* value is brought back to the default declared in
    # meson_options.txt (the single source) before building.
    python3 - "$B" /vlc/meson_options.txt <<'PY_EOF'
import json, re, subprocess, sys

build, opts = sys.argv[1], sys.argv[2]
text = open(opts, encoding="utf-8").read()
defaults = {}
for m in re.finditer(r"option\('(redesign_\w+)',(.*?)\n\n", text, re.S):
    v = re.search(r"value:\s*(?:'([^']*)'|(-?\d+))", m.group(2))
    if v:
        defaults[m.group(1)] = v.group(1) if v.group(1) is not None else v.group(2)
cached = {o["name"]: o["value"]
          for o in json.loads(subprocess.check_output(
              ["meson", "introspect", "--buildoptions", build]))
          if o["name"].startswith("redesign_")}
args = ["-D%s=%s" % (k, d) for k, d in defaults.items()
        if k in cached and str(cached[k]) != d]
# an option added since the build directory was configured is picked up by
# meson's own regeneration with its default, nothing to do for it here
if args:
    print("==> meson configure (cached fork options differ from meson_options.txt): "
          + " ".join(args))
    subprocess.check_call(["meson", "configure", build] + args)
PY_EOF

    # --- build ---------------------------------------------------------------
    echo "==> meson compile"
    meson compile -C "$B"
}
