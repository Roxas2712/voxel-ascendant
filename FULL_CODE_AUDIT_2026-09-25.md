# Repository-wide VASC audit — 3.0.46-rc.4

Local candidate built on rc.3 (`2addab81814ce4a8fac20312d05ac5a3064c2711`), retaining the public v3.0.45 release base, the 15 supplied location designs and all earlier fixes. No public release or production support upload was performed.

## Scope and method

The scope is the entire VASC repository: entry points, shared library, Gen2 library, Cards and adapters, downloads, settings, menus, overworld, battle ownership, integrated components and authoring tools. It is not limited to Terrarium.

All 896 Lua files are inventoried and compiled with the host's LuaJIT; all four Python files are parsed. Of the Lua files, 805 are outside `tests/`. Literal `V.require` references were checked against the shared, Gen2 and Gen2 shared-library roots: the sole missing-name candidate was a commented-out `ForestAtmos` reference, not a live dependency. Dynamic requires and host-owned dependencies need runtime coverage.

Manual review focuses on state ownership, restoration, fallback, persistence and recurring work at subsystem boundaries. This is not a claim that every source line or every combination of third-party mods was exercised. The coverage table distinguishes behavioral validation from source inspection.

## Reproduced and corrected

1. **Effective setting labels, Gen1 and Gen2.** A saved rung rejected by its availability gate made `get()` return the declared default while the menu always displayed the first label. Non-first defaults now use their actual label; the stored selection still recovers when its dependency returns. Regression: `mod_setting_fallback_test.lua`.
2. **Download-receipt write failures.** `HdReceiptJournal` changed its live entries before checked persistence. A failed removal could then report success on retry without persisting the deletion. Insert, replace and remove restore the previous in-memory entry on failure. Tests cover retry, reopen and ticket ownership; these are download accounting receipts, not Pokémon save data. Regression: `content_persistence_recovery_test.lua`.
3. **Optional diagnostics recovery.** Persisted scalar rows, malformed counters or retry counts were accepted; a false head blocked the queue and malformed active counters could interrupt construction. Reports are reconstructed from bounded, approved fields; history/outbox/event limits apply on load too. Encoder errors remain local, and oversized bodies no longer trigger encoding every frame. Valid queued reports still require a matching acknowledgement. Regression: `download_diagnostics_recovery_test.lua`, using an in-memory cache and fake transport only.
4. **Saved environmental clocks.** Day/night and sky restoration accepted infinities/NaN, propagating invalid values into subsequent calculations. Both generations now use their existing default for non-finite values; finite positive and negative times retain wrapping. Weather already had a finite-value guard and was left unchanged. Regression: `save_clock_recovery_test.lua`.

## Performance changes

- **Content fulfillment:** `SpriteCodeContent.update` used to resolve and plan the queued content every frame before checking scene safety/busy state. Planning can read and hash cached chunks. The waiting gate now precedes this work; completion of an already-started transfer still runs, and the plan is freshly resolved when processing resumes. In the deterministic test, enqueue plus 600 unsafe updates went from 601 planner calls to one. Another 600 busy updates add zero calls. Download starts and completion callbacks remain single-shot. `code_content_scheduling_test.lua`.
- **Internal event bus:** sorted per-event listener snapshots survive until subscription changes. Invalidation replaces snapshots instead of mutating a dispatch in progress. Priority, subscription order, recursive emits, unsubscribe during dispatch, stale ownership, per-listener payload copies and failure isolation remain intact. Unsubscribed event names are not cached. `core_hooks_dispatch_test.lua` and `core_card_lifecycle_test.lua`.

A local LuaJIT microbenchmark with 1,000 listeners on 40 topics and 10,000 emits delivered the same 250,000 callbacks: 109.624 ms before, 25.923 ms after (about 76% less CPU time in that run). Transient allocation fell from 63,362.94 to 60,157.29 KiB with GC stopped during measurement. This is a synthetic dispatcher measurement, not measured game FPS or an end-to-end loading improvement.

## Subsystem coverage

