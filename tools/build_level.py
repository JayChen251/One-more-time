#!/usr/bin/env python3
"""Generates scenes/level.tscn (the level blockout) and a PNG preview.

Run from the repo root:  python3 tools/build_level.py [preview.png]

Follows Jay's hand-drawn map, doubled in size (one graph-paper square = one
64px tile):
a corridor going right from the spawn, a tall shaft climbed with zigzag
one-way ramps and platforms, gates on the way up, and an exit channel at the
top right that leads out into space.

The level is rooms carved out of a solid hull, plus objects (platforms,
force fields, grapple points, gates...). One grid cell = one 64px tile.
Once you start editing the level by hand in Godot, stop re-running this
script: it overwrites scenes/level.tscn.

Walk-only route: right along the corridor, up the one-way ramp and over the
little force field, into the shaft, then up the zigzag ramps: each ramp runs
underneath the next platform (one-way, so you pass through it from below),
and at the top you turn around onto that platform.
"""
import base64
import struct
import sys
import zlib

T = 64                      # world pixels per cell
S = 2                       # the drawing's layout, doubled so it feels roomier
W, H = 25 * S, 26 * S       # grid size in cells
grid = [[" "] * W for _ in range(H)]   # " " outside, "#" solid, "." air


def fill(c0, c1, r0, r1, ch):
    for r in range(r0, r1 + 1):
        for c in range(c0, c1 + 1):
            grid[r][c] = ch


def air(c0, c1, r0, r1):
    fill(c0, c1, r0, r1, ".")


def y_of(row):              # world y of the top edge of a row
    return row * T


FLOOR = y_of(48)            # ground level (3072)

# ---------------------------------------------------------------- tiles
fill(0, W - 1, 0, H - 1, "#")   # hull
air(2, 25, 42, 47)          # start corridor (floor row 48, ceiling row 41)
air(26, 37, 14, 47)         # main shaft
air(38, 43, 14, 33)         # upper shaft widens right, above the ledge (row 34)
air(36, 43, 0, 13)          # exit channel up to the airlock
air(44, 47, 26, 30)         # boost gate room, floor row 31
air(20, 25, 16, 20)         # grapple gate pocket + hole through the shaft wall

# ---------------------------------------------------------------- objects
objects = []                # (scene, name, position, {props})


def obj(scene, name, pos, **props):
    objects.append((scene, name, pos, props))


def platform(name, x0, x1, y, thick=12):
    obj("one_way", name, (x0, y), size=(x1 - x0, thick))


def ramp(name, x_left, y_left, x_right, y_right):
    """One-way ramp between two points (left end, right end)."""
    obj("one_way", name, (x_left, y_left), size=(x_right - x_left, 12),
        rise=float(y_left - y_right))


# Start corridor: a platform 144px up (walkers pass under it, 8px thick) with
# a ramp down to the floor on its right, and a low force field after it.
# Walk: under the ramp and platform, turn back up the ramp, then walk off the
# platform's right end over the field (it's lower than the platform).
# The platform runs 192px past the top of the ramp so you have room to turn.
platform("CorridorPlatform", 544, 1132, FLOOR - 144, thick=8)
ramp("CorridorRamp", 736, FLOOR - 144, 1000, FLOOR)
obj("force_field", "CorridorField", (1144, FLOOR - 120), height=120.0)
obj("grapple_point", "CorridorPoint1", (508, FLOOR - 192))
obj("grapple_point", "CorridorPoint2", (1032, FLOOR - 208))

# Shaft zigzag (walkable without jumping; each step is also one jump high).
# Every ramp ends on a platform that keeps going past the ramp's top.
P1, P2, P3 = 2832, 2612, 2372
ramp("Ramp1", 1664, FLOOR, 2280, P1)         # up-right from the floor...
platform("Platform1", 1472, 2432, P1)        # ...onto Platform1 (runs on to the wall)
ramp("Ramp2", 1680, P1, 1960, P2)            # up-right from Platform1's left end...
platform("Platform2", 1960, 2432, P2)        # ...onto Platform2
ramp("Ramp3", 1856, P3, 2280, P2)            # up-left from Platform2...
platform("Platform3", 1664, 2280, P3)        # ...onto Platform3; jump gate at its left end
obj("grapple_point", "ShaftPoint1", (2228, 2716))

# Upper shaft.
P4, P5, P6 = 2176, 1940, 1528
platform("Platform4", 1808, 2248, P4)
obj("grapple_point", "ShaftPoint2", (2104, 2064))
platform("Platform5", 1664, 2352, P5)        # teleport gate at its left end
obj("force_field", "Platform5Field", (2360, P5 - 192), height=192.0)
platform("Platform6", 1848, 2040, P6)        # needs jump + boost
obj("grapple_point", "ShaftPoint3", (1988, 1364))

