# Voxel Ascendant 3.0.28 — Smaller download, sprite maintenance & MAP camera

Changes since 3.0.27:

- **Much smaller download:** about 260 MiB instead of 465 MiB. Large background artwork uses high-quality compression at its original resolution, with lossless transparency where needed. Sprite and interface artwork is unchanged by this compression.
- **Sprite maintenance:** check/repair, reinstall and remove downloaded sprite packs from the integrated menu. Interrupted maintenance can recover after restarting. Saves, bundled artwork and Stadium imports are protected.
- **Clearer Gen 1 quick menu:** grouped controls for Wilds, followers, town Pokémon and their available graphic sources. The battle menu only offers relevant battle controls. Touch navigation and controller page switching are supported.
- **Character animations:** a one-time settings migration restores the natural HD character animation preset, including supported sitting/blinking animations. Choices made after that migration remain respected.
- **Route 22 MAP battles:** corrected the battle positions in both grass areas, avoiding the previously reproduced unnecessary arena fallback.
- **Closer, more flexible Gen 1 MAP camera:** new/unset distance starts at 1X; saved choices and 3X remain available. Manual rotation, tilt and zoom retain the last safe position instead of snapping back to the start of a gesture. World geometry, actor visibility and HUD clearance still limit movement.
- **Camera controls:** corrected Q/E zoom direction, improved mouse-wheel handling, and added camera distance and centring to the quick menu. Touch drag/pinch and controller controls share the same camera safeguards.
- **Battle Pokémon sizing:** normalizes supported companion sprite density before applying Pokédex/form height, preventing high-resolution cards from becoming oversized. Older supported KASC cards receive a compatibility correction. Exact new source-density/form metadata requires the matching KASC 6.7.14 line (tested with 6.7.14-rc.3); this VASC release does not update KASC automatically.

## Updating

Update VASC and fully restart the game. Keep downloaded/imported content and user files; do not delete the existing mod folder first. No new save or blanket sprite/model re-import is required. For manual desktop updates, the optional **Preserve-Installed-Sprites** installer backs up the existing installation and preserves optional downloads. The ZIP is the normal mod package.

## Validation

Archive CRC, all 656 Lua files and package file hashes checked. Native Gen 1 tests on macOS covered Route 22's 40 grass-cell placements, MAP move selection, portrait/landscape layouts and simulated touch/controller plus desktop inputs. Pokémon-size tests covered 1,351 species/form height entries, actual sprite-provider rendering and representative 2D/MAP/ARENA/DISCS battles, including 1X/3X MAP checks with Voltenso/Manectric and Rayquaza.

Physical iPhone/Android/Windows verification is still pending. Gen 2 camera behavior is unchanged. This release does not include a change for the recently reported portrait letterbox shading.
