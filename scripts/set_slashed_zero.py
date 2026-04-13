#!/usr/bin/env fontforge

import os
import sys

import fontforge

DEFAULT_ZERO_GLYPH = "zero"
SLASHED_ZERO_GLYPH = "zero.zero"


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: set_slashed_zero.py INPUT_FONT OUTPUT_FONT")

    input_font, output_font = sys.argv[1], sys.argv[2]
    font = fontforge.open(input_font)

    if DEFAULT_ZERO_GLYPH not in font:
        raise SystemExit("missing glyph: %s" % DEFAULT_ZERO_GLYPH)
    if SLASHED_ZERO_GLYPH not in font:
        raise SystemExit("missing glyph: %s" % SLASHED_ZERO_GLYPH)

    font.selection.none()
    font.selection.select(SLASHED_ZERO_GLYPH)
    font.copy()
    font.selection.none()
    font.selection.select(DEFAULT_ZERO_GLYPH)
    font.paste()

    os.makedirs(os.path.dirname(output_font), exist_ok=True)
    font.generate(output_font)


if __name__ == "__main__":
    main()
