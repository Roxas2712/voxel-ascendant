# Voxel Ascendant 0.1.7

This release separates the player-side battle presentation and restores the
two player-attached camera modes from Voxel Ascendant's MIT-licensed v1.6.1
source line.

**TRAINER BACK** and **PKMN BACK** are now independent persistent settings.
`TRAINER BACK = OFF` places the trainer's standing front art in the staged 3D
intro, while ON keeps the rear-view throw sprite in its classic screen slot.
`PKMN BACK` separately decides whether the player's Pokemon stands in the
scene using front art or stays behind the battle menu using its back sprite.
Existing saves keep their old Pokemon choice because that setting retains the
historical `battleBack` storage key.

Trainer front selection now uses Gen1Recomp's live `player.sprite` seam. This
allows the vanilla trainer and compatible character mods such as Kanto
Ascendant to supply their own standing art. The resulting player-side card is
marked and mirrored as front art instead of being treated as a static trainer
back, fixing the reported inability to switch the trainer back to front.

The VOXEL ladder now includes **1ST** and **3RD**. Both support mouse,
right-stick and open-screen touch look plus camera-relative movement through
the engine's existing collision and cell-arrival paths. Third person adds a
collision-aware shoulder boom with wheel, Q/E, stick-click and pinch zoom.
The `3` key and SELECT cycle through and back out of both modes.

The restored files come from the same documented DramaticShapeVoxelMod v1.6.1
MIT source commit already used by Voxel Ascendant. VR, Horde, Stadium, ROM
tooling, external sprite art, disk caches and raw filesystem access remain
excluded.

The 0.1.6 mobile controls remain intact: battle grid and shadows are separately
switchable, battle shadows stay oriented to their combatants, and cold map
meshes continue loading progressively.
