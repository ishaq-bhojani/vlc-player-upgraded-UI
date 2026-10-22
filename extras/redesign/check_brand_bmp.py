#!/usr/bin/env python3
"""Check a 24-bit BMP of the Vireo brand without Qt.

    python3 extras/redesign/check_brand_bmp.py FILE WIDTH HEIGHT X Y RRGGBB [X Y RRGGBB ...]

The file is decoded from the BMP format (bottom-up rows padded to 4 bytes, pixel bytes in the order
B, G, R), so a red/blue swap in the writer is caught: the pixel at X,Y (counted from the top left)
must be exactly RRGGBB, normally the mark colour D37918 (installer panels and banner of
extras/redesign/make-icons.cpp). Also used on the bitmaps extracted from a built installer.
Exits 0 when the size and every pixel match.
"""
import struct
import sys


def main(argv):
    if len(argv) < 7 or (len(argv) - 4) % 3:
        print(__doc__.strip().split("\n\n")[0], file=sys.stderr)
        return 2
    path, w, h = argv[1], int(argv[2]), int(argv[3])
    d = open(path, "rb").read()
    if d[:2] != b"BM" or len(d) < 54:
        print("%s: not a BMP" % path)
        return 1
    off, = struct.unpack_from("<I", d, 10)
    fw, fh, planes, bpp, comp = struct.unpack_from("<iiHHI", d, 18)
    if (fw, fh, bpp, comp) != (w, h, 24, 0):
        print("%s: is %dx%d %d-bit (compression %d), expected %dx%d 24-bit" % (path, fw, fh, bpp, comp, w, h))
        return 1
    stride = (w * 3 + 3) & ~3
    if off + stride * h > len(d):
        print("%s: file too short" % path)
        return 1
    bad = 0
    for i in range(4, len(argv), 3):
        x, y, want = int(argv[i]), int(argv[i + 1]), argv[i + 2].upper()
        o = off + (h - 1 - y) * stride + x * 3          # the first stored row is the bottom line
        b, g, r = d[o], d[o + 1], d[o + 2]
        got = "%02X%02X%02X" % (r, g, b)
        if got != want:
            print("%s: pixel %d,%d is #%s, expected #%s" % (path, x, y, got, want))
            bad = 1
    if not bad:
        print("%s: %dx%d, mark pixel #%s OK" % (path, w, h, argv[6].upper()))
    return bad


if __name__ == "__main__":
    sys.exit(main(sys.argv))
