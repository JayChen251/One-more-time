#!/usr/bin/env python3
"""Generates the ship tileset: assets/images/tilemap/ship_tiles.png and
resources/ship_tileset.tres.

Run from the repo root:  python3 tools/build_tileset.py

Flat, VVVVVV-style tiles. Atlas column = which sides face open air (bit mask:
1 up, 2 right, 4 down, 8 left); atlas row = colour scheme (one per chunk of
the ship). Exposed tops get a bright edge, exposed sides a dimmer one and
exposed bottoms a dark one, so floors, walls and ceilings read differently.
build_level.py picks the right tile for every cell.
"""
import struct
import zlib

TILE = 32

# (fill, top edge, side edge, bottom edge) per scheme, bottom of the ship up.
SCHEMES = [
    ((22, 36, 71), (90, 200, 255), (50, 115, 175), (35, 70, 120)),     # blue
    ((20, 56, 40), (110, 240, 140), (60, 155, 90), (40, 100, 60)),     # green
    ((48, 26, 72), (200, 130, 255), (130, 85, 185), (90, 55, 130)),    # purple
    ((70, 36, 20), (255, 170, 80), (190, 110, 50), (130, 75, 35)),     # orange
    ((72, 20, 36), (255, 110, 150), (190, 70, 105), (130, 45, 75)),    # pink
]
UP, RIGHT, DOWN, LEFT = 1, 2, 4, 8


def shade(c, f):
    return tuple(min(255, int(v * f)) for v in c)


def draw_tile(mask, scheme):
    fill, top, side, bottom = scheme
    px = [[fill] * TILE for _ in range(TILE)]
    # A faint dot every 8px keeps big solid areas from looking empty.
    for y in range(4, TILE, 8):
        for x in range(4, TILE, 8):
            px[y][x] = shade(fill, 1.35)
    for y in range(TILE):
        for x in range(TILE):
            if mask & LEFT and x < 2:
                px[y][x] = side
            if mask & RIGHT and x >= TILE - 2:
                px[y][x] = side
            if mask & DOWN and y >= TILE - 2:
                px[y][x] = bottom
    for y in range(TILE):
        for x in range(TILE):
            if mask & UP and y < 3:
                px[y][x] = top if y < 2 else shade(top, 0.6)
    return px


def write_png(path, pixels):
    h, w = len(pixels), len(pixels[0])
    raw = b"".join(b"\x00" + bytes(v for p in row for v in p) for row in pixels)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


def main():
    cols, rows = 16, len(SCHEMES)
    sheet = [[(0, 0, 0)] * (cols * TILE) for _ in range(rows * TILE)]
    for r, scheme in enumerate(SCHEMES):
        for mask in range(cols):
            tile = draw_tile(mask, scheme)
            for y in range(TILE):
                sheet[r * TILE + y][mask * TILE:(mask + 1) * TILE] = tile[y]
    write_png("assets/images/tilemap/ship_tiles.png", sheet)

    h = TILE // 2
    lines = ['[gd_resource type="TileSet" load_steps=3 format=3]', '',
             '[ext_resource type="Texture2D" path="res://assets/images/tilemap/ship_tiles.png" id="1_tex"]', '',
             '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_ship"]',
             'texture = ExtResource("1_tex")',
             'texture_region_size = Vector2i(%d, %d)' % (TILE, TILE)]
    for r in range(rows):
        for c in range(cols):
            lines.append("%d:%d/0 = 0" % (c, r))
            lines.append("%d:%d/0/physics_layer_0/polygon_0/points = "
                         "PackedVector2Array(-%d, -%d, %d, -%d, %d, %d, -%d, %d)" % (c, r, h, h, h, h, h, h, h, h))
    lines += ['', '[resource]', 'tile_size = Vector2i(%d, %d)' % (TILE, TILE),
              'physics_layer_0/collision_layer = 1',
              'sources/0 = SubResource("TileSetAtlasSource_ship")', '']
    open("resources/ship_tileset.tres", "w").write("\n".join(lines))
    print("wrote ship_tiles.png (%dx%d) and ship_tileset.tres" % (cols * TILE, rows * TILE))


if __name__ == "__main__":
    main()
