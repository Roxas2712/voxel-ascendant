# Human grid motion — implementation and QA history

Current status: the normal mod entry point supports grid/cube human motion in
natural mode for reviewed rig profiles. The 19-file review bundle includes it;
full character/acting/performance acceptance remains incomplete.

Historical prototype stage (superseded by the final integration section):
A standalone LOVE prototype now constructs grid/cube occupancy from the same
neutral-upper/walking-lower composite used by the flat rig. It transfers the
flat rig's XY displacement field to every existing cell surface, preserving
Z values, per-face shade and topology. Feet in the lowest 4% of the mesh must
remain fixed by assertion. This avoids flattening the model and avoids retaining
old step-arm fragments in the occupancy mask.

Red and Bug Catcher were rendered in all four directions, neutral/A/B, for grid
and layered cubes (48 cells total). The images were inspected. The prototype
initially lacked the gallery's depth buffer and clipped deep cubes in its simple
projection; the final gallery has a depth buffer and normalizes projection Z.
These were prototype presentation faults, not reported production renderer bugs.

The first-cell path reads back the composed canvas, scans its alpha, constructs
occupancy/geometry, transfers motion and allocates a mesh. Latest local timings:
grid-prototype-grid.log: 24 cells; build min/median/max 15.325/20.547/59.176 ms
grid-prototype-cubes.log: 24 cells; build min/median/max 14.682/19.627/30.658 ms

These are unisolated wall-time samples, not production frame-time measurements.
The cost is too large to perform synchronously for newly visible characters.
Next implementation work must split preparation across frames, cache immutable
cell geometry/weights, reuse actor meshes and preserve fallback while pending.
Native Gen1/Gen2 integration, blink texture composition, cache eviction, option
roundtrips, actual gameplay and broad source coverage remain unimplemented for
this path. The layered-cube look also needs in-engine camera evaluation.

QA source: qa/vasc-human-motion-native/grid-motion-prototype. It uses the local
development checkout and is an experiment, not a portable installer payload.
The existing review package's 72/198 arm-source coverage is unchanged.


## Scheduled preparation and alpha scan, 2026-09-11

The experimental grid-motion-scheduled runner resumes a coroutine once per
update and checkpoints alpha rows, generated quads, interpolation and validation
work against a 2 ms soft budget. Latest 24-cube-cell run: 187 slices,
median 2.020 ms, maximum 3.002 ms. Native GPU allocation/readback,
Lua GC and scheduling cannot be preempted by these checkpoints; this is not a
hard frame-time guarantee. Flat composite preparation still happens before this
experiment's jobs, so these numbers are not complete native startup timings.

All 24 serialized vertex/index hashes match the unbudgeted baseline, including
Red/Bug Catcher in four directions and three poses. The direct alpha-byte buffer
experiment did not improve timing and was removed. The production alphaBounds
scan now updates its bounding rectangle once per occupied row instead of once
per opaque pixel. A comparison against its previous implementation covers 198
atlases / 2376 cells, both occupancy grids, synthetic alpha thresholds, 3/4
columns, empty sources, authored layouts and checkpoint counts. All match exactly.
In the interleaved catalog run, old/new total scan time was 7.400/6.985 seconds;
this approximately 6% difference is a local result, not a global FPS claim.

Logs: alpha-row-scan.log, grid-scheduled-baseline.log,
grid-scheduled-row-scan.log and grid-scheduled-row-budget2.log. The scheduled
prototype is still outside the installed renderer. Immutable geometry caching,
actor-mesh reuse, native fallback while queued, cancellation/eviction and actual
Gen1/Gen2 runtime integration remain the next required work.


## Experimental shared geometry and mutable actor cache, 2026-09-11

The new QA-only grid_motion_stencil.lua prepares interpolation references once
per cell. grid_motion_cache.lua shares that immutable topology while retaining
separate mutable meshes per actor. Identical pose keys skip deformation/upload.
Template and actor mesh counts are LRU-bounded; evicting a template releases its
associated actor meshes. clear() releases all retained meshes and is idempotent.
Nil/throwing allocations return failure without retaining a mesh. Failed
position validation or upload invalidates the pose key so a previous valid pose
cannot incorrectly reuse partially updated GPU data.

