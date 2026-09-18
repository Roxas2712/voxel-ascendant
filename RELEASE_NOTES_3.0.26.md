# Voxel Ascendant 3.0.26 — Mobile controls hotfix

- Improved camera-relative touch movement in first- and third-person views, including touch skins. Stale touch directions are cleared when controls reset; active touch input takes priority over old controller-stick values.
- The VASC quick menu shows current settings and supports direct touch selection. A small translucent white **V** button stays visible on touch devices in the overworld and battle. Keyboard/controller selection remains available.
- Battle buttons automatically use complete artwork when the mobile layout raises them above the touch controls, even with manual lift at zero. The Pokémon button becomes a full circle; the simplified Glass style remains selectable.
- Battle-button transparency now defaults to **40% on iOS/Android** and **20% on desktop**. Existing saved transparency choices are retained; change **BUTTON TRANSPARENCY** to 40% if an older value is already saved.
- Fixed a mismatch between status-card placement and HUD copy bounds that could clip parts of the status cards. Free-roam mouse capture is released while the quick menu owns input and disabled for mobile/touch input.

**Update:** Replace VASC and fully restart the game. Preserve downloaded/imported content and user files. No new save or sprite/model re-import is required. KASC is unchanged.

**Known limitations:** A MAP battle can still fall back to 2D during move selection; this was also reproduced on 3.0.25. The MAP camera also stopped producing fresh frames after a landscape–portrait–landscape rotation in the test fixture. These separate camera issues remain open. The exact iPhone input report still needs physical-device confirmation.

**Validation:** Targeted Gen 1/Gen 2 input and button-layout tests, plus native Gen 1 runs on macOS with mobile inputs: touch movement, quick-menu actions, the persistent V launcher, full-button touch targets, Glass and portrait/landscape layouts. The mobile 40% appearance was checked in-game. No physical iPhone test is claimed. Archive CRC, Lua syntax and file-index hashes verified.
