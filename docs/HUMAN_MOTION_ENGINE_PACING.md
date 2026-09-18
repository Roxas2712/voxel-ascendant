# Engine FPS-cap correction and whole-frame diagnosis

The private engine's `PresentSync.hardwarePacesCap` trusted a positive cached
probe even when VSync was OFF. The run loop could consequently skip its numeric
software limiter. The correction requires VSync to be requested before trusting
that probe. It preserves the existing checks for positive caps, a successful
probe, fallback status and panel refresh rate.

The same defect is reproduced against the original source in 252 decision-case
tests. In a native Red comparison, the QA fixture explicitly supplies a cached
positive probe while VSync is OFF and the cap is60. The original function had a
2.243ms median draw-to-draw interval; the corrected native function had16.606ms
(p9517.425ms). All590 original samples and120 corrected samples retained the
positive cached probe. This is a controlled reproduction of that state, not a
claim about every user's probe history. There is no QA pacing adapter in this
comparison. A full Crystal profile also ran with the native correction.

The correction is installed only in the separate private QA engine. Its target
resolved to qa/vasc-human-motion-native/engine/src/core/PresentSync.lua. The
obsolete private demo PID27602, revalidated by path and start time, was stopped
before the later measurements. Other game/test processes were left alone.

## Remaining pauses

The whole-frame profiler measures event pump, update, game update, draw, present,
present wait/probe, software sleep and residual wall time. It preserves original
callbacks and restores them at completion. Each mode uses12 seconds, excluding
the first2 seconds from steady samples; no screenshots are taken. Idle and
walking are tested in Classic and Natural. Scripted Game:update count was one
per rendered frame in the reported measurements.

Before the native correction (with the previously documented equivalent QA
pacing guard), a Classic idle129.535ms frame included106.419ms inside present;
a Classic walking207.347ms frame included169.362ms inside event pump. Natural
idle also had a44.107ms frame with42.061ms inside draw. The later native-cap run
had a201.766ms Natural walking frame with199.899ms inside present, and a separate
103.463ms frame with102.754ms inside draw. These are wall-time locations, not
proof of GPU-driver causation: OS scheduling and other desktop work can be
included in a call's duration. The desktop was not otherwise isolated from
other running applications. Closing the obsolete QA demo also prevents a clean
causal before/after comparison of the broad runs.

The cached-probe FPS-limit defect is corrected; the sporadic long pauses are
still unresolved. Do not describe this as a universal stutter fix.

Evidence in review bundle: whole-frame-kris.log,
whole-frame-native-cap-kris.log; engine-frame-cap/native-control.log,
unit-tests.log, installer-tests.log and changes.patch.

## Applying and rolling back the engine correction

`engine-frame-cap/` is a separate package for an unpacked engine root containing
src/core/PresentSync.lua. The main VASC installer targets the mod root. The
engine installer accepts only the exact original source hash from the private
0.2.57 fixture and keeps its own backup receipt. A different source version or
later edits are refused. A temporary-fixture test verifies read-only check,
apply, exact rollback and duplicate/version/later-edit refusal.

From the review directory:

```sh
python3 engine-frame-cap/manage_patch.py check /path/to/unpacked/engine
python3 engine-frame-cap/manage_patch.py apply /path/to/unpacked/engine
python3 engine-frame-cap/manage_patch.py rollback /path/to/unpacked/engine --backup /backup/path/printed/by/apply
```

This is a reviewable fix for an exact engine file, not a universal updater for
packed application archives or other engine versions. Full character-animation
scope, remaining source profiles and expressions are still incomplete.

## Erneute vollständige Frame-Prüfung — 99 Armquellen / 29 Blinkquellen

Vier private native Läufe in Red/Crystal, Classic/Natürlich im Stehen/Laufen, zusätzlich umgekehrte Testreihenfolge. Die erweiterten Treiber prüfen die aktive Kartenquelle und den Bewegungszustand nach dem Zeichnen. Classic hat keinen Natural-Zustand, Natural in allen geprüften Bildern; tatsächliche Gehbewegung belegt. Alle Prozesse Exit 0. In den umgekehrten Läufen hatten 30 Red- und 31 Kris-Blinzelbilder maximal 17,45/17,48 ms. Kein Frame über 25 ms in deren ausgewerteten Fenstern; dies ist keine allgemeine Ruckelfreiheitsfreigabe. Die Normalreihenfolge zeigte weiterhin Idle-Ausreißer bis 64,43 ms bei Red und 44,94 ms bei Kris, überwiegend in Present. Desktoplast nicht isoliert; keine Ursachenbehauptung aus Call-Walltimes. Kein Produktionscode geändert. Raw-CSV, Rollenprüfungen, Analyseskript und Quellhashes: whole-frame-99-review/ im Prüfpaket. Sitz-/Kopfdrehungsabnahme und voller Charakterumfang bleiben offen.
