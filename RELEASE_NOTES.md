# VASC 3.0.46-rc.5 — Menu audit and location terrariums

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

Runtime audit corrections in this candidate:

- Invalid optional Cobblemon installation receipts no longer prevent bundled models from loading.
- Gen2 shadow availability preserves the fitted canvas. Both generations explicitly release shadow resources on invalidation and failed replacement.
- Optional Terrarium dome, background and lighting failures remain local, produce one diagnostic per failure lifecycle and permit recovery after release.
- Missing Cobblemon models are negatively cached until content activation changes the content epoch, avoiding repeated disk reads and diagnostics.
- Failed Cobblemon texture preparation releases intermediate file, pixel and GPU objects.

See RUNTIME_AUDIT_2026-09-25.md and the delivery QA evidence for checks and limitations. Physical phone GPU verification remains separate from desktop or simulated mobile policy checks.

Further performance work in rc.3:

- Crystal artwork resolution caches bounded file-presence results and uses metadata on current hosts; legacy hosts read each path once. Missing art keeps the existing fallback. Transient read errors remain retryable.
- Gen2 shadow, antialiasing and scene passes share the existing platform receipt, removing repeated host capability checks from rendering.
- Terrarium lamps reuse per-arena data while updating positions, colors and lava animation. Weak arena ownership and explicit release bound the cache lifetime.

See PERFORMANCE_FOLLOWUP_2026-09-25.md for measured call/allocation reductions and validation.

Repository-wide audit changes in rc.4:

- Both generations show the actual default label when a saved setting becomes unavailable.
- Failed download-receipt writes retain their previous in-memory state so insertion, replacement and deletion remain retryable.
- Optional download diagnostics validate persisted reports, bound queues and fields, isolate encoder failures and back off oversized reports.
- Invalid non-finite day/night and sky clocks reset on save restoration in both generations.
- Content fulfillment waits for a safe, idle scene before resolving and hashing package plans; already-started downloads still finalize.
- The internal event bus reuses sorted listener snapshots until subscriptions change, preserving priority, recursive dispatch, teardown and failure isolation.

Validation: 72 headless suites; 432 native animation cases / 2,656 checks; Gen1 setup preview/apply/reopen in portrait and landscape; Crystal MAP/ARENA/DISCS/TERRARIUM battles, exits and optional-effect recovery. The audit also inventories and syntax-checks the entire Lua tree and parses all Python tools. See FULL_CODE_AUDIT_2026-09-25.md for per-subsystem coverage and limits.

Menu, download and setup corrections in rc.5:

- Contextual HELP survives conditional-row refreshes in both generations and in the download manager. Download collection/action selection survives inventory changes.
- Download status keeps the selected action when its state changes, hides unavailable manual-link actions and distinguishes successful verification from a required restart.
- F3 Back retains the originating group. Empty groups and optional status failures are handled safely; keyboard instructions use readable key names instead of unsupported arrow glyphs.
- Setup draft saves report failure and keep the screen open. Apply failures restore setting values and attempted callbacks, restore the options writer and allow retry. Resumed drafts reject invalid setting values/types and sanitize page indices.

Validation: 79 headless suites, native Red and Crystal menus, F3 groups in portrait/landscape, all ten Gen1 setup pages, real setup apply/reopen and graphics-check cancellation. Transfer interruption/restart/corrupt-cache cases use deterministic transport fixtures. No live-CDN throughput or physical-phone claim is made. See MENU_FLOW_AUDIT_2026-09-25.md.
