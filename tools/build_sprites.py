#!/usr/bin/env python3
"""Generates the player sprite sheet: assets/images/player/astronaut.png.

Run from the repo root:  python3 tools/build_sprites.py

A 16x16-texel astronaut (drawn at 4x in game), facing right. Frames, left to
right: idle0, idle1, run0-run3, rise, fall. Edit the pixel art below: each
letter is a colour from PALETTE, "." is transparent.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from build_tileset import write_png  # noqa: E402

PALETTE = {
    "k": (40, 44, 70),       # outline
    "w": (255, 241, 232),    # suit
    "g": (170, 172, 190),    # suit shade
    "v": (41, 173, 255),     # visor
    "V": (230, 250, 255),    # visor glint
    "b": (255, 163, 0),      # backpack
}

HEAD = [
    "................",
    ".....kkkkkk.....",
    "....kwwwwwwk....",
    "...kwwwvvvvwk...",
    "...kwwvVvvvvk...",
    "...kwwvvvvvvk...",
    "....kwwwwwwk....",
]
HEAD_BLINK = HEAD[:4] + ["...kwwvvvVvvk...", "...kwwvvvvvvk..."] + HEAD[6:]
BODY = [
    "..kbkwwwwwwwk...",
    "..kbkwwgwwwwk...",
    "..kbkwwgwwwwk...",
    "...kkwwwwwwwk...",
]
LEGS = {
    "stand": ["....kwwk.kwwk...", "....kwwk.kwwk...", "....kggk.kggk...", "....kkkk.kkkk..."],
    "stride": ["...kwwk..kwwk...", "..kwwk....kwwk..", "..kggk....kggk..", "..kkkk....kkkk.."],
    "pass": ["....kwwwwwwk....", ".....kwwwwk.....", ".....kggggk.....", ".....kkkkkk....."],
    "stride2": ["....kwwk.kwwk...", "...kwwk...kwwk..", "...kggk...kggk..", "...kkkk...kkkk.."],
    "tuck": ["....kwwwwwwk....", "....kggggggk....", "....kkkkkkkk....", "................"],
    "spread": ["...kwwk..kwwk...", "..kwwk....kwwk..", "..kggk....kggk..", "..kkk......kkk.."],
}
BLANK = ["................"]


def frame(head, legs):
    rows = head + BODY + LEGS[legs] + BLANK
    assert len(rows) == 16 and all(len(r) == 16 for r in rows), rows
    return rows


FRAMES = [
    frame(HEAD, "stand"), frame(HEAD_BLINK, "stand"),
    frame(HEAD, "stride"), frame(HEAD, "pass"), frame(HEAD, "stride2"), frame(HEAD, "pass"),
    frame(HEAD, "tuck"), frame(HEAD, "spread"),
]


def main():
    size = 16
    sheet = [[(0, 0, 0, 0)] * (size * len(FRAMES)) for _ in range(size)]
    for f, rows in enumerate(FRAMES):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch != ".":
                    sheet[y][f * size + x] = PALETTE[ch] + (255,)
    write_png("assets/images/player/astronaut.png", sheet, alpha=True)
    print("wrote astronaut.png (%d frames)" % len(FRAMES))


if __name__ == "__main__":
    main()
