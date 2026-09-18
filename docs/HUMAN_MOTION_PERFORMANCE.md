# Integrated human animation performance — 2026-09-10

## Final local seven-card and seated acceptance — 2026-09-11

The current renderer completed four 600-frame workloads in both generations
with the player plus six exact hero cards. Natural Walk frame p95 was 17.369 ms
in Gen1 and 17.402 ms in Gen2; maxima were 17.605 and 17.595 ms. Rig preparation
used 0.332/0.460/0.560 ms mean/p95/max in Gen1 and
0.377/0.678/0.984 ms in Gen2. Blink preparation used
0.008/0.016/0.041 ms and 0.012/0.029/0.178 ms respectively. Natural Idle also
stayed below 17.8 ms maximum in both runs. The only 37.005 ms interval occurred
in Gen1 Classic Walk and contains 23.921 ms in the native event pump.

Daisy's real seated idle measured 0.0014 ms mean blink preparation and reached
full closure. Its seat pose lookup used 0.0026 ms mean; cached preparation used
0.0065 ms mean. Red's mother's revised single-source head turn used 0.0257 ms
mean, 0.0505 ms p95 and 0.1020 ms maximum. Removing the unused optical-flow
path also removes eight 256 KiB buffers and reduces its cooperative cold load
from fifteen to six slices. The largest remaining native decode/upload slice
was 26.58 ms during map-entry preparation; the acting pilot is default off.

Both actual New Bark seats again pass full blink/head-yaw, no old-atlas draw in
Natural, exact Classic atlas restoration and Natural return. The complete
198-source regression passes after these measurements. This establishes local
Native Engine acceptance for the tested seven-card, home-seat and dialogue
loads; machine-specific operating-system or graphics-driver stalls remain
outside a single-host test. Full raw evidence and screenshots:
`final-performance/` in the review package. No Orange environment was used.

## Free-form acting blink — 2026-09-11

Acting atlases can now carry exact full-atlas eye regions. The existing blink
service retains its 32-owner LRU and shared procedural shader, but allocates a
full-size temporary canvas only for a currently acting owner. Open eyes return
the original texture after the single cold warmup; changed closure amounts
repaint the bounded canvas. Direction/source changes invalidate prior content,
and teardown releases every owned canvas and shader.

Professor Elm's 1254x1254 GPU check changed 2,009 color pixels inside the two
front eye regions while preserving alpha and every pixel outside their reviewed
padding. Its 120 submitted closure renders measured 0.080 ms mean, 0.083 ms p95
and 6.276 ms maximum on this host. These are local observations, while the
full-atlas dimensions, containment, source invalidation and resource release
are asserted. The real Gen2 laboratory run also completes without a visible
stall and captures the closed-eye diagonal view. Evidence: `elm-diagonal/`.

## Continuous planted step transfer — 2026-09-11

Human rig meshes now add a small continuous torso rise and alternating balance
under the authored neutral/A/B cadence. Both use the existing smooth stride;
the rise uses `stride²`, and both weights fade to exactly zero at the sole.
No texture blend, lower-body reflection, new canvas or extra mesh is involved.

The geometry regression verifies symmetric rise for both stride signs,
opposite torso balance, an unchanged sole and exact neutral restoration. Native
Gen1 and Gen2 runs exercise both side-step phases for all six heroes, source
stability, settling, Classic and Vanilla shutdown. The full 198-source runner
and 84-source GPU body comparison pass.

Seven-card Natural Walk after the change:

| Fixture | Mean interval | p95 | Maximum | Rig mean / p95 / maximum |
| --- | ---: | ---: | ---: | ---: |
| Gen1 | 16.830 ms | 17.417 ms | 80.965 ms | 0.341 / 0.495 / 1.678 ms |
| Gen2 | 16.667 ms | 17.377 ms | 17.712 ms | 0.260 / 0.296 / 0.371 ms |

The Gen1 maximum contained 73.360 ms in `present`; other large frames were in
general draw/event work. Rig preparation does not account for those stalls.
This runtime transfer softens body motion but does not replace later authored
improvements to side A/B art that is visually very similar. Evidence:
`step-transfer/` in the review package. No Orange environment was used.

## Frame-budgeted cold blink preparation — 2026-09-11

The first idle visit to several distinct eye profiles previously created each
profile's shader/image resource, output canvas and offscreen warmup in the same
presentation frame. Open-eye preparation now admits at most one cold exact
profile per prepared human frame. Further open-eye profiles are deferred to
later frames. An active closure always renders immediately, so the scheduler
does not delay a visible blink. Warmed profiles retain the existing fast path.

A real LOVE GPU A/B exercises twelve distinct exact profiles, five packed and
seven procedural, in both baseline/candidate orderings. The synchronous
baseline performs twelve warmups with no deferrals in its first frame. The
candidate performs twelve warmups over twelve frames and records 66 repeated
open-eye deferrals. Baseline-first maxima were 32.481 ms baseline and 18.025
ms candidate, with a 4.565 ms candidate first frame. Candidate-first maxima
were 9.659 ms candidate and 16.711 ms baseline. Shader caching and host load
make these timings observational. The asserted one-cold-profile-per-frame
limit is deterministic.

Native seven-card tests inject the six exact hero sources plus the player and
exercise Classic/Natural Idle and Walk for twelve seconds each, using the
engine's native 60-Hz pacing with VSync off. Natural Idle results:

| Fixture | Mean interval | p95 | Maximum | Blink prepare mean / maximum |
| --- | ---: | ---: | ---: | ---: |
| Gen1 | 16.667 ms | 17.200 ms | 28.608 ms | 0.022 / 0.124 ms |
| Gen2 | 16.667 ms | 17.245 ms | 17.758 ms | 0.025 / 0.114 ms |

The Gen1 maximum was in general draw work; a separate 25.485 ms frame was in
the event pump. Blink preparation does not account for either outlier. Gen2
Natural Walk also remained within 17.665 ms maximum in this run. Classic
blocks produced larger unrelated present/event outliers in both generations,
so these runs do not prove whole-game stutter is eliminated.

The full regression runner passes after the scheduler change. GPU body parity
also passes for all 84 eye sources, 996 cases and 36,976,500 pixels. Evidence:
`blink-warmup-budget/` in the review package. No Orange environment was used.

Private non-Orange engine 0.2.57 fixture, LOVE 11.5 on this Mac, 960×720.
One hero in the same indoor scene per generation. Six 7-second blocks:
classic, natural with eyelids suppressed, scheduled eyelids, continuously
changing eyelids (stress only), suppressed eyelids, classic. First second
excluded from steady samples. No screenshots during measurement. This does
not establish mobile or many-actor performance.

