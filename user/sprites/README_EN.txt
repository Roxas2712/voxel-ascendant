VOXEL ASCENDANT 2.0.12 - REPLACE SPRITES LOCALLY (ENGLISH)
========================================================

VASC ships no replacement sprites. It only provides a local, fail-open hook:
valid files can replace the final sprite selected by Game/KASC; missing,
invalid, disabled, or removed files always return that original sprite.

QUICK SETUP
-----------
1. Close the game before copying or renaming PNG files.
2. Open the installed VASC folder, then user/sprites/.
3. Put each PNG in the matching folder using the exact name described below.
4. Start the game and open VASC -> USER SPRITES -> RESCAN PNG FILES.
5. Turn CUSTOM SPRITES ON.
6. Open README + INDEX in the menu to see IDs from the currently loaded Game,
   KASC, and other compatible mods.

Accepted files are real PNG images from 1x1 through 4096x4096 pixels. Use a
transparent canvas and keep the subject's feet/baseline consistent with the
sprite being replaced. VASC does not rewrite your art. For animated overworld
sheets, keep the original sheet dimensions, frame grid, direction order, and
transparent padding or movement animations will be cut or misaligned.

CANVAS, SCALE AND GROUND ANCHORS
--------------------------------
There is deliberately no universal 16x16 or 32x32 requirement. Copy the exact
canvas dimensions and transparent padding of the final Game/KASC image you are
replacing. A Crystal-HD trainer may therefore be much larger than a native
Gen-I trainer while both are valid.

For a battle front or back picture:
- keep every visible pixel inside the PNG canvas;
- leave transparent space above the subject, not below its feet;
- place both feet/lowest contact pixels on one clear final visible row;
- do not paint a floor, drop shadow, opaque white background, or pre-skew;
- keep front and back pictures at a mutually believable visual scale.

VASC measures the visible alpha bounds, preserves the source's physical size,
and anchors the lowest visible row to the reviewed battle footing. This is what
keeps native, retro and KASC-HD art from sinking into MAP terrain, ARENA
paintings or DISCS. Large Pokemon can make the MAP/DISCS camera widen slightly
at 1X so their complete silhouettes remain visible; this does not rewrite the
saved camera setting.

POKEMON
-------
Battle, Dex, party icon, and overworld targets use uppercase canonical IDs:
  pokemon/front/PIKACHU.png
  pokemon/back/PIKACHU.png
  pokemon/dex/PIKACHU.png
  pokemon/icons/PIKACHU.png
  pokemon/overworld/PIKACHU.png

Forms are checked before the base species. Examples:
  pokemon/front/CHARIZARD_MEGA_X.png
  pokemon/front/CHARIZARD_MEGA_Y.png
  pokemon/front/MEWTWO_MEGA_Y.png
  pokemon/front/VENUSAUR_MEGA.png
  pokemon/front/PIKACHU_SHINY.png
  pokemon/front/UNOWN_A.png

KASC may keep mon.species at CHARIZARD and expose CHARIZARD_X only as live
form state. VASC resolves that as CHARIZARD_MEGA_X first, then CHARIZARD_X,
then CHARIZARD. Single-form Megas use <SPECIES>_MEGA. Shiny candidates use
<FORM>_SHINY before the normal form. This order lets one base file remain a
safe fallback for every missing special form.

PLAYER AND TRAINER BATTLE ART
-----------------------------
Player battle positions:
  player/battle_front.png
  player/battle_back.png
Generic fallbacks:
  player/front.png
  player/back.png

Enemy trainer portraits use their canonical class ID:
  trainers/OPP_RIVAL2.png
  trainers/OPP_BROCK.png
  trainers/OPP_ROCKET.png
  trainers/OPP_LORELEI.png
  trainers/OPP_BRUNO.png
  trainers/OPP_AGATHA.png
  trainers/OPP_LANCE.png

RED, BLUE, GREEN, RIVALS AND KASC ART
------------------------------------
VASC asks the game and optional mods for their final selected picture first.
Therefore Red, Blue, Green, rivals, ordinary trainers and the Elite Four keep
their native or KASC-selected art when no loose override exists. VASC does not
copy KASC code and does not require KASC.

SAVED POSITION AND SIZE INSIDE VASC
-----------------------------------
Open VOXEL ASCENDANT -> BATTLE -> BATTLE LAYOUT. This is a normal VASC runtime
feature; the separate desktop layout editor is optional. Select TARGET first,
then adjust X, Y and SIZE. Separate saved targets exist for player front,
modern player back, retro half-back, Mega, enemy Pokemon, player trainer front,
player trainer back, enemy trainer, both status cards, both team rows, command
and message zones. RESET ONE affects only the selected target. RESET ALL
returns every target to the reviewed automatic 0 / 0 / 100% composition.

These values adjust presentation after the final sprite provider has selected
its image. They do not rewrite a PNG and never change a KASC option or file.
Use them for small personal corrections; keep the default values when judging
whether a source image has the correct transparent canvas and foot baseline.

The two player/ files above are global final-player overrides. They are not a
Red/Blue/Green selector: if you install player/battle_front.png, that one file
replaces whichever player picture the current Game/KASC setup selected. Enemy
trainers can be replaced individually through trainers/<CLASS_ID>.png.

For acceptance, inspect each relevant trainer once in all enabled battle
stages:
  MAP   - feet must touch walkable terrain and remain fully visible.
  DISCS - feet must touch the projected disk, never the clear colour behind it.
  ARENA - feet must match the authored foreground footing and never be cropped.

