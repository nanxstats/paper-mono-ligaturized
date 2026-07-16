#!/usr/bin/env fontforge

import os
import sys

import fontforge
import psMat

DEFAULT_ZERO_GLYPH = "zero"
SLASHED_ZERO_GLYPH = "zero.zero"
SPACE_GLYPH = "space"


def normalize_encoded_glyph_widths(font):
    if SPACE_GLYPH not in font:
        raise SystemExit("missing glyph: %s" % SPACE_GLYPH)

    cell_width = font[SPACE_GLYPH].width
    if cell_width <= 0:
        raise SystemExit("invalid monospace cell width: %s" % cell_width)

    for glyph in font.glyphs():
        if glyph.unicode < 0 or glyph.width in (0, cell_width):
            continue

        glyph.transform(psMat.scale(float(cell_width) / glyph.width, 1.0))
        glyph.width = cell_width

    inconsistent = [
        glyph.glyphname
        for glyph in font.glyphs()
        if glyph.unicode >= 0 and glyph.width not in (0, cell_width)
    ]
    if inconsistent:
        raise SystemExit(
            "encoded glyphs have inconsistent widths: %s" % ", ".join(inconsistent)
        )


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

    normalize_encoded_glyph_widths(font)

    os.makedirs(os.path.dirname(output_font), exist_ok=True)
    font.generate(output_font)


if __name__ == "__main__":
    main()
