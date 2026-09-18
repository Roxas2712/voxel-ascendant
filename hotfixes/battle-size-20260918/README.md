# Battle sprite source density

Paired local candidate: KASC 6.7.14-rc.3 + VASC 3.0.28-rc.4.

KASC publishes a fixed card-density receipt and retains uncut 96px form masters. VASC normalizes that density before its existing constrained Pokédex height curve. Active form heights retain ownership; native/trainer/Mega/Gorochu policies remain. The Route-22 camera implementation is retained exactly.

Reproducible QA scripts and evidence are in `/Users/maarten/Documents/Recompile/output/battle-sprite-size-20260918/`: `runner/` (actual provider functions and GPU canvases), `audit.py` (full selected catalog/image inventory), `native_run.py` (isolated native game captures), `run_integrated_tests.py` (transferred fixes), `build.py` (exact ZIP overlay, syntax/CRC/hash checks), and `installers.py` (preserving installer fixtures). The native fixture modifies only its own identity.

Reviewed artifacts and detailed limitations are in `/Users/maarten/Documents/Recompile/deliverables/KASC-VASC-Kampfgroessen-20260918/Pruefbericht.md`. Full-catalog metadata/image checks do not claim a complete manual playthrough of every form. No public release or active game installation was changed.