The engine reported `hardwarePacesCap=true` while VSync was OFF, bypassing its
60-Hz software limit. The paced benchmark applies a QA-only adapter requiring
VSync ON before trusting hardware pacing. This adapter is not in the VASC
payload and does not modify the user's game or Orange. Uncapped raw results
are retained separately and must not be described as 60-Hz display tests.

Final scheduled-eyelid blocks:

| Fixture | Mean frame interval | p95 interval | Maximum interval | Mean draw time | Texture memory |
| --- | ---: | ---: | ---: | ---: | ---: |
| Red / Gen1 | 16.668 ms | 17.516 ms | 17.745 ms | 1.576 ms | 41.33 MiB |
| Kris / Gen2 | 16.667 ms | 17.564 ms | 17.915 ms | 0.886 ms | 43.11 MiB |

Continuously changing eyelids averaged 1.640 ms draw time for Red and 0.994 ms
for Kris. Natural without eyelids ranged 1.551–1.786 ms and 1.061–1.147 ms,
respectively. These block differences include scheduling/background variation;
they are not isolated GPU costs. Gen1 had an 83-ms classic outlier and an
87-ms eyelids-OFF outlier. There is no evidence here that blinks explain all
reported lag, nor a proof that the overall game cannot stutter.

The first natural transition's maximum measured draw was 13.444 ms (Red) and
12.788 ms (Kris). Earlier Red runs reached 18–21 ms before the final geometry
reduction. This is limited observational evidence, not a universal load-time
bound. Eyelid warmup now executes the closed-eye path offscreen; native tests
prove that the first full closure can reuse the prepared output while open
eyes still return the original texture.

Human arm meshes now retain dense subdivisions only in the moving shoulder
band. Counts fell from 3,072 to 1,056–1,248 vertices per row (59–66% fewer).
A comparison against the previous dense implementation checks all six heroes,
four directions, neutral/A/B phases and flat/relief geometry. World position
and shade agree within 1e-5 at every previous sample; UV coverage is retained.
This proves the removed static rows were redundant for that surface.

Evidence: integrated-perf-red-reduced.log, integrated-perf-kris-reduced.log,
rig-reduction-all-six.log, closed-warmup-resources-red.log. Native benchmark
and geometry oracle scripts remain in qa/vasc-human-motion-native. The full
release still requires remaining NPC profiles, expressions, grid support and
broader play testing. Further devices and larger mixed casts remain to be measured.

## Actual input walking follow-up

`integrated-walking-perf.lua` uses real left/right input, switching every750ms
in the disposable indoor lane. Four7-second blocks classic/natural/natural/
classic, first second excluded; same QA-only pacing adapter. Each block
traversed345–420 world pixels. Gen2 retains its ordinary follower, so these
are whole-scene timings, not isolated human costs. No screenshot capture.

| Natural blocks | Mean frame intervals | p95 intervals | Maximum intervals | Mean draw times |
| --- | --- | --- | --- | --- |
| Red / Gen1 |16.728 /16.714ms|17.792 /17.883ms|38.584 /34.557ms|3.101 /2.918ms|
| Kris / Gen2 |16.666 /16.667ms|17.576 /17.586ms|18.370 /19.582ms|3.228 /1.895ms|

Classic maximum intervals reached40.091ms in Gen1 and45.366ms in Gen2.
Scheduled blink frames were zero while walking, as required. Eye output was
rendered at most once in a draw (initial warmup), then zero during continuous
movement. Arm updates reached two per draw in Gen1 and one in Gen2; these
counts include separate mesh variants and do not alone prove duplicate work.
The initial natural transition reached17.667/17.756ms; preload remains a
potential improvement. These measurements do not establish universal60fps.
Evidence: integrated-walking-perf-red.log, integrated-walking-perf-kris.log.

## Six-copy idle renderer stress

QA-only pose injection adds five separate Red SpriteRenderer instances to the
player's scene. All six get independent animation clocks (asserted). This is
a renderer scaling test using one shared artwork source, not a test of six
different cast assets or real NPC AI. Classic/natural/continuous-blink/classic
blocks use the same method and pacing adapter.

Scheduled natural averaged16.779ms between frames (p9517.722,max40.769),
mean draw3.321ms, with42.03MiB total texture memory versus39.11MiB before
natural allocation. Continuous closure averaged16.666ms (p9517.562,max26.068),
mean draw3.395ms. Classic also produced a44.508ms interval outlier. First
natural transition reached39.992ms: simultaneous cold setup remains a visible
hitch risk and must be improved before general rollout. Evidence:
integrated-crowd-perf-red.log and integrated-crowd-perf.lua.

## Shared immutable rig templates follow-up

Production now builds neutral vertices, indices, base coordinates and arm
weights once per original mesh/landmark profile/source row. Each actor gets
its own vertex table and GPU mesh. Native six-copy fixture asserts one shared
template and six actor meshes. The geometry oracle passes all six identities,
four rows, neutral/A/B and flat/relief; updating a second actor's stride leaves
every vertex of the first actor unchanged. Native fallback/resource checks
also pass (rig-shared-geometry-all-six.log).

The repeat six-copy run measured a20.927ms initial natural transition versus
39.992ms previously. Scheduled natural: mean interval16.668ms,p9517.450ms,
maximum23.450ms; mean draw2.468ms. This single repeat is observational evidence,
not an isolated causal timing proof. Continuous stress still had a36.145ms
outlier; classic had98.787ms. First activation still exceeds the16.67ms budget.
Evidence: integrated-crowd-perf-shared-red.log. Source composition still eagerly
creates12 canvases per newly seen human source; reducing that cold work is a
remaining optimization candidate before broader cast rollout.

## Demand-only card composites

`human_rig.lua` now creates a cell canvas only when its direction/step is
requested. Shader inputs and artwork are unchanged. Native comparison against
an archived eager implementation verifies exact RGBA byte equality for all
72 cells (six identities × four rows × three columns), one allocation per
requested cell, cache reuse and graphics-state preservation. Forced draw
failure is contained, restores the previous canvas/shader and negatively
caches the failed source. Shared geometry/isolation and scene guards also pass.
Evidence: rig-lazy-all-six.log, rig-lazy-failure.log.

Six-copy idle: one composite versus twelve, total texture memory40.48MiB
versus42.03MiB. First natural draw19.688ms, scheduled interval mean16.667ms,
p9517.399ms,max19.858ms. Continuous stress still had a148.653ms interval
outlier. The memory reduction is directly verified; broad timing improvement
is not established by these noisy runs.

