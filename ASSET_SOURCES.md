# VASC – Quellen der neu erzeugten Panorama- und Materialassets

Stand: 21. August 2026. Dieses Dokument führt die während des aktuellen Panorama-/Höhlenpasses neu erzeugten Runtime-PNGs auf. Die großen ImageGen-Master werden nicht vom Mod geladen; ausgeliefert werden ausschließlich die geprüften Compact-Dateien unter `assets/`.

Die Panorama-/Materialmaster wurden mit dem eingebauten ImageGen-Werkzeug für dieses Projekt erzeugt. Die ausdrücklich als kanonisches Spielderivat ausgewiesene Forest-Gate-Datei wird dagegen ausschließlich aus dem hash-fixierten Gen1Recomp-OVERWORLD-Atlas rekonstruiert und enthält keine neu erzeugte Gestaltung. Quellnachweis und technische Gültigkeit bedeuten noch keine visuelle Freigabe: Der verbindliche Bild- und Performance-Status steht im Panorama-Audit.

## Quellenübersicht

| Runtime-Datei | SHA-256 | ImageGen-Master |
|---|---|---|
| `assets/scenery/kanto_panorama.compact.png` | `eb4668bed79673108b73a00761e5edb54d8583369bb3e60797fdc7454c30cf9f` | `tools/sources/kanto_panorama/kanto-panorama.imagegen.png` |
| `assets/sky/mountain_panorama.compact.png` | `47309c1366e49013a1146c6fffca27db7b9ea23b155a1e05c5664b3c42bd5aee` | `exec-f7553aef-76db-4619-9a62-0142b21e316d.png` |
| `assets/scenery/rural_edge.compact.png` | `35ae2571c1e0d33475ad666454e47cd9bd5b4153d673bc7e04d547734eb246c4` | `exec-33b2f4c3-be00-44d9-a56b-e2d3d37da25b.png` |
| `assets/scenery/harbor_edge.compact.png` | `31ea5d0d9fd948b9ddf185e426548bdd4b3b713b05a9ec691c2bffabbf735edb` | `exec-60d8e200-a3d6-4da1-9966-af25fc87059d.png` |
| `assets/scenery/coastal_landmarks_v3.compact.png` | `744a844ff400ea65599f44daed03f684f02e2e57bf2492845ac2f870052ee48c` | vier unten einzeln fixierte Built-in-ImageGen-Master |
| `assets/scenery/cinnabar_story_landmarks.compact.png` | `ddbfeac791b1b35fa5571277f9a85da9d310e8082427cff1b751c53fb5fa84ba` | zwei unten einzeln fixierte Built-in-ImageGen-Master |
| `assets/scenery/route8_horizon.compact.png` | `d6934895c00b78ae6375cfb05df10d213a0c766dee609bc5d74addd8dd021e0a` | `exec-63cee975-de2b-44f2-9b13-9a24aff1e671.png` |
| `assets/scenery/route8_midground.compact.png` | `a35b4113ae878d3b4f9b69705e73de323cf58922ed9ce2f04cba2bd8ceb2455c` | `exec-4d7836a4-d45a-4e52-a80e-c5b56b97ff1a.png` |
| `assets/scenery/viridian_forest_gate.compact.png` | `95a28a896892d538b2ff1f3bd0da93c81d7a8e441d5053a27e53ab2a8cad2977` | kanonisches Gen1Recomp-OVERWORLD-Spielasset, kein ImageGen |
| `assets/scenery/mt_moon_wall.compact.png` | `d5eb75248efa3358da522090886e2cc83adbce91de58b160bc82b57dcbe7d497` | `exec-ef9be062-30ef-4818-a90d-caf50cf2208c.png` |
| `assets/scenery/mt_moon_ceiling.compact.png` | `cdb5827e9e2edd21df36d331faabb73ea2b862549ab81a867bcb5fce33c78060` | `exec-3f534911-737b-4a3e-af6c-0596ccccdeaa.png` |
| `assets/scenery/pokemon_tower_wall.compact.png` | `15d4127df049a4000ee388c26b2476c2819ee847b9e400ec54685527c2a4714a` | `exec-0048ef76-a3c5-486b-a514-6116f40b6e09.png` + `exec-911d5b62-9f50-423a-9204-bb321b2c5b5b.png` |
| `assets/scenery/pokemon_tower_ceiling.compact.png` | `aa644a270b3e29a4b729c59b6b0a96a110076942f44e2d80d8b671c3190e5530` | `exec-7052e32d-0ce0-4310-9ef5-c04acb34956a.png` |
| `assets/scenery/pokecenter_room_wall.compact.png` | `2cb759ed9cc1afed883a2b3435438ede2e41e97f2f72d465226d22f012bd061a` | `exec-030f9bc5-a82c-4771-9fe5-c910e056c074.png` |
| `assets/scenery/pokecenter_room_ceiling.compact.png` | `a59a180adb7c5b819631077cd4c9e5ccbd70a8536c7ac7d70f4a246769c257ac` | `exec-fbcccbb3-ed85-43b4-9e9f-ae92c771405b.png` |

## Fernes Kanto-Panorama

- Erzeuger: eingebautes ImageGen-Werkzeug (Built-in ImageGen).
- Workspace-Master: `tools/sources/kanto_panorama/kanto-panorama.imagegen.png`, 2172×724 RGBA, SHA-256 `e0630428d652b1ad5921e6d03e0dad79ba6bb1d627c06d1141a5cf236658c7b1`.
- Prompt-Ziel: eigenständig gestalteter, scharfer 16-Bit-Kanto-Fernhorizont mit niedrigen Wäldern, kleiner Ortschaft, zurückhaltender alter Stadt, Gedenkturm, Fuji, Küste und Leuchtturm; transparente Himmelsfläche, keine Figuren, Pokémon, Logos, Schrift oder Übernahme fremder Bildpixel.
- Reproduzierbarer Build: `tools/build_kanto_panorama.py` pinnt Quellhash, RGBA-Modus und Maße, beschneidet den akzeptierten Landschaftszug, skaliert ausschließlich per Nearest-Neighbor, härtet Alpha auf 0/255, reduziert ohne Dithering auf höchstens 32 sichtbare RGB-Farben und spiegelt die 512px-Hälfte zu einem exakt anschließbaren 1024px-Rundbild.
- Runtime: `assets/scenery/kanto_panorama.compact.png`, 1024×192 RGBA, SHA-256 `eb4668bed79673108b73a00761e5edb54d8583369bb3e60797fdc7454c30cf9f`. Linke/rechte Spalte sind in jeder Zeile bytegleich; die Unterkante ist vollständig opak. Das Asset bildet ausschließlich die ferne Außenkulisse. Reale Karten, Nachbarn, Küstenwasser, Lücken, Vordergrund, die bewährte map-aware Randkulisse und Landmarken bleiben davor autoritativ.
- Budget: ein geteilter 64-Segment-Meshdraw in Outdoor-Welt und MAP-Kämpfen, 786.432 Byte RGBA8-Textur plus 256 Vertices/384 Indices. Gegenüber dem visuell akzeptierten 2048×384-Prototyp spart die Runtime exakt 2.359.296 Byte retained VRAM (75 Prozent) und drei Viertel der PNG-Dekodierfläche. DISCS und Innenräume verwenden das Panorama nicht. Eine fehlende oder falsch dimensionierte Datei fällt ohne Teilzustand auf die bisherige HorizonWall-Außenwand zurück.

## Bergpanorama

