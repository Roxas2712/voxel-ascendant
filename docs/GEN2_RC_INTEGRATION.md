# Voxel Ascendant 3.0 RC: Gen2 integration

This checkout is the shared VASC 3.0 RC integration tree. Its Gen1 and Gen2
runtimes are reviewed together and packaged as one deterministic release.

## One package, two isolated runtimes

- `main.lua` detects the active game generation and fails closed when it cannot
  identify one.
- `main_gen1.lua` is the reviewed Gen1 VASC 3.0 runtime. It preserves the 2.x
  rendering foundation while adding the common 3.0 menu, content-profile,
  mobile-HUD and compatibility contracts. Gen1 continues using root `lib/`,
  `data/` and assets.
- `gen2/main.lua`, `gen2/lib/` and `gen2/data/` are the private Johto runtime.
  A facade redirects only Gen2 code/data/options reads into this namespace.
- Assets and documented `user/` folders remain shared at package root.
- The manifest has no global `options_schema`. The dispatcher registers the
  51-key Gen2 schema only when Generation 2 is active; Gen1 continues to define
  its existing options itself.

## Native Gen2 UI boundary

Gold, Silver and Crystal remain owners of menu, dialogue, YES/NO, list and
battle semantics. VASC installs one `ui.start_menu.items` contribution labelled
`VASC` after `OPTION`. Its nine-section hub reuses the package-root
`VascMenu`/`VascMenuStyle` controller and shared FireRed/LeafGreen Ascendant
surface. With `OVERWORLD MENUS=ORAS GLASS`, package-root `OrasUiSkin` decorates
the native Gen-2 START menu, dialogue, choices and ordinary lists through
draw-only hooks. `GAME DEFAULT` restores the edition's original drawing live;
input, pagination, callbacks and saves never change.

The retired broad pause/submenu controllers, divergent edition palettes and
controller input wrapper remain inactive. Draw-only adapters may present the
native Party/Summary state and ordinary battle menu/move phases as ORAS GLASS;
Gen-2 battle commands, callbacks and input stay engine-native.

## Gen2 behavior in this RC

- Voxel views: FULL, 15, 35, 50, 75, first person and third person.
- Third person uses Gold's native stepped movement/animation with
  camera-relative cardinal mapping; only first person uses continuous movement.
- Weather, time of day, sky events, panoramas, scenery, open-world streaming,
  visible wild Pokémon, followers and local content services are namespaced.
- Live voxel battles use the optional draw-only ORAS HUD only in ordinary
  menu/move phases. Intro, animation, capture, prompt, learning/evolution,
  submenu and special-battle phases render the complete native Gen2 UI.
- A failed voxel battle composite re-enters Gold's full native battle renderer,
  including background, trainer/Pokémon pics, HUD, text and commands.
- The overworld capture minigame is disabled for this RC pending ROM QA.
- VR/OpenXR is disabled; no VR backend or native binary ships.

## Smooth AUTO and cold-map loading

The device row remains `AUTO`, `PC/MAX`, `HANDHELD`, `ECO` or `CUSTOM`.
`AUTO` deliberately resolves balanced and high hosts to `HANDHELD`, not MAX;
low hosts resolve to `ECO`. The user can still select MAX explicitly.
HANDHELD keeps the complete voxel world, weather, clouds and real shadows, but
uses the existing half-size 3D target, low shadow quality and no AA.

The Gold/Silver/Crystal bridge never calls the synchronous current-map mesh
getter during rendering. It requests the playable map body at highest queue
priority and advances it within a per-profile frame budget; the native edition
frame remains visible and interactive until the body lands atomically. Door
warps announce their exact destination early enough to spend covered fade
frames on that body. Full border/apron and neighbouring maps continue at lower
priority, never across edition or map-state ownership boundaries.

The real Gold acceptance fixture used three cold maps for 240 frames each. The
baseline worst draw was 7368.67 ms on Route 29, 314.02 ms in Cherrygrove City
and 4445.00 ms in Ilex Forest. The final candidate measured 226.27, 162.11 and
597.07 ms respectively; every body completed and the steady Ilex p95 was
14.50 ms. Silver uses this identical GS bridge. Crystal shares the same
edition-neutral queue/profile modules but still requires its full ROM matrix.

## Migration and rollback

On first Gen2 launch, known schema keys from the old `VASC4J` option bucket are
copied into `VOXEL_ASCENDANT` and marked migrated. The original `VASC4J` bucket
is never deleted or rewritten, preserving rollback. The retired `customUI`
switch cannot install its old controller. The current `qol_ui_skin` row owns
only the live `ORAS GLASS`/`GAME DEFAULT` drawing choice described above.

The manifest declares the retired standalone package as a compatibility
replacement rather than a hard conflict. When an existing installation still
has both entries enabled, Gen1Recomp keeps `VOXEL_ASCENDANT`, marks `VASC4J`
as replaced and never executes the duplicate renderer. This is intentionally
one-way: trying to re-enable the retired package beside its replacement remains
blocked, so two camera/world owners can never run in one process.

## Source and legal boundary

The Gen2 code and assets were imported from frozen VASC4J commit
`d0b73c16a5424aa995fe209985bf5f25423cc7c3` (tree
`1316f8f97ad8c2066f7255ffa4ef8226472ad75a`). Required upstream notices are
shipped below `gen2/`. No ROM, ROM-derived model pack, `.dsm`, cache, OpenXR
DLL or personal user media is included. Immutable upstream sprite sheets used
by the Gen-2 runtime live below package-owned `assets/vasc_runtime/`; the
engine/player-reserved `assets/generated/` and `data/generated/` namespaces are
never shipped or read by VASC.

See [GEN2_ROM_QA.md](GEN2_ROM_QA.md) for the remaining hardware/ROM matrix.

`GEN2_SOURCE_RECEIPT.json` hashes the packaged `main_gen1.lua` bytes. Its
current digest is an integration-base placeholder: the RC maintainer must
refresh it after the final camera/version cherry-picks. The contract test
deliberately fails if source and receipt diverge.
