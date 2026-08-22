#!/usr/bin/env python3
"""Build the compact, wrap-safe Kanto panorama from its retained master."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools/sources/kanto_panorama/kanto-panorama.imagegen.png"
OUTPUT = ROOT / "assets/scenery/kanto_panorama.compact.png"
SOURCE_SHA256 = "e0630428d652b1ad5921e6d03e0dad79ba6bb1d627c06d1141a5cf236658c7b1"
SOURCE_SIZE = (2172, 724)
CROP = (574, 180, 1598, 724)
HALF_SIZE = (512, 192)
OUTPUT_SIZE = (1024, 192)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(source: Path, output: Path) -> None:
    if sha256(source) != SOURCE_SHA256:
        raise SystemExit("kanto panorama master SHA-256 changed")
    with Image.open(source) as image:
        if image.mode != "RGBA" or image.size != SOURCE_SIZE:
            raise SystemExit(f"unexpected panorama master {image.mode} {image.size}")
        half = image.crop(CROP).resize(HALF_SIZE, Image.Resampling.NEAREST)

    alpha = half.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    rgb = half.convert("RGB").quantize(
        colors=32, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    ).convert("RGB")
    half = rgb.convert("RGBA")
    half.putalpha(alpha)

    output_image = Image.new("RGBA", OUTPUT_SIZE, (0, 0, 0, 0))
    output_image.paste(half, (0, 0))
    output_image.paste(half.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (512, 0))

    if output_image.getpixel((0, 191)) != output_image.getpixel((1023, 191)):
        raise SystemExit("panorama wrap seam is not byte-identical")
    output.parent.mkdir(parents=True, exist_ok=True)
    output_image.save(output, format="PNG", optimize=False, compress_level=9)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    build(args.source.resolve(), args.output.resolve())
    print(f"{sha256(args.output.resolve())}  {args.output}")


if __name__ == "__main__":
    main()