# Force fields sealing the boost room and the grapple pocket.
obj("force_field", "BoostRoomField", (44 * T, y_of(26)), height=5.0 * T)
obj("force_field", "GrapplePocketField", (26 * T, y_of(16)), height=5.0 * T)

# Exit channel: grapple up to the airlock.
obj("grapple_point", "ChannelPoint1", (2500, 1144))
obj("grapple_point", "ChannelPoint2", (2500, 820))
obj("grapple_point", "ChannelPoint3", (2560, 500))
obj("grapple_point", "ChannelPoint4", (2560, 330))

# Gates (closes_at 0 = never seals; timing comes later).
obj("gate", "GateJump", (1728, P3 - 48), unlocks="jump")
obj("gate", "GateTeleport", (1728, P5 - 48), unlocks="teleport")
obj("gate", "GateBoost", (3008, y_of(31) - 48), unlocks="boost")
obj("gate", "GateGrapple", (1408, y_of(21) - 48), unlocks="grapple")
obj("gate", "Exit", (2560, 240), is_exit=True)

# Airlock door lying across the top of the exit channel.
obj("airlock_door", "AirlockDoor", (36 * T, 2 * T), rotation=-1.5708, scale=(1.0, 8 * T / 192))
obj("starfield", "Starfield", (0, 0), area=(-1600, -4800, 6400, 4790))

SPAWN = (208, FLOOR - 40)

# ---------------------------------------------------------------- checks
JUMP = 1140 ** 2 / (2 * 2500)           # ~260
BOOST = 1000 ** 2 / (2 * 2500)          # 200
TELEPORT = 160
RANGE = 640
PLAYER_H = 60
checks = [
    ("walker fits under corridor platform", PLAYER_H < 144 - 8),
    ("walker on corridor platform clears the field", 120 < 144),
    ("floor walker blocked by corridor field (can't jump)", 120 > PLAYER_H),
    ("floor -> Platform1 jumpable", FLOOR - P1 <= JUMP - 10),
    ("Platform1 -> 2 jumpable", P1 - P2 <= JUMP - 10),
    ("Platform2 -> 3 jumpable", P2 - P3 <= JUMP - 10),
    ("Platform3 -> 4 jumpable", P3 - P4 <= JUMP - 10),
    ("Platform4 -> 5 jumpable", P4 - P5 <= JUMP - 10),
    ("Platform5 -> 6 needs boost", JUMP < P5 - P6 <= JUMP + BOOST - 20),
    ("walker fits between zigzag levels", min(FLOOR - P1, P1 - P2, P2 - P3) > PLAYER_H + 12),
    ("ledge -> boost room jumpable", y_of(34) - y_of(31) <= JUMP - 10),
    ("jump from Platform6 reaches grapple pocket", P6 - JUMP < y_of(21) - 10),
    ("teleport from shaft wall lands in pocket", 26 * T + 10 - TELEPORT + 10 < 26 * T),
    ("channel points within range", max(1144 - 820, 820 - 500) < RANGE),
    ("Platform6 -> ChannelPoint1 in range",
     ((2500 - 2040) ** 2 + (P6 - 38 - 1144) ** 2) ** 0.5 < RANGE),
]
for label, ok in checks:
    print(("ok   " if ok else "FAIL ") + label)
    assert ok, label

# ---------------------------------------------------------------- output
EXT = {
    "slope": "res://scenes/slope.tscn",
    "one_way": "res://scenes/one_way_platform.tscn",
    "grav_lift": "res://scenes/grav_lift.tscn",
    "force_field": "res://scenes/force_field.tscn",
    "grapple_point": "res://scenes/grapple_point.tscn",
    "gate": "res://scenes/gate.tscn",
    "airlock_door": "res://scenes/airlock_door.tscn",
    "starfield": "res://scenes/starfield.tscn",
}
GROUP_NODE = {
    "slope": "Slopes", "one_way": "Platforms", "grav_lift": "Lifts",
    "force_field": "ForceFields", "grapple_point": "GrapplePoints",
    "gate": "Gates", "airlock_door": None, "starfield": None,
}


def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, tuple):
        return "Vector2(%g, %g)" % v
    if isinstance(v, float):
        return "%g" % v if v != int(v) else "%.1f" % v
    if isinstance(v, str):
        return '"%s"' % v
    return str(v)


