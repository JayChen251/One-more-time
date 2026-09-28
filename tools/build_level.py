#!/usr/bin/env python3
"""Generates scenes/level.tscn (the level blockout) and a PNG preview.

Run from the repo root:  python3 tools/build_level.py [preview.png]

Built on Jay's drawing (corridor, zigzag shaft) and extended so every run is
a race against the 25s self-destruct. Every section is hand-placed with
varied platform lengths, heights and gaps (Celeste-style: introduce an idea
safely, then combine it; rest spots between the hard parts).
  A  corridor       bump + ramp detour over a low field
  B  zigzag shaft   one-way ramps of different lengths, both directions
     -> JUMP gate
  C1 jump tower     ledges of different sizes and spacings
  C2 reactor gap    platforms over a pit at different heights
     -> TELEPORT gate
  D  gauntlet       a lone field, then pits, steps and double fields
     -> BOOST gate
  E  vent shaft     double jumps with a field splitting the shaft
     -> GRAPPLE gate
  F  hull breach    grapple chain with fields and one rest ledge -> EXIT
Each new ability also makes the earlier sections faster; the timing model at
the bottom estimates every run's best time (target 20-24s of the 25s).

One grid cell = one 64px tile. Once you edit the level by hand in Godot,
stop re-running this script: it overwrites scenes/level.tscn.
"""
import base64
import math
import struct
import sys
import zlib

T = 64

# ---------------------------------------------------------------- physics
# Keep in sync with scripts/player.gd and scripts/grapple_point.gd.
GRAVITY = 2500.0
WALK = 400.0
JUMP_V = 900.0
JUMP = JUMP_V ** 2 / (2 * GRAVITY)       # 162px
BOOST = 1000 ** 2 / (2 * GRAVITY)        # 200px (double jump)
TELEPORT = 160.0
RANGE = 440.0
PLAYER_H = 60


def jump_reach(dy):
    """Horizontal px a running jump covers while still able to land on a
    surface `dy` px higher (negative = lower)."""
    disc = JUMP_V ** 2 - 2 * GRAVITY * dy
    if disc < 0:
        return 0.0
    return WALK * (JUMP_V + math.sqrt(disc)) / GRAVITY


# ---------------------------------------------------------------- layout numbers
FLOOR = 3200
SHAFT_X0, SHAFT_X1 = 1600, 2560
D_FLOOR, D_CEIL = 1344, 960
HALL_FLOOR = 2816

objects = []                # (scene, name, position, {props})


def obj(scene, name, pos, **props):
    objects.append((scene, name, pos, props))


def platform(name, x0, x1, y, thick=12):
    obj("one_way", name, (x0, y), size=(x1 - x0, thick))


def ramp(name, x_left, y_left, x_right, y_right):
    obj("one_way", name, (x_left, y_left), size=(x_right - x_left, 12),
        rise=float(y_left - y_right))


def field(name, x, y_top, y_bottom):
    obj("force_field", name, (x, y_top), height=float(y_bottom - y_top))


def point(name, x, y):
    obj("grapple_point", name, (x, y))


hops = []                   # (label, gap px, dy px) for the jump checks


# A: corridor. A small bump (ramp up, ramp down) to warm up, then the
# platform + ramp detour over a low field.
solid_rects = [(256, FLOOR - 64, 448, FLOOR)]
ramp("BumpUp", 128, FLOOR, 256, FLOOR - 64)
ramp("BumpDown", 448, FLOOR - 64, 576, FLOOR)
platform("CorridorPlatform", 704, 1392, FLOOR - 96, thick=8)
ramp("CorridorRamp", 896, FLOOR - 96, 1088, FLOOR)
field("CorridorField", 1400, FLOOR - 80, FLOOR)
point("CorridorPoint1", 640, FLOOR - 210)
point("CorridorPoint2", 1300, FLOOR - 230)

