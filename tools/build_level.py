#!/usr/bin/env python3
"""Generates scenes/level.tscn (the level blockout) and a PNG preview.

Run from the repo root:  python3 tools/build_level.py [preview.png]

One vertical path through the ship (Jay's drawing), split into chunks by
horizontal hatches that slide shut at set times:
  chunk 0  corridor + zigzag shaft (walkable)     -> JUMP unlock
  hatch 1  (needs jump to reach at all)
  chunk 1  fields to hop over or teleport through  -> TELEPORT unlock
  hatch 2  closes before you get there without teleport
  chunk 2  field wall + step under a field (jump+teleport) -> BOOST unlock
  hatch 3  closes before you get there without the double jump
  chunk 3  field + raised block (jump+teleport+double jump)
                                                   -> GRAPPLE unlock
  hatch 4  closes before you get there without the grapple
  chunk 4  jump, grapple, teleport, double jump, triple grapple ascent;
           crossing the escape line near the top wins
Hatch closing times come from the timing model at the bottom.

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
FLOOR = 4416                 # ground level; heights below are measured up from it
SHAFT_X0, SHAFT_X1 = 1600, 2560
COLUMN = (1600, 1856)        # left column the hatches 2-4 sit in


def Y(h):
    """World y of a height `h` px above the floor."""
    return FLOOR - h


objects = []                # (scene, name, position, {props})
solid_rects = []            # extra solid tiles (x0, y0, x1, y1)
hops = []                   # (label, gap px, dy px) for the jump checks


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


def slab(h, x0, x1):
    """A 64px solid floor whose top is at height h."""
    solid_rects.append((x0, Y(h), x1, Y(h) + 64))


# A: corridor. A small bump (ramp up, ramp down), then the platform + ramp
# detour over a low field (walkers go up the ramp and over it).
solid_rects.append((256, FLOOR - 64, 448, FLOOR))
ramp("BumpUp", 128, FLOOR, 256, FLOOR - 64)
ramp("BumpDown", 448, FLOOR - 64, 576, FLOOR)
platform("CorridorPlatform", 704, 1392, FLOOR - 96, thick=8)
field("CorridorField", 1400, FLOOR - 80, FLOOR)      # walk over it from the platform
ramp("CorridorRamp", 896, FLOOR - 96, 1088, FLOOR)
point("CorridorPoint1", 640, FLOOR - 210)
point("CorridorPoint2", 1300, FLOOR - 230)

# B (chunk 0): zigzag shaft. Ramps both ways, different lengths; walkable.
ZIG = [Y(h) for h in (136, 280, 400, 540, 680, 820)]
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
platform("Level6", 1856, 2688, ZIG[5])              # runs into the jump-unlock alcove
zig_ramps = [(1696, 2240), (1760, 2016), (1920, 2400), (1696, 2144), (2144, 2464), (1728, 2048)]
zig_flats = [2240 - 1760, 2400 - 2016, 1920 - 1696, 2464 - 2144, 2144 - 1728, 2496 - 2048]
SHAFT_POINTS = [(2080, Y(200)), (2080, Y(500)), (2400, Y(780))]   # last one under hatch 1
for i, (x, y) in enumerate(SHAFT_POINTS):
    point("ShaftPoint%d" % (i + 1), x, y)

# Chunk floors. Each has one opening (with a one-way platform in it) that a
# hatch closes at a set time.
F1, F2, F3, F4 = 960, 1344, 1856, 2432
OPENINGS = {1: (2304, 2560, F1), 2: (COLUMN[0], COLUMN[1], F2),
            3: (COLUMN[0], COLUMN[1], F3), 4: (COLUMN[0], COLUMN[1], F4)}
slab(F1, SHAFT_X0, 2304)
# No other gaps in these floors: the hatch openings are the only way up.
slab(F2, 1856, SHAFT_X1)
slab(F3, 1856, SHAFT_X1)
slab(F4, 1856, SHAFT_X1)
for n, (x0, x1, h) in OPENINGS.items():
    platform("Opening%d" % n, x0, x1, Y(h))

# Chunk 1 (jump -> teleport unlock). Two fields that stop at 190px: jump up
# a platform and over each (or teleport straight through), then climb the
# left column to the next hatch.
for name, x in (("Chunk1FieldA", 2176), ("Chunk1FieldB", 1920)):
    field(name, x, Y(F1 + 190), Y(F1))
platform("Chunk1OverA", 2208, 2304, Y(F1 + 140))
platform("Chunk1OverB", 1952, 2080, Y(F1 + 140))
platform("Chunk1Stair1", 1600, 1792, Y(F1 + 140))
platform("Chunk1Stair2", 1664, 1856, Y(F1 + 280))

# Chunk 2 (jump + teleport -> boost unlock). Along the floor: a field wall,
# then a step under a field; stairs up to a walkway back left. With the
# double jump you go straight up the left column instead.
W2 = F2 + 280
field("Chunk2Field", 2112, Y(W2) + 12, Y(F2))
solid_rects.append((2240, Y(F2 + 128), 2304, Y(F2)))
field("Chunk2StepField", 2272, Y(W2) + 12, Y(F2 + 128))
platform("Chunk2Stair", 2368, 2560, Y(F2 + 140))
platform("Chunk2Walkway", 1856, 2688, Y(W2))        # into the boost-unlock alcove
platform("Chunk2ColumnLedge", 1600, 1760, Y(W2))     # one double jump up
platform("Chunk2ColumnTop", 1664, 1856, Y(W2 + 140))

# Chunk 3 (jump + teleport + double jump -> grapple unlock). A field wall and
# a raised block right behind it: teleport through, then jump + double jump
# onto the block. Then up to a walkway back to the column. With the grapple
# you go straight up instead.
BLOCK = F3 + 192
W3 = F3 + 440
field("Chunk3Field", 2112, Y(W3) + 12, Y(F3))
solid_rects.append((2240, Y(BLOCK), SHAFT_X1, Y(F3)))
platform("Chunk3Stair", 2368, 2560, Y(BLOCK + 140))
platform("Chunk3Walkway", 1856, 2304, Y(W3))
point("Chunk3Point1", 1728, Y(F3 + 284))
point("Chunk3Point2", 1728, Y(F4 + 8))

# Chunk 4 (everything -> escape), in this order: JUMP to get in range of a
# grapple point that's just out of reach from the floor, GRAPPLE up to it,
# TELEPORT right through the floor-to-ceiling field, DOUBLE JUMP onto the
# ledge, then GRAPPLE three times up the channel past the escape line.
CEIL4 = F4 + 704
FIELD4_X = 2112
field("ChallengeField", FIELD4_X, Y(CEIL4), Y(F4))
CHALLENGE_POINT = (2048, Y(F4 + 500))
point("ChallengePoint", *CHALLENGE_POINT)
LEDGE = F4 + 620
platform("ChallengeLedge", 2368, 2496, Y(LEDGE))
CHANNEL_X0 = 2176
CHANNEL = [(2432, Y(LEDGE + 38 + 400 + 240 * i)) for i in range(3)]
for i, (x, y) in enumerate(CHANNEL):
    point("ChannelPoint%d" % (i + 1), x, y)
ESCAPE_H = LEDGE + 1000          # crossing this height ends the game
DOOR_H = ESCAPE_H + 80

SPAWN = (96, FLOOR - 40)

# ---------------------------------------------------------------- tiles
W = 50
H = FLOOR // T + 2
grid = [[" "] * W for _ in range(H)]


def carve(x0, y0, x1, y1, ch="."):
    """Carve a pixel rectangle (must be on the 64px grid)."""
    assert all(v % T == 0 for v in (x0, y0, x1, y1)), (x0, y0, x1, y1)
    for r in range(y0 // T, y1 // T):
        for c in range(x0 // T, x1 // T):
            grid[r][c] = ch


carve(0, 0, W * T, H * T, "#")                          # hull
carve(64, FLOOR - 384, SHAFT_X0, FLOOR)                 # A corridor
carve(SHAFT_X0, Y(CEIL4), SHAFT_X1, FLOOR)              # the shaft, chunks 0-4
carve(CHANNEL_X0, 0, SHAFT_X1, Y(CEIL4))                # exit channel, airlock, sky


def alcove(x0, floor_y):
    """A hole in a side wall, 2 tiles wide and 3 tall, for an unlock icon.
    `floor_y` is rounded down to the grid."""
    bottom = -(-int(floor_y) // T) * T
    carve(x0, bottom - 3 * T, x0 + 2 * T, bottom)
    return x0 + T


ALCOVES = {                     # ability: (icon x, floor y)
    "jump": (alcove(SHAFT_X1, ZIG[5]), ZIG[5]),
    "teleport": (alcove(SHAFT_X0 - 2 * T, Y(F1)), Y(F1)),
    "boost": (alcove(SHAFT_X1, Y(W2)), Y(W2)),
    "grapple": (alcove(SHAFT_X1, Y(BLOCK)), Y(BLOCK)),
}
for rect in solid_rects:
    carve(*rect, ch="#")

# ---------------------------------------------------------------- checks
def apex(h_from):
    return h_from + JUMP


checks = [
    ("walker fits under corridor platform", PLAYER_H < 96 - 8),
    ("corridor field blocks a floor walker", 80 > PLAYER_H),
    ("shaft grapple points in range", all(math.dist(a, b) < RANGE for a, b in zip(SHAFT_POINTS, SHAFT_POINTS[1:]))),
    ("zigzag steps are one jump", max(FLOOR - ZIG[0], *(a - b for a, b in zip(ZIG, ZIG[1:]))) <= JUMP - 15),
    ("walker fits between zigzag levels", min(a - b for a, b in zip(ZIG, ZIG[1:])) - 12 > PLAYER_H),
    ("top zigzag level -> first hatch is one jump", F1 - 820 <= JUMP - 15),
    ("zigzag heads clear the chunk-1 floor", 820 + PLAYER_H < F1 - 64),
    # chunk 1
    ("chunk 1 fields can't be jumped from the floor", apex(F1) < F1 + 190),
    ("chunk 1: from the platform you clear the field", apex(F1 + 140) > F1 + 190 + 10),
    ("chunk 1: and don't bonk the ceiling first", F1 + 190 + PLAYER_H < F2 - 64),
    ("chunk 1 stairs are jumps", max(140, 140, F2 - (F1 + 280)) <= JUMP - 15),
    # chunk 2
    ("chunk 2 walkway out of jump reach", apex(F2) < W2),
    ("chunk 2 column ledge is one double jump", JUMP < W2 - F2 <= JUMP + BOOST - 30),
    ("chunk 2 step is jumpable", 128 <= JUMP - 20),
    ("chunk 2 column top -> hatch 3 is a jump", F3 - (W2 + 140) <= JUMP - 15),
    ("chunk 3 teleport stops in front of the block", 2240 - 2112 > 2 * 10 + 20),
    # chunk 3
    ("chunk 3 block needs the double jump", JUMP < BLOCK - F3 <= JUMP + BOOST - 30),
    ("chunk 3 walkway out of double-jump reach from the floor", F3 + JUMP + BOOST < W3),
    ("chunk 3 walkway fits under the ceiling", W3 + PLAYER_H < F4 - 64),
    ("chunk 3 walkway -> hatch 4 is a jump", F4 - W3 <= JUMP - 15),
    ("chunk 3 grapple points in range", math.dist((1728, Y(F3 + 38)), (1728, Y(F3 + 284))) < RANGE
     and math.dist((1728, Y(F3 + 284)), (1728, Y(F4 + 8))) < RANGE),
    # chunk 4
    ("chunk 4 grapple point out of range standing on the floor",
     math.dist((CHALLENGE_POINT[0], Y(F4 + 38)), CHALLENGE_POINT) > RANGE),
    ("chunk 4 grapple point in range at the top of a jump",
     math.dist((CHALLENGE_POINT[0], Y(F4 + 38 + JUMP)), CHALLENGE_POINT) < RANGE - 20),
    ("chunk 4 rising off the grapple point stays under the ceiling",
     F4 + 500 + 112 + 22 < CEIL4),
    ("chunk 4 teleport from the point clears the field", CHALLENGE_POINT[0] + TELEPORT - 10 > FIELD4_X + 20),
    ("chunk 4 ledge out of reach without the double jump", F4 + 500 - 38 + 112 < LEDGE),
    ("chunk 4 ledge reachable with the double jump", F4 + 500 - 38 + 112 + BOOST > LEDGE + 30),
    ("chunk 4 ledge out of double-jump reach from the floor", F4 + JUMP + BOOST < LEDGE),
    ("chunk 4 ascent out of range after the grapple point",
     math.dist((CHALLENGE_POINT[0] + TELEPORT, Y(F4 + 612)), CHANNEL[0]) > RANGE),
    ("chunk 4 ledge -> ascent in range", math.dist((2432, Y(LEDGE + 38)), CHANNEL[0]) < RANGE),
    ("channel points in range", all(math.dist(a, b) < RANGE for a, b in zip(CHANNEL, CHANNEL[1:]))),
    ("last point carries you past the escape line", FLOOR - CHANNEL[-1][1] + 112 > ESCAPE_H + 10),
    ("the sky above the door fits in the map", FLOOR - DOOR_H > 128),
]
for label, gap, dy in hops:
    checks.append(("%s: gap %d, %+d up (reach %d)" % (label, gap, dy, jump_reach(dy)),
                   gap + 20 <= jump_reach(dy)))
for label, ok in checks:
    print(("ok   " if ok else "FAIL ") + label)
    assert ok, label

# ---------------------------------------------------------------- timing model
# Rough best-case estimates (seconds), not measurements. Each hatch closes
# halfway between the estimated arrival with the ability from the chunk below
# and without it (but at least MIN_SLACK after the fast arrival).
TP_SPEED, RAMP_SPEED = 750.0, 340.0
MIN_SLACK = 2.0
HATCH_EXTRA = {4: 1.5}       # hand-tuned extra seconds for specific hatches


def chain(pts):
    return sum(math.dist(a, b) / 1400 + 0.15 for a, b in zip(pts, pts[1:]))


corridor = SHAFT_X0 - SPAWN[0]
A = {"walk": corridor / WALK + 0.4 + ((1400 - 1088) * 2 / WALK + (1088 - 896) * 2 / RAMP_SPEED),
     "jump": corridor / WALK, "tp": corridor / TP_SPEED, "grapple": corridor / TP_SPEED * 0.8}
ZIGT = {"walk": sum((b - a) / RAMP_SPEED for a, b in zig_ramps) + sum(zig_flats) / WALK + 0.15 * 6,
        "jump": 7 * 0.5 + 0.3, "boost": 3 * 0.85 + 0.3,
        "grapple": chain([(1600, FLOOR - 38)] + SHAFT_POINTS) + 0.8}
CH1 = {"jump": 800 / WALK + 4 * 0.5 + 2 * 0.2 + 3 * 0.5, "tp": 800 / TP_SPEED + 3 * 0.5,
       "boost": 800 / TP_SPEED + 0.9 + 0.5}
CH2 = {"tp": 1400 / TP_SPEED + 0.3 + 0.5 + 2 * 0.5 + 3 * 0.5, "boost": 0.9 + 2 * 0.5}
CH3 = {"boost": 600 / TP_SPEED + 1.2 + 2 * 0.5 + 0.5, "grapple": chain([(1728, Y(F3 + 38)), (1728, Y(F3 + 284)), (1728, Y(F4 + 8))]) + 0.2}
CH4 = 0.4 + chain([(CHALLENGE_POINT[0], Y(F4 + 200)), CHALLENGE_POINT]) + 0.1 + 0.6 \
    + chain([(2432, Y(LEDGE + 38))] + CHANNEL) + 0.2

arrive = {
    # (fast: with the ability from the chunk below, slow: without it)
    "jump unlock (walk)": A["walk"] + ZIGT["walk"],
    "hatch 1": (A["jump"] + ZIGT["jump"], None),
    "hatch 2": (A["tp"] + ZIGT["jump"] + CH1["tp"], A["jump"] + ZIGT["jump"] + CH1["jump"]),
    "hatch 3": (A["tp"] + ZIGT["boost"] + CH1["boost"] + CH2["boost"],
                A["tp"] + ZIGT["jump"] + CH1["tp"] + CH2["tp"]),
    "hatch 4": (A["grapple"] + ZIGT["grapple"] + CH1["boost"] + CH2["boost"] + CH3["grapple"],
                A["tp"] + ZIGT["boost"] + CH1["boost"] + CH2["boost"] + CH3["boost"]),
}
print("\nestimated arrival times (self-destruct 25s):")
print("  %-20s %5.1fs" % ("jump unlock (walk)", arrive["jump unlock (walk)"]))
hatch_close = {}
for n in (1, 2, 3, 4):
    fast, slow = arrive["hatch %d" % n]
    close = fast + 3.0 if slow is None else max(fast + MIN_SLACK, (fast + slow) / 2)
    hatch_close[n] = round(close * 2) / 2 + HATCH_EXTRA.get(n, 0.0)
    print("  hatch %d  with new ability %5.1fs | without %s -> closes at %.1fs" %
          (n, fast, "%.1fs" % slow if slow else "(can't reach)", hatch_close[n]))
print("  escape (all abilities)    %5.1fs" % (arrive["hatch 4"][0] + CH4))

for n, (x0, x1, h) in OPENINGS.items():
    obj("hatch", "Hatch%d" % n, (x0, Y(h)), width=float(x1 - x0), closes_at=hatch_close[n])

# Unlock stations (they no longer close; the hatches set the pace).
for ability, (x, floor_y) in ALCOVES.items():
    obj("gate", "Unlock" + ability.capitalize(), (x, floor_y - 48), unlocks=ability)
obj("airlock_door", "AirlockDoor", (CHANNEL_X0, Y(DOOR_H)), rotation=-1.5708,
    scale=(1.0, (SHAFT_X1 - CHANNEL_X0) / 192))
obj("starfield", "Starfield", (0, 0), area=(-1000, -3000, 5000, 3500))

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
    "hatch": "res://scenes/hatch.tscn",
}
GROUP_NODE = {
    "slope": "Slopes", "one_way": "Platforms", "grav_lift": "Lifts",
    "force_field": "ForceFields", "grapple_point": "GrapplePoints",
    "gate": "Gates", "airlock_door": None, "starfield": None, "hatch": "Hatches",
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


def tile_scheme(r):
    """Colour scheme (tileset row) for a grid row: one per chunk of the ship."""
    h = FLOOR - r * T
    return sum(1 for f in (F1, F2, F3, F4) if h >= f)


def tile_data():
    out = bytearray(b"\x00\x00")
    for r in range(H):
        for c in range(W):
            if grid[r][c] != "#":
                continue
            # Which sides face open air (see tools/build_tileset.py).
            mask = 0
            for bit, (dr, dc) in ((1, (-1, 0)), (2, (0, 1)), (4, (1, 0)), (8, (0, -1))):
                rr, cc = r + dr, c + dc
                if 0 <= rr < H and 0 <= cc < W and grid[rr][cc] == ".":
                    mask |= bit
            # TileMapLayer is scaled x2, so a 32px tile covers one cell.
            out += struct.pack("<hhHhhH", c, r, 0, mask, tile_scheme(r), 0)
    return base64.b64encode(bytes(out)).decode()


def write_scene(path):
    used = [k for k in EXT if any(o[0] == k for o in objects)]
    ids = {k: "%d_%s" % (i + 2, k) for i, k in enumerate(used)}
    lines = ['[gd_scene load_steps=%d format=3]' % (len(used) + 2), '',
             '[ext_resource type="TileSet" path="res://resources/ship_tileset.tres" id="1_tiles"]']
    for k in used:
        p = EXT[k]
        lines.append('[ext_resource type="PackedScene" path="%s" id="%s"]' % (p, ids[k]))
    lines += ['', '[node name="Level" type="Node2D" groups=["level"]]', '',
              '[node name="TileMapLayer" type="TileMapLayer" parent="." groups=["tilemap"]]',
              'scale = Vector2(2, 2)',
              'tile_map_data = PackedByteArray("%s")' % tile_data(),
              'tile_set = ExtResource("1_tiles")', '',
              '[node name="PlayerSpawn" type="Marker2D" parent="." groups=["player_spawn"]]',
              'position = %s' % fmt(SPAWN), '',
              '[node name="EscapeLine" type="Marker2D" parent="." groups=["escape_line"]]',
              'position = %s' % fmt((float(CHANNEL_X0), float(Y(ESCAPE_H)))), '']
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
            col = {"jump": (115, 255, 140), "teleport": (90, 230, 255), "boost": (205, 128, 255),
                   "grapple": (255, 166, 50)}.get(props.get("unlocks"), (255, 210, 60))
            rect(x - 16, y - 56, x + 16, y - 24, col)
        elif scene == "grapple_point":
            rect(x - 16, y - 16, x + 16, y + 16, (255, 160, 50))
        elif scene == "airlock_door":
            rect(x, y - 64, x + 192 * props["scale"][1], y, colors[scene])
        elif scene == "one_way" and props.get("rise"):
            steps = int(sw)
            for i in range(steps):
                yy = y - props["rise"] * i / sw
                rect(x + i, yy, x + i + 1, yy + 8, colors[scene])
        elif scene == "hatch":
            rect(x, y, x + props["width"], y + 16, (230, 60, 60))
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