def tile_data():
    out = bytearray(b"\x00\x00")
    for r in range(H):
        for c in range(W):
            if grid[r][c] == "#":
                # TileMapLayer is scaled x2, so a 32px tile covers one cell.
                out += struct.pack("<hhHhhH", c, r, 0, 1, 1, 0)
    return base64.b64encode(bytes(out)).decode()


def write_scene(path):
    used = [k for k in EXT if any(o[0] == k for o in objects)]
    ids = {k: "%d_%s" % (i + 2, k) for i, k in enumerate(used)}
    lines = ['[gd_scene load_steps=%d format=3]' % (len(used) + 2), '',
             '[ext_resource type="TileSet" path="res://resources/industrial_tileset.tres" id="1_tiles"]']
    for k in used:
        p = EXT[k]
        lines.append('[ext_resource type="PackedScene" path="%s" id="%s"]' % (p, ids[k]))
    lines += ['', '[node name="Level" type="Node2D" groups=["level"]]', '',
              '[node name="TileMapLayer" type="TileMapLayer" parent="." groups=["tilemap"]]',
              'scale = Vector2(2, 2)',
              'tile_map_data = PackedByteArray("%s")' % tile_data(),
              'tile_set = ExtResource("1_tiles")', '',
              '[node name="PlayerSpawn" type="Marker2D" parent="." groups=["player_spawn"]]',
              'position = %s' % fmt(SPAWN), '']
    for g in dict.fromkeys(GROUP_NODE[k] for k in used if GROUP_NODE[k]):
        lines += ['[node name="%s" type="Node2D" parent="."]' % g, '']
    for scene, name, pos, props in objects:
        parent = GROUP_NODE[scene] or "."
        lines.append('[node name="%s" parent="%s" instance=ExtResource("%s")]' % (name, parent, ids[scene]))
        lines.append("position = %s" % fmt(tuple(float(x) for x in pos)))
        for k, v in props.items():
            if k == "area":
                v = "Rect2(%g, %g, %g, %g)" % v
                lines.append("%s = %s" % (k, v))
                continue
            lines.append("%s = %s" % (k, fmt(v)))
        lines.append("")
    open(path, "w").write("\n".join(lines))


def write_preview(path, scale=8):
    """Tiny PNG writer (no PIL): one cell = `scale` pixels."""
    w, h = W * scale, H * scale
    px = [[(10, 10, 20)] * w for _ in range(h)]

    def rect(x0, y0, x1, y1, col):     # world coords
        for y in range(max(0, int(y0 * scale / T)), min(h, int(y1 * scale / T + 0.999))):
            for x in range(max(0, int(x0 * scale / T)), min(w, int(x1 * scale / T + 0.999))):
                px[y][x] = col

    for r in range(H):
        for c in range(W):
            if grid[r][c] == "#":
                rect(c * T, r * T, (c + 1) * T, (r + 1) * T, (90, 95, 110))
            elif grid[r][c] == ".":
                rect(c * T, r * T, (c + 1) * T, (r + 1) * T, (30, 30, 45))
    colors = {"grav_lift": (60, 160, 90), "force_field": (80, 200, 255),
              "one_way": (240, 160, 60), "slope": (200, 170, 120),
              "gate": (60, 230, 120), "airlock_door": (230, 140, 40)}
    for scene, name, (x, y), props in objects:
        sw, sh = props.get("size", (0, 0))
        if scene == "slope":
            for i in range(int(sw)):
                hgt = sh * (i / sw if props["rises_right"] else 1 - i / sw)
                rect(x + i, y - hgt, x + i + 1, y, colors[scene])
        elif scene == "gate":
            col = (255, 210, 60) if props.get("is_exit") else (170, 70, 200)
            rect(x - 24, y - 48, x + 24, y + 48, col)
        elif scene == "grapple_point":
            rect(x - 16, y - 16, x + 16, y + 16, (255, 160, 50))
        elif scene == "airlock_door":
            rect(x, y - 64, x + 8 * T, y, colors[scene])
        elif scene == "one_way" and props.get("rise"):
            steps = int(sw)
            for i in range(steps):
                yy = y - props["rise"] * i / sw
                rect(x + i, yy, x + i + 1, yy + 8, colors[scene])
        elif scene == "force_field":
            rect(x - 4, y, x + 4, y + props["height"], colors[scene])
        elif scene in colors:
            rect(x, y, x + sw, y + max(sh, 8), colors[scene])
    sx, sy = SPAWN
    rect(sx - 10, sy - 30, sx + 10, sy + 38, (255, 80, 80))

    raw = b"".join(b"\x00" + bytes(v for p in row for v in p) for row in px)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


write_scene("scenes/level.tscn")
if len(sys.argv) > 1:
    write_preview(sys.argv[1], scale=10)
print("wrote scenes/level.tscn")
