# Voxel Ascendant: deutsche Dokumentation zum RC11-Arbeitsstand

Stand: 29. August 2026

> **Status:** Diese Dokumentation beschreibt den ungefrorenen
> RC11-Entwicklungsstand. Der Arbeitsbaum ist **weder RC11-Kandidat noch
> Release**. [`manifest.json`](../../manifest.json) und Dispatcher tragen nun
> die Entwicklungsidentität `3.0.0-rc.11`; ein grünes Headless-Gate ist dennoch
> keine Spiel-, GPU-, Paket- oder Freigabeabnahme.

Voxel Ascendant (VASC) ergänzt die unterstützten Gen1Recomp-Spiele um eine
Voxelwelt und optionale Darstellungsvarianten. Spielregeln, Eingabe,
Kampflogik und Save-Semantik bleiben bei der Engine beziehungsweise bei dem
Mod, der sie fachlich besitzt. Fehlt eine benötigte Laufzeit- oder
Darstellungsseam, soll VASC zur vollständigen nativen Darstellung
zurückkehren.

## Einstieg

| Dokument | Zweck |
| --- | --- |
| [Installation](INSTALLATION_DE.md) | Voraussetzungen, sichere Installation eines vorhandenen Pakets, erster Start und Rollback. |
| [Vollständiger Leitfaden](COMPLETE_GUIDE_DE.md) | Menü, Welt, Kampf, UI, Inhalte und Unterschiede zwischen Gen 1 und Gen 2. |
| [Fehlerbehebung](TROUBLESHOOTING_DE.md) | Sichere Rückfallwerte, Diagnose und Angaben für einen reproduzierbaren Fehlerbericht. |
| [Englische Projektübersicht](../../README.md) | Ausführliche bestehende Options- und Funktionsreferenz des derzeitigen Pakets. |

Für Maintainer gibt es zusätzlich:

- [RC11-Release-Audit](../maintainer/RC11_RELEASE_AUDIT.md),
- [Card-Katalog](../maintainer/CARD_CATALOG.md),
- [Save-Schema](../maintainer/SAVE_SCHEMA.md),
- [Vertragsübersicht](../maintainer/CONTRACTS.md),
- [Hotfix-Forward-Port](../maintainer/HOTFIX_FORWARD_PORT.md) und
- [Screenshot-Beleg-Inventar](../maintainer/SCREENSHOT_EVIDENCE_INVENTORY.md).

Die bereits vorhandenen RC11-Quellen bleiben autoritativ und werden hier
nicht kopiert:

- [Zielarchitektur](../maintainer/RC11_ARCHITECTURE.md)
- [Hook- und Besitzregister](../maintainer/RC11_HOOK_OWNERSHIP.md)
- [Testmatrix](../maintainer/RC11_TEST_MATRIX.md)
- [offener Fehler- und Abnahmearbeitsvorrat](../maintainer/RC11_ERROR_BACKLOG.md)
- [Machbarkeitsbericht](../maintainer/RC11_FEASIBILITY.md)
- [eingefrorene RC10-Vergleichsbasis](../maintainer/RC10_BASELINE.md)

## Was im Arbeitsstand belegt ist

Das gemeinsame RC11-Architektur-Gate ist mit **31/31 PASS** dokumentiert. Es
prüft Card-Verträge, exakten Kampfbesitz, Router, Lifecycle, Cleanup,
geschlossene öffentliche Diagnosegrenzen und drei verbindliche
ARENA-Background-Schritte. Das fokussierte segmentierte Paketgate und die
Runtime-Receipt-Prüfung sind ebenfalls grün. Der genaue Umfang steht in der
[Testmatrix](../maintainer/RC11_TEST_MATRIX.md).

Diese Ergebnisse belegen ausschließlich die ausgeführten Headless-Pfade. Sie
belegen insbesondere keine GPU-Pixel, keine ROM-Matrix und keine
Spielerabnahme. Die offenen P0- und P1-Punkte bleiben im
[Fehlerarbeitsvorrat](../maintainer/RC11_ERROR_BACKLOG.md) offen.

## Sichere Grundregel

Bei Darstellungsproblemen zuerst nur die betroffene Oberfläche auf
`GAME DEFAULT`, `STANDARD`, `OFF` beziehungsweise `VASC DEFAULT` stellen und
den Prozess vollständig neu starten. Savegames, fremde Mod-Buckets und
`active.json` nicht von Hand löschen. Die genaue Reihenfolge steht in der
[Fehlerbehebung](TROUBLESHOOTING_DE.md).

## Begriffe

- **Arbeitsstand:** Quellbaum während der Segmentierung; nicht als
  installierbare Freigabe bezeichnet.
- **Headless:** Test ohne sichtbares Grafikfenster; kann Besitz und Verträge,
  aber keine endgültigen Pixel belegen.
- **GAME DEFAULT / DEFAULT:** vollständige native Darstellung der jeweiligen
  Edition. Das ist ein vorgesehener Sicherheitsweg, kein heimlich bestandener
  VASC-Grafiktest.
- **Transitional:** noch nicht als eigene isolierte Card extrahierter
  Übergangspfad. MAP und ARENA sind in Gen 1 transitional; MAP, ARENA und
  DISCS sind es derzeit in Gen 2.
- **Kandidat:** erst nach dem vollständigen Gate I zulässig. Der aktuelle
  Arbeitsstand erfüllt diese Bezeichnung ausdrücklich nicht.
