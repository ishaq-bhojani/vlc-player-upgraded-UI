#!/usr/bin/env python3
"""Write the SVG sources of the icon font (modules/gui/qt/pixmaps/icons/*.svg) from the redesign sources.

    python3 extras/redesign/build_icons.py            # (re)write the SVGs
    python3 extras/redesign/build_icons.py --check    # exit 1 if a committed SVG is out of date

For every glyph named in extras/redesign/icon-map.json the SVG that VLCIcons.json points to is
replaced by a normalised copy of

  * a Phosphor Icons SVG (modules/gui/qt/redesign/assets/phosphor/<weight>/<name>.svg, MIT), or
  * a Figma icon already converted to an outline by extract_figma_icons.py
    (modules/gui/qt/redesign/assets/figma-icons/<name>.svg).

Glyphs that are not in the map keep their upstream SVG untouched.

Normalised means what makeIconFont.py (fontforge) needs: one filled path, black, and a width and
height equal to the viewBox (Phosphor ships a bare viewBox="0 0 256 256" with fill="currentColor").
Phosphor's icons are single, non-overlapping outline paths, so no further processing is needed.
Then run `python3 makeIconFont.py VLCIcons.json` in modules/gui/qt/pixmaps (see its header).
"""
import json
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
QT = os.path.join(ROOT, "modules", "gui", "qt")
PIXMAPS = os.path.join(QT, "pixmaps")
ASSETS = os.path.join(QT, "redesign", "assets")
MAP = os.path.join(ROOT, "extras", "redesign", "icon-map.json")


def source_path(spec):
    if spec["source"] == "phosphor":
        return os.path.join(ASSETS, "phosphor", spec.get("weight", "regular"), spec["name"] + ".svg")
    if spec["source"] == "figma":
        return os.path.join(ASSETS, "figma-icons", spec["name"] + ".svg")
    raise ValueError("unknown icon source %r" % spec["source"])


def normalise(text, where):
    m = re.search(r'<svg\b([^>]*)>(.*)</svg>', text, re.S)
    if not m:
        raise ValueError("%s: not an SVG" % where)
    attrs = dict(re.findall(r'([\w:-]+)="([^"]*)"', m.group(1)))
    vb = attrs.get("viewBox", "").split()
    if len(vb) != 4 or vb[0] != "0" or vb[1] != "0":
        raise ValueError("%s: viewBox must be 0 0 w h" % where)
    inner = m.group(2).strip().replace("currentColor", "black")
    if not re.fullmatch(r'<path\b[^>]*/>', inner):
        raise ValueError("%s: expected exactly one <path>" % where)
    if 'fill=' not in inner:
        inner = inner.replace("<path ", '<path fill="black" ', 1)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 %s %s">%s</svg>\n'
            % (vb[2], vb[3], vb[2], vb[3], inner))


def main(argv):
    check = "--check" in argv
    with open(MAP, encoding="utf-8") as fd:
        mapping = json.load(fd)["glyphs"]
    with open(os.path.join(PIXMAPS, "VLCIcons.json"), encoding="utf-8") as fd:
        glyphs = {g["key"]: g["path"] for g in json.load(fd)["glyphs"]}

    stale, problems = [], []
    for key, spec in mapping.items():
        if key not in glyphs:
            problems.append("%s: not a glyph of VLCIcons.json" % key)
            continue
        src = source_path(spec)
        try:
            with open(src, encoding="utf-8") as fd:
                svg = normalise(fd.read(), src)
        except (OSError, ValueError) as e:
            problems.append("%s: %s" % (key, e))
            continue
        dst = os.path.normpath(os.path.join(PIXMAPS, glyphs[key]))
        old = None
        if os.path.exists(dst):
            with open(dst, encoding="utf-8", newline="") as fd:
                old = fd.read()
        if old != svg:
            stale.append(os.path.relpath(dst, ROOT))
            if not check:
                with open(dst, "w", encoding="utf-8", newline="\n") as fd:
                    fd.write(svg)

    for p in problems:
        print("build_icons:", p, file=sys.stderr)
    if problems:
        return 1
    if check:
        for s in stale:
            print("out of date:", s)
        return 1 if stale else 0
    print("build_icons: %d glyphs mapped, %d SVGs written" % (len(mapping), len(stale)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
