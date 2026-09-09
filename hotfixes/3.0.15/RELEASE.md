# Voxel Ascendant 3.0.15

Selecting Stadium2 now renders imported models for Gen1 wild, town, ambient and follower Pokémon independently of battle model settings. Static map Pokémon use their actual species, including all five living Fuchsia zoo Pokémon.

HD people now resolves 34 missing Youngster asset references. Seated people baked into the tileset also switch to HD in eleven Pokémon Centers and Celadon Hotel. Turning HD PEOPLE off restores their original graphics. OVERWORLD CARD must be enabled at startup; its help now explains the required reload after enabling it.

Retains the 3.0.14 Low Kick animation fix. Existing private Stadium2 imports remain required. No ROM/model payload is included and no save migration is needed.

Validation: all package Lua files compile; model selection/lifecycle/fallback tests, 80 HD setting combinations, 719 NPC catalog entries, seated-figure toggling and native Gen1 world tests passed. Native testing used macOS LÖVE with a mobile profile, not a physical Android device.

Install the ZIP as a replacement for the existing Voxel Ascendant mod and fully restart the game.
