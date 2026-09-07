#!/usr/bin/env python3
"""Normalize the pinned RC66f MMO delivery to APO's front/left/back/right contract.

Mechanical asset conversion, not new artwork. Always read the immutable public
archive, never swap an already-normalized live atlas a second time.
"""
import argparse
import csv
import hashlib
import io
from pathlib import Path
import zipfile
from PIL import Image

PIN = '2f0dd8c67c9f204f8d5e9c08cd48cf84e004ea74bebcdb60ee027a3bf6825927'
PREFIX = 'integrated/ascendant_pokemon_overworld/'
INDEX = PREFIX + 'production/pokemmo-follower-runtime.tsv'


def normalize(source):
    cell = source.width // 3
    assert source.size == (cell * 3, cell * 4)
    target = Image.new('RGBA', source.size)
    for dst, src in enumerate((0, 1, 3, 2)):
        target.paste(source.crop((0, src * cell, source.width, (src + 1) * cell)), (0, dst * cell))
    return target


def runtime(atlas):
    cell = atlas.width // 3
    strip = Image.new('RGBA', (16, 96))
    width = height = 0
    for index, (row, col) in enumerate(((0, 0), (2, 0), (1, 0), (0, 1), (2, 1), (1, 1))):
        frame = atlas.crop((col * cell, row * cell, (col + 1) * cell, (row + 1) * cell))
        box = frame.getchannel('A').getbbox()
        assert box, 'empty source frame'
        actor = frame.crop(box)
        scale = min(15 / actor.width, 16 / actor.height, 1)
        size = (max(1, round(actor.width * scale)), max(1, round(actor.height * scale)))
        actor = actor.resize(size, Image.Resampling.NEAREST)
        strip.alpha_composite(actor, ((16 - actor.width) // 2, index * 16 + 16 - actor.height))
        width, height = max(width, size[0]), max(height, size[1])
    return strip, width, height


def png(image):
    output = io.BytesIO()
    image.save(output, format='PNG', optimize=True)
    return output.getvalue()


def expected(archive):
    reader = csv.DictReader(io.StringIO(archive.read(INDEX).decode()), delimiter='\t')
    fields = reader.fieldnames
    rows = list(reader)
    files = {}
    assert len(rows) == 568
    for row in rows:
        path = PREFIX + row['atlas']
        source = Image.open(io.BytesIO(archive.read(path))).convert('RGBA')
        atlas = normalize(source)
        strip, width, height = runtime(atlas)
        files[path] = png(atlas)
        files[PREFIX + row['runtime_strip']] = png(strip)
        row['runtime_content_width'], row['runtime_content_height'] = str(width), str(height)
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=fields, delimiter='\t', lineterminator='\n')
    writer.writeheader(); writer.writerows(rows)
    files[INDEX] = output.getvalue().encode()
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('root', type=Path)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    assert hashlib.sha256(args.archive.read_bytes()).hexdigest() == PIN, 'wrong baseline archive'
    with zipfile.ZipFile(args.archive) as archive:
        files = expected(archive)
        # Preflight the entire set before writing; preserve unrelated/local edits.
        for path, data in files.items():
            assert (args.root / path).read_bytes() in (archive.read(path), data), 'local edit: ' + path
        if args.apply:
            for path, data in files.items():
                (args.root / path).write_bytes(data)
        else:
            for path, data in files.items():
                assert (args.root / path).read_bytes() == data, 'not normalized: ' + path
    print('PASS 568 variants: normalized atlases + native six-frame strips; exact source pin; idempotent output')


if __name__ == '__main__':
    main()