- Master: ImageGen-Source-ID `exec-f7553aef-76db-4619-9a62-0142b21e316d.png`
- Master-SHA-256: `3c1b4ae7b6ee32d06fdc1dc8231465601022e3cb1a4406a12795dedd63052999`
- Runtime: `assets/sky/mountain_panorama.compact.png`, 2048×128 RGBA
- Contract: N = 1024 Texel W→E, E = 341 Texel N→S, S = 342 Texel E→W, W = 341 Texel S→N. Fuji erscheint ausschließlich im Nordsektor. Die vier physischen Sektorübergänge einschließlich Wrap besitzen identische Anschluss-Spalten.
- Prompt-Ziel: scharfes, erkennbares Fuji-/Kanto-Bergpanorama mit mehreren geerdeten, bewaldeten Tiefenlagen und transparenter Himmelsfläche; keine Gebäude, Schrift, Figuren oder fotorealistische Textur.
- Verarbeitung: Der akzeptierte Fuji-/Waldzug des Masters bildet den 1024-Texel-Nordsektor. Die drei übrigen Richtungen verwenden daraus abgeleitete, richtungsrichtig angeordnete und an den Eckspalten exakt verbundene niedrigere Kanto-Gebirgszüge. Die Runtime nutzt nearest filtering, keine Mipmaps, einen gemeinsamen Canvas und einen Wall-Draw.

## Ländlicher Feld-/Heckengürtel

- Master: ImageGen-Source-ID `exec-33b2f4c3-be00-44d9-a56b-e2d3d37da25b.png`
- Master-SHA-256: `70fd7193630e923480930f02b31ce515c69621e4512569b4d1bd2a189efd60f5`
- Runtime: `assets/scenery/rural_edge.compact.png`, 512×128 RGBA, 62 Farben, Alpha 0/255
- Prompt-Ziel: niedrige Felder, gestaffelte Hecken, wenige Blumen, kompakte Laub-/Nadelbäume und winzige entfernte Farmdächer im scharfen Kanto-Handheld-Pixelstil; keine mittelalterliche Architektur, Windmühlen, Moderne, Unschärfe oder Gradienten.
- Verarbeitung: Drei anschließbare Ausschnitte wurden offline mit Nearest-Neighbor auf das feste Runtime-Maß gebracht, ohne eine Himmelsfläche in die Alpha-Silhouette einzubrennen.

## Hafen-/Küstengürtel

- Master: ImageGen-Source-ID `exec-60d8e200-a3d6-4da1-9966-af25fc87059d.png`
- Master-SHA-256: `dba87444e614a1cdbc8d5852e977cbf635de0f09228f2238c41e9f7f5ce31359`
- Runtime: `assets/scenery/harbor_edge.compact.png`, 512×128 RGBA, 63 Farben, Alpha 0/255
- Prompt-Ziel: niedrige Seemauer, ruhiges Wasser, kompakte japanische Hafenhäuser, kleines Terminal, sparsame Kräne/Masten, Wellenbrecher und kleiner Leuchtturm; kein Containerhafen, keine Windräder, keine mittelalterliche Stadt, kein Blur.
- Verarbeitung: Anschließbare Module wurden auf die gemeinsame Grundlinie und das feste 512×128-Maß reduziert. Die offenen Wasserkanten bleiben geometrisch offen; das Bild darf keine Kollisions- oder Bodenfläche ersetzen.

## Ferne Küsteninseln und Seeposten – V2

- Erzeuger: eingebautes ImageGen-Werkzeug (Built-in ImageGen).
- Finaler Promptkern: vier einzeln freigestellte, scharfe Retro-Handheld-Kanto-Küstenmotive – bewaldete Felseninsel, kompakter Leuchtturm-/Seeposten, niedrige Schären und Cinnabar mit Siedlung/Vulkan – mit harten Pixelclustern, transparenter Himmelsfläche und gemeinsamer Wasserlinie; keine Schrift, Figuren, Pokémon, Wolken, Vögel, moderne Skyline, weichen Kanten oder fotorealistischen Verläufe.
- Ursprüngliche Master und SHA-256:
  - `tools/sources/coastal_landmarks_v2/01-rocky-island.imagegen.png` (ursprüngliche ImageGen-Source-ID `exec-90461ca1-83e2-49cd-ad84-f6377593a8ea.png`) – `dbed1fda229fba5b79cc13321b7aea73e61aab31e3cc6b8a0e2f31f4acd5dd2b`
  - `tools/sources/coastal_landmarks_v2/02-lighthouse.imagegen.png` (ursprüngliche ImageGen-Source-ID `exec-0b539e99-9214-4891-9c88-5ca15442991e.png`) – `333aa4d226cde7dd2243b7d7d5b4ab832b31d0aa1ab2ad3cded774c75a7ba5ca`
  - `tools/sources/coastal_landmarks_v2/03-archipelago.imagegen.png` (ursprüngliche ImageGen-Source-ID `exec-0648228d-12a4-4c5c-ae79-5b1e9e437aef.png`) – `5e25cc63becddcfe741f9d7689032727f061ecf57fa11f095535a4f85ccf804e`
  - `tools/sources/coastal_landmarks_v2/04-cinnabar.imagegen.png` (ursprüngliche ImageGen-Source-ID `exec-d68b0249-1c82-407d-bc98-fcb6a67a9c27.png`) – `9b5fe7fd3f2dfd15449da055619cb6277fc76fc7cbf8979c6551dc8fbdbeed38`
- Versionierte Workspace-Quellen und SHA-256:
  - `tools/sources/coastal_landmarks_v2/01-rocky-island.imagegen.png` – `dbed1fda229fba5b79cc13321b7aea73e61aab31e3cc6b8a0e2f31f4acd5dd2b`
  - `tools/sources/coastal_landmarks_v2/02-lighthouse.imagegen.png` – `333aa4d226cde7dd2243b7d7d5b4ab832b31d0aa1ab2ad3cded774c75a7ba5ca`
  - `tools/sources/coastal_landmarks_v2/03-archipelago.imagegen.png` – `5e25cc63becddcfe741f9d7689032727f061ecf57fa11f095535a4f85ccf804e`
  - `tools/sources/coastal_landmarks_v2/04-cinnabar.imagegen.png` – `9b5fe7fd3f2dfd15449da055619cb6277fc76fc7cbf8979c6551dc8fbdbeed38`
  Diese vier Quellen bleiben im Projekt, sind aber nicht Teil des Release-ZIP.
- Reproduzierbarer Build: `tools/build_coastal_landmarks_v2.py` liest ausschließlich die Workspace-Quellen, prüft deren vollständige Hashes sowie 1254×1254 RGBA, beschneidet die binäre Alpha-BBox und skaliert jedes Motiv proportional mit Nearest-Neighbor in sein 128×128-Modul. Modulfolge ist 0 Felseninsel, 1 Leuchtturm, 2 Schären, 3 Cinnabar. Jedes Modul endet exakt auf der bemalten Zeile y=88, besitzt ausschließlich Alpha 0/255 und höchstens 48 sichtbare RGB-Farben; Quantisierung erfolgt ohne Dithering oder Antialiasing.
- Ehemalige Runtime: `assets/scenery/coastal_landmarks_v2.compact.png`, 512×128 RGBA, SHA-256 `f9d5b0179c76cb6803f5c5f79c051eef419486040c6017c67d3ac1036d4c3ebb`. V2 bleibt zusammen mit V1 unverändert als Rollback-/Differenznachweis im Repository, ist aber weder Runtime-Referenz noch Release-Allowlist-Eintrag.
- Freigabegrenze: technische/reproduzierbare Quelle und statischer Kandidat; keine visuelle Freigabe ohne identische native Retakes.

## Ferne Küsteninseln und Seeposten – V3

