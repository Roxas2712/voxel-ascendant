# charsprite v1

Die Schnittstelle liegt auf `mod:find('ascendant_battle_heroes').exports.charsprite` und trägt die Kennung `ascendant.charsprite/v1`. Eigene Pakete laden nach Battle Heroes oder registrieren sich im Ereignis `mods.loaded`.

## Eigener Atlas

```lua
local api = mod:find('ascendant_battle_heroes').exports.charsprite
api.register('my_red', {
  path = mod.path .. '/assets/my_red.png',
  columns = 3, rows = 4,
  idleColumn = 0,
  leftRow = 1, rightRow = 3,
  frontRow = 0, backRow = 2, -- optionale vollständige Standansichten
  height = 18,
})
api.setResolver(function(battle, side, original)
  if side == 'player' and original == 'red' then return 'my_red' end
  return original
end)
```

Alle Spalten und Zeilen sind **nullbasiert**. Der Standardatlas hat drei Spalten und vier Richtungszeilen: unten, links, oben, rechts. Transparenter PNG-Hintergrund, gleiche Zellabmessungen und gleichbleibende Figurengröße sind erforderlich. `path` ist der von LÖVE erreichbare Modpfad, kein HTTP-Link. Die Registrierung verändert keine Spieldaten.

`bindTrainer('OPP_BROCK', 'my_brock')` ersetzt gezielt eine Gegnerklasse. `setResolver(nil)` entfernt den zusätzlichen Resolver. Der Resolver erhält den aktuellen Kampf, `player` oder `enemy` und die automatisch ermittelte Charakter-ID. Nicht registrierte Ergebnisse oder Fehler fallen auf die Standardzuordnung zurück.

## Eigene gezeichnete Wurfanimation

```lua
api.register('my_trainer', {
  path = mod.path .. '/assets/my_throw_sheet.png',
  columns = 6, rows = 2,
  leftRow = 0, rightRow = 1,
  clips = {
    throw_enemy = {
      {0, 0, 3}, {1, 0, 6}, {2, 0, 9}, -- Ausholen, bis Tick 18
      {3, 0, 8}, {4, 0, 10}, {5, 0, 18}, -- Freigabe/Nachschwingen
    },
    throw_player = {
      {0, 1, 3}, {1, 1, 6}, {2, 1, 9},
      {3, 1, 8}, {4, 1, 10}, {5, 1, 18},
    },
  },
  releaseHand = {
    player = {.72, .44},
    enemy = {.28, .44},
  },
})
```

Jeder Eintrag ist `{Spalte, Zeile, Dauer_in_60Hz_Ticks}`. `throw` dauert 54 Ticks; der Ball wird nach 18 Ticks freigegeben. `command` ist die Anweisungsgeste. `idle` wiederholt sich; andere Clips wechseln nach Ende zur Grundpose zurück. Ein richtungsspezifischer Clip hat Vorrang vor `throw`, `command` oder `idle` ohne Suffix.

`releaseHand` verwendet normalisierte Koordinaten der fertigen 192×256-Präsentationsfläche: links/oben `{0,0}`, rechts/unten `{1,1}`. Ohne Angabe wird die Hand aus dem Arm-Rig berechnet. Ein gezeichneter Clip ersetzt die prozedurale Armbewegung vollständig. Alle Zellen eines solchen Atlasses verwenden gemeinsam ermittelte sichtbare Grenzen, damit erhobene Arme die Figur beim Framewechsel nicht verkleinern. Der fliegende Ball gehört weiterhin der Kampfanimation und sollte nicht in die Freigabe-Frames gezeichnet werden.

## Arm-Rig für vorhandene Seitenansichten

```lua
rig = {
  [1] = {centers={.53}, radius={.12}, window={.43,.62,.74,.79}},
  [3] = {centers={.47}, radius={.12}, window={.43,.62,.74,.79}},
}
```

Die Werte beziehen sich auf das sichtbare Alpha-Rechteck der Figur. `centers[1]` ist die horizontale Armmittelachse, `radius[1]` die halbe Armbreite. `window` beschreibt die vertikale Armzone von Schulter bis Hand. Der Arm wird als separate Texturlage um die Schulter gedreht; die freigelegte Körperfläche wird aus benachbarten Körperpixeln ergänzt. Für ungewöhnliche Kleidung, große Requisiten und Gruppenbilder sind gezeichnete Clips die präzisere Lösung.

Die mitgelieferten Rig-Marken stammen aus dem bestehenden HD-Charakterbestand. Für noch nicht markierte Figuren existiert ein generisches Rig. Die API ersetzt Sprites und Darstellung; sie erzeugt keine zusätzlichen Trainer, speichert keine Heldenauswahl und beeinflusst keine Kampfentscheidung.

## Kamerabhängige Standansicht

Die eingebauten Einzeltrainer besitzen vollständige Front- und Rückansichten. `frontRow` und `backRow` aktivieren diese auch für eigene Atlanten ausdrücklich; die Zeilenzahl allein reicht nicht als Beleg. Im 3D-Kampf wählt die Kamera relativ zum Gegner die passende Standansicht. Eine Totzone verhindert Flackern an Winkelgrenzen. Wurf-/Kommandoclips und ihre Handposition behalten ihre ursprüngliche Ausrichtung. Einseitige Atlanten (z.B. Jessie/James) behalten die vorhandene Darstellung.
