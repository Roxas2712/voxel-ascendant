# Gen2 ROM QA remaining for 3.0 RC

Static contracts and deterministic packaging do not replace in-game ROM QA.
Before promoting this RC, run a clean process restart for each edition and
record screenshots/logs for the following matrix.

## Gold and Silver

- With a cold cache and `DEVICE=AUTO`, map setup itself must stay bounded and
  the native 2D frame must remain responsive while VASC builds the current body
  cooperatively. Verify that a newly entered destination is not starved by the
  previous map's border/apron job and that it promotes once, atomically, to 3D.
- Repeat Route 29, Cherrygrove City and Ilex Forest. The Gold RC fixture reduced
  worst draws from 7368.67/314.02/4445.00 ms to
  226.27/162.11/597.07 ms; treat a return to a multi-second current-map draw as
  a release blocker.

- Native START semantics remain edition-authentic and contain exactly one
  public `VASC` row immediately after `OPTION`; its destination uses the shared
  FireRed/LeafGreen Ascendant hub in both editions.
- With `OVERWORLD MENUS=ORAS GLASS`, native dialogue, YES/NO, Pack, Party,
  Pokédex, Pokégear and Mod Manager receive only the shared draw decoration;
  input, pagination and callbacks remain native. Switching to `GAME DEFAULT`
  restores the untouched edition drawing live. No retired Gold/Silver palette
  or controller-HUD prototype may appear in either mode.
- FULL, 15, 35, 50, 75, first-person and third-person views each enter/leave
  cleanly across map connections, doors, caves, surf, bike, ice and ledges.
- Third-person player uses native walk steps/animation and never glides.
- Weather, day/night, panoramas and scenery survive warp, save/load and battle.
- Wild and trainer battles retain native command input, HP bars, text, move
  animation, Pack/Party overlays, send-out/recall/faint and end-of-battle flows.
- Force a voxel render/compose failure during a live battle and verify the
  complete native battle background plus trainer/Pokémon pics return.
- Test `stadium3dSprites` on/off, missing model, corrupt local build and a legal
  local Stadium 2 ROM import. No ROM-derived output may enter the mod ZIP.
- Test with and without `red_3d_player`, including camera-owner switching.
- Android: HiDPI full-frame sizing, touch camera controls, reverse-landscape
  flip, file picker recreation and memory pressure.

## Crystal

Crystal support is architecture-ready but still requires a compatible engine
build and full edition ROM QA. Repeat the Gold/Silver matrix and additionally
verify the same shared FRLG hub/ORAS drawing contract, Pokégear/phone flows, animated battle
presentation and every Crystal-specific script/transition exposed by the host.
The same cold-map/AUTO checks above are mandatory; Crystal shares the queue,
budget and profile policy but does not inherit Gold's ROM evidence.

## Deferred feature

Overworld capture remains disabled until Gold, Silver and Crystal each pass
inventory consumption, ball selection, cancel/failure/success, save persistence,
trainer interruption, map transition and touch/controller QA.
