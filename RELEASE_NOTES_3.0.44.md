# VASC 3.0.44 — Public Test Release (combined rc.3 fixes)

Public test release based on 3.0.43, containing the combined rc.3 fixes. Published as a regular release for launcher compatibility. The Legacy Bank navigation fix from 3.0.43 is retained unchanged.

- Preserve 3D rendering if optional lighting resources fail. Desktop shader compilation can retry without the lighting program when both normal variants fail. Working lighting stays unchanged.
- Allow explicit battle-view selection from OFF, with diagnostics for requested, committed and retained views. Failed candidates keep the previous presentation and saved preference.
- Record menu setting names/values and repeated camera-level changes. Preserve scenery failure reasons without classifying the normal static battle camera as a rendering failure.
- Include the iOS grass draw-order correction for rectangular gaps around HD and Voxel characters.
- Keep original edge-cut battle buttons by default. Complete ORAS and Glass remain deliberate choices; position, size and touch-safe-area changes no longer switch the artwork.
- Add Battle buttons to Your Look with the real button artwork/layout preview, size/position choices and an explicit original-edge reset. Preview and reset remain drafts until Apply. No automatic replay of completed setup.

Validation: targeted Lua regressions; actual local game rendering with the Android policy, including OFF -> MAP -> ARENA -> DISCS -> TERRARIUM -> MAP and zero error-inbox entries. Earlier grass correction verified using local Metal/iOS policy. Button setup verified in portrait/landscape and native battle navigation. These are local policy tests, not confirmation on a physical Android or iPhone.

Open: Xiaomi performance, the reported ARENA freeze, and intermittent stage-switch refusal are not claimed fixed. A broad pre-existing HUD test also stops on an unrelated Bag-default expectation; targeted tests pass.

Install the complete archive as the VASC update and fully restart the app. The archive combines the previously separate grass/buttons and render-recovery work; no KASC update is needed for these changes.
