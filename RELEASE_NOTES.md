# Voxel Ascendant 3.0.0 RC12 R3 audition candidate

This VASC source checkpoint keeps the owner-segmented RC11 architecture as its
base. The already built Kanto Ascendant `6.6.0-rc.1` remains an immutable
rollback package and is copied byte-for-byte into the new no-clobber R3 test
folder. VASC deliberately remains `3.0.0-rc.12`: the unchanged KASC 6.6
compatibility contract rejects later VASC prereleases, so an artificial rc.13
label would make the combined candidate unloadable. This checkpoint ports the
immutable final M10 mobile lifecycle/neighbor-stream
semantics and only the reviewed five-path M10-to-M11 Gen-1 geometry/sky delta.
It is not a whole-tree M10 or M11 overlay. Existing mobile Box/Party/Dex
layouts, touch/IME and global Box search remain included.

R3 adds the isolated VASC-only Gen-1 Weather Music graph: package assets,
catalog, router, option UI and the central-owner playback adapter are five
separate Cards. Exactly 45 derived OGG cues cover Heat, Night, Rain, Storm and
Winter for nine explicitly registered Kanto maps; their deterministic payload
is 26,080,994 bytes (24.87 MiB). Clear daytime and every unsupported map use
the already final game/KASC/LocalMusic map cue. Battle, victory, jingles,
story, Bike, SURF, Evolution, title, Hall of Fame and credits remain untouched.
The option defaults ON for both new saves and old saves without a value.

Only the central Engine Music owner creates, seeks, pauses, crossfades, loops
or restores audio Sources. Same-composition weather changes wait for a safe
downbeat, retain the running native loop position and use at most two streams;
unknown custom map arrangements take the ordinary crossfade path instead of
borrowing an unproven native timing grid. This requires the separately pinned
R3 Engine companion. The assets and runtime gates are locally green, but the
music payload remains `AUDITION_ONLY` / `USER_TEST_REQUIRED` until the PC and
smartphone listening matrix is completed. R3 is therefore internal QA and not
a distributable final release.

The final M10 input is pinned at SHA-256
`66021fb9a6512d3192692b14d3f8af965f8c52d8ed4b20163b1da8228be07618`;
the narrow M11 input is pinned at SHA-256
`f40707ad446919cc5dd632bf1c0db7fc4e9cdb8827c5517d95e248c2c222c6b9`.
The raw M7/M8/M9 experiment packages remain forbidden import roots. Their
reviewed recovery and Canvas-return behavior reaches RC12 only through final
M10. The optional KASC walker is a separate fail-open compatibility segment,
so standalone VASC remains valid.

Mobile tracing and rearm controls no longer occupy the ordinary Voxel menu.
They are available only below `ADVANCED -> RC DIAGNOSTICS`. Local gates and a
real LÖVE shader check do not constitute an iPhone, Android or Windows PASS;
the phone run and joint demo remain explicitly pending. A native 2D fallback
is a safety path, not acceptance of the requested Voxel view.

The first real iPhone M11 run reproduced two P0 follow-ups: map
scenery stays black after a transition until a setting is toggled, and the
battle HUD uses the wrong device orientation. Both now have separate,
locally-green owner Cards: the map lifecycle continues its finite staging
without a menu impulse, and the HUD samples one display-orientation receipt per
frame. Their physical iPhone retest is still required, so this is not a device
PASS.

Johto's `DAYTIME` standard now follows the current Gold/Silver/Crystal
journey clock instead of starting an unrelated 20-minute sky clock. The native
hour and minute drive VASC sky, sun/moon, windows, water and shadows while the
engine retains its own MORN/DAY/NITE palette and gameplay answer. Existing
saved `cycle` selections remain available as `FREE RUN`; DAY, NIGHT, DUSK and
DAWN remain explicit pins. Indoor lighting is unchanged. The owner contract is
locally green, while the physical G/S/C visual matrix remains pending.

Gen 1's distant authored panorama now follows an already settled outdoor snow
coat through a separate draw-local grading Card. Weather accumulation and the
day/night shader remain their existing owners, so dusk and night still tint
the graded panorama naturally; indoor, clear, rain and zero-coat draws remain
neutral. The mobile-core shader deliberately retains its existing no-surface-
weather contract, so the panorama stays neutral there too. Atlas-glass is
disabled for the non-atlas panorama, and colour, glass and depth state are
restored even when the draw declines or throws. Focused and existing rendering
regressions are locally green, while the physical Red/Blue/Yellow winter matrix
remains pending.

Gen 1 move-learning prompts now claim one complete presentation surface while
the exact native `MoveLearnMenu` is active. A retained wide VASC battle no
longer bleeds its Pokemon, HUD or dialogue layers through the move list. The
adapter does not own move eligibility, replacement, EXP.ALL, TM/HM, evolution,
input, callbacks or save state; replace, decline and cancel restore the same
battle/camera/HUD lease. Its automated owner and graphics-state contracts are
green, while the visible packaged flows and device matrix remain pending.

The follow-up `VASC-66-GEN1-MOVE-LEARN-OWNER-HANDOFF` closes the concrete
owner collision with the bundled floating battle HUD. The legacy constructor,
visibility and HUD paths now yield only while the validated full-surface Card
owns that exact native menu, and resume only after explicit fail-open or
deactivation. A production-order test executes the frozen engine StateStack;
learning rules, input, callbacks, save state and battle leases are unchanged.

Three later Gen-1 fixes remain separate 6.6 Cards. FLY and Fishing publish a
custom Canvas only after their live presentation actually draws, so a missing
projection, callback or transient character renderer falls open to the native
frame instead of producing an invisible or audio-only cinematic. Battle native
latches now emit one bounded diagnostic receipt per encounter, and a later
switch cannot reopen renderer deployment after `native_latched`; no provider or
fallback policy changes. All three source gates are locally green, while their
physical Red/Green/Blue, hit/KO/victory and device cases remain pending.

The paired KASC source is pinned at `5da0d1c15dc0d1c9f34f9575035c8708de621ec8`.
Its bounded support logger is tracked as its own Card, and its five-part Rival
contract is documentation/test-only, default OFF and runtime/package inert; the
existing monolithic Rival runtime is not relabelled as segmented. The separate
Gen1Recomp desktop-input companion remains the R2 rollback source at
`02513fe8d66b0cf58609e235674c8a0020966a81`. R3 uses a separately pinned
successor that adds only the central Weather Music transition/loop owner; its
`.love` and macOS QA artifacts still require physical music, Box Search, IME,
controller and window/fullscreen acceptance. The historic RC12 ZIP and the
complete `KASC-VASC-6.6-GESAMT-RC-20260903-R2` folder remain immutable. Every
new build and receipt is restricted to the distinct no-clobber R3 folder.

