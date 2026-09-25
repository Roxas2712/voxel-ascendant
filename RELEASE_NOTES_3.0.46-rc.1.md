# VASC 3.0.46-rc.1 — Kanto location terrariums

Local review candidate built on the GitHub Latest release v3.0.45 (f3c663f308d44a020fbe8ae91e726d3366d7fc58), retrieved on 2026-09-25. This candidate has not been published.

Integrates all 15 supplied Omega Dias designs across 43 exact Gen1 map IDs:

| Design | Maps |
| --- | --- |
| S.S. Anne | Bow only |
| Fighting Dojo | Fighting Dojo |
| Power Plant | Power Plant |
| Viridian Forest | Viridian Forest |
| Rocket Hideout 1 | B1F–B3F; existing office remains on B4F |
| Silph Company | 1F–11F, during Rocket occupation only |
| Pokémon Mansion | 1F–3F and B1F |
| Safari Zone | Center, East, North, West |
| Mt. Moon | 1F, B1F, B2F |
| Diglett’s Cave | Main cave |
| Cerulean Cave | 1F, 2F, B1F |
| Oak’s Lab | Laboratory |
| Champion Road | Victory Road 1F–3F |
| Route 17 | Cycling Road only |
| Seafoam Islands | 1F and B1F–B4F |

Selection uses exact IDs and excludes Gen2, neighboring routes, ship cabins, gates, elevators and unrelated maps. Existing gym, League, Tower and Rocket office designs retain their previous routing. No encounters are added or changed.

The original authored Lua files are preserved byte for byte with SHA-256 receipts in `integrated/terarrium/gyms/SOURCES.json`. The shared host supplies the bowl, ΩDIAS signature, cameras, participants, trainer platforms, lighting and bounded mesh cache. Location palettes retain their forest, cave, industrial, ship, safari, coast or ice theme. Authored scenes remain open bowls even when the optional glass dome is selected.

Silph occupation is checked from the live engine flag `EVENT_BEAT_SILPH_CO_GIOVANNI` whenever a stage is selected. After liberation, or when save state is unavailable, the normal Silph fallback is used. Cached modules never cache story eligibility; existing battles retain their stage until the next selection.

Use TERRARIUM as the battle presentation to see these scenes. The complete ZIP can be imported through the launcher updater with the game closed. It includes the 3.0.45 baseline; keep existing saves and optional artwork. Geometry is decorative; water, gates, ladders and machinery do not change battle or overworld rules.

See the delivery QA report for checks and limitations. Physical phone GPU verification remains separate from desktop or simulated mobile policy checks.
