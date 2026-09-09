# VASC – Quellen der neu erzeugten Panorama- und Materialassets

Stand: 26. August 2026. Dieses Dokument führt die während des aktuellen Panorama-/Höhlen- und privaten UI-Testpasses erzeugten Runtime-PNGs auf. Die großen ImageGen-Master und vollständigen Quellsheets werden nicht vom Mod geladen; ausgeliefert werden ausschließlich die geprüften Dateien unter `assets/`.

Die 92 vom Projekteigner ausdrücklich als VASC-Material bereitgestellten Kampfanimations-Sheets werden wegen ihres Umfangs separat und mit Einzelhashes in `ANIMATION_ASSET_SOURCES.md` geführt. Ihr deterministischer Import stammt aus `Data/PkmnAnimations.rxdata`; `Data/Animations.rxdata` enthält dagegen nur Karten-/Emote-Effekte und ist kein Kampfprogramm.

Die Panorama-/Materialmaster wurden mit dem eingebauten ImageGen-Werkzeug für dieses Projekt erzeugt. Die ausdrücklich als kanonisches Spielderivat ausgewiesene Forest-Gate-Datei wird dagegen ausschließlich aus dem hash-fixierten Gen1Recomp-OVERWORLD-Atlas rekonstruiert und enthält keine neu erzeugte Gestaltung. Quellnachweis und technische Gültigkeit bedeuten noch keine visuelle Freigabe: Der verbindliche Bild- und Performance-Status steht im Panorama-Audit.

## Quellenübersicht

| Runtime-Datei | SHA-256 | ImageGen-Master |
|---|---|---|
| `assets/ui/dp-bag-6961.png` | `2099935dcc119ceb0a39fb5306eb1988609b97ccf67b1dc04581ef9faa17dcb8` | 16 unveränderte 1:1-Pixelcrops aus TSR-Asset 6961, kein ImageGen |
| `assets/ui/frlg-oras-bag-3865.png` | `3aee666ab5d247da143f31725d678491d32109ca08e110c1e575f9dc31531d2d` | 10 unveränderte 1:1-Pixelcrops aus TSR-Asset 3865, kein ImageGen |
| `assets/ui/bag-pocket-icons.png` | `231505882226abcf600a00cd1fd9621e348ed3a48092744df52ec9e876b9f411` | 12 unveränderte 1:1-Pixelcrops aus TSR-Asset 6961, kein ImageGen und keine VASC-Neuzeichnung |
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

### FRLG-like Battle Disks (2026-08-24)

Visuelle Referenz ist die vom Projekteigner verlinkte Tafel **Battle
Backgrounds** aus Pokémon FireRed/LeafGreen, 737×466 PNG, hochgeladen von
desgardes:
`https://www.spriters-resource.com/game_boy_advance/pokemonfireredleafgreen/asset/3866/`.
Die Tafel wird nicht ausgeliefert und kein Pixel daraus wird in ein Runtime-
Asset kopiert. Sie diente nur als Referenz für die kleine GBA-Palette, klare
Pixelcluster, zurückhaltende Ringabstufung und gute Lesbarkeit unter einer
Kampffigur.

Gemeinsamer finaler Promptkern: ein eigenständiger quadratischer Master für
eine VASC-3D-Kampfplattform; genau eine mittige, echte Kreisfläche in direkter
Draufsicht, etwa 84 Prozent des Bildes, echter transparenter Hintergrund,
ruhige flache Standfläche in der Mitte, scharfe polierte 16-Bit-Handheld-
Pixelkunst, harte Pixelcluster und Nearest-Neighbor-Anmutung. Ausgeschlossen:
Perspektivellipse, Horizont, Raum-/Landschaftskulisse, zweite Plattform,
Figuren, Kreaturen, Schrift, Logos, UI, Pokéball-Symbole, Schachbrettmatte,
Verläufe, Blur, Antialiasing, Glow und Fotorealismus. Die Referenz durfte nur
die übergeordnete visuelle Grammatik liefern; exakte Formen und Pixel sollten
nicht übernommen werden.

Familienspezifische Promptteile:

- `building`: helle Stein-/Elfenbein-Fliesen, warmes Grau/Beige, kleine kühle
  Grau-Akzente; passend für Gebäude und Stadtinnenflächen.
- `grass`: leuchtendes kurzes Wiesengras in Frühlings-/Limettengrün mit
  wenigen Halmen und ruhiger Mitte; passend für normale Routen.
- `water`: ausschließlich klares cyanblaues Ozeanwasser mit sparsamen
  Wellenpixeln; keine Küste oder Landfläche.
- `cave`: warmer ockerfarbener Höhlenboden mit wenigen flachen kantigen
  Steinen, Tan/Olive/Umber; keine Wände, Knochen oder Kristalle.
- `pond`: flaches Türkiswasser, schmaler hellgrüner Naturrand und wenige
  helle Ripples; keine Pflanzen oder Fische in der Standmitte.
- `ice`: hellblaues Eis mit wenigen kantigen Frostrissen, Cyan-/Lavendelschatten
  und weißen Highlights; keine aufragenden Kristalle oder Schneeberge.
- `sand`: creme-goldener feiner Sand mit wenigen Kieseln und Pixel-Windspuren;
  keine Vegetation, Knochen oder Wasserfläche.
- `indoor`: gedämpfte Lavendel-/Magenta-Gym-Fliesen mit zurückhaltenden
  geometrischen Fugen und dunklem Pflaumenrand; keine Runen oder Symbole.
- `long_grass`: kühler Wald-/Hochgrasboden mit dichten Blättern und höheren
  Halmen nur am Rand, moosige freie Mitte; keine Blumen oder Pilze.
- `mountain`: kühles helles Graugestein mit wenigen flachen kantigen Platten
  und Mineralpixeln; keine Kristalle, Lava oder Vegetation.

Die finalen ImageGen-Master liegen in
`tools/sources/battle_disks/*_frlg_like_v1.imagegen.png`:

| Familie | ImageGen-ID | Master-SHA-256 |
|---|---|---|
| building | `exec-30c7a097-b969-43eb-99a4-7d31069deeb0` | `94ab514344e1f9fcf9bfc94d0b28cfdc3aa332ea3b5c974a3a907896ac80e957` |
| grass | `exec-53188f88-78da-4d8a-9728-81d2ecc6f09a` | `cc7d33cfefe4dbeaba8f30f383bc12bf92088ba6f10cf5ef71acf79864a6853c` |
| water | `exec-6e9a1588-541e-4898-97ab-dd0043e560e7` | `b83eb23e1351a6f27018b26fa52ded3b92c2ba99a699ddc863b90601a8a37ad5` |
| cave | `exec-d2d73a96-8240-4263-83ee-c0c266b72de8` | `4b561cd549805826f38fb3a983953b13609f3209d430bf7caf6a848d7ebb6638` |
| pond | `exec-109000ad-c71f-4622-bccf-42b9e7bc939d` | `b821ba1a1a900eebc94290037392046f91871fefa818ddab9233bdc4465e214d` |
| ice | `exec-01299631-666e-49e2-92c2-ec05ab941df6` | `9fafc25481a6d8e93ce42ff78eac61d86ea9e050146032937ae9c8f2e9cb0928` |
| sand | `exec-5542a324-075d-4b3a-84d8-a0908a05921b` | `94d9c8a0c38d8533354279bd5d322a21fb2c813f1b39868cdc8f96bf9a5dee94` |
| indoor | `exec-ad360961-2aa0-457c-bd31-95883170ff78` | `6212fd0dfaf34349b9983a4cf6639bd8f0ec2947ee748c8e99d1a22889d06980` |
| long_grass | `exec-c408e757-efe8-44f6-a39a-81f0bee6260c` | `092358ea833cf72f4f6bcd2f5f2745877d574c4fd6a5de66a8ef34524b4680ad` |
| mountain | `exec-41b2a8ae-7e2e-4188-8054-b3c75e8aa42e` | `ec1b33c55bdd2b5da8f7d2c223403d3d4bbe3823915fb06c41a1f26e09563def` |