- Erzeuger: eingebautes ImageGen-Werkzeug (Built-in ImageGen).
- Promptkern: vier einzeln freigestellte, kompakte Retro-Handheld-Kanto-Motive mit echten transparenten Zwischenräumen und unregelmäßigen Felsfüßen: bewaldete Felseninsel; kleiner rot-cremefarbener Leuchtturm mit Häuschen; drei getrennte niedrige Schären; niedriges Cinnabar-Städtchen vor einem moderaten Vulkan. Ausgeschlossen wurden Hintergrund, Glow, weiche Kanten, moderne Architektur, durchgehende Wasser-/Schaumbänder, breite Kaikanten und gerade vollbreite Grundlinien.
- Finale ImageGen-Ausgaben, exakte Mastermaße und SHA-256:
  - `tools/sources/coastal_landmarks_v3/01-rocky-island.imagegen.png` (ursprüngliche ImageGen-Source-ID `exec-8ffd607c-fdb4-41df-8c45-99e5251c1a1d.png`) – 1774×887 RGBA – `dcc71501b90af37ab2636d246c9208f378ec82e6564e8ad96af6189ef5438615`
  - `tools/sources/coastal_landmarks_v3/02-lighthouse.imagegen.png` (ursprüngliche ImageGen-Source-ID `exec-a0fa1976-da07-4ac7-b683-7859fa447c88.png`) – 1421×1107 RGBA – `f7b353ab0a14e268ab4263482f819b7403d563981e6fc40d3979b56c1fb39477`
  - `tools/sources/coastal_landmarks_v3/03-archipelago.imagegen.png` (ursprüngliche ImageGen-Source-ID `exec-fc9d6651-427d-4166-817c-80901d528e5e.png`) – 1942×809 RGBA – `88c5b522f12cb109b6e79d3397937b85d86374932bfd429cfabf9ac61f02dde1`
  - `tools/sources/coastal_landmarks_v3/04-cinnabar.imagegen.png` (ursprüngliche ImageGen-Source-ID `exec-ac924fd6-781d-44a7-9c20-4d59f21a4a1e.png`) – 1774×887 RGBA – `db0f5fb83b84e9974c503b56748c2e01cfeced586a6ab355a6b1959210ffedec`
- Versionierte Workspace-Quellen: dieselben Bytes unter `tools/sources/coastal_landmarks_v3/01-rocky-island.imagegen.png`, `02-lighthouse.imagegen.png`, `03-archipelago.imagegen.png` und `04-cinnabar.imagegen.png`. Die vier Master bleiben außerhalb des Release-ZIP.
- Reproduzierbarer Build: `tools/build_coastal_landmarks_v3.py` pinnt je Quelle SHA-256, Größe und RGBA-Modus, beschneidet Alpha bei Schwelle 128, skaliert ausschließlich per Nearest-Neighbor und proportional in die bereits vorgesehenen World-Maxima, quantisiert nur sichtbare Pixel ohne Dithering auf höchstens 48 Farben und setzt Alpha anschließend strikt auf 0/255. Die vier 128×128-Module enden auf Zeile y=88; ihre exakten Alpha-BBoxen sind (x0,y0,x1,y1) `20,50,108,89`, `24,29,104,89`, `16,56,112,89` und `28,60,100,89`. Zusätzlich verwirft der Builder jede untere Acht-Zeilen-Struktur mit mindestens 90 Prozent Gesamtdeckung, einem mindestens 85 Prozent breiten zusammenhängenden Lauf, einer vollbreiten Alpha-Zeile oder mehr als 16 opaken Pixeln auf der letzten Zeile; dadurch kann weder ein gemeinsames Wasser-/Schaumband noch eine harte oder seitlich gekappte Kartenbasis zurückkehren.
- Runtime: `assets/scenery/coastal_landmarks_v3.compact.png`, 512×128 RGBA, SHA-256 `744a844ff400ea65599f44daed03f684f02e2e57bf2492845ac2f870052ee48c`. Runtime-UVs beschneiden das transparente Modul-Padding auf die vier fixierten BBoxen; die sichtbaren Weltmaße 88×39, 80×60, 96×33 und 72×29 entsprechen dadurch exakt den gesampelten Texeln (1 Texel = 1 World-Pixel, horizontal und vertikal). Atlasgröße, 256-KiB-VRAM-Budget, ein aggregierter Coastal-Draw, Kurven-Tessellation, Landmark-Zuordnung und ein Motiv pro Karte bleiben unverändert. Eine fehlende oder falsch dimensionierte V3-Datei wird über den bestehenden Compact-Asset-Vertrag verworfen; der V2-Pfad wird nie als Runtime-Fallback gelesen. Den exakten V3-Bytehash erzwingen Builder-, Provenienz- und Release-Tests vor der Auslieferung.
- Statische Sichtgrenze: Im 128px-Compact bleiben Leuchtturmfenster, Vulkan/Stadt und drei getrennte Schären erkennbar. Die unterste Zeile belegt je Modul nur 8/5/5/4 Pixel. Native identische Retakes sind weiterhin erforderlich, bevor die South-Sea-Familie visuell freigegeben wird.

## Zinnober-Südpfad – Vulkan und Birth Island

- Erzeuger: eingebautes ImageGen-Werkzeug (Built-in ImageGen).
- Promptkern Vulkan: eigenständig gestaltete, entfernte Vulkaninsel in sanfter 3/4-Seitenansicht mit breitem unregelmäßigem Felsfuß, einem klaren Krater, wenig Vegetation, zurückhaltenden warmen Schloten und kleiner heller Rauchfahne; handgemalte Aquarell-/Gouache-Routenillustration, transparent, ohne Himmel, Figuren, Pokémon, Schrift, Gebäude oder mittelalterliche Gestaltung.
- Promptkern Birth Island: eigenständig gestaltete, deutlich niedrigere Forschungsinsel in Links-unten→Rechts-oben-Tiefe mit facettiertem meteoritenähnlichem Zentralstein, windgeformtem Grün, kleiner temporärer Plane und schmalem Messmast; transparent, ohne Deoxys/Pokémon, Figuren, Stadt, Vulkan, Schrift, Logo oder mittelalterliche/futuristische Basis.
- Finale echte RGBA-Master und exakte SHA-256:
  - `tools/sources/cinnabar_story_landmarks/01-cinnabar-volcano.imagegen.png` (ursprüngliche ImageGen-Source-ID `exec-0528dd96-d954-4642-86c2-bfcf3960b80e.png`) – 1774×887 RGBA – `cabb66307daf915e0a21e236769eed21ef2cbe7e1bc7601f42da14e74f21288b`.
  - `tools/sources/cinnabar_story_landmarks/02-birth-island.imagegen.png` (ursprüngliche ImageGen-Source-ID `exec-40b4ef3b-90a0-490c-987c-5351d19938d8.png`) – 1774×887 RGBA – `cded987286560b4ebf4fbc52444ef639064e973babab82a23301b20839bc1b83`.
