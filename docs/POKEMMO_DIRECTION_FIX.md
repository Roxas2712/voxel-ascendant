# PokeMMO follower direction correction

The delivered PokeMMO atlas rows were front, left, right, back. The shared
APO renderer and native six-frame strip builder expect front, left, back,
right. This made north-facing Pokémon use their right-side artwork and
right-facing Pokémon use their back artwork.

Normalize all 568 bundled variants to the existing renderer contract and
rebuild their native strips. Atlas texels are only reordered: no repainting,
resampling or new graphics. The small native strips retain the existing
nearest-neighbour fitting rule. HD sprites, characters, movement, collision,
camera controls and battle-button layouts are unchanged.

Validation: 2,272 exact atlas-row comparisons and 3,408 native-frame checks
against the pinned RC66f source archive; native Gen1 and Gen2 follower-source
runs plus four-direction raster inspection on macOS. This is not physical
mobile acceptance. This source fix does not replace the existing RC66f ZIP.

Reproduce with Python/Pillow:

```
python3 scripts/repair_pokemmo_direction_rows.py RC66f.zip . --apply
python3 tests/pokemmo_direction_assets_test.py . RC66f.zip
```

The conversion is pinned to the unmodified RC66f ZIP, checks the whole target
set before writing, and is idempotent. It refuses unrelated asset changes.
The repair must also be retained by the upstream MMO importer: normalize the
source rows before deriving native strips. Do not normalize HD atlases.