The grid-motion-cached runner compares every GPU float32 vertex component to the
independent previous interpolation path for all six heroes and Bug Catcher:
4 directions x 3 cells x 7 roles x 2 styles = 168 cells. All match exactly.
The Red/Bug Catcher cube hashes also match the earlier unbudgeted 24-cell run.
Each cell additionally exercises 120 synthetic translations of the flat mesh
(20,160 updates overall), asserting mesh reuse and changed interpolated positions.
These synthetic updates exercise the transfer/cache; they are not a native
walking playthrough or evidence that every acting pose is visually finished.
Separate actor changes leave the first actor and source geometry unchanged.
The real tests deliberately cap retained templates at 3 and actor meshes at 4,
assert those caps throughout, then verify full cleanup. A fake-mesh test also
covers LRU order, allocation failures and partial upload failure recovery.

Reusable pose buffers remove per-update displacement table allocation. This is
not yet a demonstrated speedup: non-isolated runs varied. In the latest 120-update
samples, the median of per-cell medians was 0.983 ms for grid and 0.876 ms for
cubes; maximum individual updates were 2.538 and 2.989 ms. Measurements include
reading flat vertices, interpolation and mesh upload, but exclude flat-rig pose
creation, drawing, and whole-game frame cost. Many simultaneous actors can still
be expensive. The runner's overall preparation/transfer timings now include
assertions and 120 benchmark updates and must not be compared with the earlier
single-preparation timing. Gallery output displays the reference meshes whose
vertex data was compared exactly, not a live native cache renderer.

This experiment remains outside the 14 installed mod files. Production grid/cube
animation is still disabled. Native preparation queue integration, identity keys,
byte/resource budgets, cancellation on map/options/source changes, fallback while
pending or failed, eyelid composition, Gen1/Gen2 gameplay and camera/performance
acceptance remain required. No Orange engine or session was used.

Evidence: grid-cache-test.log, grid-cached-grid-reuse.log,
grid-cached-cubes-reuse.log, grid-cache-results.json. Experimental files are in
experiments/grid-motion-cached, experiments/grid-cache-test and the two
experiments/grid_motion_*.lua modules; paths still target the local QA checkout.


## Cancellable construction and admission, 2026-09-11

The experimental grid_motion_preparation.lua uses the renderer's existing
newAnimationQueue (the test extracts the actual function). Demand is bounded;
only completed resources are returned. Pending/failed resources return nil for
the eventual renderer fallback. A changed generation token or disabled animation
cancels unfinished work and disposes ready resources. Disappearing demand is
pruned. Failed sources remain negatively cached while demanded, preventing a
per-frame decode retry. This is currently an API-level fallback/cancellation
test, not proof of native menu/map wiring, which remains to be implemented.

The actual grid_motion_builder.lua now wraps canvas readback, occupancy scanning,
mesh creation and stencil extraction in a cancellable factory with cleanup.
It yields explicitly after readback and mesh creation, and cooperatively during
CPU work. Temporary image data and geometry are released on cancellation, failure
or successful transfer of the CPU shape. The composed texture/flat mesh remain
borrowed; the future caller must maintain their lifetime until cancellation or
completion. Native resource tests cancel at both explicit GPU boundaries and
verify release of all four created meshes and five readbacks across the complete
suite. Neutral root/scale are also checked at 16 and 24 world units; the stencil
now accepts distinct flat-input and output scales rather than assuming preview
pixel coordinates. Scene identity and source-version tokens must still be wired
at the native call site.

The cached geometry runner now obtains its shape through this builder. All 48
Red/Bug Catcher grid/cube cells again match the old interpolation's GPU vertices
exactly. The 168-cell all-six cache evidence in the preceding section predates
this builder connection; the builder connection itself has 48-cell coverage.
No production grid/cube enablement or installer payload changes are implied.
Evidence: grid-preparation-test.log, grid-builder-test.log, grid-builder-grid.log,
grid-builder-cubes.log; corresponding modules and runners are in experiments/.


## Native renderer seam, 2026-09-11

voxel_characters.lua now accepts an optional humanGridModule. The normal mod
entry point does not supply it, so installed grid animation remains disabled.
The private integrated-grid-motion.lua driver injects grid_motion_native.lua
into the actual renderer. It constructs a flat rig input at the native height,
queues the composed grid/cube shape, then substitutes a ready per-actor grid mesh.
Pending/failed preparation keeps the existing card. Native prepared-frame hooks
pump the queue; the generation token includes the human presentation epoch,
map and player identity. Classic, HD-off, scene suppression and renderer restore
clear the optional grid path. Optional-module exceptions are caught and disable
it while preserving the original render path.

