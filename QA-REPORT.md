# VASC 3.0.50 validation

2026-09-25.

## Passed
- ORAS GLASS ink regression: both shared copies; native/glass text, transformed panels, paint failure and state restoration. The regression fails against 3.0.49 as expected.
- Equipment display regression: KASC authority, unknown identity, explicit none, standalone fallback, egg privacy and immutable PC descriptors.
- Native battle-team ownership regression; setup context visibility, resume validation, persistence failure/rollback tests; 77 setup rules checks.
- Native Yellow / public engine 0.3.17 / KASC 6.7.26: three team styles, actual KASC Overgrow/Static and Leftovers values, removal/reassignment refresh, normal PC focus and carry cancellation, setup drafts/apply/reopen, landscape/portrait touch layout and original item-picker callback.
- All packaged Lua syntax, ZIP CRC, embedded file receipts and committed-source equality are checked during packaging. Asset hashes and anonymous public download integrity are checked after upload.

## Limits
Native checks use LÖVE on macOS with Android OS/touch layout simulation, not a physical phone. Crystal was not replayed in-game for this release. An optional existing Gen-II host test fails at its deposit assertion on engine 0.3.17 both before this patch (3.0.49 source) and after it; this release does not claim to resolve that separate pre-existing test failure. No Gen-II storage action code was changed.

Engine battle-speed removal was verified in upstream 0.3.17; no speed override is added.
