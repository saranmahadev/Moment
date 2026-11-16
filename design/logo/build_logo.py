"""Builds Moment's logo from the app's own colours and typeface.

The mark: the present moment (one ink dot) in a pane of glass, ringed by
six dots in the colours of the six kinds of log, over the app's soft orbs.

Run from the repository root:

    python3 design/logo/build_logo.py     # writes the SVGs next to this file
    node design/logo/export.cjs           # writes every PNG the app uses

Needs fontTools (`pip install fonttools`) for the name's letter shapes.
"""

import math
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

HERE = Path(__file__).parent
FONT = TTFont("assets/fonts/Newsreader/Newsreader-Medium.ttf")

# From lib/design/tokens.dart: MomentTokens.standard and MomentTokens.dark.
PALETTES = {
    "light": {
        "ground": "#EDF0F7",
        "ink": "#1B1F2A",
        "types": ["#1D4ED8", "#B45309", "#BE185D", "#6D28D9", "#0F766E", "#15803D"],
        "orbs": [("#B7C3FF", "#8B93F5"), ("#FFD3BF", "#FFAE9A"), ("#BFEFDD", "#8ADBC2")],
        "orb_alpha": 0.9,
        "glass": "rgba(255,255,255,0.58)",
        "glass_edge": "rgba(255,255,255,0.9)",
        "shadow": "rgba(40,50,100,0.20)",
        "tile_edge": "rgba(27,31,42,0.08)",
    },
    "dark": {
        "ground": "#0F1218",
        "ink": "#F1F3F8",
        "types": ["#8FB1FF", "#F2A94E", "#F58BB6", "#B9A0FA", "#56CDBF", "#6BCB88"],
        "orbs": [("#3A47A8", "#272E7C"), ("#8C4A38", "#6B3226"), ("#2B6B5B", "#1C4F43")],
        "orb_alpha": 0.75,
        "glass": "rgba(255,255,255,0.10)",
        "glass_edge": "rgba(255,255,255,0.22)",
        "shadow": "rgba(0,0,0,0.45)",
        "tile_edge": "rgba(255,255,255,0.10)",
    },
}

# Where the three orbs sit in the 512 square: centre x, centre y, radius.
ORB_PLACES = [(118, 124, 215), (436, 300, 205), (150, 468, 190)]


def name_path(height):
    """"Moment" in Newsreader as one SVG path with its cap height `height`.

    Returns (path data, width). The baseline is y = 0.
    """
    glyphs = FONT.getGlyphSet()
    cmap = FONT.getBestCmap()
    scale = height / FONT["OS/2"].sCapHeight
    pen = SVGPathPen(glyphs)
    cursor = 0.0
    for char in "Moment":
        glyph = glyphs[cmap[ord(char)]]
        glyph.draw(TransformPen(pen, (scale, 0, 0, -scale, cursor * scale, 0)))
        cursor += glyph.width
    return pen.getCommands(), cursor * scale


def orb_layer(palette):
    """The ground and the three orbs, as (defs, shapes)."""
    defs, shapes = [], [f'<rect width="512" height="512" fill="{palette["ground"]}"/>']
    alpha = palette["orb_alpha"]
    for i, ((inner, outer), (cx, cy, r)) in enumerate(zip(palette["orbs"], ORB_PLACES)):
        defs.append(
            f'<radialGradient id="orb{i}">'
            f'<stop offset="0" stop-color="{inner}" stop-opacity="{alpha}"/>'
            f'<stop offset="0.6" stop-color="{outer}" stop-opacity="{alpha * 0.85:.2f}"/>'
            f'<stop offset="1" stop-color="{outer}" stop-opacity="0"/>'
            "</radialGradient>"
        )
        shapes.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#orb{i})"/>')
    return defs, shapes


def glass_layer(palette):
    """The pane of glass with the six dots and the moment, as (defs, shapes)."""
    defs = [
        '<filter id="lift" x="-30%" y="-30%" width="160%" height="170%">'
        f'<feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="{palette["shadow"]}"/>'
        "</filter>"
    ]
    shapes = [
        f'<circle cx="256" cy="256" r="156" fill="{palette["glass"]}" '
        f'stroke="{palette["glass_edge"]}" stroke-width="3" filter="url(#lift)"/>'
    ]
    # Text at the top, then clockwise in the app's own order of types.
    for i, color in enumerate(palette["types"]):
        angle = math.radians(-90 + i * 60)
        x, y = 256 + 96 * math.cos(angle), 256 + 96 * math.sin(angle)
        shapes.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="17" fill="{color}"/>')
    shapes.append(f'<circle cx="256" cy="256" r="36" fill="{palette["ink"]}"/>')
    return defs, shapes


def svg(body, defs, size=512, view="0 0 512 512"):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}" '
        f'width="{size}" height="{size}" role="img" aria-label="Moment">'
        f"<defs>{''.join(defs)}</defs>{body}</svg>\n"
    )


def mark(theme="light", rounded=True):
    """The whole mark on its tile: the app icon."""
    palette = PALETTES[theme]
    orb_defs, orbs = orb_layer(palette)
    glass_defs, glass = glass_layer(palette)
    radius = 118 if rounded else 0
    clip = f'<clipPath id="tile"><rect width="512" height="512" rx="{radius}"/></clipPath>'
    # A hairline so the tile keeps its shape on a page of its own colour.
    edge = (
        f'<rect x="1" y="1" width="510" height="510" rx="{radius - 1}" fill="none" '
        f'stroke="{palette["tile_edge"]}" stroke-width="2"/>'
        if rounded
        else ""
    )
    body = f'<g clip-path="url(#tile)">{"".join(orbs)}{"".join(glass)}</g>{edge}'
    return svg(body, [*orb_defs, *glass_defs, clip])


def adaptive(layer):
    """One layer of Android's adaptive icon.

    The launcher shows only the middle two thirds of each layer (and may
    cut that to a circle or squircle), so the mark is drawn at two thirds
    of its size in the centre; the background fills the whole square.
    """
    palette = PALETTES["light"]
    shrink = 'transform="translate(256 256) scale(0.6667) translate(-256 -256)"'
    if layer == "background":
        defs, shapes = orb_layer(palette)
        ground, orbs = shapes[0], shapes[1:]
        return svg(f'{ground}<g {shrink}>{"".join(orbs)}</g>', defs)
    defs, shapes = glass_layer(palette)
    return svg(f'<g {shrink}>{"".join(shapes)}</g>', defs)


def lockup(theme="light"):
    """The mark beside the name, for the README and the site."""
    palette = PALETTES[theme]
    d, width = name_path(104)
    total = round(200 + 44 + width)
    inner = mark(theme).split(">", 1)[1].rsplit("</svg>", 1)[0]
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total} 200" '
        f'width="{total}" height="200" role="img" aria-label="Moment">'
        f'<svg viewBox="0 0 512 512" width="200" height="200">{inner}</svg>'
        f'<path transform="translate(244 152)" d="{d}" fill="{palette["ink"]}"/>'
        "</svg>\n"
    )


if __name__ == "__main__":
    files = {
        "mark.svg": mark(),
        "mark-dark.svg": mark("dark"),
        "mark-square.svg": mark(rounded=False),
        "adaptive-background.svg": adaptive("background"),
        "adaptive-foreground.svg": adaptive("foreground"),
        "lockup.svg": lockup(),
        "lockup-dark.svg": lockup("dark"),
    }
    for name, content in files.items():
        (HERE / name).write_text(content)
    print("wrote", ", ".join(files))
