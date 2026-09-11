# Voxel Ascendant 3.0.22 — Item menus and widescreen Bag

Using a field item now keeps the selected VASC party presentation instead of falling back to the classic 2D team screen. Item and script target callbacks are no longer mistaken for battle ownership; battle party providers retain their own presentation.

Fresh Gen 1 profiles again default to D/P ORAS WIDE. Existing saved Bag choices are preserved. If your profile still uses GAME/KASC, select D/P ORAS WIDE under BAG MENU to use the wide layout.

Includes the battle HUD placement recovery from 3.0.21. Import the ZIP and fully restart the game. No save migration is required.

Validated with KASC 6.7.4 and engine 0.2.57 on Pokémon Yellow/macOS: normal and item party screens, default Bag, cancellation without consumption, Potion healing, six-Pokémon target navigation, and Antidote use; party/battle ownership, forced and voluntary switching, saved Bag choices, sorting and presentation regressions. The reporter's Windows installation has not been tested directly.

---

# Voxel Ascendant 3.0.20 — Battle textbox positioning

Added independent TEXTBOX X and TEXTBOX Y settings in Gen 1 battle settings and Gen 2 Skins & Overlays. Move the battle dialogue and its frame horizontally or vertically; negative Y moves up. The Yes/No prompt follows the textbox. Positions stay within the viewport.

Default positions are unchanged. RESET TEXTBOX TO DEFAULT resets only the textbox position; the separate button reset preserves it. Includes all 3.0.19 battle controls, transparency and earlier fixes.

Validated in native LÖVE with configuration, viewport bounds, independent reset, button input, Safari ownership and Gen 2 UI regressions. Physical phone/tablet playtesting remains outstanding.

---

# Voxel Ascendant 3.0.19 — Personal battle controls

Configure battle button size, horizontal position, lift and transparency (0–90%) in Gen 1 battle settings or Gen 2 Skins & Overlays. Existing Card positions and default artwork remain unchanged; Reset Buttons restores only the personal button settings.

Moved/scaled buttons use completed ORAS-style artwork, including Mega, with an optional GLASS style. The completed artwork reconstructs missing edges from the existing sprites. Gen 2 commands, attacks and Back now support direct pointer/touch input; Mega retains the existing eligibility and visibility rules.

Includes all 3.0.18 camera stabilization, 3.0.17 support-report and 3.0.16 gatehouse fixes. Validated with native LÖVE/LuaJIT, configuration/input/layout regression checks and rendered transparency comparisons. Physical phone/tablet playtesting remains outstanding.

---

# Voxel Ascendant 3.0.18

Fix repeated battle camera zoom jumps with animated Stadium 2 models on DISCS platforms. Changing idle poses could trigger a wider safety camera, then immediately restore the narrow camera. The camera now keeps the verified space needed by the actors while continuing to check the current model and HUD bounds.

The correction resets on screen rotation, manual camera control, a distance-setting change, or a new battle. Camera drift and saved zoom settings are preserved. Includes the support-report features from 3.0.17.

Validation: six camera/HUD regression tests passed. Native renderer checks with engine 0.2.57 covered Charmander versus Pidgey with Stadium 2 and Crystal sprites, and Weedle versus Weedle with Stadium 2, in portrait and landscape. Testing used macOS LÖVE with Android presentation settings; physical Android confirmation remains open.

Replace the existing Voxel Ascendant mod with the ZIP and fully restart the game. No save migration is required.

---

# Voxel Ascendant 3.0.16

Gen1 gatehouses now show doors at their mapped entrances. East/west passages have doors on both sides, including both separate passages on Route 16. South entrance doors are explicitly drawn so they cannot disappear behind the facade, fixing the closed-looking Route 12 entrance. North doors follow the actual entrance position and width, with corrected tile ordering.

Coverage: 26 entrances across the Kanto gatehouses (7 west, 7 east, 7 south and 5 north), including the Safari entrance and Route 2 forest access. Existing collision and map transitions are unchanged.

Validated with native Gen1 3D views of all 26 entrances, focused mapping tests and compilation of all 529 source Lua files (463 packaged runtime files). Testing used macOS LÖVE with a mobile profile, not a physical Android device.

Includes all Stadium2, HD people and Low Kick fixes from 3.0.15. Replace the existing Voxel Ascendant mod with the ZIP and fully restart the game. No save migration is required.

---

# Voxel Ascendant 3.0.15

Selecting Stadium2 now renders imported models for Gen1 wild, town, ambient and follower Pokémon independently of battle model settings. Static map Pokémon use their actual species, including all five living Fuchsia zoo Pokémon.

HD people now resolves 34 missing Youngster asset references. Seated people baked into the tileset also switch to HD in eleven Pokémon Centers and Celadon Hotel. Turning HD PEOPLE off restores their original graphics. OVERWORLD CARD must be enabled at startup; its help now explains the required reload after enabling it.

Retains the 3.0.14 Low Kick animation fix. Existing private Stadium2 imports remain required. No ROM/model payload is included and no save migration is needed.

Validation: all package Lua files compile; model selection/lifecycle/fallback tests, 80 HD setting combinations, 719 NPC catalog entries, seated-figure toggling and native Gen1 world tests passed. Native testing used macOS LÖVE with a mobile profile, not a physical Android device.

Install the ZIP as a replacement for the existing Voxel Ascendant mod and fully restart the game.

---

# Changelog

## 3.0.0-rc.11 — Unreleased working tree

- Split the RC11 runtime at explicit provider, preset, battle-background and
  battle-presentation boundaries while keeping RC10 as the immutable behavior
  reference. The bounded architecture gate now covers 31 headless contracts.
- Pair VASC with Content Selector 0.5.0. Its optional
  `vasc-battle-backgrounds/v1` contract imports hash-pinned 16:10 PNGs and
  selects them only for an explicitly matched Gen-1 or Gen-2 ARENA battle.
  Rules are always bound to generation, game and route/map; optional battle,
  trainer and wild/trainer qualifiers narrow them further.
- Pin the optional Kanto Ascendant 6.7.0 companion to source commit
  `1be9cc71c828926b8f175f3bd394f684ff614da6`, tree
  `d247ef1bbc6c87f8858cbe78e7827b85bd7f5d48` and deterministic package SHA-256
  `25f63bbd887329be99a1543ecd884d247814169617c8debcf6fb3c9ae077a513`.
  The additive companion handoff validates and honours an explicitly selected
  Mega X/Y form without importing unrelated Johto content. VASC binds these
  exact source and package receipts at commit `2fb3bdd`.
  KASC admits VASC RC11 explicitly and keeps RC12+ fail-closed.
- Port the complete functional delta from the user-supplied Gen-2 Parity A3
  QA bundle into RC11's segmented owners. The source audit found 4,712
  byte-identical production paths, 19 intentional architecture differences
  and no missing A3-only production path; the carried historical runtime
  receipt is deliberately not reused. A later complete Johto KASC/VASC import
  remains a bound Gen-2 module update, not part of this source freeze or a new
  base, and may not overwrite shared Gen-1, battle or UI owners.
