"""Independent pixel oracle against the immutable, unnormalized source delivery."""
import csv
import io
from pathlib import Path
import sys
import zipfile
from PIL import Image

root, baseline = Path(sys.argv[1]), Path(sys.argv[2])
prefix = 'integrated/ascendant_pokemon_overworld/'
with zipfile.ZipFile(baseline) as archive:
    rows = list(csv.DictReader(io.StringIO(archive.read(prefix + 'production/pokemmo-follower-runtime.tsv').decode()), delimiter='\t'))
    for entry in rows:
        src = Image.open(io.BytesIO(archive.read(prefix + entry['atlas']))).convert('RGBA')
        dst = Image.open(root / prefix / entry['atlas']).convert('RGBA')
        strip = Image.open(root / prefix / entry['runtime_strip']).convert('RGBA')
        cell = src.width // 3
        # MMO source down/left/right/up; runtime card contract down/left/up/right.
        for source_row, dest_row in ((0, 0), (1, 1), (2, 3), (3, 2)):
            assert src.crop((0, source_row*cell, src.width, (source_row+1)*cell)).tobytes() == dst.crop((0, dest_row*cell, dst.width, (dest_row+1)*cell)).tobytes()
        for frame, (row, col) in enumerate(((0, 0), (3, 0), (1, 0), (0, 1), (3, 1), (1, 1))):
            pose = src.crop((col*cell, row*cell, (col+1)*cell, (row+1)*cell))
            pose = pose.crop(pose.getchannel('A').getbbox())
            scale = min(15/pose.width, 16/pose.height, 1)
            pose = pose.resize((max(1, round(pose.width*scale)), max(1, round(pose.height*scale))), Image.Resampling.NEAREST)
            canvas = Image.new('RGBA', (16, 16))
            canvas.alpha_composite(pose, ((16-pose.width)//2, 16-pose.height))
            assert strip.crop((0, frame*16, 16, frame*16+16)).tobytes() == canvas.tobytes(), entry['runtime_strip']
    assert len(rows) == 568
print('PASS 568 variants: 2272 pixel-exact direction rows and 3408 native runtime frames')
