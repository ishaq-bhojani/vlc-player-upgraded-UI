#!/usr/bin/env python3
"""Validate the icon sources of the VLC icon font.

    python3 extras/redesign/check_icons.py modules/gui/qt/pixmaps

Exits 0 only if

  * every glyph of <pixmaps>/VLCIcons.json has an SVG file, and
  * the viewBox of every one of those SVGs is as wide and as high as its
    width / height attributes (makeIconFont.py / fontforge scale the glyph by
    that ratio; a mismatch gives a glyph of the wrong size).

An SVG without width and height attributes passes (fontforge then takes the
viewBox); one with a width but no height (or the other way round) does not.
Offending files are printed one per line and the exit status is 1.
"""
import json
import os
import re
import sys


def parse_length(value):
    """'24', '24px', '24.0' -> 24.0; None when it is not a plain pixel length."""
    m = re.fullmatch(r"\s*([0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)\s*(?:px)?\s*", value)
    return float(m.group(1)) if m else None


def svg_root_attributes(text):
    m = re.search(r"<svg\b([^>]*)>", text, re.S)
    if not m:
        return None
    return dict(re.findall(r'([\w:-]+)\s*=\s*"([^"]*)"', m.group(1)))


def check_svg(path):
    """Return a problem description, or None when the SVG is fine."""
    try:
        with open(path, encoding="utf-8") as fd:
            attrs = svg_root_attributes(fd.read())
    except (OSError, UnicodeDecodeError) as e:
        return "unreadable (%s)" % e
    if attrs is None:
        return "no <svg> element"

    view_box = attrs.get("viewBox")
    if view_box is None:
        return "no viewBox"
    parts = re.split(r"[\s,]+", view_box.strip())
    try:
        vb_w, vb_h = float(parts[2]), float(parts[3])
        if len(parts) != 4:
            raise ValueError
    except (ValueError, IndexError):
        return "malformed viewBox '%s'" % view_box

    width, height = attrs.get("width"), attrs.get("height")
    if width is None and height is None:
        return None
    if width is None or height is None:
        return "only one of width/height is set"
    w, h = parse_length(width), parse_length(height)
    if w is None or h is None:
        return "width/height '%s' x '%s' is not a plain pixel size" % (width, height)
    if (w, h) != (vb_w, vb_h):
        return "viewBox %gx%g differs from width/height %gx%g" % (vb_w, vb_h, w, h)
    return None


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip().split("\n\n")[0], file=sys.stderr)
        return 2
    root = argv[1]
    try:
        with open(os.path.join(root, "VLCIcons.json"), encoding="utf-8") as fd:
            glyphs = json.load(fd)["glyphs"]
    except (OSError, ValueError, KeyError) as e:
        print("check_icons: cannot read %s/VLCIcons.json: %s" % (root, e), file=sys.stderr)
        return 2

    bad = []
    keys = set()
    for glyph in glyphs:
        key, rel = glyph["key"], glyph["path"]
        if key in keys:
            bad.append("%s: duplicate glyph key" % key)
        keys.add(key)
        path = os.path.normpath(os.path.join(root, rel))
        if not os.path.isfile(path):
            bad.append("%s: missing SVG %s" % (key, rel))
            continue
        problem = check_svg(path)
        if problem:
            bad.append("%s: %s: %s" % (key, rel, problem))

    for line in bad:
        print(line)
    if bad:
        print("check_icons: %d problem(s) in %d glyphs" % (len(bad), len(glyphs)), file=sys.stderr)
        return 1
    print("check_icons: %d glyphs OK" % len(glyphs))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