- Harden battle-frame transitions so a replacement can retain only an exact,
  actor-free cover from the same deployment; a custom ARENA backdrop change
  discards the complete in-progress frame before retrying, and generic scene
  exceptions fail that encounter closed instead of publishing stale pixels.
  Harden the ORAS HUD independently so status seats, actor hulls and Mega FX
  are bound to the exact current battler, mon, viewport and render token.
  These changes have focused headless regression evidence only; native visual
  acceptance remains open.
- Enforce the KASC Mega presentation boundary: VASC no longer ticks KASC's
  animation, replaces `rearOverlayAllowed` or mutates foreign KASC options.
  The only retained integration is the public
  `qualityOfLife.battle:setHudOwnerPredicate` overlay-owner hook; unavailable
  or older companions fail open without cross-owner writes.
- Support fixed `add`/`replace` choices and deterministic per-rule pools. A
  selection is latched to one battle lifecycle, survives redraws and Pokémon
  switches, and is recalculated only for a later battle. MAP, DISCS and native
  DEFAULT/2D keep their prior background, camera, HUD and lifecycle owners.
- Keep the Injector fail-closed across Python and the native macOS importer:
  copy one descriptor-stable private input snapshot, accept only bounded
  STORE/DEFLATE members, and verify actual output size, exact compressed-byte
  consumption and CRC instead of trusting ZIP declarations. The native store
  no longer hands untrusted presets to `ditto`; a forged one-byte receipt with
  an 8-MiB DEFLATE stream is a permanent cross-implementation regression.
  Complete PNG validation, exact plan hashes, Unicode/case/path collision
  checks and identical null/omission semantics remain enforced.
  Native Windows/Linux artifacts remain a separate signed build receipt gate;
  this source entry does not claim a published RC11 package.

## 3.0.0-rc.10 — 2026-08-27

- Ship one RC bundle containing VASC and VASC Content Selector 0.4.0. The
  injector discovers VASC/VASC4J and adjacent KASC installs on macOS, Windows
  and Linux, indexes real sprite/music files, and creates named default,
  Gen-1, Gen-2 and per-game presets with inheritance and copy semantics.
- Include the Kanto Ascendant 6.5.20 compatibility update in the same delivery.
  Its launcher allowlist, classic conflict fence and runtime resolver admit
  VASC RC10 in both toggle directions; KASC 6.5.19 remains RC9-only.
- Add KASC's append-only `FIRERED / LEAFGREEN WIDE` PC and Legacy-Bank
  presentations. They author a native 512×288 surface with a 5×4 Box grid,
  2×3 Team rail, persistent detail/help panels, complete Change-Box and
  Player-PC overlays and remembered navigation; existing FireRed, Ascendant
  and Game Default values keep their exact keys and order.
- Expose the existing atomic Legacy-Bank transfer through VASC's ASC BOX host.
  SELECT marks several Pokémon across boxes, START transfers the stable
  selection or all eligible entries, and locked/full/save-failure paths retain
  an explained remainder or roll Box, Dex and leases back completely. KASC's
  fitted transfer now leases and releases the entire tranche with one archive
  write, saves the game once, and grants both seen and owned Pokédex state on
  classic single, FRLG/ASC-wide, marked-selection and ALL paths.
- Add the bounded active-pointer/manifest importer to both generations. VASC
  verifies canonical manifest hashes plus every asset size and SHA-256, and
  resolves a structurally valid but invalid CUSTOM generation through its
  declared `retro` or `vasc-default` base. RETRO then falls to VASC DEFAULT;
  explicit VASC DEFAULT terminates the chain, while a missing pointer preserves
  only the historical loose-folder CUSTOM migration. Legacy v1 pointer
  envelopes are normalized to their default-scope selection before the shared
  validator runs. The menu has direct content-source, preset/scope and
  restore-default controls.
- Preserve native 16-pixel billboard geometry while sampling complete HGSS
  32-pixel and explicitly dimensioned custom frames in Gen 1 and Gen 2. Cache
  keys include the complete frame contract and invalid indices use frame zero.
- Keep Surf riders directionally aligned in both generations and hold the
  trainer's standing Surf pose instead of advancing walking frames.
- Integrate Species Fishing Cinematic 0.1.0 for both generations as a strictly
  render-only owner. The existing directional artwork tree is reused without
  duplication; rod, line, bobber, rings, bite splash and pull-out follow the
  engine's single already-selected encounter, including Gen-2 Shiny state.
  Missing assets or renderer errors keep native timing, text and battle startup.
- Make SMART/STADIUM camera travel a one-time, monotonic safe route or a
  static hold; keep Mega presentation non-blocking and repeatable without
  freezing battle/HP logic; restore VASC `attack_default` when a Gen-2 clip is
  unavailable.
- Keep Gen-2 combatants, ORAS party/TM pickers and ASC BOX/PC surfaces under
  their reviewed presentation owners while preserving native game callbacks,
  storage and graphics state. The complete menu/surface matrix now has a pure
  headless acceptance runner.
- Make the executable Gen-2 scope explicit: the reviewed 0.1.90 fixture starts
  Gold and the shared generation bridge now latches MAP, ARENA, DISCS or GAME
  DEFAULT once per battle. The same code path is edition-neutral, but RC10 does
  not claim a packaged Crystal launch or GPU pass without a legitimate extracted
  Crystal root/cache; that external fixture remains a separate release gate.
- Latch MAP, ARENA, DISCS or native presentation once per Gen-1 battle. A
  Pokémon replacement publishes an actor-free frame in the same arena/camera/
  HUD transaction until the new actor is complete; an unavailable cover
  selects native once for that battle and can never jump back into Voxel.
  Native rear art stays on the live battler while world-front art is resolved
  through a private render-only battler, preventing ORAS/front art from
  leaking into the cartridge back slot.
- Restore the remaining ASC BOX 0.5.3 interaction contracts: exact cursor
  memory across Box changes, B from the Team rail returns to the Box, and a
  rejected move preserves its source/carry until a successful retry. Bounded
  localized host/code feedback explains rejected destinations.
- Harden named content presets before any registry write: validate every
  present default/generation/game scope atomically, accept SemVer build
  metadata, generate collision-free music IDs, roll back partial music
  registration and reject changed runtime bytes process-wide until restart.
  The native macOS store runs the same bounded cross-contract as Python.
- Add the optional ORAS FULLSCREEN glass presentation only to the VASC/KASC
  settings hub, with white bitmap text, a white outer boundary, the selected
  edition's inner accent frame, focused help and remembered section/item/scroll
  state; ordinary Bag, PC, Box and game menus keep their independent skins.
- Replace the temporary drawn Bag-pocket symbols in both ORAS Bag skins with
  exact Diamond/Pearl game-art tabs for Items, Medicine, Poké Balls, TMs/HMs,
  Battle Items and Key Items. Navigation and pocket memory remain native; the
  procedural symbols are retained only as a missing-asset fallback. This
  private candidate is not cleared for public redistribution.
- Add append-only `D/P ORAS WIDE` and `FRLG ORAS WIDE` Bag choices for Gen 1.
  Both are real 512×288 compositions with nine visible rows and permanent item
  help, not stretched 160×144 screens. Atlas/Canvas readiness is checked before
  wide geometry is advertised; a later draw failure atomically presents the
  complete captured provider at exact 2×. Gen 2 keeps its separate native
  `PackMenu`; RC10 does not claim these Gen-1 adapters there.
