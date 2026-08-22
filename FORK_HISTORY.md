# Fork history

Voxel Ascendant has one publication source line:

1. **DramaticShapeVoxelMod v1.6.1** — Git commit
   `790c34efff4975c91883f7f918a875530706ee12`, licensed under MIT.
2. **Voxel Ascendant 0.1.0-rc.1** — standalone Gen1Recomp 0.1.90 hardening
   and scope reduction on branch `codex/voxel-ascendant-v0190`.
3. **Voxel Ascendant 0.1.1** — focused compatibility-maintenance release with
   the centered battle-HUD repair and an explicit no-external-art boundary.
4. **Voxel Ascendant 0.1.3** — recovery release restoring the proven 0.1.1
   runtime after withdrawing the broken 0.1.2 rendering experiment.
5. **Voxel Ascendant 0.1.4** — incomplete iOS compatibility attempt: declining
   the legacy edge-HUD seam removed its vertical flip, but still let a
   companion restore frost panels into the grayscale battle canvas.
6. **Voxel Ascendant 0.1.5** — complete iOS HUD isolation: companion feature
   detection selects the native HUD before any cross-canvas panel bridge is
   installed, and intro-panel visibility matches the engine.
7. **Voxel Ascendant 0.1.6** — mobile-safe grid/shadow controls, stable battle
   shadows, and progressive cold-map mesh loading.
8. **Voxel Ascendant 0.1.7** — independent trainer/Pokemon battle-back controls
   and the first-/third-person camera modules restored from the same licensed
   v1.6.1 source line without the removed VR/Horde feature families.
9. **Voxel Ascendant 0.1.8** — world-anchored Kanto sky, procedural rare sky
   events, weather, semantic horizon/open-sea scenery, generation-checked RAM
   preloading, atomic connected-map presentation, plain outdoor building backs
   and an optional public Kanto Ascendant menu bridge; no external art or disk
   cache was introduced.
10. **Voxel Ascendant 2.0.0** — reviewed per-location ARENA scenery, fixed
    battle footing and HUD composition, continuous four-period lighting,
    device profiles, camera/input hardening, dynamic destination loading and
    a provider-only battle-music shuffle API. The release contains no external
    soundtrack, downloader, Pokemon/trainer sprite pack or copied reference
    artwork.

The upstream mirror remains configured as the local `upstream` Git remote.
Publication is performed only after the release QA gate passes.

The Dramaless v2.0.1 tree and Battle Art releases are not ancestors or source
inputs of the product bytes. They were excluded after provenance review. No
code or assets from them are included.

Kanto in First Person `firstperson1.60.0` and later Dramatic Shape community
mirrors were inspected only as user-supplied visual references. Voxel
Ascendant's directional mountain atlas, town-edge scenery and sky-life art are
independent procedural implementations; none of those repositories' panorama
images, transformed bird frames, payload code or audio files are included.