The complete Kanto Ascendant 6.7 release tree and its history remain forbidden
inputs. The explicitly selected 6.7-derived systems are nevertheless authorized
for the combined 6.6 RC as individually rebuilt semantic Cards with their own
allowlists, tests and rollback commits; no whole-tree overlay is permitted.
The RC10 notes below are retained as historical behavior and rollback
reference; they do not describe the current RC12 package identity.

# Historical: Voxel Ascendant 3.0.0 RC 10

## One VASC + injector delivery candidate

The RC10 delivery contract is one archive: the direct-install VASC mod, native
macOS, Windows and Linux builds of VASC Content Selector 0.4.0, its portable
source fallback, the optional Kanto Ascendant 6.5.20 compatibility update,
installation notes and SHA-256 receipts. A release archive is not produced
unless all three native selector platforms pass their pinned artifact gates.
Install KASC 6.5.20 before VASC RC10 when using both;
KASC 6.5.19 accepts only through RC9 and displays a launcher conflict. The
selector finds current VASC or a
legacy VASC4J location and indexes an adjacent KASC installation without
making the player hunt for sprite and music directories. Named presets cover
the default, each generation and individual games; a narrower preset can
inherit or copy its parent.

Both VASC runtimes re-check the bounded active pointer, canonical manifest,
asset sizes and hashes before accepting CUSTOM content. If a structurally
valid CUSTOM reference later fails generation verification, its declared
`retro` base tries the public RETRO provider and then packaged VASC DEFAULT;
its declared `vasc-default` base goes directly there. Explicit VASC DEFAULT
terminates resolution. A missing pointer retains the historical loose-folder
path only for a saved legacy CUSTOM request. Existing v1 active pointers remain
accepted as migration input and map to the default scope. The in-game
`PRESET & SCOPE` page always provides a direct restore action.

RC10 also integrates high-resolution/HGSS billboard sampling without changing
native 16-pixel world geometry, directional Gen-1/Gen-2 Surf riders with a
standing trainer pose, the latched comfort-safe SMART/STADIUM camera, and a
non-blocking repeatable Mega presentation. Gen-2 battles retain sharp authored
combatants and fall back to VASC's `attack_default`; Party/TM, Bag, PC, Legacy
Bank and ASC BOX surfaces keep their native behavior beneath the selected
presentation. Their full acceptance matrix runs headless without opening LÖVE
windows.

Fishing now receives the same reviewed species-aware presentation in both
generations while the game remains its complete logic owner. The selected rod
casts a visible line and bobber, calm attempts create water rings, and a real
bite pulls out exactly the Pokémon the engine already generated; Gen 2 keeps
that object's Shiny state. No encounter is rerolled and no timing, text, input
or battle callback is replaced. The 774 sprites are the byte-identical Fly/Surf
directional set already packaged by VASC, so RC10 adds controllers but no
duplicate artwork tree. Any missing asset or drawing error leaves the native
fishing sequence running.

The reviewed executable 0.1.90 Gen-2 acceptance host starts Gold; the same
generation bridge is shared by Gold, Silver and Crystal hosts. RC10 exposes
four real battle architectures there: MAP keeps the exact frozen voxel
encounter site, ARENA uses the reviewed map-stage resolver, DISCS uses the
portable Stadium platforms and GAME DEFAULT retains the complete cartridge
scene including its original player back picture. Historical boolean saves
still map `true` to MAP and `false` to GAME DEFAULT without a migration write.
Architecture, SMART CAMERA and
HUD policy are captured once per battle, survive trainer intro, send-out and
ordinary switches, and are released at battle end. STANDARD is a transparent
native HUD over MAP/ARENA/DISCS rather than a hidden switch back to 2D; GAME
DEFAULT remains fully native. Any stage, texture, compositor or HUD failure
latches only that encounter to the complete native renderer and cannot restage
it midway through the fight.

Gen-1 battle presentation is now an immutable per-battle choice. MAP, ARENA,
DISCS and native 2D are never relabelled or written back as one another. An
unsafe or unavailable selected stage may latch native presentation only for
that exact battle and cannot jump back later. During a switch,
VASC first commits an actor-free frame with the selected arena, camera and HUD;
old sprites and attacks remain absent until the new deployment is complete.
If even that cover cannot be rendered, the battle selects native once and
cannot jump into Voxel later. The live engine battler always retains its real
cartridge rear image; VASC resolves a separate front only inside the isolated
world texture, so ORAS cannot leak a standing/front sprite into the classic
back slot.

The integrated ASC BOX again matches the reviewed 0.5.3 behavior for Box
cursor memory, Team-to-Box B navigation and rejected drops. An invalid target
keeps the carried Pokémon, source and save untouched and shows bounded
localized feedback; only an applied result clears the carry. The optional
ORAS FULLSCREEN glass skin applies exclusively to the VASC/KASC settings hub,
uses white bitmap text plus a white outer boundary and edition-colored inner
frame, remembers its section/item/scroll position and does not reskin the Bag,
PC, Box or ordinary game menus. Both optional ORAS Bag skins now use exact
Diamond/Pearl game-art tabs for Items, Medicine, Poké Balls, TMs/HMs, Battle
Items and Key Items instead of temporary drawn symbols. The original Bag
callbacks and pocket-specific cursor/scroll memory remain the owners. These
Pokémon game-art crops remain a private test candidate without public
redistribution clearance.

RC10 makes the two authored Gen-1 Bag skins public only as `D/P ORAS WIDE`
and `FRLG ORAS WIDE`: both are real 512×288 layouts with nine visible rows,
permanent item help and the real pocket images. Historical compact saved
values migrate to the matching WIDE choice; the compact presenters remain
internal emergency fallback and no longer appear in the menu. KASC separately
adds the append-only `FIRERED / LEAFGREEN WIDE` choice for its PC and Legacy
Bank with a 5×4 Box grid, 2×3 Team rail, persistent detail/help panels and
complete Change-Box and Player-PC overlays; KASC's existing compact PC styles
keep their established keys and ordering. Callbacks and storage semantics are
unchanged. Gold's native `PackMenu` remains the Gen-2 owner; the Gen-1 Bag
adapter is not falsely advertised there.

