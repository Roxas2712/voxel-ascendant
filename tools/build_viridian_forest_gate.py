#!/usr/bin/env python3
"""Build the canonical Route 2 Viridian-Forest gate facade bitmap.

This is a deterministic extraction of Gen I map art, not newly authored art.
The source tileset, exact Route 2 block composition, RED++ palette assignment
and binary silhouette rule are all pinned.  The runtime facade is the lower
40px (source y=24..63): it keeps the canonical eave, windows, brickwork and
door without mounting the top-down roof field as a vertical billboard.
"""

from __future__ import annotations

import argparse
from collections import deque
import hashlib
import os
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = (
    ROOT / "assets" / "scenery" / "viridian_forest_gate.compact.png"
)
SOURCE_RELATIVE = Path("assets/generated/tilesets/overworld.png")
SOURCE_SHA256 = "c2434aafd7d643e0f2f3866a41bf236d015eb6c39cf9f75dabc424750517b309"
RAW_COMPOSITE_RGBA_SHA256 = (
    "97b1ddd08923919a0523097781b1f8dd763c68c57c47d2827c48ac5d618f1783"
)

# ROUTE_2 building #2, top-left tile (4,80), whose door is Warp #6 to
# VIRIDIAN_FOREST_SOUTH_GATE. This is the B03/flat_commercial drawing in
# data/voxel_heights.lua, expressed as raw OVERWORLD tile ids.
TILES = (
    (0x4C, 0x53, 0x53, 0x53, 0x53, 0x53, 0x53, 0x4D),
    (0x5A, 0x12, 0x12, 0x12, 0x12, 0x12, 0x12, 0x5A),
    (0x5A, 0x12, 0x12, 0x12, 0x12, 0x12, 0x12, 0x5A),
    (0x5C, 0x17, 0x17, 0x17, 0x17, 0x17, 0x17, 0x5D),
    (0x0F, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x1F),
    (0x0F, 0x4B, 0x4B, 0x4B, 0x4B, 0x4B, 0x4B, 0x1F),
    (0x0F, 0x4B, 0x0B, 0x0C, 0x4B, 0x4B, 0x4B, 0x1F),
    (0x4E, 0x1A, 0x1B, 0x1C, 0x1A, 0x1A, 0x1A, 0x4F),
)

# PaletteFX.worldGroupAt(OVERWORLD, ROUTE_2, tile) for every tile used by
# this drawing. Group 6 receives ROUTE_2's roofByMapIndex[13] override.
TILE_GROUPS = {
    0x4C: 6, 0x53: 6, 0x4D: 6, 0x5A: 6,
    0x12: 6, 0x5C: 6, 0x17: 6, 0x5D: 6,
    0x0F: 0, 0x0A: 4, 0x1F: 0, 0x4B: 5,
    0x0B: 4, 0x0C: 4, 0x4E: 0, 0x1A: 0,
    0x1B: 5, 0x1C: 5, 0x4F: 0,
}
GROUP_COLORS = {
    0: ((222, 255, 222), (173, 173, 173),
        (107, 107, 107), (58, 58, 58)),
    4: ((222, 255, 222), (255, 255, 58),
        (255, 132, 8), (58, 58, 58)),
    5: ((222, 255, 222), (197, 148, 58),
        (165, 123, 25), (58, 58, 58)),
    6: ((222, 255, 222), (0, 239, 58),
        (0, 197, 58), (58, 58, 58)),
}
SHADE_INDEX = {255: 0, 170: 1, 85: 2, 0: 3}
FULL_EXPECTED_ALPHA_BBOX = (3, 0, 61, 64)
FULL_EXPECTED_OPAQUE = 3530
FACADE_CROP = (0, 24, 64, 64)
EXPECTED_ALPHA_BBOX = (3, 0, 61, 40)
EXPECTED_OPAQUE = 2140


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def default_source() -> Path:
    configured = os.environ.get("GEN1RECOMP_0190_ROOT")
    if configured:
        candidate = Path(configured) / SOURCE_RELATIVE
        if candidate.is_file():
            return candidate
    return ROOT.parent / "gen1recomp" / SOURCE_RELATIVE


