# Human acting pilot — requested scope

## Current acceptance — 2026-09-11

The seated system now covers 75 source-audited live human objects in Kanto and
Johto. This includes homes, both generations of Game Corners, cafes, the
Goldenrod Pokemon Center lounge, labs, Radio Tower desks, the Fan Club and the
S.S. Anne. Red's mother and Daisy sit on their exact Gen1 furniture, the New
Bark mother and opposite guest sit at their exact Gen2 positions, and owned
conversations turn seated heads toward the actual
partner. Oak and NPC Blue use exact Pallet opening-scene directions; Blue uses
folded arms and a small smile during Oak's choice speech. Elm uses four diagonal
views with breath and blink in his owned lab dialogue. The actual New Bark
Silver uses the shared exact Silver atlas and has verified gait, arm swing,
breath, idle shift and blink; no rejected Silver art is shipped.

Red's mother no longer optical-flow blends two heads. The current turn presents
one reviewed head per frame with a small anchored yaw cue, eliminating the
known double hair/eye/ear contours. Nine GPU-rendered stages, both native
dialogue directions and a source-count regression pass. Eight obsolete flow
buffers are removed, and running turn submission is 0.0257 ms mean,
0.0505 ms p95 and 0.1020 ms maximum on this host.

The real Gen1/Gen2 seven-card workloads, all 75 audited seats and the full
198-source runner pass on the current code. `DIALOGUE POSES (TEST)` stays default
off; `NATURAL`, `HD PEOPLE` and grid off are required. Classic and HD-off always
restore the old paths. Evidence: `final-performance/` in the review package.

## Daisy sits on her exact Blue House stool — 2026-09-11

The pre-map Daisy object (`BLUES_HOUSE_obj_1`, index 1, cell 2/3) now uses the
existing source-preserving seat geometry in Natural acting mode. Knees bend
toward the table while the actor coordinate and original 495x900 atlas remain
unchanged. Her own `world.talk` TextBox turns the head smoothly toward Red.
Classic restores the former standing card on the stool; HD PEOPLE off restores
Vanilla.

The later story object (`BLUES_HOUSE_obj_2`, index 2, cell 6/4) is explicitly
excluded and retains normal standing/walking motion. The real house run verifies
both objects, source/role/cell/pixel guards, bounded seat resources, head settle,
Classic, HD-off and the post-map replacement. Screenshots and log:
`daisy-states/`. No generated artwork was required.

Three generated Silver crossed-arm candidates were rejected because each file
was RGB with a baked checkerboard. None entered the repository or package;
Silver retains his already verified natural gait, arms, breath, idle shift and
blink. Exact prompts and rejection record are in
`daisy-states/SILVER_ACTING_REJECTED.md`.

## Professor Elm diagonal dialogue, breath and blink — 2026-09-11

Professor Elm now selects one of four reviewed diagonal body views while he is
the exact speaker in an owned Gen2 laboratory dialogue. The presentation looks
toward the actual player position and leaves native facing, script movement,
collision and actor coordinates untouched. His free-form acting atlas carries
source-owned eye regions, so front diagonals close both eyes and rear diagonals
close the one visible eye. The shared idle clock also keeps a subtle
foot-anchored breath while the pose is held.

The feature requires DIALOGPOSEN (TEST), NATURAL and HD PEOPLE. It cancels on
dialogue/window ownership loss, actor movement or action, map/save/VM change,
grid mode, Classic or HD PEOPLE off. Failure to load the optional acting or
blink resource retains the ordinary card. The full regression runner passes.
A real Crystal/Gen2 ELMS_LAB interaction verifies the diagonal source, active
blink, breath, return to cardinal presentation and both fallback switches. The
diagonal target in that run is produced by a 12-pixel render-only test offset
inside the real owned dialogue; no game state is saved or installed.

Built-in ImageGen produced the transparent 1254x1254 atlas from the exact Elm
source. A GPU test verifies 2,009 changed color pixels are confined to the two
reviewed eye regions, alpha and all other pixels remain unchanged, and the full
atlas coordinate system is preserved. A 120-render observation measured
0.080 ms mean, 0.083 ms p95 and 6.276 ms maximum on this host. Evidence, exact
prompt, hash and screenshots: `elm-diagonal/`.

## Context-bound folded-arms pose for NPC Blue — 2026-09-11

NPC Blue now uses a separate four-direction folded-arms pose only while he is
the exact observer of `_OaksLabOakChooseMonText`. The two front-visible views
have a small closed-mouth smile. His own dialogue phases continue to use the
registered rear/rear-right turn. Hero Blue, Gym Blue and action sources remain
excluded by exact atlas identity.

