#!/usr/bin/env python3
"""Generates scenes/level.tscn (the level blockout) and a PNG preview.

Run from the repo root:  python3 tools/build_level.py [preview.png]

Follows Jay's drawing:
  A  corridor         bump + ramp detour over a low field
  B  zigzag shaft     one-way ramps of different lengths, both directions
                      -> JUMP gate (top platform, right end)
  U  upper shaft      varied jump platforms
                      -> TELEPORT gate (left wall platform)
                      -> BOOST gate (room right of the ledge, behind a field:
                         jump from the ledge, teleport in at the top)
                      -> GRAPPLE gate (pocket behind the left wall: double
                         jump up, jump at the wall, teleport through)
                      -> EXIT (grapple up the top-right channel to the airlock)
Speed is enforced by the gates: each one seals `closes_at` seconds into the
run. Those times come from the timing model at the bottom (estimated best
time with the abilities you have then, plus GATE_SLACK seconds).

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

# U: upper shaft (Jay's drawing). Platforms above the zigzag, each a
# different size and hop.
UPPER = [(2208, 2432, 2260), (1856, 2048, 2130), (1600, 1920, 1990)]
prev = (1856, 2560, ZIG[5])
for i, (x0, x1, y) in enumerate(UPPER):
    platform("Upper%d" % (i + 1), x0, x1, y)
    gap = max(0, x0 - prev[1], prev[0] - x1)
    hops.append(("upper %d" % (i + 1), gap, prev[2] - y))
    prev = (x0, x1, y)
TP_PLATFORM = UPPER[2]                               # teleport gate, left end
field("TpPlatformField", TP_PLATFORM[1] + 8, TP_PLATFORM[2] - 100, TP_PLATFORM[2])

# Ledge right of the shaft (top 2112) and the boost room above it, sealed by
# a field: jump from the ledge and teleport in at the top of the jump.
LEDGE_Y, ROOM_FLOOR = 2112, 1984
hops.append(("upper 1 -> ledge", SHAFT_X1 - UPPER[0][1], UPPER[0][2] - LEDGE_Y))
field("BoostRoomField", 2816, 1856, ROOM_FLOOR)

# Double-jump platform, and the grapple pocket behind the left wall.
DJ_PLATFORM = (1728, 1920, 1780)
platform("DoubleJumpPlatform", *DJ_PLATFORM)
POCKET_FLOOR = 1728
field("PocketField", SHAFT_X0, 1536, POCKET_FLOOR)

# Exit channel (top right): grapple up to the airlock.
CHANNEL = [(2176, 1620), (2432, 1380), (2432, 1100), (2432, 820)]
for i, (x, y) in enumerate(CHANNEL):
    point("ChannelPoint%d" % (i + 1), x, y)
EXIT_Y = 690

SPAWN = (96, FLOOR - 40)

# ---------------------------------------------------------------- tiles
W, H = 50, 52
grid = [[" "] * W for _ in range(H)]


def carve(x0, y0, x1, y1, ch="."):
    """Carve a pixel rectangle (must be on the 64px grid)."""
    assert all(v % T == 0 for v in (x0, y0, x1, y1)), (x0, y0, x1, y1)
    for r in range(y0 // T, y1 // T):
        for c in range(x0 // T, x1 // T):
            grid[r][c] = ch


carve(0, 0, W * T, H * T, "#")                          # hull
carve(64, FLOOR - 384, SHAFT_X0, FLOOR)                 # A corridor
carve(SHAFT_X0, 1472, SHAFT_X1, FLOOR)                  # B zigzag + U upper shaft
carve(SHAFT_X1, 1856, 2816, LEDGE_Y)                    # space above the ledge
carve(2816, 1856, 3072, ROOM_FLOOR)                     # boost room
carve(1344, 1536, SHAFT_X0, POCKET_FLOOR)               # grapple pocket
carve(2304, 640, SHAFT_X1, 1472)                        # exit channel
carve(2304, 0, SHAFT_X1, 640)                           # airlock (door) and open sky above
for rect in solid_rects:
    carve(*rect, ch="#")

# ---------------------------------------------------------------- checks
JUMP_APEX_FOOT = LEDGE_Y - JUMP
checks = [
    ("walker fits under corridor platform", PLAYER_H < 96 - 8),
    ("corridor field blocks a floor walker", 80 > PLAYER_H),
    ("zigzag steps are one jump", max(FLOOR - ZIG[0], *(a - b for a, b in zip(ZIG, ZIG[1:]))) <= JUMP - 15),
    ("walker fits between zigzag levels", min(a - b for a, b in zip(ZIG, ZIG[1:])) - 12 > PLAYER_H),
    ("boost room: jump from ledge clears its floor", JUMP_APEX_FOOT < ROOM_FLOOR - 15),
    ("boost room: body fits the doorway at the apex", JUMP_APEX_FOOT - PLAYER_H > 1856),
    ("teleport from the ledge wall lands in the room", 2816 - 10 + TELEPORT - 10 > 2816 + 20),
    ("double-jump platform needs the double jump",
     JUMP < TP_PLATFORM[2] - DJ_PLATFORM[2] <= JUMP + BOOST - 30),
    ("pocket doorway reachable with a jump from the platform",
     DJ_PLATFORM[2] - JUMP < POCKET_FLOOR - 20),
    ("teleport from the wall lands in the pocket", SHAFT_X0 + 10 - TELEPORT + 10 < SHAFT_X0 - 20),
    ("first channel point in range", math.dist((DJ_PLATFORM[1], DJ_PLATFORM[2] - 38), CHANNEL[0]) < RANGE),
    ("channel points in range", all(math.dist(a, b) < RANGE for a, b in zip(CHANNEL, CHANNEL[1:]))),
    ("last point carries you into the exit", CHANNEL[-1][1] - 750 ** 2 / (2 * GRAVITY) - 22 < EXIT_Y + 48),
    ("exit out of reach without grapple", DJ_PLATFORM[2] - JUMP - BOOST - PLAYER_H > EXIT_Y + 48),
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
GATE_SLACK = 3.0             # seconds of leeway before a gate seals


def chain(pts):
    return sum(math.dist(a, b) / 1400 + 0.15 for a, b in zip(pts, pts[1:]))


corridor = SHAFT_X0 - SPAWN[0]
a = {"walk": corridor / WALK + 0.4 + ((1400 - 1088) * 2 / WALK + (1088 - 896) * 2 / RAMP_SPEED),
     "jump": corridor / WALK, "tp": corridor / TP_SPEED, "grapple": corridor / TP_SPEED * 0.8}
zig = {"walk": sum((b - a) / RAMP_SPEED for a, b in zig_ramps) + sum(zig_flats) / WALK + 0.15 * 6,
       "jump": 6 * 0.5 + 0.4, "boost": 3 * 0.85 + 0.3,
       "grapple": chain([(1600, 3162), (2080, 3000), (2080, 2700), (2080, 2420)]) + 0.3}
upper_jumps = sum(0.5 + g / WALK for _, g, _ in hops[:3])
estimates = {
    "jump": a["walk"] + zig["walk"],
    "teleport": a["jump"] + zig["jump"] + upper_jumps + 0.4,
    "boost": a["tp"] + zig["jump"] + 0.6 + 0.8 + 0.7,
    "grapple": a["tp"] + zig["boost"] + 2 * 0.9 + 0.9 + 0.8,
    "exit": a["grapple"] + zig["grapple"] + 1.5 + chain([(1900, 1742)] + CHANNEL) + 0.3,
}
print("\nestimated best times -> gate closes at (self-destruct 25s):")
closes = {}
for gate, t in estimates.items():
    closes[gate] = min(round(t + GATE_SLACK), 24) if gate != "exit" else 0.0
    print("  %-9s %5.1fs -> %s" % (gate, t, "%ds" % closes[gate] if closes[gate] else "never"))

# Gates.
obj("gate", "GateJump", (2496, ZIG[5] - 48), unlocks="jump", closes_at=float(closes["jump"]))
obj("gate", "GateTeleport", (1664, TP_PLATFORM[2] - 48), unlocks="teleport",
    closes_at=float(closes["teleport"]))
obj("gate", "GateBoost", (3008, ROOM_FLOOR - 48), unlocks="boost", closes_at=float(closes["boost"]))
obj("gate", "GateGrapple", (1440, POCKET_FLOOR - 48), unlocks="grapple",
    closes_at=float(closes["grapple"]))
obj("gate", "Exit", (2432, EXIT_Y), is_exit=True)
obj("airlock_door", "AirlockDoor", (2304, 640), rotation=-1.5708, scale=(1.0, 256 / 192))
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
            rect(x, y - 64, x + 4 * T, y, colors[scene])
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
