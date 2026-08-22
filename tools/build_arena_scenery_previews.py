#!/usr/bin/env python3
"""Build transparent, browser-sized previews for arena-scenery candidates."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


OUTPUT_SIZE = (1280, 800)


def boundary_sky(rgb: Image.Image) -> Image.Image:
    """Return a mask for the bright neutral field connected to an edge."""
    width, height = rgb.size
    pixels = rgb.load()
    candidate = bytearray(width * height)
    outside = bytearray(width * height)
    queue: deque[int] = deque()

    for y in range(height):
        row = y * width
        for x in range(width):
            red, green, blue = pixels[x, y]
            candidate[row + x] = int(
                min(red, green, blue) >= 220
                and max(red, green, blue) - min(red, green, blue) <= 14
            )

    def seed(x: int, y: int) -> None:
        index = y * width + x
        if candidate[index] and not outside[index]:
            outside[index] = 1
            queue.append(index)

    for x in range(width):
        seed(x, 0)
        seed(x, height - 1)
    for y in range(height):
        seed(0, y)
        seed(width - 1, y)
    while queue:
        index = queue.popleft()
        x, y = index % width, index // width
        if x:
            seed(x - 1, y)
        if x + 1 < width:
            seed(x + 1, y)
        if y:
            seed(x, y - 1)
        if y + 1 < height:
            seed(x, y + 1)

    expanded = Image.frombytes(
        "L", (width, height), bytes(255 if value else 0 for value in outside)
    ).filter(ImageFilter.MaxFilter(9))
    return expanded.point(lambda value: 0 if value else 255, mode="L")


def build(source: Path, output: Path) -> None:
    with Image.open(source) as opened:
        rgb = opened.convert("RGB")
    alpha = boundary_sky(rgb)
    rgba = rgb.copy()
    rgba.putalpha(alpha)
    result = (
        rgba.convert("RGBa")
        .resize(OUTPUT_SIZE, Image.Resampling.LANCZOS)
        .convert("RGBA")
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    result.save(output, format="PNG", optimize=False, compress_level=9)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("sources", type=Path, nargs="+")
    args = parser.parse_args()
    for source in args.sources:
        output = args.output_dir / source.name
        build(source.resolve(), output.resolve())
        print(output)


if __name__ == "__main__":
    main()
