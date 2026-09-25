# VASC 3.0.46 — QA report

Source runtime: rc.8 commit 0205ef59c1ba3ad3e50e38541068b5f28734361f. Public promotion changes only version, documentation and generated package receipts. The public archive is compared with rc.8 to enforce that constraint.

- 86/86 headless regression suites passed.
- Prepared coverage: 463 species, 1,894 variants, ten slots each; 1,069 unique models; 85,520 finite pose samples.
- Native Gen1 battle: category routing, original actions, recoil, fallback, source switching and exit passed.
- Native Gen2 battle: corresponding original-action checks passed.
- Native Dex: 90 captures across nine available species, 48 original and 42 VASC actions; Rayquaza skipped because absent from the Crystal host.
- Native generated-action battle: Unown attacks, entrance, flinch, manual faint/held endpoint, sprite suppression, Crystal alpha, enclosed whites, frame separation and cache reuse passed.
- Corrected Crystal and mid/completed-faint screenshots were inspected. The entire 90-capture set was not individually signed off visually.
- All packaged Lua is syntax-checked. ZIP CRC, file receipts, prepared-model content hashes and 30 original Terrarium source hashes are checked during packaging.

Missing original action slots use procedural VASC movement, not newly authored original Cobblemon animation. No exhaustive visual signoff for all variants, full zero-HP knockout-sequence test, or physical phone/console GPU testing is claimed. Historical runtime/menu/performance audit documents in the package describe their own scope. Existing device-specific reports outside those checks are not claimed resolved.