`tools/build_frlg_battle_disks.py` pinnt alle Masterhashes und das exakte
1254×1254-RGBA-Maß, beschneidet die sichtbare Alpha-Silhouette, passt sie
zentriert in höchstens 118×118 Texel ein, skaliert ausschließlich mit
Nearest-Neighbor, quantisiert sichtbare Farben ohne Dithering auf höchstens 64
und setzt Alpha strikt auf 0/255. Das Zentrum muss opak, jede Ecke transparent
und jedes Runtime-Asset exakt 128×128 RGBA sein.

| Runtime | SHA-256 |
|---|---|
| `assets/battle_disks/disk_building-frlg.compact.png` | `ce7ff386a3dd31a2abfaf3e015ef8240223e3c16880f34012f85fcc4e02870b1` |
| `assets/battle_disks/disk_grass-frlg.compact.png` | `4e5eecd659c452f6d89859d1c84ee9a4c7ed7468ce5c05a8476abd6cbf25ad8b` |
| `assets/battle_disks/disk_water-frlg.compact.png` | `a422b268570e2ae725f443236ace402c178090b0f5af94bd4450a4ec9911e29d` |
| `assets/battle_disks/disk_cave-frlg.compact.png` | `0d351e901e71c2a65b29961d58d52a76e051e1acfd7aa87a77f0b880f333baf8` |
| `assets/battle_disks/disk_pond-frlg.compact.png` | `ad74e54b595e2ad4232d65bee494bcd529a35ff27f4cd77c287349d6bfdce02d` |
| `assets/battle_disks/disk_ice-frlg.compact.png` | `61b67d359a5f899b2a6125656d18243914e752b18a5407448433bdf3a2637c96` |
| `assets/battle_disks/disk_sand-frlg.compact.png` | `d18f41d9bf27566d57f0743a50ce67222c88d75dfbc88a960121a354ba1efdbe` |
| `assets/battle_disks/disk_indoor-frlg.compact.png` | `08ff5f68825e8dd201bc4b453954706fd9156d689d285f289fa84614ad6643f4` |
| `assets/battle_disks/disk_long-grass-frlg.compact.png` | `da9cf1fd76cbd424b3ea4572db277df523373a50fa7353a99f966b1f29c4e722` |
| `assets/battle_disks/disk_mountain-frlg.compact.png` | `2414b8ba83aacc2b5fd816e109e1643ddd38d2c46f37837598b01ced7a977eb1` |

Runtime-Zuordnung liegt in `data/battle_disks.lua`: Der vorhandene
`BattleArenaStyle` liefert die Kartenfamilie, exakte Receipts schärfen
Seeschauminseln auf Eis, Siegesstraße/Bruno auf Berg und Lorelei auf Eis.
KASC-Erweiterungsprofile ohne freigegebene FRLG-Zuordnung fallen auch in
`FRLG` geschlossen auf die neutrale VASC-Disk zurück. `V+FRLG` lost nur
zwischen VASC und dem bereits passenden FRLG-Asset; die Terrainfamilie selbst
wird nie zufällig gewählt und bleibt für den gesamten Kampf gelatcht.

Zu jeder freigegebenen Familie steht außerdem ein sehr heller RGB-Wert in
`data/battle_disks.lua`. Der Renderer verwendet ihn als weißbasierte,
materialbezogene Hintergrundtönung (Grün für Gras, Cyan für Wasser/Eis,
Ocker für Sand/Höhle, Lavendel für Indoor usw.). Dafür existiert ausdrücklich
**kein** vollflächiges Bitmap-Asset und kein weiterer ImageGen-Master. Im
VASC-Zweig sowie bei nicht unterstützten Karten liefert dieselbe strikte
Zuordnung keinen Farbwert; damit bleiben der bisherige Live-Himmel bzw. der
Innenraum-Void unverändert. `ARENA BG` und seine großen ortsspezifischen
Gemälde sind von diesem prozeduralen DISCS-Hintergrund vollständig getrennt.

## Arenenkulissen – vollständige 111-Anker-Auswahl

### FRLG-Area-Preview-Pass (2026-08-23)

Visuelle Ortsreferenz ist die vom Projekteigner verlinkte Tafel **Area
Previews** aus Pokémon FireRed/LeafGreen, 738×1176 PNG, hochgeladen von
FrenchOrange:
`https://www.spriters-resource.com/game_boy_advance/pokemonfireredleafgreen/asset/3859/`.
Die Tafel wird nicht ausgeliefert. Sie diente ImageGen ausschließlich als
Stil-, Farb- und Ortsreferenz; alle Runtime-Hintergründe sind neue Bilder ohne
Figuren, Pokémon, Schrift, Logos oder UI.

Gemeinsamer Promptkern: breite 16:10-Kampfszene, polierte GBA-Pixelkunst mit
klaren Pixelclustern und begrenzter FireRed/LeafGreen-ähnlicher Palette,
natürliche Standflächen bei 43%/66% und 56%/61%, ruhige untere 32% für das
unveränderte HUD, keine Kampfkreise oder Plattformen. Für Höhlen und Gebäude
wurde das Preview nur auf Material- und Farbidentität bezogen und ausdrücklich
ein geschlossener Innenraum verlangt; ein gezeigter Außeneingang durfte nicht
zum falschen Kampfkontext werden. Nur `VIRIDIAN_FOREST` und die Safari-Profile
fordern eine obere, randverbundene Transparenzöffnung. Beide enthalten weder
gemalten Himmel noch Sonne, Mond, Sterne oder Wolken; VASC liefert diese aus
dem bereits vorhandenen Live-Himmel und tönt Kulisse, Kämpfer und Wetter mit
demselben kontinuierlichen `DayNight.tint`. Vertania-Wald bleibt dabei ein
Canopy-Profil ohne offene Himmelskörper. Alle elf Innenprofile sind vollständig
opak und erhalten keine Tageszeit. Die bereits geprüften Mansion-Fenstermasken
bleiben als einzige Ausnahme aktiv und färben nur die zwei physischen Scheiben.

Die 13 finalen ImageGen-Master liegen in
`tools/sources/arena_scenery/*_frlg_v1.imagegen.png`. Ihre ImageGen-IDs und
SHA-256 sind:

