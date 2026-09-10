# Voxel Ascendant 3.0.16

Gen1 gatehouses now show doors at their mapped entrances. East/west passages have doors on both sides, including both separate passages on Route 16. South entrance doors are explicitly drawn so they cannot disappear behind the facade, fixing the closed-looking Route 12 entrance. North doors follow the actual entrance position and width, with corrected tile ordering.

Coverage: 26 entrances across the Kanto gatehouses (7 west, 7 east, 7 south and 5 north), including the Safari entrance and Route 2 forest access. Existing collision and map transitions are unchanged.

Validated with native Gen1 3D views of all 26 entrances, focused mapping tests and compilation of all 529 source Lua files (463 packaged runtime files). Testing used macOS LÖVE with a mobile profile, not a physical Android device.

Includes all Stadium2, HD people and Low Kick fixes from 3.0.15. Replace the existing Voxel Ascendant mod with the ZIP and fully restart the game. No save migration is required.
