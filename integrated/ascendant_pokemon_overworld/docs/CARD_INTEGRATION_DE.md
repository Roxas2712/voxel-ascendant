# Spätere VASC-Card-Einbindung

Die veröffentlichte Card-ID lautet
`ascendant.pokemon-overworld.visual-provider`, Schema `ascendant.card/v1`.
Sie stellt zwei versionierte Fähigkeiten bereit:

- `ascendant.overworld-pokemon/v1`
- `ascendant.overworld-characters/v1`

Der Descriptor ist über `mod.exports.ascendantCard.descriptor()` verfügbar.
Er deklariert Save-Namespace, Hooks, Dateien, Tests und Lifecycle-Funktionen.

VASC 3.0 meldet derzeit `externalRegistration=false`. Deshalb versucht diese
Version keine private oder simulierte Registrierung. Sobald VASC einen
autorisierten externen Lease-/Registrierungspunkt veröffentlicht, wird nur ein
dünner Host-Adapter ergänzt:

1. Descriptor an den öffentlichen Host übergeben.
2. Aktivierungs-Receipt und Health-Status übernehmen.
3. Bei Deaktivierung Runtime-Hooks zurückrollen.
4. Bei Kartenkonflikten VASCs Resolverentscheidung befolgen.

Bis dahin läuft exakt dieselbe Funktionalität als normale Standalone-Mod.