| Profil | ImageGen-ID | Master-SHA-256 |
|---|---|---|
| Vertania-Wald | `exec-e4332f5f-9a45-47c7-97a5-c883515ecf2a` | `b9e5afa2d9cba8500ce91695b10bdb524bec76bebf07d408bc2631ac9041c659` |
| Safari-Zone | `exec-a604ee3c-aa99-46b9-9c38-886ca012ff7f` | `757588672c002ca427ad3ad690a2dd5e06d55812cd69834414b55c8e313fdb73` |
| Mondberg | `exec-887ae974-0356-4124-af36-6b2dd6355e4b` | `6a9bff6e43242f390d05f92cef829864fcdca36fdcff95f246cac19cfddc197e` |
| Digda-Höhle | `exec-2fa1685a-1c95-429a-b24b-b2a7d4e23841` | `3b2699b93d279c280427563988a144ef7f97c97dd2c99cae3d407418af53a88d` |
| Felstunnel | `exec-4e3d61de-6e00-4c7a-8ee9-cbf9f1f412bb` | `eddf5b32f09836cd65f85efee6060124f7967f26f72e35fb029f66ba9ae0a846` |
| Pokémon-Turm | `exec-77e2cf65-450c-406f-9867-f9ccd8f1b8f8` | `04cd300994c4a5bceaedafc3f616cdf34766755d38aee44c3d60da51aa2628d9` |
| Kraftwerk | `exec-7af0071c-6f1d-40b0-9ac3-8907e541e9c0` | `af0f27b120f0bf14ccc003a15a29e363767e892b2a651fe805c26c17f3a01b87` |
| Rocket-Versteck | `exec-063fe48a-3a5e-4679-b6b4-b7325c44a682` | `794754d0c8a5af3503b6610aa8d3be52c47cd763285f04d2ed926bc006508e66` |
| Silph Co. | `exec-83ad5af4-5eb0-4aff-b0e7-b8810b6b8f78` | `549a38a432fd4951ff20d6fbb152ee91bc14a704181be42d374f6378a9c6e1c6` |
| Seeschauminseln | `exec-6ea6d27c-5487-4346-992b-258e42deb59c` | `9da5b92cf868c4b305cfd06551b227e3ded08a0421148c1f496a04a27376ebca` |
| Pokémon-Haus | `exec-c54b0e3f-4a08-4106-b815-37f33410b21d` | `044b8c75cc8d8b0d1f6098090d7b288c64010166c198a799e6dd2d3e7ee79345` |
| Siegesstraße | `exec-7df4c44c-fb09-4839-9c65-357d415d3b5a` | `c3a788c1f60074b64a02ab1c42cbf4514ca4daf7704dde3a6e21db47e371d27e` |
| Azuria-Höhle | `exec-c252082e-7607-4d48-811b-342a0af62fde` | `7aa1bd3de3e22129ae4d7d29bdeec477b42b4ff1ddcdda2d55995814e05bad16` |