Pose selection requires both the captured dialogue key and actor kind. A
missing optional pose falls back to the same NPC's existing diagonal sheet.
The candidate is preloaded on map entry, outside the draw that first selects
it. Native grass/escort/lab testing passes with twelve pause samples and
Classic/Vanilla shutdown. The full runner includes exact selection, missing
pose fallback, release accounting and a 1254x1254 RGBA/alpha/hash asset check.
Built-in ImageGen produced the final transparent asset after an RGB
checkerboard candidate was rejected. Evidence and prompts: `blue-folded/`.

The first in-game rollout covers the six hero identities (Red, Green, Blue,
Gold, Kris and Silver) and the important opening-town actors in Pallet Town
and New Bark Town, including their houses/labs. This is a staged test of the
full all-human goal, not a reduction of that goal.

Required named actors: Red's mother, Daisy (Blue's sister), Professor Oak,
Blue as the NPC rival, Johto's mother, Professor Elm and Silver as the NPC
rival. Supporting opening-town actors remain in scope for the first area
test. Hero Blue/Silver and NPC Blue/Silver use different shipped atlases;
their admission must be explicit, not inferred from the shared role name.

Add a separate experimental switch beside human card animation/HD people in
the existing VASC menu, using the shared Gen1/Gen2 option schema. Default off.
Classic card animation and HD PEOPLE off must still override all new poses.
Do not expose an inert switch before its renderer is connected.

Conversation direction follows the actual partner, which may be another
NPC. Do not assume the player is always the addressee. Oak must turn between
Blue and Red when the dialogue requires it. A seated actor keeps the body
on its chair and turns the head. Daisy's sitting and walking map objects
are separate states and must not be conflated.

Standing actors also need diagonal, three-quarter body views toward their
partner (eight presentation directions). Keep presentation orientation
separate from native four-direction movement/collision/script facing.
Use reviewed directional artwork; rotating a flat front card is not a
three-quarter body view. A seated actor turns its head without turning or
sliding the seated body. Classic/Vanilla restores native orientation.

Inspect and fix Oak's high-grass opening and the escort/laboratory scene.
The native story2.lua sequence opens TextBoxes directly; it does not use
world.talk or ScriptRunner for all dialogue. The new normal-conversation
ownership adapter alone therefore cannot authorize these scene poses.
Use explicit scene/speaker/partner metadata and preserve scripted movement.

Earlier evidence: a private seated-mother rendering prototype with both head
directions and Classic/Vanilla restoration; an independently tested exact
conversation-owner adapter. These mother components remain QA-only. The
newer integrated Oak slice is described in the final section below.
All testing uses the private non-Orange fixture.

## Dynamic Oak binding — verified 2026-09-11

The Gen1 show_object command creates Oak without a spawn event. The walking
sprite binder now observes that command, calls the native operation once,
and binds only the matching live NPC in the active world. It preserves the
scripted position and native return/error behavior. The wrapper is restored
on fallback/Card teardown and is not installed for Gen2.

Private native evidence: oak-start-scene-binding-verified.log passes all six
actual grass/escort/lab dialogue phases and asserts HD binding for each live
Oak/Blue. human_spawn_binding_test.lua checks world ownership, disabled
mode, wrapper restoration, downstream errors and Gen2 exclusion. The full
human-motion runner passes. This fixes sprite ownership only; diagonal
artwork, dialogue-partner posing and the pilot menu remain pending.


## Diagonal dialogue prototype — verified 2026-09-11

QA now contains four candidate Oak diagonal standing views with actual alpha
and an explicit opening-scene partner adapter. The native six-dialogue
sequence verifies Blue -> Oak, Oak -> Red, Blue -> Oak, Oak -> Blue and the
corresponding listening actor. Unit checks cover eight directions and stale
world/save/source/actor/movement/overlay cancellation. The final native
render run (oak-diagonal-native-scoped.log) passes, with inspected front-left
Oak, ordinary front toward Red, Classic and Vanilla screenshots. Fourteen
intercepted draws prove the candidate actually reached the renderer.

This is still QA-only. Hard view cuts remain, only front-left has native
visual coverage, and the other actors/Gen2/production menu integration are
pending. The temporary QA draw hook must be removed before map or options
changes: otherwise renderer reinstallation can capture it recursively.
The final driver does this; earlier failed logs are retained separately.
Artifacts and prompts: qa/vasc-human-motion-native/art-review/oak-diagonal-v1.


## Integrated experimental switch — 2026-09-11

`human_acting.lua` and `human_dialogue.lua` now run through the regular
VoxelCharacters preparation/draw path. No QA draw wrapper is needed.
DIALOGUE POSES (TEST) / DIALOGPOSEN (TEST), `apo_human_acting_pilot`, is saved
with the human options in both menu generations, default OFF. The current
implemented slice is Oak's Pallet opening dialogue. NATURAL and HD PEOPLE
must be enabled and the people grid must be OFF. Gen2, other people, unknown
text, unsupported source/action, missing or empty candidate artwork retain
the existing render path. This is not the full opening-town/hero rollout.