Also test TRAINER BACK OFF and ON. OFF uses the standing final front art in the
3D scene; ON places the real classic rear-view throw picture on that same
reviewed 3D player ground mark. It therefore remains separate from the foe and
cannot cover it in ARENA/portrait layouts. These are presentation choices, not
different sprite file formats.

POKEMON FRONT/BACK AND MEGA FORMS
--------------------------------
Test every custom battle Pokemon in both presentation modes:
- PKMN BACK OFF: both Pokemon stand on reviewed world/arena/disk footings.
- PKMN BACK ON: the player's real back picture stands on the same reviewed 3D
  footing and uses the same physical-size cap as its front view; the opponent
  remains on its own footing. No rear returns to the oversized lower slot.

Do this for a normal-sized species, a very large species, and every supplied
Mega form. Mega filenames follow the form lookup shown above. If a Mega file is
missing, VASC passes through the animated final Game/KASC image rather than
showing a blank card or silently substituting unrelated art.

OVERWORLD SHEETS, INCLUDING KASC STATES
---------------------------------------
Readable registered sprite IDs are preferred:
  overworld/SPRITE_RED.png
  overworld/SPRITE_RED_BIKE.png
  overworld/SPRITE_KA_CRYSTAL_GREEN_WALK.png
  overworld/SPRITE_KA_CRYSTAL_GREEN_BIKE.png
  overworld/SPRITE_KA_CRYSTAL_GREEN_FISH.png

This is how a KASC-specific bicycle, fishing, surfing, walking, or other state
can be changed without altering KASC. For old or anonymous sheets, VASC also
supports a stable source-key filename. README + INDEX displays both the
readable target and its source fallback for the current loaded mod stack.

RESTORING GAME/KASC
-------------------
- CUSTOM SPRITES OFF bypasses all loose sprite files.
- BACK TO GAME / KASC also selects VASC's base sprite-pack mode.
- ALL TO GAME/KASC in the main VASC menu resets music and sprites together.

No reset action deletes files. Custom sprites are OFF by default. Therefore
KASC remains protected and is always the normal fallback.

WHERE THE INSTALLED FOLDER IS
-----------------------------
Append this to the active game save directory:
  mods/VOXEL_ASCENDANT/user/sprites/

Windows:
  %APPDATA%\LOVE\pokemon-love2d\mods\VOXEL_ASCENDANT\user\sprites\

macOS:
  ~/Library/Application Support/LOVE/pokemon-love2d/mods/
  VOXEL_ASCENDANT/user/sprites/

Linux:
  ~/.local/share/love/pokemon-love2d/mods/VOXEL_ASCENDANT/user/sprites/

iPhone/iPad:
  Files -> On My iPhone -> gen1recomp++ -> mods -> VOXEL_ASCENDANT ->
  user -> sprites
  Current iOS builds expose Documents directly; do not add pokemon-love2d.

Android:
  Internal storage/Android/data/com.theboisclub.pokemonred/files/save/
  pokemon-love2d/mods/VOXEL_ASCENDANT/user/sprites/
  Modern Android may hide Android/data. Use USB or a file manager that can
  access the app's external-files directory. Root is not required.

Nintendo Switch:
  sdmc:/switch/gen1recomp/pokemon-love2d/mods/VOXEL_ASCENDANT/user/sprites/

Xbox Dev Mode:
  Gen1Recomp/LocalState/pokemon-love2d/mods/VOXEL_ASCENDANT/user/sprites/
  Access LocalState through Xbox Device Portal.

Portable desktop builds may use the mods/ folder beside the executable. Edit
the copy the launcher currently lists as installed. VASC START help also lists
the platform roots.

UPDATES AND TROUBLESHOOTING
---------------------------
- Back up VOXEL_ASCENDANT/user/ before replacing or updating the whole mod.
- Names use A-Z, 0-9, underscore, and hyphen after canonicalisation.
- Rescan after every copy, rename, or removal.
- A file that opens in a browser may still be malformed; export it as a real
  PNG again if VASC rejects it.
- If scale, facing, or animation is wrong, compare canvas, transparent padding,
  and frame layout to the exact Game/KASC source being replaced.
- If a figure appears sunk into the floor, remove transparent rows below the
  feet and confirm that no shadow/floor pixels extend below the intended sole.
- If a figure is too small or too large, compare against the final selected
  native/KASC canvas, not a Discord preview or a browser-scaled screenshot.
- If a trainer is invisible, temporarily disable CUSTOM SPRITES. If the
  Game/KASC fallback appears, the local filename or PNG is wrong; if it does
  not, record the battle stage, trainer class ID and TRAINER BACK value.
- If a Pokemon back picture is missing, verify pokemon/back/<SPECIES>.png and
  PKMN BACK ON. Front files do not replace the selected rear-art source.
- Always check portrait and landscape once on iPhone/Android after changing
  canvas padding; rotation changes HUD placement, not the sprite's baseline.
- Do not redistribute art unless you have the necessary rights.

RELEASE-ACCEPTANCE CHECKLIST
----------------------------
[ ] Native/retro front pictures in MAP, DISCS and several ARENAs
[ ] Native/retro Pokemon back pictures with PKMN BACK ON
[ ] Final KASC front and back pictures (when KASC is installed)
[ ] Red, Blue, Green and rival fronts with TRAINER BACK OFF
[ ] Trainer rear throw picture with TRAINER BACK ON
[ ] Ordinary trainer, Gym Leader and all four Elite Four classes
[ ] Normal, fainted and empty party-ball receipts remain readable
[ ] Large Pokemon and Mega forms are complete at 1X, 2X, 3X and ARENA camera
[ ] No feet below terrain/disk/arena footing; no head or wing crop
[ ] HUD/text remains readable at 35-80% alpha in portrait and landscape
