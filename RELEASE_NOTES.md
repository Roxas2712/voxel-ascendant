# Voxel Ascendant 0.1.6

This maintenance release adds explicit mobile-safe rendering controls and
reduces the visible wait when a cold map or battle arena is first meshed.

**BTL GRID** now controls voxel seams in 3D battles independently of the
overworld's **V-GRID** row. Battles no longer force those seams on. **SHADOWS**
controls the shadow-map pass in both scenes; switching it OFF also suppresses
the flat fallback decals, which gives iPhone users a clean shadowless path.
Both new settings default to the historical ON look and remain accessible
inside the FULL preset.

When shadows are ON, staged-battle shadows now use each combatant's stable
bearing toward its opponent. The visible sprite card may continue facing the
drifting camera, but its shadow stays rooted to the Pokemon rather than
rotating with that camera-facing billboard.

Map building remains asynchronous so loading cannot freeze a mobile frame.
On a cold map the drawable body is queued before its border ring, terrain is
made visible before decorative meshes finish, and battle arenas are queued
before the transition starts. The complete scene still fills in behind the
transition and subsequent frames.

Voxel Ascendant remains a narrow compatibility alternative for Gen1Recomp
0.1.90 and newer.

This release supersedes the incomplete 0.1.4 iOS HUD fix. Kanto Ascendant
6.5.6 can feature-detect Voxel Ascendant's historical edge-HUD compositor.
Version 0.1.4 declined that compositor on iOS, but Kanto Ascendant then restored
the compact frost panels while Gen1Recomp's grayscale battle canvas was still
bound. The SGB zone pass recolored that panel as a bright green rectangle.

On iOS, the public module now omits the legacy edge-HUD capability.
Kanto Ascendant therefore selects its renderer-native profile before it can
install either the snap or panel bridge. The original engine HUD and its frost
panels remain upright inside the centered UI canvas. The wild-battle intro also
uses the engine's exact visibility rule, so no enemy panel appears behind the
party-ball row before the status HUD exists.

The established iOS HUD isolation, gameplay behavior and desktop companion
integration are unchanged outside these new renderer controls.

Voxel Ascendant includes no Pokemon or trainer sprite pack and offers no
sprite-pack menu. Battles use the game's existing art, or art selected by a
separately installed compatible content mod. The superseded 0.1.0 package was
withdrawn because it bundled third-party character art outside this project's
intended legal and maintenance boundary.

It is an MIT v1.6.1 fork and contains no Battle Art code/assets. It also ships
without Stadium models or ROM tooling, VR/OpenXR, Horde mode, external Gen 2
art, first-/third-person free movement, disk caching, or raw filesystem APIs.

The supported core remains the voxel overworld, orbit camera modes, tilt-shift,
water/lighting options, and native Gen 1 card battles on MAP or DISCS. Kanto
Ascendant integration is optional and uses the documented versioned export
contract; Voxel Ascendant has no Kanto Ascendant dependency.