- Bind the outer RC bundle to an explicit KASC 6.5.20 source tree. Every
  companion payload byte is verified against that tree and recorded in a
  machine-readable provenance ledger; a self-consistent but foreign rehashed
  companion is rejected.
- Restore Canvas, shader, depth/cull, blend and color transactionally around
  Gen-1 and Gen-2 shadow passes. Gold deployment receipts now distinguish
  trainer, active Pokémon and sprite identity; native redraw errors balance
  leaked graphics pushes, while Stadium failures stay side- and battler-local.
- Restore the reviewed compact enemy-front anchor only for an explicitly
  selected Gen-1 `DEFAULT/OFF + STANDARD` cartridge battle. Player backs keep
  the ROM-authored `hlcoord 1,5` baseline, and DEFAULT+ORAS, MAP, ARENA, DISCS,
  trainer fronts and oversized custom sheets retain their own placement.
- Make all three ORAS status-anchor settings effective again. OUTSIDE and
  ABOVE use each exact rendered alpha hull, CORNERS stays screen-bound, and a
  deterministic safe-frame clamp prevents 4:3 MAP battles from failing to
  native solely because a status card began off screen. Camera preflight now
  treats an unsafe owner proposal as a definite rejected seat rather than an
  unknown provider result, and reserves the Safari counter together with the
  active flow surface before accepting a status layout.
- Apply the optional ORAS FULLSCREEN skin to KASC's exported Ascendant guided
  menus as well as VASC's own tree. KASC retains its controller, callbacks,
  focus and independent per-skin scroll memory; FireRed and ordinary Bag,
  Bank, question and game menus remain unchanged, including KASC's global
  help callback.
- Make both release builders fail closed before any build side effect when the
  target ZIP already exists. The combined RC builder also reserves its checksum
  path up front, and both ZIP/checksum writes use exclusive creation so a
  previously reviewed or rejected artifact cannot be silently replaced.
- Bind Content Selector 0.4.0 to a checked-in 34-file source ledger, including
  all 15 inputs of the native-platform builds. Native and portable injectors are
  built only from the verified immutable snapshot; foreign Python/Swift inputs,
  source drift, changed ZIP members and unpinned build-environment overrides
  fail before either the outer archive or its checksum is published.
- Require the Gen-1 visual gate to compare two otherwise identical final
  compositor frames with the production attack draw enabled and suppressed.
  The resulting pixels must be confined to the projected production trajectory
  corridor, carry significant opacity and produce different origin/travel,
  attack-only and final-frame SHA-256 values. Transparent, clipped, off-screen,
  static, overdrawn or wrongly projected attacks can no longer create a false
  visual PASS.
- Bundle the corrected KASC 6.5.20 Useful Bag runtime. Each field-Bag pocket
  resumes its stable item and scroll row across pocket changes and reopen,
  while battle Bags remain isolated. The outer builder now rejects a missing
  or source-divergent <code>useful_bag.lua</code> instead of accepting a green
  source fix that the Companion packer omitted.

## 3.0.0-rc.9 — 2026-08-26

- Preserve Voxel + ORAS ownership across consecutive Gen-1 encounters and
  ignore stale battle-end notifications. MAP battles without a reviewed arena
  now receive a safe portable Voxel stage instead of silently reverting to
  the cartridge presentation.
- Restore KASC's Mega transformation capsule on the private battle layer and
  keep ASCENDANT-menu ownership separate from Bag instances.
- Make SMART / STADIUM the clearly labelled default battle camera while
  retaining STATISCH 3X. Automatic paths are selected once, require complete
  physical and HUD clearance, obey comfort pitch/speed limits and otherwise
  latch the best static seat for that fight.
- Restore Crystal's sharp authored combatants inside the Gen-2 ORAS scene,
  keep Wild, Fishing and Trainer fights on the same owner, and expose the
  working ORAS party selector. Optional Stadium models suppress a Crystal
  sprite only after an explicit scene-drawn receipt.
- Fix FIELD KIT Surf callback ownership and retain the exact rider/mount card
  while zooming a selected 3RD camera. Gen-2 Fly now presents its rider at the
  same 16-pixel world height as surrounding NPCs.
- Add render-only LOCAL ramps at proven walkable, non-water map connections;
  connected roads and NPC stand tiles keep one visual datum while collision,
  warps, WORLD and FLAT remain unchanged.
- Restore ASC BOX header paging, readable Johto type badges and one consistent
  KASC Crystal/Shiny sprite source across Box, detail and mini-Team.

## 3.0.0-rc.8 — 2026-08-26

- Keep the exact VASC/ORAS battle owner through ordinary Gen-1 and Gen-2
  introductions, messages, send-out/switch, attacks and HP animation. Gen 2
  binds its scene-HUD receipt to the current BattleState and rendered canvas,
  so neither a stale following encounter nor Gold/Silver/Crystal's complete
  160x144 cartridge canvas can flash over a valid voxel fight.
- Guarantee progressive residency for every real directly connected Gen-2
  map. A temporarily unavailable neighbour remains queued for a later frame,
  siblings still progress fairly, and the adapter budget remains capped at
  one attempt per presented frame.
- Keep Gen-2 Surf, Fly and Field-Kit Jetski on the exact native caller captured
  for that successful move. Third person no longer substitutes a generic
  BIRD/MONSTER actor, and Jetski supplies down/up/left/right presentation.
- Restore the reviewed ASC BOX header navigation and readable detail/footer
  ink. Preserve Gen-2 dual types, DV-derived Shiny state and the host's actual
  palette through the public UI snapshot so grid, detail and mini-team agree.
- Replace the Bag pocket text glyphs with small pocket-specific pixel images
  while retaining the real Poké Ball selection cursor and independent edition
  body/accent controls.

## 3.0.0-rc.7 — 2026-08-26

- Keep VASC's ORAS battle owner latched through transient Gen-1 message,
  attack, switch and animation phases, preventing native 2D/cardridge frames
  from flashing through. Restore the KASC Mega egg presentation through the
  same observed form-change path.
- Restore the reviewed ASC BOX 0.5.3 geometry, colors, team rail and provider
  ownership while keeping every storage write and transfer with the PC or
  Legacy host. Retire the accidental direct START-menu storage row.
- Fix the Crystal aggressive-wild crash by supplying the engine countdown
  field alongside VASC's authored emote duration.
- Replace Gen-2's synchronous connected-map first frame with an atomic
  current-map BODY, then admit at most one complete neighbour per frame. BODY
  no longer analyses the synthetic outer tree ring, and FULL waits for direct
  seam masks, preventing cold-start tree fragments and long blank frames.
- Add draw-only Gold/Silver/Crystal Fly, species-Surf and Field-Kit Jetski
  presentation with all four Surf directions. Native move rules, saves,
  callbacks and warps remain authoritative and every missing receipt or asset
  fails open to the game.
- Keep the Gen-2 ORAS battle/party presentation latched across ordinary battle
  text and animation phases, while special workflows continue to fail open.
- Remove the retired VASC4J runtime facade and user label from the unified
  package while retaining explicit migration/conflict provenance.