Gen 1 now also ships the reviewed Modern Pokédex 0.4.0 as the default
512×288 list and data presentation. `GAME DEFAULT` returns directly to the
unchanged cartridge Pokédex. Portrait selection is scoped to this Pokédex and
can use KASC's Crystal provider, the active VASC sprite style or the original
game picture without changing battle, Box, Party or overworld sprites. The
integrated Kanto widescreen map supplies the optional AREA page only through
its public provider; a missing or invalid provider, construction error or
rendering failure opens the exact native area map with the original species.
Save data, seen/owned flags, species records, cries, scripted previews, screen
stack and Start-menu callbacks remain engine-owned in every mode.

The Legacy Bank can now be operated naturally from ASC BOX: SELECT marks or
unmarks several Pokémon across Box pages, the visible count follows the
selection, and START transfers that stable selection to the normal PC boxes or
clears it. `ALLE IN PC-BOXEN` remains available. Both paths delegate to KASC's
reviewed batch transfer core. It preflights capacity, locks and every selected
identity before mutation, leases the complete fitted tranche with one archive
commit and then writes the game once. Classic single withdrawal, the
FRLG/ASC-wide adapter, marked selections and `ALLE IN PC-BOXEN` set both seen
and owned Pokédex state for every actually moved species. Any insertion or
save failure removes the physical Box/Party additions, restores the previous
Dex state and releases the same tranche with one archive commit; a full target
retains and explains the exact Bank remainder.

The RC10 correction pass restores two presentation contracts that had
regressed during integration. An explicitly selected Gen-1
`DEFAULT/OFF + STANDARD` battle once again uses the reviewed compact enemy
front position; the ROM-authored player-back baseline and every ORAS/Voxel,
trainer and oversized-custom placement remain untouched. In staged ORAS
battles, OUTSIDE, ABOVE and CORNERS are real status-card layouts again. They
derive from exact rendered alpha hulls and are clamped deterministically to
the physical safe frame, so a valid 4:3 MAP scene cannot be rejected merely
because the initial player card began outside the window. Camera preflight
rejects an unsafe owner proposal definitively and tries the next safe seat;
its occupied-area contract includes the active command/message surface and
the Safari counter before a layout can be declared complete.

KASC's exported Ascendant settings controller now consumes the same mandatory
ORAS FULLSCREEN presentation bridge as VASC's own settings tree. The bridge is
live and loader-order-safe, retains KASC's callbacks, focus and scroll state,
and never wraps KASC's global help callback or ordinary Bag, Bank, question
and game menus. The compact presentation is internal emergency fallback only.

The bundled KASC Useful Bag now also restores the last stable item and visible
row separately for every field pocket. Pocket changes, reopen, reorder,
consumed items and empty pockets stay bounded; battle Bags keep their own
priority and never inherit field navigation. RC creation verifies this exact
runtime against the pinned KASC Git tree so the Companion builder cannot omit
the fix unnoticed.

Release creation is no-clobber: both the direct-install and combined RC
builders reject an existing output before collecting or building inputs. The
combined builder protects its checksum path as well, preventing a previously
reviewed or rejected RC artifact from being silently overwritten.

Content Selector 0.4.0 is additionally bound to a checked-in 34-file source
ledger, including every one of the 15 native-platform build inputs. The native
apps and portable delivery are produced only from those verified bytes. Foreign
Python/Swift input, source drift during packaging, a portable ZIP member that
differs from the ledger or an inherited catalog/signing override fails before
either the outer archive or its checksum becomes visible.

Preset validation is transactional across every present default, generation
and per-game scope before the first engine registration. Music identifiers are
derived from the complete manifest and asset digests plus a stable ordinal,
partial registration is removed on failure, SemVer build metadata is accepted,
and changed package/runtime bytes remain restart-required across fresh Lua
loader handles. The native macOS store is release-gated against the same
Python SemVer, conflict, repository and allow-package contract. The outer
delivery additionally compares every KASC payload
byte with the explicitly reviewed 6.5.20 source tree and includes that complete
provenance ledger alongside its package hashes.

Both shadow pipelines now restore Canvas, shader, depth/cull, blend and color
even when a caster fails. Gold deployment receipts distinguish trainer,
active Pokémon and sprite identity; the native redraw boundary balances leaked
graphics pushes, and a broken Stadium rig remains local to its exact side and
battler instead of reloading every frame.

The package-bound Gen-1 visual acceptance gate now reads back the actual GPU
pixels of the production EMBER animation after the complete final compositor.
For each frozen keyframe it renders an otherwise identical A/B pair, once with
the production attack draw and once with only that instance-local draw
suppressed. Their difference must carry significant opacity exclusively inside
the correctly projected trajectory corridor. Origin and travel keyframes must
also differ in attack-only and final-frame SHA-256. Transparent, clipped,
off-screen, static, overdrawn or wrongly projected effects therefore fail
closed.

## RC9 baseline

## Private battle, Crystal and storage correction candidate

RC 9 keeps Voxel and ORAS ownership continuous through consecutive Red and
Crystal encounters, including message, send-out, switch, attack, Fishing and
Trainer paths. Crystal's authored front/back pictures are composited directly
into the live Voxel scene until a future Stadium renderer explicitly receipts
that it drew the same side. A missing reviewed arena now receives a portable
Voxel stage rather than silently changing the requested battle mode to 2D.

SMART / STADIUM remains the default battle camera and STATISCH 3X remains an
explicit alternative. The smart director commits only a completely clear,
comfort-limited path selected for the current room; constrained rooms hold the
best safe view. Gen-2 Fly uses ordinary NPC scale, FIELD KIT Surf retains its
jet-ski owner and 3RD zoom no longer hides the rider/mount card.

ASC BOX again pages from the focused Box header, shows named Johto type badges
and resolves Box, detail and mini-Team from the same KASC Crystal/Shiny source.
LOCAL mode adds visual-only ramps at proven walkable non-water connections;
game collision, saves, doors and warps remain untouched.

## Private Start-team and cinematic-startup hotfix