`tools/build_frlg_arena_scenery.py` pinnt alle Masterhashes und -maße,
entfernt nur bei den zwei Außenprofilen die helle randverbundene
Vorschau-Matte und skaliert per Nearest-Neighbor deterministisch auf
1280×800 RGBA. Der Build verweigert transparente Standflächen, offene
Unterkanten oder Alpha in einem Innenraum.

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
| `assets/battle/arena_cave-cerulean.compact.png` | `69fe69ab74f5d291fdec9c1966899087358b8eb4a07da5bf511a06df4c84b5ce` | `cave_cerulean_baseline_v1.imagegen.png` |
| `assets/battle/arena_cave-diglett.compact.png` | `a568da9855e38e22e35aac14a31864b78765ddbf36ac6c2d5ebb82b404f6b027` | `cave_diglett_baseline_v1.imagegen.png` |
| `assets/battle/arena_cave-mt-moon.compact.png` | `7217da25e804c321de02e398e1528143cf311f71bd28f244c026b91a8c102e8c` | `cave_mt_moon_baseline_v1.imagegen.png` |
| `assets/battle/arena_cave-rock-tunnel.compact.png` | `cd6b8d6767f57924039bc98ae71c89d8d43700cf5bd4b1b0e2fcd1a14f327ddf` | `cave_rock_tunnel_baseline_v1.imagegen.png` |
| `assets/battle/arena_cave-seafoam.compact.png` | `1fd37693394cf14c1f1ffb28fc34bca462c75f2edfb1dd1a1e189642732b3b42` | `cave_seafoam_baseline_v1.imagegen.png` |
| `assets/battle/arena_cave-victory-road.compact.png` | `c6b7b38cb7793df7019dbef62442d69b896397f42b2c88b1cc2ad533b85177eb` | `cave_victory_road_baseline_v1.imagegen.png` |
| `assets/battle/arena_forest-viridian.compact.png` | `5f2141d3f5e499aca586ffc36a73e30ef74684ec8501a6af023128e8ba463e6e` | `forest_viridian_baseline_v2.imagegen.png` |
| `assets/battle/arena_industrial-power-plant.compact.png` | `8cc53b683232903fc24dea8abbd2800dfbe77df6972bd7354ecc232dc834755d` | `industrial_power_plant_baseline_v2.imagegen.png` |
| `assets/battle/arena_industrial-silph.compact.png` | `af9670e6c595ccc241f5d91736dd772c5abd07009f92fec0747e6c786ba2c241` | `industrial_silph_baseline_v3.imagegen.png` |
| `assets/battle/arena_mansion-cinnabar.compact.png` | `81f74e3196751592a59c10288fc5d03b5e32bb319038f54fb987ef29934251b3` | `mansion_cinnabar_baseline_v1.imagegen.png` |
| `assets/battle/arena_rocket-hideout.compact.png` | `ca92c527c9a396c910e1050ea1aab866bb83964fa50d1f14365d70d19dd09128` | `rocket_hideout_baseline_v2.imagegen.png` |
| `assets/battle/arena_safari-kanto.compact.png` | `7085268246a0c911cfc04e12f8a8ffb371e1a4f0371cb3aa499dfeab5c4dca13` | `retained reviewed VASC master` |
| `assets/battle/arena_tower-lavender.compact.png` | `2ceca440f8841294fdf0d2e794db5d3b858c3e4062ffbd375d768d7f6f099388` | `tower_lavender_baseline_v2.imagegen.png` |
| `assets/battle/arena_cape-route25.compact.png` | `444da9c117ac0a25e953cf07fb12c69a8f4488cedd71cd1aa776d2af1575a1cd` | `previews/route25-cape-v1.png` |
| `assets/battle/arena_cave-cerulean-frlg.compact.png` | `31f672b31d91076e51e8a6bf093fe5d3ee9ba037c1fb4b56324bcc96c2d8a8c9` | `cave_cerulean_frlg_v1.imagegen.png` |
| `assets/battle/arena_cave-diglett-frlg.compact.png` | `7fed73be7ffa7eb88402b62087d84b05974aca67383bf6a2e4becd76107fe19b` | `cave_diglett_frlg_v1.imagegen.png` |
| `assets/battle/arena_cave-mt-moon-frlg.compact.png` | `ddd274a5f2b517a766997275845130f099defec1fda38b7760c98d66767eb300` | `cave_mt_moon_frlg_v1.imagegen.png` |
| `assets/battle/arena_cave-rock-tunnel-frlg.compact.png` | `e8523cb76507e3e2aac4998d765ebb186b6a98af8427555021cdeb2da7b848e1` | `cave_rock_tunnel_frlg_v1.imagegen.png` |
| `assets/battle/arena_cave-seafoam-frlg.compact.png` | `fc3946288f390c97a50cf6ca5f4d93c4148c95185e12f8aa034378702d3b68d4` | `cave_seafoam_frlg_v1.imagegen.png` |
| `assets/battle/arena_cave-victory-road-frlg.compact.png` | `ad6a35943fbfa8f086a394a16d7a29c52c6b377b2cf3d14a91932b251d74aced` | `cave_victory_road_frlg_v1.imagegen.png` |
| `assets/battle/arena_cerulean-canal.compact.png` | `bb9243b38c1ed0e146abd7afa3dd0c3ebc3c57bff1d31dc060a5ac0893175d99` | `previews/cerulean-rival-c1.png` |
| `assets/battle/arena_coast-cinnabar.compact.png` | `c9e7faf6663a9a7592c70f719514b1c47b56ce597549bfe6e5dc9591fb2e0ba4` | `previews/profile-coast-cinnabar-baseline-v1.png` |
| `assets/battle/arena_coast-surf.compact.png` | `1b641515d1c7bd34e31027f2d6917d7460052ded9749a0907c5b9ff44c612d6f` | `previews/profile-coast-surf-baseline-v2.png` |
| `assets/battle/arena_forest-viridian-frlg.compact.png` | `2dc735e61c43c6ca6df9f21612910e91aa84958f16fc1a3ca7f5101426ea4d78` | `forest_viridian_frlg_v1.imagegen.png` |
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
| `assets/battle/arena_industrial-power-plant-frlg.compact.png` | `cf54a668a1ae8486d3404891eb9b82d0a25820dac3a04aa79296886693ae9ba5` | `industrial_power_plant_frlg_v1.imagegen.png` |
| `assets/battle/arena_industrial-silph-frlg.compact.png` | `91c9c85c2a48a62f02a413022112536a279fd923b52fd594ed1f6d4e9b2dbec4` | `industrial_silph_frlg_v1.imagegen.png` |
| `assets/battle/arena_interior-oaks-lab.compact.png` | `169f6b12dde7493c8d446192a34981e311396d6582ff586eac58dc65785e8443` | `previews/profile-interior-oaks-lab-baseline-v3.png` |
| `assets/battle/arena_league-lorelei.compact.png` | `b49c0c5ac487ac00d9a5a060718047fc9dfffd8be6c4ca20a30a2ce6e56312e4` | `previews/profile-league-lorelei-baseline-v4.png` |
| `assets/battle/arena_league-bruno.compact.png` | `baeefb472c79e3a8a087dfc0d915dcb20a8a15c97ae0baaaebcc005cb7f24da1` | `previews/profile-league-bruno-baseline-v2.png` |
| `assets/battle/arena_league-agatha.compact.png` | `b44510cb57e201b23bb13e18e6ba7a09be86d3120af9e105dfaa884af7da2a58` | `previews/profile-league-agatha-baseline-v2.png` |
| `assets/battle/arena_league-lance.compact.png` | `00816c8beb6c6a233eaead5736ba6703d88bf767bc3f5394e0bb4c2ea1368f3e` | `previews/profile-league-lance-baseline-v2.png` |
| `assets/battle/arena_league-champion.compact.png` | `3e7b6137f22f8444efbf7dea68e2ca3433385fc64686adf9ef2a6c9b3eb6ea3f` | `previews/profile-league-champion-baseline-v2.png` |
| `assets/battle/arena_mansion-cinnabar-frlg.compact.png` | `95e01126edf9f51d92d56aadef67e1e3fcc6e89a9b983f5c38334dee39c9f1f7` | `mansion_cinnabar_frlg_v1.imagegen.png` |
| `assets/battle/arena_moon-approach-route3.compact.png` | `aaf33f6ec0dc311fb021f1da0c1d4667086b8531dc77681c122ff0881c0f0912` | `previews/route3-mtmoon-v1.png` |
| `assets/battle/arena_moon-exit-route4.compact.png` | `3831b93ab2091faaae60f2fb0b748f190e8a061ea28a9e9d727de22ce92b8e7b` | `previews/profile-moon-exit-baseline-v2.png` |
| `assets/battle/arena_rock-water-route10.compact.png` | `04f7bf1c47804ace3abe96558a60e9c88d47e9698d49bb3832e4571356c82a71` | `previews/route10-canal-b1.png` |
| `assets/battle/arena_rocket-game-corner.compact.png` | `73da751f53c7f75028878419c88866e010e9b094fd7fa6c983a628b82e44b955` | `previews/profile-rocket-game-corner-baseline-v2.png` |
| `assets/battle/arena_rocket-hideout-frlg.compact.png` | `8e246ca2d61ec8880a1f3cf4b750efbf1b8c3acb67105c64bbee90997f051893` | `rocket_hideout_frlg_v1.imagegen.png` |
| `assets/battle/arena_route2-forest-gate.compact.png` | `00b932d766804d1b0c224fbddae852407a2149adbb6266ceaf8e22403cf2a17e` | `previews/route2-gate-c1.png` |
| `assets/battle/arena_safari-kanto-frlg.compact.png` | `1a5e2f528e1538bbe643eca67c700ea5af71b317c6d20f23b8d2d767d7bcb80e` | `safari_kanto_frlg_v1.imagegen.png` |
| `assets/battle/arena_ship-cabins.compact.png` | `fff9b64e34bc644bc021c8ec71e0f7df568a6a5f843912bb8f8f2fe594081e1d` | `previews/profile-ship-cabins-baseline-v3.png` |
| `assets/battle/arena_ship-corridor.compact.png` | `0b3289d0ceb2840dec0bc1ffa897b8029a0e055c48ec02aef9a1fdf1aec118c5` | `previews/profile-ship-corridor-baseline-v2.png` |
| `assets/battle/arena_ship-bow.compact.png` | `5c98649c0c7688cc2e4c9d9ac1b77a4274c4d521e8c575ec4843bc94ae43e2d1` | `previews/profile-ship-bow-baseline-v2.png` |
| `assets/battle/arena_tower-lavender-frlg.compact.png` | `d1b713b482093c4d89cba9f8d82a69e599fb20233a52e4f507508fb538b0862e` | `tower_lavender_frlg_v1.imagegen.png` |
| `assets/battle/arena_vermilion-gate-route11.compact.png` | `4ae449df419515b388a5794882c118f321bd3227de63cf00f2890d98e0719db6` | `previews/profile-vermilion-gate-route11-baseline-v1.png` |

## FRLG-like Kampfplattformen für DISCS

Die zehn optionalen FRLG-like Plattformmotive wurden mit dem eingebauten
ImageGen-Werkzeug für VASC erzeugt. Die vollständigen 1254×1254-RGBA-Master
bleiben unter `tools/sources/battle_disks/` im Projekt und werden nicht in das
Release-ZIP aufgenommen. `tools/build_frlg_battle_disks.py` pinnt jeden
Masterhash, beschneidet nur die Alpha-Silhouette, skaliert proportional per
Nearest-Neighbor, quantisiert ohne Dithering auf höchstens 64 Farben und
erzeugt reproduzierbare 128×128-RGBA-Runtime-Dateien mit binärem Alpha. Der
ursprüngliche vollständige Prompttext ist nicht separat überliefert und wird
deshalb nicht nachträglich erfunden.

