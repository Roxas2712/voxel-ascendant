# Human motion handoff — 2026-09-11

Goal: natural gait, arms and suitable idle life for all shipped human cards,
with exact Classic/Vanilla fallback, scene safety, measured performance and a
reviewable package with rollback. No Orange tests, live installation, commit or
push were performed.

Current runtime coverage is 198/198 catalogued human arm sources and 84 exact
ordinary blink sources. All six heroes (Red, Green, Blue, Gold, Kris, Silver)
have verified gait, arm swing, breath, idle blink/weight shift and stopping in
both generations. The full runner passes 198 atlases, 2,376 frames and 9,504
flat/relief/grid/cube variants. Standard remains Classic; HD PEOPLE off is the
Vanilla path. Actions, missing assets, unsupported scenes and source changes
fail closed.

Opening-area acting is behind the separate default-off DIALOGUE POSES (TEST)
switch. Red's mother and Daisy sit at their exact Gen1 furniture; New Bark's
mother and opposite guest sit at their exact Gen2 positions. Owned dialogue
turns only the seated head toward the actual partner. Oak and NPC Blue follow
the real Pallet opening speaker/listener/observer sequence; Blue folds his arms
and smiles during Oak's choice speech. Elm has four diagonal dialogue views,
breath and blink. Actual New Bark Silver uses his exact ordinary atlas and has a
native idle/blink test; three bad checkerboard acting candidates were rejected
and are not shipped.

The final local workload renders the player plus six exact hero cards for 600
frames in each Classic/Natural idle/walk mode. Natural Walk p95/max is
17.369/17.605 ms in Gen1 and 17.402/17.595 ms in Gen2. Rig mean is 0.332 and
0.377 ms; blink mean is 0.008 and 0.012 ms. The only 37.005 ms sample was in
Gen1 Classic and attributes 23.921 ms to the native event pump. Daisy's seated
blink call averages 0.0014 ms. Both New Bark seats pass full blink/head yaw and
show no old atlas behind the Natural seat.

Red's mother now shows exactly one authored head source per transition frame.
The small anchored turn cue replaces optical-flow blending and removes the
known doubled hair/eye/ear contours. Eight obsolete 256 KiB flow buffers are
gone. Nine GPU stages and both real dialogue directions pass. Turn submission
is 0.0257/0.0505/0.1020 ms mean/p95/max. Cold preparation uses six slices,
62.87 ms total active work and one remaining 26.58 ms native image decode/upload
slice queued at map entry; the pilot remains default off.

Authoritative locations:

- Repository: `<workspace>/vasc-smooth-character-walk`
- Native QA: `<workspace>/qa/vasc-human-motion-native`
- Review bundle: `<workspace>/deliverables/VASC-human-motion-review-20260910`
- Final evidence: `pending-review/final-performance/` and bundle
  `final-performance/`

The current manifest contains 53 runtime files based on VASC 3.0.20 commit
`19039d6c`. `build_review.py` cleans and reconstructs payload/docs/final evidence.
`test_installer.py` verifies read-only check, atomic apply, complete backup,
exact rollback, repeated-apply refusal, divergent-target refusal and preservation
of later edits. The ZIP must be rebuilt and hashed after any further change.

Deliberate limits: ordinary eyelids remain source-reviewed rather than universal
for obscured/masked faces; unreviewed furniture and scripted relocations do not
inherit seat behavior; the local timing run cannot guarantee other hardware or
operating-system driver behavior. The shipped source PNGs and raster/grid art
remain byte-identical. Existing side A/B artwork is sometimes visually similar;
the runtime planted-step transfer improves continuity without inventing mirrored
shoe pixels.
