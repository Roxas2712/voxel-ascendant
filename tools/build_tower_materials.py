#!/usr/bin/env python3
"""Build the reviewed Pokemon Tower wall and ceiling compact textures.

The creative source remains the project-bound ImageGen masters documented in
ASSET_SOURCES.md.  This script performs only deterministic crop, nearest-
neighbour reduction, shared-palette quantisation, and exact repeat-edge repair.
It deliberately adds no blur, antialiasing, dithering, or procedural painting.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image


WALL_SIZE = (512, 160)
WALL_SEGMENT_SIZE = (256, 160)
CEILING_SIZE = (256, 256)
COLORS = 24


def parse_span(value: str) -> tuple[int, int]:
    try:
        left, right = (int(part) for part in value.split(":", 1))
    except (TypeError, ValueError) as exc:
        raise argparse.ArgumentTypeError("span must be LEFT:RIGHT") from exc
    if left < 0 or right <= left:
        raise argparse.ArgumentTypeError("span must satisfy 0 <= LEFT < RIGHT")
    return left, right


def opaque_rgb(path: Path) -> Image.Image:
    with Image.open(path) as source:
        return source.convert("RGB")


def quantize(image: Image.Image) -> Image.Image:
    return image.quantize(
        colors=COLORS,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")


def wall_segment(path: Path, span: tuple[int, int]) -> Image.Image:
    source = opaque_rgb(path)
    left, right = span
    if right > source.width:
        raise ValueError(f"{path}: crop {span} exceeds width {source.width}")
    crop = source.crop((left, 0, right, source.height))
    return crop.resize(WALL_SEGMENT_SIZE, Image.Resampling.NEAREST)


def repair_wall_joins(image: Image.Image) -> None:
    # Each source crop ends on the centre of a full-height timber post.  One
    # identical boundary column turns the two half-posts into an intentional
    # joint and makes the 512px wrap mathematically exact.
    image.paste(image.crop((255, 0, 256, image.height)), (256, 0))
    image.paste(image.crop((0, 0, 1, image.height)), (511, 0))


def repair_ceiling_wrap(image: Image.Image) -> None:
    image.paste(image.crop((0, 0, 1, image.height)), (image.width - 1, 0))
    image.paste(image.crop((0, 0, image.width, 1)), (0, image.height - 1))


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def describe(path: Path) -> str:
    with Image.open(path) as source:
        image = source.convert("RGBA")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    colors = len(image.getcolors(maxcolors=1 << 20) or [])
    return f"{path}: {image.width}x{image.height}, {colors} colors, {digest}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--wall-a", type=Path, required=True)
    parser.add_argument("--wall-b", type=Path, required=True)
    parser.add_argument("--ceiling", type=Path, required=True)
    parser.add_argument("--wall-a-span", type=parse_span, default=(109, 1664))
    parser.add_argument("--wall-b-span", type=parse_span, default=(107, 1486))
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    wall = Image.new("RGB", WALL_SIZE)
    wall.paste(wall_segment(args.wall_a, args.wall_a_span), (0, 0))
    wall.paste(wall_segment(args.wall_b, args.wall_b_span), (256, 0))
    wall = quantize(wall)
    repair_wall_joins(wall)

    ceiling = opaque_rgb(args.ceiling).resize(
        CEILING_SIZE, Image.Resampling.NEAREST
    )
    ceiling = quantize(ceiling)
    repair_ceiling_wrap(ceiling)

    wall_path = args.output_dir / "pokemon_tower_wall.compact.png"
    ceiling_path = args.output_dir / "pokemon_tower_ceiling.compact.png"
    save(wall, wall_path)
    save(ceiling, ceiling_path)
    print(describe(wall_path))
    print(describe(ceiling_path))


if __name__ == "__main__":
    main()
