#!/usr/bin/env python3
"""Deterministic pixel acceptance for the photographed iOS intro-HUD fault.

This is a CPU simulation, not an iPhone or GPU test.  It verifies the exact
Gen1Recomp 0.1.90 battle-zone rectangles and red-channel shade thresholds
against an engine source tree, then applies that same mapping to the one state
that regressed: a wild-intro frame with the player's party-ball row live and
both status HUDs hidden.  The left panel visualizes the 0.1.4/KASC fallback
panel entering bgCanvas; the right panel visualizes 0.1.5 with no such panel.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


GB_W, GB_H = 160, 144
ENEMY_PANEL = (8, 0, 80, 32)

# Exact Gen1Recomp 0.1.90 BattleState.lua BATTLE_ZONES entries. Coordinates
# are inclusive 8x8 tile coordinates, and later entries replace earlier ones.
BATTLE_ZONES = (
    (0, 0, 0, 19, 17),
    (1, 1, 0, 10, 3),
    (0, 10, 7, 19, 10),
    (2, 0, 4, 8, 11),
    (3, 11, 0, 19, 6),
    (2, 0, 12, 19, 17),
)

# Exact Yellow SGB GREENBAR palette in data/palettes_yellow.lua. The supplied
# screenshot is a Yellow playthrough; its block falls in pal 1 (enemy HUD),
# for which a healthy enemy resolves GREENBAR. Alpha is carried through
# unchanged by PaletteFX.shader().
GREENBAR = (
    (255, 255, 255, 255),
    (255, 255, 0, 255),
    (0, 255, 0, 255),
    (25, 25, 25, 255),
)


def verify_engine_source(engine_root: Path) -> None:
    battle = (engine_root / "src/battle/BattleState.lua").read_text()
    palette_fx = (engine_root / "src/render/PaletteFX.lua").read_text()
    palettes = (engine_root / "data/palettes_yellow.lua").read_text()

    required_zones = (
        "{ pal = 0, 0, 0, 19, 17 }",
        "{ pal = 1, 1, 0, 10, 3 }",
        "{ pal = 0, 10, 7, 19, 10 }",
        "{ pal = 2, 0, 4, 8, 11 }",
        "{ pal = 3, 11, 0, 19, 6 }",
        "{ pal = 2, 0, 12, 19, 17 }",
    )
    for literal in required_zones:
        if literal not in battle:
            raise AssertionError(f"engine BATTLE_ZONES drifted: {literal}")
    threshold = (
        "p.r > 0.83 ? c0 : (p.r > 0.5 ? c1 : "
        "(p.r > 0.17 ? c2 : c3))"
    )
    if threshold not in palette_fx:
        raise AssertionError("engine PaletteFX shade thresholds drifted")
    for literal in (
        "{ 255, 255, 255 }",
        "{ 255, 255, 0 }",
        "{ 0, 255, 0 }",
        "{ 25, 25, 25 }",
    ):
        if literal not in palettes:
            raise AssertionError(f"engine GREENBAR palette drifted: {literal}")


def shade(red: int, palette: tuple[tuple[int, int, int, int], ...]) \
        -> tuple[int, int, int, int]:
    value = red / 255.0
    if value > 0.83:
        return palette[0]
    if value > 0.5:
        return palette[1]
    if value > 0.17:
        return palette[2]
    return palette[3]


def zone_at(x: int, y: int) -> int:
    selected = 0
    for palette, x1, y1, x2, y2 in BATTLE_ZONES:
        if x1 * 8 <= x < (x2 + 1) * 8 and y1 * 8 <= y < (y2 + 1) * 8:
            selected = palette
    return selected


def intro_bg_canvas(with_bad_panel: bool) -> Image.Image:
    canvas = Image.new("RGBA", (GB_W, GB_H), (0, 0, 0, 0))
    px = canvas.load()

    # Draw the exact live UI family for this phase: the player's party-ball
    # chrome/row. It is intentionally below the enemy panel zone. The simple
    # grayscale marks stand in for Gen1's actual HUD tiles; only canvas target,
    # alpha, zone placement and shade mapping matter to this regression.
    for x in range(72, 152):
        px[x, 88] = (0, 0, 0, 255)
    for i in range(6):
        cx = 88 + i * 8
        for yy in range(80, 86):
            for xx in range(cx, cx + 6):
                edge = xx in (cx, cx + 5) or yy in (80, 85)
                px[xx, yy] = (0, 0, 0, 255) if edge else (170, 170, 170, 255)

    # VASC 0.1.4 + exact KASC 6.5.6 restored this frost panel while bgCanvas
    # was bound. Use a deterministic two-shade frost field: PaletteFX maps the
    # dominant 96/255 red to GREENBAR c2 and the highlight to c0.
    if with_bad_panel:
        ex, ey, ew, eh = ENEMY_PANEL
        for y in range(ey, ey + eh):
            for x in range(ex, ex + ew):
                highlight = x > ex + ew * 3 // 4 and y < ey + eh // 2
                value = 230 if highlight else 96
                px[x, y] = (value, value, value, 220)
    return canvas


def zone_pass(source: Image.Image) -> Image.Image:
    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    src, dst = source.load(), out.load()
    # Only pal 1 is material to the photographed block. Other zones use the
    # same four colors in this diagnostic so ordinary grayscale furniture
    # remains readable while preserving exact thresholds and alpha behavior.
    palettes = {0: GREENBAR, 1: GREENBAR, 2: GREENBAR, 3: GREENBAR}
    for y in range(GB_H):
        for x in range(GB_W):
            r, _g, _b, alpha = src[x, y]
            mapped = shade(r, palettes[zone_at(x, y)])
            dst[x, y] = (mapped[0], mapped[1], mapped[2], alpha)
    return out


def world_backdrop() -> Image.Image:
    image = Image.new("RGBA", (GB_W, GB_H), (68, 104, 64, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, GB_H, 8):
        for x in range(0, GB_W, 8):
            if (x // 8 + y // 8) % 2:
                draw.rectangle((x, y, x + 7, y + 7), fill=(82, 121, 73, 255))
    draw.polygon(((0, 76), (160, 45), (160, 100), (0, 130)),
                 fill=(115, 112, 88, 255))
    return image


def compose(with_bad_panel: bool) -> Image.Image:
    world = world_backdrop()
    world.alpha_composite(zone_pass(intro_bg_canvas(with_bad_panel)))
    return world


def green_pixels(image: Image.Image) -> int:
    ex, ey, ew, eh = ENEMY_PANEL
    px = image.load()
    return sum(
        1 for y in range(ey, ey + eh) for x in range(ex, ex + ew)
        if px[x, y][:3] == GREENBAR[2][:3]
    )


def artifact(output: Path) -> None:
    bad_zone = zone_pass(intro_bg_canvas(True))
    fixed_zone = zone_pass(intro_bg_canvas(False))
    bad_green, fixed_green = green_pixels(bad_zone), green_pixels(fixed_zone)
    if bad_green < ENEMY_PANEL[2] * ENEMY_PANEL[3] // 2:
        raise AssertionError("bad control did not reproduce the green HUD slab")
    if fixed_green != 0:
        raise AssertionError("fixed intro still contains GREENBAR panel pixels")

    bad, fixed = compose(True), compose(False)

    scale, margin, header = 4, 12, 38
    panel_w, panel_h = GB_W * scale, GB_H * scale
    sheet = Image.new(
        "RGB", (panel_w * 2 + margin * 3, panel_h + header + margin),
        (28, 28, 31),
    )
    bad = bad.resize((panel_w, panel_h), Image.Resampling.NEAREST)
    fixed = fixed.resize((panel_w, panel_h), Image.Resampling.NEAREST)
    sheet.paste(bad.convert("RGB"), (margin, header))
    sheet.paste(fixed.convert("RGB"), (margin * 2 + panel_w, header))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    draw.text((margin, 10), f"SIMULATED 0.1.4 / KASC: {bad_green} green pixels",
              fill=(255, 180, 180), font=font)
    draw.text((margin * 2 + panel_w, 10),
              f"SIMULATED 0.1.5: {fixed_green} green pixels",
              fill=(165, 255, 190), font=font)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)
    print(f"ok simulated iOS zone-pass pixels: {output}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine-root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    verify_engine_source(args.engine_root)
    artifact(args.output)


if __name__ == "__main__":
    main()