Native tests now pass in Red (Red actor) and Crystal (Gold actor). Both exercise
balanced cube depth, ready rendering, classic/Vanilla/dialog off-and-on rounds,
a real map transition, visible blink composition and actual input-driven walking.
Native screenshots were inspected, but they are small full-scene captures and
do not establish final artistic quality or all-six native acceptance. The first
Red attempt used the unknown depth value 'medium', which resolves to shallow
grid; subsequent retained runs explicitly use the valid 'balanced' setting.

The initial native walk revealed avoidable repeated fallback: 56 ready draws and
264 pending draws in 160 walking frames (two render passes per frame). Keeping
recently demanded cells for 1.5 seconds, capped at 24, avoids discarding each
step variant as soon as the next step appears. Context/option changes still
clear immediately. Latest Red cold pass: 224 ready / 96 pending. The following
160-frame warm pass is 320 ready / 0 pending in both Red and Crystal. These are
render-path counts, not frame-time or general crowd-performance measurements.
An injected preparation exception in Red also verifies fault containment and
release of cached actor meshes. Canonical human_motion_runner exited 0 with
no stdout, and installer apply/rollback passes for the updated renderer seam.

Remaining before general activation: byte budgets and source/resource lifetime
review, efficient cold prewarming, all-six native direction/pose inspection,
source/action rebinding and broader cube/shading modes, frame-time/crowd testing,
and bundling the experimental modules through the normal entry point. Existing
72/198 reviewed arm sources and the remaining facial/acting scope are unchanged.
No Orange engine or session was used.

Evidence: integrated-grid-motion.lua; grid_motion_native.lua; grid-native-red-
retained.log, grid-native-crystal-retained.log, grid-native-red-before-retention.log,
grid-native-seam-installer.log. QA injection modules are under experiments/.


## Resource budgets and reported character lines, 2026-09-11

Experimental cache limits now include 128,000 template vertices and 8 MiB of
accounted vertex/index buffer payload, in addition to 24 templates / 32 meshes.
The payload calculation is six float32 components and conservatively uint32
indices; it does not claim to measure driver memory or Lua table overhead.
The preparation controller separately limits completed shapes to 128,000 vertices.
Oversized cache entries are rejected before mesh allocation. Budget pressure
uses existing LRU eviction; rejected preparation stays negatively cached while
demanded. Invalid weight functions/values are contained, and clear/prune returns
accounted resources to zero. Temporary work and borrowed source textures still
require their own lifetime controls; these are not total-process memory caps.

Native six-actor tests cover all six heroes in all four directions in both Red
and Crystal (48 direction/role/gen samples). Counts and accounted payload remain
bounded and classic mode clears them. Screenshots include five visible clones
and the player, which can overlap a clone; they are not six distinct AI agents.
Budget tests and native logs accompany the experiment. Repeated unchanged poses
also reuse their interpolation inputs, avoiding flat-vertex reads on every pass;
no whole-frame speedup is claimed from that change alone.

The user's reported lines were reproduced with the character grid. atlasCardMesh
previously inset each cell (7% shallow grid, 0.6% cubes) and shaded side faces at
0.035. Natural human rendering now uses exactly shared cell/UV boundaries, no
inset, and sprite-colored side faces. Hidden internal shallow-grid faces are
removed. Classic calls preserve the old defaults and explicit false path exactly;
Pokemon and non-human presentation do not opt into continuous surfaces.
The optional native builder uses the same surface mode. This surface correction
also applies to natural human base cards without the experimental grid module.

human_continuous_grid_test verifies exact joins, non-black natural surfaces,
classic/default equivalence and internal face removal. The full regression
runner passed, including 198 atlases/2,376 cells and Gen1/Gen2 seams. Native Red
passes shallow grid and balanced cubes; Crystal passes balanced cubes, including
blink, walking, toggles, map changes and injected failure. Red was also checked
with the grid off; its screenshot shows no comparable raster lines. These are
specific verified presentations, not proof that every possible source is free
of unrelated artwork defects. The user could not confirm their raster setting.
Before/after shallow-grid screenshots clearly show the reproduced line removal.

