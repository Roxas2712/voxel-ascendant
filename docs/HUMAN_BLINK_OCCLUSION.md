# Current blink coverage: 23 exact sources (2026-09-11)

Archer and Ariana now blink in front and side views. Ariana uses a reviewed eye-only color exception so red iris pixels close without erasing red hair. All21 previous sources remain byte-identical across252 interleaved GPU comparisons. Native Gen1/Gen2 closure, movement and per-role fallback checks pass. Evidence: executive-blink/README.md in the review bundle. Historical notes follow.

# Giovanni sloping-eye support (2026-09-11)

Giovanni now has front/side procedural blinking that preserves his diagonal upper eye contour. 21 exact sources are covered. The prior 20 sources remain byte-identical across 240 GPU comparisons, including shader reuse after Giovanni. Gallery, native Red/Crystal evidence and limitations: giovanni-blink/README.md in the review bundle. No raster source was changed. Historical notes follow.

# Eyelid sweep without iris compression

Both packed and procedural eyelid shaders now reveal the original source iris
below a curved moving lid boundary. Source eye coordinates are never rescaled.
This affects the six heroes plus Oak, Elm and Misty; it adds no new characters.
The 170 ms blink clock, scene admission, classic/Vanilla behavior and texture
cache remain unchanged. Fully closed outputs are byte-identical to the preceding
renderer for all 27 supported directional faces.

A production LOVE pixel comparison renders 108 partial/full outputs and checks
8,560 uncovered eye samples against the original source pixels. All match within
one channel quantization step. The preceding compression renderer alters 5,560
of those samples by more than .02, confirming this comparison detects the old
behavior. Complete closure matches exactly. Source alpha and opaque pixels
outside the eye regions also pass the gallery checks. Three galleries cover
all nine characters, open/half/closed and front/left/right, and were inspected.

Evidence: blink-occlusion-pixels.log, blink-occlusion-heroes-{a,b}.log,
blink-occlusion-npc-gallery.log and the corresponding images. The shader adds
no canvas or texture and removes the shifted iris sampling. This is a visual
correction, not evidence that global frame-time spikes have been fixed.

Native Red tests pass visible blink cancellation on classic, Vanilla, dialog,
actual player movement, script/input locks and option/map restoration. They also
pass independent canvases, the 32-canvas bound, duplicate/open render reuse and
missing-asset fallback. Crystal repeats player cancellation with Kris and checks
Oak/Elm/Misty as separately bound NPC records in three directions, with movement,
classic and dialog cancellation. These are renderer-level tests in the private
non-Orange engine; logs: blink-occlusion-resources-red.log and
blink-occlusion-crystal.log.


## Daisy and NPC Blue idle eyes — 2026-09-11

Added exact daisy-oak v2 and NPC blue v2 front/left/right procedural eye
regions. No new bitmap assets are needed. Source/role admission now resolves
explicit alternate eye profiles using path-segment boundaries. Shader resources
are cached per profile, not just role; output canvases also invalidate when
the resolved profile changes. Thus the playable Blue's packed eyelids and
NPC Blue's procedural lids cannot reuse each other's shader or rendered eyes.
The same record/texture switching hero → NPC → hero is a regression case.
Gym/action/unreviewed/suffix-collision paths remain excluded.

The six-face GPU gallery checks original alpha and opaque pixels outside eye
regions, shared procedural shader, and no rear-view overlay. Open, half and
closed front/side views were visually inspected. Native Red/Crystal private
interior tests bind independent NPC records and exercise scheduled idle blinking,
side views, rear rejection, Classic and Vanilla. The ordinary idle atlases are
covered; this does not add eyes to custom diagonal dialogue poses or finish
Daisy's separate seated/dialogue behavior.

Evidence: opening-blink-gallery.log, opening-blink-{red,crystal}.log,
human-motion-opening-blink.log, opening-blink-gallery.png and native captures.

## Johto mother ordinary-card blink — 2026-09-11

Added an exact-source procedural profile for
`npcs/johto-mother-kasc-hd-4x3-walk-sheet-v1.png` (495×900), using role
`johto-mother`. Front and both side rows have separately reviewed eye regions.
The gallery checks original alpha and pixels outside the eye region; open, half
and closed views were visually inspected. No additional eyelid image is loaded.
The existing central Natural/Classic/HD gating and rear/walking exclusions apply.

The isolated Crystal driver exercises a bound mother card through a scheduled
6.2-second blink window, both side rows, rear exclusion and Classic/Vanilla
switches. It also checks the actual mother's atlas/role binding in PlayersHouse1F.
This is an ordinary-card idle addition, not seated Johto acting or dialogue
head turning. The ordinary blink catalog now covers twelve exact atlases;
all-character blink/acting coverage remains incomplete. Evidence:
johto-mother-blink-gallery.log/png, johto-mother-blink-native.log and
human-motion-johto-mother-blink.log in the non-Orange QA root.

## Actual New Bark rival — 2026-09-11