# B: zigzag shaft (x 1600..2560). Legs: (ramp, next platform). Ramps go both
# ways and have different lengths; every ramp top has room to land.
# Walk: floor -> R0 right -> P1 back left -> R1 right -> P2 right -> R2 left
# -> P3 left -> R3 right -> P4 right -> R4 left -> P5 left -> R5 right -> P6.
ZIG = [3064, 2920, 2800, 2660, 2530, 2390]          # P1..P6 heights
ramp("Ramp0", 1696, FLOOR, 2240, ZIG[0])
platform("Level1", 1504, 2560, ZIG[0])
ramp("Ramp1", 1760, ZIG[0], 2016, ZIG[1])           # short and steep
platform("Level2", 2016, 2560, ZIG[1])
ramp("Ramp2", 1920, ZIG[2], 2400, ZIG[1])           # rises left
platform("Level3", 1600, 2112, ZIG[2])
ramp("Ramp3", 1696, ZIG[2], 2144, ZIG[3])
platform("Level4", 1984, 2560, ZIG[3])
ramp("Ramp4", 2144, ZIG[4], 2464, ZIG[3])           # rises left
platform("Level5", 1600, 2304, ZIG[4])
ramp("Ramp5", 1728, ZIG[4], 2048, ZIG[5])
platform("Level6", 1856, 2560, ZIG[5])              # jump gate at the far right
zig_ramps = [(1696, 2240), (1760, 2016), (1920, 2400), (1696, 2144), (2144, 2464), (1728, 2048)]
zig_flats = [2240 - 1760, 2400 - 2016, 1920 - 1696, 2464 - 2144, 2144 - 1728, 2496 - 2048]
for i, y in enumerate((3000, 2700, 2420)):
    point("ShaftPoint%d" % (i + 1), 2080, y)

# C1: jump tower. (x0, x1, y) ledges, each a different size and hop.
TOWER = [(2240, 2432, 2250), (1920, 2064, 2130), (1664, 1792, 1990),
         (1664, 1856, 1860), (2048, 2304, 1740), (2432, 2560, 1600),
         (2128, 2256, 1470), (2368, 2688, 1340)]
prev = (1856, 2560, ZIG[5])
for i, (x0, x1, y) in enumerate(TOWER):
    platform("Tower%d" % (i + 1), x0, x1, y)
    gap = max(0, x0 - prev[1], prev[0] - x1)
    hops.append(("tower %d" % (i + 1), gap, prev[2] - y))
    prev = (x0, x1, y)
for i, (x, y) in enumerate(((1984, 2040), (2176, 1700), (2300, 1400))):
    point("TowerPoint%d" % (i + 1), x, y)
Y_TRAV = TOWER[-1][2]

# C2: reactor gap. (x0, width, y) platforms over the pit; heights and gaps
# vary, one wide rest platform in the middle, one tiny one.
GAP = [(2880, 192, 1340), (3280, 96, 1276), (3584, 64, 1276), (3904, 256, 1404),
       (4384, 128, 1340), (4688, 96, 1212), (5056, 160, 1276)]
prev = (2368, 2688, Y_TRAV)
for j, (x0, w, y) in enumerate(GAP):
    platform("Gap%d" % (j + 1), x0, x0 + w, y)
    hops.append(("gap %d" % (j + 1), x0 - prev[1], prev[2] - y))
    prev = (x0, x0 + w, y)
D_X0 = 5504
hops.append(("gap -> gauntlet", D_X0 - prev[1], prev[2] - D_FLOOR))

# D: force-field gauntlet (floor 1344, ceiling 960). Intro: a lone field.
# Then a pit behind a field, a step under a field, rest, a wide pit split by
# two fields, and a step with a pit right after it.
field("GauntletField1", D_X0 + 320, D_CEIL, D_FLOOR)
pits = [(D_X0 + 704, D_X0 + 832)]
field("GauntletField2", D_X0 + 832, D_CEIL, D_FLOOR)
solid_rects.append((D_X0 + 1152, D_FLOOR - 128, D_X0 + 1216, D_FLOOR))
field("GauntletField3", D_X0 + 1184, D_CEIL, D_FLOOR - 128)
pits.append((D_X0 + 1856, D_X0 + 2112))
field("GauntletField4a", D_X0 + 1920, D_CEIL, D_FLOOR)
field("GauntletField4b", D_X0 + 2048, D_CEIL, D_FLOOR)
solid_rects.append((D_X0 + 2432, D_FLOOR - 128, D_X0 + 2496, D_FLOOR))
field("GauntletField5", D_X0 + 2464, D_CEIL, D_FLOOR - 128)
pits.append((D_X0 + 2496, D_X0 + 2624))
E_X0 = D_X0 + 2880

# E: vent shaft (640 wide). Ledges one double jump apart at uneven heights;
# a field splits the upper shaft, so switching sides means teleporting.
E_X1 = E_X0 + 640
VENT = [(E_X0 + 384, E_X0 + 576, D_FLOOR - 300), (E_X0 + 64, E_X0 + 288, D_FLOOR - 640),
        (E_X0 + 416, E_X0 + 704, D_FLOOR - 940)]
