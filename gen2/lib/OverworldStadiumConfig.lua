-- Stadium Overworld Models configuration.
--
-- This file ships with the add-on and is loaded by lib/OverworldStadium.lua.
-- It contains NO Pokemon Stadium assets.  Dramatic Shape's existing Stadium
-- importer supplies the model packs from the player's own compatible ROM.
local Config = {}

-- Master switch for overworld replacement.
Config.enabled = true

-- Release an off-map rig after this many rendered frames.  Keeping a short
-- grace period avoids rebuilding a model when a connected-map ghost crosses
-- a seam and becomes a local entity on the next frame.
Config.staleFrames = 120

-- If an entity has no explicit Pokemon tag, allow species-specific sprite
-- names such as PIKACHU / SPRITE_PIKACHU to resolve automatically.  Generic
-- Gen 1 sheets such as MONSTER, BIRD, or BUG intentionally do not guess a
-- species because one sheet can represent several different Pokemon.
Config.autoSpriteSpecies = true

-- Pokemon Yellow's built-in follower entity is still used for its original
-- trailing movement, hiding/showing, warps, and collision behavior.  The
-- model drawn on that entity is taken LIVE from party slot #1, so changing
-- party order changes the follower without needing a map reload.
Config.firstPartyFollower = true

-- Species size mode.
--
-- v0.1.8 restores the original pre-v0.1.6 sizing by default. Dramatic Shape's
-- Stadium model worldHeight() is used directly, matching v0.1.5 and earlier.
-- Set this back to true only if you want the experimental Pokedex-relative
-- height scaling from v0.1.6/v0.1.7.
Config.pokedexScale = false

-- Small-Pokemon visibility floor (v0.1.38). Dramatic Shape intentionally
-- compresses the Stadium battle models, which can make species such as
-- Rattata disappear almost completely inside tall grass. When Pokedex scaling
-- is OFF (the default), models shorter than this many world pixels are enlarged
-- up to this floor. Larger Pokemon are left completely unchanged.
Config.smallPokemonMinWorldHeight = 11.5

-- Optional per-species minimums for especially low-profile models. These are
-- absolute world-pixel floors, not multipliers. Rattata is given a slightly
-- stronger floor because its Stadium stance is both short and horizontal.
Config.smallPokemonMinHeightOverrides = {
  [19] = 12.5, -- Rattata
  [20] = 12.0, -- Raticate
  [50] = 11.5, -- Diglett
  [90] = 11.5, -- Shellder
  [100] = 11.5, -- Voltorb
  [129] = 12.0, -- Magikarp
  [132] = 11.5, -- Ditto
}


-- Large-Pokemon presence boost (v0.1.41). The restored Dramatic Shape sizes
-- still compress several naturally large species too much next to the trainer.
-- These are multiplicative boosts applied only when Pokedex scaling is OFF.
-- Species not listed remain exactly at their existing v0.1.38 size.
Config.largePokemonScaleOverrides = {
  -- Starters / large final evolutions
  [3]   = 1.70, -- Venusaur
  [6]   = 2.25, -- Charizard (reference scale / mount-scale)
  [9]   = 1.65, -- Blastoise

  -- Large/heavy terrestrial Pokemon
  [31]  = 1.55, -- Nidoqueen
  [34]  = 1.65, -- Nidoking
  [36]  = 1.35, -- Clefable
  [38]  = 1.35, -- Ninetales
  [57]  = 1.35, -- Primeape
  [59]  = 1.70, -- Arcanine
  [62]  = 1.45, -- Poliwrath
  [68]  = 1.55, -- Machamp
  [71]  = 1.40, -- Victreebel
  [76]  = 1.60, -- Golem
  [78]  = 1.55, -- Rapidash
  [80]  = 1.45, -- Slowbro
  [85]  = 1.45, -- Dodrio
  [87]  = 1.55, -- Dewgong
  [89]  = 1.45, -- Muk
  [91]  = 1.45, -- Cloyster
  [94]  = 1.45, -- Gengar
  [95]  = 2.70, -- Onix
  [97]  = 1.40, -- Hypno
  [99]  = 1.50, -- Kingler
  [103] = 1.65, -- Exeggutor
  [110] = 1.45, -- Weezing
  [112] = 1.85, -- Rhydon
  [113] = 1.45, -- Chansey
  [115] = 1.80, -- Kangaskhan
  [127] = 1.55, -- Pinsir
  [128] = 1.65, -- Tauros

  -- Huge / long-bodied Pokemon
  [130] = 2.75, -- Gyarados
  [131] = 2.30, -- Lapras
  [139] = 1.55, -- Omastar
  [141] = 1.55, -- Kabutops
  [142] = 2.20, -- Aerodactyl
  [143] = 2.20, -- Snorlax

  -- Legendary / late-game large Pokemon
  [123] = 1.65, -- Scyther
  [125] = 1.45, -- Electabuzz
  [126] = 1.45, -- Magmar
  [144] = 1.95, -- Articuno
  [145] = 1.95, -- Zapdos
  [146] = 1.95, -- Moltres
  [148] = 1.85, -- Dragonair
  [149] = 2.15, -- Dragonite
  [150] = 1.70, -- Mewtwo

  -- Gen-2 legendary presence.  The original override table stopped at the
  -- Gen-1 roster, so Stadium 2's large Johto legends were left at the generic
  -- compressed battle-model scale.  Keep Celebi unboosted intentionally.
  [243] = 1.65, -- Raikou
  [244] = 1.75, -- Entei
  [245] = 1.65, -- Suicune
  [249] = 2.25, -- Lugia
  [250] = 2.15, -- Ho-Oh
}

