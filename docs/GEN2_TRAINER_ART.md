# Gen-2 battle trainer art

The Gen-2 live-world battle presentation first reuses the approved, internally
authored KASC HD trainer standees. It does not download or silently substitute
third-party HGSS art.

## Player standees

- Gold: `assets/trainers/gen2/players/gold_front_hd.png`
- Silver: `assets/trainers/gen2/players/silver_front_hd.png`
- Kris: `assets/trainers/gen2/players/kris_front_hd.png`

These were copied without alteration from KASC's
`assets/johto_masters/battle/` source directory. A female Crystal save selects
Kris, a male Silver save selects Silver, and Gold or male Crystal selects Gold.

## Opponent standees

Compatible Gen-2 trainer classes resolve to KASC's approved 128x128 trainer
pack under `assets/trainers/gen2/kasc/`. The rival resolves to Silver. Unique
Johto classes without an honest KASC counterpart deliberately keep their
native Gold/Silver/Crystal battle picture. New externally sourced art should
only be introduced for such audited gaps and must carry its own provenance.

The cartridge still controls both intro flags. The HD trainer is visible only
while `showEnemyTrainer` or `showPlayerTrainer` is true, so it disappears at
the native Pokemon send-out rather than remaining as an overworld walker.
