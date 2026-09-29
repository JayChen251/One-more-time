#!/usr/bin/env python3
"""Generates the player sprite sheet: assets/images/player/astronaut.png.

Run from the repo root:  python3 tools/build_sprites.py

A 32x32-texel astronaut (drawn at 2x in game, the same pixel size as the
tiles), facing right, in the Industrial tileset's palette. Frames, left to
right: idle0, idle1, run0-run3, rise, fall. Each frame is built from a
helmet, a torso and a pair of legs; edit the pixel art below: each letter is a
colour from PALETTE, "." is transparent.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from build_tileset import write_png  # noqa: E402

SIZE = 32
PALETTE = {
    "k": (12, 10, 18),       # outline
    "W": (246, 248, 250),    # suit highlight
    "w": (215, 226, 230),    # suit
    "l": (182, 200, 204),    # suit shade
    "g": (116, 123, 139),    # deep shade
    "d": (75, 72, 91),       # boots
    "v": (20, 49, 74),       # visor
    "c": (39, 91, 137),      # visor mid
    "C": (87, 150, 206),     # visor light
    "V": (213, 235, 255),    # visor glint
    "o": (249, 110, 32),     # backpack
    "O": (170, 60, 20),      # backpack shade
    "y": (249, 198, 32),     # backpack light / suit stripe
}

HELMET = [          # 16 wide, placed at x=9
    ".....kkkkkk.....",
    "...kkWWwwwwkk...",
    "..kWWwwwwwwwwk..",
    ".kWwwwwwkkkkkkk.",
    ".kWwwwwkcCVVCCck",
    "kwwwwwkvcCVCCcck",
    "kwwwwwkvvcCCcvck",
    "kwlwwwkvvvccvvck",
    "klwwwwkvvvvvvvck",
    "kllwwwwkkkkkkkk.",
    ".kllwwwwwwwwwlk.",
    "..kglllllllllk..",
    "...kkkkkkkkkkk..",
]
HELMET_BLINK = HELMET[:4] + [".kWwwwwkcCCVVCck", "kwwwwwkvcCCVCcck"] + HELMET[6:]
TORSO = [           # placed at x=6, under the helmet
    ".kkkkkkkWwwwwwwk...",
    "kyoookkwwwwwwwwwk..",
    "koooOkwwwwwwwwwwk..",
    "koooOkwwlwwwkkwwk..",
    "koooOkwwlwwkwwwwk..",
    "kOOOOkwwlwwkwwwlk..",
    ".kkkkkyyyywwklllk..",
    ".....kglllllggggk..",
    ".....kkggggggggk...",
]
LEGS = {            # placed at x=9
    "stand": [
        "..kwwwk.kwwwk...",
        "..kwwwk.kwwwk...",
        "..kwllk.kwllk...",
        "..kwllk.kwllk...",
        ".kdddddkdddddk..",
        ".kgddddkgddddk..",
        ".kkkkkkkkkkkkk..",
    ],
    "stride": [
        ".kwwwk...kwwwk..",
        ".kwwlk....kwwwk.",
        "kwwlk.....kwllk.",
        "kwllk......kwlk.",
        "kddddk....kdddddk",
        "kgdddk....kgddddk",
        "kkkkkk....kkkkkkk",
    ],
    "pass": [
        "...kwwwwwwk.....",
        "...kwwwwllk.....",
        "....kwwllk......",
        "....kwllk.......",
        "...kddddddk.....",
        "...kgdddddk.....",
        "...kkkkkkkk.....",
    ],
    "stride2": [
        "..kwwwk..kwwwk..",
        "..kwwlk...kwwwk.",
        ".kwwlk....kwllk.",
        ".kwllk.....kwlk.",
        ".kddddk...kddddk",
        ".kgdddk...kgdddk",
        ".kkkkkk...kkkkkk",
    ],
    "tuck": [
        "..kwwwwwwwwk....",
        "..kwwlllwwwwk...",
        "..kdddddkddddk..",
        "..kgddddkgdddk..",
        "..kkkkkkkkkkkk..",
        "................",
        "................",
    ],
    "spread": [
        ".kwwwk...kwwwk..",
        "kwwlk.....kwwwk.",
        "kwlk.......kwlk.",
        "kddk.......kddk.",
        "kddddk....kddddk",
        "kkkkkk....kkkkkk",
        "................",
    ],
}
# Feet end on this row (the sprite's centre is row 16); keep player.gd's
# SPRITE_FEET_ROWS in sync.
FEET_ROW = 30


def frame(helmet, legs, bob=0):
    px = [[None] * SIZE for _ in range(SIZE)]

    def paint(rows, x0, y0):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch != ".":
                    px[y0 + y][x0 + x] = PALETTE[ch]

    top = FEET_ROW - 7 - 9 - 13 + 1 + bob
    paint(LEGS[legs], 9, FEET_ROW - 6)
    paint(TORSO, 6, top + 13)
    paint(helmet, 9, top)
    return px


FRAMES = [
    frame(HELMET, "stand"), frame(HELMET_BLINK, "stand"),
    frame(HELMET, "stride"), frame(HELMET, "pass", 1), frame(HELMET, "stride2"), frame(HELMET, "pass", 1),
    frame(HELMET, "tuck", -1), frame(HELMET, "spread"),
]


def main():
    sheet = [[(0, 0, 0, 0)] * (SIZE * len(FRAMES)) for _ in range(SIZE)]
    for f, px in enumerate(FRAMES):
        for y in range(SIZE):
            for x in range(SIZE):
                if px[y][x]:
                    sheet[y][f * SIZE + x] = px[y][x] + (255,)
    write_png("assets/images/player/astronaut.png", sheet, alpha=True)
    print("wrote astronaut.png (%d frames)" % len(FRAMES))


if __name__ == "__main__":
    main()