Actual-input walking lazy runs retain independent arms and zero scheduled
blink frames during movement. Gen1 natural block intervals averaged16.935/
16.975ms (max39.743/42.741ms). Gen2 averaged16.747/16.792ms (max46.416/
61.048ms); its initial natural draw reached113.272ms. This must remain in the
record, not be discarded as warmup. Classic also had57–75ms interval outliers.
Evidence: integrated-walking-perf-lazy-red.log and -kris.log.

A subsequent Gen2 factory/prepare trace did not reproduce the113ms startup.
First cold-cell draw15.141ms: rig factory3.352ms, rig prepare2.358ms, eyes
factory0.003ms, eyes prepare5.219ms. Five further new-cell draws took4.427–
5.641ms total; their rig prepare portions0.246–1.551ms. Maximum individual
cell composition0.924ms. Yet a136.866ms steady frame interval occurred while
maximum steady draw cost was9.541ms, so draw profiling alone cannot explain
all pauses. Next diagnostics must include update/pacing/scheduling, without
claiming a root cause from this trace. The fixture can include ordinary live
Pokemon actors, whose identities vary; it is not an isolated GPU microbenchmark.
Evidence: rig-lazy-trace-kris.log; all timing scripts use the documented QA-only
software-pacing adapter and no Orange environment.


## Shared human animation instant per prepared frame

The optional preparePokemonFrame hook now captures one human presentation time
before shadow and color/eye rendering. Human gait, breathing, blink and weight
shift use this same instant for the captured map/player identity pair. Pokemon clocks are unchanged.
Hosts that never call the hook still sample draw time; a different world cannot
reuse a previous world's instant. Installation restores the previous hook exactly.
The existing residency preparation remains chained and is not duplicated.

The Gen1/Gen2 draw-seam regression explicitly advances wall time between simulated
passes: human state remains identical, the next prepared frame advances, and a
foreign world falls back to its current time. A render facade with the same
map/player matches; another player or a map mutation after preparation does not. The full existing regression passes.
A native Red run records 270 prepared frames, 540 human draw observations and 270
duplicate passes, all with identical human state within the frame; 269 subsequent
player frame advances are observed. It includes stationary, walking and settling
periods plus the existing classic/Vanilla/context cancellation checks.

This corrects intra-frame pose consistency. It is not proof that the previously
measured long draw/present/event stalls are resolved, nor a complete VR playtest.
Evidence: shared-frame-clock-regression.log and shared-frame-clock-red.log.


The first Crystal probe found that Gen2 passes a separate render facade to
preparePokemonFrame. Comparing that table to World missed the shared instant.
The final implementation captures map and player identities (not the mutable
facade/world table), resolving Gen2 and invalidating the instant after a map
change. Crystal then matches Red's 270 frames / 540 observations / 270 identical
duplicate passes / 269 advances. See shared-frame-clock-crystal.log. Existing
classic/Vanilla/dialog/script/input cancellation remains part of these runs.


## Seated-mother pilot cold preparation (2026-09-11)

Private Red fixture observations: 104.4 ms original synchronous preparation;
73.7 ms with directly uploaded prepacked displacement buffers; final version
81.4 ms active work across 15 cooperative steps, maximum 24.9 ms step.
The work is now spread between frames and construction publishes atomically.
Native decode/upload calls can still exceed one 60 Hz frame; broader cold,
warm and crowd performance acceptance remains open. The final native log is
mother-acting-integrated-sliced.log. These runs are not a statistical A/B
benchmark. No per-pixel unpack/setPixel loop remains in the runtime loader.


## Seated pose steady-state and memory (2026-09-11)

Removed the unused 512x512 RGBA8 standing-body canvas when constructing
head-only layers for the seated renderer: exactly 1 MiB less GPU texture
payload. The six resulting head canvases compare byte-for-byte against
full-layer construction (6,291,456 RGBA bytes), recorded in
mother-layer-verification.log. Other callers retain the default body layer.
The pose cache now compares numeric frame/progress values instead of
allocating a string every prepared frame.

Native current-run observations in mother-perf-after.log: 500 idle samples,
zero seated-canvas redraws during the two-second idle window. CPU submission
mean/p95/max: idle 0.00345/0.00587/0.0131 ms; the mixed conversation/turn
window (1,326 samples) 0.0312/0.0575/0.368 ms. These measure the seated frame
function and command submission, not completed GPU execution or total frame
time. Other live LOVE instances were observed, so these are diagnostic
samples, not an isolated statistical before/after benchmark. Do not infer a
whole-game speedup or completed stutter acceptance from them.

The native driver also rechecks both head directions, unrelated overlay,
Classic/Vanilla/pilot restoration and native placement. Full runner:
human-motion-mother-memory.log. Broader all-character/crowd performance,
initial decode/upload spikes and remaining actor coverage stay open.


## Bounded arm-rig residency and current whole-frame samples (2026-09-11)

The arm rig previously retained source composites without an explicit residency
limit and relied on garbage collection for per-actor meshes. Renderer teardown
did not explicitly clear the rig. It now owns at most 24 source entries and 128
actor mesh entries, evicts least-recently-used entries, releases associated
canvases/meshes immediately, and drops actor/template references when their
source is evicted. Failed sources share the same bounded source cache.
Original-mesh template keys are weak. Renderer restore calls an idempotent
clear that also releases the composition shader. These are entry limits, not
an assertion that total engine texture memory has the same bound.

Unit stress covers 181 retained actor instances and 41 sources, exact vertex
reconstruction after actor and source eviction, removal of stale actor/template
references, actor reset, and complete resource release. The real LOVE stress
uses 181 actors and 29 source textures, confirms 24-source/128-mesh bounds,
checks native mesh vertices after reconstruction, and clears all probe resources.
Evidence: human-motion-rig-budget.log and rig-budget-native.log.

Two current native Red whole-frame runs use the same 60 FPS software cap and
no QA pacing adapter. Each of four blocks lasts 12 seconds, with the first two
excluded from steady samples. Interval mean / p95 / max (milliseconds):

| Mode | Before residency bound | After residency bound |
| --- | --- | --- |
| Classic idle | 16.710 / 17.423 / 41.899 | 16.708 / 17.450 / 33.440 |
| Natural idle | 16.667 / 17.348 / 20.161 | 16.789 / 17.480 / 90.550 |
| Classic walking | 16.666 / 17.508 / 21.663 | 16.666 / 17.511 / 23.781 |
| Natural walking | 16.708 / 17.488 / 40.771 | 16.667 / 17.323 / 18.549 |

