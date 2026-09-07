# FRLG-ORAS bag runtime atlas

Private UI candidate derived from [The Spriters Resource asset 3865,
“Interface & Bag Screens”](https://www.spriters-resource.com/game_boy_advance/pokemonfireredleafgreen/asset/3865/),
uploaded by **2b2n**. The upstream sheet is not included in this repository.

These Pokémon game-art pixels are not covered by VASC's MIT licenses. This
atlas is retained only for the requested private RC test; redistribution
clearance is still outstanding and it must not be published as a release.

- Upstream file: `704x560` indexed PNG; SHA-256
  `054e4c6e88402127639baa870f16e2eee81c4e1076ed00025d2b85e7eff95610`.
- Runtime file: `assets/ui/frlg-oras-bag-3865.png`, `320x128` RGBA PNG;
  SHA-256 `3aee666ab5d247da143f31725d678491d32109ca08e110c1e575f9dc31531d2d`;
  RGBA pixel SHA-256
  `cdd36de11a986f90be081acfd965fe39f4277fcfa7895a2f13874194368167d9`.
- Builder: `tools/build_frlg_oras_bag_atlas.py`; it requires the original sheet,
  checks the upstream hash and dimensions, and copies only 64x64 cells with no
  scaling, filtering, recolouring or resampling. Exact matte `#9CDCEF` becomes
  binary transparency.

Atlas cells are 64x64. Row 0 is Leaf's shoulder bag and row 1 is Red's
backpack. Columns 0–3 are `closed`, `items`, `key items`, `Poke Balls`.
Column 4 row 0 is the shared Berry Pouch; column 4 row 1 is the shared TM Case.

| Runtime cell | Source crop `(x, y, w, h)` |
|---|---|
| Leaf closed | `(32, 32, 64, 64)` |
| Leaf items | `(112, 112, 64, 64)` |
| Leaf key items | `(32, 112, 64, 64)` |
| Leaf Poke Balls | `(112, 32, 64, 64)` |
| Berry Pouch | `(352, 32, 64, 64)` |
| Red closed | `(192, 32, 64, 64)` |
| Red items | `(272, 112, 64, 64)` |
| Red key items | `(192, 112, 64, 64)` |
| Red Poke Balls | `(272, 32, 64, 64)` |
| TM Case | `(352, 112, 64, 64)` |

For the six-pocket VASC provider, Items, Medicine and Battle Items share the
genuine FRLG `items` pose; Key Items and Poke Balls use their respective real
bag poses; TMs/HMs use the real TM Case. A provider with a separate Berries
pocket can use the real Berry Pouch. There are no fabricated eight-colour bag
states in this atlas.

`GAME/KASC` remains the default presentation and leaves the exact native,
Useful Bag or KASC draw owner untouched. `FRLG ORAS` is applied only after an
explicit player choice and wraps `draw` only; every provider callback, item,
pocket, input and save rule stays on the original Bag instance.
