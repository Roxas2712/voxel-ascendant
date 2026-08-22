#!/usr/bin/env python3
"""Render the VASC audit Markdown as a self-contained local HTML viewer.

This intentionally uses only Python's standard library.  The audit is a
controlled Markdown subset (headings, paragraphs, tables, lists, quotes,
fenced code and links), so a focused renderer is both deterministic and keeps
the QA workstation free of another package dependency.
"""

from __future__ import annotations

import argparse
import html
import re
import unicodedata
from datetime import datetime
from pathlib import Path
from urllib.parse import quote


IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".gif"}
INLINE = re.compile(
    r"!\[([^\]]*)\]\(([^)]+)\)"
    r"|\[([^\]]+)\]\(([^)]+)\)"
    r"|`([^`]+)`"
    r"|\*\*([^*]+)\*\*"
    r"|(?<!\*)\*([^*]+)\*(?!\*)"
)


def slugify(value: str) -> str:
    value = unicodedata.normalize("NFKD", value)
    value = "".join(c for c in value if not unicodedata.combining(c))
    value = re.sub(r"[^a-zA-Z0-9]+", "-", value).strip("-").lower()
    return value or "abschnitt"


def href_for_browser(raw: str) -> str:
    raw = raw.strip()
    if raw.startswith(("http://", "https://", "#", "mailto:")):
        return raw
    if raw.startswith("/"):
        return "file://" + quote(raw)
    return quote(raw, safe="/:#?&=%+@")


def is_image(raw: str) -> bool:
    clean = raw.split("#", 1)[0].split("?", 1)[0]
    return Path(clean).suffix.lower() in IMAGE_SUFFIXES


def image_exists(source_dir: Path, raw: str) -> bool:
    if raw.startswith(("http://", "https://")):
        return True
    target = Path(raw)
    if not target.is_absolute():
        target = source_dir / target
    return target.is_file()


def inline(text: str, source_dir: Path) -> str:
    out: list[str] = []
    pos = 0
    for match in INLINE.finditer(text):
        out.append(html.escape(text[pos : match.start()]))
        image_alt, image_url, link_label, link_url, code, strong, emphasis = (
            match.groups()
        )
        if image_url is not None:
            url = href_for_browser(image_url)
            out.append(
                f'<a class="shot" href="{html.escape(url)}" data-image>'
                f'<img loading="lazy" src="{html.escape(url)}" '
                f'alt="{html.escape(image_alt)}"><span>{html.escape(image_alt)}</span></a>'
            )
        elif link_url is not None:
            url = href_for_browser(link_url)
            label = html.escape(link_label)
            if is_image(link_url):
                exists = image_exists(source_dir, link_url)
                legacy = " legacy" if Path(link_url).suffix.lower() in {".jpg", ".jpeg"} else ""
                missing = " missing" if not exists else ""
                thumb = (
                    f'<img loading="lazy" src="{html.escape(url)}" alt="{label}">'
                    if exists
                    else '<span class="missing-mark">Bild fehlt</span>'
                )
                out.append(
                    f'<a class="shot{legacy}{missing}" href="{html.escape(url)}" data-image>'
                    f'{thumb}<span>{label}</span></a>'
                )
            else:
                external = link_url.startswith(("http://", "https://"))
                attrs = ' target="_blank" rel="noreferrer"' if external else ""
                out.append(f'<a href="{html.escape(url)}"{attrs}>{label}</a>')
        elif code is not None:
            out.append(f"<code>{html.escape(code)}</code>")
        elif strong is not None:
            out.append(f"<strong>{html.escape(strong)}</strong>")
        else:
            out.append(f"<em>{html.escape(emphasis or '')}</em>")
        pos = match.end()
    out.append(html.escape(text[pos:]))
    return "".join(out)


def split_table_row(line: str) -> list[str]:
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|"):
        line = line[:-1]
    return [cell.strip() for cell in line.split("|")]


def is_table_separator(line: str) -> bool:
    cells = split_table_row(line)
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", c) for c in cells)


