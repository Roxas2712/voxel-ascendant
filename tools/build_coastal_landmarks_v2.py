#!/usr/bin/env python3
"""Build the compact four-module South Sea landmark atlas.

The retained ImageGen masters live below ``tools/sources`` so a fresh checkout
can reproduce the runtime bitmap without depending on a user's Codex cache.
Every resize is nearest-neighbour, every module owns its palette, and alpha is
binary.  The last painted pixel of all four modules is row 88.
"""

from __future__ import annotations

import argparse
import hashlib
import math
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "tools" / "sources" / "coastal_landmarks_v2"
DEFAULT_OUTPUT = (
    ROOT / "assets" / "scenery" / "coastal_landmarks_v2.compact.png"
)
MODULE_WIDTH = 128
ATLAS_HEIGHT = 128
PAINTED_BASELINE = 88
MODULE_COLORS = 48
ALPHA_THRESHOLD = 128

SOURCES = (
    (
        "01-rocky-island.imagegen.png",
        "dbed1fda229fba5b79cc13321b7aea73e61aab31e3cc6b8a0e2f31f4acd5dd2b",
    ),
    (
        "02-lighthouse.imagegen.png",
        "333aa4d226cde7dd2243b7d7d5b4ab832b31d0aa1ab2ad3cded774c75a7ba5ca",
    ),
    (
        "03-archipelago.imagegen.png",
        "5e25cc63becddcfe741f9d7689032727f061ecf57fa11f095535a4f85ccf804e",
    ),
    (
        "04-cinnabar.imagegen.png",
        "9b5fe7fd3f2dfd15449da055619cb6277fc76fc7cbf8979c6551dc8fbdbeed38",
    ),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def binary_alpha(alpha: Image.Image) -> Image.Image:
    return alpha.point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0)


def compact_module(path: Path) -> Image.Image:
    with Image.open(path) as source:
        if source.size != (1254, 1254) or source.mode != "RGBA":
            raise ValueError(
                f"{path}: expected exact 1254x1254 RGBA ImageGen master, "
                f"got {source.size} {source.mode}"
            )
        rgba = source.copy()

    mask = binary_alpha(rgba.getchannel("A"))
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError(f"{path}: source alpha is empty")
    crop = rgba.crop(bounds)
    crop_mask = mask.crop(bounds)

    source_w, source_h = crop.size
    available_h = PAINTED_BASELINE + 1
    scale = min(MODULE_WIDTH / source_w, available_h / source_h)
    width = max(1, min(MODULE_WIDTH, math.floor(source_w * scale + 0.5)))
    height = max(1, min(available_h, math.floor(source_h * scale + 0.5)))

    rgb = crop.convert("RGB").resize(
        (width, height), resample=Image.Resampling.NEAREST
    )
    reduced = rgb.quantize(
        colors=MODULE_COLORS,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    reduced_alpha = crop_mask.resize(
        (width, height), resample=Image.Resampling.NEAREST
    )
    reduced_alpha = binary_alpha(reduced_alpha)
    module_art = reduced.convert("RGBA")
    module_art.putalpha(reduced_alpha)

    module = Image.new("RGBA", (MODULE_WIDTH, ATLAS_HEIGHT), (0, 0, 0, 0))
    x = (MODULE_WIDTH - width) // 2
    y = PAINTED_BASELINE - height + 1
    module.paste(module_art, (x, y))
    return module


def build() -> Image.Image:
    modules: list[Image.Image] = []
    for filename, expected_hash in SOURCES:
        path = SOURCE_DIR / filename
        if not path.is_file():
            raise FileNotFoundError(f"missing retained source: {path}")
        actual_hash = sha256(path)
        if actual_hash != expected_hash:
            raise ValueError(
                f"{path}: source SHA-256 drifted: {actual_hash}"
            )
        modules.append(compact_module(path))

    atlas = Image.new(
        "RGBA", (MODULE_WIDTH * len(modules), ATLAS_HEIGHT), (0, 0, 0, 0)
    )
    for index, module in enumerate(modules):
        atlas.paste(module, (index * MODULE_WIDTH, 0))
    return atlas


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
        visible = {
            pixel[:3]
            for pixel in module.getdata()
            if pixel[3] == 255
        }
        if len(visible) > MODULE_COLORS:
            raise ValueError(
                f"module {index}: {len(visible)} colors exceed {MODULE_COLORS}"
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

    # Hash the exact shipped bytes.  In check mode the existing reviewed file
    # is authoritative; otherwise it is the file just written above.
    print(f"{sha256(output)}  {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
