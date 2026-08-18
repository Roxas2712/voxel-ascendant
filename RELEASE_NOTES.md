# Voxel Ascendant 0.1.5

This maintenance release keeps Voxel Ascendant a narrow compatibility
alternative for Gen1Recomp 0.1.90 and newer.

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

The 3D renderer, gameplay state, settings and desktop companion behavior are
unchanged.

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