The later Natural idle outlier includes 86.593 ms inside draw. Natural walking
mean draw submission time is 1.832 then 1.763 ms. This noisy pair does not prove
a timing speedup or resolve intermittent stalls; unrelated desktop processes
were not shut down. The correction establishes bounded ownership and teardown,
not universal smoothness. Logs: whole-frame-current-red.log and
whole-frame-rig-budget-red.log. Global performance acceptance remains open.


Seated idle blinking now redraws the existing pose canvas during the 170 ms
blink only; unchanged open-eye idle frames still reuse it. The closed-eye shader
path is warmed and open eyes restored before publication, with no added canvas.
Final mother-blink-native.log observes 83.87 ms active preparation over 15 steps,
maximum 25.94 ms step. Cold preparation can still exceed a 60 Hz frame; this
is not a new claim that loading stalls are solved.

## Blink resource ownership — 2026-09-11

The blink service now explicitly releases all generated row quads, output
canvases and shaders at teardown. Its actor table is strongly owned but bounded
to 32 entries: removed actors can no longer disappear from the ownership table
before explicit cleanup. Eviction releases their canvas and every row quad.
The shared procedural shader is released once; failed packed-asset loading
releases its newly allocated shader immediately. Cached Assets.image textures
remain owned by Assets and are never released here. clear() is idempotent and
resets resource caches so the same service can rebuild after cleanup.

This removes reliance on garbage-collection timing for these owned objects.
It is not evidence that all gameplay stutters are fixed. The regression covers
40 transient actor records, all three blink rows, a forced GC, repeated clear,
shared procedural shader ownership, failed packed loading and subsequent rebuild.
Native opening-NPC blink checks exercise Daisy and NPC Blue plus the existing
side/rear and Classic/Vanilla paths. Evidence is stored in
human-motion-blink-lifetime.log and blink-lifetime-native.log.

## Seven-card native frame profile — 2026-09-11

Private Red indoor renderer benchmark: player plus six independent render-only
actors using the exact six hero atlases. Each mode runs 12 seconds; the first
two seconds are excluded. Native patched 60-FPS pacing, VSync off; no QA pacing
override. Screenshots and record assertions verify distinct actors. Their
movement follows the player's native pose; this is a controlled rendering load,
not a simulation of six NPC scripts or arbitrary crowded maps. Some furniture
occludes parts of the cards. Captures are excluded from measured modes.

The initial failed setup reused an already-bound player renderer; it was fixed
before measurement. An initial complete run overlapped a test actor with the
player; the final run separates their rows. Both logs are retained as diagnostics,
and their variation must not be interpreted as a production improvement.

Final full-frame mean/p95/max (ms): Classic idle 16.668/17.259/19.291; Natural
idle 16.666/17.455/19.372; Classic walk 16.667/17.371/19.068; Natural walk
16.666/17.428/25.646. Draw mean: 2.077, 2.168, 2.093, 3.299 ms respectively.
The longest Natural walk frame spent 24.973 ms in draw. This identifies render
work for deeper profiling, not specifically mesh submission, shader execution
or GC. Those need attribution before optimization. The earlier overlapping
sample reached 32.854 ms; neither sample proves stutter-free performance.

Evidence: integrated-crowd-frame-profile.lua, crowd-frame-profile.log,
crowd-frame-profile-summary.json and crowd-profile screenshots. Full objective
remains open: more source profiles/acting, head ghosting, and broader performance.

## Nested seven-card attribution — 2026-09-11

The follow-up profiler times rig.prepare, blink.prepare, Voxel3D card draw and
love.graphics.draw within the existing whole-frame measurement. Wrappers are
restored on completion. These are nested CPU wall times: rig/blink are included
in card draw, and card draw in total draw. Graphics draw measures submission,
not completed GPU work. They must not be summed as independent stages.

Natural walk: rig mean/p95/max 1.12109/1.46917/1.84583 ms; blink mean .01048 ms;
card draw mean 1.51424 ms; total draw mean 3.39860 ms. The longest draw was
17.05796 ms, with 3.22787 ms inside the card wrapper (about 13.83 ms outside it).
Thus both rig CPU work and the rest of scene drawing warrant attention; this
does not identify any individual external scene/GPU operation as the cause.

Frame interval mean/p95/max was 16.66584/17.34979/17.66937 ms. The previous
25.646 ms outlier was not reproduced. No production optimization occurred, so
the run-to-run difference is not a claimed improvement. Source/state checks
passed for all six added actors. Evidence: integrated-crowd-detail-profile.lua,
crowd-detail-profile.log and crowd-detail-summary.json in private non-Orange QA.

## Shared rig vertices — 2026-09-11

Production arm meshes now merge vertices only when all six attributes match
(position, depth, UV and shade). Triangle indices are remapped; UV/shading seams
stay split. This runs once per geometry template. Runtime arm/lean updates
therefore touch fewer vertices without reducing the surface sampling or changing
the motion equations. No extra textures or shaders are allocated.

The differential test compares against the unshared construction in 1,032 poses
across all registered base/alternate rig definitions, four directions, flat and
relief surfaces, three strides and nonzero lean. Every expanded triangle
attribute is exactly equal. Vertex count is 28.08% of the unshared count. This
is not additional artwork/profile coverage; the existing 80-source rig scope
remains. Full runner and native Daisy/NPC Blue geometry/cell/pose tests passed.

Same nested seven-card profiler: Natural-walk rig mean 1.12109 → .27555 ms
(about 75% less measured rig time); card-wrapper mean 1.51424 → .67871 ms.
Timing is a sequential local comparison, not a controlled hardware guarantee.
Overall frame max increased to 56.19058 ms in this sample: 51.57296 ms in draw,
but only 1.95529 ms in the card wrapper and .33725 ms in rig preparation. The
remaining scene-wide outlier is not claimed fixed by this optimization.

Evidence: human-motion-vertex-sharing.log, crowd-detail-vertex-sharing.log,
vertex-sharing-opening-rig.log and tests/human_rig_vertex_sharing_test.lua.
The math verifier now imports the compaction helper when extracting the rig.
Classic/Vanilla renderer round trips and installer rollback are retained.


## Partial-stop arm restart continuity — 2026-09-11

A short stop resets the foot-frame distance while arms are still settling.
Previously, restarting immediately sampled the reset sine phase and snapped
the arms away from their current pose. A new failing regression reproduced
this before the change. Natural now resumes from the actual settling excursion,
selects the phase branch with the previous swing direction, and eases the
shortest phase offset back to the feet over 32 travelled units. The phase
adjustment is bounded so it cannot reverse progression; a full rest, warp,
hidden-time gap or clock reset clears it. Foot columns/cadence are unchanged.

