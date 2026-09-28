#!/usr/bin/env python3
"""Generates scenes/level.tscn (the blockout level) and a PNG preview.

Run from the repo root:  python3 tools/build_level.py [preview.png]

The level is described below as rooms carved out of a solid hull, plus
objects (lifts, platforms, gates...). One grid cell = one 64px tile.
Once you start painting the level by hand in Godot, stop re-running this
script: it overwrites scenes/level.tscn.

Route (walk-only), bottom-left to top-right:
  spawn -> right up a slope -> lift up (right) -> left -> lift up (left)
  -> right -> lift up (right) -> left -> lift up (left) -> out onto the deck
  -> fall into the teleport pit -> slow lift back up -> fall into the grapple
  chasm -> slow lift up into the gate hall -> gates -> airlock.
Shortcuts:
  jump      ladder of jump-through platforms, spawn -> F2 (skips 2 lifts)
  boost     wide hatches, F2 -> F3 -> F4 (skips 2 lifts)
  teleport  through the force field over the pit (skips the pit + lift)
  grapple   three points across the chasm (skips the chasm + lift)
"""
import base64
import struct
import sys
import zlib

T = 64                      # world pixels per cell
W, H = 78, 46               # grid size in cells
grid = [[" "] * W for _ in range(H)]   # " " outside, "#" solid, "." air


def fill(c0, c1, r0, r1, ch):
    for r in range(r0, r1 + 1):
        for c in range(c0, c1 + 1):
            grid[r][c] = ch


def air(c0, c1, r0, r1):
    fill(c0, c1, r0, r1, ".")


def solid(c0, c1, r0, r1):
    fill(c0, c1, r0, r1, "#")


def y_of(row):              # world y of the top edge of a row
    return row * T


# ---------------------------------------------------------------- hull
solid(0, 76, 17, 44)

# ---------------------------------------------------------------- tower
# Floor surfaces (top of slab row): F0 row 40, F1 36, F2 32, F3 28, F4 24.
air(1, 24, 37, 42)          # spawn area (floor row 43) + F0 corridor
solid(14, 24, 40, 42)       # F0 floor block
solid(10, 11, 42, 42)       # slope supports
solid(12, 13, 41, 42)
air(22, 24, 36, 36)         # RL1 shaft through F1
air(4, 5, 36, 36)           # jump-ladder hatch in F1
air(1, 24, 33, 35)          # between F1 and F2
air(1, 2, 32, 32)           # LL1 shaft through F2
air(4, 5, 32, 32)           # jump-ladder hatch in F2
air(1, 24, 29, 31)          # between F2 and F3
air(22, 24, 28, 28)         # RL2 shaft through F3
air(4, 7, 28, 28)           # boost hatch in F3
air(1, 24, 25, 27)          # between F3 and F4
air(1, 2, 24, 24)           # LL2 shaft through F4
air(4, 7, 24, 24)           # boost hatch in F4

# ---------------------------------------------------------------- deck
air(1, 59, 21, 23)          # deck corridor, floor row 24, ceiling row 20
solid(16, 19, 23, 23)       # hill top (slopes added below)
air(34, 34, 24, 24)         # teleport pit
air(34, 44, 25, 31)         # teleport lower room, floor row 32
air(42, 43, 24, 24)         # T-lift hatch
air(48, 59, 24, 24)         # grapple chasm
air(48, 61, 25, 33)         # grapple lower room, floor row 34
air(60, 61, 24, 24)         # G-lift hatch into the gate hall
air(60, 75, 18, 23)         # gate hall, floor row 24, ceiling row 17
air(76, 76, 21, 23)         # airlock opening (door object fills it)

# ---------------------------------------------------------------- objects
objects = []                # (scene, name, position, {props})


def obj(scene, name, pos, **props):
    objects.append((scene, name, pos, props))


# Slopes: position = bottom-left corner.
obj("slope", "SpawnRamp", (8 * T, y_of(43)), size=(6 * T, 3 * T), rises_right=True)
obj("slope", "HillUp", (14 * T, y_of(24)), size=(2 * T, T), rises_right=True)
obj("slope", "HillDown", (20 * T, y_of(24)), size=(2 * T, T), rises_right=False)

# Jump ladder (cols 4-5): platforms every 72px, 8px thick, so a walker's head
# (60px) just clears the lowest one and a full jump (84.5px) clears each step.
spawn_floor = y_of(43)
for k in range(1, 7):
    obj("one_way", "Ladder%d" % k, (4 * T, spawn_floor - 72 * k), size=(2 * T, 8))
obj("one_way", "HatchF1", (4 * T, y_of(36)), size=(2 * T, 12))
for k in range(1, 4):
    obj("one_way", "Ladder%d" % (6 + k), (4 * T, y_of(36) - 72 * k), size=(2 * T, 8))
obj("one_way", "HatchF2", (4 * T, y_of(32)), size=(2 * T, 12))
# Boost hatches (cols 4-7): 256px apart, jump+boost reaches 284.5px.
obj("one_way", "BoostHatchF3", (4 * T, y_of(28)), size=(4 * T, 12))
obj("one_way", "BoostHatchF4", (4 * T, y_of(24)), size=(4 * T, 12))
# Lift exit hatches.
obj("one_way", "TLiftHatch", (42 * T, y_of(24)), size=(2 * T, 12))
obj("one_way", "GLiftHatch", (60 * T, y_of(24)), size=(2 * T, 12))