def composite(source: Image.Image) -> Image.Image:
    if source.size != (128, 48) or source.mode != "RGBA":
        raise ValueError(
            f"expected canonical 128x48 RGBA OVERWORLD atlas, got "
            f"{source.size} {source.mode}"
        )
    raw = Image.new("RGBA", (64, 64))
    for tile_y, row in enumerate(TILES):
        for tile_x, tile in enumerate(row):
            source_x = (tile % 16) * 8
            source_y = (tile // 16) * 8
            raw.paste(
                source.crop((source_x, source_y, source_x + 8, source_y + 8)),
                (tile_x * 8, tile_y * 8),
            )
    if hashlib.sha256(raw.tobytes()).hexdigest() != RAW_COMPOSITE_RGBA_SHA256:
        raise ValueError("canonical Route 2 gate composite pixels drifted")
    return raw


def silhouette(raw: Image.Image) -> list[int]:
    """Flood boundary-connected light shades; preserve enclosed light detail."""
    width, height = raw.size
    pixels = list(raw.getdata())
    outside: set[int] = set()
    queue: deque[int] = deque()

    def seed(x: int, y: int) -> None:
        index = y * width + x
        # Exact four-shade source: 170/255 are the two non-structural shades.
        if index not in outside and pixels[index][0] >= 170:
            outside.add(index)
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
        for nx, ny in ((x + 1, y), (x - 1, y),
                       (x, y + 1), (x, y - 1)):
            if 0 <= nx < width and 0 <= ny < height:
                seed(nx, ny)
    return [0 if index in outside else 255 for index in range(width * height)]


def colorize(raw: Image.Image, alpha: list[int]) -> Image.Image:
    pixels = list(raw.getdata())
    output = Image.new("RGBA", raw.size)
    colored = []
    width = raw.width
    for index, (red, green, blue, source_alpha) in enumerate(pixels):
        if source_alpha != 255 or red != green or red != blue:
            raise ValueError("OVERWORLD source stopped being opaque four-shade art")
        shade = SHADE_INDEX.get(red)
        if shade is None:
            raise ValueError(f"unexpected OVERWORLD shade {red}")
        tile_x, tile_y = (index % width) // 8, (index // width) // 8
        group = TILE_GROUPS[TILES[tile_y][tile_x]]
        color = GROUP_COLORS[group][shade]
        colored.append((*color, alpha[index]))
    output.putdata(colored)
    return output


def build(source_path: Path, output_path: Path) -> Image.Image:
    if not source_path.is_file():
        raise FileNotFoundError(f"missing canonical gen1recomp atlas: {source_path}")
    if sha256(source_path) != SOURCE_SHA256:
        raise ValueError(f"canonical OVERWORLD atlas hash drifted: {source_path}")
    with Image.open(source_path) as opened:
        raw = opened.convert("RGBA")
    raw = composite(raw)
    full_alpha = silhouette(raw)
    full_result = colorize(raw, full_alpha)
    if raw.getbbox() != (0, 0, 64, 64):
        raise ValueError("canonical Route 2 gate composite bounds drifted")
    if full_result.getchannel("A").getbbox() != FULL_EXPECTED_ALPHA_BBOX:
        raise ValueError("full gate facade alpha bounding box drifted")
    if sum(value == 255 for value in full_alpha) != FULL_EXPECTED_OPAQUE:
        raise ValueError("full gate facade alpha occupancy drifted")
    if set(full_alpha) != {0, 255}:
        raise ValueError("full gate facade alpha stopped being binary")
    result = full_result.crop(FACADE_CROP)
    alpha = list(result.getchannel("A").getdata())
    if result.getchannel("A").getbbox() != EXPECTED_ALPHA_BBOX:
        raise ValueError("gate facade alpha bounding box drifted")
    if sum(value == 255 for value in alpha) != EXPECTED_OPAQUE:
        raise ValueError("gate facade alpha occupancy drifted")
    if set(alpha) != {0, 255}:
        raise ValueError("gate facade alpha stopped being binary")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    result.save(output_path, format="PNG", optimize=False, compress_level=9)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=default_source())
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    result = build(args.source.resolve(), args.output.resolve())
    visible_colors = {
        pixel[:3] for pixel in result.getdata() if pixel[3] == 255
    }
    print(
        f"{sha256(args.output.resolve())}  {args.output.resolve()} "
        f"{result.width}x{result.height} rgba colors={len(visible_colors)} "
        f"opaque={EXPECTED_OPAQUE} bbox={EXPECTED_ALPHA_BBOX}"
    )


if __name__ == "__main__":
    main()