An option epoch cancels the current pose; enabling again takes effect at the
next recognized dialogue, not by reviving an old captured conversation.
The native complete six-dialogue run passes without the QA render hook:
one owned 1254x1254 texture upload, 182 source selections in the first run,
correct Oak front-left to Blue and ordinary front to Red, Classic and
Vanilla restoration. The final recheck log is oak-acting-integrated-final.log.
The full runner includes human_acting_test.lua and human_dialogue_test.lua.
The image payload is 6,290,064 bytes for RGBA8 before driver overhead; only
one candidate texture is retained, with no upload or pixel scan in draw.
This is a resource bound, not a claim of full-scene performance acceptance.

The installable review payload now includes the two acting modules and
professor-oak-diagonal-v1.png. Hard view cuts, other native diagonal views,
all other actors, Gen2 acting, seat integration, grid/cube acting and the
remaining full-game movement/idle/performance coverage remain unfinished.


## Integrated seated mother — 2026-09-11

The regular acting module now includes Red's mother at the exact native
REDS_HOUSE_1F / REDSHOUSE1F_MOM chair (cell 5,4; native pixels 80,64), using
only the original admitted v2 mother identity. The pose has world height 18
and render-only Y=-5/Z=+8 placement. Actor state, collision and script
position remain unchanged. Movement, action or identity changes reject the
seat pose. Both the seated body and prototype head-turn resources are
inside the reversible review payload. Existing source PNGs are untouched.

human_conversation.lua owns only TextBoxes pushed by the actual world.talk
script coroutine for the chosen NPC. The body remains seated while the head
turns toward a lateral interlocutor, using elapsed time once per prepared
frame. A foreign overlay returns the head to neutral; popping it can resume
the still-owned conversation. Classic, Vanilla, the pilot switch and actor
grid restore the previous presentation. The pilot remains default OFF.

Native evidence: mother-acting-integrated-sliced.log passes both lateral
conversations, unrelated overlay, native position, option roundtrips and one
resource preparation. Source selections: 1,406; head canvas updates: 936.
Unit evidence includes exact owner cancellation, 30/60/120 Hz timing, exact
chair/source/action admission, partial-load cleanup and cancelled coroutine
preparation. Full runner: human-motion-with-mother-sliced.log.

Cold preparation measurements on the same private fixture: the initial
per-pixel displacement upload took 104.4 ms. Prepacked float displacement
buffers reduced the next synchronous run to 73.7 ms. The final cooperative
run used 81.4 ms of active work across 15 steps; its largest step was 24.9 ms.
These are individual observations, not a statistical benchmark. Native
image decode/upload calls still cannot yield internally, so the first load
is not yet guaranteed within a 16.7 ms frame. No claim of complete global
performance acceptance is made. Eight numeric flow buffers are validated
by SHA-256 and uploaded directly; source artwork is not modified by this
conversion. Pending preparation publishes no half-built pose and releases
all owned resources on teardown.

Remaining: rear-facing dialogue views, blinking/expression and breathing
for the seated pose, final visual polish, other seated actors, all other
pilot actors and Gen2, grid/cube acting, Oak's smooth turn transitions and
the full all-human movement/idle/performance goal.


The seated renderer now omits its unused standing-body canvas (1 MiB less
RGBA8 texture payload) and uses allocation-free numeric pose-cache keys.
Six head canvases remain byte-identical; the native idle window causes no
redraws. See HUMAN_MOTION_PERFORMANCE.md for measured scope and limitations.


## NPC Blue dialogue views — 2026-09-11

The Pallet opening now gives both NPC Blue and Oak their own diagonal
standing views. human_acting_profiles.lua declares exact source-atlas keys;
no hero-role aliasing is used. Each admitted actor has its own texture/load
state, so a missing Blue sheet leaves Oak operational. The real hero Blue,
Johto gym Blue and bicycle Blue paths are explicitly excluded in tests.
This extends dialogue posing, not the count of reviewed walking-arm rigs.

Native oak-blue-acting-integrated.log passes the full six-dialogue
high-grass/escort/laboratory sequence. In dialogue phases 3, 5 and 6, both
source identities are checked: Blue back-right toward Oak, Oak front-left
toward Blue. During the choice speech Oak uses the original front toward
Red and Blue receives no unrelated pose. Two texture uploads, 352 source
selections; Classic/Vanilla tests and player exclusion pass. The native
screenshot and the four-view light/dark gallery were inspected. Missing
Blue assets and real hero/gym/action exclusions pass in
acting-blue-exclusions.log; the full runner is human-motion-with-blue.log.

