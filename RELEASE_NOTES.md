# Voxel Ascendant 0.1.3

This maintenance release keeps Voxel Ascendant a narrow compatibility
alternative for Gen1Recomp 0.1.90 and newer.

This recovery release restores the exact 0.1.1 rendering implementation. The
experimental mobile DPI, shader, Android-water and transparent-HUD changes
from 0.1.2 have been removed because affected clients could no longer render
the voxel world reliably.

The enemy and player status panels now remain inside Gen1Recomp's centered
battle frame. They share one scale with the command and move menus, avoiding
the oversized, clipped HUD seen on large and HiDPI windows.

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
