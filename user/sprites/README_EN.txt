VOXEL ASCENDANT 2.0.1 - REPLACE SPRITES LOCALLY (ENGLISH)
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
- Do not redistribute art unless you have the necessary rights.
