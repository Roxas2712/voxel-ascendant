# Installation und sicherer erster Start

Stand: 29. August 2026

> **Kein RC11-Installationsartefakt:** Der vorliegende Quellbaum ist weder ein
> RC11-Kandidat noch ein Release. Manifest und Dispatcher tragen zwar die
> Entwicklungsidentität `3.0.0-rc.11`; diese Anleitung dokumentiert jedoch nur
> die sichere Paketform und macht aus dem Arbeitsbaum kein freigegebenes Archiv.

## Voraussetzungen

- Ein unterstütztes Spiel: Rot, Blau, Gelb, Gold, Silber oder Kristall.
- Gen1Recomp ab `0.1.90`; das aktuelle Manifest begrenzt die Engine auf
  `>=0.1.90 <2.0.0`.
- Für die Voxelpfade ein Grafiktreiber mit Shader- und Depth-Canvas-Support.
  Fehlen diese Fähigkeiten, muss die Edition vollständig nativ zeichnen.
- Ein frisches Testprofil für Abnahmen. Der RC11-Arbeitsbaum darf nicht über
  ein einziges produktives Nutzerprofil entwickelt oder freigegeben werden.

Die genaue Paketidentität ist ausschließlich im
[`manifest.json`](../../manifest.json) autoritativ. Dateinamen oder
Verzeichnisnamen dürfen keine höhere Version vortäuschen.

## Vor der Installation

1. Spielstand, Engine-Optionen und vorhandene Mod-Konfiguration sichern.
2. Bestehende VASC-, KASC- und Engine-Versionen notieren.
3. Alte eigenständige VASC-Erweiterungen nicht parallel aktiv lassen. Das
   Manifest ersetzt unter anderem `VASC4J`, die alten Kanto-Karten-,
   Field-Cinematic-, Storage-UI- und Modern-Dex-Pakete.
4. Kanto Ascendant ist optional. Wenn es verwendet wird, nur eine nachweislich
   kompatible, gepinnte Kombination benutzen und KASC vor VASC installieren.
   VASC darf KASC-Spielregeln oder KASC-Saves nicht übernehmen.
5. Keine ROM, keine aus einer ROM erzeugten Modelle und keine privaten Medien
   in ein VASC-Paket kopieren.

Die eingefrorenen Vergleichspins und ihre Einschränkungen stehen in der
[RC10-Baseline](../maintainer/RC10_BASELINE.md). Sie sind Referenzen, keine
Freigabeaussage.

## Paket installieren

Für ein ausdrücklich bereitgestelltes, geprüftes Paket gilt:

1. Bei einer bereits installierten Kopie die Launcher-Funktion **Check for
   updates** verwenden. Ein manueller Import überschreibt absichtlich kein
   Paket mit derselben Mod-ID.
2. Bei der Erstinstallation die VASC-ZIP im Mod-Manager auswählen.
3. `manifest.json` muss direkt im ZIP-Wurzelverzeichnis liegen.
4. Das Archiv nicht entpacken, umbenennen, neu packen oder mit Dateien aus
   einem anderen Build vermischen.
5. Im Launcher nur `VOXEL_ASCENDANT` als VASC-Laufzeit aktiv lassen. Wird das
   ausgemusterte `VASC4J` erkannt, ist VASC der vorgesehene Ersatz.

Der aktuelle RC11-Quellbaum darf erst dann als Paket ausgegeben werden, wenn
die Schritte des vollständigen [Gate I](../maintainer/RC11_TEST_MATRIX.md)
bestanden und eine konsistente Paket-, Hash- und Plattformidentität erstellt
wurden. Die Entwicklungsversion ist gesetzt; diese Abnahmen fehlen weiterhin.

## Content Selector und lokale Inhalte

Der Content Selector schreibt begrenzte, hashgebundene Presets unter
`user/content-selector/preset-runtime/v1/`. VASC prüft `active.json`, Manifest,
Dateigrößen und SHA-256 erneut und verwendet eine unvollständige CUSTOM-
Generation nicht teilweise.

Der aktuelle Plattformvertrag steht auf `PENDING_EXTERNAL_BUILD`: echte
geprüfte Windows- und Linux-Artefakte samt Self-Test-Receipts fehlen. Portable
Python-Dateien dürfen diese nativen Spielerartefakte nicht unter falschem Namen
ersetzen. Einzelheiten stehen in [Content-Presets](../CONTENT_PRESETS.md).

Eigene Medien bleiben in den dokumentierten `user/music/`- und
`user/sprites/`-Bäumen. Sie sind kein Teil des VASC-Releases. Nur Dateien
verwenden, an denen die nutzende Person die nötigen Rechte besitzt.

## Erster Start

1. Spiel und Edition vollständig neu starten; kein Hot-Reload für eine
   Abnahme verwenden.
2. Prüfen, dass genau ein VASC-Menüpunkt sichtbar ist.
3. Zuerst mit nativen Sicherheitswerten starten:
   - Welt/Kampf: `OFF` oder `GAME DEFAULT`,
   - HUD und Menüs: `GAME DEFAULT` beziehungsweise `STANDARD`,
   - Inhalte: `VASC DEFAULT`.
4. Danach genau eine Darstellungsfunktion einschalten und die Edition normal
   bedienen.
5. Bei Gen 2 Gold, Silber und Kristall getrennt behandeln. Der gleiche Code
   ersetzt keine editionsbezogene ROM-Abnahme; die offene Matrix steht in
   [Gen-2-ROM-QA](../GEN2_ROM_QA.md).

Ein automatischer Rückfall auf native 2D-Darstellung ist bei fehlender oder
fehlerhafter Voxel-Seam das vorgesehene Verhalten. Er darf nicht durch das
Mischen von Dateien oder das Löschen von Save-Daten „repariert“ werden.

## Aktualisierung und Rollback

- Vor einer Aktualisierung den laufenden Prozess beenden.
- Nie ein vorhandenes Archiv unter gleichem Namen mit neuen Bytes ersetzen.
- Für einen Rollback VASC im Launcher deaktivieren oder das zuvor gesicherte,
  eindeutig identifizierte Paket wieder aktivieren.
- Der alte Gen-2-Optionsbucket `VASC4J` wird als Migrationsquelle beibehalten
  und darf nicht automatisch gelöscht oder überschrieben werden.
- `RESTORE VASC DEFAULT` entfernt nur die aktive Custom-Auswahl; benannte
  Presets bleiben erhalten.
- Wenn eine zweite Runtime-Instanz mit `restart required` abgewiesen wurde,
  ist ein kompletter Prozessneustart der einzige vorgesehene Wiederanlauf.

Für Symptome und die benötigten Diagnoseangaben siehe
[Fehlerbehebung](TROUBLESHOOTING_DE.md). Für die Speichergrenzen siehe
[Save-Schema](../maintainer/SAVE_SCHEMA.md).
