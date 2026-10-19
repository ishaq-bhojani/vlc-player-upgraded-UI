#!/usr/bin/env python3
"""Cut single icons out of the Figma component sheet and turn them into plain filled outlines.

    python3 extras/redesign/extract_figma_icons.py docs/redesign/figma-svg/Icon.svg \\
        extras/redesign/icon-map.json modules/gui/qt/redesign/assets/figma-icons

Needs shapely (Debian: python3-shapely). It is only run when the set of Figma icons changes; the
result is committed, so the build does not depend on it.

The sheet (Icon.svg) is a grid of 24x24 cells, 12 columns, pitch 44, first cell at (20, 20). Its
icons are *stroked* paths (1.5 wide, round caps and joins; some "inside" strokes are drawn as a
3 wide stroke clipped by a mask of the shape) plus filled shapes. makeIconFont.py / fontforge
cannot use strokes, so every cell is converted to filled geometry:

  * strokes are expanded (shapely buffer, round caps and joins), masked strokes are intersected with
    their mask shape,
  * fills follow the nonzero rule (nesting by contour area, opposite winding = hole),
  * everything of a cell is united into one outline (no overlaps, one colour).

The output is a 24x24 SVG, one path, curves flattened to polylines (tolerance 0.002 units).
Elements filled #303030 / #373737 are the cell backgrounds of the sheet and are dropped.

icon-map.json entries with "source": "figma" and "cell": [column, row] are extracted to <name>.svg;
"drop": "segments" leaves out the single straight strokes of the cell (the volume ticks).
"""
import json
import math
import os
import re
import sys

from shapely.geometry import LineString, LinearRing, Point, Polygon, box
from shapely.ops import unary_union

PITCH, ORIGIN, CELL = 44, 20, 24
BACKGROUNDS = {"#303030", "#373737"}
TOLERANCE = 0.002


# ---------------------------------------------------------------- parsing

def attrs_of(text):
    return dict(re.findall(r'([\w:-]+)="([^"]*)"', text))


def parse_sheet(svg):
    """-> (elements, masks); an element is a dict with its tag and attributes."""
    masks = {}
    for m in re.finditer(r'<mask\b([^>]*)>(.*?)</mask>', svg, re.S):
        mid = attrs_of(m.group(1))["id"]
        masks[mid] = attrs_of(re.search(r'<path\b([^>]*)/?>', m.group(2)).group(1))["d"]
    body = re.sub(r'<mask\b.*?</mask>', '', svg, flags=re.S)
    elements = []
    for m in re.finditer(r'<(path|rect|circle)\b([^>]*?)/?>', body):
        a = attrs_of(m.group(2))
        a["tag"] = m.group(1)
        elements.append(a)
    return elements, masks


NUM = re.compile(r'-?\d*\.?\d+(?:e-?\d+)?')


def flatten_path(d):
    """Flatten an absolute M/L/H/V/C/Z path -> list of (points, closed)."""
    tokens = re.findall(r'[MLHVCZ]|' + NUM.pattern, d)
    subpaths, cur, closed = [], [], False
    pos = (0.0, 0.0)
    i, cmd = 0, None

    def num():
        nonlocal i
        v = float(tokens[i])
        i += 1
        return v

    while i < len(tokens):
        if re.fullmatch(r'[MLHVCZ]', tokens[i]):
            cmd = tokens[i]
            i += 1
            if cmd == 'Z':
                if cur:
                    subpaths.append((cur, True))
                    pos = cur[0]
                cur = []
                continue
        if cmd == 'M':
            if cur:
                subpaths.append((cur, False))
            pos = (num(), num())
            cur = [pos]
            cmd = 'L'
        elif cmd == 'L':
            pos = (num(), num())
            cur.append(pos)
        elif cmd == 'H':
            pos = (num(), pos[1])
            cur.append(pos)
        elif cmd == 'V':
            pos = (pos[0], num())
            cur.append(pos)
        elif cmd == 'C':
            p0 = pos
            p1, p2, p3 = (num(), num()), (num(), num()), (num(), num())
            length = sum(math.dist(a, b) for a, b in ((p0, p1), (p1, p2), (p2, p3)))
            steps = max(4, int(math.sqrt(length / TOLERANCE) * 0.5))
            for k in range(1, steps + 1):
                t = k / steps
                u = 1 - t
                cur.append((u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                            u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]))
            pos = p3
        else:
            raise ValueError("unsupported path data near %r" % tokens[i:i + 4])
    if cur:
        subpaths.append((cur, False))
    return subpaths


# ---------------------------------------------------------------- geometry

def signed_area(pts):
    return sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1])) / 2


def fill_geometry(subpaths):
    """Nonzero fill of closed contours: by decreasing area, same winding as the largest adds, the
    opposite winding cuts a hole."""
    contours = [pts for pts, _ in subpaths if len(pts) >= 3]
    contours.sort(key=lambda p: -abs(signed_area(p)))
    if not contours:
        return Polygon()
    outer_sign = math.copysign(1, signed_area(contours[0]))
    result = Polygon()
    for pts in contours:
        poly = Polygon(pts).buffer(0)
        if math.copysign(1, signed_area(pts)) == outer_sign:
            result = result.union(poly)
        else:
            result = result.difference(poly)
    return result


