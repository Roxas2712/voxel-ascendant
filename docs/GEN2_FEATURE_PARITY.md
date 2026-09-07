# VASC Gen-2 feature parity audit

This audit records what the generation dispatcher actually installs for
Pokemon Gold, Silver and Crystal. A file merely present below `gen2/` does not
count as an implemented feature; an active install hook or exported runtime
receipt is required.

Audit checkpoint: 30 August 2026, pre-documentation VASC source commit
`af5dfae88b7c24e121c5de82c9f680a3ae5cf133`, tree
`a50982470ec4170449b63e7005b092a2cc2c4bd0`. The user-supplied A3 functional
delta is accounted for in the
[RC11 A3 import audit](maintainer/A3_IMPORT_AUDIT.md). All rows below are
source/headless statements unless they explicitly cite native ROM/GPU proof;
they do not label this working tree a candidate or release.

Status meanings:

- **Implemented**: loaded by `gen2/main.lua` or its installed bridge and covered
  by a runtime/contract test.
- **Missing**: available in the current Gen-1 VASC runtime but without an
  equivalent reviewed Gen-2 owner.
- **Not applicable**: cartridge- or KASC-specific behavior that must not be
  copied into Johto VASC.
- **QA pending**: code and hook exist, but release-quality real-cartridge visual
  proof is still required.

| VASC capability | Gold | Silver | Crystal | Gen-2 owner / note |
| --- | --- | --- | --- | --- |
| Generation dispatcher and fail-closed boot | Implemented | Implemented | Implemented | `main.lua` recognizes all three public cartridge ids and roots gameplay code below `gen2/`. |
| Voxel terrain and connected-map renderer | Implemented | Implemented | Implemented | `GoldVoxelBridge`, `GoldPipelineBridge`, `GoldComposeBridge`. |
| Consecutive map/cache ownership | QA pending | QA pending | QA pending | The A3 cache/map recovery is integrated below `gen2/` at `780e7ff` and covered by focused headless ownership tests. Two real consecutive transitions in each Gold, Silver and Crystal ROM remain required before this can be called visually accepted. |
| FULL/15/35/50/75/first/third-person camera ladder | Implemented | Implemented | Implemented | `GoldCameraControls`, `VascRendererOptions`; seven-value schema contract. |
| Open-world connected graph and extended zoom | Implemented | Implemented | Implemented | `GoldVoxelBridge`, `OpenWorldZoom`. |
| Grid, curve, water, shadows, AA and device profiles | Implemented | Implemented | Implemented | Gen-2 option schema plus renderer-option bridge. |
| Day/night, weather, clouds, sky events and scenery | Implemented | Implemented | Implemented | `VascEnvironment` installs the current public services on the Gen-2 renderer. |
| Local music, sprites and content profiles | Implemented | Implemented | Implemented | Public `LocalMusic`, `LocalSprites`, `LocalContent` modules from the Gen-2 environment receipt. |
| Visible wild Pokemon and party followers | Implemented | Implemented | Implemented | Embedded Gen-2 Wilds runtime plus `GoldWildsBridge` and single-owner follower bridge. |
| Stadium 2 local model import, Pokemon/player models | Implemented | Implemented | Implemented | `StadiumRomMenu`, `VoxelScenePatch`, locally generated model pack; no ROM ships. |
| Four battle architectures: MAP / ARENA / DISCS / GAME DEFAULT | Implemented | Implemented | Implemented | `OverworldBattle` latches one architecture per encounter: MAP keeps the frozen encounter world, ARENA resolves `BattleArena`, DISCS resolves `StadiumStage`, and GAME DEFAULT leaves the complete cartridge scene including its back sprite untouched. Effects, HUD choice and SMART CAMERA remain separate latched presentation contracts. The A3 parity port is headless only; package-bound camera/GPU capture and the reported Gen-2 player/HUD placement remain release QA. |
| One public VOXEL ASCENDANT Start descriptor | Implemented | Implemented | Implemented | `VascMenuGen2` contributes exactly one `voxel_ascendant` descriptor at priority 900. A KASC-style collector may group it through the public hook; no private resolver is used. |
| Grouped VASC control centre | Implemented | Implemented | Implemented | Nine sections are populated directly from the complete live Gen-2 schema. Unknown future toggle/choice rows fail visibly into ADVANCED rather than disappearing. |
| Shared FireRed/LeafGreen Ascendant hub controller + style | Implemented | Implemented | Implemented | Gen 2 now consumes the exact root `VascMenu.lua` and `VascMenuStyle.lua`; its adapter supplies only Johto's live sections/settings. The retired Gen-2 controller and edition-palette copies are removed. |
| ORAS drawing for native menus/dialogue/lists | Implemented | Implemented | Implemented | Shared `OrasUiSkin` draw-only hook, default `ORAS GLASS`, live `GAME DEFAULT` fallback. Native input, pagination and callbacks remain untouched. |
| Edition-specific custom menu/HUD palettes | Not applicable | Not applicable | Not applicable | Active Johto palette selection is removed. The compatibility HUD theme resolves every edition to one shared ASC/ORAS receipt. |
| Draw-only ORAS battle HUD and Party/Summary presentation | Implemented | Implemented | Implemented | Independent ORAS GLASS/GAME DEFAULT choices. The A3 shared-party/UI path is integrated at `780e7ff`; the HUD owns drawing only in ordinary menu/move phases while native input, callbacks, intros, animations, prompts, learning/evolution, submenus and special battles remain complete fail-open paths. Real G/S/C layout, type-colour and interaction screenshots remain QA pending. |
| Gen-1 WORLD/SLICE/LOCAL/FLAT terrain-height modes | Missing | Missing | Missing | Gen-2 has its established mesh/shape height handling but no equivalent four-mode public contract yet. Requires Johto collision/map fixtures, not a UI-only copy. |
| Gen-1-authored arena/disk artwork and per-role layout editor | Missing | Missing | Missing | This row concerns the specific Kanto-painted backgrounds/disks and Gen-1 role editor, not battle architecture. Gen 2 already implements MAP/ARENA/DISCS/DEFAULT with Johto-owned stage resolvers; importing the Gen-1 art/editor would be a separate authored-content feature requiring Johto layout fixtures. |
| Kanto Safari rules/HUD and Legacy Bank | Not applicable | Not applicable | Not applicable | KASC/Gen-1 gameplay features; VASC must not synthesize them in Gold/Silver/Crystal. |
| Overworld capture minigame | QA pending | QA pending | QA pending | Source exists but `ENABLE_OVERWORLD_CAPTURE_RC=false` until real ROM QA. |
| Native VR binaries | Not applicable | Not applicable | Not applicable | Deliberately excluded from the release allowlist. |

## Ownership boundary

VASC owns rendering and its self-contained settings tree. The engine continues
to own Gen-2 menu input, callbacks, saves and battle rules; VASC's optional
ORAS HUD owns drawing only in its explicitly supported ordinary phases.
Optional KASC-style grouping is descriptor-based through
`ui.start_menu.items`; VASC imports no KASC module, option bucket or private
resolver. Unsupported phases and every renderer failure restore the complete
edition-native canvas rather than leaving a partially replaced battle.

## Deferred complete Johto update

The complete newer Johto KASC/VASC extension announced after this checkpoint
is not part of the current freeze. When supplied, it is to be reviewed as a
bound Gen-2 module update with its own source receipt, Gold/Silver/Crystal
contract matrix and native visual evidence. It is not a new base and must not
overwrite shared Gen-1, battle or UI owners. The existing segmentation is the
integration boundary for that later update, not evidence that the future
package has already been accepted.
