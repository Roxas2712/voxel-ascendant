# VASC 3.0.50 — Team and PC layouts

Complete update based on 3.0.49, published as a regular Latest release for launcher updates. Recommended KASC pairing remains 6.7.26.

## Fixes and setup
- Fix nearly invisible names, levels, HP numbers and cursor in the native ORAS GLASS team menu. Light ink is now limited to glass panels actually painted; native white areas retain their original text colour. Includes transformed panels and native paint fallback.
- Name the existing full-screen default **ORAS FULLSCREEN** consistently, replacing the misleading ASC BOX label. Existing saved layout choices are preserved. PC boxes still follow the shared UI by default, whose fresh default is ORAS FULLSCREEN.
- Add **Team and PC layouts** to Your Look setup: START team, battle team, PC boxes and shared Pokémon UI. Choices remain drafts until Apply and survive Save for later / reopen.
- Show KASC's actual ability and held-item names in the full-screen team details. The normal PC selection now shows both fields too, without picking up the Pokémon or opening Equipment. Item changes refresh immediately; empty and unknown equipment remains a dash. Eggs do not disclose hidden metadata.
- Keep PC HP, Attack and Defence values and the six-slot team navigator visible alongside the new equipment rows. The shared Gen-II box presentation also gains these rows.

## Battle speed
The missing BATTLE SPEED option in engine 0.3.17 is separate: upstream removed that option and locks battle logic to 1x. This update does not override that engine decision. See [upstream change](https://github.com/bryanthaboi/gen1recomp/commit/a685f16e00595ab39f31b409ddf6e71507dfc950).

## Validation
Native Pokémon Yellow with KASC 6.7.26 and public engine 0.3.17: all three team styles; team and box ability/held-item display; item removal/reassignment; box pick-up/cancel; setup draft/apply/reopen; landscape and portrait Android touch layouts; native item-selection callback. Tests ran in LÖVE on macOS with Android layout simulation, not on a physical Android device. See QA-REPORT.md for checks and limits.

## Install
Close the game, update through the launcher or import Voxel-Ascendant-3.0.50.zip, then restart. Includes the complete 3.0.49 content and fixes.
