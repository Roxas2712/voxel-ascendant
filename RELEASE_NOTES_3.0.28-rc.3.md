# Voxel Ascendant 3.0.28-rc.3 — local candidate

Includes all rc.2 compression, sprite maintenance, animation migration and quick-menu changes.

- Route 22 MAP battles: two reviewed east/west positions replace the unusable east-edge court. All 40 native grass cells now resolve a safe position on the same map. Existing collision, terrain and visibility checks remain active.
- Gen1 MAP camera: new/unset distance starts at 1X instead of 3X. Explicit saved 1X/2X/3X choices stay intact; authored ARENA still starts at its reviewed 3X master.
- Deliberate orbit/pitch can move from constrained static camera seats in both directions, with world/path, actor and HUD validation. The automatic director remains constrained.
- Zoom retains the last safe intermediate point instead of returning to the start of a long wheel/pinch gesture. A close-up may reframe above the command dock without silently widening the requested lens. Small MAP actors no longer have an unconditional 1X fit floor.
- Q/E now match their labels (Q closer, E farther). Mouse wheel preserves fractional/multiple notches. Touch drag/pinch and controller zoom use the same camera guards.
- Gen1 battle quick menu adds starting camera distance and centre/reset controls. Explicit setting changes supersede pending gesture rollback.

Validation: native Yellow battles in both Route 22 grass regions, all 40 grass-cell placements; simulated mobile portrait/landscape, desktop mouse/keyboard and synthetic controller inputs; MAP move selection; camera/HUD/collision/input regression tests; archive CRC, Lua syntax and payload checksums.
No physical iPhone/Android or Windows device tested. Gen2 camera behavior is unchanged. Local RC only, not publicly uploaded.