- Nicht verwendete Bearbeitungsversuche `exec-af32169d-b0d8-46d1-94d3-8e9d95ea92a3.png` und `exec-458665ec-1427-475c-a67c-ef8ba07c1b46.png` wurden verworfen, weil ihr sichtbares Vorschau-Schachfeld als RGB eingebrannt war. Sie sind weder Workspace-Quelle noch Release-Bestandteil.
- Reproduzierbarer Build: `tools/build_cinnabar_story_landmarks.py` pinnt Quelle, Hash, Maß und RGBA-Modus, beschneidet Alpha und reduziert proportional mit premultipliziertem Lanczos-Downsampling. Die zusammenhängenden gemalten Küsten- und Brandungsfüße bleiben erhalten; nur nahezu transparente Werte unter 8 und isolierte Compact-Komponenten unter 24 Pixeln werden entfernt. Sichtbare Farben werden ohne Dithering auf höchstens 96 Farben quantisiert. Transparente Runtime-Texel sind RGB `(0,0,0)`; weiches Alpha bleibt für saubere Baum-, Rauch-, Fels- und Wasserkanten erhalten.
- Runtime: `assets/scenery/cinnabar_story_landmarks.compact.png`, exakt 512×128 RGBA, SHA-256 `ddbfeac791b1b35fa5571277f9a85da9d310e8082427cff1b751c53fb5fa84ba`. Modul 0 (Vulkan) sampelt BBox `(18,15,238,119)` mit 220×104 Texeln und wird auf 144×68 Weltpixel projiziert; Modul 1 (Birth Island) sampelt BBox `(30,35,226,119)` mit 196×84 Texeln und wird auf 112×48 Weltpixel projiziert. Die höhere Sample-Auflösung verhindert zerhackte Silhouetten, ohne die entfernten Landmarken zu vergrößern. Beide teilen einen zusätzlichen 256-KiB-Texturslot sowie einen aggregierten Draw und nutzen lineare Filterung.
- Laufzeitvertrag: Erst die vollständige, outdoor und reziprok verbundene Vierkartenstruktur `CINNABAR_ISLAND` → `CINNABAR_SOUTH_CHANNEL` → links `CINNABAR_VOLCANO` / rechts `KA_HOENN_BIRTH_ISLAND` aktiviert die Spur. Vulkan bleibt links, Birth Island rechts. Ein bereits gestreamter Zielkörper unterdrückt nur seine eigene Fernkarte. Ältere KASC-Version, fehlende Karte, falsche ID/Richtung/Offset, unpassendes Asset oder fehlende GPU-Textur lassen die bestehende Küste unverändert; Kollision, Warps, Questflags, NPCs und klassisches 2D werden nie berührt.

## Route 8 – durchgehender Fernstrip

- Master: ImageGen-Source-ID `exec-63cee975-de2b-44f2-9b13-9a24aff1e671.png`
- Master-SHA-256: `db746f1b0531c8a3c8437912e76784dddce3f4db7ed2cea3d43e499323f2d22f`
- Runtime: `assets/scenery/route8_horizon.compact.png`, 960×96 RGBA, Alpha 0/255
- Prompt-Ziel: ein durchgehender Retro-Kanto-Horizont von Saffronia über niedrige Vorstadt bis Lavandia: links ein zurückhaltender Civic-/Silph-Akzent, mittig kleine Häuser und Baumgürtel, rechts genau ein violetter Turm-/Friedhofsakzent mit Bergen; keine Schrift, Logos, Glas-Skyline oder fotorealistischen Flächen.
- Verarbeitung: Der Master wurde in einen einzigen 960px-Streifen mit festen Connector-Spalten überführt. West besitzt die Saffronia-Landmarke, Ost die Lavandia-Landmarke; N/S verwenden landmarkenfreie Fenster. Die Runtime streckt den Strip nicht über eine beliebige Union und erzeugt für Route 8 nur eine Wall-Familie.

## Route 8 – Mittelgrundmodule

- Master: ImageGen-Source-ID `exec-4d7836a4-d45a-4e52-a80e-c5b56b97ff1a.png`
- Master-SHA-256: `3f105320fc86f43cf6f8d6e7e5561fbe15a542235a23ba4151ecde5d10d8edef`
- Runtime: `assets/scenery/route8_midground.compact.png`, 256×64 RGBA, acht 32×64-Module, 32 Farben, Alpha 0/255
- Prompt-Ziel: vier niedrige Saffronia-Randmodule (Lampe, kleines Haus, Laden, Zaun/Strauch) und vier niedrige Lavandia-Module (Konifere, Friedhofszaun, Gräber/Busch, Bäume/Hecke); keine zweite Landmarke, Personen, Pokémon, Schrift oder Unschärfe.
- Verarbeitung: Die acht Alpha-Komponenten wurden einzeln beschnitten, proportional mit Nearest-Neighbor in höchstens 30×43 sichtbare Pixel eingepasst, bodenbündig gesetzt, ohne Dithering auf 32 Farben reduziert und auf binäres Alpha gebracht. Der aktuelle reduzierte Route-8-Aufbau bleibt in einem aggregierten Foreground-Draw und nutzt einen 64-KiB-Canvas.

## Vertania-Waldtor – kanonische Route-2-Front

- Quelle: `gen1recomp/assets/generated/tilesets/overworld.png`, 128×48 RGBA, SHA-256 `c2434aafd7d643e0f2f3866a41bf236d015eb6c39cf9f75dabc424750517b309`. Dies ist ein vorhandenes kanonisches Spielasset; es wurde kein ImageGen-Master und keine neue Gestaltung verwendet.
- Autoritative Platzierung: `ROUTE_2`, Gebäude 2 ab Tile `(4,80)`, Tür/Warp 6 zu `VIRIDIAN_FOREST_SOUTH_GATE`; Profil B03 `flat_commercial`. Die vollständige 8×8-Tilematrix ist im Builder fixiert. Der vor der Farbzuweisung zusammengesetzte 64×64-RGBA-Puffer besitzt SHA-256 `97b1ddd08923919a0523097781b1f8dd763c68c57c47d2827c48ac5d618f1783`.
- Reproduzierbarer Build: `tools/build_viridian_forest_gate.py` prüft den vollständigen Quellhash, setzt ausschließlich die 64 kanonischen 8×8-Tiles zusammen und wendet dieselben vier Shade-Grenzen, OVERWORLD-Tilegruppen sowie den Route-2-Dachfarbslot (Map-Index 13) wie `TileRenderer`/`PaletteFX` an. Die binäre Alphamaske flutet im vollständigen 64×64-Verbund vom Bildrand nur durch die beiden hellen Quellshades; die beiden Strukturshades und eingeschlossene helle Details bleiben sichtbar. Erst danach wird ausschließlich Quellzeile `y=24..63` ausgeschnitten, sodass Traufe, Fenster, Mauerwerk und Tür erhalten bleiben, das Top-down-Dachfeld aber nicht senkrecht montiert wird. Der 64×40-Crop besitzt exakt 2140 opake und 420 transparente Pixel, Alpha ausschließlich 0/255 und BBox `(3,0)-(61,40)` mit exklusiver rechter/unterer Kante.
- Runtime: `assets/scenery/viridian_forest_gate.compact.png`, 64×40 RGBA, SHA-256 `95a28a896892d538b2ff1f3bd0da93c81d7a8e441d5053a27e53ab2a8cad2977`, zehn sichtbare kanonische GBC-Farben. Nord- und Südabschluss teilen bei 1 Texel = 1 World-Pixel einen 10-KiB-Canvas, zwei Quads und einen Draw; die Südseite spiegelt nur U. Wege, übrige Waldgeometrie, Kollision und Warps werden nicht verändert. Eine fehlende, alte 64×64 oder sonst falsch dimensionierte Datei lässt den Horizon-Key fail-closed abbrechen.

## Mondberg – Wand und Decke