RC 6 removes the accidental root-level `BOXEN`/`STORAGE` shortcut. Storage
opens only through the regular PC or a compatible KASC Legacy Bank host, so
those owners keep every save, capacity and transfer rule. The normal Gen-1
`POKéMON` Start row is unchanged and now offers a presentation-only team skin
instead. On Red/Blue/Yellow, under `ASCENDANT → SKINS & OVERLAYS`,
`START TEAM UI` and
`BATTLE TEAM UI` are independently selectable as `ASC BOX`, `ORAS GLASS` or
`GAME DEFAULT`; both default to ASC BOX. Native team actions, field moves,
item targets, switching, callbacks and saves remain authoritative. Gold,
Silver and Crystal now expose independent `START TEAM UI`, `BATTLE TEAM UI`
and `BATTLE HUD` choices between draw-only `ORAS GLASS` and `GAME DEFAULT`.
Their engine still owns every input and callback; intros, attack/capture
animations, prompts, learning/evolution, submenus and special battles always
fall back to the complete native canvas.

The integrated Fly 0.4.3 and Surf 0.3.1 pipeline patches now install before
the engine freezes its content registries. This prevents the half-installed
state in which native Fly stopped while neither the carrier nor the selected
Pokémon appeared. Existing runtime failure paths still release every input,
visibility and transition lock back to the native animation.

ORAS menu outlines now use pixel-exact rasterization and restore the previous
graphics state. This removes the one-native-pixel vertical remnant left at an
old centered Start-menu edge after KASC widened and right-anchored the menu.
The fix is covered by a real 160×144 LÖVE pixel readback, not only a mocked
rectangle test.

Direct WILDS contact battles no longer alternate between the last Voxel/ORAS
frame and native 2D when one cold scene update intentionally yields no new
shot. VASC retains the last fully committed frame only while both exact actor
receipts still match; a switch, form change, missing receipt or real renderer
failure returns safely to native 2D.

## Private Bag integration candidate

This private RC test adds three Bag presentation rungs inside VASC:
`GAME/KASC`, `D/P ORAS` and `FRLG ORAS`. `GAME/KASC` is the default and does
not wrap the game's, Useful Bag's or KASC's draw function. Choosing either
VASC style explicitly decorates only `draw` on the next opened Bag; the
original instance continues to own update, input, item/pocket data, sorting,
USE/TOSS, quantities, TM/battle rules, saves and all callbacks. Returning to
`GAME/KASC`, losing an atlas or encountering a renderer error calls the exact
draw captured from that provider. The Bag selector is independent from the
ordinary `OVERWORLD MENUS` skin.

The D/P style uses sixteen unscaled Bag crops and the FRLG style uses ten
unscaled Bag/Pouch/Case crops. Accent and silhouette can be changed separately;
AUTO consumes only KASC's public RED/BLUE/GREEN identity and otherwise uses
red/round. Exact hashes and derivation recipes are recorded in
`ASSET_SOURCES.md` and `FRLG_ORAS_BAG_ASSET.md`.

These Pokémon game-art pixels are not covered by VASC's MIT licenses. This
candidate is for private compatibility/visual testing only, must not be pushed
or published as a release, and still requires redistribution clearance.

This release candidate is one autonomous package for Generation 1 and
Generation 2. `main.lua` selects a fail-closed runtime: the reviewed Kanto
renderer remains in `main_gen1.lua`, while Gold/Silver/Crystal gameplay and
world modules use the isolated `gen2/` namespace. The generation-neutral menu
controller and FRLG/ORAS presentation sources are shared from the package
root. The current Gen-2 parity candidate keeps native menu and
dialogue semantics but gives their drawing the shared ORAS skin, while the
Voxel Ascendant control centre uses the exact shared FireRed/LeafGreen
Ascendant renderer. Gen-2 battle input remains native; VASC's ordinary
menu/move phases may use the draw-only ORAS HUD and otherwise fail open to the
complete native battle canvas. No ROM, private KASC module or VASC4J runtime
is bundled.

RC 5 integrates VASC Species Fly Cinematic 0.4.3 and Species Surf Cinematic
0.3.1 directly into the Gen-1 runtime. Red, Blue and Yellow now ship one VASC
package with the exact selected normal/Shiny species through Hoenn plus
Gorochu, the authored mount/tow/board/balloon profiles and trainer-only KASC
Field-Kit jet ski/jetpack paths. The two source packages' 774 byte-identical
directional atlases are stored once; Surf's world carriers reuse the 502 exact
RC4 payloads already in VASC and add only the missing Hoenn/Gorochu set. Exact
input hashes, provenance, notices and credits remain packaged under
`docs/species_cinematics/`.

Both cinematics compose the existing VASC-owned voxel pipeline and leave HM
permission, party selection, maps, movement, encounters, audio, warps and save
state to the game. Asset, canvas, GPU or controller failures release their own
temporary locks and return to native Surf/Fly without retiring the shared
pipeline. The integrated Fly module obtains optional Field-Kit control only
from KASC's public `fieldTech` service. Retired standalone IDs are replaced by
manifest policy and guarded at runtime against duplicate wrappers.

VASC no longer assigns SELECT to its camera ladder. SELECT belongs to native
game input and KASC Quick Select/Field Kit; `3`, `V`, `ZR/R2/RT` and the VASC
options remain the dedicated camera controls. Twenty alternating Surf-to-Fly
cycles, targeted Surf failure recovery, real KASC SELECT holds and the source,
runtime, packaging and Gen2 regression suites cover the integrated layout.

RC 4 is the combined public hotfix for the current Gen-1 field reports. On the
first valid rendered frame of a Pokémon's deployment, its ORAS status card is
derived from that exact model's alpha-ink head and its complete screen-space
rectangle is then frozen. A real switch relatches only the changed side;
animation frames, camera travel and actor crossings never reproject, sort or
rebind either card. The dynamic STADIUM director remains available in roomy
arenas, accepts manual steering as its new orbit basis and evaluates both world
occlusion and these frozen HUD rectangles before resuming automatic motion.

Gold, Silver and Crystal now share a smooth-install performance policy instead
of promoting a detected desktop straight to the most expensive preset. AUTO
uses the existing HANDHELD renderer on balanced/high hosts (complete voxel
world, weather and sky at half-size with low shadows and no costly AA) and ECO
on low-tier hosts; PC/MAX remains an explicit choice. Cold current-map meshes
are built cooperatively behind the native 2D fallback, destination bodies are
prefetched during the cartridge's existing warp fade, and a newly entered map
outranks leftover apron work from the previous map. Dense grass/figure uploads
are budgeted as well. In the real Gold acceptance run the worst Route 29 draw
fell from 7368.67 ms to 226.27 ms and Ilex Forest from 4445.00 ms to 597.07 ms;
all three cold maps became responsive and then promoted atomically to 3D.