The regression covers 36 partial-stop combinations at 30/60/120 FPS, exact
first-resume continuity, both swing directions, bounded next increments,
rejoining the foot cadence, duplicate render passes and warp reset. The full
human-motion runner passes including Classic/Vanilla/missing-asset roundtrips.
Native Red and Crystal renderer fixtures each exercise four short-stop
restarts for each of the six hero atlases and assert actual pre/post draw arm
continuity. These fixtures inject moving render actors into ordinary interiors;
they do not prove arbitrary input/story paths or visual perfection. No new
textures, meshes or render passes are introduced.

Evidence in private non-Orange QA: arm-restart-before.log,
arm-restart-rejoin-regression.log, integrated-arm-restart.lua and
arm-restart-rejoin-native-{red,crystal}.log. tests/human_arm_restart_test.lua
is included in the standard runner. This fixes a concrete restart jump; head
ghosting, remaining NPC coverage and scene-wide long frames remain open.


## Actual player input follow-up — 2026-09-11

A new private input driver selects Red/Green/Blue in Red and Gold/Kris/Silver
in Crystal, presses/releases real left/right controls for four short walking
sequences per hero, and records each distinct rendered human-motion sample.
No actor positions or motion states are injected. At a requested 60 FPS,
median sample spacing is 16.57–16.82 ms. Travel is 63 measured units in Red
(the first unit predates the first sample) and 64 in Crystal; maximum position
increment is 1 and maximum arm increment .1950903 for every hero. All observed
positions are integer-valued. No nonzero arm-rejoin offset is entered during
these complete native steps; they are distinct from the partial-stop renderer
fixtures that reproduced the now-fixed restart discontinuity. This limits the
scope of the fix: it is not evidence that ordinary whole-step jitter is solved.

Native player code explicitly floors step displacement (src/world/Player.lua
and src/world/gen2/Player.lua in the private engine). Presentation interpolation
is therefore a relevant next investigation, provided it preserves native
coordinates, collision, grounded poses, actions and immediate fallback. The
current traces do not prove that integer stepping causes every reported stutter.

The driver captures moving/resting screenshots, so its maximum sample gaps
(48–66 ms) must not be interpreted as screenshot-free frame performance. The
Red moving capture was inspected; still images do not establish temporal
visual acceptance. Earlier uncapped Red data is retained separately.
Evidence: integrated-actual-input-restart.lua, actual-input-restart-gen{1,2}.csv,
actual-input-restart-{red,crystal}-60.log, actual-input-restart-review.json and
actual-input-moving-*.png in private non-Orange QA. No production change was
made by this follow-up; the prior arm fix and remaining scope are unchanged.


## QA-only fractional player projection — 2026-09-11

The private projection driver uses the remaining FixedStep fraction to present
(progress + alpha) / stepFrames along a one-cell already-authorized walking
segment. The captured pose is adjusted before the shared shadow/color passes;
native actor px/py are asserted unchanged. Only the player, straight one-cell
walks with at least 16 frames, zero lift and no action marker are admitted.
Projection is clamped to the step endpoint and stays within one native unit.
This prototype has not been added to the production payload.

Two fixture pitfalls were diagnosed before accepting results. The engine's
POKEPORT_DRIVER advances logic with a constant 1/60 dt per rendered frame;
MOTION_QA_PACED enables presentation pacing only. At 120 FPS that driver mode
is not normal realtime simulation. The final private driver feeds the actual
host dt to Game:update and restores its wrappers afterward. Also, a map event
reinstalls the production renderer when a foreign prepare hook is active,
invalidating captured record references. The final driver restores the owned
hook before map changes and installs its probe after binding. Early failed
travel assertions and constant-alpha traces are diagnostic, not acceptance.
Gen2 exposes the shared FixedStep module locally instead of game.fixedStep;
the final driver uses the verified src.core.FixedStep fallback. Its initial
missing-clock failure is retained, not a production bug.

At requested 120 FPS with actual input, the Red/Green/Blue and Gold/Kris/Silver
runs complete. For adjacent moving samples separated by 4–12 ms and less than
two units of travel, Gen1 has 281 pairs: native holds 142, projected holds 0;
step-increment standard deviation falls from .5000 to .0739. Gen2 has 355 pairs:
native holds 181, projected holds 0; standard deviation .4999 to .0593. Maximum
projection distance is .9792/.9764 units. These paired trajectory statistics
exclude stalls and are not a frame-time benchmark or proof of visual perfection.
The Red moving still was inspected. Camera motion, NPC schemas, high/low speed,
scene/action gates, full fallback and temporal visual acceptance remain open
before production integration.

Evidence in private non-Orange QA: integrated-position-projection.lua,
position-projection-{red-realtime,crystal-realtime-clock}.log,
position-projection-gen{1,2}.csv, position-projection-motion-gen{1,2}.csv,
review_position_projection.py and position-projection-review.json.


## Shared player/NPC projection calculation — 2026-09-11

The QA-only human_position_projection.lua replaces the inline player arithmetic
in the realtime projection driver. Its pure query does not mutate actor or
pose tables. It verifies the current coordinates against the engine's native
floored step equation, requires matching cardinal facing/target and a one-cell
segment, admits 16–64 frame steps, and uses Gen1 NPC's 32-frame default versus
16 frames for both players and Gen2 NPCs. Inconsistent/unknown schemas, altered
poses, nonfinite values, finished steps, lift, frozen/input/script ownership,
walking-in-place, jump/hop, bicycle/surf, teleport/tree-shake/rock-smash/bounce
and explicit action/Pokemon markers are excluded. Scene, option and exact
source readiness admission are caller responsibilities and remain to be wired.

The pure test passes 12,800 samples over four directions, player/NPC defaults,
explicit step durations, bounded projection, input immutability, repeated
queries and rejection cases. Native Red and Crystal test drivers call the
actual NPC.update methods on isolated fixture objects: 3,840 and 3,520
projection samples match those native step equations and finish at exactly
the native target with no residual offset. This is native-method coverage,
not yet a world-NPC visual or collision/pathfinding test.

The final shared helper also passes the actual-input, realtime 120-FPS player
fixtures for all six heroes. Updated paired trace results: Gen1 308 pairs,
156 native holds versus zero projected holds, increment standard deviation
.5000 to .0713; Gen2 339 pairs, 169 holds versus zero, .5000 to .0921. The
same 4–12 ms adjacent-moving-pair filter applies. Maximum offset stays below
one unit (.9727/.9750). Earlier prototype measurements remain historical.