| Runtime-Datei | Runtime-SHA-256 | ImageGen-Master | Master-SHA-256 |
|---|---|---|---|
| `assets/battle_disks/disk_building-frlg.compact.png` | `ce7ff386a3dd31a2abfaf3e015ef8240223e3c16880f34012f85fcc4e02870b1` | `building_frlg_like_v1.imagegen.png` | `94ab514344e1f9fcf9bfc94d0b28cfdc3aa332ea3b5c974a3a907896ac80e957` |
| `assets/battle_disks/disk_cave-frlg.compact.png` | `0d351e901e71c2a65b29961d58d52a76e051e1acfd7aa87a77f0b880f333baf8` | `cave_frlg_like_v1.imagegen.png` | `4b561cd549805826f38fb3a983953b13609f3209d430bf7caf6a848d7ebb6638` |
| `assets/battle_disks/disk_grass-frlg.compact.png` | `4e5eecd659c452f6d89859d1c84ee9a4c7ed7468ce5c05a8476abd6cbf25ad8b` | `grass_frlg_like_v1.imagegen.png` | `cc7d33cfefe4dbeaba8f30f383bc12bf92088ba6f10cf5ef71acf79864a6853c` |
| `assets/battle_disks/disk_ice-frlg.compact.png` | `61b67d359a5f899b2a6125656d18243914e752b18a5407448433bdf3a2637c96` | `ice_frlg_like_v1.imagegen.png` | `9fafc25481a6d8e93ce42ff78eac61d86ea9e050146032937ae9c8f2e9cb0928` |
| `assets/battle_disks/disk_indoor-frlg.compact.png` | `08ff5f68825e8dd201bc4b453954706fd9156d689d285f289fa84614ad6643f4` | `indoor_frlg_like_v1.imagegen.png` | `6212fd0dfaf34349b9983a4cf6639bd8f0ec2947ee748c8e99d1a22889d06980` |
| `assets/battle_disks/disk_long-grass-frlg.compact.png` | `da9cf1fd76cbd424b3ea4572db277df523373a50fa7353a99f966b1f29c4e722` | `long_grass_frlg_like_v1.imagegen.png` | `092358ea833cf72f4f6bcd2f5f2745877d574c4fd6a5de66a8ef34524b4680ad` |
| `assets/battle_disks/disk_mountain-frlg.compact.png` | `2414b8ba83aacc2b5fd816e109e1643ddd38d2c46f37837598b01ced7a977eb1` | `mountain_frlg_like_v1.imagegen.png` | `ec1b33c55bdd2b5da8f7d2c223403d3d4bbe3823915fb06c41a1f26e09563def` |
| `assets/battle_disks/disk_pond-frlg.compact.png` | `ad74e54b595e2ad4232d65bee494bcd529a35ff27f4cd77c287349d6bfdce02d` | `pond_frlg_like_v1.imagegen.png` | `b821ba1a1a900eebc94290037392046f91871fefa818ddab9233bdc4465e214d` |
| `assets/battle_disks/disk_sand-frlg.compact.png` | `d18f41d9bf27566d57f0743a50ce67222c88d75dfbc88a960121a354ba1efdbe` | `sand_frlg_like_v1.imagegen.png` | `94d9c8a0c38d8533354279bd5d322a21fb2c813f1b39868cdc8f96bf9a5dee94` |
| `assets/battle_disks/disk_water-frlg.compact.png` | `a422b268570e2ae725f443236ace402c178090b0f5af94bd4450a4ec9911e29d` | `water_frlg_like_v1.imagegen.png` | `b83eb23e1351a6f27018b26fa52ded3b92c2ba99a699ddc863b90601a8a37ad5` |

Runtime-Vertrag: `data/arena_scenery.lua` deckt exakt dieselben 95 Karten
wie `data/battle_arenas.lua` und damit alle 111 Anker ab. Arena-Kämpfe nutzen
nur `3X` oder den darauf aufbauenden `STADIUM`-Regisseur; HUD-, Teamleisten-
und Frontsprite-Größen bleiben die unveränderten Spielwerte. Außenkulissen
werden mit exakt demselben `DayNight.tint` wie Overworld und Figuren getönt;
Innenräume bleiben neutral. Fehlende Datei, falsches Maß, falscher
Außen/Innen-Kontext oder ungültiger Anker lassen den Ort geschlossen auf den
normalen Kampf zurückfallen.

### Glatter statischer Regenbogen (2.0.6)

Der neue Himmelsbogen wurde mit dem eingebauten ImageGen aus dem bestehenden
Regenbogenmotiv freigestellt und anschließend verlustarm auf die feste
Runtime-Größe 1024×512 skaliert. Der vollständige RGBA-Master bleibt unter
`tools/sources/sky/rainbow_smooth_v1.imagegen.png` erhalten; die Runtime lädt
`assets/sky/rainbow_smooth.png` mit linearer Filterung und ohne Mipmaps.

Finaler ImageGen-Prompt:

> Use case: background-extraction. Asset type: transparent game sky billboard.
> Primary request: remove the entire white/light-gray checkerboard background
> and the white bottom strip. Return only the smooth rainbow arch on genuine
> fully transparent alpha. Preserve exactly: the rainbow's smooth round
> semicircular geometry, symmetric position, six colored bands, soft
> antialiased edges, and gentle colored glow. Constraints: genuinely
> transparent RGBA background everywhere outside the rainbow; no checkerboard
> pixels, no white backdrop, no ground line, no shadow outside the colored
> arch, no added objects, no text, no watermark. Keep both rainbow legs
> complete and aligned to the same baseline.

| Datei | SHA-256 |
|---|---|
| `tools/sources/sky/rainbow_smooth_v1.imagegen.png` | `c3e6169463bcc86b9473588962348de8ac261b345815c4c374392b760e04394a` |
| `assets/sky/rainbow_smooth.png` | `2bae95b685101b0a976a9a8afd4906e6a4bd95cbc75f46f0836afd90a408cb1c` |

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

Für Lugias Wetterüberflug wird ausdrücklich nicht der frühere weiße
KASC-Fallback `assets/lugia_front.png` verwendet. VASC enthält stattdessen die
vollständigen 14 normalen Frontframes aus Kanto Ascendants Crystal-Animation
für Dex 249. Jede Runtime-Datei unter `assets/sky/lugia_crystal/` ist eine
bytegleiche Kopie der gleichnamigen Quelle unter
`gen1recomp/mods/000_kanto_ascendant_phase8qa/assets/crystal_animated/front/normal/249/`.
Der Renderer übernimmt außerdem KASCs vollständige Zeitfolge
`380,160,160,210,210,210,160,350,150,150,150,300,150,1000` Millisekunden
und loopt sie nach exakt 3740 ms. Es wird weder KASC-Code eingebettet noch eine
harte KASC-Abhängigkeit eingeführt.