The ORAS HUD transaction keeps its private full-frame fail-open layer but, for
the built-in provider, clears and commits only the published status-card damage
rectangles. At 3420x2214 in a real Yellow OAKS_LAB battle this raises VASC from
85.42 to 103.82 FPS and VASC+KASC from 83.78 to 106.34 FPS without reducing
scene resolution; the OAKS_LAB overworld remains above 200 FPS in the same
fixture.

The public Pokémon-screen seam now requires a live Host-v1 receipt as well as
a complete provider. Standard PC, Legacy Bank and battle-party choices appear
only where their schema, modes, actions and events intersect; an opaque host
handle binds immutable snapshots and authoritative callbacks to one exact
session. Stale receipts or malformed results revoke the controller and return
the next whole frame to the host. This affects only those three screens:
ORAS GLASS battle HUD remains an independent setting.

ASC BOX now ports the final 0.5.3 storage presentation through that boundary
as VASC's default. The chosen surface opens through the regular PC or a
compatible Legacy Bank host; the Start menu no longer bypasses those owners;
visible Box seats remain independent from dense save-array indexes; A lifts
and atomically drops or swaps between Box and the mini Team, including across
Box pages. Merely lifting or cancelling cannot mutate. Box paging is
promptless and does not force a disk write; the same live save object persists
through the game's ordinary later Save/Savestate flow. Eggs expose only a
neutral private descriptor, and a live external KASC host wins PC/Legacy at
the exact screen open without duplicate interception.

Host v1 now negotiates the ASC BOX logical canvas without naming the provider:
the provider declares one bounded viewport, the host declares the exact sizes
it can present, and the accepted viewport is bound into the session receipt.
Exclusive input crosses the boundary only as a validated sparse `pressed`
envelope. On a Legacy Party entry, ASC BOX offers the host-authorized atomic
deposit path instead of attempting an invalid bank-to-bank move.

`ORAS GLASS` remains a separate live choice for the battle team and forced
switch surface, using the same native VASC validation host. It is deliberately
not offered for PC or Legacy Bank and remains independent of the ORAS battle
HUD setting.

The same pass keeps every uploaded battle arena inside globally safe map
space, retries transient arena startup, aligns Lorelei's room axis, restores
Silph recovery beds, and makes Safari battles use the complete VASC ORAS owner
without leftover native/KASC gender, caught or EXP overlays. VASC still owns
its HUD and camera autonomously; KASC 6.5.18 cooperates only through versioned
public receipts.

The VASC control centre now stays opaque and wide enough for its translated
rows, carries one permanent contextual help strip on every page and leaves no
old vertical shadow or stale dialogue fragment behind it. Scene uploads expose
the complete visible voxel plan instead of a stale map root. Battle placement
is clamped against global map bounds and nearby geometry, covering the reported
Route 1 edge, Vermilion dock/building and Mt. Moon wall anchors.

HEIGHTS=SLICE now renders Route 1's physically framed jump-ledge garden as a
genuinely raised local terrace with a watertight vertical front. The repeated
jump gaps remain ledges—not invented stairs—while the real broad rear passage
is kept walkable as the graded return to ordinary ground. The slice remains
bounded to that contour and does not propagate into water, Route 5, Cycling
Road or a neighbouring map. FLAT, LOCAL and WORLD keep their separate saved
semantics.

Red, Blue, Yellow, Gold, Silver and Crystal now contribute a thin edition
accent to the existing shared ORAS frame instead of installing separate menu
or HUD palettes. Gold/Silver/Crystal reuse the shared VASC control centre and
draw-only ORAS dialogue/list skin while retaining native engine input. Their
ordinary battle menu/move phases and Party/Summary screens may use the same
ORAS language; every unsupported phase and renderer error restores the full
native canvas.

USER CONTENT now has one saved source row with exactly `KASC`, `VASC DEFAULT`,
`RETRO` and `CUSTOM`. Optional KASC/Retro content is accepted only through a
complete public receipt; unavailable or colliding providers fall back per slot
without changing the player's request. CUSTOM reuses the documented loose
sprite/music folders produced by the separate cross-platform selector. Direct
`.vascpreset` parsing remains fail-closed until the engine exposes bounded
read/hash asset calls.

The public KASC 6.5.17 package and its 128px trainer handoff are the compatibility
reference. VASC consumes only the public `OverworldBattle.sideTexture` boundary
and preserves its 320x288 canvas, logical 160x144 anchors, source-scale receipt
and nearest sampling; VASC remains fully usable when KASC is absent.

VASC remains the sole owner of the voxel battle camera. In a narrow or
obstructed physical arena it now evaluates multiple clear viewing seats once,
chooses the best view that keeps both Pokemon readable, and holds that seat
static for the battle. Roomy arenas retain the saved STADIUM director and
optical zoom; optional companion mods do not supply or drive this camera.

RC 3 completed three presentation hotfixes found in the combined KASC 6.5.18
test: every VASC settings page now keeps a permanent cursor-sensitive help
strip, rain/storm/fog/snow suppress the hard sun/world shadow pass, and SLICE
uses only a locally enclosed, walkable stair opening instead of a weaker
LOCAL/WORLD height sweep. KASC 6.5.18 must admit the VASC 3.0 RC public HUD
receipt to suppress its native EXP/gender/caught fallbacks; VASC does not read
or modify KASC options to achieve that handoff.

The saved **HEIGHTS** row now offers `WORLD`, `SLICE`, `LOCAL` and `FLAT`. WORLD carries
only a proven ledge datum across direct outdoor map seams and lets the nearest
enclosing rocks or bollards ride the same plateau; it never stretches a stair
across a city or an unrelated road, and the land may return to zero after the
physical frame. SLICE accepts only locally bounded physical contours and never
crosses a map connection. A single collision-proven stair opening may grade
into its raised component; a repeated framed jump-ledge front may form a
vertical terrace but never invents stair ramps in its jump gaps. Ponds and
unframed ledges stay flat. LOCAL restores the previous bounded per-map interpretation.
FLAT retains native stair/ledge art and gameplay without lifting the region
behind it. This keeps Cerulean level outside its real Nugget Bridge/house rise.
Walkable one- or two-cell openings inside the same proven ledge contour now
form short diagonal approaches with closed sides; ordinary cliffs stay vertical
and gameplay/collision data are unchanged.

