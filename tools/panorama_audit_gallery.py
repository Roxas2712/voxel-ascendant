#!/usr/bin/env python3
"""Build browsable contact sheets from the QA panorama capture tree.

Expected input layout::

    <root>/<MAP>/panorama/N.png
    <root>/<MAP>/connections/*.png
    <root>/<MAP>/warps/*.png
    <root>/<MAP>/buildings/*.png

The tool is deliberately independent from the game runtime.  It never edits
captures; it creates labelled, downscaled review sheets and a local HTML index
whose thumbnails link back to the full-resolution evidence.
"""

from __future__ import annotations

import argparse
import html
import math
import os
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


PANORAMA_ORDER = {"N": 0, "E": 1, "S": 2, "W": 3}
CARD = (600, 375)
LABEL_H = 42
PAGE_SIZE = 12


def font(size: int) -> ImageFont.ImageFont:
    candidates = (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    )
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            pass
    return ImageFont.load_default()


TITLE_FONT = font(24)
LABEL_FONT = font(18)


def card(path: Path, label: str) -> Image.Image:
    with Image.open(path) as source:
        source = ImageOps.exif_transpose(source).convert("RGB")
        # These sheets are visual evidence for deliberately hard-edged pixel
        # art. Lanczos introduces blur/ringing and JPEG adds block noise, so a
        # contact sheet made with either can exaggerate the exact defect the
        # audit is meant to measure. Keep nearest-neighbour texels here; every
        # card still links to the full-resolution source PNG for final review.
        fitted = ImageOps.contain(source, CARD, Image.Resampling.NEAREST)
    out = Image.new("RGB", (CARD[0], CARD[1] + LABEL_H), "#11151b")
    out.paste(fitted, ((CARD[0] - fitted.width) // 2,
                       (CARD[1] - fitted.height) // 2))
    draw = ImageDraw.Draw(out)
    draw.rectangle((0, CARD[1], CARD[0], CARD[1] + LABEL_H), fill="#202733")
    draw.text((14, CARD[1] + 9), label, font=LABEL_FONT, fill="#f5f7fa")
    return out


def contact_sheet(items: list[tuple[Path, str]], title: str,
                  columns: int = 2) -> Image.Image:
    rows = max(1, math.ceil(len(items) / columns))
    gap, title_h = 12, 54
    width = columns * CARD[0] + (columns + 1) * gap
    height = title_h + rows * (CARD[1] + LABEL_H) + (rows + 1) * gap
    sheet = Image.new("RGB", (width, height), "#0b0f14")
    draw = ImageDraw.Draw(sheet)
    draw.text((gap, 14), title, font=TITLE_FONT, fill="#ffffff")
    for index, (path, label) in enumerate(items):
        row, col = divmod(index, columns)
        x = gap + col * (CARD[0] + gap)
        y = title_h + gap + row * (CARD[1] + LABEL_H + gap)
        sheet.paste(card(path, label), (x, y))
    return sheet


def image_files(root: Path) -> list[Path]:
    suffixes = {".png", ".jpg", ".jpeg", ".webp"}
    return sorted(path for path in root.rglob("*")
                  if path.is_file() and path.suffix.lower() in suffixes)


def grouped(root: Path) -> dict[str, dict[str, list[Path]]]:
    maps: dict[str, dict[str, list[Path]]] = {}
    for path in image_files(root):
        rel = path.relative_to(root)
        if len(rel.parts) < 3:
            continue
        map_id, category = rel.parts[0], rel.parts[1]
        maps.setdefault(map_id, {}).setdefault(category, []).append(path)
    return maps


def sort_category(category: str, paths: list[Path]) -> list[Path]:
    if category == "panorama":
        def panorama_key(path: Path) -> tuple[int, int, str]:
            match = re.fullmatch(r"anchor(\d+)", path.parent.name,
                                 flags=re.IGNORECASE)
            anchor = int(match.group(1)) if match else 0
            return (anchor, PANORAMA_ORDER.get(path.stem.upper(), 99),
                    str(path))

        return sorted(paths, key=panorama_key)
    return sorted(paths, key=lambda p: p.name)


def safe_name(value: str) -> str:
    return "".join(c if c.isalnum() or c in "-_" else "-" for c in value)


def build(root: Path, output: Path) -> tuple[int, int]:
    maps = grouped(root)
    output.mkdir(parents=True, exist_ok=True)
    sheets_root = output / "sheets"
    sheets_root.mkdir(exist_ok=True)
    nav, sections = [], []
    capture_count = 0

    for map_id in sorted(maps):
        anchor = safe_name(map_id).lower()
        nav.append(f'<a href="#{anchor}">{html.escape(map_id)}</a>')
        blocks = [f'<section id="{anchor}"><h2>{html.escape(map_id)}</h2>']
        map_out = sheets_root / safe_name(map_id)
        map_out.mkdir(exist_ok=True)
        for category in ("panorama", "connections", "warps", "buildings"):
            paths = sort_category(category, maps[map_id].get(category, []))
            if not paths:
                continue
            capture_count += len(paths)
            blocks.append(f'<h3>{html.escape(category.title())} '
                          f'<span>{len(paths)}</span></h3>')
            for page_index in range(0, len(paths), PAGE_SIZE):
                page = paths[page_index:page_index + PAGE_SIZE]
                items = []
                for path in page:
                    rel_capture = path.relative_to(root)
                    label_parts = list(rel_capture.parts[2:])
                    label_parts[-1] = Path(label_parts[-1]).stem
                    items.append((path, "/".join(label_parts).replace("_", " ")))
                number = page_index // PAGE_SIZE + 1
                out_name = f"{category}-{number:02d}.png"
                sheet = contact_sheet(items, f"{map_id} · {category} · {number}")
                sheet.save(map_out / out_name, format="PNG", optimize=True)
                rel_sheet = (map_out / out_name).relative_to(output)
                blocks.append(f'<a class="sheet" href="{html.escape(str(rel_sheet))}">'
                              f'<img loading="lazy" src="{html.escape(str(rel_sheet))}" '
                              f'alt="{html.escape(map_id + " " + category)}"></a>')
            blocks.append('<div class="originals">')
            for path in paths:
                rel = Path(os.path.relpath(path, output))
                blocks.append(f'<a href="{html.escape(str(rel))}">'
                              f'{html.escape(path.name)}</a>')
            blocks.append('</div>')
        blocks.append('</section>')
        sections.append("\n".join(blocks))

    page = f"""<!doctype html>
<html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>VASC Panorama Audit</title>
<style>
body{{margin:0;background:#0b0f14;color:#eef2f7;font:16px system-ui,sans-serif}}
header{{position:sticky;top:0;background:#111823ee;padding:16px 24px;z-index:2}}
h1{{margin:0 0 10px;font-size:24px}} nav{{display:flex;gap:8px;flex-wrap:wrap}}
nav a,.originals a{{color:#9bc5ff;text-decoration:none}} nav a{{background:#202b3a;padding:5px 8px;border-radius:5px}}
main{{max-width:1320px;margin:auto;padding:20px}} section{{padding:18px 0 34px;border-bottom:1px solid #303844}}
h2{{font-size:28px}} h3 span{{color:#94a0b2;font-weight:400}} .sheet img{{width:100%;height:auto;border:1px solid #303844}}
.originals{{display:flex;gap:8px;flex-wrap:wrap;margin:8px 0 24px}} .originals a{{font-size:13px}}
</style></head><body><header><h1>VASC Panorama Audit</h1><nav>{''.join(nav)}</nav></header>
<main>{''.join(sections)}</main></body></html>"""
    (output / "index.html").write_text(page, encoding="utf-8")
    return len(maps), capture_count


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture_root", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    maps, captures = build(args.capture_root.resolve(), args.output.resolve())
    print(f"panorama gallery: {maps} maps, {captures} captures -> {args.output}")


if __name__ == "__main__":
    main()
