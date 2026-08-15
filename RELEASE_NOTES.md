# Voxel Ascendant 0.1.0

RC.2 keeps the enemy and player battle HUDs inside Gen1Recomp's centered
battle frame. They now obey the same UI scale as the command and move menus,
instead of being enlarged independently at the physical window edges. This
prevents clipped names and oversized, disconnected status panels on large or
HiDPI displays.

It also adds a self-contained Gen-I Crystal battle-art pack and two VASC
options: **BATTLE ART** (`CRYSTAL` / `GEN I`) and **CRYSTAL MOTION**. The pack
contains front animations, rear cards and trainer portraits copied into this
repository from Kanto Ascendant's documented Gen-I sources. KASC keeps its own
files and remains the art authority when both mods are enabled; neither mod
depends on the other's installation.

The voxel world, MAP/DISCS stages and public companion API are unchanged.

## RC.1 foundation

This is the first standalone Voxel Ascendant release candidate for Gen1Recomp
0.1.90 and newer.

It is an MIT v1.6.1 fork and contains no code or assets from the Battle Art
voxel fork. It also ships
without Stadium models or ROM tooling, VR/OpenXR, Horde mode, external Gen 2
art, first-/third-person free movement, disk caching, or raw filesystem APIs.

The supported core is the voxel overworld, orbit camera modes, tilt-shift,
water/lighting options, and native Gen 1 card battles on MAP or DISCS. Kanto
Ascendant integration is optional and uses the documented versioned export
contract; Voxel Ascendant has no Kanto Ascendant dependency.