The VASC control centre now has the stable eight-section hierarchy requested
for native START menus: `VIEW + WORLD`, `WEATHER + SCENERY`, `BATTLE`,
`POKéMON + MODELS`, `WILDS + FOLLOWERS`, `PERFORMANCE`, `USER CONTENT` and
`ADVANCED`. Standalone VASC owns the complete tree; an active KASC only moves
the single public VASC descriptor into its menu and opens that same tree.
Every category and selectable row has contextual START/SELECT guidance in
English and German. The installed custom-sprite guides now also document
front/back canvases, trainer identities, Megas, foot anchors and the complete
MAP/DISCS/ARENA/mobile acceptance matrix.

VASC now offers a responsive ORAS battle HUD or the previous readable standard
HUD as an autonomous presentation in standalone and combined installations.
The ORAS path scales its complete command group, status/EXP/team receipts and
party selector for desktop, mobile and controller input. KASC may authorize a
Mega control only for the exact eligible active Pokémon through its public
service; installation alone never creates a control or displaces VASC. Only a
versioned external HUD claim hides VASC's own HUD rows.

`BATTLE -> BATTLE LAYOUT` adds saved end-user fine placement directly inside
VASC. The player can select front, modern back, retro half-back, Mega, enemy
Pokémon, player/enemy trainer or an individual VASC fallback-HUD zone, then
move it on X/Y and scale it from 50 to 200 percent. Every role keeps its own
values and has an individual reset; a full reset restores the reviewed
automatic 0/0/100-percent composition. Optional KASC or local sprite providers
may supply the final artwork, but this controller remains VASC-owned and never
changes another mod's options or files.

VASC's integrated Weather, Sky, Sky Events and Weather Footsteps path is now
the single canonical effect director for CLEAR/AUTO/RAIN/SNOW/FOG/STORM/HEAT/
RAINBOW. Direct choices, AUTO and optional state providers all feed the same
resolved VASC renderer instead of activating parallel effect implementations.
RAIN and STORM gain short deterministic foreground windows with only a few
soft adhered drops and downward trails; outside those windows the pass draws
none, and outdoor battles use a deliberately quieter count.

RAIN also receives eight map-fixed wet-grey cloud-bank candidates and STORM
twelve darker, larger candidates. Their world addresses contain no weather
clock, camera, player or event-occurrence input. The existing drifting clouds,
clear-day horizon bank and synchronized cloud/flyer shadows remain separate
bounded layers.

Ordinary map/object shadows now remain limited to outdoor CLEAR+DAY, while
terrain, water, cliffs and map edges never become casters. Visible cloud and
flying-Pokémon events keep synchronized shadows behind their own toggles.
RAIN/STORM can stage Lugia and HEAT Ho-Oh only in deterministic 2/3-spaced
windows; each weather legend owns the only permitted shadow in that weather,
and roughly every third visible pass can request its already registered cry.
Lugia ships as fourteen hash-recorded 56x56 Crystal frames with the exact
3740-ms source timing. VASC still contains no KASC code or hard dependency;
KASC remains an optional separately installed public integration partner.

The rainbow now uses exactly the same complete world-sky projection as VASC's
clouds. Both its bearing and elevation are fixed sky directions; the remaining
screen-space Y override has been removed, so 3RD/1ST cannot carry the bow like
a camera-layer element. Its map-stable bearing contains no clock, drift speed
or event occurrence, matching a static sky motif rather than wandering clouds.

Clear daylight now adds a second bank of ten small, slowly wandering clouds
close to the distant horizon. They exist only as world-sky directions—not near
the player—and reuse the existing cloud atlas without another texture load.

The post-rain rainbow is now a large, smooth and genuinely round atmospheric
arc. It remains fixed in the world sky instead of following the camera,
uses a dedicated 1024x512 antialiased texture with linear sampling,
and lets both complete legs continue behind the terrain. The prismatic screen
reflections from 2.0.5 remain active.

`3D-BTL = DISCS` now exposes its own `DISK ART` row. `V+FRLG` makes one
stable choice for the whole fight between VASC's established neutral disk and
the FRLG-like terrain assigned to the current map; `VASC` and `FRLG` pin the
respective family. The shuffle never chooses a terrain. Grass, forest, water,
pond, cave, Seafoam ice, Safari sand, mountain, building and special indoor
disks come from explicit map/profile receipts. Unsupported expansion profiles
retain the neutral VASC disk even in the FRLG-only position. `ARENA BG` remains
a separate ARENA-only control. A selected FRLG disk also supplies a very pale
material-matched renderer tint for the otherwise white procedural void. This
is a color value, not a large background image; outdoor variants can still use
the normal weather overlay, while VASC-only and unsupported fallbacks keep
their established live sky/void.

Ten newly generated 128x128 RGBA textures are included. Their ImageGen masters,
prompts, hashes and deterministic nearest-neighbor build are recorded in
`ASSET_SOURCES.md`; the linked original Battle Backgrounds sheet is a
non-shipped visual reference only.

AUTO weather now behaves as a small director rather than a fast cycling map
hash. It holds longer spells, reshuffles cleanly after map and interior exits,
makes thunderstorms rare, and keeps HEAT and SNOW in separate seasons with a
normal interval between them. CLEAR, RAIN, SNOW, FOG, STORM, daytime HEAT and
RAINBOW remain selectable test states. When rain or a storm clears, the live
sky guarantees a world-anchored rainbow. Its smooth circular arc keeps
its natural proportions while both complete legs continue behind the terrain
horizon. Four slowly drifting, map-seeded kaleidoscope clusters
throw mirrored additive rainbow shards across the world canvas instead of the
former barely visible corner rings; the HUD is drawn later and stays clean.

Snow/wet terrain no longer identifies roofs by their brightness. The mesh now
marks actual upward geometry, so ground, roof slopes and tree crowns can react
while Pokemon Center and house walls stay untouched. Walking on snow creates
a quiet synthesized crunch; walking in rain or a storm creates a subtle wet
splash. These sounds follow the game's SFX volume, skip bike/Surf movement,
and add no bundled audio asset.

This hotfix adds an `ARENA BG` row whenever `3D-BTL` is set to `ARENA`.
`VASC + FRLG` shuffles once per fight between the existing VASC painting and
the new FireRed/LeafGreen-like counterpart, but only on geographically
reviewed maps. `VASC ONLY` keeps the established gallery; `FRLG-LIKE ONLY`
uses the 13 new profiles where they fit and retains the correct VASC master
everywhere else. The selected image is latched for the whole fight. Outdoor
Forest and Safari profiles continue to use VASC's live day/night sky; enclosed
rooms remain opaque except for the Mansion's already-reviewed physical window
masks.

