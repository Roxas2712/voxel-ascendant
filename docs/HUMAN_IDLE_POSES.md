# Human idle weight shifts

Natural mode now adds an occasional foot-anchored weight shift to reviewed
human rigs. After movement, eligibility resumes only after two seconds; the
clock then waits 8–14 seconds. Entry and exit each take 1.2 seconds, with a
1.8–3.2 second hold and a fresh quiet interval before the next shift. Separate
per-actor phase and serial state keep this independent of the blink clock and
the engine RNG. Pauses, reversed/nonfinite time and ineligibility reset it.

The deformation is x += neutral_y × lean. Ground-height points stay fixed;
height, depth, UVs and shade are unchanged. Maximum lean is .012 for reviewed
sources, .006 for Fisher, and zero for Gentleman and his variants so the cane
remains supported. It reuses the actor's existing mesh; no new textures or
bitmap assets are required. Unknown sources never reach this rig path.

Classic, Vanilla, dialogue/action/context guards stop the new pose through the
existing presentation admission. Actual movement cancels the shift immediately.
Native Red and Kris checks prove a nonzero lean reached the rendered mesh and
was cancelled by movement, Classic, Vanilla and a real TextBox. Pure-clock tests
cover 30/60/120 Hz, smooth rates, cooldown, multipass and reset. Geometry tests
cover every old sample, restore to neutral, and unchanged floor anchor. Direct
API checks verify Gentleman performs no vertex upload for a disabled shift.

Evidence: idle-shift-regression.log, native-idle-shift-red.log,
native-idle-shift-crystal.log, idle-shift-geometry-heroes.log,
idle-shift-geometry-equipment.log. A production-mesh Red left/neutral/right
comparison was visually viewed. These checks do not resolve the earlier
out-of-draw frame-pacing pauses or prove broader device performance.

Folded arms remain unfinished. Built-in image generation produced a Red pose
draft with an opaque checkerboard; the background correction was rejected by
the image service. The draft and prompt are retained only under the private
QA art-review directory and excluded from the payload. No alternate generation
route was used. Facial smiles, other acting poses and the remaining character
sources still require work; this is not completion of the overall goal.
