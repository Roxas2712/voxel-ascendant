#!/usr/bin/env python3
"""Remove top-connected near-black matte residue from an RGBA outdoor master."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path
from statistics import median

from PIL import Image


def repair(
    source: Path,
    destination: Path,
    threshold: int,
    edge_threshold: int,
    edge_radius: int,
    speck_threshold: int,
    fill_dark_matte: bool,
) -> tuple[int, int, int, int, int, int]:
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

    # The generated outdoor paintings are one continuous foreground whose
    # fully opaque lower edge reaches the bottom of the file. Any remaining
    # alpha island that cannot reach that edge is therefore not scenery: it is
    # detached matte debris (the black bird-like flecks seen against runtime
    # skies). Remove the complete island, including its antialiased rim. This
    # topological rule is independent of color and consequently cannot shave
    # a dark tree, roof or mountain that is connected to the painted ground.
    foreground: set[tuple[int, int]] = set()
    foreground_queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        if pixels[x, height - 1][3] > 0:
            foreground.add((x, height - 1))
            foreground_queue.append((x, height - 1))
    while foreground_queue:
        x, y = foreground_queue.popleft()
        for neighbor_y in range(max(0, y - 1), min(height, y + 2)):
            for neighbor_x in range(max(0, x - 1), min(width, x + 2)):
                point = (neighbor_x, neighbor_y)
                if point not in foreground and pixels[neighbor_x, neighbor_y][3] > 0:
                    foreground.add(point)
                    foreground_queue.append(point)

    floating_removed = 0
    for y in range(height):
        for x in range(width):
            point = (x, y)
            if pixels[x, y][3] > 0 and point not in foreground:
                pixels[x, y] = (0, 0, 0, 0)
                sky.add(point)
                floating_removed += 1

    # Decontaminate the complete narrow live-sky fringe, not only black pixels.
    # Image generation left both black and cyan/green matte colors around tree
    # crowns. Alpha and therefore the exact silhouette stay byte-identical; RGB
    # is borrowed from fully opaque pixels further inside the same local object.
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
        if not alpha:
            continue
        samples: list[tuple[int, int, int]] = []
        for radius in range(depth + 1, edge_radius + 17):
            for sample_y in range(max(0, y - radius), min(height, y + radius + 1)):
                for sample_x in range(max(0, x - radius), min(width, x + radius + 1)):
                    sample_red, sample_green, sample_blue, sample_alpha = source_pixels[sample_x, sample_y]
                    sample_depth = distance.get((sample_x, sample_y), edge_radius + 1)
                    if (sample_alpha == 255 and sample_depth > edge_radius
                            and max(sample_red, sample_green, sample_blue)
                            > edge_threshold):
                        samples.append((sample_red, sample_green, sample_blue))
            if len(samples) >= 6:
                break
        if samples:
            pixels[x, y] = (
                int(median(sample[0] for sample in samples)),
                int(median(sample[1] for sample in samples)),
                int(median(sample[2] for sample in samples)),
                alpha,
            )
            fringe_recolored += 1

    # Thin tree tips may have no pixel deeper than the fringe radius. Repair
    # black/cyan/red generator islands from their clean local border inward.
    # Each pass uses a frozen source, so a thick island is corrected one honest
    # neighbourhood layer at a time instead of being flattened in one jump.
    # Alpha and therefore the exact painted silhouette remain untouched.
    sky_bottom = max((point[1] for point in sky), default=0)
    def recolor_specks() -> int:
        """Repair local matte outliers against the image's current colors."""
        speck_source = image.copy().load()
        candidates: set[tuple[int, int]] = set()
        for y in range(min(height, sky_bottom + 49)):
            for x in range(width):
                red, green, blue, alpha = speck_source[x, y]
                channels = sorted((red, green, blue))
                suspicious = (channels[2] <= 48
                              or (channels[0] <= 8 and channels[2] >= 70
                                  and channels[2] - channels[0] >= 70))
                if alpha and suspicious:
                    candidates.add((x, y))

        recolored = 0
        for _ in range(128):
            if not candidates:
                break
            speck_source = image.copy().load()
            changes: list[tuple[int, int, tuple[int, int, int]]] = []
            for x, y in candidates:
                red, green, blue, alpha = speck_source[x, y]
                channels = sorted((red, green, blue))
                suspicious = (channels[2] <= 48
                              or (channels[0] <= 8 and channels[2] >= 70
                                  and channels[2] - channels[0] >= 70))
                if not alpha or not suspicious:
                    continue
                local: list[tuple[int, int, int]] = []
                for sample_y in range(max(0, y - 3), min(height, y + 4)):
                    for sample_x in range(max(0, x - 3),
                                          min(width, x + 4)):
                        if sample_x == x and sample_y == y:
                            continue
                        sr, sg, sb, sa = speck_source[sample_x, sample_y]
                        if sa >= 128:
                            local.append((sr, sg, sb))
                if len(local) < 5:
                    continue
                center = (
                    int(median(sample[0] for sample in local)),
                    int(median(sample[1] for sample in local)),
                    int(median(sample[2] for sample in local)),
                )
                if max(abs(red - center[0]), abs(green - center[1]),
                       abs(blue - center[2])) >= speck_threshold:
                    changes.append((x, y, center))
            if not changes:
                break
            for x, y, center in changes:
                alpha = pixels[x, y][3]
                pixels[x, y] = (*center, alpha)
            recolored += len(changes)
        return recolored

    specks_recolored = recolor_specks()

    # A few early outdoor masters (notably Safari) contain enclosed, fully
    # opaque black matte masses rather than a thin colored fringe. They cannot
    # be turned transparent without punching holes through real branches.
    # When explicitly requested for such a reviewed master, propagate nearby
    # painted foliage/wood colors through each dark component while preserving
    # every alpha byte. This option is intentionally opt-in so normal shadows
    # in other paintings are never reinterpreted automatically.
    if fill_dark_matte:
        dark = {
            (x, y)
            for y in range(min(height, sky_bottom + 49))
            for x in range(width)
            if pixels[x, y][3] > 0 and max(pixels[x, y][:3]) <= 48
        }
        while dark:
            seed = dark.pop()
            component = {seed}
            component_queue = deque([seed])
            while component_queue:
                x, y = component_queue.popleft()
                for neighbor_y in range(max(0, y - 1), min(height, y + 2)):
                    for neighbor_x in range(max(0, x - 1), min(width, x + 2)):
                        point = (neighbor_x, neighbor_y)
                        if point in dark:
                            dark.remove(point)
                            component.add(point)
                            component_queue.append(point)
            if len(component) < 3:
                continue

            owners: dict[tuple[int, int], tuple[int, int, int]] = {}
            owner_queue: deque[tuple[int, int]] = deque()
            for x, y in sorted(component, key=lambda point: (point[1], point[0])):
                samples: list[tuple[int, int, int]] = []
                for radius in (3, 6, 10, 16):
                    samples = []
                    for sample_y in range(max(0, y - radius),
                                          min(height, y + radius + 1)):
                        for sample_x in range(max(0, x - radius),
                                              min(width, x + radius + 1)):
                            if (sample_x, sample_y) in component:
                                continue
                            sr, sg, sb, sa = pixels[sample_x, sample_y]
                            if sa >= 128 and max(sr, sg, sb) >= 80:
                                samples.append((sr, sg, sb))
                    if len(samples) >= 8:
                        break
                if samples:
                    owners[(x, y)] = (
                        int(median(sample[0] for sample in samples)),
                        int(median(sample[1] for sample in samples)),
                        int(median(sample[2] for sample in samples)),
                    )
                    owner_queue.append((x, y))
            if not owner_queue:
                continue
            while owner_queue:
                x, y = owner_queue.popleft()
                color = owners[(x, y)]
                for neighbor_y in range(max(0, y - 1), min(height, y + 2)):
                    for neighbor_x in range(max(0, x - 1), min(width, x + 2)):
                        point = (neighbor_x, neighbor_y)
                        if point in component and point not in owners:
                            owners[point] = color
                            owner_queue.append(point)
            for x, y in component:
                alpha = pixels[x, y][3]
                pixels[x, y] = (*owners[(x, y)], alpha)
            specks_recolored += len(component)

        # The broad fill can expose a handful of small color discontinuities
        # at its boundary. Run the exact same local gate once more against the
        # final painted colors so the shipped image and the validator agree.
        specks_recolored += recolor_specks()

    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, format="PNG", optimize=False)
    return (opaque_removed, low_alpha_removed, fringe_recolored, deepest_y,
            floating_removed, specks_recolored)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--threshold", type=int, default=16)
    parser.add_argument("--edge-threshold", type=int, default=72)
    parser.add_argument("--edge-radius", type=int, default=8)
    parser.add_argument("--speck-threshold", type=int, default=48)
    parser.add_argument("--fill-dark-matte", action="store_true")
    args = parser.parse_args()
    opaque, low_alpha, fringe, deepest, floating, specks = repair(
        args.source,
        args.destination,
        args.threshold,
        args.edge_threshold,
        args.edge_radius,
        args.speck_threshold,
        args.fill_dark_matte,
    )
    print(
        f"opaque_removed={opaque} low_alpha_removed={low_alpha} "
        f"fringe_recolored={fringe} deepest_y={deepest} "
        f"floating_removed={floating} specks_recolored={specks}"
    )


if __name__ == "__main__":
    main()
