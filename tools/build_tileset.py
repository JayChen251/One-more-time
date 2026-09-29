#!/usr/bin/env python3
"""Generates the ship tileset from the Industrial tileset pack:
assets/images/tilemap/ship_tiles.png and resources/ship_tileset.tres.

Run from the repo root:  python3 tools/build_tileset.py

The pack sheets (assets/images/tilemap/1_Industrial_Tileset_1.png and its
_Background twin) are 6x4 grids of 32px tiles laid out like
0_Template_Tileset.png:

    col 0-2, row 0     a one-tile-high platform: left end, middle, right end
    col 3,   row 0     a single block
    col 0-2, row 1-3   a 3x3 block (corners, edges, centre)
    col 3,   row 1-3   a one-tile-wide pillar: top, middle, bottom
    col 4-5, row 0-3   seamless 2x4 filler for the inside of big blocks

Output sheet: one 4-row band per colour scheme (one scheme per chunk of the
ship, bottom up). Columns 0-5 are the pack's solid tiles, palette-swapped so
each chunk has its own accent colour; columns 6-7 are the dimmed background
filler for the back wall (no collision). build_level.py picks the tile for
every cell from which of its sides face open air.
"""
import struct
import zlib

TILE = 32    # texels; the TileMapLayers are scaled x2, so a tile covers a 64px cell
PACK = "assets/images/tilemap/1_Industrial_Tileset_1.png"
PACK_BG = "assets/images/tilemap/2_Industrial_Tileset_1_Background.png"

# The pack's teal accent colours (dark to light) and what each chunk swaps
# them for, bottom of the ship up.
ACCENT = [(2, 16, 28), (7, 25, 41), (20, 49, 74)]
SCHEMES = [
    [(2, 16, 28), (7, 25, 41), (20, 49, 74)],        # blue (the pack's own)
    [(2, 24, 14), (5, 42, 26), (12, 84, 52)],        # green
    [(14, 5, 28), (28, 11, 50), (60, 28, 98)],       # purple
    [(28, 11, 2), (50, 22, 5), (104, 50, 12)],       # orange
    [(28, 3, 14), (50, 9, 28), (104, 24, 58)],       # pink
]
# How strongly the rest of the metal leans towards the chunk's accent.
BODY_TINT = 0.18
# Back wall brightness (the pack's background tiles are fairly light).
BACK_WALL_DIM = 0.3
# Brightness of the filler deep inside the hull.
DEEP_DIM = 0.4


def read_png(path):
    """Decodes an 8-bit RGB/RGBA PNG into rows of (r, g, b, a)."""
    data = open(path, "rb").read()
    pos, idat = 8, b""
    while pos < len(data):
        n, = struct.unpack(">I", data[pos:pos + 4])
        kind, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + n]
        pos += 12 + n
        if kind == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", body[:10])
            assert depth == 8 and ctype in (2, 6), "only 8-bit RGB(A) PNGs"
        elif kind == b"IDAT":
            idat += body
    raw = zlib.decompress(idat)
    bpp = 4 if ctype == 6 else 3
    stride = w * bpp
    rows, prev, p = [], bytearray(stride), 0
    for _ in range(h):
        f, line = raw[p], bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = line
        rows.append([tuple(line[x * bpp:x * bpp + 3]) + ((line[x * bpp + 3],) if bpp == 4 else (255,))
                     for x in range(w)])
    return rows


def write_png(path, pixels, alpha=False):
    """Writes RGB (or RGBA, with alpha=True) pixel rows as a PNG."""
    h, w = len(pixels), len(pixels[0])
    n = 4 if alpha else 3
    raw = b"".join(b"\x00" + bytes(v for p in row for v in p[:n]) for row in pixels)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6 if alpha else 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


def recolour(px, scheme, dim=1.0):
    r, g, b, a = px
    if a == 0:
        return (0, 0, 0, 0)
    if (r, g, b) in ACCENT:
        r, g, b = scheme[ACCENT.index((r, g, b))]
    else:
        # Lean the greys towards the accent hue, keeping their brightness.
        tint = scheme[2]
        lum = (r + g + b) / 3.0
        tl = sum(tint) / 3.0 or 1.0
        r, g, b = (v + (lum * t / tl - v) * BODY_TINT for v, t in zip((r, g, b), tint))
    return tuple(max(0, min(255, round(v * dim))) for v in (r, g, b)) + (255,)


def main():
    pack, pack_bg = read_png(PACK), read_png(PACK_BG)
    cols, rows = 16, 4 * len(SCHEMES)
    sheet = [[(0, 0, 0, 0)] * (cols * TILE) for _ in range(rows * TILE)]
    for s, scheme in enumerate(SCHEMES):
        for y in range(4 * TILE):
            for x in range(6 * TILE):
                sheet[s * 4 * TILE + y][x] = recolour(pack[y][x], scheme)
                sheet[s * 4 * TILE + y][10 * TILE + x] = recolour(pack[y][x], scheme, DEEP_DIM)
            for x in range(2 * TILE):
                sheet[s * 4 * TILE + y][6 * TILE + x] = recolour(pack_bg[y][4 * TILE + x], scheme, BACK_WALL_DIM)
    write_png("assets/images/tilemap/ship_tiles.png", sheet, alpha=True)

    h = TILE // 2
    lines = ['[gd_resource type="TileSet" load_steps=3 format=3]', '',
             '[ext_resource type="Texture2D" path="res://assets/images/tilemap/ship_tiles.png" id="1_tex"]', '',
             '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_ship"]',
             'texture = ExtResource("1_tex")',
             'texture_region_size = Vector2i(%d, %d)' % (TILE, TILE)]
    for r in range(rows):
        for c in range(cols):
            lines.append("%d:%d/0 = 0" % (c, r))
            if c not in (6, 7, 8, 9):
                lines.append("%d:%d/0/physics_layer_0/polygon_0/points = "
                             "PackedVector2Array(-%d, -%d, %d, -%d, %d, %d, -%d, %d)"
                             % (c, r, h, h, h, h, h, h, h, h))
    lines += ['', '[resource]', 'tile_size = Vector2i(%d, %d)' % (TILE, TILE),
              'physics_layer_0/collision_layer = 1',
              'sources/0 = SubResource("TileSetAtlasSource_ship")', '']
    open("resources/ship_tileset.tres", "w").write("\n".join(lines))
    print("wrote ship_tiles.png (%dx%d) and ship_tileset.tres" % (cols * TILE, rows * TILE))


if __name__ == "__main__":
    main()