- Remove SLICE from the selectable height ladder and migrate saved SLICE to
  LOCAL. LOCAL Viridian uses one coherent raised visual datum without changing
  collision, doors, warps or map data.
- Add the desktop `V` alias to the complete Gen-2 voxel-camera ladder and an
  optional ORAS-style upper-left shortcut notice for successful camera, zoom,
  color and Gen-2 game-speed changes.
- Give both explicit VASC Bag skins sharp pocket-specific glyphs and a
  Pokéball row cursor. Keep the pocket/selection accent independent from a new
  masked `TASCHENKÖRPER` edition palette (AUTO, ORAS, Red, Blue, Yellow, Gold,
  Silver or Crystal); GAME/KASC remains an untouched draw owner.

## 3.0.0-rc.6 — 2026-08-26

- Remove the accidental root `BOXEN`/`STORAGE` shortcut. PC and Legacy Bank
  remain the only storage entrances and retain all host-owned save, transfer,
  capacity and Pokédex behavior.
- Add independent Gen-1 `START TEAM UI` and `BATTLE TEAM UI` controls under
  the new `SKINS & OVERLAYS` page. Both expose exactly ASC BOX, ORAS GLASS and
  GAME DEFAULT; normal Start-party ASC BOX ports the reviewed 0.5.3 party,
  summary and modal presentation without replacing native actions or field
  moves. Gen 2 receives its own draw-only ORAS Party/Summary adapter with a
  separate GAME DEFAULT fallback; native callbacks and field moves remain
  authoritative.
- Install integrated Fly and Surf before the engine's content-registry freeze,
  preventing a partial late install that could hold the native animation with
  no carrier Pokémon visible.
- Rasterize rounded ORAS menu outlines pixel-exactly and restore the previous
  line style, eliminating the one-pixel stale vertical edge beside dynamically
  widened KASC/VASC Start menus.
- Keep the last fully committed Voxel/ORAS battle frame across a transient
  no-shot update only while both exact actor receipts still match. This stops
  direct WILDS encounters flashing between Voxel and native 2D without ever
  retaining a stale Pokémon across a switch or renderer failure.

## 3.0.0-rc.5 — 2026-08-26

- Integrate selectable **D/P ORAS** and **FRLG ORAS** draw-only Bag styles
  into VASC. **GAME/KASC** is the safe default: it leaves the exact native,
  Useful Bag or KASC renderer unwrapped. Only an explicit VASC choice replaces
  drawing on a newly opened Bag; update, input, items, pockets, sorting,
  actions, battle rules, saves and provider callbacks remain owner-controlled.
- Add independent **TASCHEN-AKZENT** and **TASCHENFORM** controls. AUTO reads
  only KASC's public RED/BLUE/GREEN character receipt and otherwise uses the
  standalone red round form. Runtime option changes and all asset/render
  failures return immediately to the captured provider draw.
- Add the deterministic 576×128 Diamond/Pearl sixteen-crop atlas and separate
  320×128 FireRed/LeafGreen ten-crop Bag/Pouch/Case atlas with pinned PNG/RGBA
  hashes, source recipes and focused ownership/render tests.
- This is a private test candidate. The Pokémon game-art atlases are not
  covered by VASC's MIT licenses and must not be publicly released until their
  redistribution status is cleared.
- Integrate VASC Species Fly Cinematic 0.4.3 and Surf Cinematic 0.3.1 as
  internal Gen-1 modules and assets in the single `VOXEL_ASCENDANT` package.
  The selected normal/Shiny species through Hoenn plus Gorochu retains its
  mount/tow/board/balloon presentation; KASC Field Kit uses the active trainer
  with the jet ski/jetpack path through its public `fieldTech` service.
- Deduplicate the two sources' 774 byte-identical directional atlases and
  reuse 502 byte-identical RC4 world carriers. Preserve both input packages'
  exact provenance, notices and credits in the release.
- Keep native Surf/Fly as the fail-open owner after missing/corrupt assets,
  canvas/GPU errors, a retired voxel pipeline or unsupported species. Surf
  failure cannot retire Fly or write the saved VOXEL level.
- Remove VASC's legacy SELECT camera hook centrally. SELECT now remains with
  the game/KASC Quick Select and Field Kit; `3`, `V`, `ZR/R2/RT` and the
  options retain VASC camera control.
- Replace and conflict with the retired standalone Fly/Surf IDs, with a second
  runtime guard against duplicate wrappers on older launchers.
- Integrate the reviewed Kanto Fly Map 1.6.3 runtime and its three map assets
  under VASC's public owner receipt. The native Town Map still supplies
  visited destinations and Fly eligibility; unsupported states fail open to
  the game, and the retired standalone map is replaced instead of double
  hooking the menu.

## 3.0.0-rc.4 — 2026-08-26

- Integrate the final standalone ASC BOX 0.5.3 presentation through Host
  Contract v1 as VASC's default PC and battle-party UI, with a direct Start
  entrance, spatial Box↔Team carry/swap, dense-save visual-seat metadata,
  promptless Box paging, carried Pokédex targets, neutral private Eggs and
  live external KASC PC/Legacy ownership. Every storage mutation remains one
  authoritative host commit and follows ordinary later save persistence.
- Negotiate each Pokemon-UI canvas through a provider-neutral logical
  viewport, normalize exclusive controller input to one bounded `pressed`
  envelope and route Legacy Party focus through the host's atomic `deposit`
  action. External PC/Legacy hosts therefore render ASC BOX without clipping,
  raw engine input or provider-ID size coupling.
- Register the existing ORAS GLASS look as an independent, real
  battle-party-only Host-v1 provider; it never creates dead PC/Legacy rows or
  changes the separately selected ORAS battle HUD.
- Make Gen-2 AUTO a smooth default: balanced/high devices resolve to the
  existing HANDHELD profile and low devices to ECO, while PC/MAX remains
  explicitly selectable. HANDHELD keeps the full voxel/weather/sky feature
  set at half-size, low shadows and no expensive AA.
- Remove the synchronous Gold/Silver/Crystal current-map mesh gate. Cold map
  bodies now build in bounded frame slices behind the native 2D fallback,
  prewarm during covered warp frames and outrank stale apron jobs; retained
  grass/figure uploads use the same cooperative budget. A real Gold run cut
  Route 29's worst cold draw from 7368.67 to 226.27 ms and Ilex Forest from
  4445.00 to 597.07 ms without changing map, collision or warp data.
- Bound the built-in ORAS battle-HUD transaction to versioned damage
  rectangles while retaining the full-canvas fail-open path for external,
  malformed and iOS providers. Real 3420x2214 OAKS_LAB testing improved VASC
  from 85.42 to 103.82 FPS and VASC+KASC from 83.78 to 106.34 FPS without an
  Overworld or resolution regression.
- Replace the provider-only Pokémon-screen seam with Host Contract v1. PC,
  Legacy Bank and battle-party skins are now selectable only at a live
  Provider×Host capability intersection; opaque host handles, immutable
  versioned models/results/events, exclusive input, atomic drawing and
  terminal dispatch revocation prevent partial or stale menu ownership. ORAS
  battle-HUD selection remains independent from the battle-party skin.
