# Voxel Ascendant 0.1.4

This maintenance release keeps Voxel Ascendant a narrow compatibility
alternative for Gen1Recomp 0.1.90 and newer.

This hotfix keeps the recovered 0.1.3 renderer unchanged and repairs one
optional companion path on iOS. Kanto Ascendant 6.5.6 can feature-detect and
call Voxel Ascendant's legacy edge-HUD compositor. Gen1Recomp presents the
world canvas with a vertical flip on iOS, so status panels already baked into
that canvas were flipped and exchanged top-to-bottom even though the voxel
world, text box and touch controls were correct.

Voxel Ascendant now declines that legacy compositor on iOS. Kanto Ascendant's
existing fallback then draws the original battle HUD upright inside the
centered engine frame. The 3D renderer, desktop HUD behavior, settings and
gameplay state are unchanged.

On iOS, the enemy and player status panels now remain inside Gen1Recomp's
centered battle frame. They share one scale with the command and move menus,
avoiding the flipped and displaced HUD shown by the legacy edge compositor.

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