The new transparent sheet was produced with built-in image_gen from the
exact existing NPC Blue v2 atlas. Prompt and art-review evidence are under
qa/vasc-human-motion-native/art-review/blue-diagonal-v1. The other three
new views have gallery coverage but still need native scene coverage.
Hard view cuts, six hero acting profiles, Daisy, Elm, Silver and other town
actors, Gen2 acting, full all-human idle/gait coverage and global performance
acceptance remain open. Pilot default and Classic/Vanilla controls remain
unchanged. The reversible payload now contains 41 files.


## Dialogue pause continuity — 2026-09-11

Fixed a confirmed old-card flash between the opening laboratory dialogues.
The exact captured TextBox completion callback creates a native three-tick
hold. The dialogue owner now retains its speaker/listener pose for that
specific hold object and callback, after the native callback returns.
Unrelated overworld frames, emotes and overlays receive no extra permission.
All existing actor, position, source, map, save and option invalidations remain.
Owned completion wrappers restore on reset and preserve native returns/errors.

The native grass-trigger/escort/lab driver integrated-dialogue-continuity.lua
passes all six dialogues and observes 12 actor-render samples retaining the
correct diagonal sources during the pauses. Two texture uploads; Classic and
Vanilla still pass. The full human_motion_runner passes, including callback
return/error preservation and unrelated/replaced/expired hold rejection.
Evidence: dialogue-continuity-native.log, human-motion-dialogue-continuity.log.
This fixes the confirmed pause flash; it does not claim that all reported
visual artifacts or hard direction changes have been eliminated.


## Registered Oak turn — 2026-09-11

human_turn.lua now integrates the reviewed front/down-left Oak pair into the
pilot. Two unchanged-art views are registered to the same 224-pixel height
and floor position in 256-square textures. The displacement fields are
source-specific, hash-checked 128-square RGBA32F buffers. Bidirectional
inverse warping replaces the abrupt cut when Oak turns between Blue and Red.
Vertical displacement tapers to zero at the feet. A shared output canvas is
only redrawn while progress changes; turns settle to exact endpoints.

The source is selected only through the existing exact dialogue/hold owner.
Unsupported directions retain the existing source selection. Classic,
Vanilla, grid, actor/action/map/scene changes cancel the turn. Missing or
invalid turn resources retain the previous diagonal/card behavior; partial
loads release resources and render failure stops further redraw attempts.
There is one admitted actor/profile, with 1.25 MiB RGBA texture payload for
two views, two vector textures and one output canvas (excluding driver cost).

Native integrated-oak-turn-production.lua passes the real grass/escort/lab
sequence, both turning directions, endpoint settling, idle cache reuse,
12 retained actor samples across dialogue holds, Classic and Vanilla.
Intermediate in-scene captures were inspected. The full runner adds easing,
clock, actor reset, unsupported direction, GPU failure, source hashes and
resource teardown tests. This is an Oak front/down-left pair only: Blue and
other actors still need their own registered transitions; all-human coverage
and global performance acceptance remain incomplete. The payload has 46 files.


## Blue turns and third-party listening — 2026-09-11

NPC Blue now has a registered rear/rear-right turn using the same bounded
renderer as Oak. His exact original rear frame and admitted diagonal frame
are normalized to the same height/floor; two independently computed flow
buffers and both source images are hash checked. No hero Blue, action card,
or gym Blue alias is admitted. The additional texture payload is 1.25 MiB.
The five-step comparison gallery and actual lab images were inspected.

During _OaksLabOakChooseMonText, Blue is an explicit third-party observer
looking at the speaker Oak. This prevents his presentation reverting while
Oak addresses Red. The observer snapshot participates in the same identity,
source, movement and scene invalidations as speaker/listener; arbitrary NPCs
are not given this permission. Native dual-turn-production-native.log covers
both registered sources, completion and idle-cache reuse, observer continuity,
all dialogue holds, Classic and Vanilla. Full regression evidence is
human-motion-dual-turn.log. The reversible payload now has 50 files.
Other actor transitions and full all-human coverage remain unfinished.


## Seated mother's idle blink — 2026-09-11

The seated mother now uses HumanIdle's existing deterministic blink clock:
2.2–5.4 second intervals, 170 ms close/hold/open cycle, no random-generator
mutation or delayed-blink replay. It applies only to her settled front idle
head. Owned dialogue/head turns, unrelated overlays, emotes, running/failed
script queries and existing source/action/placement guards cancel it.
Classic, Vanilla and the pilot switch retain full original presentation.

The front-head shader paints a source-specific eyelid mask while keeping the
existing seated body and silhouette intact. It needs no extra texture/canvas;
the existing pose cache includes closure amount, so unchanged open-eye frames
remain cached. The actual closed-lid draw is warmed during construction and
restored to open eyes before the pose is published. Eye lines follow the closing edge instead of floating above the
remaining iris. Five native-rendered intermediate states were inspected.
A GPU pixel test checks unchanged alpha everywhere, no pixel changes outside
the eye region, byte-identical open-eye restoration, and idle cache reuse.
Unit timing/delivery checks cover 30/60/120 FPS and cancellations. Native
integrated-mother-blink.lua exercises scheduled idle blink, both conversations,
head turns, unrelated overlay, Classic/Vanilla/pilot and unchanged placement.
Evidence: mother-blink-pixels.log, mother-blink-native.log,
human-motion-mother-blink.log. Side-facing/dialogue blinking and breathing of
the seated body are still open; this does not complete all-human expressions.