- Derive each ORAS status card from the exact rendered alpha-ink head on the
  first valid frame of that Pokémon's deployment, then freeze its complete
  screen-space rectangle. A real switch relatches only the changed side;
  animation frames, camera travel and actor crossings never reproject, sort or
  rebind either card.
- Let the roomy STADIUM director consume provider-neutral HUD safe rectangles,
  preserve manual steering as the resumed automatic basis and choose a static
  seat only when world/HUD clearance genuinely cannot be proven.
- Keep player/enemy status payloads bound by semantic battle side while the
  camera rejects any path that cannot preserve their owner-relative clearance.
- Keep uploaded battle arenas inside global safe space, retry transient arena
  startup, align Lorelei's arena axis, restore Silph recovery beds and remove
  leftover native/KASC overlays from Safari ORAS battles.
- Keep every VASC settings page opaque and wide with a permanent contextual
  help strip, no vertical shadow/stale dialogue fragment, and publish complete
  visible scene plans. Clamp reported Route 1, Vermilion and Mt. Moon battle
  anchors against world bounds and occluding geometry.
- Render Route 1's physically framed jump-ledge garden as one raised local
  SLICE terrace with a watertight front. Jump gaps remain ledges, the broad
  rear passage stays walkable and the height never reaches water, Route 5,
  Cycling Road or a map seam.

- Keep one shared ORAS surface language while adding a one-pixel public
  edition accent for Red, Blue, Yellow, Gold, Silver and Crystal. The same
  generation-neutral resolver now frames the VASC/START menus and permanent
  help strip, native dialogue/choice boxes and ORAS battle cards without
  restoring the retired Gen-2 palettes.
- Reuse the exact root VASC menu controller and FireRed/LeafGreen Ascendant
  renderer for the grouped Gold/Silver/Crystal Voxel Ascendant hub. The Gen-2
  adapter now supplies only Johto's live sections/settings; the divergent old
  controller and edition-palette copies are removed.
- Install the shared draw-only ORAS skin for native Gen-2 dialogue, choices,
  START and ordinary lists. `GAME DEFAULT` restores the original edition draw
  methods live; input, callbacks, saves and game rules remain engine-owned.
- Add a draw-only Gen-2 ORAS battle HUD for the ordinary command and move
  phases plus independent START/BATTLE Party choices. The historical input
  wrapper remains inactive; intros, animations, prompts, submenus and special
  battles use the complete native canvas, as does every renderer failure.
- Record the installed/missing/not-applicable Gen-1-to-Gen-2 feature matrix in
  `docs/GEN2_FEATURE_PARITY.md` rather than treating source presence as proof.

## 3.0.0-rc.3 — 2026-08-25

- Give every VASC control-centre page the same permanent, cursor-sensitive
  help strip as the current KASC route while retaining standalone ownership.
- Disable the hard sun/world shadow map under rain, storm, fog and snow; clear
  and heat retain the established world-shadow presentation.
- Rebuild HEIGHTS=SLICE around a collision-proven, locally enclosed walkable
  stair opening. Only its bounded upper component and physical frame rise;
  water, jump ledges, cycling-road rails, map seams and unrelated towns stay
  flat, while WORLD, LOCAL and FLAT remain unchanged.
- Keep the public frame-local HUD receipt as the only KASC/VASC overlay
  handoff; VASC remains autonomous and owns the complete ORAS presentation.

## 3.0.0-rc.2 — 2026-08-25

- Make VASC the explicit sole owner of the voxel battle camera. Narrow or
  obstructed physical arenas now select the best clear two-combatant seat once
  and hold it statically; roomy arenas retain the STADIUM director and saved
  optical zoom.
- Preserve the public KASC trainer-asset boundary without importing any KASC
  camera module or option.

## 3.0.0-rc.1 — 2026-08-25

- Ship one generation-dispatching package for Red/Blue/Yellow and
  Gold/Silver/Crystal. Gen1 uses the reviewed VASC 3.0 runtime; Gen2 is isolated
  below `gen2/`, retains native standard UI ownership and fails closed when its
  voxel composite is unavailable.
- Replace competing sprite-pack, custom-sprite and custom-music source switches
  with one persisted `CONTENT PROFILE`: `KASC`, `VASC DEFAULT`, `RETRO` or
  `CUSTOM`. KASC/Retro require complete public receipts; provider absence,
  errors and collisions deterministically fall back without private discovery.
- Keep the selector's direct preset reader closed until the engine supplies
  bounded read/hash APIs. Existing materialized CUSTOM folders remain fully
  supported and VASC itself contains no executable selector dependency.
- Validate the public KASC 6.5.17 HD-trainer contract at its sole public
  `OverworldBattle.sideTexture` boundary while preserving VASC autonomy.
- Carry forward the complete 2.0.12 mobile HUD, arena/disk, saved battle layout,
  canonical weather/sky, shadows, animation, scenery and terrain-height work.

## 2.0.12 — 2026-08-24

- Add `BATTLE -> BATTLE LAYOUT`, a saved VASC runtime controller with separate
  X/Y and 50–200% size corrections for player front/back/retro-back, Mega,
  enemy Pokémon, player/enemy trainers and each VASC fallback-HUD zone. Neutral
  values preserve the reviewed automatic anchors; per-role and full reset are
  available in English and German, with no KASC file or option writes.

- Replace the MAP/ARENA STADIUM camera's small sinus drift with a deterministic cinematic
  director: trainer/wild opening focus, alternating opponent/player portraits,
  shoulder views, move launch/impact cuts and one slow forward 360-degree orbit
  per cycle. STADIUM runs on MAP as well as ARENA, prefers the real Voxel-map arena, searches closer or
  higher camera lanes when terrain hides its subject, and retains the authored
  ARENA painting only as a safe fallback where no physical stage fits.
- Add a comfort pass to STADIUM: portrait/overview holds, four segmented orbit
  legs with still rests, a 24-degree-per-second yaw ceiling, and whole-path
  camera-body checks against terrain plus collision-backed trees, walls and
  houses. Unsafe travel reframes, freezes at the last safe seat or cuts; it
  never interpolates through the obstruction.
- Add the saved **HEIGHTS** control: WORLD carries only proven, bounded ledge
  terraces through direct map seams, raises their nearest rock/poller frames
  and permits the terrain to fall again beyond that enclosure; SLICE raises
  only a local contour with an evidenced walkable stair opening and never
  crosses a map seam; LOCAL restores the prior per-map treatment and FLAT
  keeps native steps without terrain lift.
  This explicitly keeps most of Cerulean and unrelated roads level.
- Render a one- or two-cell walkable opening inside one proven plateau contour
  as a short diagonal approach, with watertight triangular rock-side closure.
  Ordinary cliffs, collision, ledge jumps and raw map data remain unchanged.
- Recompose portrait MAP/DISCS cameras around the battle midpoint instead of
  exposing a large empty sky cap. The world keeps its aspect ratio, both
  combatants remain visible, and authored ARENA cover/crop stays untouched.
- Give portrait AUTO HUD a strict top/action/player/bottom hierarchy at crisp
  native scale: enemy status/team receipt at the safe top, player status/team
  receipt above one continuous bottom text/command frame. Landscape remains
  compact and no status layer overlaps the command window.
