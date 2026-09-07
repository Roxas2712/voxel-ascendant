# Gen-2 Trainer Card badge case

The Gen-2 Trainer Card uses a compact runtime atlas derived from the HGSS
Badge Case sheet published by The Spriters Resource:

- source page: https://www.spriters-resource.com/ds_dsi/pokemonheartgoldsoulsilver/asset/29323/
- credited ripper: Kyo Wolf
- exact source file: `tools/sources/hgss_badge_case/29323.png`
- source SHA-256: `38c120a0d0608348d999c2631053b594e29a8f802a137b7be2f09b7f4e88644e`
- source dimensions: 990 x 650 RGB PNG

The source note allows use without separate permission, appreciates credit,
and prohibits claiming the sprites as original work. This project preserves
that attribution here and does not represent the artwork as project-owned.

`tools/build_gen2_trainer_card_badge_case.py` reproducibly extracts all sixteen
leader portraits and one front-facing frame for each of the sixteen badges.
It removes only the white sheet background from badge cells. The generated
`assets/ui/gen2/trainer_card/hgss_badge_case_runtime.png` is 384 x 160 RGBA.

Runtime ownership remains entirely inside Card `vasc.gen2.menu-ui`. The asset
is presentation-only: Johto reads `player.badges`, Kanto reads
`player.kantoBadges`, and the engine continues to own input, page selection,
unlocking, save data and dismissal.
