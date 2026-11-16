"""Builds Moment's logo files from the app's own tokens and typeface.

Run from the repository root:  python3 design/logo/build_logo.py
Needs fontTools (pip install fonttools). Writes SVGs next to this script;
design/logo/export.mjs turns them into the PNGs the app and site use.
"""

import math
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

HERE = Path(__file__).parent
FONT = TTFont("assets/fonts/Newsreader/Newsreader-Medium.ttf")

# From lib/design/tokens.dart.
GROUND, INK = "#EDF0F7", "#1B1F2A"
DARK_GROUND, DARK_INK = "#0F1218", "#F1F3F8"
TYPES = ["#1D4ED8", "#B45309", "#BE185D", "#6D28D9", "#0F766E", "#15803D"]
ORBS = [("#B7C3FF", "#8B93F5"), ("#FFD3BF", "#FFAE9A"), ("#BFEFDD", "#8ADBC2")]
DARK_ORBS = [("#3A47A8", "#272E7C"), ("#8C4A38", "#6B3226"), ("#2B6B5B", "#1C4F43")]


def text_path(text, height, x=0.0, baseline=0.0):
    """`text` in Newsreader as one SVG path, cap height scaled to `height`.

    Returns (path data, advance width).
    """
    glyphs = FONT.getGlyphSet()
    cmap = FONT.getBestCmap()
    scale = height / FONT["OS/2"].sCapHeight
    pen = SVGPathPen(glyphs)
    cursor = 0.0
    for char in text:
        name = cmap[ord(char)]
        glyphs[name].draw(
            TransformPen(pen, (scale, 0, 0, -scale, x + cursor * scale, baseline))
        )
        cursor += glyphs[name].width
    return pen.getCommands(), cursor * scale


def glyph_bounds(char, height):
    glyphs = FONT.getGlyphSet()
    name = FONT.getBestCmap()[ord(char)]
    scale = height / FONT["OS/2"].sCapHeight
    pen = BoundsPen(glyphs)
    glyphs[name].draw(pen)
    x0, y0, x1, y1 = pen.bounds
    return x0 * scale, x1 * scale


def mark(dark=False, variant="dots", rounded=True, size=512):
    """The app icon: the app's soft orbs, a pane of glass, and the moment."""
    ground = DARK_GROUND if dark else GROUND
    ink = DARK_INK if dark else INK
    orbs = DARK_ORBS if dark else ORBS
    orb_alpha = 0.75 if dark else 0.9
    glass_fill = "rgba(255,255,255,0.10)" if dark else "rgba(255,255,255,0.58)"
    glass_edge = "rgba(255,255,255,0.22)" if dark else "rgba(255,255,255,0.9)"
    shadow = "rgba(0,0,0,0.45)" if dark else "rgba(40,50,100,0.20)"
    # Type colours lifted for the dark ground, as in MomentTokens.dark.
    types = (
        ["#8FB1FF", "#F2A94E", "#F58BB6", "#B9A0FA", "#56CDBF", "#6BCB88"]
        if dark
        else TYPES
    )

    defs = []
    circles = []
    for i, ((a, b), (cx, cy, r)) in enumerate(
        zip(orbs, [(118, 124, 215), (436, 300, 205), (150, 468, 190)])
    ):
        defs.append(
            f'<radialGradient id="orb{i}">'
            f'<stop offset="0" stop-color="{a}" stop-opacity="{orb_alpha}"/>'
            f'<stop offset="0.6" stop-color="{b}" stop-opacity="{orb_alpha * 0.85:.2f}"/>'
            f'<stop offset="1" stop-color="{b}" stop-opacity="0"/>'
            "</radialGradient>"
        )
        circles.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#orb{i})"/>')

    defs.append(
        '<filter id="lift" x="-30%" y="-30%" width="160%" height="170%">'
        f'<feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="{shadow}"/>'
        "</filter>"
    )
    radius = 118 if rounded else 0
    defs.append(
        f'<clipPath id="tile"><rect width="512" height="512" rx="{radius}"/></clipPath>'
    )

    glass = (
        f'<circle cx="256" cy="256" r="156" fill="{glass_fill}" '
        f'stroke="{glass_edge}" stroke-width="3" filter="url(#lift)"/>'
    )

    if variant == "dots":
        # Six kinds of log, kept apart, around the present moment.
        inner = []
        for i, color in enumerate(types):
            angle = math.radians(-90 + i * 60)
            x, y = 256 + 96 * math.cos(angle), 256 + 96 * math.sin(angle)
            inner.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="17" fill="{color}"/>')
        inner.append(f'<circle cx="256" cy="256" r="36" fill="{ink}"/>')
    else:
        x0, x1 = glyph_bounds("M", 150)
        d, _ = text_path("M", 150, x=256 - (x0 + x1) / 2, baseline=256 + 75)
        inner = [f'<path d="{d}" fill="{ink}"/>']

    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" '
        f'width="{size}" height="{size}" role="img" aria-label="Moment">'
        f"<defs>{''.join(defs)}</defs>"
        f'<g clip-path="url(#tile)">'
        f'<rect width="512" height="512" fill="{ground}"/>'
        f"{''.join(circles)}{glass}{''.join(inner)}"
        "</g></svg>\n"
    )


def lockup(dark=False):
    """The mark beside the name, for the README and the site header."""
    ink = DARK_INK if dark else INK
    d, width = text_path("Moment", 104, x=0, baseline=0)
    total = 200 + 44 + width
    inner = mark(dark=dark, size=200).split(">", 1)[1].rsplit("</svg>", 1)[0]
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total:.0f} 200" '
        f'width="{total:.0f}" height="200" role="img" aria-label="Moment">'
        f'<svg viewBox="0 0 512 512" width="200" height="200">{inner}</svg>'
        f'<path transform="translate(244 152)" d="{d}" fill="{ink}"/>'
        "</svg>\n"
    )


if __name__ == "__main__":
    (HERE / "mark.svg").write_text(mark())
    (HERE / "mark-dark.svg").write_text(mark(dark=True))
    (HERE / "mark-square.svg").write_text(mark(rounded=False))
    (HERE / "mark-monogram.svg").write_text(mark(variant="monogram"))
    (HERE / "lockup.svg").write_text(lockup())
    (HERE / "lockup-dark.svg").write_text(lockup(dark=True))
    print("wrote", sorted(p.name for p in HERE.glob("*.svg")))