- Add a responsive ORAS battle-HUD choice for VASC standalone, including
  localized proportional controls, larger status/EXP/team receipts and
  Crystal-icon fallback. VASC deliberately supplies no Mega button or Mega
  activation. When KASC is present, its exclusive provider and QoL options
  replace both VASC's ORAS selector and the older readable-HUD controls.
- Keep **TRAINER BACK** as real Red/Blue/Green/native rear art but stage it on
  the player ground mark instead of enlarging it in the fixed Game Boy slot;
  this prevents the back card from covering the rival in ARENA and narrow
  mobile compositions. **PKMN BACK** retains its independent classic slot.

- Replace the flat VASC hub with the stable eight-section START subtree:
  `VIEW + WORLD`, `WEATHER + SCENERY`, `BATTLE`, `POKéMON + MODELS`,
  `WILDS + FOLLOWERS`, `PERFORMANCE`, `USER CONTENT`, `ADVANCED`.
- Keep that complete tree VASC-owned and standalone; KASC integration moves
  only its public descriptor into KASC and opens the same VASC screen.
- Add English/German category and row-level START/SELECT help, plus expanded
  installed custom-sprite documentation for front/back art, Red/Blue/Green,
  trainers, Megas, ground anchors, mobile rotation and battle-stage acceptance.

- Make the integrated Weather/Sky/Sky Events/Weather Footsteps pipeline the
  canonical VASC weather path for both direct choices and resolved AUTO or
  optional-provider state.
- Restore rare deterministic foreground rain windows with a few soft adhered
  beads and short vertical trails. Closed windows draw none; outdoor battles
  use a reduced count.
- Add eight static wet-grey RAIN clouds and twelve darker, denser STORM clouds.
  Their map-fixed world addresses cannot read clock, camera, player or event
  occurrence, and the complete ambient weather budget remains bounded.
- Restrict ordinary world shadows to outdoor CLEAR+DAY and synchronize cloud,
  bird and legendary shadows with their visible sky sprites. Lugia remains a
  RAIN/STORM event and Ho-Oh a HEAT event in deterministic 2/3-spaced windows.
- Ship Lugia's fourteen hash-recorded Crystal frames with their exact 3740-ms
  timing while retaining VASC as a standalone package with no KASC code or
  hard dependency.

## 2.0.9 — 2026-08-24

- Remove the rainbow's remaining screen-space vertical placement. Bearing and
  elevation now pass through exactly the same world-sky projector as clouds,
  so 3RD/1ST cannot carry it as a camera-layer element.
- Give the rainbow a map-stable bearing with no clock, drift speed or ambient
  event occurrence. It behaves like a static sky motif rather than one of the
  wandering cloud layers.

## 2.0.8 — 2026-08-24

- Anchor the rainbow horizontally to a fixed world-sky bearing instead of the
  viewport. Turning 1ST/3RD now moves it across the view or out of sight, while
  its separately fixed vertical composition prevents camera-pitch bobbing.
- Add short deterministic leaf gusts to storms. Sparse olive and autumn leaves
  cross overworld and battle views during only part of each weather cycle;
  ordinary rain and the majority of every storm interval remain leaf-free.

## 2.0.7 — 2026-08-24

- Pair every location-approved FRLG-like disk with a pale procedural
  material tint behind the stage. No full-frame disk-background bitmap is
  loaded; VASC-only and unsupported-map fallbacks retain the established
  sky/void.
- Decouple the rainbow's vertical placement from the live terrain horizon.
  Player motion and camera-mode horizon changes can no longer move or resize
  the bow; only the terrain composite clips its oversized lower legs.
- Add ten low-elevation, slowly drifting cloud-bank candidates during clear
  daylight. They are world-sky directions rather than player-local objects,
  reuse the existing prewarmed atlas and disappear at night or in other weather.

## 2.0.6 — 2026-08-24

- Replace the visibly pixel-stepped rainbow with a new 1024x512 transparent,
  antialiased arc and opt only that soft-gradient asset into linear sampling.
- Keep the large rainbow statically centred in the sky at its natural round
  2:1 proportions. On shallow horizons its complete legs continue behind the
  terrain instead of flattening the bow or leaving its ends in mid-air.

## 2.0.5 — 2026-08-24

- Add a saved `DISK ART` row that appears only while `3D-BTL` is set to
  `DISCS`. Compact `V+FRLG`, `VASC` and `FRLG` labels select a stable
  once-per-fight mix, the historical neutral VASC platforms, or generated
  FRLG-like terrain disks.
- Ship ten original 128x128 disk families derived from the map's existing
  location profile: building, grass, water, cave, pond, ice, sand, indoor,
  long grass/forest and mountain. Exact Seafoam, Victory Road and League
  receipts narrow broad cave/interior profiles; unsupported expansion maps
  fail closed to the neutral VASC disk.
- Keep `ARENA BG` and all authored Arena Scenery behavior independent and
  unchanged.
- Expand the post-rain rainbow beyond the viewport, flatten it to the live sky
  wedge and anchor the authored visible leg pixels just behind the terrain
  horizon, so the arc reads as a landscape-spanning bow instead of floating.
- Replace the nearly invisible corner flare rings with four map-seeded,
  slowly drifting kaleidoscope clusters. Fifty-six mirrored additive prism
  shards visibly split the rainbow light across the world while the later HUD
  composite remains unaffected.

## 2.0.4 — 2026-08-23

- Replace AUTO's short map hash with a saved seasonal weather director: long
  stable spells, a fresh weighted hand after map/interior exits, one rare
  storm bucket in 64, and distinct HEAT/SNOW seasons with normal weather
  between them. All effects plus RAINBOW remain direct test choices.
- Guarantee a world-anchored rainbow after rain or storms clear and add sparse
  upper-corner light glints that avoid the playfield and HUD.
- Encode real ground/roof/tree-crown geometry into terrain vertices instead
  of guessing upper surfaces from face brightness. Snow and wetness therefore
  cannot tint Pokemon Center or house walls, even when a facade and roof share
  a shade.
- Add quiet procedurally synthesized snow-crunch footsteps and rain/storm
  splashes on completed walking cells. They follow SFX volume and skip bike
  and Surf movement; no audio file is bundled.

## 2.0.3 — 2026-08-23

- Add the saved `ARENA BG` selector with compact `V+FRLG`, `VASC` and `FRLG`
  menu labels for the full mixed/VASC-only/FRLG-like-only choices. The mixed
  mode makes one stable shuffled choice
  per fight and only on maps with a geographically reviewed counterpart;
  unsupported maps retain their existing VASC master in all three modes.
- Ship the original VASC and new FRLG-like masters together for all 13
  paired profiles, preserving live sky/time-of-day behaviour only for the
  reviewed outdoor Forest and Safari scenery and reviewed Mansion windows.

## 2.0.2 — 2026-08-23

- Replace 13 generic ARENA paintings with new FireRed/LeafGreen-area-preview-
  guided GBA pixel-art profiles. Viridian Forest and Safari alone expose the
  existing live sky; eleven cave/building profiles remain opaque, while the
  Mansion keeps only its already-reviewed clock-aware physical windows.
- Replace VASC's custom dark hub with the same native `ListMenu` component
  used by Kanto Ascendant, restoring its exact readable type, cursor, spacing
  and white menu treatment.
