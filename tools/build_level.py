#!/usr/bin/env python3
"""Generates scenes/level.tscn (the level blockout) and a PNG preview.

Run from the repo root:  python3 tools/build_level.py [preview.png]

Built on Jay's drawing (corridor, zigzag shaft), extended so that every run
is a race against the 25s self-destruct:
  A  corridor            walk (ramp detour) | jump over / teleport through
  B  zigzag shaft        walk the one-way ramps | jump/double jump/grapple up
     -> JUMP gate
  C1 jump tower          alternating ledges, one jump apart
  C2 reactor gap         platforms over a pit (falling = climb again)
     -> TELEPORT gate
  D  force-field gauntlet  pits behind fields, fields above steps:
                           jump + teleport combos
     -> BOOST gate
  E  vent shaft          ledges one double jump apart, split by a field:
                         jump, teleport across, double jump
     -> GRAPPLE gate
  F  hull breach         grapple chain over the void, teleport through
                         fields mid-flight -> EXIT (airlock)
Each new ability also makes the earlier sections faster; the timing model at
the bottom estimates every run's best time (target: 20-24s of the 25s).

The level is rooms carved out of a solid hull, plus objects. One grid cell =
one 64px tile. Once you edit the level by hand in Godot, stop re-running
this script: it overwrites scenes/level.tscn.
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
JUMP = 900 ** 2 / (2 * GRAVITY)          # 162px
BOOST = 1000 ** 2 / (2 * GRAVITY)        # 200px (double jump)
TELEPORT = 160.0
RANGE = 440.0
PLAYER_H = 60

# ---------------------------------------------------------------- layout numbers
FLOOR = 3200                 # corridor / shaft floor (top of row 50)
LEVEL = 140                  # zigzag and tower step height (one jump)
N_ZIG = 6                    # zigzag levels -> jump gate
N_TOWER = 8                  # tower ledges (even: top ledge is on the right)
SHAFT_X0, SHAFT_X1 = 1600, 2304
ZIG = [FLOOR - LEVEL * k for k in range(1, N_ZIG + 1)]      # L1..L6
TOWER = [ZIG[-1] - LEVEL * i for i in range(1, N_TOWER + 1)]  # T1..T8
Y_TRAV = TOWER[-1]           # traverse platforms height (1240)
N_TRAV = 8                   # traverse platforms
TRAV_X0 = 2432               # end of the tower's top ledge
TRAV_STEP = 384              # 128 platform + 256 gap
D_X0 = TRAV_X0 + 256 + TRAV_STEP * N_TRAV   # gauntlet starts (5760)
D_FLOOR, D_CEIL = 1280, 896
E_X0 = 8128                  # vent shaft (boost gate at its foot)
E_X1 = E_X0 + 640
E_LEDGE = 320                # one double jump
N_BREACH = 12                # grapple points across the breach
BREACH_STEP = 360
F_X0 = E_X1 + 64
F_POINTS_X0 = F_X0 + 148
F_END = math.ceil((F_POINTS_X0 + BREACH_STEP * (N_BREACH - 1) + 192) / T) * T
HALL_FLOOR = 2816            # where you land if you fall off C/D/F
W = math.ceil((F_END + 64) / T) + 1
H = 52

grid = [[" "] * W for _ in range(H)]   # " " outside, "#" solid, "." air


def carve(x0, y0, x1, y1, ch="."):
    """Carve a pixel rectangle (must be on the 64px grid)."""
    assert all(v % T == 0 for v in (x0, y0, x1, y1)), (x0, y0, x1, y1)
    for r in range(y0 // T, y1 // T):
        for c in range(x0 // T, x1 // T):
            grid[r][c] = ch


def solid(x0, y0, x1, y1):
    carve(x0, y0, x1, y1, "#")


carve(0, 0, W * T, H * T, "#")                 # hull
carve(64, FLOOR - 384, SHAFT_X0, FLOOR)        # A corridor
carve(SHAFT_X0, 832, SHAFT_X1, FLOOR)          # B + C1 shaft and tower
carve(SHAFT_X1, 896, SHAFT_X1 + 64, 1280)      # tower top -> traverse
carve(SHAFT_X1, HALL_FLOOR - 128, SHAFT_X1 + 64, HALL_FLOOR)  # hall -> shaft
carve(SHAFT_X1 + 64, 896, D_X0, HALL_FLOOR)    # C2 traverse void + hall
carve(D_X0, D_CEIL, E_X0, D_FLOOR)             # D gauntlet
carve(D_X0, D_FLOOR + 64, F_END, HALL_FLOOR)   # hall under D/E/F
carve(E_X0, 64, E_X1, D_FLOOR)                 # E vent shaft
carve(E_X1, 64, F_X0, 448)                     # E -> F opening
carve(F_X0, 64, F_END, HALL_FLOOR)             # F breach void

# ---------------------------------------------------------------- objects
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


# A: corridor. Walkers go under the ramp and platform, back up the ramp,
# along the platform and over the low field. Jumpers hop the field.
platform("CorridorPlatform", 640, 1152, FLOOR - 96, thick=8)
ramp("CorridorRamp", 832, FLOOR - 96, 1024, FLOOR)
field("CorridorField", 1160, FLOOR - 80, FLOOR)
point("CorridorPoint1", 560, FLOOR - 200)
point("CorridorPoint2", 1240, FLOOR - 220)

# B: zigzag shaft. Every ramp rises right and lands on a full-width platform
# with 128px to spare before the wall; walk left under the next ramp, turn.
RAMP_L, RAMP_R = 1696, 2176
ramp("Ramp0", RAMP_L, FLOOR, RAMP_R, ZIG[0])
for k, y in enumerate(ZIG):
    left = 1504 if k < 2 else SHAFT_X0          # L1/L2 reach into the corridor
    platform("Level%d" % (k + 1), left, SHAFT_X1, y)
    if k + 1 < N_ZIG:
        ramp("Ramp%d" % (k + 1), RAMP_L, y, RAMP_R, ZIG[k + 1])
for i, y in enumerate((2990, 2650, 2310)):
    point("ShaftPoint%d" % (i + 1), 1984, y)

# C1: jump tower, ledges alternating left/right (a 128px gap in the middle).
for i, y in enumerate(TOWER):
    if i % 2 == 0:
        platform("Tower%d" % (i + 1), 1664, 1920, y)
    else:
        right = TRAV_X0 if i == N_TOWER - 1 else 2240
        platform("Tower%d" % (i + 1), 2048, right, y)
for i, y in enumerate((1980, 1640, 1300)):
    point("TowerPoint%d" % (i + 1), 1984, y)

# C2: reactor gap. 128px platforms with 256px gaps (a full jump is ~300px).
for j in range(N_TRAV):
    x = TRAV_X0 + 256 + TRAV_STEP * j
    platform("Gap%d" % (j + 1), x, x + 128, Y_TRAV)

# D: force-field gauntlet (floor 1280, ceiling 896).
def pit(x0, x1):
    carve(x0, D_FLOOR, x1, D_FLOOR + 64)


D1 = D_X0 + 384                  # pit + field on its far edge: teleport over
pit(D1, D1 + 128)
field("GauntletField1", D1 + 128, D_CEIL, D_FLOOR)
D2 = D_X0 + 960                  # step (128) with a field above: jump, then teleport
solid(D2, D_FLOOR - 128, D2 + 64, D_FLOOR)
field("GauntletField2", D2 + 32, D_CEIL, D_FLOOR - 128)
D3 = D_X0 + 1472                 # wide pit with two fields: jump, teleport twice
pit(D3, D3 + 256)
field("GauntletField3a", D3 + 64, D_CEIL, D_FLOOR)
field("GauntletField3b", D3 + 192, D_CEIL, D_FLOOR)
D4 = D_X0 + 1984                 # step + field, then a pit right behind it
solid(D4, D_FLOOR - 128, D4 + 64, D_FLOOR)
field("GauntletField4", D4 + 32, D_CEIL, D_FLOOR - 128)
pit(D4 + 64, D4 + 192)

# E: vent shaft. Ledges one double jump apart, alternating sides; a field
# splits the upper shaft, so crossing sides means teleporting mid-air.
E_MID = E_X0 + 320
e_ledges = [D_FLOOR - E_LEDGE * n for n in (1, 2, 3)]      # 960, 640, 320
platform("Vent1", E_X0 + 384, E_X0 + 576, e_ledges[0])
platform("Vent2", E_X0 + 64, E_X0 + 256, e_ledges[1])
platform("Vent3", E_X0 + 384, F_X0, e_ledges[2])
field("VentField", E_MID, 64, e_ledges[0] - 70)
for i, y in enumerate((1000, 700, 380)):
    point("VentPoint%d" % (i + 1), E_X0 + 480, y)

# F: hull breach. Grapple chain over the void; two fields block the line of
# sight, so teleport through them while flying.
fx = [F_POINTS_X0 + BREACH_STEP * i for i in range(N_BREACH)]
for i, x in enumerate(fx):
    point("BreachPoint%d" % (i + 1), x, 380 if i % 2 == 0 else 460)
for n, i in enumerate((3, 7)):
    field("BreachField%d" % (n + 1), (fx[i] + fx[i + 1]) // 2, 64, 1100)
solid(F_END - 192, 576, F_END, 640)                        # exit ledge

# Gates (closes_at 0 = never seals: the 25s self-destruct is the limit).
obj("gate", "GateJump", (1664, ZIG[-1] - 48), unlocks="jump")
obj("gate", "GateTeleport", (D_X0 + 64, D_FLOOR - 48), unlocks="teleport")
obj("gate", "GateBoost", (E_X0 + 96, D_FLOOR - 48), unlocks="boost")
obj("gate", "GateGrapple", (E_X0 + 448, e_ledges[2] - 48), unlocks="grapple")
obj("gate", "Exit", (F_END - 96, 576 - 48), is_exit=True)
carve(F_END, 384, F_END + 64, 576)                          # airlock opening
obj("airlock_door", "AirlockDoor", (F_END, 384))
obj("starfield", "Starfield", (F_END + 64, 0), area=(0, -1200, 4000, 4400))

SPAWN = (160, FLOOR - 40)

# ---------------------------------------------------------------- checks
checks = [
    ("walker fits under corridor platform", PLAYER_H < 96 - 8),
    ("corridor field blocks a floor walker", 80 > PLAYER_H),
    ("platform walker passes over corridor field", 80 < 96),
    ("zigzag step is one jump", LEVEL <= JUMP - 15),
    ("walker fits between zigzag levels", LEVEL - 12 > PLAYER_H),
    ("traverse gap is one running jump", 256 <= 2 * math.sqrt(2 * JUMP / GRAVITY) * WALK - 30),
    ("D2 step is jumpable", 128 <= JUMP - 20),
    ("vent ledge needs double jump", JUMP < E_LEDGE <= JUMP + BOOST - 30),
    ("grapple chains in range", max(340, 330, 300, 320, math.hypot(BREACH_STEP, 80)) < RANGE),
    ("vent top point lands you on Vent3", 380 - 750 ** 2 / (2 * GRAVITY) + 38 < e_ledges[2]),
]
for label, ok in checks:
    print(("ok   " if ok else "FAIL ") + label)
    assert ok, label

# ---------------------------------------------------------------- timing model
# Rough best-case times (seconds) per section for each ability set. These are
# estimates from the physics numbers, not measurements.
TP_SPEED = 750.0         # running while teleporting on cooldown
RAMP = 340.0             # walking up a ramp


def grapple_chain(dists):
    return sum(d / 1400 + 0.15 for d in dists)


corridor = SHAFT_X0 - SPAWN[0]
detour = (1160 - 1024) * 2 / WALK + (1024 - 832) * 2 / RAMP
zig_walk = (RAMP_L - SHAFT_X0) / WALK + N_ZIG * (RAMP_R - RAMP_L) / RAMP \
    + (N_ZIG - 1) * (RAMP_R - RAMP_L + 64) / WALK + (RAMP_R - 1664) / WALK
trav_len = D_X0 + 64 - TRAV_X0
d_len = E_X0 + 96 - D_X0
sections = {
    #            walk        jump       +teleport   +boost      +grapple
    "A":  [corridor / WALK + detour, corridor / WALK, corridor / TP_SPEED,
           corridor / TP_SPEED, 0.8 + grapple_chain([420, 700])],
    "B":  [zig_walk, N_ZIG * 0.5 + 0.2, N_ZIG * 0.5 + 0.2, N_ZIG / 2 * 0.85,
           0.3 + grapple_chain([420, 340, 340])],
    "C1": [None, N_TOWER * 0.65, N_TOWER * 0.6, N_TOWER / 2 * 0.85,
           grapple_chain([330, 340, 340]) + 0.3],
    "C2": [None, trav_len / TRAV_STEP * 0.96, trav_len / TRAV_STEP * 0.6,
           trav_len / TRAV_STEP * 0.55, trav_len / TRAV_STEP * 0.55],
    "D":  [None, None, d_len / TP_SPEED + 2.0, d_len / TP_SPEED + 1.9,
           d_len / TP_SPEED + 1.9],
    "E":  [None, None, None, 3 * 1.0 + 0.2, grapple_chain([420, 300, 320]) + 0.3],
    "F":  [None, None, None, None, grapple_chain([300] + [BREACH_STEP] * (N_BREACH - 1)) + 2 * 0.35 + 0.4],
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
