# Voxel Ascendant 3.0.28-rc.4 — private test candidate

Based on the verified Route-22 camera candidate 3.0.28-rc.3.

- Consumes KASC's explicit source-card density before applying Pokédex-based battle sizing. Fixed density per animation card prevents frame-to-frame size pumping. Pair with KASC 6.7.14-rc.3 for exact animated and static/form receipts.
- Uses precise metric Pokédex height when available and preserves a valid active-form height receipt. Invalid measurements fall back safely.
- Older KASC Neo cards retain a bounded 56/96 compatibility correction. Native, trainer, Mega and Gorochu sizing policies are retained.
- Retains the complete rc.3 camera fix, including the MAP 0.45 lower bound, 1X/3X settings and camera fit from visible actor dimensions.

Local review build; no publication or installation implied. No physical mobile-device test.
