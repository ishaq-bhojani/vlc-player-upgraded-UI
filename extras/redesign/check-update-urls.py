#!/usr/bin/env python3
"""Static checks of the VLC Reborn update channel (run by the meson test
test_qt_update_channel_urls, and usable by hand):

    extras/redesign/check-update-urls.py SRC_ROOT [LIBVLCCORE]

The fork must never contact VideoLAN's update infrastructure, and the status file
and its signature must come from the same stem:

  1. no update.videolan.org / update-test.videolan.org / download.videolan.org in
     src/misc/update*.c, src/misc/update.h, include/vlc_pgpkey.h, and, when a
     libvlccore is given, in the built library (the key fetch of upstream,
     download_key(), is gone);
  2. update.c uses UPDATE_VLC_STATUS_URL only to build the platform URL `url`; the
     status file is opened with `url` and the signature is downloaded with the very
     same `url` (download_signature appends ".asc", giving status-win-x64.asc, which
     is what extras/redesign/make-status.sh publishes);
  3. a status file signed by any other key is refused without a fetch.
"""
import re
import sys
from pathlib import Path

FORBIDDEN = re.compile(rb"(update|update-test|download)\.videolan\.org")

errors = []


def fail(msg):
    errors.append(msg)


def main(argv):
    if len(argv) not in (2, 3):
        print(__doc__, file=sys.stderr)
        return 64
    root = Path(argv[1])
    lib = Path(argv[2]) if len(argv) == 3 else None

    files = {
        "update.c": root / "src/misc/update.c",
        "update_crypto.c": root / "src/misc/update_crypto.c",
        "update.h": root / "src/misc/update.h",
        "vlc_pgpkey.h": root / "include/vlc_pgpkey.h",
        "make-status.sh": root / "extras/redesign/make-status.sh",
        "meson_options.txt": root / "meson_options.txt",
    }
    text = {}
    for name, path in files.items():
        if not path.is_file():
            fail(f"{path} not found")
            continue
        text[name] = path.read_text(encoding="utf-8")
    if errors:
        return report()

    # 1. no VideoLAN update host in the sources or in the library
    for name in ("update.c", "update_crypto.c", "update.h", "vlc_pgpkey.h"):
        for n, line in enumerate(text[name].splitlines(), 1):
            if FORBIDDEN.search(line.encode()):
                fail(f"{files[name]}:{n}: VideoLAN update host: {line.strip()}")
    for name in ("update.c", "update_crypto.c", "update.h"):
        if re.search(r"\bdownload_key\b", text[name]):
            fail(f"{name}: download_key() must not exist (it fetched keys from VideoLAN)")
    if lib is not None:
        if not lib.is_file():
            fail(f"{lib} not found")
        else:
            data = lib.read_bytes()
            m = FORBIDDEN.search(data)
            if m:
                fail(f"{lib}: contains the string {m.group(0).decode()}")

    # 2. one URL for the status file and its signature
    upd = text["update.c"]
    allowed = re.compile(
        r'^\s*#define UPDATE_VLC_STATUS_URL |"-win-|static const char url\[\] = UPDATE_VLC_STATUS_URL;'
    )
    for n, line in enumerate(upd.splitlines(), 1):
        if "UPDATE_VLC_STATUS_URL" in line and not allowed.search(line):
            fail(f"update.c:{n}: UPDATE_VLC_STATUS_URL is only for building `url`: {line.strip()}")
    if not re.search(r"vlc_stream_NewURL\(\s*p_update->p_libvlc\s*,\s*url\s*\)", upd):
        fail("update.c: the status file must be opened with `url`")
    if not re.search(
        r"download_signature\(\s*VLC_OBJECT\(\s*p_update->p_libvlc\s*\)\s*,\s*&sign\s*,\s*url\s*\)", upd
    ):
        fail("update.c: the status signature must be downloaded with the same `url` as the status file")
    if not re.search(r'strcat\(\s*psz_sig\s*,\s*"\.asc"\s*\)', text["update_crypto.c"]):
        fail("update_crypto.c: download_signature no longer appends .asc to the url")
    if '"$STATUS.asc"' not in text["make-status.sh"] or 'STATUS="$STAGE/status-win-x64"' not in text["make-status.sh"]:
        fail("make-status.sh no longer publishes status-win-x64 + status-win-x64.asc")
    if not re.search(r"value: '[^']*/status',", text["meson_options.txt"]):
        fail("meson_options.txt: redesign_update_url must end with /status (update.c appends -win-x64)")

    # 3. an unknown signer is refused, nothing is fetched
    if "Status file signed by an unknown key" not in upd:
        fail("update.c: a status file signed by another key must be refused")

    return report()


def report():
    if errors:
        for e in errors:
            print("check-update-urls: " + e, file=sys.stderr)
        return 1
    print("check-update-urls: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
