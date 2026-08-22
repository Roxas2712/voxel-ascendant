#!/usr/bin/env python3
"""Build the selected painterly arena-scenery backgrounds.

Built-in ImageGen previews may contain a baked neutral checker even when the
prompt requests alpha.  This builder removes only the boundary-connected,
high-luminance neutral field, then resamples in premultiplied-alpha space so
the live sky never inherits a pale checker halo.
"""

from __future__ import annotations

import argparse
from collections import deque
import hashlib
from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (
    ROOT / "tools/sources/arena_scenery/nugget_bridge_anchors_v2.imagegen.png"
)
OUTPUT = ROOT / "assets/battle/nugget_bridge_a.compact.png"
SOURCE_SHA256 = "101f1e7f86205a31d70d3acd98d7a994d017131272c1d9dcca54fa323ad910a5"
SOURCE_SIZE = (1548, 1016)
OUTPUT_SIZE = (1280, 800)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checker_sky(rgb: Image.Image) -> bytearray:
    """Return only neutral bright pixels connected to an image boundary."""
    width, height = rgb.size
    source = rgb.load()
    total = width * height
    candidate = bytearray(total)
    outside = bytearray(total)
    queue: deque[int] = deque()

    for y in range(height):
        row = y * width
        for x in range(width):
            red, green, blue = source[x, y]
            candidate[row + x] = int(
                min(red, green, blue) >= 225
                and max(red, green, blue) - min(red, green, blue) <= 9
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
        if x > 0:
            seed(x - 1, y)
        if x + 1 < width:
            seed(x + 1, y)
        if y > 0:
            seed(x, y - 1)
        if y + 1 < height:
            seed(x, y + 1)
    return outside


def premultiplied_resize(rgb: Image.Image, alpha: Image.Image) -> Image.Image:
    rgba = rgb.copy()
    rgba.putalpha(alpha)
    # Pillow's RGBa mode stores premultiplied channels. Resizing in that mode
    # prevents transparent checker colours from bleeding into the skyline;
    # conversion back to RGBA safely unpremultiplies the finished pixels.
    return (
        rgba.convert("RGBa")
        .resize(OUTPUT_SIZE, Image.Resampling.LANCZOS)
        .convert("RGBA")
    )


def build(source: Path, output: Path) -> Image.Image:
    if sha256(source) != SOURCE_SHA256:
        raise SystemExit("Nugget Bridge ImageGen master SHA-256 changed")
    with Image.open(source) as opened:
        if opened.mode != "RGB" or opened.size != SOURCE_SIZE:
            raise SystemExit(
                f"unexpected Nugget Bridge master {opened.mode} {opened.size}"
            )
        rgb = opened.copy()

    sky = checker_sky(rgb)
    # ImageGen's baked preview blends one or two pale checker pixels into the
    # painted skyline.  Expand only the already boundary-connected sky by two
    # source pixels; at source resolution this removes the halo without changing a leaf's
    # readable silhouette, and the final Lanczos pass restores a soft edge.
    sky_mask = Image.frombytes(
        "L", SOURCE_SIZE, bytes(255 if value else 0 for value in sky)
    ).filter(ImageFilter.MaxFilter(9))
    alpha = sky_mask.point(lambda value: 0 if value else 255, mode="L")
    transparent = sum(1 for value in sky_mask.getdata() if value)
    total = SOURCE_SIZE[0] * SOURCE_SIZE[1]
    if not (total * 0.20 < transparent < total * 0.48):
        raise SystemExit(f"implausible transparent sky occupancy: {transparent}")
    if alpha.crop((0, 0, SOURCE_SIZE[0], 1)).getextrema() != (0, 0):
        raise SystemExit("arena scenery top edge stopped being transparent")
    if alpha.crop(
        (0, SOURCE_SIZE[1] - 1, SOURCE_SIZE[0], SOURCE_SIZE[1])
    ).getextrema() != (255, 255):
        raise SystemExit("arena scenery ground edge stopped being opaque")

    result = premultiplied_resize(rgb, alpha)
    out_alpha = result.getchannel("A")
    if result.size != OUTPUT_SIZE or result.mode != "RGBA":
        raise SystemExit("arena scenery output contract drifted")
    if out_alpha.crop((0, 0, OUTPUT_SIZE[0], 1)).getextrema() != (0, 0):
        raise SystemExit("resized arena scenery top edge stopped being transparent")
    if out_alpha.crop(
        (0, OUTPUT_SIZE[1] - 1, OUTPUT_SIZE[0], OUTPUT_SIZE[1])
    ).getextrema() != (255, 255):
        raise SystemExit("resized arena scenery ground edge stopped being opaque")
    histogram = out_alpha.histogram()
    if sum(histogram[1:255]) == 0:
        raise SystemExit("arena scenery skyline lost antialiasing")

    output.parent.mkdir(parents=True, exist_ok=True)
    result.save(output, format="PNG", optimize=False, compress_level=9)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    result = build(args.source.resolve(), args.output.resolve())
    alpha = result.getchannel("A").histogram()
    print(
        f"{sha256(args.output.resolve())}  {args.output.resolve()} "
        f"{result.width}x{result.height} rgba "
        f"transparent={alpha[0]} "
        f"partial={sum(alpha[1:255])}"
    )


if __name__ == "__main__":
    main()
