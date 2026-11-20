"""Build one upright Liga Paper Mono OTF from the pinned Paper Mono release."""

import json
import subprocess
import sys
from collections import defaultdict
from math import ceil, floor
from pathlib import Path
from tempfile import TemporaryDirectory

import fontforge
import ligaturize
from char_dict import char_dict
from fontTools import subset
from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib import TTFont
from ligatures import ligatures

EXCLUDED = {"&&", "~@", "\\/", ".?", "?:", "?=", "?.", "??", ";;", "/\\"}


def prepare_terminal_base(font):
    features = {
        record.FeatureTag
        for tag in ("GSUB", "GPOS")
        for record in font[tag].table.FeatureList.FeatureRecord
    }
    # aalt also references the discarded glyphs. Prune those references along
    # with the features, keeping names for features that survive the subset.
    options = subset.Options(
        layout_features=features - {"ss01", "ss02", "ss03"},
        layout_closure=False,
        notdef_outline=True,
        name_IDs=list(range(256)),
        name_languages=["*"],
        name_legacy=True,
        passthrough_tables=True,
    )
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(
        glyphs=[
            name
            for name in font.getGlyphOrder()
            if name != "SPC" and not name.endswith((".liga", ".ss02", ".ss03"))
        ]
    )
    subsetter.subset(font)


def add_ligatures(font):
    donor_file = ligaturize.get_ligature_source(font.fontname)
    donor_path = Path(ligaturize.__file__).parent / donor_file
    donor = fontforge.open(str(donor_path))
    creator = ligaturize.LigatureCreator(
        font, donor, scale_character_glyphs_threshold=0.1, copy_character_glyphs=False
    )
    supported = []
    for spec in sorted(ligatures, key=lambda spec: len(spec["chars"])):
        name = spec["firacode_ligature_name"]
        if name is None or name not in donor:
            continue
        chars = spec["chars"]
        text = "".join(char_dict[g] for g in chars)
        if text not in EXCLUDED:
            creator.add_ligature(chars, name)
            supported.append(text)
    donor.close()

    # Ligaturizer predates some of Paper Mono's Latin language systems.
    scripts = defaultdict(set)
    for lookup in font.gsub_lookups:
        for _, registrations in font.getLookupInfo(lookup)[2]:
            for script, languages in registrations:
                scripts[script].update(languages)
    registrations = tuple(
        (script, tuple(sorted(languages))) for script, languages in sorted(scripts.items())
    )
    for lookup in font.gsub_lookups:
        if lookup.startswith("calt."):
            font.lookupSetFeatureList(lookup, (("calt", registrations),))
    return supported


def fit_wide_symbols(font):
    width = font["space"].width
    if width <= 0:
        raise ValueError("invalid space width")
    for glyph in font.glyphs():
        if glyph.width in (0, width):
            continue
        if glyph.width < width:
            raise ValueError(f"unexpected narrow glyph: {glyph.glyphname}")
        # The caps lock symbol's ink extends beyond even its original advance.
        left, bottom, right, top = glyph.boundingBox()
        left = min(0, floor(left))
        right = max(glyph.width, ceil(right))
        scale = width / (right - left)
        y_offset = (1 - scale) * (bottom + top) / 2
        glyph.transform((scale, 0, 0, scale, -left * scale, y_offset))
        glyph.width = width
    return width


def finalize(base, built, result):
    # FontForge drops the language metadata and cv01's menu labels on export.
    for tag in ("meta", "gasp", "prep", "name"):
        built[tag] = base[tag]
    params = {
        r.FeatureTag: r.Feature.FeatureParams
        for r in base["GSUB"].table.FeatureList.FeatureRecord
    }
    for record in built["GSUB"].table.FeatureList.FeatureRecord:
        record.Feature.FeatureParams = params.get(record.FeatureTag)

    for record in built["name"].names:
        if record.nameID in (1, 3, 4, 6, 16):
            value = record.toUnicode().replace("Paper Mono", "Liga Paper Mono")
            record.string = value.replace("PaperMono-", "LigaPaperMono-")
        elif record.nameID == 0:
            record.string = record.toUnicode() + ligaturize.COPYRIGHT

    top = built["CFF "].cff.topDictIndex[0]
    top.Notice = built["name"].getDebugName(0)
    top.CharStrings["zero"] = top.CharStrings["zero.zero"]
    built["hmtx"]["zero"] = built["hmtx"]["zero.zero"]
    built.save(result)


