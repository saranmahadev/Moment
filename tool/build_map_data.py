"""Builds the offline place-map tiles in assets/map/ from Natural Earth.

Natural Earth (naturalearthdata.com) is public domain. Run from the
repository root:

    python3 tool/build_map_data.py /path/to/natural-earth-zips

The folder holds the 1:10m zips: ne_10m_land, ne_10m_lakes,
ne_10m_urban_areas, ne_10m_roads, ne_10m_railroads,
ne_10m_rivers_lake_centerlines, ne_10m_admin_1_states_provinces (lines
used) and ne_10m_populated_places. Needs `pip install pyshp shapely`.

Output: one JSON file per 10 x 10 degree tile, named
`<south>_<west>.json` (for example `10_70.json`). Ocean-only tiles have no
file. Coordinates are whole thousandths of a degree, delta-encoded, flat
lists of x (longitude) and y (latitude). Features that cross a tile edge
are clipped to the tile plus a margin, so neighbours overlap a little.
"""

import json
import sys
import zipfile
from pathlib import Path

import shapefile
from shapely.geometry import box, shape
from shapely.geometry.base import BaseGeometry

TILE = 10
MARGIN = 0.3
SCALE = 1000
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'map'


def read(folder: Path, name: str):
    target = folder / name
    if not target.exists():
        with zipfile.ZipFile(folder / f'{name}.zip') as z:
            z.extractall(target)
    reader = shapefile.Reader(str(target / f'{name}.shp'))
    return [
        (sr.record.as_dict(), shape(sr.shape.__geo_interface__))
        for sr in reader.iterShapeRecords()
    ]


def flat(coords):
    """Delta-encoded thousandths of a degree: x0, y0, dx1, dy1, ..."""
    out, px, py = [], 0, 0
    for x, y in coords:
        ix, iy = round(x * SCALE), round(y * SCALE)
        out += [ix - px, iy - py]
        px, py = ix, iy
    return out


def lines(geom: BaseGeometry):
    for part in getattr(geom, 'geoms', [geom]):
        if part.geom_type == 'LineString' and len(part.coords) > 1:
            yield flat(part.coords)
        elif part.geom_type == 'GeometryCollection':
            yield from lines(part)


def polys(geom: BaseGeometry):
    for part in getattr(geom, 'geoms', [geom]):
        if part.geom_type == 'Polygon' and not part.is_empty:
            yield [flat(part.exterior.coords)] + [
                flat(i.coords) for i in part.interiors
            ]
        elif part.geom_type == 'GeometryCollection':
            yield from polys(part)


def main(folder: Path):
    layers = {
        'land': ('ne_10m_land', 'poly', 0.004),
        'lakes': ('ne_10m_lakes', 'poly', 0.004),
        'urban': ('ne_10m_urban_areas', 'poly', 0.003),
        'states': ('ne_10m_admin_1_states_provinces', 'border', 0.006),
        'rivers': ('ne_10m_rivers_lake_centerlines', 'line', 0.004),
        'rail': ('ne_10m_railroads', 'line', 0.005),
        'roads': ('ne_10m_roads', 'road', 0.004),
    }
    data = {k: read(folder, v[0]) for k, v in layers.items()}
    places = read(folder, 'ne_10m_populated_places')
    tiles = {}
    for key, (_, kind, tol) in layers.items():
        for rec, geom in data[key]:
            if kind == 'border':
                geom = geom.boundary
            geom = geom.simplify(tol)
            if geom.is_empty:
                continue
            minx, miny, maxx, maxy = geom.bounds
            for ty in range(max(int((miny - MARGIN) // TILE), -9), min(int((maxy + MARGIN) // TILE), 8) + 1):
                for tx in range(max(int((minx - MARGIN) // TILE), -18), min(int((maxx + MARGIN) // TILE), 17) + 1):
                    south, west = ty * TILE, tx * TILE
                    cut = geom.intersection(box(west - MARGIN, south - MARGIN, west + TILE + MARGIN, south + TILE + MARGIN))
                    if cut.is_empty:
                        continue
                    t = tiles.setdefault((south, west), {})
                    if kind == 'poly':
                        t.setdefault(key, []).extend(polys(cut))
                    elif kind == 'road':
                        major = 1 if rec.get('type') == 'Major Highway' else 0
                        for ln in lines(cut):
                            t.setdefault(key, []).append([major, ln])
                    else:
                        t.setdefault(key, []).extend(lines(cut))
    for rec, pt in places:
        name = rec.get('NAME')
        if not name:
            continue
        south, west = int(pt.y // TILE) * TILE, int(pt.x // TILE) * TILE
        t = tiles.setdefault((south, west), {})
        t.setdefault('places', []).append(
            [name, round(pt.x * SCALE), round(pt.y * SCALE), int(rec.get('SCALERANK') or 10)]
        )
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob('*.json'):
        old.unlink()
    total = 0
    for (south, west), t in sorted(tiles.items()):
        text = json.dumps(t, separators=(',', ':'), ensure_ascii=False)
        (OUT / f'{south}_{west}.json').write_text(text, encoding='utf-8')
        total += len(text)
    print(f'{len(tiles)} tiles, {total / 1e6:.1f} MB of JSON')


if __name__ == '__main__':
    main(Path(sys.argv[1]))
