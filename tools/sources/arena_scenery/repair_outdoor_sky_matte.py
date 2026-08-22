#!/usr/bin/env python3
"""Remove top-connected near-black matte residue from an RGBA outdoor master."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def repair(
    source: Path,
    destination: Path,
    threshold: int,
    edge_threshold: int,
    edge_radius: int,
) -> tuple[int, int, int, int]:
    image = Image.open(source).convert("RGBA")
    pixels = image.load()
    width, height = image.size

    def is_sky_matte(x: int, y: int) -> bool:
        red, green, blue, alpha = pixels[x, y]
        return alpha < 16 or max(red, green, blue) <= threshold

    queue: deque[tuple[int, int]] = deque()
    sky: set[tuple[int, int]] = set()
    for x in range(width):
        if is_sky_matte(x, 0):
            sky.add((x, 0))
            queue.append((x, 0))

    while queue:
        x, y = queue.popleft()
        for neighbor_y in range(max(0, y - 1), min(height, y + 2)):
            for neighbor_x in range(max(0, x - 1), min(width, x + 2)):
                point = (neighbor_x, neighbor_y)
                if point not in sky and is_sky_matte(neighbor_x, neighbor_y):
                    sky.add(point)
                    queue.append(point)

    opaque_removed = 0
    low_alpha_removed = 0
    deepest_y = 0
    for x, y in sky:
        red, green, blue, alpha = pixels[x, y]
        if alpha == 255:
            opaque_removed += 1
        elif alpha:
            low_alpha_removed += 1
        if alpha:
            deepest_y = max(deepest_y, y)
        pixels[x, y] = (0, 0, 0, 0)

    # Replace only the narrow near-black matte fringe next to the live-sky cut.
    # Its alpha/shape remains unchanged; RGB comes from the nearest local painted
    # silhouette colors, avoiding a black outline on bright runtime skies.
    distance: dict[tuple[int, int], int] = {point: 0 for point in sky}
    distance_queue: deque[tuple[int, int]] = deque(sky)
    while distance_queue:
        x, y = distance_queue.popleft()
        depth = distance[(x, y)]
        if depth == edge_radius:
            continue
        for neighbor_y in range(max(0, y - 1), min(height, y + 2)):
            for neighbor_x in range(max(0, x - 1), min(width, x + 2)):
                point = (neighbor_x, neighbor_y)
                if point not in distance:
                    distance[point] = depth + 1
                    distance_queue.append(point)

    source_pixels = image.copy().load()
    fringe_recolored = 0
    for (x, y), depth in distance.items():
        if not depth:
            continue
        red, green, blue, alpha = source_pixels[x, y]
        if not alpha or max(red, green, blue) > edge_threshold:
            continue
        samples: list[tuple[int, int, int]] = []
        for radius in range(1, 8):
            for sample_y in range(max(0, y - radius), min(height, y + radius + 1)):
                for sample_x in range(max(0, x - radius), min(width, x + radius + 1)):
                    sample_red, sample_green, sample_blue, sample_alpha = source_pixels[sample_x, sample_y]
                    if sample_alpha == 255 and max(sample_red, sample_green, sample_blue) > edge_threshold:
                        samples.append((sample_red, sample_green, sample_blue))
            if len(samples) >= 4:
                break
        if samples:
            count = len(samples)
            pixels[x, y] = (
                sum(sample[0] for sample in samples) // count,
                sum(sample[1] for sample in samples) // count,
                sum(sample[2] for sample in samples) // count,
                alpha,
            )
            fringe_recolored += 1

    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, format="PNG", optimize=False)
    return opaque_removed, low_alpha_removed, fringe_recolored, deepest_y


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--threshold", type=int, default=16)
    parser.add_argument("--edge-threshold", type=int, default=72)
    parser.add_argument("--edge-radius", type=int, default=3)
    args = parser.parse_args()
    opaque, low_alpha, fringe, deepest = repair(
        args.source,
        args.destination,
        args.threshold,
        args.edge_threshold,
        args.edge_radius,
    )
    print(
        f"opaque_removed={opaque} low_alpha_removed={low_alpha} "
        f"fringe_recolored={fringe} deepest_y={deepest}"
    )


if __name__ == "__main__":
    main()
