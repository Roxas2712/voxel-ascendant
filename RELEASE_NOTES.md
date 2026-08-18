# Voxel Ascendant 0.1.2

This maintenance release keeps Voxel Ascendant a narrow compatibility
alternative for Gen1Recomp 0.1.90 and newer.

Mobile rendering now uses the engine's separate horizontal and vertical DPI
metrics, while the battle HUD, scene-depth and reflection targets stay at one
canvas pixel per framebuffer pixel. This avoids mixed-size render attachments
on Retina iPhone and iPad displays and improves alignment on rotated Android
surfaces.

The new `HUD BACKING` setting defaults to `TRANSPARENT` for the enemy and
player status blocks. Text and command boxes keep their readable panel;
`FROST` restores the previous translucent status backing.

The mobile GLES shaders now guard zero-length camera rays and invalid shadow
depth values. Android uses flat animated water instead of the problematic
reflection pass. Screen orientation, safe areas and touch controls remain
owned by Gen1Recomp and are not rotated a second time by this mod.

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