| Area | Review / validation in this round |
| --- | --- |
| Boot, modules, Cards | Entry-point save/ready hooks and Card host/registry lifecycle reviewed; dependency ownership, stale context, failed activation and rollback retry tested; real Gen1/Crystal boot. |
| Event dispatch | Ordering, nested dispatch, callback mutation, owner removal, payload isolation and broken error reporting tested; benchmark above. |
| Settings and save restoration | Both ModSetting implementations; Gen2 migration/persistence scope, canonical precedence, stored false values, write-error reporting and idempotent installation; day/night/sky invalid-clock recovery. |
| Setup, options and input | Existing access/setup/control/error/support suites; actual Gen1 preview in five configurations and two orientations, draft isolation, resume/reset/apply/reopen. |
| Bag and party | Restored manual pocket-sort, default width, mobile ownership and party battle-owner suites. Sorting retains native use/cancel/pocket handling. |
| PC boxes | Restored Gen2 host, action parity, native STATUS dispatch and search suites. |
| Battle ownership / fallback | Gen2 provider-router, choice ownership, native retry and current live-selection tests; the current explicit OFF-to-MAP behavior is preserved. |
| Battle animations | Real host AnimPlayer and generated Red data: 216 move/side cases against each of the two VASC animation implementations, 432 total; 2,656 completion/timing checks. |
| Downloads and imports | Catalog, code fulfillment, journal, installer/store, bounded transport and maintenance transitions reviewed. Restored binary-fetch, bounded-client, failover, transport, receipt replay, collection and restart suites. No production network submission. |
| Diagnostic/support UI | Corrupt diagnostic queues and encoder failure tests, plus existing support transition, inbox, detail, ownership and support-menu suites. |
| Overworld / followers | Movement, bootstrap sprite selection, KASC player rebind/lifecycle priority tests; reviewed follower spacing/collision/runtime boundaries. Existing streaming, terrain, hidden-actor and camera suites retained. |
| Wardrobe / appearance | Wardrobe Card activation/deactivation and provider health tested; reviewed saved-selection and derived-cache paths. This does not exercise every garment/character/action combination. |
| Local sprites / music / content | Source registration/unregistration, selected-state restoration and fallback/pass-through paths inspected; source-menu refresh regression tested. No exhaustive custom-user-file/audio matrix. |
| Fly map | Selection, zoom/input ordering and flight callback path inspected; no full flight/destination traversal in this round. |
| Rendering / Terrarium | Existing shadow/model/failure/camera/location tests rerun; Crystal MAP, ARENA, DISCS and TERRARIUM actual battles with run/return, injected optional-light failure and recovery. No new Terrarium production change. |
| Authoring / packaging | Python syntax, complete Lua compilation, complete ZIP CRC/content hashes and all 30 authored Terrarium source SHA-256 receipts. |

## Test evidence and reproducibility

- **72/72 headless suites pass**, each in a fresh LuaJIT state/process against this candidate. Eight new boundary suites and 27 restored historical suites broaden the shipped coverage beyond rendering.
- Restored fixtures were updated for current dependencies: engine location comes from `ENGINE_DIR`, content menus model the optional Cobblemon service, native retry supplies diagnostics and preserves the already-supported explicit OFF transition, and collection selection expects the current exact family screen. An obsolete historical VASC-menu section-count test was not adopted; current menu tests and native UI checks are listed above.
- **Native Gen1 setup**: 10 configuration/orientation screenshots; preview never changes live settings; resume/reset/apply/reopen pass. Selected screenshots inspected visually.
- **Native animation**: 432 move/side cases, 2,656 checks; test retained in `tests/native/battle_animation_completion.lua`. Requires the engine on `package.path`, `VASC_ROOT` and `GEN1_ANIM_DATA`.
- **Native Crystal**: all four battle presentations render and exit correctly, with optional-light failure/recovery. Isolated `vasc-full-audit-...-qa` save identities used.
- Headless fixtures receive `arg[1]` pointing to the candidate and `ENGINE_DIR` pointing to the test host. The three graphics-only suites (`indoor_mist_composite`, `local_light_grid`, `mobile_mist_gpu`) remain native tests and were not counted in the 72 headless suites. Their prior rc.2/rc.3 GPU results are historical; no GPU test claim is added for this round.
- The delivery includes logs, source inventory, test results, benchmark and native drivers under `QA/` plus `verification.json` and the ZIP checksum.

## Limits

Desktop LÖVE 11.5 / LuaJIT validation does not replace physical Android/iOS GPU and touch testing. Live download servers, CDN/network failure behavior in production, all historical user saves, every map interaction and every mod combination were not exhaustively exercised. Non-finite clock values were deliberately injected to test recovery. Existing native/API compatibility fallbacks remain intentional where required; the review does not indiscriminately remove them.