- Wand-Master: ImageGen-Source-ID `exec-ef9be062-30ef-4818-a90d-caf50cf2208c.png`
- Wand-Master-SHA-256: `164bf235d1ffef68e2d0966e2df65efff4f1704e56d94a5d1bc0f5125915fd89`
- Decken-Master: ImageGen-Source-ID `exec-3f534911-737b-4a3e-af6c-0596ccccdeaa.png`
- Decken-Master-SHA-256: `9834bb2565464e752fc2d4ef4870c0ee5fa473dd6cf5c67cb366a56c911a7073`
- Runtime: `mt_moon_wall.compact.png` 512×160 und `mt_moon_ceiling.compact.png` 256×256, jeweils vollständig opak und 22 Farben
- Prompt-Ziel: dunkles kühl-violettgraues/anthrazitfarbenes Mondgestein in harten Handheld-Pixelclustern; zwei unterschiedliche Wandformationen, unregelmäßige Deckenplatten/Risse, keine Figuren, Requisiten, Perspektive, Schrift, Painterly-Softness oder Gradienten.
- Verarbeitung: Wand 256×80 und Decke 128×128 wurden zunächst in echte Cluster reduziert und danach exakt 2× nearest skaliert. Beide wurden ohne Dithering auf 22 Farben gehärtet. Die Wand besitzt eine unregelmäßige dunkle Kontaktkante und identische Randspalten; die Decke identische Gegenkanten. Native V3-Abnahme: `MT_MOON_1F` 78/100 lokal behalten, `B2F` 80/100 lokal behalten, Gesamtfamilie und übrige Höhlen noch nicht freigegeben.

## Pokémon-Turm – Wand und Decke

- Wand-Master A: ImageGen-Source-ID `exec-0048ef76-a3c5-486b-a514-6116f40b6e09.png`
- Wand-Master-A-SHA-256: `1fa57d46ecdb5a4b789615943959cc2676e8e534475186432fb599b820f0f934`
- Wand-Master B: ImageGen-Source-ID `exec-911d5b62-9f50-423a-9204-bb321b2c5b5b.png`
- Wand-Master-B-SHA-256: `e84b3a3b503b3ac10cba904a1e4c8863fe4cdda340e16a4e0ab8358af51aaf84`
- Decken-Master: ImageGen-Source-ID `exec-7052e32d-0ce0-4310-9ef5-c04acb34956a.png`
- Decken-Master-SHA-256: `7627c365c0c5d37f2e6d4a49e145ba77155010e136bf5239c84c2a97f37479c3`
- Runtime: `pokemon_tower_wall.compact.png` 512×160 und `pokemon_tower_ceiling.compact.png` 256×256, jeweils vollständig opak und 24 Farben
- Prompt-Ziel Wand: dunkle pflaumen-/schieferfarbene Gedenkturm-Mauer mit zurückhaltenden rotbraunen japanischen Holzrahmen, wenigen elfenbeinfarbenen Feldern und zwei wirklich unterschiedlichen breiten Architekturbuchten; keine Figuren, Gräber, Türen, Außenfenster, Schrift, Perspektive oder kleine Tapetenwiederholung.
- Prompt-Ziel Decke: passende dunkle Kassettendecke aus Stein und Holz mit wenigen warmen Licht-/Lüftungsdetails, flach von oben, vierseitig anschließbar und ohne große Mittelsymbole, moderne Leuchten, Perspektive, Blur oder Gradienten.
- Verarbeitung: `tools/build_tower_materials.py` beschneidet beide Wand-Master zwischen nachgewiesenen Vollhöhenpfosten, reduziert jede Bucht mit Nearest-Neighbor auf 256×160, kombiniert beide und quantisiert die gemeinsame Wand ohne Dithering auf 24 Farben. Die Decke wird ebenso nearest auf 256×256 reduziert. Pfostenjoin und alle Wrap-Kanten werden pixelgenau geschlossen; die 32×32-Prüfung findet 80/80 unterschiedliche Wand- und 64/64 unterschiedliche Deckenblöcke.
- Runtime-Vertrag: Alle sieben Turmetagen teilen genau einen 512×160-Wand- und einen 256×256-Decken-Canvas. Quellen werden nach dem Backen freigegeben; Geometrie, 32px-WorldCurve-Raster und zwei Draws bleiben unverändert. Retained VRAM: 589.824 Byte (576 KiB). Bei fehlenden oder falschen Assets bleibt der alte opake prozedurale Turm als Fallback erhalten.
- Freigabestatus: **RETEST OFFEN**. Der Pass beseitigt den nachgewiesenen kleinen Wand-/Deckenstempel technisch, erhöht den Tower-Score aber erst nach identischen nativen 1ST-/3RD-Aufnahmen aller Etagen.

## Pokécenter-Raumhülle

- Wand-Master: ImageGen-Source-ID `exec-030f9bc5-a82c-4771-9fe5-c910e056c074.png`
- Wand-Master-SHA-256: `ca5c4befb4b53730c8bb6efe0aac3e00ab1d19376f090b7b1618480148d4113d`
- Decken-Master: ImageGen-Source-ID `exec-fbcccbb3-ed85-43b4-9e9f-ae92c771405b.png`
- Decken-Master-SHA-256: `d94d6cd35bbc41ae6564d535ad43cf3b7ba59ca5462db1ee795b64ecf0dd365d`
- Runtime: `pokecenter_room_wall.compact.png` 128×160 und `pokecenter_room_ceiling.compact.png` 128×128, jeweils vollständig opak und 24 Farben
- Prompt-Ziel: ruhige Kanto-Pokécenter-Innenwand und -Decke in Elfenbein, Blaugrau, Olivgold und Kobaltblau; keine Höhlenziegel, Naturtextur, Figuren, Pokémon, Schrift, Logos, Transparenz oder weiche Gradienten.
- Verarbeitung: Beide Materialien blieben im nativen Zielmaß, wurden ohne sichtbaren Kantenbruch auf 24 Farben reduziert und als exakte Wiederholung geprüft. Sie werden ausschließlich für `MT_MOON_POKECENTER` und `ROCK_TUNNEL_POKECENTER` verwendet. Echte `CAVERN`-/`ORANGE_GEN2_CAVE`-Tilesets bleiben autoritativ Höhlen und können niemals diese Room-Art erhalten.
- Budget: zwei geteilte RGBA8-Canvases, zusammen 147.456 Byte (144 KiB), und zwei Horizon-Draws pro isoliertem Raum.

## Arenenkulisse – Nuggetbrücke

- Ausgewählter ImageGen-Master: `tools/sources/arena_scenery/nugget_bridge_anchors_v2.imagegen.png`, 1548×1016 RGB, SHA-256 `101f1e7f86205a31d70d3acd98d7a994d017131272c1d9dcca54fa323ad910a5`.
- Prompt-Ziel: eine eigenständig gezeichnete, breite Kanto-Aquarell-/Gouache-Kampfszene an einer langen goldenen Bogenbrücke über blauem Fluss. Die zwei auffälligen hellen Ovalflächen der vorigen Fassung wurden vollständig in eine zusammenhängende Wiese zurückgemalt. An den festen 3X-Figurenankern bleiben ausschließlich sehr subtile, überwiegend grüne Trittspuren; sie dürfen nie wie Plattformen oder aufgeklebte Kreise lesen. Bank, weißer Uferzaun, rechter Seilzaun, Brücke, Fluss, Vegetation und die Öffnung für den echten Spielhimmel bleiben erhalten. Keine Figuren, Pokémon, Schrift oder UI.
- Reproduzierbarer Build: `tools/build_arena_scenery.py` pinnt Master-Hash und -Maß, entfernt ausschließlich das vom Bildrand aus zusammenhängende helle neutrale Vorschau-Schachfeld, erweitert diese Maske minimal gegen helle Säume und skaliert in premultipliziertem Alpha per Lanczos auf das Runtime-Maß. Oberkante muss vollständig transparent, Unterkante vollständig opak und die Silhouette antialiasiert bleiben.
- Runtime: `assets/battle/nugget_bridge_a.compact.png`, 1280×800 RGBA, SHA-256 `e86a1d07a4668139bd9afbe1668b0e0d81eeeceba2478cd8520ad029478b46a3`. Nur das exakt geprüfte Profil `nugget_bridge` darf es laden. Es wird hinter Pokémon und HUD linear gefiltert, mit derselben Tageszeitfarbe wie die Kämpfer getönt und lässt Wetter, Sonne, Mond und Sterne des Live-Himmels durch die Alphaöffnung sichtbar. Unbekannte Orte, Innenräume, fehlende oder falsch dimensionierte Dateien fallen geschlossen auf den normalen Kampf zurück; die verworfene prozedurale Pixelcollage wird nicht als Ersatz angezeigt.
- Auswahlstatus: Die flache erste Fassung und die geerdete Zwischenfassung bleiben als `nugget_bridge_a.imagegen.png` und `nugget_bridge_grounded.imagegen.png` für Rollback und Bildvergleich erhalten. `nugget_bridge_anchors_v2.imagegen.png` beseitigt deren zwei unnatürliche helle Standovale. Der native Lauf `nugget-arena-anchors-v7` bestätigt **RETAIN** in festem 3X und STADIUM: beide Figuren stehen auf derselben natürlichen Wiese, Bank und Zäune bleiben lesbar, und es gibt keine Plattform-, Wasser- oder HUD-Kollision. Beide zulässigen Kompositionen verwenden denselben verpflichtenden, bildspezifischen 3X-Ankersatz (`player x/y/z = 0/-8/0`, `enemy = 0/-16/0` relativ zu den kanonischen Kampfzellen); Rot und Gegner stehen auf der trockenen Wiese oberhalb des HUD. ARENA ignoriert die MAP/DISCS-Rungen 1X/2X und sperrt manuelles Orbit/Pitch/Zoom. Jede weitere veröffentlichte Arenenkulisse muss ebenfalls Kamera=`3X` sowie endliche Player-/Enemy-X/Y/Z-Anker deklarieren; fehlt ein Receipt, fällt der Ort geschlossen auf den normalen Kampf zurück.