-- Human reference used to turn metres into overworld world-pixels. A Pokemon
-- whose Pokedex height equals `humanReferenceMeters` will be this many world
-- pixels tall. 24 px is 1.5 overworld tiles and matches the visual scale of
-- the 3D trainer reasonably well while still letting giants feel giant.
Config.humanReferenceMeters = 1.60
Config.humanReferenceWorldHeight = 24

-- Global multiplier after Pokedex scaling. Leave at 1 for the canonical
-- Pokemon:human ratio. If the whole cast feels too large/small, change only
-- this value (for example 0.85 or 1.15).
Config.pokedexScaleMultiplier = 1.0

-- Optional per-Dex multipliers for artistic/camera exceptions. These are
-- applied AFTER canonical height scaling. Example: [95] = 0.8 for Onix.
Config.heightOverrides = {}

-- Safety clamps in world pixels. `nil` means no clamp, preserving the actual
-- relative height ratio even for Onix/Gyarados. Set maxPokemonWorldHeight if
-- you prefer the biggest Pokemon to stay inside the camera more often.
Config.minPokemonWorldHeight = 3
Config.maxPokemonWorldHeight = nil

-- Grounded biped walking locomotion (v0.1.7).
--
-- The Stadium battle assets do not provide one universal named walk clip.
-- For grounded two-legged species the overworld renderer uses that species'
-- alternate standby loop when available, synchronizes it to actual distance
-- travelled, and adds a subtle footfall bob/pitch. Flying/hovering Pokemon and
-- quadrupeds retain their existing Stadium animation.
Config.walkingAnimations = true

-- Global gait speed. 1.0 is tuned to Gen 1 overworld movement. Higher values
-- make feet cycle faster for the same distance travelled.
Config.walkCadenceMultiplier = 1.0

-- Stadium skeletal playback is also distance-driven, but unlike older builds
-- it is no longer forced through an entire standby loop every gait cycle.
-- This is the nominal world distance travelled per one second of Stadium clip.
Config.walkClipWorldSpeed = 54

-- Safety ceiling on skeletal playback rate relative to its authored 30 FPS.
-- This keeps followers from looking fast-forwarded when movement mods, catch-up
-- pathing, or uneven entity interpolation produce a large one-frame step.
Config.walkClipMaxRate = 1.25

-- Charizard transition bridge (v0.1.50). Charizard's idle_alt clip contains
-- lead-in frames before loopStart. Replaying them once on movement start gives
-- the large model a much softer stand -> walk hand-off instead of snapping
-- directly to the first looping gait pose.
Config.charizardWalkUseIntro = true
Config.charizardWalkTransitionSeconds = 0.34

-- Body-motion multipliers for the procedural ground-contact portion. Set bob
-- to 0 if you want only the Stadium skeletal loop, or pitch to 0 to remove the
-- slight forward/back weight shift while preserving the step cycle.
Config.walkBobMultiplier = 1.0
Config.walkPitchMultiplier = 1.0

-- Per-Dex grounded-biped classification overrides. Use true to opt a species
-- in, false to opt one out without editing PokemonLocomotion.lua.
-- Example: Config.walkSpeciesOverrides = { [52] = false, [123] = true }
Config.walkSpeciesOverrides = {
  [6] = true, -- Charizard: grounded overworld walk instead of always being excluded as Flying type
}

-- Optional exact overrides for old maps/mods whose Pokemon NPCs carry only a
-- generic overworld sprite and no species metadata.
--
-- Keys are map IDs.  Inside a map, key by entity index or by entity name/id.
-- Values may be a National Dex number or an engine species key.
--
-- Example:
-- Config.overrides = {
--   SOME_MAP = {
--     [3] = 25,
--     PIKACHU_FOLLOWER = "PIKACHU",
--   },
-- }
Config.overrides = {}

return Config