def render_markdown(markdown: str, source_dir: Path) -> tuple[str, list[tuple[int, str, str]]]:
    lines = markdown.splitlines()
    heading_ids: dict[int, str] = {}
    used: dict[str, int] = {}
    toc: list[tuple[int, str, str]] = []
    for index, line in enumerate(lines):
        match = re.match(r"^(#{1,6})\s+(.+?)\s*$", line)
        if not match:
            continue
        level, title = len(match.group(1)), match.group(2)
        title = re.sub(r"[*_`]", "", title)
        base = slugify(title)
        used[base] = used.get(base, 0) + 1
        anchor = base if used[base] == 1 else f"{base}-{used[base]}"
        heading_ids[index] = anchor
        if level in (2, 3):
            toc.append((level, title, anchor))

    rendered: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue

        heading = re.match(r"^(#{1,6})\s+(.+?)\s*$", line)
        if heading:
            level = len(heading.group(1))
            rendered.append(
                f'<h{level} id="{heading_ids[i]}">{inline(heading.group(2), source_dir)}</h{level}>'
            )
            i += 1
            continue

        if line.startswith("```"):
            language = line[3:].strip()
            code_lines: list[str] = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                code_lines.append(lines[i])
                i += 1
            i += 1 if i < len(lines) else 0
            klass = f' class="language-{html.escape(language)}"' if language else ""
            rendered.append(f"<pre><code{klass}>{html.escape(chr(10).join(code_lines))}</code></pre>")
            continue

        if line.startswith(">"):
            quote_lines: list[str] = []
            while i < len(lines) and lines[i].startswith(">"):
                quote_lines.append(re.sub(r"^>\s?", "", lines[i]))
                i += 1
            rendered.append(
                "<blockquote>" + "<br>".join(inline(x, source_dir) for x in quote_lines) + "</blockquote>"
            )
            continue

        if line.lstrip().startswith("|") and i + 1 < len(lines) and is_table_separator(lines[i + 1]):
            headers = split_table_row(line)
            i += 2
            rows: list[list[str]] = []
            while i < len(lines) and lines[i].lstrip().startswith("|"):
                rows.append(split_table_row(lines[i]))
                i += 1
            rendered.append('<div class="table-wrap"><table><thead><tr>')
            rendered.extend(f"<th>{inline(c, source_dir)}</th>" for c in headers)
            rendered.append("</tr></thead><tbody>")
            for row in rows:
                row += [""] * (len(headers) - len(row))
                rendered.append("<tr>")
                rendered.extend(f"<td>{inline(c, source_dir)}</td>" for c in row[: len(headers)])
                rendered.append("</tr>")
            rendered.append("</tbody></table></div>")
            continue

        unordered = re.match(r"^\s*[-*]\s+(.+)$", line)
        ordered = re.match(r"^\s*\d+\.\s+(.+)$", line)
        if unordered or ordered:
            tag = "ul" if unordered else "ol"
            items: list[str] = []
            pattern = r"^\s*[-*]\s+(.+)$" if unordered else r"^\s*\d+\.\s+(.+)$"
            while i < len(lines):
                item = re.match(pattern, lines[i])
                if not item:
                    break
                items.append(item.group(1))
                i += 1
            rendered.append(f"<{tag}>" + "".join(f"<li>{inline(x, source_dir)}</li>" for x in items) + f"</{tag}>")
            continue

        if re.fullmatch(r"\s*([-*_])(?:\s*\1){2,}\s*", line):
            rendered.append("<hr>")
            i += 1
            continue

        paragraph = [line.strip()]
        i += 1
        while i < len(lines) and lines[i].strip():
            nxt = lines[i]
            if re.match(r"^(#{1,6})\s+", nxt) or nxt.startswith((">", "```")):
                break
            if re.match(r"^\s*[-*]\s+", nxt) or re.match(r"^\s*\d+\.\s+", nxt):
                break
            if nxt.lstrip().startswith("|") and i + 1 < len(lines) and is_table_separator(lines[i + 1]):
                break
            paragraph.append(nxt.strip())
            i += 1
        rendered.append(f"<p>{inline(' '.join(paragraph), source_dir)}</p>")

    return "\n".join(rendered), toc


def image_gallery(markdown: str, source_dir: Path) -> str:
    seen: set[str] = set()
    cards: list[str] = []
    for match in re.finditer(r"\[([^\]]+)\]\(([^)]+\.(?:png|jpe?g|webp))\)", markdown, re.I):
        label, raw = match.group(1), match.group(2)
        if raw in seen or not image_exists(source_dir, raw):
            continue
        seen.add(raw)
        url = href_for_browser(raw)
        legacy = " legacy" if Path(raw).suffix.lower() in {".jpg", ".jpeg"} else ""
        cards.append(
            f'<a class="gallery-card{legacy}" href="{html.escape(url)}" data-image>'
            f'<img loading="lazy" src="{html.escape(url)}" alt="{html.escape(label)}">'
            f'<span>{html.escape(label)}</span></a>'
        )
    if not cards:
        return ""
    return (
        '<section class="evidence" id="bilduebersicht"><div class="evidence-head">'
        f'<div><h2>Bildübersicht</h2><p>{len(cards)} verlinkte Belege – klicken für Originalgröße. '
        'Gelb markierte JPGs sind nur historische Übersicht, PNGs sind maßgeblich.</p></div>'
        '</div><div class="gallery">' + "".join(cards) + "</div></section>"
    )


