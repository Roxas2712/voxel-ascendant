VOXEL ASCENDANT 2.0.1 - ADD YOUR OWN MUSIC (ENGLISH)
====================================================

VASC does not ship copyrighted replacement music. These folders are a local,
user-controlled interface. Your files remain in your own installation.

QUICK SETUP
-----------
1. Close the game before copying or renaming files.
2. Open the installed VASC folder, then user/music/.
3. Copy MP3, OGG, WAV or FLAC files into the matching category folder.
4. Start the game and open VASC -> USER MUSIC -> RESCAN FOLDERS.
5. Turn CUSTOM MUSIC ON.
6. Open a category and choose ORIGINAL, SHUFFLE, or one named file.

SHUFFLE chooses a track again for each matching battle or cue and avoids an
immediate repeat when more than one valid file exists. If a file is missing,
invalid, removed, or cannot be decoded, VASC safely keeps the final Game/KASC
track. VASC uses the normal game music player, including its volume, pause,
resume, and battle-exit behaviour.

CATEGORY FOLDERS
----------------
  wild/        ordinary wild and Safari battles
  trainer/     ordinary trainer battles
  rival/       rival battles
  gym/         Gym Leader battles
  elite4/      Elite Four battles
  champion/    Champion battles
  field/       overworld and map music
  bike/        bicycle music
  surf/        surfing music
  victory/     post-battle victory music
  evolution/   evolution, hatching, and trade evolution
  title/       title-screen music
  halloffame/  Hall of Fame music
  credits/     credits music
  jingle/      short one-shot cues
  scene/       Oak speech, encounters, and other scripted scenes

File names inside category folders are display names only. Examples:
  wild/Johto Wild.mp3
  gym/My Gym Theme.ogg
  field/Night Route.flac

EXACT GAME/KASC SONG REPLACEMENT
--------------------------------
The replace/ folder is the advanced fallback for every music cue that has no
dedicated category. Name the file exactly like the resolved Game/KASC song ID:
  replace/Music_WildBattle.mp3
  replace/<ORIGINAL_SONG_ID>.ogg

The filename stem is case-sensitive on some devices. Only letters, digits,
underscore, dot, and hyphen are accepted for an exact ID. A selected category
track intentionally takes precedence over an exact replacement in the same
category. Open EXACT SONG REPLACEMENTS after a rescan to verify which files
VASC accepted.

RESTORING THE ORIGINAL GAME/KASC MUSIC
--------------------------------------
- In one category, choose ORIGINAL.
- In USER MUSIC, choose BACK TO GAME / KASC to reset all music categories and
  the optional VASC battle-music pack selector.
- In the main VASC menu, choose ALL TO GAME/KASC to reset both music and sprite
  customisation at once.

These actions do not delete your files. Custom music is OFF by default, so a
fresh install always preserves the final cue selected by Game/KASC.

WHERE THE INSTALLED FOLDER IS
-----------------------------
Append this to the active game save directory:
  mods/VOXEL_ASCENDANT/user/music/

Windows:
  %APPDATA%\LOVE\pokemon-love2d\mods\VOXEL_ASCENDANT\user\music\

macOS:
  ~/Library/Application Support/LOVE/pokemon-love2d/mods/
  VOXEL_ASCENDANT/user/music/

Linux:
  ~/.local/share/love/pokemon-love2d/mods/VOXEL_ASCENDANT/user/music/

iPhone/iPad:
  Files -> On My iPhone -> gen1recomp++ -> mods -> VOXEL_ASCENDANT ->
  user -> music
  iOS exposes the app Documents folder directly; there is no additional
  pokemon-love2d folder on current builds.

Android:
  Internal storage/Android/data/com.theboisclub.pokemonred/files/save/
  pokemon-love2d/mods/VOXEL_ASCENDANT/user/music/
  Modern Android may hide Android/data from its stock Files app. Use a USB
  connection or a file manager that can access the app's external-files
  directory. Do not root the device for VASC.

Nintendo Switch:
  sdmc:/switch/gen1recomp/pokemon-love2d/mods/VOXEL_ASCENDANT/user/music/

Xbox Dev Mode:
  Gen1Recomp/LocalState/pokemon-love2d/mods/VOXEL_ASCENDANT/user/music/
  Access LocalState through Xbox Device Portal.

Portable desktop builds may use the mods/ folder beside the executable. Edit
the copy the launcher currently lists as installed. The VASC START help also
shows the platform roots.

UPDATES AND TROUBLESHOOTING
---------------------------
- Back up VOXEL_ASCENDANT/user/ before replacing or updating the whole mod.
- Do not put folders inside a category; scanning is intentionally one level.
- A renamed extension does not convert audio. Use a real MP3/OGG/WAV/FLAC.
- Rescan after every copy, rename, or removal.
- If playback fails, choose ORIGINAL first. The game/KASC cue must still play.
- Never redistribute music unless you have the necessary rights.
