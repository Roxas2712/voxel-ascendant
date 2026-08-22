#!/usr/bin/env python3
"""Build the reviewed four-module South Sea V3 landmark atlas.

The retained ImageGen masters are versioned below ``tools/sources``.  The
builder pins every master by exact byte hash, dimensions and mode, then uses
only binary-alpha nearest-neighbour reduction.  Each 128px module keeps an
irregular transparent rock foot: a broad opaque bottom strip is rejected so a
future source change cannot silently restore the old water-ribbon/card look.
"""

from __future__ import annotations

import argparse
import hashlib
import math
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "tools" / "sources" / "coastal_landmarks_v3"
DEFAULT_OUTPUT = (
    ROOT / "assets" / "scenery" / "coastal_landmarks_v3.compact.png"
)
MODULE_WIDTH = 128
ATLAS_HEIGHT = 128
PAINTED_BASELINE = 88
SIDE_MARGIN = 4
TOP_MARGIN = 2
MODULE_COLORS = 48
ALPHA_THRESHOLD = 128
BOTTOM_AUDIT_ROWS = 8

# filename, exact SHA-256, exact ImageGen dimensions, exact mode,
# maximum reviewed world footprint (width, height).  The compact alpha BBox is
# fitted proportionally inside this footprint; runtime maps that exact BBox at
# one atlas texel per world pixel.
SOURCES = (
    (
        "01-rocky-island.imagegen.png",
        "dcc71501b90af37ab2636d246c9208f378ec82e6564e8ad96af6189ef5438615",
        (1774, 887),
        "RGBA",
        (88, 80),
    ),
    (
        "02-lighthouse.imagegen.png",
        "f7b353ab0a14e268ab4263482f819b7403d563981e6fc40d3979b56c1fb39477",
        (1421, 1107),
        "RGBA",
        (80, 80),
    ),
    (
        "03-archipelago.imagegen.png",
        "88c5b522f12cb109b6e79d3397937b85d86374932bfd429cfabf9ac61f02dde1",
        (1942, 809),
        "RGBA",
        (96, 72),
    ),
    (
        "04-cinnabar.imagegen.png",
        "db0f5fb83b84e9974c503b56748c2e01cfeced586a6ab355a6b1959210ffedec",
        (1774, 887),
        "RGBA",
        (72, 72),
    ),
)

# These are deliberately pinned as part of the runtime UV/geometry contract.
# x1/y1 are exclusive Pillow BBox coordinates.
EXPECTED_BOUNDS = (
    (20, 50, 108, 89),  # rocky island: 88x39
    (24, 29, 104, 89),  # lighthouse: 80x60
    (16, 56, 112, 89),  # archipelago: 96x33
    (28, 60, 100, 89),  # Cinnabar: 72x29
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def binary_alpha(alpha: Image.Image) -> Image.Image:
    return alpha.point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0)