Evidence: human_position_projection.lua, position-projection-test/main.lua,
position-projection-core.log, integrated-npc-position-projection.lua,
npc-position-projection-{red,crystal}-final.log,
position-projection-helper-{red,crystal}.log and updated projection CSV/JSON.
All reside in private non-Orange QA. No production source or payload changed.
Camera coordination, normal-option/scene/source gates, runtime fallback and
temporal visual acceptance must be completed before integrating this helper.


## QA camera/pose coordination — 2026-09-11

The camera prototype snapshots the player's fractional offset once at the
start of each host draw and uses that alpha for pose preparation. The same
x/y offset is supplied to Voxel3D.beginScene, ShadowMap.begin and the glass
glint camera query. Each main-camera invocation asserts its offset matches
the prepared player pose. No native camera fields are assigned. Calls at
each prototype camera boundary assert unchanged native camera fields and
preserve all return values.

Final private realtime 120-FPS Red/Green/Blue and Gold/Kris/Silver input runs
pass: Red has 319 main-camera and 319 shadow-camera nonzero-offset calls;
Crystal has 368 and 182. The latter counts reflect actual invocations, not
a promise that a cached shadow is rebuilt for every main-camera call. Moving
Red and Gold screenshots were inspected. This tests the current ordinary
interior camera only; first-person/VR, outdoor/reflection coverage and temporal
visual acceptance remain open.

The initial camera test needed two fixture corrections. Renderer ownership
includes beginScene as well as preparePokemonFrame, so both must be restored
before map changes and rewrapped after binding. Red's public facade omits
ShadowMap; the test retrieves the active private module from
scene.render -> renderWorld -> castShadows. This debug access is QA-only,
not a proposed production API. Crystal's World:draw normally calls Camera:follow
and applies screen-position lift during drawing (src/world/gen2/World.lua).
A whole-draw unchanged-camera assertion therefore falsely attributed native
updates to the prototype. It was replaced by assertions around the actual
three prototype camera boundaries, supported by inspection of the native code.
The first failed process entered LOVE's error display and was explicitly
interrupted; subsequent tests print fatal errors and exit instead of idling.

Evidence: integrated-camera-projection.lua,
camera-projection-{red,crystal}-hook-boundary.log, camera-projection-gen{1,2}.csv,
camera-projection-motion-gen{1,2}.csv and camera-projection-moving-{red,gold}.png
in private non-Orange QA. Production code/payload are unchanged. Normal
option/scene/source admission, fallback and further camera modes must still
be implemented and tested before integrating fractional presentation.


## Production fractional walking integration (2026-09-11)

This section supersedes the prototype-only status above. `human_position.lua`
now prepares fractional presentation coordinates once before shared rendering;
`VoxelScene.lua` applies the matching local player camera offset before
first-person preparation, shadows, glint and scene rendering. Native actor and
camera state remain owned by the engine. Repeated preparation is idempotent;
Classic/HD-off restores an already prepared pose. The renderer admits only
ready human card sources in the active matching world/map/player, Natural
mode and normal walking. Dialogue/script locks, special actions, malformed
clocks, missing assets and mismatched providers retain native positions.

The regression runner passes, including 12,800 projection samples and actual
production admission/camera-block tests, partial-error rollback, plus existing
198-atlas geometry and Gen2 rendering/fallback checks. Native real-input
Red/Green/Blue and Gold/Kris/Silver tests pass with 131/129/127 and 141/143/143
fractionally positioned frames, respectively, including camera and live
Classic/Vanilla switches. The private driver adapts its forced update delta
to real time at 120 FPS; this is QA setup, not a production engine change.

Isolated real NPC classes also pass: Bill/Kurt yield 185/193 fractional frames
in Red and 113/140 in Crystal, with immutable simulation, zero NPC camera
offset, Classic, Vanilla and real TextBox-dialogue exclusions. These are
controlled fixtures, not story-map or pathfinding acceptance. Each fixture
owns a baseline renderer made from the player definition so fallback can be
exercised; its baseline artwork is not a claim of authentic Bill/Kurt sprites.
An earlier fixture omitted this baseline and failed on Vanilla; corrected
fixtures passed both generations.

Production moving Red and Gold screenshots were visually inspected: each
shows one main character at the floor anchor. A still image cannot establish
absence of intermittent sprite flashes or temporal jitter. Head-turn blend
ghosts remain open, as do wider camera/VR/first-person/outdoor/transition and
performance acceptance. The package remains review-foundation-incomplete.
Evidence: human-position-integration/ contains production drivers, four native
logs, regression output, trajectory CSVs and six-hero captures.


## Correction: Gen2 camera integration and four-direction runtime audit

The previous production-position-crystal.log contained a swallowed
`Stadium VoxelScene overlay failed` camera assertion even though the process
exited zero and printed per-role PASS markers. Its earlier camera acceptance
is withdrawn. Marker-only verification was too weak. The root cause was a
missing production change in `gen2/lib/VoxelScene.lua`: Gen2's patched scene
uses that separate source. Player positions were fractional but its local
camera centre was still integer. The same bounded offset now runs after pose
preparation and before glint, first-person and shadows in that source too.
Externally supplied VR eyes retain their caller-owned centre; this guard is
unit-tested, not a VR visual acceptance claim.

A new native driver exercises right/down/left/up twice for each of the six
heroes, resetting to known clear indoor cells before each segment. It audits
the actual renderer submission seam with QA-only stack inspection to identify
player calls, permitting animated canvas textures but rejecting the native
proxy texture. It also tests Classic/Vanilla switches. Red/Green/Blue each
produced 1,014 authored submissions and zero proxy submissions; Gold/Kris/
Silver produced 1,056/1,048/1,064 and zero proxy submissions. There were 2,003
Gen1 and 2,076 Gen2 camera assertions. Both logs have no runtime error lines.
The new external log verifier rejects the old swallowed-error log as a
negative control. The full regression runner passes with both production
camera source blocks exercised, including the external-eye ownership guard.

Earlier test attempts used a square path that hit furniture, compared only
the atlas texture instead of animation canvases, and subsequently exposed
the real Gen2 camera omission. Those attempts are not acceptance evidence.
Trajectory CSV travel totals include explicit between-segment repositioning;
do not interpret them as uninterrupted distance or performance measurements.
Source submission checks exclude old-proxy fall-through in these observed
player calls only. They do not prove absence of every possible ghost pixel,
head-morph double contour, or fallback transition in every scene. Grid,
free-camera, outdoor, NPC story scenes and longer frame pacing remain open.