for i, (x0, x1, y) in enumerate(VENT):
    platform("Vent%d" % (i + 1), x0, x1, y)
E_MID = E_X0 + 336
field("VentField", E_MID, 64, VENT[0][2] - 70)
for i, y in enumerate((1080, 780, 480)):
    point("VentPoint%d" % (i + 1), E_X0 + 480, y)

# F: hull breach. Grapple points at varied spacing and height, a rest ledge
# in the middle, fields blocking the aim twice.
F_X0 = E_X1 + 64
BREACH = [(F_X0 + 200, 380), (F_X0 + 560, 300), (F_X0 + 900, 470), (F_X0 + 1300, 420),
          (F_X0 + 1640, 330), (F_X0 + 2000, 520), (F_X0 + 2380, 400),
          (F_X0 + 2760, 300), (F_X0 + 3100, 460), (F_X0 + 3480, 360),
          (F_X0 + 3840, 420)]
for i, (x, y) in enumerate(BREACH):
    point("BreachPoint%d" % (i + 1), x, y)
field("BreachField1", (BREACH[2][0] + BREACH[3][0]) // 2, 64, 1100)
platform("BreachRest", F_X0 + 2160, F_X0 + 2320, 700)      # breather
field("BreachField2", (BREACH[8][0] + BREACH[9][0]) // 2, 64, 1100)
F_END = math.ceil((BREACH[-1][0] + 256) / T) * T
solid_rects.append((F_END - 192, 576, F_END, 640))           # exit ledge

# Gates (closes_at 0 = never seals: the 25s self-destruct is the limit).
obj("gate", "GateJump", (2496, ZIG[5] - 48), unlocks="jump")
obj("gate", "GateTeleport", (D_X0 + 96, D_FLOOR - 48), unlocks="teleport")
obj("gate", "GateBoost", (E_X0 + 96, D_FLOOR - 48), unlocks="boost")
obj("gate", "GateGrapple", (E_X0 + 560, VENT[2][2] - 48), unlocks="grapple")
obj("gate", "Exit", (F_END - 96, 576 - 48), is_exit=True)
obj("airlock_door", "AirlockDoor", (F_END, 384))
obj("starfield", "Starfield", (F_END + 64, 0), area=(0, -1200, 4000, 4400))

SPAWN = (96, FLOOR - 40)

# ---------------------------------------------------------------- tiles
W = math.ceil((F_END + 64) / T) + 1
H = 52
grid = [[" "] * W for _ in range(H)]


def carve(x0, y0, x1, y1, ch="."):
    """Carve a pixel rectangle (must be on the 64px grid)."""
    assert all(v % T == 0 for v in (x0, y0, x1, y1)), (x0, y0, x1, y1)
    for r in range(y0 // T, y1 // T):
        for c in range(x0 // T, x1 // T):
            grid[r][c] = ch


carve(0, 0, W * T, H * T, "#")                          # hull
carve(64, FLOOR - 384, SHAFT_X0, FLOOR)                 # A corridor
carve(SHAFT_X0, 896, SHAFT_X1, FLOOR)                   # B + C1
carve(SHAFT_X1, 1024, SHAFT_X1 + 64, 1408)              # tower top -> gap
carve(SHAFT_X1, HALL_FLOOR - 128, SHAFT_X1 + 64, HALL_FLOOR)  # hall -> shaft
carve(SHAFT_X1 + 64, 960, D_X0, HALL_FLOOR)             # C2 void + hall
carve(D_X0, D_CEIL, E_X0, D_FLOOR)                      # D gauntlet
carve(D_X0, D_FLOOR + 64, F_END, HALL_FLOOR)            # hall under D/E/F
carve(E_X0, 64, E_X1, D_FLOOR)                          # E vent shaft
carve(E_X1, 64, F_X0, 448)                              # E -> F opening
carve(F_X0, 64, F_END, HALL_FLOOR)                      # F breach void
carve(F_END, 384, F_END + 64, 576)                      # airlock opening
for x0, x1 in pits:
    carve(x0, D_FLOOR, x1, D_FLOOR + 64)
for rect in solid_rects:
    carve(*rect, ch="#")

# ---------------------------------------------------------------- checks
checks = [
    ("walker fits under corridor platform", PLAYER_H < 96 - 8),
    ("corridor field blocks a floor walker", 80 > PLAYER_H),
    ("zigzag steps are one jump", max(FLOOR - ZIG[0], *(a - b for a, b in zip(ZIG, ZIG[1:]))) <= JUMP - 15),
    ("walker fits between zigzag levels", min(a - b for a, b in zip(ZIG, ZIG[1:])) - 12 > PLAYER_H),
    ("gauntlet steps are jumpable", 128 <= JUMP - 20),
    ("vent ledges need a double jump", all(JUMP < d <= JUMP + BOOST - 20 for d in
        (D_FLOOR - VENT[0][2], VENT[0][2] - VENT[1][2], VENT[1][2] - VENT[2][2]))),
    ("breach points in range", all(math.dist(a, b) < RANGE for a, b in zip(BREACH, BREACH[1:]))),
]
for label, gap, dy in hops:
    checks.append(("%s: gap %d, %+d up (reach %d)" % (label, gap, dy, jump_reach(dy)),
                   gap + 20 <= jump_reach(dy)))
for label, ok in checks:
    print(("ok   " if ok else "FAIL ") + label)
    assert ok, label

# ---------------------------------------------------------------- timing model
# Rough best-case estimates (seconds), not measurements.
TP_SPEED, RAMP_SPEED = 750.0, 340.0


def chain(pts):
    return sum(math.dist(a, b) / 1400 + 0.15 for a, b in zip(pts, pts[1:]))


corridor = SHAFT_X0 - SPAWN[0]
walk_a = corridor / WALK + 0.4 + ((1400 - 1088) * 2 / WALK + (1088 - 896) * 2 / RAMP_SPEED)
walk_b = sum((b - a) / RAMP_SPEED for a, b in zig_ramps) + sum(zig_flats) / WALK + 0.15 * 6
tower_jump = sum(0.5 + g / WALK for _, g, _ in hops[:len(TOWER)])
gap_len = D_X0 + 96 - 2688
gap_jump = sum(0.15 + g / WALK for _, g, _ in hops[len(TOWER):]) + sum(w for _, w, _ in GAP) / WALK
d_len = E_X0 + 96 - D_X0
f_chain = chain([(E_X0 + 560, VENT[2][2] - 38)] + BREACH) + 2 * 0.35 + 0.5
sections = {
    #      walk     jump          +teleport          +boost             +grapple
    "A":  [walk_a, corridor / WALK, corridor / TP_SPEED, corridor / TP_SPEED,
           corridor / TP_SPEED * 0.8],
    "B":  [walk_b, 6 * 0.5 + 0.4, 6 * 0.5 + 0.3, 3 * 0.85 + 0.3,
           chain([(1600, 3162), (2080, 3000), (2080, 2700), (2080, 2420)]) + 0.3],
    "C1": [None, tower_jump, tower_jump * 0.85, tower_jump * 0.65,
           chain([(2080, 2420), (1984, 2040), (2176, 1700), (2300, 1400)]) + 0.5],
    "C2": [None, gap_jump, gap_len / 620, gap_len / 680, gap_len / 680],
    "D":  [None, None, d_len / TP_SPEED + 2.6, d_len / TP_SPEED + 2.4, d_len / TP_SPEED + 2.4],
    "E":  [None, None, None, 3 * 1.0 + 0.3, chain([(E_X0 + 96, 1306), (E_X0 + 480, 1080), (E_X0 + 480, 780), (E_X0 + 480, 480)]) + 0.5],
    "F":  [None, None, None, None, f_chain],
}
runs = [("walk -> JUMP gate", 0, ["A", "B"]),
        ("jump -> TELEPORT gate", 1, ["A", "B", "C1", "C2"]),
        ("+teleport -> BOOST gate", 2, ["A", "B", "C1", "C2", "D"]),
        ("+boost -> GRAPPLE gate", 3, ["A", "B", "C1", "C2", "D", "E"]),
        ("+grapple -> EXIT", 4, ["A", "B", "C1", "C2", "D", "E", "F"])]
print("\nestimated best times (self-destruct 25s):")
for label, k, secs in runs:
    total = sum(sections[s][k] for s in secs)
    print("  %-26s %5.1fs   (%s)" % (label, total,
          ", ".join("%s %.1f" % (s, sections[s][k]) for s in secs)))

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
    write_preview(sys.argv[1], scale=4)
print("wrote scenes/level.tscn")
