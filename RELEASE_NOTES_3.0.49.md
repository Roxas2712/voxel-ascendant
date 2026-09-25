# VASC 3.0.49 — Crystal battle sizes and Mira

Complete update based on 3.0.48. Recommended pairing: KASC 6.7.26. Published as a regular Latest release for the launcher; public test status remains unchanged.

## Changes
- Fit Cobblemon battle models to the occupied Crystal battle-sprite dimensions, correcting oversized Pokemon such as Exeggcute and Bellsprout. Both height and horizontal model extent constrain one uniform scale.
- Calibrate against the prepared animated pose so size stays stable across animation frames. Later species retain the existing Gen-2-style reference table. The scaling module is shared by both generations.
- Add dedicated HD and voxel artwork for Hunting Club leader Mira. Character-style switching restores her native KASC sprite, and other NPCs retain their own artwork.

Includes the complete 3.0.48 baseline, including the local Pokemon PNG color correction.

## Validation and scope
All 251 Crystal size references and fallback cases passed the size regression; existing overworld-size, battle-action, pose and lookup tests passed. Native Red battles checked Exeggcute and Bellsprout against the trainer. Native combined KASC/VASC checks cover Mira's Vanilla/HD/Voxel round trip, four facings, identity isolation and club interaction. No new native Gen-2 run or physical phone test is claimed. The separately reported automatic 3D-to-2D fallback trigger remains unconfirmed.

## Install
Close the game, update through the launcher or import Voxel-Ascendant-3.0.49.zip, and restart. Keep saves and optional/custom artwork. Use KASC 6.7.26 for Mira's unique identity and Hunting Club changes. No ROM, engine or player save is included.
