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