def check_font(path, base, cmap, width):
    with TTFont(path) as font:
        top = font["CFF "].cff.topDictIndex[0]
        metrics = font["hmtx"].metrics
        advances = {w for w, _ in metrics.values()}
        if advances != {0, width} or not (font["post"].isFixedPitch and top.isFixedPitch):
            raise ValueError("OTF is not fixed pitch")
        if font.getBestCmap() != cmap:
            raise ValueError("Unicode coverage changed")
        if top.CharStrings[cmap[0x30]].bytecode != top.CharStrings["zero.zero"].bytecode:
            raise ValueError("default zero differs from the slashed alternate")
        features = {r.FeatureTag for r in font["GSUB"].table.FeatureList.FeatureRecord}
        if "calt" not in features or features & {"ss01", "ss02", "ss03"}:
            raise ValueError("unexpected coding or width-changing features")
        glyphs = font.getGlyphSet()
        for name, (advance, _) in base["hmtx"].metrics.items():
            if (advance == 0) != (metrics[name][0] == 0):
                raise ValueError(f"zero-width status changed for {name}")
            if advance > width:
                pen = BoundsPen(glyphs)
                glyphs[name].draw(pen)
                if pen.bounds and (pen.bounds[0] < 0 or pen.bounds[2] > width):
                    raise ValueError(f"{name} extends past its cell")


def check_shaping(path, cmap, supported, width):
    if not {"->", "=>", "==="}.issubset(supported):
        raise ValueError("Fira Code is missing expected coding ligatures")
    tokens = supported + sorted(EXCLUDED)
    samples = "\n".join(tokens) + "\n"

    def shape(*options):
        output = subprocess.check_output(
            ["hb-shape", "--output-format=json", *options, path], input=samples, text=True
        )
        return [json.loads(line) for line in output.splitlines()]

    default = shape()
    if shape("--script=latn", "--language=tr") != default:
        raise ValueError("coding ligatures differ in the Turkish language system")
    disabled = shape("--features=-calt,ss01")
    for token, shaped, plain in zip(tokens, default, disabled, strict=True):
        nominal = [cmap[ord(c)] for c in token]
        if [g["g"] for g in plain] != nominal:
            raise ValueError(f"{token!r} substitutes with calt disabled")
        substituted = [g["g"] for g in shaped] != nominal
        if substituted != (token not in EXCLUDED):
            raise ValueError(f"unexpected default shaping for {token!r}")
        if [g["ax"] for g in shaped] != [width] * len(token):
            raise ValueError(f"{token!r} does not preserve its terminal cells")


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: build_font.py INPUT.otf OUTPUT.otf")
    source, destination = map(Path, sys.argv[1:])
    with (
        TTFont(source, recalcTimestamp=False) as base,
        TemporaryDirectory(dir=destination.parent) as directory,
    ):
        work_dir = Path(directory)
        cmap = base.getBestCmap().copy()
        prepare_terminal_base(base)
        terminal = work_dir / source.name
        base.save(terminal)
        font = fontforge.open(str(terminal))
        supported = add_ligatures(font)
        ligaturize.update_font_metadata(font, "Liga Paper Mono")
        width = fit_wide_symbols(font)
        intermediate = work_dir / "ligaturized.otf"
        font.generate(str(intermediate))
        font.close()

        result = work_dir / destination.name
        with TTFont(intermediate, recalcTimestamp=False) as built:
            finalize(base, built, result)
        check_font(result, base, cmap, width)
        check_shaping(result, cmap, supported, width)
        result.replace(destination)


if __name__ == "__main__":
    main()