The playable Silver and native rival already use the same exact reviewed
`npcs/silver-kasc-hd-4x3-walk-sheet-v1.png` source and `silver` role. No duplicate
profile or new coverage count is added. A private Gen2 run observed the actual
`NEW_BARK_TOWN_obj_3` for 6.2 seconds: blink peak 1, side row 3. The same actor's
output stopped updating under Classic and HD-off/Vanilla. Both options were
restored before the final capture.

The first camera placement left the rival outside the screenshot; the final
run used player position (3,4) and captured the rival beside the laboratory
during a closed-eye phase. Native actor position and sprite were not replaced.
Evidence: integrated-silver-native-idle.lua, silver-native-idle.log and
silver-native-blink-closed.png/silver-native-newbark.png in the private QA root.
This verifies idle integration at the actual map actor, not rival dialogue
acting or walking scenes.

## Ordinary Kanto mother card — 2026-09-11

Added exact-source procedural eye boxes for
`npcs/reds-mother-kasc-hd-4x3-walk-sheet-v2.png`, role `reds-mother`. This makes
the ordinary card blink with Natural enabled even when the seated/dialogue
pilot is off. Front/left/right open, half and closed views were rendered and
inspected. The right-eye bounds were corrected to avoid sampling a dark mouth
pixel as eyelid skin. Alpha and pixels outside the eye region remain intact.

The private Red runner exercises the real REDS_HOUSE_1F_obj_1 in its normal
side-facing idle with the acting pilot explicitly disabled, then Classic and
HD-off/Vanilla. This is separate from the seated mother's existing endpoint
blink behavior. The ordinary blink source count is now thirteen, not complete
all-character coverage. Evidence: red-mother-blink-gallery.log/png,
standing-mother-blink-native.log, human-motion-standing-mother-blink.log and
the corresponding private drivers/captures.


## Bill and Kurt idle eyelids — 2026-09-11

Added exact bill/kurt v1 front/left/right procedural eye boxes. The ordinary
blink profiles now cover 15 exact atlases; arm registration remains 82/198.
Kurt's side boxes extend below the dark lower-eye boundary so the existing
shader samples cheek skin rather than gray outline pixels. His large brows
remain outside the eye replacement. No source raster or shader was changed.

GPU galleries use the production profile/module, cover open/half/closed eyes
in all three faces for both actors, assert unchanged alpha and opaque pixels
outside the eye region, shared procedural shader allocation and absent rear
eye output. The final gallery and native Red closed-eye captures were visually
inspected. Native private Red/Crystal fixtures independently bind both NPC
cards and exercise 6.2 seconds of scheduled idle (peaks 1/1 in Red, ~1/.99856
in Crystal), both sides, rear rejection, moving-eye cancellation, Classic and
HD-off/Vanilla. These are injected independent render actors in ordinary
interiors, not verification of Bill/Kurt story scripts or their home maps.
The full human-motion regression runner passed.

Evidence in private non-Orange QA: bill-kurt-blink-gallery/main.lua and its
log/image, integrated-bill-kurt-blink.lua, bill-kurt-blink-native-{red,crystal}.log,
bill-kurt-blink-regression.log and bill-kurt-idle-blink-{bill,kurt}-gen1.png.
Broader character coverage, dialogue acting and head-morph ghosting remain open.

## Bruno / Chuck — 2026-09-11

Exact v1 front/left/right procedural profiles bring ordinary blink coverage to 25 sources. Source-reviewed sloping lid starts preserve eyebrows; tightened Chuck boxes avoid sampling mouth shadows. Native Gen1/Gen2 closure, movement cancellation and per-role Classic/HD-off restoration pass. Enlarged six-face production gallery visually reviewed, with alpha/outside-eye invariants. Previous 23 profiles remain byte-identical across 276 real-GPU outputs. Full human-motion runner passes. Evidence and limited synthetic NPC placement scope: martial-blink/README.md. Universal blinking, story acting and seated head turns remain incomplete.

## Karen / Will mask apertures — 2026-09-11

Two exact v1 profiles bring ordinary blink count to 27. Will has source-reviewed convex eight-point eye apertures and cheek samples; outside-aperture pixels and alpha are preserved by a portable GPU regression. All prior 25 sources remain byte-identical in 300 GPU outputs, interleaving the new clipped profile. Native Gen1/Gen2 movement/fallback and Gen2 extreme-volume closures pass. See elite-four-blink/README.md for visual review, failed prototypes, boundaries and functional scope.

## Koga / Koga Gen2 — 2026-09-11

Separate exact v1 eye boxes and sloping upper boundaries preserve thick brows. Final six-face gallery checked; initial thinning candidate rejected. Alpha/outside-eye/upper-brow invariants pass. Previous 27 sources remain byte-identical across 324 GPU outputs. Native idle closure, movement reopening and per-role fallback pass in both generations. Full runner passes; ordinary blink count now 29. Scope: koga-blink/README.md.