This mobile presentation hotfix makes the VASC hub use Kanto Ascendant's
native menu style 1:1 and adds saved HUD position, scale and transparency
controls. Landscape phones default to wide edge status panels; portrait iOS
and Android use crisp native-size furniture in a fixed hierarchy: opponent
status/team at the safe top, an unobstructed fight, player status/team, then
one continuous bottom text/command frame. Portrait MAP/DISCS cameras tilt
around the unchanged battle midpoint to show useful ground instead of a large
empty sky cap without stretching the world or moving either ground anchor.
ARENA scenery now keeps its aspect ratio through rotation by cropping the
excess instead of squeezing the painting, and Q/E, wheel or pinch can adjust
the authored ARENA lens from its reviewed 3X opening.

Rain, snow and fog have been rebuilt as layered atmospheric effects rather
than repeated pixel stripes. The project-supplied VASC animation collection
is now converted deterministically from `PkmnAnimations.rxdata`: the package
contains 230 executable programs and 92 hash-recorded effect sheets. Gen 1
move animations are available in standalone VASC; later-generation programs
are exposed only when KASC is active. Focus metadata is preserved so every
player move starts at the player's Pokémon and opponent programs run in the
opposite direction. The six KASC moves without an exact supplied record use a
reviewed same-type substitute instead of becoming invisible.

KASC Mega sprite animation now has a fail-safe liveness watchdog for stale
hot-reload state while still delegating frame choice to KASC. Both teams'
remaining-Pokémon rows also stay visible during the normal command phase using
VASC's original Poké Ball artwork: the original soft-red healthy tint and
grey fainted ball with its single diagonal slash.

This corrective RC retains the full 2.0 presentation while closing the first
device and community findings: ARENA presentation orientation is normalized,
Mega and large battle sprites use form-aware grounding and separation, iOS
canvas presentation is guarded, precipitation/fog are restrained, and city
shadows are capped instead of producing oversized dark masses. Outdoor ARENA
nights now show a real cratered moon and varied stars through the scenery's
transparent skyline; reviewed interior windows follow the same smooth
dawn/day/dusk/night state without tinting opaque walls or greenhouse panes as
open sky.

The VASC menu now includes START help even without Kanto Ascendant. Users can
drop their own music into seven category folders and select ORIGINAL, SHUFFLE
or an exact local file. PNG replacement folders cover Pokemon front/back/Dex/
icons/overworld, the player, enemy trainer portraits and generic overworld
sprites. No third-party music or replacement sprite is bundled.

VASC 2.0.2 also contains the additive visual half of KASC 6.7's future
Cinnabar south fork. Only a complete outdoor, reciprocal map graph activates
it: the volcanic destination is fixed on the left and the Deoxys/Birth-Island
research coast directly beside it on the right. The two transparent cut-outs
share one compact 256-KiB atlas and one draw. Existing KASC builds, partial
hot-patches, missing art and malformed offsets retain the current Cinnabar
coast with no movement, collision, warp, NPC or quest change.

This major update substantially expands the outdoor and enclosed-world presentation
and shortens the long catch-up path when voxel maps become visible. Visual
release acceptance remains evidence-driven; the packaged contract tests do not
by themselves certify every route, cave or transition viewpoint.

This RC also fixes a Gen1Recomp 0.2.19 zero-fade ownership change that could
leave `transitioning` set forever after Fly reached a cold 3D destination.
The existing dynamic reveal gate remains intact: it releases immediately when
the complete destination is ready rather than adding a fixed delay. Dedicated
`V` and mapped right-trigger (`ZR`/`R2`/`RT`) shortcuts now cycle the same
camera ladder as `3`; RC5 removes the former SELECT alias centrally.

Kanto now has a switchable banded sky with sun and pixel clouds. The saved
DAYTIME control includes a color-coordinated 20-minute CYCLE; nights add the
moon, stars and occasional shooting stars. WEATHER can stay CLEAR, choose
stable AUTO spells, or force lightweight RAIN, SNOW, FOG or STORM. Fog uses a
small fixed set of drifting haze bands; storms add denser rain and rare,
deterministic lightning pulses. Every active effect carries into staged
outdoor battles, while indoor fights stay clear. SKY, CLOUDS, WEATHER and
SCENERY remain independently switchable for performance-sensitive devices.
Clouds, stars, shooting stars and every celestial body are fixed to world
bearings in both orbit and freely turning cameras instead of rotating with the
screen. The separate SKY EVENTS ladder enables rare rainbows and distant sky
life together, by class, or not at all. Ordinary windows rotate Pidgey,
Pidgeotto, Pidgeot, Spearow, Fearow and Murkrow through solo flights or compact
formations; Articuno, Zapdos, Moltres and Ho-Oh are much rarer and always fly
alone. Idle/OFF frames issue no event draw calls and the rare cadence persists
with the save.

Outdoor worlds and MAP battles now share an original, player- or arena-centred
Kanto distance panorama behind the real streamed maps. It supplies a coherent
far forest, town, memorial-tower, mountain and coast silhouette without
stretching the final map tile or packing the near edge with artificial land.
The existing 16px edge breathing room, water continuation, foreground trees,
reviewed map-aware edge curtain, authored landmarks and connected map bodies
remain in front; the panorama never replaces that near composition. The battle-camera
1X/2X/3X rigs are unchanged; 3X remains the default and widest view. Interiors
and DISCS battles do not draw this outdoor layer, and any asset/graphics
failure retains the previous horizon wall.
The retained panorama is a deliberately compact 1024×192 nearest-filtered
texture: 768 KiB of GPU storage rather than the visually equivalent 3 MiB
prototype. It is decoded lazily on the first outdoor SCENERY=FULL frame,
cached across ordinary map/interior changes, and released when SCENERY is
turned OFF.