The latest warm walk stayed at 320 ready / 0 pending draws in Red; Crystal's
latest balanced run had 304 ready / 16 pending. Thus the previous zero-fallback
sample is not universal: cold/retention work and unisolated stalls remain open.
Installer apply/rollback passed after this surface fix. Production grid arm
motion remains gated behind the optional QA module; the full goal remains open.


## Normal mod integration and resident lookup, 2026-09-11

The normal entry point now loads five human_grid modules and supplies HumanGrid
to the renderer. Natural + HD people + human grid selection activates grid arm
motion for the reviewed rig sources. Classic is still the option default; the
existing scene/action/profile admission and missing-art fallbacks remain. The
module group loads under pcall: any missing module disables this optional path
and warns while preserving existing character cards. human_grid_loading_test
checks success and each of five missing-module cases against the actual loader
block. The review installer now contains 19 payload files and passes apply and
rollback with the additional modules.

Cached templates are now looked up directly before submitting preparation.
Completed work is removed from the preparation controller, whose lifetime no
longer determines whether a previously prepared cell can render. Lookup refreshes
LRU usage; limits still evict old cells. Runtime texture identities use monotonic
IDs attached through weak keys rather than textual pointer addresses. Actor
interpolation state is refreshed if its cached shape object changes.

The native test explicitly clears completed preparation while a prepared player
is visible and verifies that drawing continues without pending fallback or a new
preparation job. The initial outdoor version of this assertion also counted
other pending human actors and failed; the targeted test now uses an interior.
This does not claim that every outdoor actor was already ready. A separate first
normal-entry run hit the prior fixed-frame startup assertion; the driver now
waits up to three seconds for the actual admitted human render state. Subsequent
normal-entry Red and Crystal runs pass with no QA module injection, including
classic/Vanilla/dialog roundtrips, map change, blink, real input walking and an
injected queue failure. Both final warm runs report 320 ready / 0 pending draws.
These remain bounded samples, not a universal no-stutter claim.

QA wrappers now load the actual installed module files. Cache/budget and
preparation tests pass against those files, as does the full human regression
runner. See grid-installed-{red,crystal}.log, grid-installed-cache-test.log,
grid-installed-preparation-test.log, grid-installed-regression.log and
grid-installed-installer.log. Historical experiment sections above describe
older states and are superseded by this integration status.

Remaining scope includes the 126 pending arm-source reviews, additional facial
and acting poses, action/source rebinding tests for this newly installed path,
cold prewarming, broader depth/shading/crowd performance and artistic acceptance.
The overall goal remains incomplete; no Orange environment was used.


## Action, identity and unavailable-atlas roundtrips, 2026-09-11

The normal installed grid path now has native rebind tests. Red -> Green -> Red
and Gold -> Kris -> Gold select their own cached geometry, with a distinct shape
for the replacement identity. Marking a special action stops additional human
grid drawing and clears its motion state; removing the marker resumes animation.
These are renderer rebind tests, not full scripted performances for every actor.

The missing-source test injects actual targeted Assets.image/imageData failures
and invalidates the renderer's atlas entry. This found a real Gen2 fallback
issue: a preloaded role card remained available and still received natural
animation when the explicitly assigned atlas was unavailable. The draw path now
excludes such fallback cards from human motion. Source resolution also clears
human motion clocks on atlas failure even if no fallback card is drawn at all.
Restoring the valid source resumes animation. Native Red/Crystal tests pass;
the core Gen1/Gen2 seam test compares a preloaded fallback against classic mesh,
texture and transform, then verifies recovery. This does not change the existing
availability of preloaded static role cards.

The first filename-only fault probe was not a reliable missing-file simulation
under live identity binding and was replaced with the targeted loader fault.
Early test admission also failed while humanScene returned false with a stack
entry present. The harness now selects its quiet interior before waiting for
normal rendering; production scene admission was not weakened. Diagnostic/failing
logs are retained rather than represented as passes. The test runner retains its
real quit/report functions so a test's fake love table cannot mask an assertion
with a second shutdown error.

Evidence: grid-rebind-red.log, grid-rebind-crystal.log, grid-rebind-regression.log,
grid-rebind-installer.log and integrated-grid-rebind.lua. Full human regression
and installer rollback pass. Four leader atlases (Sabrina Gen2, Lt. Surge, Blaine,
Falkner) received initial source/hand inspection only; no new rig profiles were
admitted yet, so arm coverage remains 72/198 with 126 pending.