## Seated torso breathing — 2026-09-11

The seated mother now has a 4.8-second breathing cycle with at most three
registered source pixels of upper-body rise. A dedicated 24-vertex flat or
96-vertex relief card mesh deforms the torso smoothly while the lap/feet remain
fixed; head and eyelids travel with the same card surface. Native NPC position,
chair offset, collision and texture coordinates are unchanged. No extra canvas
is created and breathing does not recompose the seated texture.

The helper caches at most eight card meshes, shares unchanged amounts between
calls, returns the exact original card for zero amplitude, and explicitly
releases its meshes on renderer teardown. The presentation clock runs during
idle/owned conversation; overlays, invalid scene/source and existing central
switches cancel it. Existing head-turn and blink tests remain in the native run.

Native mother-breath-native.log: peak amplitude .999995, 1,253 unchanged
open-eye texture frames; 1,273 prepare calls with CPU submission mean/p95/max
.02581/.04179/.13554 ms. This path called the helper once per rendered frame;
shared-pass reuse is tested separately in the unit test, not claimed from this
native sample. It is not a whole-frame or completed-GPU benchmark. Native build
work was 118.32 ms over 15 steps, peak 35.75 ms; cold-load stalls remain open.

GPU exhale/half/inhale images were inspected; the lower lap/feet render stays
unchanged within one byte of interpolation rounding. Unit tests cover fixed
anchors, flat/relief topology, zero-pose identity, bounded cache/release and
30/60/120 FPS cycle timing. Evidence: mother-breath-render.log,
human-motion-seated-breath.log and mother-breath-native.log. The payload has
51 files. Side-view eyelids and the existing neck/collar join still need visual
refinement; broader all-human acting and performance acceptance remain open.

## Seated collar correction — 2026-09-11

The body plate now retains source rows 550–604, preserving the authored shoulder
tops and collar under the moving head. The former horizontal cut at row 605
removed them. Source PNGs, head motion, blink masks and chair placement are unchanged.

Real GPU comparison against the previous mask checks nine angles from -1 to 1:
546–593 formerly transparent shoulder pixels are now filled in the sampled band;
all pixels outside output rows 275–302 are byte-identical. Straight and side
endpoints and two intermediate poses were visually inspected. Existing blink
(alpha/outside-eye invariants and exact reopening), breathing (fixed lap/feet),
full motion runner and native chair/dialogue/Classic/Vanilla tests passed.
Evidence: qa/mother-collar/{mother-collar-render.log,mother-blink-collar.log,
mother-breath-collar.log,human-motion-collar.log,mother-collar-native.log}.

Visual inspection also exposed significant double contours in head interpolation,
especially angle -.25 (front to left three-quarter). The collar fix does not
resolve this. Native functionality tests are insufficient evidence of morph
quality. This remains an explicit release blocker, alongside angled blinking,
all-human acting coverage and whole-frame performance. Native cold load in this
run peaked at 38.22 ms per slice; no stutter-free claim is made.

## Head ghosting diagnosis — 2026-09-11

Read-only pixel comparison rules out stale analysis input: production head layers
1, 2 and 5 exactly match the images used for the shipped displacement fields.
The front-to-left field instead has incorrect face correspondences (nose moves
about 11.5 source pixels left instead of the visually estimated 44).

Separate QA-only landmark registration and inverse-solver experiments were
rendered at three intermediate stages. Global hair/face spline registration
folded the silhouette. Face-only registration with Newton inversion improved the
eye, but retained double hair contours; Newton inversion on the shipped fields
alone also produced unstable pixels. None was promoted to production or the
payload. Evidence and precise rejection reasons are recorded in
qa/vasc-human-motion-native/mother-flow-landmarks/review.json, alongside two
reproducible LOVE labs. Next: direct orientation-preserving face interpolation
and separate hair visibility, followed by actual intermediate-frame visual QA.

## Direct head mesh prototype — 2026-09-11

QA-only front-to-left-three-quarter rendering now uses a shared 54-triangle
surface with two UV sets. Forward vertex interpolation removes the iterative
inverse solver. A common triangulation, with necessary diagonal flips, preserves
positive signed area over the full continuous interval: the verifier evaluates
the quadratic area at endpoints and every interior stationary point. This is a
geometry invariant, not visual acceptance.