- Add saved HUD position, size and glass-alpha controls. AUTO uses KASC's wide
  edge layout in landscape and a top/bottom composition on portrait iPhone and
  Android screens; FRAME retains the original centered battle UI.
- Preserve ARENA artwork aspect ratio across phone rotation with centered
  cover/crop presentation instead of independently squeezing both axes.
- Allow Q/E, wheel and pinch zoom in authored ARENA fights while keeping their
  reviewed 3X opening, locked orbit/pitch and optional Stadium director.
- Replace striped block weather with varied three-depth rain, sparse splash
  rings, layered drifting snow and soft fog wisps in overworld and battles.
- Import the project-supplied VASC battle-animation library as 230 executable
  programs backed by 92 hash-recorded effect sheets. Gen 1 move programs are
  always available; post-Gen-1 programs and the six reviewed substitute
  programs activate only while KASC is active. Player attacks originate at
  the player's Pokémon and enemy attacks keep the reverse focus direction.
- Keep KASC's animated Mega controller alive after hot reloads without
  replacing KASC's sprite selection or animation setting.
- Keep both teams' remaining-Pokémon rows visible throughout battle while
  preserving VASC's original red/grey Poké Ball artwork and diagonal fainted
  slash; only the KASC/mobile palette contamination is removed.

## 2.0.1 — 2026-08-23

- Replace the broken one-pixel ARENA night marker with a cratered moon and a
  varied, deterministic star field; remove black/coloured skyline matte
  remnants and keep transparent outdoor scenery tied to the live sky.
- Make reviewed interior windows follow the same smooth
  dawn/day/dusk/night cycle while opaque rooms and greenhouse glazing retain
  their authored materials.
- Correct iOS ARENA canvas presentation, Mega/form sprite facing, grounding
  and size, large-sprite separation, oversized city shadows and overly heavy
  rain/fog presentation.
- Add a standalone VASC settings layout with START help and retain the public
  Kanto Ascendant menu integration when KASC is installed.
- Add grouped local user folders for battle, world, result and scene music,
  with per-category ORIGINAL/SHUFFLE/file selection and exact replacement of
  any resolved Game/KASC song ID.
- Add opt-in local PNG replacement for Pokemon forms/front/back/Dex/icons,
  player art, enemy trainers and registered overworld sheets, including KASC
  Mega and bicycle states. GAME/KASC is the protected default; per-section and
  global reset actions bypass every VASC replacement. Ship detailed English
  and German folder guides with platform-specific install paths. No third-party
  music or sprite is bundled.
- Keep the dynamic reveal gate, destination-specific Fly recovery, reviewed
  ARENA anchors and the Route 8 build-budget optimization intact.
- Add a fail-open KASC 6.7 Cinnabar story panorama contract: once the complete
  reciprocal south-channel topology exists, a compact volcano appears left of
  Birth Island on the approach horizon. Older/partial maps remain byte-for-byte
  on the established coast; VASC never owns the quest gate, rocks or scientists.

## 2.0.0 — 2026-08-22

- Add the reviewed ARENA battle presentation: 46 independent location masters
  cover 110 anchors across 95 maps, with fixed 3X footing, original HUD
  placement and an optional authored STADIUM director.
- Add continuous AUTO dawn/day/dusk/night lighting to the overworld, live sky,
  outdoor arenas and only the reviewed exterior-window regions of interiors.
- Add location-aware battle anchor selection for trainer, rival, Gym, League,
  cave, ship and special-room fights without changing MAP, DISCS or classic
  battle placement.
- Add persistent AUTO/PC/MAX/HANDHELD/ECO/CUSTOM device profiles, dedicated
  keyboard/controller voxel shortcuts and mouse-release-safe free cameras.
- Add a versioned optional battle-music provider API with ORIGINAL, per-fight
  SHUFFLE and available GEN 2–6 choices. No audio or network downloader is
  bundled; provider failure restores the original cue.
- Retain the dynamic reveal/load gate and Route 8 structure-analysis shortcut:
  presentation waits only for the actual destination, while the verified
  no-object regions remove 240,228 build-budget ticks without geometry drift.

## 0.1.8 — 2026-08-19

- Fix Gen1Recomp 0.2.19 zero-fade warps leaving `transitioning` permanently
  set after a cold voxel destination (notably Fly to Cinnabar), even though
  the arrival animation had already released the player's input lock.
- Add dedicated `V` and mapped right-trigger (`ZR`/`R2`/`RT`) camera-ladder
  shortcuts. Existing `3` and SELECT controls remain available.
- Add switchable Kanto skies with sun, pixel clouds, a color-coordinated
  20-minute day/night cycle, moon, stars and occasional shooting stars.
- Anchor clouds, stars, shooting stars, sun/moon and rare sky events to world
  bearings across ORBIT/1ST/3RD instead of rotating them with the camera.
- Add independently switchable, save-persistent rare rainbows and distant
  sky life with FULL/RAINBOW/FLYERS/OFF performance levels. Ordinary windows
  rotate Pidgey, Pidgeotto, Pidgeot, Spearow, Fearow and Murkrow through
  deterministic one-to-four-bird formations; Articuno, Zapdos, Moltres and
  Ho-Oh remain much rarer singleton sightings.
- Add lightweight CLEAR/AUTO/RAIN/SNOW/FOG/STORM weather. Fog uses bounded
  drifting haze; storms add denser rain and rare deterministic lightning.
  Active outdoor weather now remains visible in staged 3D battles.
- Replace enlarged border-block wallpaper with cached, transparent pixel-art
  skyline panels: varied layered trees, water/reeds, stepped mountains and
  stratified cave walls. Semantic outdoor/cave maps no longer build the old
  decorative border ring; separately tiled caps close elevated-view corners.
- Close every semantic cave and Pokemon Tower floor with a 160px wall and a
  32px-tessellated downward-facing ceiling. Cave tilesets select that shell
  regardless of map id; the two location-named Pokecenters remain rooms.
  Pokemon Tower now shares an opaque 512x160 two-bay wall and 256x256 coffered
  ceiling instead of repeating the former small procedural brick stamp.
- Add a world-fixed Kanto ridge behind open-sky routes, towns and mountain
  regions while keeping canopy forest, caves and the southern sea distinct.
  Route 1/Viridian replace their raised green side slabs with compact town-edge
  silhouettes and two sparse rows of batched voxel trees.
- Keep distant forest panels crisp with coarse outlined tree art and explicit
  1x-DPI, nearest-filtered, non-MSAA/non-mipmapped panorama canvases.
- Replace Viridian Forest's black no-sky void with a muted, day/night-aware
  canopy fill. It stays closed to celestial bodies while fog and storms still
  reach both the forest overworld and staged forest battles.
- Continue Cinnabar's free southern/western edges and the adjoining sea-route
  edges as reflective open ocean rather than procedural scenery walls.
- Replace the South Sea landmark cards with four irregularly grounded V3
  cut-outs: rocky island, lighthouse post, separated skerries and Cinnabar.
  Crop transparent module padding and map visible texels 1:1 to world pixels;
  map ownership, shared draw and 256 KiB texture budget stay unchanged.
