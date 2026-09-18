# Herkunft des lokalen Pakets

Dieses Paket wurde aus dem vorhandenen Recompile-Arbeitsbestand erstellt. Die enthaltenen Pokémon- und Trainergrafiken sind keine neu erteilten frei lizenzierten Assets.

- `runtime/vendor/`: vorhandene Gen2-Animationslaufzeit aus `johto-crystal-expansion/harness/src/battle/gen2` sowie `src/ui/gen2/SpriteAnims.lua`. Die Catch-Skripte und kleinen OAM-Grafikblätter wurden aus dem lokal bereits importierten Crystal-Datenbestand übernommen.
- `runtime/JourneysBalls.lua`: vorhandenes `vasc-smooth-character-walk/gen2/lib/Gen2CaptureBallPresentation.lua`, angepasst an den Gen1-Zeichenaufruf und dessen zusätzlichen Farbpass. Drehung, Bodenphase und Kontrollleuchte stammen aus diesem Modul.
- `runtime/BallStyles.lua`: die bestehenden `BALL_SKINS` aus `gen2/lib/Gen2KascQol.lua`.
- `runtime/assets/journeys_balls`: unveränderte Dateien des vorhandenen Journeys-/Essentials-Bestands. Im vorliegenden Quellordner ist die tatsächliche Masterball-Grafik als `safari_ball.png`, die Hyperball-Grafik als `master_ball.png` und die Safariball-Grafik als `ultra_ball.png` benannt. Der Gen1-Adapter ordnet anhand des sichtbaren Designs zu. Zusätzlich: Level→`fast_ball`, Köder→`level_ball`, Schwer→`lure_ball`, Liebe→`heavy_ball`, Freund→`love_ball`, Mond→`friend_ball`, Turbo→`moon_ball`.
- Helden, reguläre Gegner und Arm-Markierungen: `vasc-smooth-character-walk/integrated/ascendant_pokemon_overworld/assets/characters` und `src/human_rig_profiles.lua`.
- Jessie/James/Meowth: vorhandene freigegebene Battle-Grafik aus `trainer_rematch/assets/yellow_jessie_james/battle`.
- Der optionale VASC-HUD-Eingriff ergänzt dessen vorhandene Floating-Battle-HUD-Integration. Die ursprünglichen MIT-Lizenztexte sind unter `licenses` beigefügt.

Der Build ist für den vorhandenen lokalen/privaten Projektbestand bestimmt. Es wurden weder ROM-Dateien noch komplette Engine-, VASC- oder KASC-Pakete beigefügt.
