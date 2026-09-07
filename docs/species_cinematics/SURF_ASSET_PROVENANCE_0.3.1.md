# Asset-Herkunftsbeleg

Dieses Paket enthält zwei getrennte, aber verwandte Sprite-Sätze. Beide decken
Nationaldex `001` bis `386` lückenlos ab und enthalten zusätzlich Kanto
Ascendants Gorochu (`1026`), jeweils in `normal` und `shiny`.

## VASC-Carrier und Fallback (`assets/world_sprites/`)

- 772 PNG-Dateien für #001–386 plus zwei Gorochu-Dateien, jeweils 16×96 Pixel
- sechs 16×16-Frames in der Reihenfolge `idle_down`, `idle_up`, `idle_left`,
  `walk_down`, `walk_up`, `walk_left`; rechts wird vom Renderer gespiegelt
- die 772 Nationaldex-Dateien sind bytegleich aus Kanto Ascendants vendortem
  Wilds-1.12.2-Runtime-Katalog
  `vendor/wilds_1_12_2/assets/bundled_runtime/followsprites_runtime/`
  übernommen
- dessen Manifest nennt für jede Art/Variante Quellblatt, Form,
  Konvertierung, Skalierung und Frame-Reihenfolge
- SHA-256 dieses Quellmanifests:
  `99bda84e1c4fb04f396ca63422230b9cdd2f1814291e694f988d9e3498fd7074`
- Gorochu Normal/Shiny ist bytegleich aus KASCs
  `assets/followers_runtime/{normal,shiny}/follower_GOROCHU.png` übernommen:
  `13bbbf9392ba8defd0225ad88dc84cf52ac9c7d648c5d72f54b3bf0337a95cc3`
  und `a6ef9daac168cc19a588af59631968a495b50861f38c7413daa1ecae57629e49`.

Seit Version 0.3.0 werden diese 16px-Blätter nicht mehr als sichtbare
Pokémon-Quelle der laufenden Fahrt verkleinert. Sie bleiben als verifizierter
1:6-UV-Carrier und kompatibler Asset-Fallback im Paket.

## Seitenanimation für Aufstieg, Fahrt und Rückruf (`assets/surf_sprites/`)

- 774 PNG-Dateien: #001–386 mit vier Richtungen und vier Frames je Richtung,
  dazu Gorochus zwei unveränderte 16×96-Sechsposenblätter
- 758 Blätter sind 128×128; Steelix nutzt 144×144, Wailord 164×164 und
  Lugia, Ho-Oh, Kyogre, Groudon sowie Rayquaza 256×256. Der Renderer ermittelt
  die jeweilige Zellgröße aus der Blattbreite.
- bytegleich aus dem bereits geprüften Nationaldex-Katalog des eigenständigen
  `VASC Species Fly Cinematic`-Pakets übernommen
- Gorochus sechs Posen werden zur Laufzeit wie im Flug-Mod logisch auf vier
  Richtungen abgebildet; das Quellblatt wird dabei nicht neu skaliert.
- Die laufende Fahrt nutzt ab Version 0.3.0 die linke Seitenzeile direkt in
  einer 64×384-Komposittextur; VASC spiegelt die vollständige Einheit nach
  rechts. Front-/Rückenframes werden dafür nicht mehr verwendet.

Dessen Auswahl folgt der Wilds-Mappingdatei
`assets/enhanced_overworld/followsprites_mapping/followsprites_mapping.json`
mit SHA-256
`226cba57ebfee3e8b769a7afb5a7b29396bf7868afb71df0c851e1511cc5a142`.

Die Dateien gehören zur in `THIRD_PARTY_NOTICES.md` beschriebenen
Followers-EX-/PokéPC-Followers-/Crystal-Clear-Sprite-Linie. Dieser Beleg
dokumentiert Auswahl und technische Ableitung; er erteilt keine neue Lizenz
für Drittanbieter-Grafiken.