Three real GPU intermediate renders were inspected. Added jaw, mouth and
forehead correspondences improve facial alignment, but hair tufts, ponytails
and ears still double, and the hairline has local kinks. The prototype remains
outside production. Reproduction/evidence: mother_mesh_probe.py,
mother-mesh-lab/, mother-mesh-geometry.log and mother-mesh-review.json in the
private non-Orange QA root. Next work is separate hair visibility and correct
face/ear boundaries; extending this incomplete prototype to other pairs would
not establish the requested quality.

## Back-hair occlusion prototype — 2026-09-11

QA-only mother-hair-lab separates the ponytail and tuft from the direct face
mesh. Back hair is composed before the seated body and face. Seven intermediate
GPU renders check 52,645 body pixels per frame against a no-back-hair reference.
The allowed contribution is bounded by the original body transparency plus one
byte of rounding; the test asserts nonempty coverage. This verifies layer order,
not completely opaque artwork.

Visual middle-angle inspection shows the duplicate side ponytails replaced by
a tail that passes behind the head/body. Tuft alignment improves, but doubled
arcs, hairline kinks and ear/outer-head overlap remain. The prototype is not
installed in production and has no gameplay/performance acceptance. Evidence:
mother-hair-render.log, mother-hair-review.json, mother-hair-lab/ and seven
mother-hair screenshots in the private non-Orange QA root.

## Measured head contours — 2026-09-11

The QA-only contour prototype replaces approximate temple controls with alpha
silhouette samples at eight source rows. Its 82 triangles preserve winding over
the continuous interval (minimum signed double area 2). Seven GPU stages retain
the body-occlusion regression; early/middle/late images were visually inspected.
Outer hair double contours are reduced. An additional five-anchor ear mapping
created kinks and was rejected rather than promoted.

Evidence: mother_contour_probe.py, mother-contour-lab/, geometry/render logs and
mother-contour-review.json in the private QA root. Partial-alpha pixel counts
are recorded only as a contour-overlap diagnostic, not as visual acceptance.
Ear overlap, tuft arcs and endpoint transitions remain open. All of this remains
outside the production payload until those defects and the other turn pairs
are addressed and native gameplay/performance checks pass.

## Consistent endpoint composition and blink — 2026-09-11

QA-only mother-endpoint-lab now uses the same mesh/back-hair/body order at t=0
and t=1 as between them. The previous prototype switched to an unsplit source
quad at endpoints, changing hair/body occlusion. GPU tests at offsets .01, .001,
.0001 and .00001 approach both endpoint images. At .00001 the maximum channel
difference is within 1.01/255 and the mean max-channel difference below .00002.
This verifies local endpoint convergence, not complete animation quality.

The existing front eyelid formula is explicitly applied in the mesh shader.
Four closure levels preserve alpha and change only the eye region; reopening
restores identical bytes. Both endpoint images were visually inspected.
Evidence: mother-endpoint-render.log, mother-endpoint-review.json and the LOVE
lab in the private QA root. This remains a single-pair prototype outside the
production payload. Intermediate ear/tuft artifacts and all-pair/native
integration/performance acceptance remain open.

## Tuft ribbon experiment rejected — 2026-09-11

QA-only paired alpha-interval strips align the upper tuft arc, but smear its
root where the number of visible alpha intervals changes and the strand joins
the crown. A more restrictive lower mask did not fix this. The 640-triangle
prototype is rejected for production; extra tessellation is not evidence of
better quality. Endpoint convergence and blink checks passed despite this
visible defect, so those checks must not be used as visual acceptance.

Evidence: mother_tuft_probe.py, mother-tuft-lab/, mother-tuft-render.log and
mother-tuft-review.json in the private non-Orange QA root. Retain the prior
endpoint/contour prototype as the less distorted baseline. The strand root
requires a topology-aware separation rather than row-by-row interval matching.

## Seated mother side-dialogue blink — 2026-09-11

The production seated pose now supplies eye boxes for the front view and both
fully turned head views (layers 1, 3 and 6). The shared eyelid shader receives
the selected view's boxes. Only exact endpoints admit the overlay; intermediate
head morphs suppress it. The idle clock now also runs during an owned mother
conversation after the head reaches its target. Unknown overlays, movement,
source/map invalidation and existing Classic/Vanilla/pilot gates still cancel it.
No new textures, canvases or shaders are added by the side profiles.

GPU open/half/closed renders for all three views preserve alpha, confine changes
to the eye band and restore open eyes byte-exactly. Images were inspected,
including both closed side views and a half-closed side view. Tests at
30/60/120 FPS verify both owned-dialogue directions blink and head movement
never receives an eyelid overlay. The full human-motion runner passed.

Native normal world:interact conversations passed on both sides: blink peaks
.99347 left and .99790 right. Actual dialogue captures were inspected. The run
also passed chair-position, unrelated-overlay, front idle, breathing and
Classic/Vanilla/pilot fallback checks. Evidence: mother-side-blink-render.log,
human-motion-mother-side-blink.log, mother-side-blink-native.log and the new
side-blink lab/captures in private non-Orange QA.

