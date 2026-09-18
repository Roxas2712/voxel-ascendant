# Voxel-Ascendant 3.0.28-rc.2 — local candidate

- Downloaded sprite maintenance shared by KASC and VASC: check/repair, reinstall, or delete downloaded packs. Interrupted operations retain a checksummed restart journal. Only download cache roots are cleared; saves, bundled art and Stadium imports remain.
- Corrupt/truncated sprite payloads, materialized copies and activation records are detected; repair downloads only affected packages. Fully clearing the download cache runs after save and restart, before mounting sprites.
- Large backgrounds: 156 original-resolution JPEG95 images with lossless alpha where needed. 29 smaller scenery textures remain PNG. The original graphics backup is preserved separately. GPU alpha composition has a CPU fallback; sprites and interface artwork are not converted to JPEG.
- Grouped touch/controller quick menu for Wilds, follower controls/modes, town Pokémon and their sprite sources. Reads and changes the actual owning settings. Battle menu excludes overworld controls; 3D-only controls are hidden when there is no 3D shot.
- Retains the one-time Natural human-animation migration from rc.1; later player choices are respected.

Local candidate only, not published. Native macOS render/input tests and phone-size touch simulations passed; no physical iPhone or Android device was tested.
