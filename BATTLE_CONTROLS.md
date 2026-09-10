# Personal battle controls

Available in Voxel Ascendant 3.0.19, based on 3.0.18 with its camera, support-report and gatehouse fixes preserved.

Gen 1: Voxel Ascendant → battle settings. Gen 2: Voxel Ascendant → Skins & Overlays.

- **BUTTON SIZE:** 50–150%; default 100%. Applies to the command group and attack selection independently of status cards.
- **BUTTON X:** horizontal offset in viewport percent; default 0%.
- **BUTTON LIFT:** upward offset in viewport percent; default 0%.
- **BUTTON TRANSPARENCY:** 0–90%; default 0%. Fades the entire controls, including Mega, attacks and Back. Status cards and hit targets are unaffected.
- **BUTTON SHAPE:** AUTO retains the original assets at default values. Personal positioning/scaling selects completed ORAS artwork. ORIGINAL forces the existing cropped assets. COMPLETE ORAS forces the completed artwork. GLASS selects the optional transparent code-drawn controls.
- **RESET BUTTONS TO DEFAULT:** restores only these five settings. Status cards, actor positions, authored Card data and other player settings are untouched.

The group includes the conditional Mega button. Gen 1 retains its existing direct command, attack, Mega and Back input, using the transformed drawing rectangles. Gen 2 publishes command, attack and Back hit areas from each successful rendered frame; the existing Mega input bridge owns touch capture, mouse clicks and Android coordinate remapping. Native battle dispatch remains responsible for move legality and all battle rules. Resize, ownership and phase changes invalidate stale input.

The completed artwork is a reconstruction from the existing EN/DE sprite references, generated with Imagegen; it is not a newly recovered official sprite rip. Existing asset files are byte-for-byte unchanged. New source art is stored under `assets/hud/oras/completed`. The renderer removes the generated magenta background and crops its empty margins once when loading each completed sprite. The optional GLASS style is separate from the completed original-style artwork.

Validation: LuaJIT compilation in native LÖVE; configuration/viewport/reset/input regression checks; existing command camera bounds, Safari ownership and Gen 2 draw-only UI checks; native LÖVE rendering of original/completed/glass variants including Mega. Physical smartphone/tablet playtesting has not been performed.

Since 3.0.20: **TEXTBOX X / Y** move the battle dialogue independently in 5% viewport steps (−60% to +60%, clamped to screen bounds). Negative Y moves up. Default is 0%. **RESET TEXTBOX TO DEFAULT** resets only these two settings; button and Card settings remain unchanged.
