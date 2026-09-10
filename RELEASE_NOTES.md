# Voxel Ascendant 3.0.18

Fix repeated battle camera zoom jumps with animated Stadium 2 models on DISCS platforms. Changing idle poses could trigger a wider safety camera, then immediately restore the narrow camera. The camera now keeps the verified space needed by the actors while continuing to check the current model and HUD bounds.

The correction resets on screen rotation, manual camera control, a distance-setting change, or a new battle. Camera drift and saved zoom settings are preserved. Includes the support-report features from 3.0.17.

Validation: six camera/HUD regression tests passed. Native renderer checks with engine 0.2.57 covered Charmander versus Pidgey with Stadium 2 and Crystal sprites, and Weedle versus Weedle with Stadium 2, in portrait and landscape. Testing used macOS LÖVE with Android presentation settings; physical Android confirmation remains open.

Replace the existing Voxel Ascendant mod with the ZIP and fully restart the game. No save migration is required.
