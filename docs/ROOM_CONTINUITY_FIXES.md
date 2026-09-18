# Room continuity and live battle views

Local follow-up to the bug batch and character walk smoothing integration.

- Key `8` cycles MAP → ARENA → DISCS → MAP with both Pokémon and trainer front views enabled. The switch waits for a stable battle menu and a complete candidate frame. A battle may also start in DISCS. Back-view DISCS retains its existing renderer and does not enter this cycle.
- Native interior walls use aligned materials from the existing artwork and one feature panel per wall direction. Oak’s lab uses Bulbasaur, Charmander and Squirtle separately. Wall and doorway heights are reduced; adjacent exits share a framed opening (subsequently replaced by closed paneled doors; see ROOM_FOLLOWUP.md). MS Anne remains excluded.
- Reviewed perimeter wall artwork is replaced without changing map collision or warps. SCENERY OFF restores the native rendering. Interior stairs, furniture and internal walls are preserved.
- MAP battles retain voxel furniture and visible item objects in both the color and shadow pass. The original overworld entity list is restored on exit.
- Red’s walking identity remains latched like the other heroes. Explicit character selections and save load/create events still refresh the identity. No character or Pokémon image files were changed.

Validation: 23 targeted regression scripts, the human motion renderer suite, six native hero runs, 133 interior geometry profiles, all 23 finish textures and representative native rooms. Native battle testing covers repeated mode cycles, candidate failures, party replacement and cleanup. Native runtime coverage is macOS Gen1Recomp 0.2.57; Windows/mobile were not played in this pass.
