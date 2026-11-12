"""Rebuilds assets/images/pdf_footer.svg from the company checklist PDF.

The footer in `assets/pdf/Modified Comp Checklist With Load Test.pdf` is vector
artwork: a navy band with a stepped top edge and a world map. This script reads
those exact shapes from the PDF and writes them out as an SVG, so the app's
footer matches the paper form.

Usage:  python tool/make_pdf_footer.py        (requires PyMuPDF)

MAP_FILL is the map colour in the SVG. The original is light grey (#BFBFBF),
which would fight the footer text, so it is blended towards the band colour.
"""
import os

import pymupdf

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "..", "assets", "pdf",
                      "Modified Comp Checklist With Load Test.pdf")
TARGET = os.path.join(HERE, "..", "assets", "images", "pdf_footer.svg")

BAND_FILL = "#0E2841"
MAP_FILL = "#33465C"


def fmt(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def path_data(items, dx, dy):
    """Turn PyMuPDF drawing items into an SVG path `d` string."""
    parts = []
    cursor = None

    def pt(p):
        return f"{fmt(p.x - dx)},{fmt(p.y - dy)}"

    for item in items:
        kind = item[0]
        if kind == "l":
            p1, p2 = item[1], item[2]
            if cursor is None or abs(cursor.x - p1.x) > 0.01 or abs(cursor.y - p1.y) > 0.01:
                parts.append(f"M{pt(p1)}")
            parts.append(f"L{pt(p2)}")
            cursor = p2
        elif kind == "c":
            p1, c1, c2, p2 = item[1], item[2], item[3], item[4]
            if cursor is None or abs(cursor.x - p1.x) > 0.01 or abs(cursor.y - p1.y) > 0.01:
                parts.append(f"M{pt(p1)}")
            parts.append(f"C{pt(c1)} {pt(c2)} {pt(p2)}")
            cursor = p2
        elif kind == "re":
            r = item[1]
            parts.append(f"M{fmt(r.x0 - dx)},{fmt(r.y0 - dy)}H{fmt(r.x1 - dx)}V{fmt(r.y1 - dy)}H{fmt(r.x0 - dx)}Z")
            cursor = None
    return "".join(parts)


def main():
    doc = pymupdf.open(SOURCE)
    page = doc[0]  # the first page carries the map; the others have the band only
    page_h = page.rect.height

    band = None
    world = None
    for d in page.get_drawings():
        if d["rect"].y1 < page_h - 130:
            continue
        if d["rect"].width > 600 and band is None:
            band = d
        elif d["rect"].width > 400 and len(d["items"]) > 100:
            world = d

    top = band["rect"].y0
    height = band["rect"].y1 - band["rect"].y0
    width = band["rect"].width

    band_d = path_data(band["items"], 0, top) + "Z"
    map_d = path_data(world["items"], 0, top)
    rule = "evenodd" if world.get("even_odd") else "nonzero"

    svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<!--
  A&S Electric PDF footer band.

  Traced from the footer of "Modified Comp Checklist With Load Test.pdf": the
  same navy band, stepped top edge and world map, at the same proportions.
  The map is dimmed towards the band colour so footer text stays readable, in
  colour and in black and white.

  Regenerate with `python tool/make_pdf_footer.py` (needs PyMuPDF).
-->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {fmt(width)} {fmt(height)}" width="{fmt(width)}" height="{fmt(height)}">
  <defs>
    <clipPath id="band"><path d="{band_d}"/></clipPath>
  </defs>
  <path d="{band_d}" fill="{BAND_FILL}"/>
  <path clip-path="url(#band)" fill-rule="{rule}" d="{map_d}" fill="{MAP_FILL}"/>
</svg>
'''
    with open(TARGET, "w", encoding="utf-8") as f:
        f.write(svg)
    print("wrote", os.path.basename(TARGET), f"{len(svg) // 1024} KB",
          f"viewBox {fmt(width)} x {fmt(height)}", "map items", len(world["items"]))


if __name__ == "__main__":
    main()