## Freigabestatus

## Arenenkulissen – vollständige 111-Anker-Auswahl

Die Auswahloberfläche unter `qa-screenshots/vasc/arena-scenery-candidates-20260822/`
ordnet 95 Karten mit insgesamt 111 Kampfankern 46 eigenständig erzeugten
Masterkulissen zu. Alle Runtime-Dateien sind 1280×800 RGBA. Außenkulissen
besitzen eine echte, vom oberen Rand zusammenhängende Alphaöffnung für den
Live-Himmel; Innenräume sind vollständig opak. Die beiden festen
Figurenfußpunkte `(43 %, 66 %)` und `(56 %, 61 %)` sowie die unteren 32 Prozent
für das unveränderte Spiel-HUD sind in jeder aktiven Fassung opak. Spielhalle,
Rocket-Versteck, M.S.-Anne-Kabinen, Eichs Labor und Silph Co. verwenden die
nachträglich enger gefassten, menschlich skalierten Varianten. Lorelei und
Fuchsania sind auf die verbindliche Links-unten-nach-Rechts-oben-Komposition
gespiegelt. Route 22 übernimmt in seiner C-Fassung Fels, Wasser, Pfeiler und
Torarchitektur des Route-23-Anstiegs. Die jeweilige Preview ist der ausgewählte
Projektmaster; alternative A/B/C-Fassungen bleiben nur im Audit.

Die 17 Außenkulissen werden aus ihren unveränderten Projektmastern mit
`tools/sources/arena_scenery/repair_outdoor_sky_matte.py` reproduzierbar
nachbearbeitet. Der Schritt entfernt ausschließlich topologisch abgetrennte
Matte-Inseln und ersetzt schwarze beziehungsweise Cyan-/Rot-/Grün-Fremdfarben
an der Live-Himmel-Kante durch die robuste lokale Bildfarbe; die Alpha-Kontur,
Abmessungen, Figurenanker und sämtliche Innenpixel außerhalb des schmalen
Skyline-Prüfbereichs bleiben erhalten.
Das Safari-Profil aktiviert zusätzlich `--fill-dark-matte`: Die dort im
Projektmaster eingeschlossenen opaken Schwarzflächen werden mit benachbarter
Laub-/Holzfarbe gefüllt, ohne die Alpha-Silhouette zu öffnen.

