local function eq(a, b, message)
  if a ~= b then
    error((message or "mismatch") .. ": " .. tostring(a)
          .. " ~= " .. tostring(b), 2)
  end
end

-- The runtime table must cover the complete authored battle catalog, not
-- merely the gallery's representative cards.  This is the release-facing
-- receipt for all 95 maps and all 111 height/room anchors.
local authored = assert(loadfile("data/battle_arenas.lua"))()
local reviewed = assert(loadfile("data/arena_scenery.lua"))()
local mapCount, anchorCount, reviewedCount = 0, 0, 0
-- Portable ARENA scenery may cover a battle-capable map that deliberately
-- has no MAP-mode anchor.  Viridian City is such a case: Kanto Ascendant can
-- start trainer/rematch fights there, while the base authored arena catalog
-- only contains maps with reviewed voxel-ground placements.
local portableOnly = {
  PALLET_TOWN=true, VIRIDIAN_CITY=true, PEWTER_CITY=true,
  LAVENDER_TOWN=true, VERMILION_CITY=true, CELADON_CITY=true,
  FUCHSIA_CITY=true, INDIGO_PLATEAU=true, SAFFRON_CITY=true,
}
for id, entry in pairs(authored) do
  mapCount = mapCount + 1
  anchorCount = anchorCount
                + ((type(entry.spots) == "table" and #entry.spots) or 1)
  if type(reviewed[id]) ~= "table" then
    error("missing reviewed Arena Scenery for " .. tostring(id))
  end
end
for id, spec in pairs(reviewed) do
  reviewedCount = reviewedCount + 1
  if authored[id] == nil and not portableOnly[id] then
    error("stale reviewed Arena Scenery map " .. tostring(id))
  end
  eq(spec.width, 1280, id .. " width")
  eq(spec.height, 800, id .. " height")
  eq(spec.camera, "3X", id .. " fixed authoring camera")
  eq(type(spec.outdoor), "boolean", id .. " outdoor receipt")
  eq(type(spec.actorScale), "number", id .. " actor scale receipt")
  eq(type(spec.clockTint), "boolean", id .. " clock tint receipt")
  eq(spec.anchors.player.y, -8,
     id .. " player foot stays above the text window")
  eq(spec.anchors.enemy.y, -17,
     id .. " opponent keeps the reviewed upper-right foot")
  if spec.clockTint then
    eq(type(spec.windows), "table", id .. " window region receipt")
    eq(#spec.windows > 0, true, id .. " owns at least one window region")
  else
    eq(spec.windows, nil, id .. " windowless room has no clock mask")
  end
end
eq(mapCount, 95, "authored map count")
eq(reviewedCount, 104,
   "reviewed maps plus nine portable trainer-only towns")
eq(anchorCount, 111, "reviewed anchor count")
eq(reviewed.POKEMON_MANSION_1F.actorScale, 1.55,
   "Mansion uses its reviewed compact-room actor datum")
eq(reviewed.POKEMON_MANSION_1F.anchors.player.x, -9,
   "Mansion gains player-side separation without pushing under the HUD")
eq(reviewed.POKEMON_MANSION_1F.anchors.enemy.x, 5,
   "Mansion keeps the opponent clear of the original right HUD")
eq(reviewed.GAME_CORNER.anchors.player.x, 4,
   "Game Corner moves the player off the cabinet and stool row")
eq(reviewed.GAME_CORNER.anchors.enemy.x, 12,
   "Game Corner keeps the opponent separated on the clear carpet")
eq(reviewed.SS_ANNE_2F.clockTint, true,
   "the corridor portholes follow the shared overworld clock")

local made, reads = {}, {}
local assetWidth, assetHeight = 1280, 800
local uploadFails = false
local Assets = {}

function Assets.imageData(path)
  reads[#reads + 1] = path
  local data = { w=assetWidth, h=assetHeight, released=false }
  function data:getDimensions() return self.w, self.h end
  function data:release() self.released=true end
  return data
end

package.loaded["src.render.Assets"] = Assets
love = {
  graphics = {
    newImage = function(data)
      if uploadFails then error("synthetic upload failure") end
      local image = { data=data, released=false }
      function image:setFilter(min, mag) self.filter={min,mag} end
      function image:setWrap(x, y) self.wrap={x,y} end
      function image:getDimensions() return data.w, data.h end
      function image:release() self.released=true end
      made[#made + 1] = image
      return image
    end,
  },
}

local drawReceipt, windowReceipt = nil, nil
local clockTint = {.4,.6,.8}
local modules = {
  Mat4 = {
    mul=function(a,b) return {a,b} end,
    translate=function(...) return {...} end,
    scale=function(...) return {...} end,
  },
  Voxel3D = {
    tint={.7,.8,.9},
    newMesh=function() return {} end,
    backdrop=function(image, tint)
      drawReceipt={image=image,tint=tint}
      return true
    end,
    backdropWindows=function(scene, regions, width, height)
      windowReceipt={scene=scene,tint=scene.tint,
                     regions=regions,width=width,height=height}
      return true
    end,
    seams=function() end, glass=function() end, draw=function() end,
  },
  DayNight = {
    tint=function(outdoor)
      if not outdoor then return {1,1,1} end
      return clockTint
    end,
  },
}
local V = {
  path="/reviewed-mod",
  require=function(name) return assert(modules[name], name) end,
  data=function(name)
    if name ~= "arena_scenery" then return {} end
    local anchors = {
      player={x=0,y=-8,z=0}, enemy={x=0,y=-17,z=0},
    }
    return {
      ROUTE_2={path="assets/battle/arena_route2.compact.png",
               width=1280,height=800,camera="3X",outdoor=true,
               actorScale=1,clockTint=false,
               anchors=anchors},
      VIRIDIAN_CITY={path="assets/battle/arena_grass-route1.compact.png",
                     width=1280,height=800,camera="3X",outdoor=true,
                     actorScale=1,clockTint=false,
                     anchors=anchors},
      OAKS_LAB={path="assets/battle/arena_lab.compact.png",
                width=1280,height=800,camera="3X",outdoor=false,
                actorScale=2.1,clockTint=true,
                windows={{shape="rect",x=700,y=20,w=100,h=160,
                          tintScale=.55,alphaScale=.45,starsScale=.25,
                          moon=false}},
                anchors={player={x=-7,y=-8,z=0},
                         enemy={x=7,y=-17,z=0}}},
      ROUTE_3={path="assets/battle/arena_bad.compact.png",
               width=1280,height=800,camera="3X",outdoor=true,
               actorScale=1,clockTint=false,
               anchors={player={x=0/0,y=-8,z=0},enemy=anchors.enemy}},
    }
  end,
}
local Stage = assert(loadfile("lib/VoxelBattleStage.lua"))(V)

local profiles = assert(loadfile("lib/BattleArenaStyle.lua"))({
  data=function() return {} end,
}).PROFILES
local function arena(id, profile, variant, mapId)
  return { arenaStyle={ id=id, profile=profile, variant=variant,
                        seed=12345, mapId=mapId }, mid={16,16},
           player={8,24}, enemy={24,8}, discs=true }
end

local nugget = arena("nugget_bridge", profiles.nugget_bridge, "r24:1:0")
eq(Stage.hasAuthoredBackdrop(nugget), true,
   "Nugget Bridge owns reviewed Arena Scenery")
eq(Stage.presentationGroundY(nugget, "player", 12), 4,
   "player uses the reviewed dry-foreground anchor")
eq(Stage.presentationGroundY(nugget, "enemy", 12), -5,
   "enemy uses the fixed authored 3X painterly-bank anchor")
local px, py, pz = Stage.presentationPosition(nugget, "player", 12)
eq(px, 8, "player keeps its reviewed horizontal anchor")
eq(py, 4, "player uses its reviewed vertical anchor")
eq(pz, 24, "player keeps its reviewed depth anchor")
local ex, ey, ez = Stage.presentationPosition(nugget, "enemy", 12)
eq(ex, 24, "enemy keeps its reviewed horizontal anchor")
eq(ey, -5, "enemy uses its reviewed vertical anchor")
eq(ez, 8, "enemy keeps its reviewed depth anchor")
local art = assert(Stage.backdropFor(nugget, true))
eq(reads[1],
   "/reviewed-mod/assets/battle/nugget_bridge_a.compact.png",
   "runtime reads only the allowlisted compact asset")
eq(art.data.w, 1280, "Arena Scenery width")
eq(art.data.h, 800, "Arena Scenery height")
eq(art.data.released, true, "source ImageData released after upload")
eq(art.filter[1], "linear", "painterly Arena Scenery keeps smooth filtering")
eq(art.wrap[1], "clamp", "Arena Scenery cannot wrap at frame edges")
eq(Stage.backdropFor(nugget, true), art, "same place reuses cached art")
eq(#reads, 1, "cache avoids repeated asset reads")

local route2 = arena("route2_gate", profiles.route2_gate, "r2:1:0", "ROUTE_2")
eq(Stage.hasAuthoredBackdrop(route2), true,
   "a reviewed map-id owns its selected Arena Scenery")
eq(Stage.presentationGroundY(route2, "enemy", 12), -5,
   "reviewed maps reuse the fixed authored 3X footing")
local route2Art = assert(Stage.backdropFor(route2, true))
eq(reads[2], "/reviewed-mod/assets/battle/arena_route2.compact.png",
   "reviewed outdoor map reads its exact selected asset")
eq(Stage.backdropFor(route2, false), nil,
   "outdoor reviewed art cannot masquerade as an interior")

local lab = arena("interior", profiles.interior, "lab:1:0", "OAKS_LAB")
eq(Stage.hasAuthoredBackdrop(lab), true,
   "reviewed indoor map owns its selected Arena Scenery")
eq(Stage.presentationScale(lab), 2.1,
   "compact lab enlarges cards around their fixed feet")
local labPX = Stage.presentationPosition(lab, "player", 12)
local labEX = Stage.presentationPosition(lab, "enemy", 12)
eq(labPX, 1, "compact lab shifts the player left from the shared centre")
eq(labEX, 31, "compact lab shifts the opponent right from the shared centre")
local labArt = assert(Stage.backdropFor(lab, false))
eq(reads[3], "/reviewed-mod/assets/battle/arena_lab.compact.png",
   "reviewed interior reads its exact selected asset")
eq(Stage.backdropFor(lab, true), nil,
   "interior reviewed art remains neutral and cannot enter outdoor tinting")
local labTint = Stage.presentationTint(lab)
eq(labTint, modules.Voxel3D.tint,
   "windowed room keeps its authored neutral artificial light")
eq(Stage.presentationWindowTint(lab), clockTint,
   "the exterior glass follows the shared continuous world clock")
eq(Stage.drawBackdrop(lab, false, labArt), true,
   "windowed interior draws its prepared art")
eq(drawReceipt.tint, labTint,
   "windowed interior base is not globally clock tinted")
eq(windowReceipt.tint, clockTint,
   "only reviewed glass receives the clock-derived tint")
eq(windowReceipt.width, 1280, "window mask uses authored source width")
eq(windowReceipt.height, 800, "window mask uses authored source height")

local viridian = arena("city", profiles.city, "viridian:trainer:0",
                       "VIRIDIAN_CITY")
eq(Stage.hasAuthoredBackdrop(viridian), true,
   "Viridian trainer fights own portable Arena Scenery")
eq(Stage.presentationScale(viridian), 1,
   "outdoor trainer scenery keeps the historical actor size")
local viridianArt = assert(Stage.backdropFor(viridian, true))
eq(reads[4], "/reviewed-mod/assets/battle/arena_grass-route1.compact.png",
   "Viridian trainer fight reads the reviewed southern-city meadow")

local unknown = arena("grass", profiles.grass, "unknown:1:0", "UNKNOWN_MAP")
eq(Stage.hasAuthoredBackdrop(unknown), false,
   "unreviewed places cannot claim authored art")
eq(Stage.presentationScale(unknown), 1,
   "unreviewed places keep the historical actor size")
eq(Stage.presentationGroundY(unknown, "enemy", 12), 12,
   "MAP/DISCS and unreviewed ARENAs keep historical anchors")
eq(Stage.backdropFor(unknown, true), nil,
   "unreviewed place declines rather than generating a collage")

-- The reviewed table is an ARENA-only presentation contract.  A portable
-- DISCS fight and an ordinary MAP/voxel fight carry no arenaStyle, even on a
-- map such as GAME_CORNER whose ARENA has bespoke carpet footing.  They must
-- therefore keep the engine's original positions and 1:1 card scale.
local nonArenaGameCorner = {
  mid={16,16}, player={8,24}, enemy={24,8}, discs=true,
  map={ id="GAME_CORNER" },
}
eq(Stage.hasAuthoredBackdrop(nonArenaGameCorner), false,
   "DISCS cannot opt into GAME_CORNER Arena Scenery by map id alone")
eq(Stage.presentationScale(nonArenaGameCorner), 1,
   "DISCS keeps the original 1:1 card scale")
local discPX, discPY, discPZ = Stage.presentationPosition(
  nonArenaGameCorner, "player", 12)
eq(discPX, 8, "DISCS keeps the original player X")
eq(discPY, 12, "DISCS keeps the original player ground height")
eq(discPZ, 24, "DISCS keeps the original player Z")

local malformed = arena("moon_approach", profiles.moon_approach,
                        "bad:1:0", "ROUTE_3")
eq(Stage.hasAuthoredBackdrop(malformed), false,
   "non-finite reviewed anchors fail closed")
eq(Stage.backdropFor(malformed, true), nil,
   "malformed reviewed records never touch an asset")
eq(Stage.backdropFor(nugget, false), nil,
   "outdoor art cannot masquerade as an interior")
eq(#reads, 4, "declined places never touch an asset")

eq(Stage.drawBackdrop(nugget, true, art), true,
   "ARENA hands its prepared art to the scene")
eq(drawReceipt.image, art, "draw uses the prepared image")
eq(drawReceipt.tint, modules.Voxel3D.tint,
   "Arena Scenery follows the same day/night tint as its actors")

Stage.invalidate()
eq(art.released, true, "invalidate releases the retained artwork")
eq(route2Art.released, true, "invalidate releases reviewed outdoor artwork")
eq(labArt.released, true, "invalidate releases reviewed indoor artwork")
eq(viridianArt.released, true,
   "invalidate releases Viridian trainer artwork")

assetWidth = 1279
eq(Stage.backdropFor(nugget, true), nil,
   "wrong dimensions fail closed")
local failedReads = #reads
assetWidth = 1280
eq(Stage.backdropFor(nugget, true), nil,
   "a malformed asset stays declined until explicit invalidation")
eq(#reads, failedReads, "failed asset is not hammered every frame")

Stage.invalidate()
uploadFails = true
eq(Stage.backdropFor(nugget, true), nil, "upload failure fails closed")
Stage.invalidate()
uploadFails = false
local recovered = assert(Stage.backdropFor(nugget, true))
eq(recovered.data.w, 1280, "invalidate permits a clean retry")
Stage.invalidate()
eq(recovered.released, true, "retry artwork also releases cleanly")

package.loaded["src.render.Assets"] = nil
print("battle arena backdrop: ok")
