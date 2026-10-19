#!/usr/bin/env python3
"""Write the SVG sources and the glyph list of the redesign icon font.

    python3 extras/redesign/build_icons.py            # (re)write the files
    python3 extras/redesign/build_icons.py --check    # exit 1 if a committed file is out of date

The stock icon font (modules/gui/qt/pixmaps/VLCIcons.json, icons/*.svg, VLCIcons.ttf) is upstream's
and is never touched. The redesign has a second font, VLCIconsRedesign.ttf, built from

  * modules/gui/qt/redesign/assets/VLCIconsRedesign.json: upstream's glyph list in the same order
    (so every existing glyph keeps its code point), then the new `rd_*` glyphs of icon-map.json;
  * modules/gui/qt/redesign/assets/icons/<glyph>.svg: for every glyph of extras/redesign/icon-map.json
    a normalised copy of
      - a Phosphor Icons SVG (modules/gui/qt/redesign/assets/phosphor/<weight>/<name>.svg, MIT), or
      - a Figma icon already converted to an outline by extract_figma_icons.py
        (modules/gui/qt/redesign/assets/figma-icons/<name>.svg).
    Glyphs that are not in the map point at upstream's SVG in pixmaps/icons/ (no copy).

Normalised means what makeIconFont.py (fontforge) needs: one filled path, black, and a width and
height equal to the viewBox (Phosphor ships a bare viewBox="0 0 256 256" with fill="currentColor").
Phosphor's icons are single, non-overlapping outline paths, so no further processing is needed.

Then generate the font, the header style/vlcicons.hpp and style/vlcicons.cpp with
extras/redesign/make_icon_font.py (needs fontforge; see its header).
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
OUT_JSON = os.path.join(ASSETS, "VLCIconsRedesign.json")
OUT_ICONS = os.path.join(ASSETS, "icons")


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


def read(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8", newline="") as fd:
        return fd.read()


def main(argv):
    check = "--check" in argv
    with open(os.path.join(PIXMAPS, "VLCIcons.json"), encoding="utf-8") as fd:
        upstream = json.load(fd)
    with open(MAP, encoding="utf-8") as fd:
        mapping = json.load(fd)["glyphs"]

    upstream_paths = {g["key"]: g["path"] for g in upstream["glyphs"]}
    new_keys = [k for k in mapping if k not in upstream_paths]
    for k in new_keys:
        if not k.startswith("rd_"):
            print("build_icons: %s: glyphs that upstream lacks must be named rd_*" % k, file=sys.stderr)
            return 1

    files = {}      # path -> content
    problems = []
    entries = []    # (key, path relative to the redesign assets directory)
    for key in [g["key"] for g in upstream["glyphs"]] + new_keys:
        spec = mapping.get(key)
        if spec is None:
            # kept upstream: reference upstream's SVG, no copy
            rel = os.path.relpath(os.path.join(PIXMAPS, upstream_paths[key]), ASSETS).replace(os.sep, "/")
            entries.append((key, rel))
            continue
        src = source_path(spec)
        try:
            with open(src, encoding="utf-8") as fd:
                svg = normalise(fd.read(), src)
        except (OSError, ValueError) as e:
            problems.append("%s: %s" % (key, e))
            continue
        files[os.path.join(OUT_ICONS, key + ".svg")] = svg
        entries.append((key, "./icons/%s.svg" % key))
    for k in mapping:
        if k not in upstream_paths and k not in new_keys:   # cannot happen, kept for clarity
            problems.append("%s: not a glyph" % k)

    lines = ",\n".join('        {"key":"%s", "path": "%s"}' % e for e in entries)
    files[OUT_JSON] = ('{\n'
                       '    "hpp_name": "../../style/vlcicons.hpp",\n'
                       '    "cpp_name": "../../style/vlcicons.cpp",\n'
                       '    "qml_prefix": "qrc:///redesign/",\n'
                       '    "font_file": "VLCIconsRedesign.ttf",\n'
                       '    "font_name": "VLCIcons",\n'
                       '    "glyphs" : [\n%s\n    ]\n}\n' % lines)

    for p in problems:
        print("build_icons:", p, file=sys.stderr)
    if problems:
        return 1

    stale = [p for p, c in files.items() if read(p) != c]
    # icons that no longer belong to the map
    if os.path.isdir(OUT_ICONS):
        for f in os.listdir(OUT_ICONS):
            p = os.path.join(OUT_ICONS, f)
            if p not in files:
                stale.append(p)
    if check:
        for s in stale:
            print("out of date:", os.path.relpath(s, ROOT))
        return 1 if stale else 0
    os.makedirs(OUT_ICONS, exist_ok=True)
    for p, c in files.items():
        if read(p) != c:
            with open(p, "w", encoding="utf-8", newline="\n") as fd:
                fd.write(c)
    for p in stale:
        if p not in files and os.path.exists(p):
            os.remove(p)
    print("build_icons: %d glyphs (%d mapped, %d new), %d files written"
          % (len(entries), len(mapping), len(new_keys), len(stale)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