| Runtime-Datei | SHA-256 | ausgewählter Projektmaster |
|---|---|---|
| `assets/battle/arena_cape-route25.compact.png` | `444da9c117ac0a25e953cf07fb12c69a8f4488cedd71cd1aa776d2af1575a1cd` | `previews/route25-cape-v1.png` |
| `assets/battle/arena_cave-cerulean.compact.png` | `69fe69ab74f5d291fdec9c1966899087358b8eb4a07da5bf511a06df4c84b5ce` | `previews/profile-cave-cerulean-baseline-v1.png` |
| `assets/battle/arena_cave-diglett.compact.png` | `a568da9855e38e22e35aac14a31864b78765ddbf36ac6c2d5ebb82b404f6b027` | `previews/profile-cave-diglett-baseline-v1.png` |
| `assets/battle/arena_cave-mt-moon.compact.png` | `7217da25e804c321de02e398e1528143cf311f71bd28f244c026b91a8c102e8c` | `previews/profile-cave-mt-moon-baseline-v2.png` |
| `assets/battle/arena_cave-rock-tunnel.compact.png` | `cd6b8d6767f57924039bc98ae71c89d8d43700cf5bd4b1b0e2fcd1a14f327ddf` | `previews/profile-cave-rock-tunnel-baseline-v1.png` |
| `assets/battle/arena_cave-seafoam.compact.png` | `1fd37693394cf14c1f1ffb28fc34bca462c75f2edfb1dd1a1e189642732b3b42` | `previews/profile-cave-seafoam-baseline-v1.png` |
| `assets/battle/arena_cave-victory-road.compact.png` | `c6b7b38cb7793df7019dbef62442d69b896397f42b2c88b1cc2ad533b85177eb` | `previews/profile-cave-victory-road-baseline-v1.png` |
| `assets/battle/arena_cerulean-canal.compact.png` | `bb9243b38c1ed0e146abd7afa3dd0c3ebc3c57bff1d31dc060a5ac0893175d99` | `previews/cerulean-rival-c1.png` |
| `assets/battle/arena_coast-cinnabar.compact.png` | `c9e7faf6663a9a7592c70f719514b1c47b56ce597549bfe6e5dc9591fb2e0ba4` | `previews/profile-coast-cinnabar-baseline-v1.png` |
| `assets/battle/arena_coast-surf.compact.png` | `1b641515d1c7bd34e31027f2d6917d7460052ded9749a0907c5b9ff44c612d6f` | `previews/profile-coast-surf-baseline-v2.png` |
| `assets/battle/arena_forest-viridian.compact.png` | `5f2141d3f5e499aca586ffc36a73e30ef74684ec8501a6af023128e8ba463e6e` | `previews/profile-forest-viridian-baseline-v2.png` |
| `assets/battle/arena_grass-route1.compact.png` | `da4d768ade44fae36537889f4b2f769975598f2b2e9d7c31856291cfc0dbe50c` | `previews/route1-pallet-v1.png` |
| `assets/battle/arena_grass-kanto-open.compact.png` | `2a64cc54c6176e483bd80a2dad6b7d9032c968a424b3963129e6ba381f532957` | `previews/profile-grass-kanto-open-baseline-v1.png` |
| `assets/battle/arena_gym-celadon.compact.png` | `938b1dbdf381bb2c8c5aa600fd4a1aa9cd921a4fcf3ae173b25a7517bc087ae8` | `previews/profile-gym-celadon-baseline-v2.png` |
| `assets/battle/arena_gym-cerulean.compact.png` | `15c3740c6fb3051c83df96377cfa3d116950875d558f9468df953e7b4cad44e3` | `previews/profile-gym-cerulean-baseline-v2.png` |
| `assets/battle/arena_gym-cinnabar.compact.png` | `c6b330bba2951bde94a4b1feab625fdee987703c31b65b4b2c32e9072475b586` | `previews/profile-gym-cinnabar-baseline-v2.png` |
| `assets/battle/arena_gym-fighting-dojo.compact.png` | `523053799f16e7ab56f9775ac568dfec718640f8ed62b2706fcc02a9f6ae6b4c` | `previews/profile-gym-fighting-dojo-baseline-v2.png` |
| `assets/battle/arena_gym-fuchsia.compact.png` | `61b7364c621f8200da26ac972a6425f12e490fcec7304b9c369573014b31d12f` | `previews/profile-gym-fuchsia-baseline-v3.png` |
| `assets/battle/arena_gym-pewter.compact.png` | `a7aa6ac36d13bb0a9a4cecc00be4536fe19c113a1c5e678de1db333708bfade8` | `previews/profile-gym-pewter-baseline-v2.png` |
| `assets/battle/arena_gym-saffron.compact.png` | `5aa1c1836b65826b792f780424474f947138ec89abe538b94efdb4287748299a` | `previews/profile-gym-saffron-baseline-v1.png` |
| `assets/battle/arena_gym-vermilion.compact.png` | `95cbf52f3ff2f9ae34968eb8e94e536b7734e07333638d31a78f4f41f7ae6ac5` | `previews/profile-gym-vermilion-baseline-v1.png` |
| `assets/battle/arena_gym-viridian.compact.png` | `15498f412b0a306ef761cdbb3ee91a050e1eaedc97b74870f54351348607cb19` | `previews/profile-gym-viridian-baseline-v2.png` |
| `assets/battle/arena_indigo-gate-route22.compact.png` | `f97ce6226dfc7e5236bd65e6a5cfcd4312d820b711bd4d5d4149a27ed3aa3912` | `previews/profile-indigo-gate-route22-baseline-v3.png` |
| `assets/battle/arena_indigo-road-route23.compact.png` | `c9b7fd2fd6d1c3b7e54a7efbc1e573d29644ae3ff5afdaa44eb7d68d15640e71` | `previews/profile-indigo-road-route23-baseline-v1.png` |
| `assets/battle/arena_industrial-power-plant.compact.png` | `8cc53b683232903fc24dea8abbd2800dfbe77df6972bd7354ecc232dc834755d` | `previews/profile-industrial-power-plant-baseline-v2.png` |
| `assets/battle/arena_industrial-silph.compact.png` | `af9670e6c595ccc241f5d91736dd772c5abd07009f92fec0747e6c786ba2c241` | `previews/profile-industrial-silph-baseline-v3.png` |
| `assets/battle/arena_interior-oaks-lab.compact.png` | `169f6b12dde7493c8d446192a34981e311396d6582ff586eac58dc65785e8443` | `previews/profile-interior-oaks-lab-baseline-v3.png` |
| `assets/battle/arena_league-lorelei.compact.png` | `b49c0c5ac487ac00d9a5a060718047fc9dfffd8be6c4ca20a30a2ce6e56312e4` | `previews/profile-league-lorelei-baseline-v4.png` |
| `assets/battle/arena_league-bruno.compact.png` | `baeefb472c79e3a8a087dfc0d915dcb20a8a15c97ae0baaaebcc005cb7f24da1` | `previews/profile-league-bruno-baseline-v2.png` |
| `assets/battle/arena_league-agatha.compact.png` | `b44510cb57e201b23bb13e18e6ba7a09be86d3120af9e105dfaa884af7da2a58` | `previews/profile-league-agatha-baseline-v2.png` |
| `assets/battle/arena_league-lance.compact.png` | `00816c8beb6c6a233eaead5736ba6703d88bf767bc3f5394e0bb4c2ea1368f3e` | `previews/profile-league-lance-baseline-v2.png` |
| `assets/battle/arena_league-champion.compact.png` | `3e7b6137f22f8444efbf7dea68e2ca3433385fc64686adf9ef2a6c9b3eb6ea3f` | `previews/profile-league-champion-baseline-v2.png` |
| `assets/battle/arena_mansion-cinnabar.compact.png` | `81f74e3196751592a59c10288fc5d03b5e32bb319038f54fb987ef29934251b3` | `previews/profile-mansion-cinnabar-baseline-v1.png` |
| `assets/battle/arena_moon-approach-route3.compact.png` | `aaf33f6ec0dc311fb021f1da0c1d4667086b8531dc77681c122ff0881c0f0912` | `previews/route3-mtmoon-v1.png` |
| `assets/battle/arena_moon-exit-route4.compact.png` | `3831b93ab2091faaae60f2fb0b748f190e8a061ea28a9e9d727de22ce92b8e7b` | `previews/profile-moon-exit-baseline-v2.png` |
| `assets/battle/arena_rock-water-route10.compact.png` | `04f7bf1c47804ace3abe96558a60e9c88d47e9698d49bb3832e4571356c82a71` | `previews/route10-canal-b1.png` |
| `assets/battle/arena_rocket-game-corner.compact.png` | `73da751f53c7f75028878419c88866e010e9b094fd7fa6c983a628b82e44b955` | `previews/profile-rocket-game-corner-baseline-v2.png` |
| `assets/battle/arena_rocket-hideout.compact.png` | `ca92c527c9a396c910e1050ea1aab866bb83964fa50d1f14365d70d19dd09128` | `previews/profile-rocket-hideout-baseline-v2.png` |
| `assets/battle/arena_route2-forest-gate.compact.png` | `00b932d766804d1b0c224fbddae852407a2149adbb6266ceaf8e22403cf2a17e` | `previews/route2-gate-c1.png` |
| `assets/battle/arena_safari-kanto.compact.png` | `7085268246a0c911cfc04e12f8a8ffb371e1a4f0371cb3aa499dfeab5c4dca13` | `previews/profile-safari-kanto-baseline-v1.png` |
| `assets/battle/arena_ship-cabins.compact.png` | `fff9b64e34bc644bc021c8ec71e0f7df568a6a5f843912bb8f8f2fe594081e1d` | `previews/profile-ship-cabins-baseline-v3.png` |
| `assets/battle/arena_ship-corridor.compact.png` | `0b3289d0ceb2840dec0bc1ffa897b8029a0e055c48ec02aef9a1fdf1aec118c5` | `previews/profile-ship-corridor-baseline-v2.png` |
| `assets/battle/arena_ship-bow.compact.png` | `5c98649c0c7688cc2e4c9d9ac1b77a4274c4d521e8c575ec4843bc94ae43e2d1` | `previews/profile-ship-bow-baseline-v2.png` |
| `assets/battle/arena_tower-lavender.compact.png` | `2ceca440f8841294fdf0d2e794db5d3b858c3e4062ffbd375d768d7f6f099388` | `previews/profile-tower-lavender-baseline-v2.png` |
| `assets/battle/arena_vermilion-gate-route11.compact.png` | `4ae449df419515b388a5794882c118f321bd3227de63cf00f2890d98e0719db6` | `previews/profile-vermilion-gate-route11-baseline-v1.png` |

Runtime-Vertrag: `data/arena_scenery.lua` deckt exakt dieselben 95 Karten
wie `data/battle_arenas.lua` und damit alle 111 Anker ab. Arena-Kämpfe nutzen
nur `3X` oder den darauf aufbauenden `STADIUM`-Regisseur; HUD-, Teamleisten-
und Frontsprite-Größen bleiben die unveränderten Spielwerte. Außenkulissen
werden mit exakt demselben `DayNight.tint` wie Overworld und Figuren getönt;
Innenräume bleiben neutral. Fehlende Datei, falsches Maß, falscher
Außen/Innen-Kontext oder ungültiger Anker lassen den Ort geschlossen auf den
normalen Kampf zurückfallen.

