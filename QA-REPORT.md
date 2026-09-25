# VASC 3.0.49 validation

Date: 2026-09-25. Full package retains 3.0.48.

All 251 Crystal size references and fallback cases passed the size regression; existing overworld-size, battle-action, pose and lookup tests passed. Native Red battles checked Exeggcute and Bellsprout against the trainer. Native combined KASC/VASC checks cover Mira's Vanilla/HD/Voxel round trip, four facings, identity isolation and club interaction. No new native Gen-2 run or physical phone test is claimed. The separately reported automatic 3D-to-2D fallback trigger remains unconfirmed.


Packaging: every Lua file is compiled with the bundled Lua runtime; ZIP CRC and byte-for-byte source equality are checked. Embedded receipts, where present, are regenerated and verified. Public asset digests and anonymous downloads are verified after upload.

Limits: native tests use Red on macOS; no fresh native Crystal, physical phone/console test or complete playthrough is claimed. No changes to save-file formats.
