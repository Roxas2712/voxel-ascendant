#!/usr/bin/env python3
"""Build the deterministic two-module Cinnabar story-landmark atlas.

The retained ImageGen masters are large genuine-RGBA cut-outs.  They are
resampled with premultiplied colour into generously sized atlas modules so the
painted coast, surf and rock silhouettes remain continuous.  Runtime geometry
projects those samples at a smaller world size; texture resolution and visible
landmark size are deliberately independent.
"""

from __future__ import annotations

import argparse
import hashlib
import math
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "tools" / "sources" / "cinnabar_story_landmarks"
DEFAULT_OUTPUT = (
    ROOT / "assets" / "scenery" / "cinnabar_story_landmarks.compact.png"
)
MODULE_WIDTH = 256
ATLAS_HEIGHT = 128
PAINTED_BASELINE = 118
ALPHA_THRESHOLD = 8
MODULE_COLORS = 96
MIN_COMPONENT_PIXELS = 24

# filename, exact source SHA-256, exact ImageGen size/mode, maximum visible
# runtime footprint.  The fitted image never exceeds the handoff contract.
SOURCES = (
    (
        "01-cinnabar-volcano.imagegen.png",
        "cabb66307daf915e0a21e236769eed21ef2cbe7e1bc7601f42da14e74f21288b",
        (1774, 887),
        "RGBA",
        (220, 110),
    ),
    (
        "02-birth-island.imagegen.png",
        "cded987286560b4ebf4fbc52444ef639064e973babab82a23301b20839bc1b83",
        (1774, 887),
        "RGBA",
        (196, 98),
    ),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def remove_pixel_islands(alpha: Image.Image) -> Image.Image:
    """Remove tiny detached compact specks without touching real silhouettes."""
    out = alpha.copy()
    width, height = out.size
    seen: set[tuple[int, int]] = set()
    for y in range(height):
        for x in range(width):
            if out.getpixel((x, y)) < ALPHA_THRESHOLD or (x, y) in seen:
                continue
            component = [(x, y)]
            seen.add((x, y))
            cursor = 0
            while cursor < len(component):
                px, py = component[cursor]
                cursor += 1
                for nx, ny in (
                    (px - 1, py), (px + 1, py),
                    (px, py - 1), (px, py + 1),
                ):
                    if (0 <= nx < width and 0 <= ny < height
                            and (nx, ny) not in seen
                            and out.getpixel((nx, ny)) >= ALPHA_THRESHOLD):
                        seen.add((nx, ny))
                        component.append((nx, ny))
            if len(component) < MIN_COMPONENT_PIXELS:
                for px, py in component:
                    out.putpixel((px, py), 0)
    return out


def visible_palette(rgb: Image.Image, alpha: Image.Image) -> Image.Image:
    pixels = [
        color
        for color, opacity in zip(rgb.getdata(), alpha.getdata())
        if opacity >= 32
    ]
    if not pixels:
        raise ValueError("cannot quantize an empty landmark")
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
                f"{path}: expected {expected_size} {expected_mode}, "
                f"got {source.size} {source.mode}"
            )
        rgba = source.copy()

    source_alpha = rgba.getchannel("A").point(
        lambda value: 0 if value < ALPHA_THRESHOLD else value
    )
    bounds = source_alpha.getbbox()
    if bounds is None:
        raise ValueError(f"{path}: empty source alpha")
    crop = rgba.crop(bounds)
    source_w, source_h = crop.size
    scale = min(target_limit[0] / source_w, target_limit[1] / source_h)
    width = max(1, math.floor(source_w * scale + 0.5))
    height = max(1, math.floor(source_h * scale + 0.5))

    # Resize premultiplied color and alpha together.  This preserves the
    # painterly silhouette without pulling transparent RGB into its edge.
    resized = crop.convert("RGBa").resize(
        (width, height), resample=Image.Resampling.LANCZOS
    ).convert("RGBA")
    rgb = resized.convert("RGB")
    alpha = resized.getchannel("A").point(
        lambda value: 0 if value < ALPHA_THRESHOLD else value
    )
    alpha = remove_pixel_islands(alpha)
    painted = visible_palette(rgb, alpha).convert("RGBA")
    painted.putalpha(alpha)

    # Transparent RGB is zeroed explicitly; non-zero alpha keeps its straight
    # (unpremultiplied) quantized color for LOVE's ordinary alpha blending.
    pixels = list(painted.getdata())
    painted.putdata([
        pixel if pixel[3] else (0, 0, 0, 0) for pixel in pixels
    ])

    module = Image.new("RGBA", (MODULE_WIDTH, ATLAS_HEIGHT), (0, 0, 0, 0))
    x = (MODULE_WIDTH - width) // 2
    y = PAINTED_BASELINE - height + 1
    # Paste the RGBA pixels verbatim.  Passing ``painted`` as a mask here would
    # multiply its alpha a second time and punch holes into antialiased surf.
    module.paste(painted, (x, y))
    return module


def build() -> Image.Image:
    atlas = Image.new(
        "RGBA", (MODULE_WIDTH * len(SOURCES), ATLAS_HEIGHT), (0, 0, 0, 0)
    )
    for index, (filename, expected_hash, size, mode, limit) in enumerate(SOURCES):
        path = SOURCE_DIR / filename
        if not path.is_file():
            raise FileNotFoundError(f"missing retained source: {path}")
        actual_hash = sha256(path)
        if actual_hash != expected_hash:
            raise ValueError(f"{path}: source SHA-256 drifted: {actual_hash}")
        module = compact_module(path, size, mode, limit)
        atlas.paste(module, (index * MODULE_WIDTH, 0))
    return atlas


def audit(atlas: Image.Image) -> tuple[tuple[int, int, int, int], ...]:
    if atlas.size != (512, 128) or atlas.mode != "RGBA":
        raise ValueError("runtime atlas must be exactly 512x128 RGBA")
    alpha = atlas.getchannel("A")
    bounds: list[tuple[int, int, int, int]] = []
    limits = ((220, 110), (196, 98))
    for index, (max_width, max_height) in enumerate(limits):
        module = atlas.crop((index * 256, 0, (index + 1) * 256, 128))
        module_alpha = module.getchannel("A")
        bbox = module_alpha.getbbox()
        if bbox is None:
            raise ValueError(f"module {index} is empty")
        if bbox[2] - bbox[0] > max_width or bbox[3] - bbox[1] > max_height:
            raise ValueError(f"module {index} exceeds its world footprint: {bbox}")
        if any(module_alpha.getpixel((x, 0)) for x in range(256)):
            raise ValueError(f"module {index} touches the atlas top edge")
        if sum(module_alpha.getpixel((x, 127)) == 255 for x in range(256)) > 24:
            raise ValueError(f"module {index} restored a broad opaque base")
        if any(pixel[:3] != (0, 0, 0)
               for pixel in module.getdata() if pixel[3] == 0):
            raise ValueError(f"module {index} retained transparent RGB matte")
        bounds.append(bbox)
    return tuple(bounds)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    atlas = build()
    bounds = audit(atlas)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(args.output, optimize=True)
    print(f"wrote {args.output}")
    print(f"sha256={sha256(args.output)}")
    print(f"bounds={bounds}")


if __name__ == "__main__":
    main()