def stroke_geometry(subpaths, width):
    parts = []
    for pts, closed in subpaths:
        if len(pts) < 2:
            continue
        line = LinearRing(pts) if closed and len(pts) >= 3 else LineString(pts)
        parts.append(line.buffer(width / 2, quad_segs=24, cap_style="round", join_style="round"))
    return unary_union(parts) if parts else Polygon()


def rect_subpaths(a):
    x, y, w, h = (float(a[k]) for k in ("x", "y", "width", "height"))
    r = float(a.get("rx", 0))
    shape = box(x + r, y + r, x + w - r, y + h - r).buffer(r, quad_segs=24) if r else box(x, y, x + w, y + h)
    return [(list(shape.exterior.coords)[:-1], True)]


def circle_subpaths(a):
    c = Point(float(a["cx"]), float(a["cy"])).buffer(float(a["r"]), quad_segs=48)
    return [(list(c.exterior.coords)[:-1], True)]


def element_geometry(a, masks):
    if a["tag"] == "path":
        subpaths = flatten_path(a["d"])
    elif a["tag"] == "rect":
        subpaths = rect_subpaths(a)
    else:
        subpaths = circle_subpaths(a)
    parts = []
    fill = a.get("fill", "none")           # the sheet sets fill="none" on its root
    if fill != "none" and fill not in BACKGROUNDS:
        parts.append(fill_geometry(subpaths))
    stroke = a.get("stroke")
    if stroke and stroke != "none":
        g = stroke_geometry(subpaths, float(a.get("stroke-width", 1)))
        m = re.search(r'url\(#([^)]+)\)', a.get("mask", ""))
        if m:
            g = g.intersection(fill_geometry(flatten_path(masks[m.group(1)])))
        parts.append(g)
    return unary_union(parts) if parts else Polygon()


def bbox_center(a):
    if a["tag"] == "path":
        pts = [p for sp, _ in flatten_path(a["d"]) for p in sp]
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    elif a["tag"] == "rect":
        xs = [float(a["x"]), float(a["x"]) + float(a["width"])]
        ys = [float(a["y"]), float(a["y"]) + float(a["height"])]
    else:
        xs = [float(a["cx"])]
        ys = [float(a["cy"])]
    return (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2


def is_segment(a):
    """A single straight line (the sound waves of the speaker icons)."""
    return a["tag"] == "path" and re.fullmatch(r'M[\d. ]+L[\d. ]+', a["d"]) is not None


def cell_of(a):
    cx, cy = bbox_center(a)
    return int((cx - ORIGIN + 10) // PITCH), int((cy - ORIGIN + 10) // PITCH)


# ---------------------------------------------------------------- output

def ring_d(coords, dx, dy):
    pts = list(coords)[:-1]
    return "M" + "L".join("%s %s" % (fmt(x - dx), fmt(y - dy)) for x, y in pts) + "Z"


def fmt(v):
    s = ("%.3f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def to_svg(geom, dx, dy):
    geom = geom.simplify(TOLERANCE, preserve_topology=True)
    polys = [geom] if geom.geom_type == "Polygon" else list(geom.geoms)
    d = ""
    for poly in polys:
        if poly.is_empty:
            continue
        # clockwise outline, counter-clockwise holes: nonzero fill is then unambiguous
        from shapely.geometry.polygon import orient
        poly = orient(poly, sign=-1.0)
        d += ring_d(poly.exterior.coords, dx, dy)
        for hole in poly.interiors:
            d += ring_d(hole.coords, dx, dy)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
            '<path d="%s" fill="black"/></svg>\n' % (CELL, CELL, CELL, CELL, d))


def main(argv):
    if len(argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    sheet_path, map_path, out_dir = argv[1:]
    with open(sheet_path, encoding="utf-8") as fd:
        elements, masks = parse_sheet(fd.read())
    with open(map_path, encoding="utf-8") as fd:
        mapping = json.load(fd)

    cells = {}
    for a in elements:
        if "stroke-dasharray" in a:      # the dashed frame around the sheet
            continue
        cells.setdefault(cell_of(a), []).append(a)

    wanted = {}
    for key, spec in mapping["glyphs"].items():
        if spec.get("source") == "figma":
            wanted[spec["name"]] = (tuple(spec["cell"]), spec.get("drop"))
    os.makedirs(out_dir, exist_ok=True)
    for name, ((col, row), drop) in sorted(wanted.items()):
        dx, dy = ORIGIN + PITCH * col, ORIGIN + PITCH * row
        used = [a for a in cells.get((col, row), []) if not (drop == "segments" and is_segment(a))]
        geom = unary_union([element_geometry(a, masks) for a in used])
        if geom.is_empty:
            print("empty cell %s,%s for %s" % (col, row, name), file=sys.stderr)
            return 1
        minx, miny, maxx, maxy = geom.bounds
        if minx < dx - 1 or miny < dy - 1 or maxx > dx + CELL + 1 or maxy > dy + CELL + 1:
            print("warning: %s (%s,%s) reaches outside its cell: %s" % (name, col, row, geom.bounds),
                  file=sys.stderr)
        with open(os.path.join(out_dir, name + ".svg"), "w", encoding="utf-8", newline="\n") as fd:
            fd.write(to_svg(geom, dx, dy))
        print("%-28s cell %2d,%2d  %d elements" % (name, col, row, len(cells[(col, row)])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
