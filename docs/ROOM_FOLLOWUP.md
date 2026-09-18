# Interior and NPC follow-up

The selected KASC rival identity now wins over the static map sprite when VASC binds a human NPC, including objects created by `show_object`. This fixes Red being rendered as Blue in Oak's lab with Green selected as the player. The player movement identity fix remains intact.

Oak's lab artwork is cut at its authored wooden uprights instead of equal thirds. The botanical frames beside Charmander remain complete. Domestic back walls move forward by one native tile course where there is no north doorway, closing the gap left by removing the old wall course.

Wall exits now show opaque paneled doors with handles; two-cell exits use two leaves. Native collision and warp activation are unchanged. Authored staircase and ladder cells do not create decorative wall openings or doors. MS Anne remains excluded.

Daisy's exact stationary Blue-house seat now works with HD people even under CLASSIC and with the dialogue-pose pilot off. Head-turn animation still requires the existing NATURAL/dialogue settings. The moving Daisy, other actors, HD-off and the voxel character grid retain their guards. No sprite files were replaced.

Validation: 24 targeted regression scripts, complete human motion suite, native selected-Red identity refreshes and Daisy's default seated geometry, five room types with view rotations, SCENERY OFF/ON and window resize, real door and staircase transitions. Runtime coverage: macOS Gen1Recomp 0.2.57. Other platform playthroughs were not repeated.
