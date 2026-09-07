# WX World Cycle — RC10 reviewed intake

Voxel Ascendant RC10 remains the sole weather renderer and gameplay owner.
The V4.1 RC9 package was used only as an isolated design/source intake. No
VoxelUltimate renderer, state, battle rule, menu, asset or unrelated world
code is included.

`WX MICRO EVENTS` is an independent presentation setting:

- `OFF`: no micro-event draw, no accumulated surface timing; canonical VASC
  weather only.
- `SUBTLE` (production default): the complete bounded event rules at lower
  density.
- `FULL`: the same rules at full density for discovery and visual QA.

Existing saves keep their selected value. The setting does not select base
weather and does not alter battle logic.

## World calendar

- `WEATHER=AUTO` owns one regional front for 240 seconds (4 minutes). Crossing
  between outdoor maps or through an interior does not reroll the front.
- Four fronts form a 960-second (16-minute) season. The temperate, warm,
  temperate, winter year lasts 64 minutes.
- `DAYTIME=CYCLE` keeps RC10's existing independent 1200-second (20-minute)
  continuous day. The 64-minute year and 20-minute day do not phase-lock.
- Rain/storm followed by clear/heat keeps the existing forced-rainbow path.
  Manual `WEATHER=RAINBOW` remains available for immediate testing.

## Micro-event combinations

| Combination | Additive result |
|---|---|
| storm + outdoors | bounded tumbling storm leaves |
| snow + cold route | hail |
| clear + forest + night/evening | independently moving fireflies |
| fog + coast | spray |
| clear/heat + Cinnabar | ash |
| clear/heat + Route 3/4 | dust |
| clear/snow/heat elsewhere | recurring wind gusts |
| clear + Route 3/4 + night | rare meteors |

Only one micro-event can win a frame. Weather-like additions may enter a live
overworld battle at half density; fireflies and meteors remain exploration
only. The current RC10 scene, battle, shadow, occlusion and HUD ordering stays
authoritative.

## Surface and sound

- Existing 3D snow treatment builds toward a deterministic light-to-heavy
  coat over 105 seconds and thaws over 210 seconds.
- Wet ground can linger and drain for up to 45 seconds after rain/storm.
- Completed walking steps can play procedural splash or snow-crunch sounds.
  Bike and Surf are excluded; Gen2 accepts its native `game.world` owner.
- Snow crunch starts only after a small coat has settled and scales with it.
- Step and wind sounds respect SFX volume, fail silently when audio facilities
  are unavailable and briefly duck music through the engine's `music.volume`
  hook. Saved volume is never rewritten and returns smoothly.

## Non-negotiable normal-rain contract

Only AUTO timing/selection was changed in the two canonical `Weather.lua`
files; their current RC10 painter remains intact. When the resolved base mode
is normal `rain`, `WeatherTweak` returns before reading LOVE, scheduling audio
or drawing. Rain density, runoff, tint, splash rings, renderer ordering and
battle rain therefore remain owned by the current VASC renderer.

## Deliberately rejected RC9 differences

- No complete RC9 `Weather.lua`, `VoxelScene.lua`, `Voxel3D.lua`, main,
  options, environment or Gold bridge file replaced its newer RC10 peer.
- No older RC9 battle/environment lifecycle or renderer ordering was restored.
- No VoxelUltimate ledge/height system, WeatherFX bundle, menu/rebranding,
  optional GBC effects, gameplay, Kanto world or Stadium package was copied.
- Later experimental weather/legend/thunder variants outside the requested
  V4.1 intake remain separate work.

## Focused visual matrix

Use `WX MICRO EVENTS=FULL` for discovery, then repeat representative cases in
`SUBTLE` and verify `OFF`. Forced `WEATHER` values are test inputs; return to
`AUTO` for the regional calendar.

- Hail: `ROUTE_23` or `INDIGO_PLATEAU`, `WEATHER=SNOW`.
- Fireflies: `VIRIDIAN_FOREST`, `WEATHER=CLEAR`, `DAYTIME=NIGHT`.
- Storm leaves/wind: any outdoor route, `WEATHER=STORM`.
- Coastal spray: Vermilion/Cinnabar coast, `WEATHER=FOG`.
- Ash: Cinnabar outdoors, `WEATHER=HEAT` or `CLEAR`.
- Dust/meteor: `ROUTE_3` or `ROUTE_4`; meteor additionally needs `NIGHT`.
- Footsteps: walk on foot in `RAIN`, `STORM`, or after snow has settled.
- Rain guard: compare `WX MICRO EVENTS=OFF`, `SUBTLE` and `FULL` under normal
  `WEATHER=RAIN`; canonical output and scheduling must be identical.
