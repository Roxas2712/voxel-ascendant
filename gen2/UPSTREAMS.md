# Upstream ledger

Voxel Ascendant's integrated Gen-2 runtime keeps its two source lines separate
so either side can be updated without hiding provenance or turning future
merges into a copy/paste guess.

| source | pinned baseline | role |
| --- | --- | --- |
| `randyadr/Gen2-3D-Sprites` | tag `v0.2.81`, commit `91b61a1` | Gen-2 host, Gold/Silver bridges, Stadium 2 importer/models, Open World, Wilds/followers and custom Gen-2 UI |
| `Roxas2712/voxel-ascendant` | local VASC 2.0.10 development snapshot (2026-08-24), based on commit `6e0a3dd` | Current VASC behavior/API reference; reviewed shared modules/assets are ported while Gen2 keeps runtime ownership |

The names in this ledger document source provenance only. They do not name a
second runtime mod loaded alongside Voxel Ascendant.

The implemented VASC-derived tranches consist of:

- dynamic owner IDs and default-aware `ModSetting` behavior;
- independent overworld and battle voxel-grid controls;
- settings exposure for the existing Gen-2 curve, water, AA, resolution and
  shadow-quality implementations;
- a VASC API v1-shaped, owner-isolated public facade.
- current DayNight, Sky, SkyEvents and full Weather services;
- PanoramaBackdrop, HorizonWall scenery, interior cutaway and wall decals;
- device profiles, saved environment clocks, weather footsteps and local
  user sprite/music services.

No Nintendo ROM, ROM-derived Stadium model pack, or extracted model data is
part of the repository or release archive.