### Bereits vorhandene Runtime-Assets

Auch die bereits vor dem regionalen Panorama-/Höhlenpass vorhandenen PNGs der Release-Allowlist wurden gegen die aufbewahrten ImageGen-Master geprüft. Die Zuordnung basiert auf den eindeutigen Silhouetten beziehungsweise Streifenmotiven; Runtime- und Masterdateien sind jeweils zusätzlich per SHA-256 fixiert. Für diese ältere Gruppe ist der damalige vollständige Prompttext nicht in der Release-Dokumentation erhalten und wird deshalb nicht nachträglich erfunden.

| Runtime-Datei (SHA-256) | ImageGen-Master (SHA-256) |
|---|---|
| `forest_edge_a.compact.png` `528244b1a6f31771e4f15aae82288e6ac82e33b0e9a30325060f7509e896c170` | `exec-fd3e0a48-a53d-448f-8cda-71ccf79ead59.png` `b9b247b9f5ca77468e6c68c46a3c5c7998750d86ef461c72e8a9025b275956cf` |
| `forest_edge_b.compact.png` `2722660ad2d01a983e87c98b238416e09f94110826323b28d00d50b7aecb131a` | derselbe Forest-Master `exec-fd3e0a48-a53d-448f-8cda-71ccf79ead59.png` |
| `forest_edge_c.compact.png` `23b038cea0bb1e9283a05a1c93f60a252a49e164f97493f88949368503ebfd1f` | derselbe Forest-Master `exec-fd3e0a48-a53d-448f-8cda-71ccf79ead59.png` |
| `mini_trees.compact.png` `0dbfff089290e3580c242c671fa372875947720f90ec487c2a6f1580a76a69f9` | `exec-de44431a-b5e7-4eef-85eb-e25170566dd2.png` `f0136bfea8a26ad9fb104beec5177d335fefec49a4eabc467f6b76cb719c7f3c` |
| `metropolis.compact.png` `e5cf2ce6922abd201b74f6588eac1807b97e8eb3c4d50e9ec12206dc05ce64ad` | `exec-f36daff4-2672-4cf9-aec6-fb3e5c132b10.png` `dba2207c2a27bab19c4c9ddff6cd3e2a3a9ccabf0734bfb594d9b564abf98d6b` |
| `viridian_town.compact.png` `b9093fcc8d3cc5f4db0cc4c2686d9644e2c7954e293ede0261884d847dad28ac` | `exec-60b499f1-d459-47ce-8bf5-8126136c6df9.png` `b96d97b3c1b713a845f084e41b9a0a9905f130eb56d05d2b61ff8a25c98da924` |
| `clouds.png` `1beb43b423be81d5c88caa043a9085bd9147b78c0f41c7f0216cd1b79472b126` | `exec-b13170ed-1799-4eb6-a2de-df83b9f83975.png` `76644b4878204d9eabe07a2a531bb3d10c0c4722143f563c1d16341efc5e2b92` |
| `bird_flock.png` `78d884c6ed32d070ca4aa995156ae1c9bbb8d48f843a14fc56cdea40f6ec9e91` | `exec-7e49d149-1da3-4801-90d0-6bc7157e5528.png` `46f903100f26247863ca0f53fcdb578c7f3cf7204a6c211118d2c37d1f4d6bf8` |
| `hooh.png` `c1731c73ddb7b12aad64aadc42c008152c2bacc01d3521a73099f220f38fb718` | `exec-5aa6c671-0d99-4308-a495-20fb196ea639.png` `01cd6a2d9ae2231f516f1727245d76e900bab27683e1fdfc8ad249ea4f193309` |
| `articuno.png` `b98ba3a8a9f9cf090e35000890c4dbeb4be4a8507b0233474fad8210230aa751` | `exec-77bd5bf2-ac60-45a5-acd1-9206de5147cc.png` `088a614dc6e81087ea0d70ff07e2f0ba0f07706ba7e70479415e78878ae77ad5` |
| `farfetchd.png` `1090e2f411769ab92f50ee94196b7d703e69abe025a780727dc6bf7010c31b3a` | `exec-49862431-91e0-45ce-ac30-dea620e42789.png` `34f2edcf67fd1a711ef6e53bb70a1d65bdce0650429d39544a970b755841e765` |
| `moltres.png` `b518ce4d50b70cdd4a4a16247e5185358b5e481f950c22598f83500401d451c5` | `exec-03970f50-2663-4750-9dfa-08a6a06f2a62.png` `1b3187a66d6f77db07b4422650ccfec9fdb71671ed77e2e9795b3f35f195802c` |
| `murkrow_flock.png` `5bcca6a4293b86d5f4cf9fa5732b37780bcf98ce86b41e7bf20c54acf84f3eb6` | `exec-33aaf0ef-6ec0-48f5-aff1-e45ff3d574ae.png` `2a07987e210a4fae7181bd8046b8fa8b3de026b5f90143afbaa47c08b3136021` |
| `spearow_flock.png` `ee2b7df22a2ce0515742fa0d8b2e6074e82f1e57f0c9ffbed2154c1bc6660347` | `exec-1ce42a60-89c4-477a-8808-5bed0116e783.png` `d8fe5fe34eebcb1f5bb6ca7cbad6b10f2a22d1c518853bda3b7050b9e84360b8` |
| `zapdos.png` `ac1d5c6073a33ed5cb19f5853f7b02da1793c0cdad0165ec5b359c62ef55dcb1` | `exec-7c6bda66-5fc3-4d2d-8628-c5c6da1f1304.png` `fe89c850fe63c7504d03adc911dc8fd9d9aaaa6f0779bf53937d491ee2abc657` |
| `rainbow.png` `0d8cfec347900b5a53c3a3a6918b0a06750c59445d5910109c3ac281c469ab93` | `exec-acb82089-1333-42a5-8e11-c3cab4086880.png` `5919c6536177bdc0f3615e57d1f4afa90267a5b0c8e530cc886783af503cb652` |
| `fuji_panorama.compact.png` `49385baa2d9b498266e4b296e26b2057a33a0b056fd8928c62fe356d7a39e642` | derselbe Fuji-Master `exec-f7553aef-76db-4619-9a62-0142b21e316d.png` wie das neue Bergpanorama |

Die neutralen ImageGen-Source-IDs und vollständigen SHA-256-Werte dieser älteren Gruppe stehen in der obigen Tabelle; private Generator-Cachepfade sind keine portable Provenienz und werden nicht veröffentlicht.

### Status

Sämtliche 32 durch `scripts/build_release.py` ausgelieferten Runtime-PNGs besitzen damit einen konkreten Quell- und Runtime-Hashnachweis (31 ImageGen-Ableitungen sowie das ausdrücklich dokumentierte kanonische Forest-Gate-Spielderivat). Das beseitigt ausschließlich den Dokumentationsbruch zwischen Repo, Release-Archiv und HTML-Audit; es erhöht keinen visuellen Score. Die Nuggetbrücken-Arenenkulisse besitzt inzwischen ihren lokalen 3X/STADIUM-Nativebeleg; Route 8, Südmeer, Safari, die meisten Höhlen/Turmetagen, die Pokécenter-Raumhülle und alle noch nicht authorierten Arenenkulissen-Familien bleiben bis zu identischen nativen Aufnahmen sowie den Performance-Gates im Status **RETEST OFFEN** beziehungsweise **REJECT**.

Nicht verwendete alternative ImageGen-Ausgaben – etwa andere Regenbogen-, Zapdos- oder mechanische Vogelfassungen – sind weder in der Allowlist noch im Release-ZIP enthalten.