This closes the missing settled-side eyelid behavior; it does not repair the
known ghost contours during head interpolation, extend the seated pilot to
Johto, or establish all-human/performance acceptance.

## Single-texture curved head experiment — 2026-09-11

A QA-only 64 by 40 cell mesh projects the front head through a curved surface
at seven angles from -45 to +45 degrees. The neck deformation fades to zero
at source row 226. Every pose samples only head layer 1, eliminating the
two-view blending mechanism in this experiment. LOVE rendered all seven
poses successfully; the front and both extreme views were visually inspected.

The extreme views compress the front drawing and retain front-view facial
features instead of reproducing the authored side views. This is not accepted
as the mother's dialogue head turn. The prototype also does not remap the
production side-view eyelid boxes, so its renders intentionally use blink=0;
they provide no evidence of side-blink compatibility. No production renderer,
head asset or blink profile was replaced. The existing review package is
unchanged, and the known production head-morph ghost contours remain open.

Evidence in the private non-Orange QA root: mother-curved-head-lab/main.lua,
mother-curved-head-lab/morph.lua, mother-curved-head.log and
shots/mother-curved-1.png through mother-curved-7.png. This isolated experiment
does not diagnose intermittent native sprite flashes elsewhere in the game.


## Dense authored head-turn experiment rejected — 2026-09-11

A built-in Imagegen experiment requested eight small yaw increments from front
to -28 degrees, fixed neck pivot and true RGBA on a 4x2 grid, using the prior
mother pose artwork as identity reference. The output was RGB 1774x887, with
baked checkerboard and dimensions indivisible by the requested grid. Visual
inspection also found an abrupt ponytail side switch between cells 2 and 3,
uneven yaw increments and neck/scale drift. It is rejected, not installed.

Read-only `audit_sprite_sheet.py` now diagnoses actual alpha, integer cell
grid, per-cell opaque subject/transparent padding and visible bounds. The
rejected sheet fails the alpha and grid checks; the existing production
heads.png passes its actual 3x2 layout. Existing production background RGB
colors have alpha zero; their appearance in a preview is not evidence of a
visible backdrop in LOVE. This diagnostic cannot establish visual continuity.
No source PNG, production renderer or review-package payload changed.

Evidence and exact built-in prompt: private QA art-review/mother-dense-turn-v1/
(PROMPT.md, rejected-sheet.png, inspection.json, production-alpha-audit.json).
The experiment does not solve production morph double contours. Further
head work needs temporally consistent hair attachment and face/ear geometry;
this generated full sheet is not a usable source for optical flow or gameplay.


## Oak dialogue eyelids (2026-09-11)

Oak's two hash-validated 256x256 turn endpoint textures now have reviewed eye
rectangles and procedural eyelid sweeps. human_turn uses the existing human_idle
schedule only at an exact settled endpoint. Starting a turn cancels eyelids;
unsupported directions, actor/reset/options epochs clear the schedule. Blue's
rear turn has no eye profile. This adds two acting endpoint treatments, not
two ordinary atlas sources: the ordinary coverage remains 87 arm / 20 blink.

Actual LOVE GPU tests verify partial/full closure in both endpoint views,
unchanged alpha and opaque non-eye pixels, and no eyelids during interpolation.
The six-cell gallery was inspected. The portable test lives under
tests/human_turn_blink_runner. The regular human_motion_runner also passes;
its turn test now exercises the real idle schedule, multipass caching, turn
cancellation and reset. An initial test setup failure retained the preceding
injected GPU-failure flag; clearing it before the new case corrected the test.

A private Red native run follows the real Pallet high-grass trigger and escort
through six laboratory dialogue boxes. Oak reaches full scheduled eye closure
while facing Blue and while facing Red (peak 1 in both); captures were inspected.
It also passes Blue turn continuity, 15 exact native pause observations,
Classic/Vanilla shutdown and stale-dialogue epoch rejection. Logs are checked
for swallowed runtime errors as well as terminal successful completion.

This does not fix the known optical-flow double contours during head/body
turns, add front-facing dialogue blinks to other actors, or establish global
performance acceptance. Only open-eye settled frames retain the prior canvas
cache; active eyelids redraw their small canvas. No Orange access. Evidence:
oak-dialogue-blink/ in the review package.


## Elm interaction-owned dialogue idle (2026-09-11)

New human_dialogue_idle.lua admits only the exact bound Professor Elm source
in ELMS_LAB during a directly initiated NPC conversation. It is controlled by
the existing DIALOGUE POSES (TEST) switch plus NATURAL, HD PEOPLE and people
grid OFF. The option descriptions now include Elm. This extends the pilot's
Johto coverage to dialogue breathing/eyelids, not diagonal/head poses. Ordinary
arm/eye atlas coverage remains 87 / 20.