STYLE = r"""
:root{color-scheme:dark;--bg:#0b1016;--panel:#111923;--panel2:#172331;--text:#e8eef5;--muted:#9cafc3;--line:#26384b;--cyan:#57d6d2;--green:#73dc8c;--yellow:#ffd166;--red:#ff6b6b;--blue:#70a7ff;--shadow:0 14px 42px #0007}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:radial-gradient(circle at 80% -10%,#1a3343 0,transparent 35%),var(--bg);color:var(--text);font:16px/1.58 ui-sans-serif,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
a{color:#8ddcff;text-decoration:none}a:hover{text-decoration:underline}.shell{display:grid;grid-template-columns:290px minmax(0,1fr);min-height:100vh}.sidebar{position:sticky;top:0;height:100vh;overflow:auto;padding:24px 18px;background:#0d151ed9;border-right:1px solid var(--line);backdrop-filter:blur(16px)}.brand{padding:4px 8px 20px;border-bottom:1px solid var(--line);margin-bottom:15px}.brand b{display:block;font-size:18px;letter-spacing:.02em}.brand span{font-size:12px;color:var(--muted)}.toc a{display:block;padding:6px 9px;border-radius:7px;color:#bdcad7;font-size:13px}.toc a.l3{padding-left:22px;color:#879bad}.toc a:hover{background:#162331;text-decoration:none;color:white}.content{max-width:1480px;width:100%;padding:40px 48px 100px}.hero{border:1px solid var(--line);border-radius:18px;background:linear-gradient(135deg,#172433,#101821);padding:28px 32px;box-shadow:var(--shadow);margin-bottom:26px}.hero .kicker{color:var(--cyan);text-transform:uppercase;letter-spacing:.14em;font-size:12px;font-weight:800}.hero h1{border:0;margin:.2em 0;font-size:clamp(28px,4vw,52px)}.hero p{max-width:80ch;color:var(--muted)}.badges{display:flex;gap:9px;flex-wrap:wrap;margin-top:16px}.badge{padding:6px 10px;border-radius:999px;border:1px solid #445467;background:#0b1118;font-weight:700;font-size:12px}.badge.reject{color:#ff9e9e;border-color:#7f3a40}.badge.work{color:#ffe09b;border-color:#6c5a2e}.badge.native{color:#9ae8d1;border-color:#276653}
main>h1{display:none}h1,h2,h3,h4{line-height:1.18;scroll-margin-top:24px}h2{margin:55px 0 16px;padding-bottom:10px;border-bottom:1px solid var(--line);font-size:28px}h3{margin:34px 0 12px;font-size:21px;color:#dce9f7}h4{color:#bad0e6}p{max-width:110ch}strong{color:#fff}code{background:#1a2836;border:1px solid #2c4153;border-radius:5px;padding:.1em .35em;color:#b6f3de;font-size:.9em}pre{background:#071018;border:1px solid var(--line);padding:18px;border-radius:10px;overflow:auto}blockquote{margin:18px 0;padding:14px 18px;border-left:4px solid var(--yellow);background:#211f18;color:#e9dfbd;border-radius:0 9px 9px 0}li{margin:.32em 0}.table-wrap{overflow:auto;border:1px solid var(--line);border-radius:12px;margin:17px 0 26px;box-shadow:0 8px 25px #0003}table{border-collapse:collapse;width:100%;min-width:720px;background:#0f1720}th{position:sticky;top:0;background:#1a2836;color:#dbe9f6;text-align:left;font-size:13px;letter-spacing:.01em}th,td{padding:11px 12px;border-bottom:1px solid #223242;border-right:1px solid #1c2b38;vertical-align:top}tr:nth-child(even) td{background:#121c27}td strong{color:#ffb3b3}
.evidence{padding:24px;border:1px solid var(--line);border-radius:16px;background:#0e1721;margin:26px 0 42px}.evidence h2{margin:0;border:0;padding:0}.evidence-head p{margin:.4em 0 1.2em;color:var(--muted)}.gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:14px}.gallery-card,.shot{border:1px solid #314558;background:#0b1219;border-radius:10px;overflow:hidden;color:#d9e8f5;text-decoration:none;box-shadow:0 6px 16px #0004}.gallery-card{display:flex;flex-direction:column;min-height:150px}.gallery-card img{display:block;width:100%;height:180px;object-fit:contain;image-rendering:pixelated;background:#070b10}.gallery-card span,.shot span{padding:8px 10px;font-size:12px}.gallery-card.legacy{border-color:#68572d}.shot{display:inline-grid;vertical-align:top;max-width:230px;margin:4px}.shot img{display:block;max-width:100%;max-height:140px;object-fit:contain;image-rendering:pixelated;background:#070b10}.shot.legacy{border-color:#68572d}.shot.missing{border-color:#7f3a40}.missing-mark{padding:12px;color:#ff9e9e}.shot:hover,.gallery-card:hover{border-color:var(--cyan);text-decoration:none;transform:translateY(-1px)}
dialog{border:1px solid #4b6175;border-radius:14px;background:#060a0e;padding:12px;max-width:96vw;max-height:96vh;box-shadow:0 24px 80px #000}dialog::backdrop{background:#000c;backdrop-filter:blur(5px)}dialog img{display:block;max-width:92vw;max-height:88vh;object-fit:contain;image-rendering:pixelated}.close{position:fixed;top:16px;right:22px;border:1px solid #677d90;border-radius:999px;background:#101923;color:white;padding:9px 13px;cursor:pointer}
@media(max-width:900px){.shell{display:block}.sidebar{position:relative;height:auto;border-right:0;border-bottom:1px solid var(--line)}.toc{columns:2}.content{padding:24px 16px 70px}.hero{padding:22px 20px}.gallery{grid-template-columns:repeat(auto-fill,minmax(160px,1fr))}.gallery-card img{height:130px}}
@media print{.sidebar,.hero .badges,dialog{display:none}.shell{display:block}.content{max-width:none;padding:0}body{background:white;color:#111}a{color:#0366d6}.table-wrap{box-shadow:none}table,th,td{color:#111;background:white!important}.shot img{max-height:90px}}
"""


