#!/usr/bin/env python3
"""Render a small deterministic headless composition preview."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ATLAS = ROOT / "assets" / "scenery" / "cinnabar_story_landmarks.compact.png"
OUTPUT = (
    ROOT / "qa-screenshots" / "vasc" / "cinnabar-story-landmarks-20260823"
    / "cinnabar-volcano-birth-island-headless.png"
)


def banded_sky(canvas: Image.Image) -> None:
    draw = ImageDraw.Draw(canvas)
    bands = (
        (0, 95, (70, 139, 225, 255)),
        (95, 190, (92, 161, 235, 255)),
        (190, 285, (132, 192, 239, 255)),
        (285, 340, (183, 219, 241, 255)),
    )
    for y0, y1, color in bands:
        draw.rectangle((0, y0, canvas.width, y1), fill=color)


def sea(canvas: Image.Image) -> None:
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, 340, canvas.width, canvas.height), fill=(32, 132, 190, 255))
    for y, color, width in (
        (356, (104, 205, 225, 255), 3),
        (382, (57, 167, 209, 255), 2),
        (417, (126, 220, 228, 255), 3),
        (462, (43, 151, 199, 255), 4),
        (514, (156, 232, 232, 255), 3),
    ):
        for x in range(-20, canvas.width, 82):
            draw.arc((x, y, x + 62, y + 18), 200, 340, fill=color, width=width)


def main() -> None:
    canvas = Image.new("RGBA", (1100, 620), (0, 0, 0, 255))
    banded_sky(canvas)
    sea(canvas)
    with Image.open(ATLAS) as source:
        atlas = source.convert("RGBA")
    volcano = atlas.crop((18, 15, 238, 119)).resize(
        (330, 156), Image.Resampling.LANCZOS
    )
    birth = atlas.crop((256 + 30, 35, 256 + 226, 119)).resize(
        (280, 120), Image.Resampling.LANCZOS
    )
    canvas.alpha_composite(volcano, (210, 226))
    canvas.alpha_composite(birth, (576, 262))

    draw = ImageDraw.Draw(canvas)
    # A low near shoreline frames the approach without pretending to be the
    # final KASC map geometry.
    draw.polygon(
        ((0, 545), (170, 513), (330, 540), (515, 525), (690, 548),
         (875, 516), (1100, 540), (1100, 620), (0, 620)),
        fill=(68, 88, 82, 255),
    )
    draw.line(((0, 545), (170, 513), (330, 540), (515, 525), (690, 548),
               (875, 516), (1100, 540)), fill=(186, 220, 205, 255), width=5)
    draw.rectangle((0, 0, 1100, 42), fill=(12, 20, 25, 235))
    draw.text((18, 13),
              "VASC 2.0.1 HEADLESS PREVIEW  —  VULKAN LINKS / BIRTH ISLAND RECHTS",
              fill=(238, 244, 241, 255))
    draw.text((18, 590),
              "Kompositionstest; echte Position folgt dem verifizierten KASC-Suedkanal.",
              fill=(225, 235, 230, 255))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUTPUT, quality=91, optimize=True)
    print(OUTPUT)


if __name__ == "__main__":
    main()