Map edges no longer enlarge an arbitrary border tile into wallpaper. A small
cached transparent skyline supplies layered, varied trees, water reeds,
stepped mountain ridges or stratified cave rock according to the map. It
replaces the expensive carved border ring on semantic outdoor/cave maps,
remains visible from first/third-person and elevated orbit cameras, and uses
32px connection-aligned panels. A separately tiled canopy/ground surface and
four corner caps prevent the stretched horizontal strips and open high-view
corners of the earlier implementation. This also avoids turning Route 23
statues or transition art into giant repeated walls.
Tree silhouettes use a coarse outlined pixel grid and a one-device-pixel,
nearest-filtered source without MSAA or mipmaps, preventing isolated distant
forest panels from becoming soft on high-DPI displays.
Viridian Forest now closes its former black void with a muted canopy colour
derived from the active time of day. The canopy never exposes open-sky bodies,
but remains an outdoor weather space for fog, rain, snow and thunderstorms,
including staged battles inside the forest.
South and west of Cinnabar, and along the adjoining sea routes, unconnected
water edges now continue as a curved, reflective open ocean instead of a
procedural mountain/tree barricade.
The sparse distant South Sea motifs now use irregular V3 rock feet and
transparent gaps rather than a continuous foam/water baseline. Route 19,
Route 20, Route 21 and Cinnabar still own exactly one distinct motif each;
Dock and the SS Anne bow retain their established lighthouse/skerry reuse.
The replacement keeps the same single 512x128 texture, one aggregated draw
and curve-safe coastal mesh. Transparent atlas padding is excluded from the
billboard UVs, so visible pixels now map one-to-one into world space instead
of being anisotropically squeezed with the complete 128px module.

Semantic caves and all Pokemon Tower floors now close above the camera with a
160px enclosure and a downward-facing ceiling tessellated on the same 32px
WorldCurve grid as the world. Cave tilesets select this path even for future or
renamed maps; Mt Moon's named Pokecenter and Rock Tunnel's Pokecenter are kept
as indoor rooms. Pokemon Tower replaces the previous small repeated brick and
panel stamps with one shared opaque two-bay wall and broad coffered ceiling,
without adding a third draw or changing collision. Missing package art fails
closed to the old opaque material rather than revealing the clear colour.

Open-sky routes, towns and mountain regions now share a fixed distant Kanto
ridge behind their local foreground instead of carrying the scenery with the
camera. Route 1 and Viridian replace the two raised green side slabs with a
compact low-rise town edge, distant sprite trees and two sparse rows of real
batched voxel trees. The sheltered Viridian Forest canopy, caves, interiors
and the southern open sea intentionally do not receive an implausible mountain
backdrop.

PRELOAD safely warms the current map and its connected neighbours while voxel
mode is off. It is RAM-only, bounded to the live/previous neighbourhood and
generation-checked: map edits invalidate derived meshes and no stale cache is
written to disk. Repeated forest, grass and building geometry is retained as a
small set of shared templates plus instance offsets instead of hundreds of
thousands of expanded Lua quads. Connected maps rotate through the available
frame budget, and route-sized indexed GPU conversion is split into
1,024-vertex upload pages instead of one uninterruptible main-thread call.
The renderer keeps showing the complete 2D world until current terrain, grass,
flowers, figures, exact atlas/mask and panorama are drawable together. The
finished 3D scene then appears in one swap without freezing the transition or
letting decoration pop in later. A separate bounded loading budget keeps that
fallback responsive; only a real fade or menu uses the larger covered-frame
budget.

One-way ledges now also shape the visible land. Their authored lip tile already
stands 6px high, so it stays on the lower base while the plateau behind it is
raised. This makes stacked Route 4 terraces meet cleanly at 18/12/6/0px instead
of producing accidental double-height teeth. Terrain, shores, buildings,
vegetation, figures, entities, camera grounding and shadows use one immutable
snapshot; collision and the engine's jump rules are untouched.

Outdoor building backs now synthesize their wall from a repeated clean 8x8
source tile. Arbitrary front windows and signs can no longer leak onto that
wall. Door-bearing OVERWORLD and FOREST templates then restore their own
unambiguous native 2x2 door course on the rear facade. Route 2 and Cerulean use
their already-authored aligned rear warps; the other matching houses receive
only the visual counterpart and never invent collision or a destination.
Indoor furniture keeps its authored historical behaviour.

The trainer-front repair is also updated for Kanto Ascendant 6.7's live sprite
hooks. TRAINER BACK and PKMN BACK remain independent, and 1ST/3RD, battle grid
and shadow controls from 0.1.7/0.1.6 remain intact.

Staged fights also gain a saved **BTL CAM** distance. 1X is the close view, 2X
the middle ground and 3X the default wide view for new saves. FULL never
overwrites an existing choice. Q/E, mouse wheel and pinch still fine-tune the
live camera up to 3X after the setting is applied; the original 2D battle
screen and HUD are untouched.

The new opt-in **ARENA** battle rung supplies 46 independently painted Kanto
locations across all 111 reviewed battle anchors and supported city trainer
fights. ARENA alone uses per-location 3X footing and reviewed indoor scale;
MAP, DISCS, their floor plates and the classic battle retain their existing
positions and sizes. The ARENA CAM row offers a fixed 3X composition or the
STADIUM director. Outdoor scenery keeps the live sky, and rooms with real
windows follow the overworld's smooth AUTO/day/night/dawn/dusk tint without
turning windowless interiors blue or dark.

When Kanto Ascendant is active, its public ASCENDANT collector now receives a
single **VOXEL ASCENDANT** row that opens the normal VASC settings. Discovery
is runtime-only: KASC remains optional and its bundle is not modified.

The opt-in **USER MUSIC** row scans local MP3, OGG, WAV and FLAC files live.
KASC-style submenus group wild, trainer, rival, Gym, Elite Four, Champion,
field, bicycle, surf, victory, evolution, title, Hall of Fame, credits,
jingles and scripted scenes. `replace/<ORIGINAL_SONG_ID>.<ext>` can replace
any additional resolved Game/KASC cue without adding another option row.
ORIGINAL/SHUFFLE/exact-file choices remain independent by category.

The opt-in **USER SPRITES** row resolves readable PNG names for every Pokémon
front/back/Dex/icon/overworld role, KASC Mega aliases such as
`CHARIZARD_MEGA_X`, player battle art, enemy trainers, and registered
Game/KASC overworld sheets such as `SPRITE_KA_CRYSTAL_GREEN_BIKE`. Both user
systems default to and can return immediately to **GAME/KASC**, bypassing all
VASC replacement providers without deleting personal files. Version 2.0.2
also adds one global **ALL TO GAME/KASC** action and detailed English/German
guides inside both user folders, including the installed paths for Windows,
macOS, Linux, iOS, Android, Switch and Xbox. It contains no third-party
soundtrack, Pokémon character-sprite pack or network downloader; the separate
project-supplied VASC battle-effect sheets are documented with individual
hashes.