| Crystal-Frame | SHA-256 (Quelle = Runtime) |
|---|---|
| `001.png` | `0950be73880d6f1edacc1b551cd651da7ac96b7f12ca4029a040685a8ac363d6` |
| `002.png` | `3b436920356ebf8411a7e1227280016eb385d7308948ec6437f406739a3de08a` |
| `003.png` | `a5d2df66b4a9e8797e2e0c08c26f6de15d7fbd0ccfb547b1017f11a7542564c7` |
| `004.png` | `de5407d1b7ad75f3456b8f03370c100a2b8dcf641b84971002a511df0542ccc3` |
| `005.png` | `9f9b4fc78cea4d2475c414b3925c97f732e729f542cc697cdf4ecdfe2bb4db47` |
| `006.png` | `76cdbf35c6d7f834eef297c7738c1cd5d5d235498067c691d91e08209ec88f64` |
| `007.png` | `e1295aa29ff924e8e4d7fedd350a693dde5322f1e0bf7217941a3400397a5fd1` |
| `008.png` | `0950be73880d6f1edacc1b551cd651da7ac96b7f12ca4029a040685a8ac363d6` |
| `009.png` | `28d534b895caa2070d2984faf9ea7599fd661b0f5233aa5622f52f9bc907196a` |
| `010.png` | `0950be73880d6f1edacc1b551cd651da7ac96b7f12ca4029a040685a8ac363d6` |
| `011.png` | `28d534b895caa2070d2984faf9ea7599fd661b0f5233aa5622f52f9bc907196a` |
| `012.png` | `0950be73880d6f1edacc1b551cd651da7ac96b7f12ca4029a040685a8ac363d6` |
| `013.png` | `c74af5ea5955d16849c48a332cc05c2f29929bea66d43fe982b288d74bc57a80` |
| `014.png` | `de5407d1b7ad75f3456b8f03370c100a2b8dcf641b84971002a511df0542ccc3` |

Die neutralen ImageGen-Source-IDs und vollständigen SHA-256-Werte dieser älteren Gruppe stehen in der obigen Tabelle; private Generator-Cachepfade sind keine portable Provenienz und werden nicht veröffentlicht.

### Status

Sämtliche durch `scripts/build_release.py` ausgelieferten Runtime-PNGs besitzen damit einen konkreten Quell- und Runtime-Hashnachweis. Das beseitigt ausschließlich den Dokumentationsbruch zwischen Repo, Release-Archiv und HTML-Audit; es erhöht keinen visuellen Score. Die Nuggetbrücken-Arenenkulisse besitzt inzwischen ihren lokalen 3X/STADIUM-Nativebeleg; Route 8, Südmeer, Safari, die meisten Höhlen/Turmetagen, die Pokécenter-Raumhülle und alle noch nicht authorierten Arenenkulissen-Familien bleiben bis zu identischen nativen Aufnahmen sowie den Performance-Gates im Status **RETEST OFFEN** beziehungsweise **REJECT**.

Nicht verwendete alternative ImageGen-Ausgaben – etwa andere Regenbogen-, Zapdos- oder mechanische Vogelfassungen – sind weder in der Allowlist noch im Release-ZIP enthalten.

### ModKit-Near-Duplicate-Ausnahmen

ModKits grober 8×8-Wahrnehmungshash kann sehr kleine, fast leere Hilfsbilder
mit beliebigen importierten Cachebildern verwechseln. Die vier folgenden
Dateien sind keine Kopien aus `assets/generated/`: drei sind bytegleich aus
dem eingefrorenen VASC4J-Quellcommit
`d0b73c16a5424aa995fe209985bf5f25423cc7c3` übernommen und als einfache
VASC-eigene Platzhalter visuell geprüft; `mini_trees` besitzt zusätzlich den
oben dokumentierten ImageGen-Master. `.modkitromallow` erlaubt ausschließlich
diese exakten Pfade für den Near-Duplicate-Test. Byteidentität, reservierte
Cachepfade und sämtliche übrigen ModKit-Regeln bleiben unvermindert aktiv.

| Runtime-Datei | SHA-256 | Unabhängige Herkunft/Funktion |
|---|---|---|
| `assets/fallback/pokemon_missing.png` | `eb827ca2c49ff04d43160f4cf2832674ab9d47692812a9b5a527d92491cb8e94` | Originales 16×16-VASC-Fragezeichen für einen fehlenden Spriteprovider; bytegleich im eingefrorenen VASC4J-Commit. |
| `assets/runtime/dynamic_billboard_base.png` | `232c2eac760eae604f9dd43352c0b272396b7cfaf220081b54583b6d0cbc2320` | Transparenter 16×16-Allokationsseed ohne Spielgrafik; bytegleich im eingefrorenen VASC4J-Commit. |
| `assets/scenery/mini_trees.compact.png` | `0dbfff089290e3580c242c671fa372875947720f90ec487c2a6f1580a76a69f9` | Originaler ImageGen-Atlas; Master `exec-de44431a-b5e7-4eef-85eb-e25170566dd2.png` und dessen Hash stehen in der obigen Bestandstabelle. |
| `assets/spawn_placeholder.png` | `2ce010940ff21b3201424eaaf4ad3acb11ca181e4236ae9ed1b9db966252e274` | Originaler 16×16-VASC-Registrierungsmarker (grüner Rahmen); bytegleich im eingefrorenen VASC4J-Commit. |

## Diamond/Pearl-Taschenatlas (privater UI-Kandidat)

- Quelle: The Spriters Resource, **Bag**, Pokémon Diamond/Pearl, Asset 6961,
  hochgeladen von Cheese:
  `https://www.spriters-resource.com/ds_dsi/pokemondiamondpearl/asset/6961/`.
  Das nicht ausgelieferte Original ist ein 743×442-RGB-PNG mit 38.584 Byte
  und SHA-256
  `654a94fc97dddcc32d9add16c95abc2ffe71a13c58d0642984804a3037afe2f9`.
- Runtime: `assets/ui/dp-bag-6961.png`, 576×128 RGBA, 7.975 Byte,
  SHA-256
  `2099935dcc119ceb0a39fb5306eb1988609b97ccf67b1dc04581ef9faa17dcb8`;
  SHA-256 der dekodierten RGBA-Pixel:
  `9ddcb4bb56746e41530c722621cf30d0c386056a02234b47a414308b849cbdf3`.
  Der Atlas enthält ausschließlich 16 Taschenbilder; Kopfzeile,
  Trainerfiguren, Schrift, Pokéball-Muster und übrige Sheet-UI fehlen.
- Reproduzierbare Ableitung: `tools/build_dp_bag_atlas.py` pinnt Quellhash,
  Maß und RGB-Modus; `tests/test_dp_bag_atlas.py` prüft Runtime- und
  RGBA-Pixelhash sowie bei bereitgestellter Quelle den bytegenauen Neubau. Die
  matte Quellfarbe RGB `#D0E8F8` wird transparent. Jede Quelle bleibt
  unskaliert und ungefiltert in einer 72×64-Zelle. Frauenreihe oben: Slots 1–7
  aus `(x=10+65*i,y=86,w=64,h=57)` nach `(4,3)`, Slot 8 aus
  `(465,86,69,57)` nach `(1,3)`. Herrenreihe unten: Slots 1–8 aus
  `(x=36+57*i,y=149,w=56,h=58)` nach `(8,3)`.
- Slotfolge: Pokébälle, Medizin, Beeren, Basis-Items, Post, TMs/VMs, Items,
  Kampfitems. VASCs sechs Fächer verwenden die Slots `7,2,1,6,8,4`.
- Form/Akzent: Die obere rechteckige Reihe wird als `HENKEL`, die untere runde
  Reihe als `NORMAL` geführt. AUTO nutzt bei gültigem öffentlichen KASC-Beleg
  für GREEN den Henkel und für RED/BLUE die runde Form. Ein lokaler Shader
  färbt ausschließlich die originalen roten/pinken Facheinsätze; Goldmaterial,
  Schattierung, Alpha und Konturen bleiben unverändert. Filter, Position und
  Skalierung sind `nearest`, ganzzahlig und 1×.
