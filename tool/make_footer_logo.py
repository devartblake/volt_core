"""Makes the pale, single-colour version of the A&S Electric company logo used on
the navy PDF footer band.

    python -I tool/make_footer_logo.py

Reads  assets/images/company_logo.png  (the cream line-art logo used in the PDF
header, on a white background) and writes  assets/images/company_logo_footer.png:
the same artwork in a pale ice blue (#D2E6FA, the footer's second text colour)
on a transparent background, so it stands apart from the navy band and from the
header's cream colour.

Re-run it if company_logo.png changes. Needs Pillow.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'images', 'company_logo.png')
DST = os.path.join(ROOT, 'assets', 'images', 'company_logo_footer.png')
PALE = (0xD2, 0xE6, 0xFA)


def main():
    src = Image.open(SRC).convert('RGBA')
    px = src.load()
    w, h = src.size

    # How far each pixel is from the white background; the artwork is cream, so
    # the blue channel separates it best (white = 255, cream = about 176).
    distance = [[255 - min(px[x, y][0], px[x, y][1], px[x, y][2]) for x in range(w)] for y in range(h)]
    strongest = max(max(row) for row in distance) or 1

    out = Image.new('RGBA', (w, h), PALE + (0,))
    op = out.load()
    for y in range(h):
        for x in range(w):
            a = distance[y][x] * 255 // strongest
            # A little contrast boost so thin strokes survive printing.
            a = min(255, int(a * 1.15))
            if px[x, y][3] == 0:
                a = 0
            op[x, y] = PALE + (a,)

    out.save(DST, optimize=True)
    print('wrote', os.path.relpath(DST, ROOT), '%dx%d' % (w, h))


if __name__ == '__main__':
    main()