Evidence: four-direction-camera-fix/ contains the driver, source-aware log
verifier, accepted logs, verification summary and regression log. This section
supersedes the earlier Gen2 camera conclusion. Package status stays incomplete.


## Grid preparation preserves animated poses (2026-09-11)

The natural human path previously discarded the already computed flat rig
when `humanGrid.prepare` returned pending, drawing the static card until the
queued grid became available. This could switch arm poses during initial
preparation or a new direction. It now keeps that same animated mesh and
texture until a grid is ready; grid initialization/preparation failure also
retains the available flat rig. Classic behavior is unchanged.

A native grid-enabled version of the four-direction test exercises all six
heroes, eight real-input segments per hero, repeated cold map preparation,
live Classic/Vanilla switches and camera alignment. A QA wrapper records the
flat animated mesh passed into grid preparation and checks exact mesh
identity at the actual player submission when preparation reports pending.
Red/Green/Blue passed 128/140/140 such checks; Gold/Kris/Silver passed
130/136/132. Each also produced over 1,000 ready-grid draw calls. The
source-aware audit found zero native player proxy submissions, and the logs
contain no runtime errors. Gen1/Gen2 camera checks total 1,844/2,027.

Grid counters include shadow/color passes; pending totals are cumulative,
not unique frames. Concurrent private tests are functional checks, not FPS
benchmarks. Indoor Red/Gold stills were inspected for silhouette/floor anchor;
stills do not prove temporal perfection. The brief transition from animated
flat surface to prepared grid is still a representation change and has not
been established visually imperceptible. Camera variants, outdoor scenes,
head-turn ghosts and wider NPC coverage remain open. No Orange interaction.
Evidence: grid-position-continuity/ in the review package.


## Outdoor real-input frame measurements (2026-09-11)

Private Red Pallet Town and Crystal New Bark Town walks use production human
animation/positioning, normal residents/followers and real left/right input.
Each sequential process takes Classic/Natural/Natural/Classic seven-second
samples, excluding the first second from steady summaries. A private real-dt
adapter corrects the engine driver's forced timestep; a private cap adapter
requires VSync before reporting hardware pacing. Resolution 960x720, cap60,
VSync off, human grid off. No simultaneous QA games were used for these runs.

Red initial interval p95 (ms): 17.589,19.268,17.607,17.487; corresponding mean
whole-draw costs: 3.888,4.682,4.902,4.509. The first Natural sample has a
112.541ms interval, with 48.736ms spent in its preceding draw. Crystal p95:
17.735,17.793,17.808,18.313; mean draw: 4.180,4.569,4.755,4.838. Its longest
interval is 61.939ms in the final Classic sample. These are observed samples,
not controlled identical routes: live NPC collisions and the player's continuing
position change the view. The driver checks substantial travel per sample.
Blinks were enabled normally but the moving player had zero blink frames;
these runs do not benchmark an actual eyelid closure.

A second sequential Red run adds measured game.update time per draw interval.
The four worst intervals are 66.674,47.325,71.369,42.850ms. Their preceding
draws are 64.487,3.397,70.139,4.625ms, and measured updates 1.484,.870,.524,
.685ms. Remaining time is .704,43.058,.706,37.540ms. This residual includes
presentation/pacing/host scheduling and uninstrumented engine work; it is not
attributed to a specific subsystem. Long drawing and non-drawing intervals
occur in both modes. The measured update call does not explain these worst
pauses; further profiling should focus on drawing and inter-frame work.

All three processes exited successfully with four completed samples each and
no runtime error lines. Natural outdoor Red and Kris screenshots were visually
inspected, with resident actors and floor shadows present. These stills do not
prove temporal smoothness. Production code was not changed during measurement,
and no general performance acceptance is granted. Raw per-frame CSV, logs,
drivers and update breakdown live in outdoor-frame-measurements/ in the review
package. No Orange interaction; no frame-cap patch was installed in a live game.


## Outdoor render-stage diagnosis and held matrix prototype (2026-09-11)

Red's corrected stage driver classifies preparation, human cards, Pokemon
cards and other Voxel3D submissions during normal outdoor walking. Its four
worst draw frames (Classic/Natural/Natural/Classic) were 20.276/22.337/24.924/
41.076ms; human drawing took .218/.703/.851/.363ms in those frames. A later
instrumented run timed draw/drawInstanced, setCanvas/setShader and creation
of canvases/images/meshes/shaders. None of those individual calls exceeded
8ms. Their combined durations in each sample's worst whole draw were
.573/.526/.741/.850ms out of 23.550/19.132/26.071/25.981ms. This list does
not cover every graphics method, and graphics timings overlap the card
categories; do not sum the two measurements. It narrows these observed
frames away from human card submission and the sampled graphics calls.

A separate Lua instruction hook (every 20,000 VM instructions, only during
draw) frequently sampled Mat4.mul, loader option lookup, diagnostic string
cleanup and alpha-bound scanning. Instruction frequency is not wall-time
attribution; JIT/hook overhead prevents using that run as an FPS benchmark.
The first stage attempt failed because a QA counter inspected the timing
wrapper rather than its original function; corrected logs passed.

An unrolled Mat4.mul candidate preserves original arithmetic order and
allocates its result in one table constructor. 2,048 random general matrix
pairs matched exactly in the benchmark. A temporary full regression test
checked both Gen1/Gen2 files (4,096 products, fresh results, unchanged inputs
and affine composition), and the full human runner passed. Alternating
150,000-product trials gave median times of 120.742 -> 31.710ms with JIT
and 231.983 -> 105.724ms without JIT, with substantial individual variance.

The candidate's subsequent real outdoor run was slower than the earlier
baseline, but a fresh original-function control was slower still, with large
outliers. A process snapshot after the control observed three unrelated
LOVE processes at approximately 50-60 percent CPU each, as well as other
host load. Those processes used a different executable path and were not
interacted with. This contemporaneous observation does not reconstruct
host load for every earlier sample. It prevents treating these runs as a
controlled overall-performance comparison.

The candidate was therefore NOT promoted: both production Mat4 files were
restored byte-exactly, the temporary test was moved into private QA, and the
54-file package payload remains unchanged. Evidence is retained under
matrix-render-optimization/ as a prototype, including both controls. Future
whole-game acceptance needs a controlled host/scene comparison; work on
other missing actor profiles and poses can proceed independently. No Orange
interaction and no general performance completion claim.


## Idle crowd blink-cache correction (2026-09-11)