- Eigentumsgrenze: `GAME/KASC` ist Standard und umwickelt den vorhandenen
  Spiel-/Useful-/KASC-Draw nicht. Nur `D/P ORAS` ersetzt nach bewusster Wahl
  `draw`; Update, Eingabe, Item-/Fachdaten, Sortierung und Aktionen bleiben
  beim Original. Ohne Atlas oder bei Draw-Fehler wird exakt dorthin delegiert.
- Lizenzstatus: Diese Pokémon-Spielgrafik ist nicht von VASCs MIT-Lizenzen
  erfasst. Der Atlas bleibt ein privater Testkandidat und darf ohne geklärte
  Umverteilungsgrundlage nicht öffentlich veröffentlicht werden.

## FireRed/LeafGreen-Taschenatlas für `FRLG ORAS` (privater UI-Kandidat)

- Quelle: The Spriters Resource, **Interface & Bag Screens**, Pokémon
  FireRed/LeafGreen, Asset 3865, hochgeladen von 2b2n:
  `https://www.spriters-resource.com/game_boy_advance/pokemonfireredleafgreen/asset/3865/`.
  Das nicht ausgelieferte Original ist ein 704×560-Indexed-PNG mit 17.932 Byte
  und SHA-256
  `054e4c6e88402127639baa870f16e2eee81c4e1076ed00025d2b85e7eff95610`.
- Runtime: `assets/ui/frlg-oras-bag-3865.png`, 320×128 RGBA, SHA-256
  `3aee666ab5d247da143f31725d678491d32109ca08e110c1e575f9dc31531d2d`;
  SHA-256 der dekodierten RGBA-Pixel:
  `cdd36de11a986f90be081acfd965fe39f4277fcfa7895a2f13874194368167d9`.
  Enthalten sind genau zehn native 64×64-Zellen: Leafs Schultertasche und Reds
  Rucksack jeweils geschlossen, Items, Basis-Items und Pokébälle sowie die
  echte Beerentasche und das echte TM-Case. Sheet-Menüs und Text fehlen.
- Reproduzierbare Ableitung: `tools/build_frlg_oras_bag_atlas.py` pinnt
  Quellhash/-maß, ersetzt ausschließlich das Matte `#9CDCEF` durch binäres
  Alpha und kopiert die zehn in `FRLG_ORAS_BAG_ASSET.md` einzeln verzeichneten
  64×64-Crops ohne Skalierung, Filter, Farbänderung oder Resampling.
  `tests/test_frlg_oras_bag_atlas.py` prüft Runtime-Hash, Zellen und bei
  bereitgestellter Originalquelle den bytegenauen Neubau.
- Fachzuordnung: Items, Medizin und Kampfitems verwenden die echte Items-Pose;
  Pokébälle und Basis-Items ihre echten Posen, TMs/VMs das TM-Case. Ein
  optionales Beerenfach kann die echte Beerentasche verwenden. Es werden keine
  künstlichen acht Farbzustände erzeugt.
- Eigentumsgrenze: `GAME/KASC` ist auch hier Standard. `FRLG ORAS` ist nur
  VASCs ausdrücklicher zweiter Zeichenstil um dieselbe bestehende
  Bag-/Useful-/KASC-Logik und besitzt keinerlei Verhalten oder Speicherdaten.
- Lizenzstatus: Auch diese Pokémon-Spielgrafik ist nicht von VASCs
  MIT-Lizenzen erfasst. Der Atlas bleibt ein privater Testkandidat und darf
  ohne geklärte Umverteilungsgrundlage nicht öffentlich veröffentlicht werden.

## Gemeinsamer Taschenfach-Iconatlas

- Quelle: The Spriters Resource, **Bag**, Pokémon Diamond/Pearl, Asset 6961,
  hochgeladen von Cheese:
  `https://www.spriters-resource.com/ds_dsi/pokemondiamondpearl/asset/6961/`.
  Verwendet wird dasselbe nicht ausgelieferte 743×442-RGB-Quellsheet wie
  beim oben dokumentierten D/P-Taschenatlas; SHA-256
  `654a94fc97dddcc32d9add16c95abc2ffe71a13c58d0642984804a3037afe2f9`.
- Runtime: `assets/ui/bag-pocket-icons.png`, 204×68 RGBA, 3.402 Byte,
  SHA-256
  `231505882226abcf600a00cd1fd9621e348ed3a48092744df52ec9e876b9f411`;
  SHA-256 der dekodierten RGBA-Pixel:
  `81ea29cb5cdc041213135cdfbc584d290242e675d12b4b2788065316cc3fa19e`.
- Exakte Ableitung: Das Quellsheet ordnet die Symbole als Items, Medizin,
  Pokébälle, TMs/VMs, Beeren, Post, Kampfitems und Basisitems an. VASC kopiert
  die sechs benötigten 34×34-Zellen der Quellspalten `0,1,2,3,6,7`, jeweils
  bei `x=49+35*i`; die unveränderte goldene Ruhezeile beginnt bei `y=325`, die
  unveränderte rot markierte Aktivzeile bei `y=360`. Nur die flache
  Sheet-Matte RGB `#D0E8F8` wird transparent. Sichtbare RGB-Pixel werden weder
  skaliert, umgefärbt noch neu gezeichnet.
- Reproduzierbarkeit: `tools/build_bag_pocket_icon_atlas.py` pinnt Quellhash,
  Maß, Modus, Cropkoordinaten, Reihenfolge und PNG-/RGBA-Hashes. Der Quelltest
  vergleicht bei bereitgestelltem Original jeden Runtime-Pixel gegen seinen
  Quellpixel und baut das PNG byteidentisch neu.
- Runtime-Vertrag: Spalten sind fest `items`, `medicine`, `balls`, `tms`,
  `battle`, `key`; Zeile 0 ist inaktiv und Zeile 1 aktiv. `D/P ORAS` und
  `FRLG ORAS` zeichnen dieselben 34px-Quellzellen mit `nearest` bei 12×12
  nativen Menüpixeln. Der Bildadapter ändert weder Navigation, Callbackbesitz
  noch Pocket-Memory; prozedurale Symbole existieren ausschließlich als
  Fehlerfallback für direkte Adapter. Das Releasepaket verlangt den Atlas.
- Lizenzstatus: Diese Pokémon-Spielgrafik ist nicht von VASCs MIT-Lizenzen
  erfasst. Der Atlas bleibt wie der D/P-Taschenatlas ein privater Testkandidat
  und darf ohne geklärte Umverteilungsgrundlage nicht öffentlich veröffentlicht
  werden.

## Responsive ORAS battle HUD (private test integration)

### Standalone trainer fallback

- Runtime: `assets/fallback/red_voxel_front_hd.png`, 128×128 RGBA,
  SHA-256 `9bba6856d9e67608864bb83a5960073f984cbaed3f691544cbb6c20564d8bf66`.
- Source: byte-identical reviewed maintainer asset
  `kanto-ascendant/assets/characters/crystal_chars/red_voxel_front_hd.png`
  from KASC 6.5.17 commit
  `71ffb218f863f7f4949f700bd77ca917174f1fc7`.
- Runtime policy: VASC uses this full-body front only for the player-trainer
  intro when no optional public `OverworldBattle.sideTexture` provider has
  supplied a more specific identity. It is drawn nearest-neighbour into a
  320×288 canvas while retaining the logical 160×144 anchor contract. No KASC
  code or private resolver is imported.

- Visual reference and prepared interface components:
  https://www.spriters-resource.com/3ds/pokemonomegarubyalphasapphire/asset/67574/