def visible_palette(rgb: Image.Image, alpha: Image.Image) -> Image.Image:
    """Quantize against visible pixels only, never transparent RGB garbage."""
    pixels = [
        color for color, opacity in zip(rgb.getdata(), alpha.getdata())
        if opacity == 255
    ]
    if not pixels:
        raise ValueError("cannot build a palette from empty alpha")
    sample = Image.new("RGB", (len(pixels), 1))
    sample.putdata(pixels)
    palette = sample.quantize(
        colors=MODULE_COLORS,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    return rgb.quantize(palette=palette, dither=Image.Dither.NONE).convert("RGB")


def compact_module(
    path: Path,
    expected_size: tuple[int, int],
    expected_mode: str,
    target_limit: tuple[int, int],
) -> Image.Image:
    with Image.open(path) as source:
        if source.size != expected_size or source.mode != expected_mode:
            raise ValueError(
                f"{path}: expected exact {expected_size} {expected_mode} "
                f"ImageGen master, got {source.size} {source.mode}"
            )
        rgba = source.copy()

    mask = binary_alpha(rgba.getchannel("A"))
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError(f"{path}: source alpha is empty")
    crop = rgba.crop(bounds)
    crop_mask = mask.crop(bounds)

    source_w, source_h = crop.size
    available_w = min(MODULE_WIDTH - SIDE_MARGIN * 2, target_limit[0])
    available_h = min(PAINTED_BASELINE - TOP_MARGIN + 1, target_limit[1])
    scale = min(available_w / source_w, available_h / source_h)
    width = max(1, min(available_w, math.floor(source_w * scale + 0.5)))
    height = max(1, min(available_h, math.floor(source_h * scale + 0.5)))

    rgb = crop.convert("RGB").resize(
        (width, height), resample=Image.Resampling.NEAREST
    )
    reduced_alpha = crop_mask.resize(
        (width, height), resample=Image.Resampling.NEAREST
    )
    reduced_alpha = binary_alpha(reduced_alpha)
    reduced = visible_palette(rgb, reduced_alpha)
    module_art = reduced.convert("RGBA")
    module_art.putalpha(reduced_alpha)

    module = Image.new("RGBA", (MODULE_WIDTH, ATLAS_HEIGHT), (0, 0, 0, 0))
    x = (MODULE_WIDTH - width) // 2
    y = PAINTED_BASELINE - height + 1
    module.paste(module_art, (x, y))
    return module


def build() -> Image.Image:
    modules: list[Image.Image] = []
    for (filename, expected_hash, expected_size, expected_mode,
         target_limit) in SOURCES:
        path = SOURCE_DIR / filename
        if not path.is_file():
            raise FileNotFoundError(f"missing retained source: {path}")
        actual_hash = sha256(path)
        if actual_hash != expected_hash:
            raise ValueError(f"{path}: source SHA-256 drifted: {actual_hash}")
        modules.append(compact_module(
            path, expected_size, expected_mode, target_limit
        ))

    atlas = Image.new(
        "RGBA", (MODULE_WIDTH * len(modules), ATLAS_HEIGHT), (0, 0, 0, 0)
    )
    for index, module in enumerate(modules):
        atlas.paste(module, (index * MODULE_WIDTH, 0))
    return atlas


def opaque_runs(alpha: Image.Image, y: int) -> list[int]:
    runs: list[int] = []
    length = 0
    for x in range(alpha.width):
        if alpha.getpixel((x, y)) == 255:
            length += 1
        elif length:
            runs.append(length)
            length = 0
    if length:
        runs.append(length)
    return runs


def save(image: Image.Image, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output, format="PNG", optimize=False, compress_level=9)


def verify_contract(image: Image.Image) -> None:
    if image.size != (512, 128) or image.mode != "RGBA":
        raise ValueError("generated atlas is not 512x128 RGBA")
    for index in range(4):
        module = image.crop(
            (index * MODULE_WIDTH, 0, (index + 1) * MODULE_WIDTH, ATLAS_HEIGHT)
        )
        alpha = module.getchannel("A")
        if set(alpha.getdata()) - {0, 255}:
            raise ValueError(f"module {index}: alpha is not binary")
        bounds = alpha.getbbox()
        if bounds is None or bounds[3] - 1 != PAINTED_BASELINE:
            raise ValueError(f"module {index}: painted baseline drifted")
        if bounds != EXPECTED_BOUNDS[index]:
            raise ValueError(
                f"module {index}: alpha BBox drifted: {bounds}"
            )
        if bounds[0] < SIDE_MARGIN or bounds[2] > MODULE_WIDTH - SIDE_MARGIN:
            raise ValueError(f"module {index}: subject touches a module side")
        if bounds[1] < TOP_MARGIN:
            raise ValueError(f"module {index}: subject touches the module top")
        visible = {
            pixel[:3] for pixel in module.getdata() if pixel[3] == 255
        }
        if len(visible) > MODULE_COLORS:
            raise ValueError(
                f"module {index}: {len(visible)} colors exceed {MODULE_COLORS}"
            )

        # The old sprites ended in a shared foam/water card.  Reject any
        # future bottom row that approaches a full-width slab, whether that
        # slab is one continuous run or several nearly touching fragments.
        subject_width = bounds[2] - bounds[0]
        for y in range(PAINTED_BASELINE - BOTTOM_AUDIT_ROWS + 1,
                       PAINTED_BASELINE + 1):
            runs = opaque_runs(alpha, y)
            coverage = sum(runs)
            longest = max(runs, default=0)
            if (coverage >= math.ceil(subject_width * 0.90)
                    or longest >= math.ceil(subject_width * 0.85)):
                raise ValueError(
                    f"module {index}: row {y} restored a broad opaque base "
                    f"({coverage}px total, {longest}px continuous)"
                )
        if any(sum(opaque_runs(alpha, y)) == MODULE_WIDTH
               for y in range(ATLAS_HEIGHT)):
            raise ValueError(f"module {index}: contains a full-width alpha row")
        baseline_runs = opaque_runs(alpha, PAINTED_BASELINE)
        if sum(baseline_runs) > 16:
            raise ValueError(
                f"module {index}: baseline is no longer an irregular rock foot"
            )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("-o", "--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify that OUTPUT is pixel-identical instead of rewriting it",
    )
    args = parser.parse_args()

    generated = build()
    verify_contract(generated)
    output = args.output.resolve()
    if args.check:
        if not output.is_file():
            raise SystemExit(f"missing generated atlas: {output}")
        with Image.open(output) as existing_source:
            existing = existing_source.convert("RGBA")
        if existing.size != generated.size or existing.tobytes() != generated.tobytes():
            raise SystemExit(f"generated atlas drifted: {output}")
    else:
        save(generated, output)

    print(f"{sha256(output)}  {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