Ownership starts with world.interacted kind=npc and binds the ensuing
script.started context only when VM, script key and object index match. Johto
resumes its coroutine BEFORE invoking showTextFn, so a coroutine.running
check at screen.pushed was correctly found insufficient in the first native
run. The final adapter wraps only that active VM's showTextFn, preserving its
return values/errors, and captures only the textbox pushed during its actual
text request. General humanScene remains closed. Source/world/save/map/actor
identity, frozen stationary position and exact current box are required.
Other actors and the player remain ineligible. Dialogue entry/exit clears
travel state; weight shifts are disabled in this dialogue pilot.

Script end or reset restores the VM callback if still owned; another mod's
later wrapper is preserved. Map/save/options changes clear ownership. Classic,
Vanilla and grid activation disable the adapter; re-enabling does not revive
an existing dialogue. Missing/replaced source or actor action invalidates it.

Native private Crystal test: actual World:interact with Elm, 2,310 sampled
textbox frames, zero missing motion states, full blink peak 1, breath range
.006, no walking/arm stride/weight shift, and no bystander/player admission.
Closed-eye screenshot inspected. Classic restores the exact VM callback and
clears motion; Natural/Vanilla toggles cannot resurrect the old dialog. The
final ordinary regression runner passes, including the new admission tests
for foreign textboxes/actors, signs, script/object mismatch, movement, source
action, map/save/VM changes, option shutdown, callback restoration, later
wrapper preservation and original text errors. Final native log is checked
for swallowed errors as well as terminal success. Subsequent defensive nil
source/nonnumeric index guards are covered by the final unit run.

The private fixture sets both save and live mapScenes to 1 before interacting.
It does not validate automatic Elm map-entry cutscenes or other Johto actors.
It also does not resolve the existing optical-flow double contours or provide
a global performance approval. Evidence: elm-dialogue-idle/ in review package.
No Orange access.


## New Bark mother dialogue idle (2026-09-11)

The interaction-owned Johto pilot now admits the exact johto-mother atlas in
PLAYERS_HOUSE_1F as well as Elm in ELMS_LAB. Admission profiles pair each map
with its role and source; neither actor inherits the other map's permission.
A captured map object's label is also pinned against in-place relabelling.
The existing dialog test switch and Classic/Vanilla/grid restrictions apply.

Native private Crystal run uses the real mother and World:interact after
setting scene 1 in both private save/live scene stores. It observes 2,455
textbox frames with motion present, blink peak .98965, breath range .006,
neutral legs/arms and no weight shifts. Other human NPCs and the player do
not inherit permission. Classic removes the VM wrapper; subsequent Natural
and Vanilla toggles cannot revive the old dialogue. Screenshot inspected;
process terminates successfully and log is error-checked. Unit coverage adds
the mother route, wrong actor/map pairing and in-place map relabelling; the
complete regression runner passes.

Explicit outstanding user requirement: THE NEW BARK MOTHER MUST ALSO SIT ON
HER OWN CHAIR. This patch still uses her standing atlas, and does not satisfy
that requirement. Her seated body, chair alignment and dialogue head turn are
next visual work, distinct from Red's seated mother. Automatic introductory
scenes and dialogue choices remain outside this direct-interaction acceptance.
No all-character completion or global percentage is claimed. Source arm
coverage is 87/198 (about 44%); this is not overall task completion.

Evidence: johto-mother-dialogue-idle/ in the review package. No Orange access.


## Opposite New Bark guest dialogue ownership (2026-09-11)

The direct-conversation adapter now also admits the requested opposite woman,
PLAYERS_HOUSE_1F object index 5 with the exact base pokefan-female-gen2 atlas.
All routes are explicit map/role/atlas/object-index pairs (mother index1,
Elm index1). Matching artwork in another slot does not inherit admission.
This prepares exact ownership for the pending seated rendering of both women.

Private native Crystal test interacts with the real guest at cell4,4. Across
2,572 textbox frames her presentation state is available and breathing varies
by .006; no arm stride, walk or weight shift is introduced. Mother, player
and other human bystanders remain ineligible. Classic restores the exact
VM text callback and clears motion; re-enabling Natural/Vanilla cannot revive
that conversation. Native screenshot inspected, process exited successfully,
log error-checked. The ordinary regression runner passes, including the new
guest route, wrong participant and same-looking wrong object slot exclusions.

The logged blink clock peak is NOT evidence of visible guest eyelids: this
ordinary source has smile-closed front eyes and no admitted eye-render profile.
The two women still use standing artwork in production. Their seated body
plates, natural head motion and seated blinking remain outstanding. The
seated QA experiments are not promoted by this change. No Orange access.
Evidence: johto-guest-dialogue/ in the review package.
