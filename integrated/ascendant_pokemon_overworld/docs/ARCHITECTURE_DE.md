# Architektur

Die Mod trennt neun Verantwortungen:

1. `src/catalog.lua` löst Nationaldex, Shiny-Zustand und die 1004
   Artwork-Varianten auf.
2. `src/runtime.lua` besitzt im Standalone-Modus genau einen Begleiter und
   delegiert vollständig, sobald KASC, JASC oder eine bekannte Follower-Mod
   bereits zuständig ist. Bei einem öffentlichen `followerSprites`-Resolver
   ersetzt eine reversible Brücke nur dessen Bildauflösung; Bewegung, Auswahl
   und Entitätsbesitz bleiben beim Fremdprovider.
3. `src/characters.lua` liest Basis-Walker und öffentliche Charakter-Provider.
   Es setzt nur neutrale Runtime-Tags und verändert weder Story noch Auswahl.
4. `src/compat.lua` enthält die einzigen Berührungspunkte zu optionalen Mods.
   Private Module werden nicht geladen.
5. `src/character_actions.lua` veröffentlicht die produktiven 3x4-Atlanten
   für Fahrrad und Angeln der sechs Hauptfiguren. Die Spiellogik bleibt beim
   jeweiligen Spiel beziehungsweise Charakter-Provider.
6. `src/npc_catalog.lua` liest die quellengestützten Karteninventare und
   veröffentlicht für jede menschliche Gen-1-/Gen-2-Objektinstanz ihre
   konkrete, paketierte HD-Grafik. Bei Kämpfern ist die Trainerklasse und nicht
   bloß die häufig wiederverwendete Original-Kartenfigur maßgeblich.
7. `src/walking_sprites.lua` verbindet diese Karteninstanzen mit den
   freigegebenen 4x3-Atlanten. Es ersetzt nur den Renderer lebender Entitäten,
   speichert das ursprüngliche Rendererobjekt in einer schwachen Tabelle und
   kann dadurch beim Optionswechsel verlustfrei auf Vanilla/KASC/JASC
   zurückschalten. Die Engine erhält einen 16x96-Fallback; VASC liest über
   `ascendantAtlasImage` weiterhin den vollständigen HD-Atlas.
8. `src/pokemon_walksheets.lua` löst die 822 transparenten Pokémon-Atlanten
   nach Nationaldex, sichtbarem Geschlecht und verfügbarer Palette auf. Die
   Laufzeit nutzt den zugehörigen nativen 16x96-Streifen; VASC erhält den
   unveränderten 3x4-Atlas und eine aus der Cartridge-Höhe bestimmte
   Größenklasse.
9. `src/pokemon_world_sprites.lua` verbindet dieselben Atlanten getrennt mit
   Begleitern, sichtbaren Wild-Pokémon, festen Stadt-Pokémon und den friedlichen
   Stadt-Pokémon von Wilds. Es dekoriert ausschließlich öffentliche
   Resolver/Entitäten, invalidiert deren Bildcache bei Optionswechsel und
   stellt jede Identität exakt wieder her. Die beim Import gemessenen sichtbaren
   Pixelgrenzen werden mit derselben zentralen Skala wie VASC auf 9,45 / 15,525 /
   21,6 Welteinheiten gebracht; skaliert wird um den Fußpunkt, sodass keine
   Figur schwebt. Eine explizit gewählte GO-HD-Renderkarte oder
   PokeMMO-Pixelkarte setzt nur an ihrer Entität
   `pokemonModel=false`/`stadiumModel=false`, damit in VASC nicht zugleich der
   konkrete Pokémon-Stadium-2-Körper und die gewählte Lauffigur erscheinen.
   Die gelieferten GO-HD-Renderkarten sind dabei eine eigene Pokémon-GO-Quelle
   und keine Stadium-2-Modelle.

`cards/overworld_pokemon_card.lua` beschreibt dieselben Dienste bereits als
`ascendant.card/v1`. Damit sind Standalone-Runtime und spätere VASC-Card keine
zwei Implementierungen, sondern zwei Hosts derselben Provider.

## Eigentumsregeln

- Pokémon-Auswahl und zwei Save-Schlüssel: diese Mod, aber nur im
  Standalone-Modus.
- KASC-/JASC-Charakterzustand: immer KASC beziehungsweise JASC.
- VASCs Rendering und Import seiner konkreten Pokémon-Stadium-2-Quelle: immer
  VASC. Diese Mod entscheidet nur, ob ein separat aktivierter Pokémon-Kontext
  stattdessen eine GO-HD-Renderkarte, eine PokeMMO-Pixelkarte oder eine
  2D-Sprite zeigt, und liefert bei aktiviertem Finish ein transparentes,
  flaches Reliefmesh mit vier subtil beleuchteten Facetten; Welt, Kamera und
  Licht bleiben VASC. Im Modus `AUTO` lautet die gewünschte Priorität für
  #001–251: Pokémon Stadium 2, danach GO-HD, danach 2D.
- 3D-Character-Selector und dessen Modelle: immer `red_3d_player`.
- Native NPC-Bewegung, Kartenobjekte und Ereignisse: immer das Spiel/Engine;
  ausgetauscht wird ausschließlich deren lokales `SpriteRenderer`-Objekt.

Diese Grenzen verhindern doppelte NPCs, konkurrierende Hooks und ein
versehentliches Umschreiben fremder Spielstände.
