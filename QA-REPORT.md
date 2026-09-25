# VASC 3.0.52 validation

2026-09-25. Complete package based on 3.0.51.

- Terrarium zoom regression: actual camera and input modules; fixed eye/focus/up/pitch, optical scaling and shadow framing, bounds, canonical/VR view, no mutation of service-owned camera data, per-battle restoration and independence from MAP/DISCS distance preferences. Fails against 3.0.51 as expected.
- Zoom profile tests: restore with a fresh instance, coalesced writes, final flush, bounded retry after write failures, per-playthrough isolation and malformed/non-finite input handling. Native two-process restart verifies the stored zoom with the real engine storage.
- Existing Terrarium location, both-arrangement, idle-rocking, lighting/cache and resource-release tests passed.
- Existing hidden-actor camera ownership and battle-view transaction/recovery tests passed, including preservation of the old view on failed replacement.
- Native LÖVE/macOS: Cerulean Gym Terrarium, Pikachu/Starmie and Crystal artwork; Q/E, wheel, left/right stick clicks, actual two-finger pointer event routing, landscape/portrait, both arrangements and an attack. Fixed camera pose asserted and screenshots inspected.
- Packaging: all Lua files compiled; ZIP CRC, byte-for-byte source equality and embedded file receipts verified. Asset hashes and anonymous public download integrity checked after upload.

Limits: the isolated native host reports engine 0.3.2. No physical Android/iPhone, fresh engine 0.3.18 native run, Gen-II playthrough or complete gameplay run is claimed. This change targets the integrated Gen-I Terrarium. No save-format changes.