def lift(name, c0, c1, top_surface_row, bottom_surface_row, speed):
    top = y_of(top_surface_row) - 16
    obj("grav_lift", name, (c0 * T, top),
        size=((c1 - c0 + 1) * T, y_of(bottom_surface_row) - top), speed=speed)


lift("LiftF0toF1", 22, 24, 36, 40, 160.0)
lift("LiftF1toF2", 1, 2, 32, 36, 160.0)
lift("LiftF2toF3", 22, 24, 28, 32, 160.0)
lift("LiftF3toF4", 1, 2, 24, 28, 160.0)
lift("LiftTeleportRoom", 42, 43, 24, 32, 120.0)
lift("LiftGrappleRoom", 60, 61, 24, 34, 120.0)

# Thin force field just past the teleport pit, ceiling to deck. Walkers drop
# into the pit (nothing above it), jumps/boosts across hit the field and fall,
# and a teleport (160px) from within ~60px of the pit edge lands past it.
obj("force_field", "PitField", (35 * T, y_of(21)), size=(16, 3 * T))

# Grapple points across the chasm, 256px apart (range 320).
for i, col in enumerate((50.5, 54.5, 58.5)):
    obj("grapple_point", "GrapplePoint%d" % (i + 1), (col * T, 21.5 * T))

# Gates on the gate hall floor. closes_at values are placeholder estimates:
# replace them with measured times (see README section in the commit/PR).
gate_y = y_of(24) - 48
obj("gate", "GateJump", (64.5 * T, gate_y), unlocks="jump", closes_at=50.0)
obj("gate", "GateBoost", (66.5 * T, gate_y), unlocks="boost", closes_at=38.0)
obj("gate", "GateTeleport", (68.5 * T, gate_y), unlocks="teleport", closes_at=28.0)
obj("gate", "GateGrapple", (70.5 * T, gate_y), unlocks="grapple", closes_at=22.0)
obj("gate", "Exit", (73.5 * T, gate_y), is_exit=True, closes_at=17.0)

obj("airlock_door", "AirlockDoor", (76 * T, y_of(21)))
obj("starfield", "Starfield", (77 * T, 0))

SPAWN = (2.5 * T, spawn_floor - 40)

# ---------------------------------------------------------------- checks
JUMP = 650 ** 2 / (2 * 2500)            # 84.5
BOOST = 1000 ** 2 / (2 * 2500)          # 200
checks = [
    ("ladder step <= jump - 8", 72 <= JUMP - 8),
    ("ladder top -> F1 hatch", (spawn_floor - 72 * 6) - y_of(36) <= JUMP - 8),
    ("walker clears lowest rung (head 60 < 72-8)", 60 < 72 - 8),
    ("F1 -> F2 too high to jump", y_of(36) - y_of(32) > JUMP),
    ("boost hatch reachable (256 < jump+boost)", 256 < JUMP + BOOST - 16),
    ("boost hatch not reachable by jump", 256 > JUMP),
    ("lift rooms too deep to boost out", y_of(32) - y_of(24) > JUMP + BOOST),
    # teleport from the pit edge (player centre 10px back) clears the field
    ("teleport clears pit field", (34 * T - 10 + 160) - 10 >= 35 * T + 16),
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
    ids = {k: "%d_%s" % (i + 2, k) for i, k in enumerate(EXT)}
    lines = ['[gd_scene load_steps=%d format=3]' % (len(EXT) + 2), '',
             '[ext_resource type="TileSet" path="res://resources/industrial_tileset.tres" id="1_tiles"]']
    for k, p in EXT.items():
        lines.append('[ext_resource type="PackedScene" path="%s" id="%s"]' % (p, ids[k]))
    lines += ['', '[node name="Level" type="Node2D" groups=["level"]]', '',
              '[node name="TileMapLayer" type="TileMapLayer" parent="." groups=["tilemap"]]',
              'scale = Vector2(2, 2)',
              'tile_map_data = PackedByteArray("%s")' % tile_data(),
              'tile_set = ExtResource("1_tiles")', '',
              '[node name="PlayerSpawn" type="Marker2D" parent="." groups=["player_spawn"]]',
              'position = %s' % fmt(SPAWN), '']
    for g in dict.fromkeys(v for v in GROUP_NODE.values() if v):
        lines += ['[node name="%s" type="Node2D" parent="."]' % g, '']
    for scene, name, pos, props in objects:
        parent = GROUP_NODE[scene] or "."
        lines.append('[node name="%s" parent="%s" instance=ExtResource("%s")]' % (name, parent, ids[scene]))
        lines.append("position = %s" % fmt(tuple(float(x) for x in pos)))
        for k, v in props.items():
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
              "one_way": (230, 230, 230), "slope": (200, 170, 120),
              "gate": (60, 230, 120), "airlock_door": (230, 140, 40)}
    for scene, name, (x, y), props in objects:
        sw, sh = props.get("size", (0, 0))
        if scene == "slope":
            for i in range(int(sw)):
                hgt = sh * (i / sw if props["rises_right"] else 1 - i / sw)
                rect(x + i, y - hgt, x + i + 1, y, colors[scene])
        elif scene == "gate":
            col = (255, 210, 60) if props.get("is_exit") else colors[scene]
            rect(x - 24, y - 48, x + 24, y + 48, col)
        elif scene == "grapple_point":
            rect(x - 16, y - 16, x + 16, y + 16, (255, 160, 50))
        elif scene == "airlock_door":
            rect(x, y, x + 64, y + 192, colors[scene])
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
    write_preview(sys.argv[1])
print("wrote scenes/level.tscn")