Reproduced a concrete rendering-work defect: 40 open-eyed actors sharing an
approved profile, visited in stable order for 30 frames, caused 1,200 canvas
allocations and eyelid warmup renders. The 32-owner LRU evicted each actor
before its next visit (1,168 evictions), so every frame repeated initialization.

Warmup completion now belongs to the exact eye profile resource. Once warmed,
open eyes return the original source without touching the actor LRU or creating
a canvas. Active eyelids still allocate/reuse bounded per-owner output. Resource
clear resets warmup state; invalid amounts are rejected before shader loading.
The first actual draw still warms each profile, preserving the existing intent
to exercise its shader ahead of scheduled closure. This does not precompile
all profiles globally or eliminate every first-use allocation.

The new 40-actor regression fails on the prior implementation with 1,200
renders and passes after the change. A real LOVE GPU A/B using the same exact
youngster source reproduces 1,200 renders/allocations before versus one after,
with zero idle evictions after. All 40 subsequently requested partial closures
still render in both versions. The prior module is preserved with its SHA-256
in blink-crowd-lab/ for reproduction. Counts describe workload, not a measured
whole-game FPS gain. Simultaneous active blinks beyond the 32-owner budget can
still require eviction; the fix specifically removes open-eye churn.

The complete ordinary regression runner and shared rim GPU tests pass. Native
isolated fixtures in Red and Crystal pass all three youngster palettes with
scheduled closure, side/rear policy, movement cancellation and Classic/Vanilla
shutdown. Both native processes terminated successfully, with error-aware log
checks. Native tests use three palette cases, not an actual 40-NPC story scene.
Evidence: blink-idle-crowd/ in the review package. No Orange access.


## Active crowd eyelid canvas reuse (2026-09-11)

The preceding open-eye fix did not eliminate GPU allocation churn when more
than 32 actors actually blink. The new regression reproduces repeated
allocation with 40 active actors. Matching width/height canvas and quad sets
are now transferred from the LRU victim to the next owner. Source, role, eye
profile, amount and row metadata are freshly initialized; the new owner must
render its own face, even when its amount equals the previous owner's amount.
Different dimensions release/reallocate instead. Capacity remains 32 owners.

Real LOVE GPU A/B: 40 actors across 30 frames, changing closure amount and
front/left/right views across three exact youngster palettes. Both versions
render 1,200 requested eye outputs. Canvas allocations fall from 1,200 to 32,
with 1,168 successful reuses. Each eye output is immediately drawn into a crowd
canvas; all 30 complete RGBA frame hashes match the prior implementation. This
checks that repainting a canvas does not corrupt already submitted draws. The
final crowd image was inspected. This is allocation reduction and image parity,
not a whole-game FPS benchmark or proof that existing source rim artifacts are
fully resolved. No new native scene run is claimed for this isolated cache fix.

The portable GPU test tests/human_blink_crowd_runner retains the prior module
as a test-only baseline. The ordinary regression runner passes, including
active allocation stability, incompatible-size rejection, bounded ownership,
exact resource release, packed asset failure and rebuild. Existing native
Classic/Vanilla/source tests are part of that runner. Evidence and baseline
are included under blink-active-crowd/. No Orange access.

## Tatsächlich belegten Rig-Bildspeicher begrenzen — 2026-09-11

Die bisherige 24-Quellen-LRU verursachte bei 40 unterschiedlichen Figuren ständige Wiederaufbauten: 1200 Quellen-, Bild- und Geometrieaufbauten in 30 Idle-Durchläufen. Quellenmetadaten und Geometrien sind jetzt jeweils auf 128 begrenzt; erzeugte Einzelbilder haben eine eigene LRU mit 10.692.000 Pixeln (rund 40,8 MiB RGBA8 ohne Treiberkosten). Originaltexturen sind darin nicht enthalten; mehr Quellenplätze können mehr Originaltextur-Referenzen halten. Im Idle bleiben 40 Figuren nach dem ersten Aufbau warm. Bei 40 echten Atlasquellen und 30 Bewegungsbildern sinken die Aufbauten von 1200 auf 120 Bild- und 40 Quellen-/Geometrieaufbauten, bei 30 pixelgleichen Gesamtbildern. Das belegt weniger Wiederholungsarbeit, keine pauschale FPS-Steigerung.

Die Budgetprüfung überschreitet Quellen-, Geometrie- und Pixelgrenzen und kontrolliert Speicherfreigabe, Neuaufbau und idempotentes Aufräumen. Voller Runner bestanden. Alle sechs Helden bestehen den nativen Eingabetest in ihrer jeweiligen Generation samt Classic/Vanilla. Der erste Gen2-Lauf wurde von einem Ambient-Vulpix blockiert und zählt als fehlgeschlagen; der private Wiederholungstreiber schaltet Town Pokémon aus und lässt die eigentliche Kollision unverändert. Details: rig-source-budget/README.md im Prüfpaket. Die übrigen langen Einzelbilder und der vollständige Charakterumfang bleiben offen.

Erweiterter GPU-Test: 150 pixelgleiche Gesamtbilder über vier Richtungen und Rückkehr zur ersten, einschließlich tatsächlicher LRU-Freigabe und Neuaufbau. 600 statt 6000 Bildaufbauten, 40 statt 6000 Quellenaufbauten; Pixelgrenze eingehalten. Siehe rig-source-budget/gpu-evict-rebuild.log.

## Erneute vollständige Frame-Prüfung — 99 Armquellen / 29 Blinkquellen

Vier private native Läufe in Red/Crystal, Classic/Natürlich im Stehen/Laufen, zusätzlich umgekehrte Testreihenfolge. Die erweiterten Treiber prüfen die aktive Kartenquelle und den Bewegungszustand nach dem Zeichnen. Classic hat keinen Natural-Zustand, Natural in allen geprüften Bildern; tatsächliche Gehbewegung belegt. Alle Prozesse Exit 0. In den umgekehrten Läufen hatten 30 Red- und 31 Kris-Blinzelbilder maximal 17,45/17,48 ms. Kein Frame über 25 ms in deren ausgewerteten Fenstern; dies ist keine allgemeine Ruckelfreiheitsfreigabe. Die Normalreihenfolge zeigte weiterhin Idle-Ausreißer bis 64,43 ms bei Red und 44,94 ms bei Kris, überwiegend in Present. Desktoplast nicht isoliert; keine Ursachenbehauptung aus Call-Walltimes. Kein Produktionscode geändert. Raw-CSV, Rollenprüfungen, Analyseskript und Quellhashes: whole-frame-99-review/ im Prüfpaket. Sitz-/Kopfdrehungsabnahme und voller Charakterumfang bleiben offen.