SCRIPT = r"""
const dlg=document.getElementById('lightbox'),pic=dlg.querySelector('img');
document.addEventListener('click',e=>{const a=e.target.closest('[data-image]');if(!a)return;e.preventDefault();pic.src=a.href;pic.alt=(a.textContent||'Bild').trim();dlg.showModal();});
dlg.addEventListener('click',e=>{if(e.target===dlg||e.target.classList.contains('close'))dlg.close();});
"""


def build(source: Path, destination: Path) -> None:
    markdown = source.read_text(encoding="utf-8")
    body, toc = render_markdown(markdown, source.parent)
    toc_html = "".join(
        f'<a class="l{level}" href="#{anchor}">{html.escape(title)}</a>'
        for level, title, anchor in toc
    )
    gallery = image_gallery(markdown, source.parent)
    generated = datetime.now().astimezone().strftime("%d.%m.%Y · %H:%M %Z")
    document = f"""<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>VASC Panorama-Audit</title><style>{STYLE}</style></head>
<body><div class="shell"><aside class="sidebar"><div class="brand"><b>VASC Panorama-Audit</b><span>Arbeitsbericht · {generated}</span></div><nav class="toc">{toc_html}</nav></aside>
<div class="content"><header class="hero"><div class="kicker">Native Screenshot QA</div><h1>VASC Panorama-Audit</h1><p>Visueller Arbeitsbericht mit direkt eingebetteten Belegen. PNG-Kontaktbögen und Originalbilder öffnen per Klick in voller Größe. Ein grüner Vertragstest gilt nicht automatisch als visuelle Freigabe.</p><div class="badges"><span class="badge reject">Gesamtsystem: REJECT</span><span class="badge work">Korrekturschleife läuft</span><span class="badge native">Native PNGs maßgeblich</span></div></header>{gallery}<main>{body}</main></div></div>
<dialog id="lightbox"><button class="close" type="button">Schließen</button><img alt="Screenshot"></dialog><script>{SCRIPT}</script></body></html>"""
    destination.write_text(document, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    build(args.source.resolve(), args.destination.resolve())
    print(args.destination.resolve())


if __name__ == "__main__":
    main()
