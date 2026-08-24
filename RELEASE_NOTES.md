# Voxel Ascendant 2.0.2

This compatibility hotfix restores startup on Gen1Recomp 0.2.22, where the
engine replaced `src.render.GBCFX` with `src.render.ShaderFX`. VASC now detects
either API once, disables the applicable final-frame effect while its voxel
presentation is active, and preserves saved ShaderFX preset choices for use
when VASC is disabled. Gen1Recomp 0.2.19 remains supported.

This corrective RC retains the full 2.0 presentation while closing the first
device and community findings: ARENA presentation orientation is normalized,
Mega and large battle sprites use form-aware grounding and separation, iOS
canvas presentation is guarded, precipitation/fog are restrained, and city
shadows are capped instead of producing oversized dark masses. Outdoor ARENA
nights now show a real cratered moon and varied stars through the scenery's
transparent skyline; reviewed interior windows follow the same smooth
dawn/day/dusk/night state without tinting opaque walls or greenhouse panes as
open sky.

The VASC menu now includes START help even without Kanto Ascendant. Users can
drop their own music into seven category folders and select ORIGINAL, SHUFFLE
or an exact local file. PNG replacement folders cover Pokemon front/back/Dex/
icons/overworld, the player, enemy trainer portraits and generic overworld
sprites. No third-party music or replacement sprite is bundled.

VASC 2.0.2 also contains the additive visual half of KASC 6.7's future
Cinnabar south fork. Only a complete outdoor, reciprocal map graph activates
it: the volcanic destination is fixed on the left and the Deoxys/Birth-Island
research coast directly beside it on the right. The two transparent cut-outs
share one compact 256-KiB atlas and one draw. Existing KASC builds, partial
hot-patches, missing art and malformed offsets retain the current Cinnabar
coast with no movement, collision, warp, NPC or quest change.

This major update substantially expands the outdoor and enclosed-world presentation
and shortens the long catch-up path when voxel maps become visible. Visual
release acceptance remains evidence-driven; the packaged contract tests do not
by themselves certify every route, cave or transition viewpoint.

This RC also fixes a Gen1Recomp 0.2.19 zero-fade ownership change that could
leave `transitioning` set forever after Fly reached a cold 3D destination.
The existing dynamic reveal gate remains intact: it releases immediately when
the complete destination is ready rather than adding a fixed delay. Dedicated
`V` and mapped right-trigger (`ZR`/`R2`/`RT`) shortcuts now cycle the same
camera ladder as the retained `3` and SELECT aliases.

Kanto now has a switchable banded sky with sun and pixel clouds. The saved
DAYTIME control includes a color-coordinated 20-minute CYCLE; nights add the
moon, stars and occasional shooting stars. WEATHER can stay CLEAR, choose
stable AUTO spells, or force lightweight RAIN, SNOW, FOG or STORM. Fog uses a
small fixed set of drifting haze bands; storms add denser rain and rare,
deterministic lightning pulses. Every active effect carries into staged
outdoor battles, while indoor fights stay clear. SKY, CLOUDS, WEATHER and
SCENERY remain independently switchable for performance-sensitive devices.
Clouds, stars, shooting stars and every celestial body are fixed to world
bearings in both orbit and freely turning cameras instead of rotating with the
screen. The separate SKY EVENTS ladder enables rare rainbows and distant sky
life together, by class, or not at all. Ordinary windows rotate Pidgey,
Pidgeotto, Pidgeot, Spearow, Fearow and Murkrow through solo flights or compact
formations; Articuno, Zapdos, Moltres and Ho-Oh are much rarer and always fly
alone. Idle/OFF frames issue no event draw calls and the rare cadence persists
with the save.

Outdoor worlds and MAP battles now share an original, player- or arena-centred
Kanto distance panorama behind the real streamed maps. It supplies a coherent
far forest, town, memorial-tower, mountain and coast silhouette without
stretching the final map tile or packing the near edge with artificial land.
The existing 16px edge breathing room, water continuation, foreground trees,
reviewed map-aware edge curtain, authored landmarks and connected map bodies
remain in front; the panorama never replaces that near composition. The battle-camera
1X/2X/3X rigs are unchanged; 3X remains the default and widest view. Interiors
and DISCS battles do not draw this outdoor layer, and any asset/graphics
failure retains the previous horizon wall.
The retained panorama is a deliberately compact 1024×192 nearest-filtered
texture: 768 KiB of GPU storage rather than the visually equivalent 3 MiB
prototype. It is decoded lazily on the first outdoor SCENERY=FULL frame,
cached across ordinary map/interior changes, and released when SCENERY is
turned OFF.

Map edges no longer enlarge an arbitrary border tile into wallpaper. A small
cached transparent skyline supplies layered, varied trees, water reeds,
stepped mountain ridges or stratified cave rock according to the map. It
replaces the expensive carved border ring on semantic outdoor/cave maps,
remains visible from first/third-person and elevated orbit cameras, and uses
32px connection-aligned panels. A separately tiled canopy/ground surface and
four corner caps prevent the stretched horizontal strips and open high-view
corners of the earlier implementation. This also avoids turning Route 23
statues or transition art into giant repeated walls.
Tree silhouettes use a coarse outlined pixel grid and a one-device-pixel,
nearest-filtered source without MSAA or mipmaps, preventing isolated distant
forest panels from becoming soft on high-DPI displays.
Viridian Forest now closes its former black void with a muted canopy colour
derived from the active time of day. The canopy never exposes open-sky bodies,
but remains an outdoor weather space for fog, rain, snow and thunderstorms,
including staged battles inside the forest.
South and west of Cinnabar, and along the adjoining sea routes, unconnected
water edges now continue as a curved, reflective open ocean instead of a
procedural mountain/tree barricade.
The sparse distant South Sea motifs now use irregular V3 rock feet and
transparent gaps rather than a continuous foam/water baseline. Route 19,
Route 20, Route 21 and Cinnabar still own exactly one distinct motif each;
Dock and the SS Anne bow retain their established lighthouse/skerry reuse.
The replacement keeps the same single 512x128 texture, one aggregated draw
and curve-safe coastal mesh. Transparent atlas padding is excluded from the
billboard UVs, so visible pixels now map one-to-one into world space instead
of being anisotropically squeezed with the complete 128px module.