- Add safe RAM-only PRELOAD. Current and connected meshes warm in the
  background, generation checks invalidate map edits, and the cache never
  writes stale geometry to disk.
- Keep the complete 2D renderer visible until current terrain, grass, flowers,
  figures, atlas/mask and panorama are drawable as one atomic scene. Repeated
  forest, grass and building geometry now uses shared templates plus instance
  offsets; connected jobs still rotate through a bounded budget. Split
  route-sized indexed GPU conversion into 1,024-vertex pages so transitions
  cannot stop the main thread for seconds or reveal delayed decoration pop-in.
- Derive a visual height datum from the engine's real one-way ledge triples.
  The existing 6px lip stays on the lower base while the plateau behind rises,
  producing flush and stackable Route 4 terraces without changing collision,
  movement, encounter or jump logic. Terrain, buildings, vegetation, figures,
  entities, camera placement and shadows all use the same snapshot.
- Fix outdoor house backs copying arbitrary front windows or signage. Rear
  walls repeat a clean 8x8 source-wall tile, then restore only an unambiguous
  native 2x2 door course on door-bearing OVERWORLD/FOREST buildings. A rear
  door becomes functional only where a real aligned warp already exists;
  cosmetic counterparts never invent collision, destinations or gameplay.
- Fix Kanto Ascendant 6.7 trainer-front routing and advertise the exact staged
  battle camera profile its compatibility bridge expects.
- Show an optional **VOXEL ASCENDANT** settings entry inside Kanto Ascendant's
  **ASCENDANT** menu through public runtime discovery, with no hard dependency
  and a no-op fallback when KASC is absent.
- Add a persistent **BTL CAM** 1X/2X/3X starting-distance control shared by
  MAP and DISCS 3D fights. New saves default to the wide 3X view, valid saved
  1X/2X choices remain intact and FULL no longer overwrites that preference.
  The existing Q/E, wheel and pinch zoom can still fine-tune the live shot up
  to 3X without being reset every frame; 2D battle framing and HUD rendering
  remain unchanged.

## 0.1.7 — 2026-08-19

- Split the former **BACK SPRITES** control into independent **TRAINER BACK**
  and **PKMN BACK** settings. Existing `battleBack` saves retain their Pokemon
  choice; the new trainer control defaults to front art in the 3D scene.
- Route `TRAINER BACK = OFF` through the engine's live `player.sprite` seam so
  vanilla and companion-selected trainer front art both render as a correctly
  mirrored player-side card.
- Restore the MIT-origin **1ST** and **3RD** VOXEL rungs with mouse, right-stick
  and touch look, camera-relative movement, collision-aware third-person boom,
  camera zoom and controller/touch-friendly SELECT cycling.
- Keep the restored camera code independent of the removed VR, Horde, Stadium,
  ROM and external-art features.

## 0.1.6 — 2026-08-19

- Add a persistent **BTL GRID** option so 3D battles no longer force voxel
  seams on against the player's preference.
- Add a persistent **SHADOWS** option for both the overworld and staged
  battles. OFF skips the shadow-map pass and its fallback decals, including on
  iPhone, while keeping the existing ON default for upgrades.
- Anchor each battle shadow to the combatant/opponent axis instead of the
  camera-facing billboard, so a stationary Pokemon's shadow no longer rotates
  or slides when the presentation camera drifts.
- Make cold map transitions progressive: queue the drawable body before the
  full border-ring mesh and expose terrain before grass, flowers and authored
  figures finish building.
- Queue a battle arena before its transition begins, allowing the first
  covered frame to contribute to loading instead of discovering the job one
  frame late.

## 0.1.5 — 2026-08-18

- Stop advertising the legacy wide/edge-HUD capability to companion mods on
  iOS. This makes Kanto Ascendant select its renderer-native HUD profile before
  installing the panel bridge that produced a bright green HUD-sized block.
- Match Gen1Recomp's status-HUD visibility guards, including the wild-battle
  party-ball intro where no enemy status panel exists yet.
- Fail closed when the platform cannot be identified, so companion HUD bridges
  are enabled only after a non-iOS platform is positively detected.
- Keep the owner renderer and desktop companion integration unchanged.
- Supersede 0.1.4, whose early snap decline removed the vertical flip but still
  allowed Kanto Ascendant to restore a colored frost panel into the grayscale
  battle canvas.

## 0.1.4 — 2026-08-18

- Decline the optional legacy edge-HUD compositor on iOS, where Gen1Recomp's
  final world-canvas presentation would otherwise flip those already-rendered
  status panels vertically.
- Preserve the established companion fallback contract: Kanto Ascendant and
  other feature-detecting consumers receive `false` and keep the original,
  upright HUD inside the centered engine frame.
- Leave the voxel renderer, desktop compositor and all gameplay state
  unchanged.

## 0.1.3 — 2026-08-18

- Restore the exact proven 0.1.1 renderer and battle-HUD implementation after
  the 0.1.2 mobile experiment caused Voxel Ascendant to stop rendering on
  affected clients.
- Keep only the release/API version bump; no experimental DPI, shader, water
  or HUD-backing behavior remains in this recovery release.
- Name the release archive directly from the case-sensitive manifest ID as
  `VOXEL_ASCENDANT-0.1.3.zip`, matching the launcher's canonical update rule.

## 0.1.1 — 2026-08-15

- Keep both battle HUDs in the centered engine frame so status panels and
  command menus share one scale on large and HiDPI displays.
- Confirm the permanent package boundary: no bundled Pokemon/trainer art and
  no sprite-pack menu; use the game or a separate compatible content mod.
- Move the project into focused compatibility-maintenance mode.

## 0.1.0-rc.1 — 2026-08-15

- Established the standalone `VOXEL_ASCENDANT` identity for Gen1Recomp
  `>=0.1.90`.
- Preserved the voxel overworld, orbit-camera ladder, tilt-shift, water,
  day/night lighting, native-card MAP/DISCS battles, back sprites, and AA.
- Added a versioned public renderer receipt and a RAM-only wall-decal
  registration/draw API for companion mods.
- Removed VR/OpenXR binaries, Stadium/ROM import and extraction code, Horde
  mode, first-/third-person free movement, global mouse callback mutations,
  FFI acceleration, process/filesystem probes, and disk caches.
- Added fail-closed capability checks, a narrow conflict set, deterministic
  direct-install packaging, and complete MIT provenance records.

The upstream v1.6.1 history is retained separately in
`UPSTREAM_CHANGELOG.md`; it contains features intentionally absent here.
## 0.1.8 — RC panorama completion

- Add an original, reproducibly built 1024×192 Kanto distance panorama behind
  outdoor map unions and MAP battles, centred on the player or battle arena.
- Preserve real terrain, connected neighbours, coastal openings, water,
  foreground scenery, the reviewed map-aware edge curtain, authored landmarks
  and all 1X/2X/3X camera rigs; draw the panorama strictly behind them.
- Keep 3X as the default battle view, retain stored 1X/2X choices and leave
  FULL from rewriting the battle-camera setting.
- Reduce the accepted panorama prototype from 2048×384 to 1024×192 after
  native 3X/coast comparison, saving 2.25 MiB retained VRAM; load it lazily
  and release its texture and mesh when SCENERY is switched OFF.