- Runtime scope: localized Bag/Tasche, Fight/Kampf, Pokémon, Run/Flucht,
  Move/Attacke and HP/KP furniture under `assets/hud/`, plus the status,
  command and message plates required by the responsive renderer.
- Party fallback: Pokémon Crystal-derived six-frame 16×16 sheets for National
  Pokédex #001–251 under `assets/hud/crystal_menu_icons/`. The live
  Gen1Recomp/KASC front/Dex resolver is attempted first; these tiny sheets are
  only the final image fallback.
- VASC boundary: the private RC includes `de_mega.png`, `en_mega.png`,
  `mega_transformation.png` and `assets/audio/mega-evolution.mp3` solely for
  exact KASC compatibility acceptance. VASC standalone never exposes or
  activates Mega Evolution; the abandoned `frlg/` prototype stays excluded.

The ORAS and Crystal pixels are game artwork and are not covered by VASC's MIT
licenses. This integration remains a local test candidate and must not be
published until its redistribution status and visual acceptance are cleared.

## ASC BOX German fallback glyphs

- Runtime: `assets/ui/font_de_umlauts.png`, 56×8 RGBA, SHA-256
  `f4f66a26b49722c298eb87112d3d698302ea9b57aaf743796f532559b0c50fb6`.
- Reviewed source package: final `vasc-oras-storage-ui-0.5.3.zip`, SHA-256
  `d5f4bc04c3a14921f64a2a28593c5f415900fd16eadf699005b65aa2eba3db88`.
- Authorship: seven original VASC 8×8 alpha masks, first produced for that
  standalone ORAS storage prototype and moved byte-for-byte into the Host-v1
  ASC BOX provider. They contain no ROM-derived font pixels.
- Retained editable source: `assets/ui/font_de_umlauts.source.txt` records
  every mask row and the PNG packing order (`Ä Ö Ü ä ö ü ß`), byte-identical
  to 0.5.3, SHA-256
  `d1cd3b9b474671da5d1388e2b1745b125a6ae0399f9cc2dc7cc20c235a895ec6`.
- Runtime policy: VASC registers only glyphs missing from the active font
  catalog. A translation mod's existing character mapping always wins.

## Integrated Kanto Fly Map (RC10 Widescreen with internal compact fallback)

- Reviewed Widescreen source package:
  `vasc-kanto-fly-map-widescreen-1.0.0.zip`, SHA-256
  `e08b41897b68fa59588059f2caab6ab0c55a91fe3f98bfae43d1a1bd513a2744`.
- `assets/maps/kanto_fly_map_wide.png`, 576×324 PNG, 383185 bytes,
  SHA-256
  `6c7364811ab093cd50289f232af194f030f05e883e4705f9808e75d12e43a9a1`.
- `assets/maps/kanto_fly_map_wide_zoom.png`, 1152×648 PNG, 1481735 bytes,
  SHA-256
  `c9ce022bf3b68f2381c818c678d42595e5acd5fe077b4a8010b86db0fe6c778f`.
- These are the only new Widescreen runtime images in the deterministic
  release allowlist. The source package's 3067215-byte cleaned master is
  recorded in `integrated/kanto_fly_map/SOURCE_RECEIPT.json` but deliberately
  omitted from delivery because no runtime path reads it.
- `CARTRIDGE MAP` remains a direct engine path. The following older files are
  retained only for the automatic 288×240 fail-open renderer and are no longer
  a public menu choice:

- `assets/maps/kanto_fly_map_hd.png`, 288×230 PNG, SHA-256
  `6b4e5afc8ec8ea0fdddd0f729235498830524d72d11df6a7f9dd89df9a41785a`.
- `assets/maps/kanto_fly_map_hd_zoom.png`, 576×460 PNG, SHA-256
  `990ba4a574a3efdede7a285053d5af90bd70db30e1291c8279099bfd0fdee9fc`.
- `assets/maps/kanto_fly_map_vintage_clean.png`, retained repository source
  artwork but omitted from the runtime ZIP, SHA-256
  `9757923e7e35beaa0e71d784d23d7feb597cfd8a715deece40c528213903f966`.
- Source and transformation: user-supplied hand-painted vintage Kanto artwork;
  its lower brand/text region was removed with the built-in OpenAI ImageGen
  tool and replaced only with matching sea. Geography, routes and islands were
  retained. The 288×230 overview and 576×460 zoom are deterministic runtime
  derivatives used only by the integrated compact fallback controller.
- Ownership/licensing: rights in the supplied artwork remain with their
  respective rights holders. These files are private-RC assets and are not
  relicensed by VASC's MIT software license.

## Species Fly/Surf/Fishing cinematics (RC5/RC10)

- Source packages and SHA-256:
  - `VASC-Species-Fly-Cinematic-0.4.3.zip`:
    `1e49115da44cb600538e0b88be7046310d5a6ab123b4bdab07375d507b5d7f80`.
  - `VASC-Species-Surf-Cinematic-0.3.1.zip`:
    `5bd9914278efa3c9761d3cd86f21e3195bc512b4ddec2f76f0b859637ab1ca9d`.
  - `VASC-Species-Fishing-Cinematic-0.1.0.zip`:
    `1dfc5f146148d14d4873c9585b4943e0aa1c5f9686871308a07988ac16040d1a`.
- Directional runtime: 774 normal/Shiny files below
  `assets/species_cinematics/directional/`. All three inputs contain the same
  774 SHA-256 payloads, so VASC packages one deduplicated tree. Fishing adds
  no `assets/species_sprites/` copy.
- Surf carriers: 774 normal/Shiny six-pose files below
  `assets/vasc_runtime/followsprites_runtime/`; 502 were already byte-identical
  in RC4 and only the missing Hoenn/Gorochu payloads are new.
- Complete source receipt and runtime policy:
  `docs/SPECIES_CINEMATICS.md`.
- Verbatim input provenance, third-party notices and credits:
  `docs/species_cinematics/`.
- Licensing: these fan-art sprite assets are not relicensed under VASC's MIT
  software license. The preserved input notices remain authoritative.


## Pokémon Center seated person (3.0.15)

assets/characters/pokecenter-seated-man-hd-v1.png: generated with the built-in image_gen tool for this project on 2026-09-10. Original transparent RGBA output preserved; body framed with renderer UV coordinates.

## Verwendeter Prompt

Create ONE transparent-background game sprite asset, not a scene or sprite sheet. A friendly middle-aged male NPC sitting on an invisible low bench, seen from exact RIGHT-FACING SIDE PROFILE with a slightly elevated camera (top of hair visible), matching polished chibi Pokemon remake NPC game cards. Large head, compact body, short neat black hair, no hat, clean shaven, white short-sleeve shirt, dark navy blue trousers, dark brown shoes. Sitting relaxed, torso upright, thighs extending horizontally to the RIGHT, knees bent at ninety degrees, lower legs hanging down, feet pointing right. Hands resting on thighs. Entire person fully visible, no crop. Neutral friendly face. Soft faceted 3D-render illustration appearance, clean defined silhouette and subtle outlines, even neutral lighting, no glow, no cast shadow. NO bench, NO furniture, NO floor, NO background, NO lettering, NO other people. Transparent alpha background. Center the body with modest 8% transparent margin. Square image. This will replace the man drawn into the couch in classic Pokemon Centers; preserve unmistakably SEATED posture and RIGHT-facing direction.
