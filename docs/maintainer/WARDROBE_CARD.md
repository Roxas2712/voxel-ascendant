# Wardrobe Card 1.1.0

Card ID: `vasc.gen1.wardrobe`. Integration baseline: KASC 6.7.19-rc.1, VASC 3.0.37-rc.8,
host 0.2.61. The optional Card owns `wardrobeEnabled`; KASC owns character
identity and save-local `wardrobe_v1` selections. OFF bypasses appearances without
deleting saved outfits. The bedroom wardrobe also offers untouched native looks.

The runtime uses the saved-layer compositor `wardrobe_overlay.lua` and three
reviewed packages under KASC `assets/wardrobe/collection/`. Each hero has ten
outfit combinations plus Original, with complete walking/fishing/bicycle layers,
League caps, eyewear and hair materials. Green additionally has Lotta caps and a
pink bag; her footwear remains paired with its authored trouser/shorts cuffs.

`wardrobe_packages.lua` registers only reviewed packages. Appearance readiness
requires successful registration for all three heroes. Assets are checked against
the exact HD source RGBA hashes, frame inventories and protected-pixel masks when
built. Missing or incompatible parts fail before save commit. No procedural
fallback or image generation runs in the game. Cached PNGs are bounded to 96
entries / 32 MiB. Battle HeroAtlas retains at most 12 decoded textures.

The Card routes the selected HD walking/fishing/bicycle atlases through existing
consumers, including Fly/Surf and the KASC HD throw. Existing animation order,
rig, timing, ball release and battle rules retain their original owners. The
trainer remains behind its Pokémon. Native/pixel back-throw frames and every
original source image are untouched. Quad caching includes resolved atlas bounds
so cap changes cannot reuse an old crop.

Verification in the release bundle:

- `collection-live.log`: all 33 recipes, full required actions, cap switching,
  high-density preview, original HD throw and standing trainer for all heroes.
- `collection-field-actions.log`: actual authored Champion outfits and League
  caps through walk, bike, fishing, Fly and Surf for all three heroes.
- `collection-production.log`: production package loading, saved accessories,
  open-hair-to-cap transition, two save slots/reload, Card OFF/ON, cabinet
  collision/interaction and untouched native walkers/bikes.
- `accessories-verified.log`: 39 accessory/material combinations checked.
- `release-rebuild.json`: repeated offline builds produce identical PNGs/receipts.
- `original-sprite-integrity.json`: 43 native and HD source images unchanged.
- `installer-verification.json`: version/hash checks, idempotence and exact rollback.

`tests/wardrobe_card_test.lua` verifies registry lifecycle and the service boundary.
The separate authoring kit documents saved parts, masks, recipes and reproducible
imports; future artwork must pass visual and action checks before review status.

## Blue cap coverage

Opaque cap material now replaces orange source-hair highlights that the skin heuristic previously protected. Fixed face/eye rectangles remain protected. Both League-cap orientations are verified in all 72 walk/fishing/bicycle frames against the saved artwork. The test rejects the 1.0.0 cap layers. The version-locked installer accepts known 1.0.0 payload hashes and records the actual pre-upgrade content for exact rollback.

## 1.1.0 — current RC compatibility

Rebased against the user-supplied KASC 6.7.19-rc.1 and VASC 3.0.37-rc.8 ZIPs. VoxelItems retains the new Driftglass prism seam and Moltres volcano boulder branches alongside the wardrobe model. All nine HD source atlases are byte-identical to the authored templates. The delivered installer verifies these exact RC versions and source hashes.

### KASC wardrobe 1.2.1 renderer selection

KASC reads `overworldPokemon.walkingSprites.enabled()` on the active public
provider. Native outfits remain native when HD PEOPLE is off. The external
KASC walker must retain renderers tagged `kaWardrobe2d`, including in the Voxel
view. The KASC provider owns activation and wardrobe creation. This optional
bridge adds no wardrobe setting when KASC is absent.

### 1.3.0: standalone VASC owner

Supersedes the previous no-KASC/no-wardrobe rule. In Gen 1, `SoloWardrobe`
installs the vendored wardrobe provider only when KASC is absent. It registers
one cabinet, binds the native Red actor and keeps selection in VASC's own
`wardrobe_v1` save entry. With KASC, no local provider is installed and KASC
remains authoritative. Walking and battle atlas consumers resolve the KASC
provider first, then the standalone VASC provider. All shared runtime/art files
are enumerated in `integrated/wardrobe/source-inventory.json` and copied by
`tools/sync_vasc_wardrobe.py` in the development project. Native small battle
backs remain original. Gen-2 protagonist outfits are outside this collection.
