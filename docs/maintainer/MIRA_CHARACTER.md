# Mira character artwork

KASC's Hunting Club leader uses the unique `SPRITE_KA_MIRA_WALK` identity.
The Gen-1 walking-sprite resolver maps that identity to role `mira`, without
changing any generic Cooltrainer. The existing character-style selector chooses
HD or voxel and restores KASC's palette-aware native renderer when disabled.

Assets under `integrated/ascendant_pokemon_overworld/assets/characters/`:

- `npcs/mira-kasc-hd-4x3-walk-sheet-v1.png`: HD 576×1024 atlas.
- `voxel-npcs/mira-kasc-hd-4x3-walk-sheet-v1.png`: matching voxel artwork.
- `runtime/npcs/mira-kasc-hd-4x3-walk-sheet-v1.png`: native 16×96 fallback.

Atlas rows: down, left, up, right. Columns: idle, left stride, right stride.
All cells have transparent backgrounds and consistent scale/foot alignment.
The existing atlas/voxel renderer consumes these assets; no standalone 3D model
or generic dialogue-rig calibration is introduced.

Original art generated with OpenAI's built-in image_gen, 2026-09-25, for this
project. Shared identity: asymmetrical auburn bob with tuft, teal neckerchief,
ochre field jacket, dark trousers, boots, brass badge and crossbody pouch.

Validation: native Red engine with KASC and VASC, Vanilla/HD/Voxel/Vanilla/HD
round trip, identity isolation, all four facings, and Hunting Club interaction
through accept/pause/party/cancel. Native fallback remains usable without VASC.
