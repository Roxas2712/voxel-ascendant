# Voxel Ascendant 3.0.27 – Mobile layout & support hotfix

- Mobile SELECT now defaults to the upper left and START to the upper right, leaving more space for the battle menu below. The dots menu moves below START. Custom touch positions and skins are preserved.
- The battle HUD no longer reserves bottom space for START/SELECT when they are above it. Full lifted buttons, Glass styling and the existing transparency settings remain available.
- Support log sending works around the missing dedicated POST bridge in iOS engine 0.2.61 by using its existing background HTTP request transport. Only a successful HTTP status confirms a sent report; there are no automatic retries.
- SEND SUPPORT LOG now sends with one selection after entering the support code, without an extra help popup or confirmation click. Reports remain manual, bounded and redacted; no save file is attached.

Validation: native touch comparison through battle menu, move selection and rotation; the tested move-selection scene now stays in 3D. Native background upload was received and verified on the support server; iOS bridge/status handling and both generations' control regressions pass. Physical iPhone verification is still pending. This does not claim to fix every camera fallback or the separately reported HD-sprite problem.

Update VASC in the launcher and restart the game. No engine reinstall is needed for this mod-side log workaround on 0.2.61.