Semantic caves and all Pokemon Tower floors now close above the camera with a
160px enclosure and a downward-facing ceiling tessellated on the same 32px
WorldCurve grid as the world. Cave tilesets select this path even for future or
renamed maps; Mt Moon's named Pokecenter and Rock Tunnel's Pokecenter are kept
as indoor rooms. Pokemon Tower replaces the previous small repeated brick and
panel stamps with one shared opaque two-bay wall and broad coffered ceiling,
without adding a third draw or changing collision. Missing package art fails
closed to the old opaque material rather than revealing the clear colour.

Open-sky routes, towns and mountain regions now share a fixed distant Kanto
ridge behind their local foreground instead of carrying the scenery with the
camera. Route 1 and Viridian replace the two raised green side slabs with a
compact low-rise town edge, distant sprite trees and two sparse rows of real
batched voxel trees. The sheltered Viridian Forest canopy, caves, interiors
and the southern open sea intentionally do not receive an implausible mountain
backdrop.

PRELOAD safely warms the current map and its connected neighbours while voxel
mode is off. It is RAM-only, bounded to the live/previous neighbourhood and
generation-checked: map edits invalidate derived meshes and no stale cache is
written to disk. Repeated forest, grass and building geometry is retained as a
small set of shared templates plus instance offsets instead of hundreds of
thousands of expanded Lua quads. Connected maps rotate through the available
frame budget, and route-sized indexed GPU conversion is split into
1,024-vertex upload pages instead of one uninterruptible main-thread call.
The renderer keeps showing the complete 2D world until current terrain, grass,
flowers, figures, exact atlas/mask and panorama are drawable together. The
finished 3D scene then appears in one swap without freezing the transition or
letting decoration pop in later. A separate bounded loading budget keeps that
fallback responsive; only a real fade or menu uses the larger covered-frame
budget.

One-way ledges now also shape the visible land. Their authored lip tile already
stands 6px high, so it stays on the lower base while the plateau behind it is
raised. This makes stacked Route 4 terraces meet cleanly at 18/12/6/0px instead
of producing accidental double-height teeth. Terrain, shores, buildings,
vegetation, figures, entities, camera grounding and shadows use one immutable
snapshot; collision and the engine's jump rules are untouched.

Outdoor building backs now synthesize their wall from a repeated clean 8x8
source tile. Arbitrary front windows and signs can no longer leak onto that
wall. Door-bearing OVERWORLD and FOREST templates then restore their own
unambiguous native 2x2 door course on the rear facade. Route 2 and Cerulean use
their already-authored aligned rear warps; the other matching houses receive
only the visual counterpart and never invent collision or a destination.
Indoor furniture keeps its authored historical behaviour.

The trainer-front repair is also updated for Kanto Ascendant 6.7's live sprite
hooks. TRAINER BACK and PKMN BACK remain independent, and 1ST/3RD, battle grid
and shadow controls from 0.1.7/0.1.6 remain intact.

Staged fights also gain a saved **BTL CAM** distance. 1X is the close view, 2X
the middle ground and 3X the default wide view for new saves. FULL never
overwrites an existing choice. Q/E, mouse wheel and pinch still fine-tune the
live camera up to 3X after the setting is applied; the original 2D battle
screen and HUD are untouched.

The new opt-in **ARENA** battle rung supplies 46 independently painted Kanto
locations across all 111 reviewed battle anchors and supported city trainer
fights. ARENA alone uses per-location 3X footing and reviewed indoor scale;
MAP, DISCS, their floor plates and the classic battle retain their existing
positions and sizes. The ARENA CAM row offers a fixed 3X composition or the
STADIUM director. Outdoor scenery keeps the live sky, and rooms with real
windows follow the overworld's smooth AUTO/day/night/dawn/dusk tint without
turning windowless interiors blue or dark.

When Kanto Ascendant is active, its public ASCENDANT collector now receives a
single **VOXEL ASCENDANT** row that opens the normal VASC settings. Discovery
is runtime-only: KASC remains optional and its bundle is not modified.

The opt-in **USER MUSIC** row scans local MP3, OGG, WAV and FLAC files live.
KASC-style submenus group wild, trainer, rival, Gym, Elite Four, Champion,
field, bicycle, surf, victory, evolution, title, Hall of Fame, credits,
jingles and scripted scenes. `replace/<ORIGINAL_SONG_ID>.<ext>` can replace
any additional resolved Game/KASC cue without adding another option row.
ORIGINAL/SHUFFLE/exact-file choices remain independent by category.

The opt-in **USER SPRITES** row resolves readable PNG names for every Pokémon
front/back/Dex/icon/overworld role, KASC Mega aliases such as
`CHARIZARD_MEGA_X`, player battle art, enemy trainers, and registered
Game/KASC overworld sheets such as `SPRITE_KA_CRYSTAL_GREEN_BIKE`. Both user
systems default to and can return immediately to **GAME/KASC**, bypassing all
VASC replacement providers without deleting personal files. Version 2.0.2
also adds one global **ALL TO GAME/KASC** action and detailed English/German
guides inside both user folders, including the installed paths for Windows,
macOS, Linux, iOS, Android, Switch and Xbox. It contains no third-party
soundtrack, sprite pack or network downloader.
