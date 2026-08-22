-- Voxel world mode: turn a map's tile layer into one static 3D mesh.
--
-- The scene description comes from Structures.lua, which -- 3dSen-style --
-- detects each connected drawn thing on the map and picks its model:
--
--   flat      ground / water / void: a single quad.
--   top art   ledges, roofs (profile-authored): a box with the art on its
--             TOP face; partial side bands crop the art (a 6px ledge face
--             is the bottom of the lip drawing).
--   volume    walls, buildings, tree lines: each column rises to the
--             structure's REAL drawn height (Structures measures it,
--             repeat-aware and region-consistent -- a 6-row house is 48px,
--             a 40-row border forest is rows of 16px trees). The south
--             face folds the full artwork upright, 8px band by band, band
--             k sampling the map row k tiles north; the top wears the
--             structure's top rows.
--   object    small props with a silhouette (plants, signs, lone trees):
--             per-pixel voxel prisms prebuilt by Structures, standing on
--             synthesized ground -- this mesher just emits their quads.
--             Round trees arrive as STAMPS (a shared hull template plus a
--             cell offset) and expand here, straight into the vertex
--             stream, so no map retains per-cell copies of its forests.
--
-- Side faces are never stretched: all sides are 8px bands with the art
-- tiled per band and cropped at partial bands.
--
-- Texturing samples the TILESET ATLAS, not a rendered copy of the map. The
-- atlas is 128x48; a map-space canvas covering the biggest routes would be
-- ~5 MB each with up to five live at once (connected maps), which is real
-- memory on the mobile targets. Sampling the atlas costs 24 KB, and costs
-- nothing in fidelity because TerrainAtlas hands back the same atlas
-- TileRenderer draws with -- including the fully recolored one RED++
-- bakes -- so terrain color comes through untouched.
--
-- BUILDS ARE ASYNCHRONOUS. A frame never blocks on meshing: VoxelScene
-- requests what it wants to draw, request() queues a build job, and
-- pump() -- called once a frame from the pipeline's update -- advances
-- the queue inside a few-millisecond budget (BuildBudget suspends the
-- job's coroutine mid-loop when the slice is spent). Until a mesh lands
-- the scene simply draws without it: the engine's flat path while the
-- current map has nothing, the body-only variant while the full one (the
-- border ring) is still cooking, neighbours popping in as they finish.
-- The synchronous get() remains for probes and tests.
--
-- Meshes are cached per map id and EVICTED down to the live set (current
-- map + connected neighbours) whenever that set changes -- setLive()
-- releases far maps' GPU meshes and their Structures analysis, which is
-- what used to grow the heap by gigabytes over a cross-region trek.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Assets = require("src.render.Assets")
local Structures = V.require("Structures")
local TileShape = V.require("TileShape")
local Voxel3D = V.require("Voxel3D")
local LedgeElevation = V.require("LedgeElevation")
local Budget = V.require("BuildBudget")
local ModSetting = V.require("ModSetting")

local ChunkMesher = {}

-- Build the current map and its connected neighbours quietly while voxel mode
-- is still off. This is an in-memory, generation-checked cache: map edits and
-- option changes already invalidate it, and nothing stale survives a restart.
-- Safer than serialising GPU/ROM-derived geometry to disk, while removing the
-- cold-toggle wait in normal play.
ChunkMesher.preloadSetting = ModSetting.new("preload", "PRELOAD",
  { true, false }, { "ON", "OFF" })

-- Ring of border blocks meshed around the body, matching the width
-- TileRenderer draws so the two modes end at the same place.
local RING = 3

-- A sliver of a texel, to keep a quad's sampling inside its own tile.
-- Without any inset the perspective rasteriser lands on a NEIGHBOURING
-- tile's texel along the shared edge and stitches bright seams across the
-- whole map.
--
-- It has to be a sliver and not, as it first was, half a texel. A tile is
-- 8 texels of art across 8 world pixels -- one texel per pixel exactly --
-- and insetting the uv by half a texel at each end squeezes that art into
-- a 7-texel sample range while the quad still covers 8 world pixels. The
-- art then advances 7/8 of a texel per pixel: boundaries drift off the
-- pixel grid, one art pixel gets sampled twice and another never at all.
-- Nothing showed it until the voxel wireframe drew the grid those pixels
-- were supposed to be sitting on. Interpolation error is nowhere near a
-- fiftieth of a texel, so this is as safe against bleed and costs 0.25% of
-- a pixel of drift across a whole tile.
local INSET = 0.02

-- The south face of a volume is the artwork itself, so it draws at full
-- brightness; its top face darkens a touch so the plateau behind a
-- standing drawing reads as depth rather than repeating the same art at
-- the same energy.
local VOLUME_TOP_SHADE = 0.85

-- CAVERN's $3C is authored unlit rock: a real flat body tile at the cave
-- datum, not the $22 fall-through hole. Its atlas art is pure black, however,
-- so a low camera cannot distinguish the existing top quad from missing
-- geometry. Inside the authored map body only, reuse the tileset's own $20
-- dark-floor grain at a near-black shade. The border ring stays $3C-black,
-- and this changes neither shape height nor collision nor geometry count.
local CAVERN_UNLIT_TILE = 0x3c
local CAVERN_SHADOW_FLOOR_TILE = 0x20
local CAVERN_SHADOW_FLOOR_SHADE = 0.22

-- Shared visual dimensions for Structures' nine data-gated outdoor cave
-- mouths.  The quarter-pixel rear/side reveal sits just in front of the
-- generic cliff faces, so the authored art wins depth testing without a
-- coplanar flicker.  Every textured extent after that nudge is still an exact
-- integer number of world pixels and samples the atlas one texel per pixel.
local CAVE_PORTAL_NUDGE = 0.25
local CAVE_PORTAL_DEPTH = 12
local CAVE_PORTAL_HEIGHT = 16
local CAVE_PORTAL_THRESHOLD_DEPTH = 2
local CAVE_PORTAL_THRESHOLD_HEIGHT = 1
local CAVE_PORTAL_ROCK_TILE = 0x11
local CAVE_PORTAL_QUADS = 20
local CAVE_PORTAL_ROUTE4_SHIELD = { [2] = true, [3] = true }
local CAVE_PORTAL_ROUTE4_EXTRA_DEPTH = 8
local CAVE_PORTAL_ROUTE4_SHOULDER_HEIGHT = 8
local CAVE_PORTAL_ROUTE4_QUADS = CAVE_PORTAL_QUADS + 2
local CAVE_PORTAL_ROUTE4_STEP_QUADS = 16
local CAVE_PORTAL_ROUTE4_CHEEK_QUADS = 0
-- The two Route 4 entrances are the only canonical mouths whose rigid ledge
-- datum leaves the terminal proud of its ridge.  V2 is deliberately gated on
-- the already data-proven stamp AND the complete local height signature: a
-- ROM/modded contour keeps the established 12px reveal instead of acquiring
-- a floating Kanto-specific shoulder.  Warp #3 alone has the 16px outer-west
-- ridge needed by the stepped buttress below.
local CAVE_PORTAL_ROUTE4_V2 = {
  [2] = { target = "MT_MOON_1F", base = 12, north = 16,
          west = 6, east = 6 },
  [3] = { target = "MT_MOON_B1F", base = 6, north = 16,
          west = 6, east = 6, northWest = 16, outerWest = 16,
          southWest = 8, steppedWest = true },
}
ChunkMesher._CAVE_PORTAL_QUADS = CAVE_PORTAL_QUADS
ChunkMesher._CAVE_PORTAL_ROUTE4_QUADS = CAVE_PORTAL_ROUTE4_QUADS
ChunkMesher._CAVE_PORTAL_ROUTE4_STEP_QUADS = CAVE_PORTAL_ROUTE4_STEP_QUADS
ChunkMesher._CAVE_PORTAL_ROUTE4_CHEEK_QUADS = CAVE_PORTAL_ROUTE4_CHEEK_QUADS

local cache = {}     -- map id -> { full = mesh|false, body = ..., grass = ... }
local gen = {}       -- map id -> generation, bumped by invalidate/evict
local mapRefs = {}   -- map id -> live instance, for elevation invalidation
local templateFootprints = setmetatable({}, { __mode = "k" })

-- One immutable visual-datum snapshot is shared by every product of a map
-- build: terrain, stamps, auxiliary meshes, figures and VoxelScene.groundAt.
-- LedgeElevation owns the weak cache; retaining only live map instances here
-- lets ChunkMesher's existing edit/eviction invalidation close both caches in
-- the same breath.
local function elevationFor(map)
  if type(map) == "table" and map.id ~= nil then mapRefs[map.id] = map end
  return LedgeElevation.map(map)
end

local function invalidateElevation(mapId)
  if mapId ~= nil then
    local map = mapRefs[mapId]
    if map then LedgeElevation.invalidate(map) end
    mapRefs[mapId] = nil
  else
    LedgeElevation.invalidate()
    mapRefs = {}
  end
end

ChunkMesher.elevation = elevationFor

-- Horizontal neighbours: tile step, face direction id (see Voxel3D).
local SIDES = {
  { 1, 0, 1 },    -- +X east
  { -1, 0, 2 },   -- -X west
  { 0, 1, 5 },    -- +Z south
  { 0, -1, 6 },   -- -Z north
}

local function keyOf(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end

-- ------------------------------------------------------------ vertex sinks

-- A sink accepts quads (4 corners, 4 uv pairs, flat or per-corner shade)
-- and finishes into a drawable mesh. The TABLE sink reproduces the
-- historical pure-Lua output -- geometry() returns its arrays for the
-- headless suite. The asynchronous sink below pages vertices and packs its
-- index data, so no route-sized LOVE table conversion can stop a frame.

local function newTableSink()
  local verts, indices, quads = {}, {}, 0
  return {
    push = function(c, uv, shade)
      local flat = type(shade) ~= "table"
      for i = 1, 4 do
        local cc, t = c[i], uv[i]
        verts[#verts + 1] = { cc[1], cc[2], cc[3], t[1], t[2],
                              flat and shade or shade[i] }
      end
      Voxel3D.pushQuad(indices, quads)
      quads = quads + 1
    end,
    results = function()
      return verts, indices, quads
    end,
    finish = function()
      return Voxel3D.newMesh(verts, indices)
    end,
  }
end

-- The asynchronous builder must not hand LOVE one route-sized Lua table.
-- `love.graphics.newMesh(..., verts, ...)` converts every nested vertex table
-- before it returns, and that conversion cannot yield back to the transition
-- animation.  Forest-heavy routes can carry hundreds of thousands of faces,
-- turning an otherwise budgeted coroutine into one multi-second main-thread
-- stop right at `finish()`.
--
-- Keep geometry generation exactly as sliceable as before, but store its four
-- UNIQUE corners in modest upload pages. Once the final vertex count is known
-- we allocate an empty mesh and feed one page at a time; Budget.check between
-- pages lets pump() return on its deadline. The six indices per quad are
-- packed incrementally into native-endian uint32 strings and handed to LOVE as
-- Data, so setVertexMap performs one raw copy instead of walking a route-sized
-- Lua table. On LOVE 11.5 this retained the single terrain draw call, cut the
-- vertex buffer by one third versus the temporary unindexed path, and made its
-- largest page conversion smaller. Uploaded page references are cleared
-- immediately so incremental GC can reclaim them while later pages yield.
-- geometry(), probes and synchronous get/build retain the historical compact
-- indexed table sink and return shape.
local UPLOAD_QUADS = 256
local UPLOAD_VERTICES = UPLOAD_QUADS * 4
local unpackArgs = table.unpack or unpack

local function newAsyncSink(job)
  local pages, page = {}, {}
  local indexPieces, indexPage = {}, {}
  local vertices, indices, quads = 0, 0, 0

  local function append(cc, t, shade)
    page[#page + 1] = { cc[1], cc[2], cc[3], t[1], t[2], shade }
    vertices = vertices + 1
  end

  local function sealPage()
    if #page == 0 then return end
    if not (love and love.data and love.data.pack) then
      error("packed voxel index data is unavailable", 0)
    end
    -- 256 quads are only 1,536 arguments: safely below LuaJIT's unpack limit,
    -- while the resulting 6 KB string is cheap to concatenate at finish().
    Budget.check()
    local format = "=" .. string.rep("I4", #indexPage)
    local packed = love.data.pack("string", format,
                                  unpackArgs(indexPage, 1, #indexPage))
    pages[#pages + 1] = page
    indexPieces[#indexPieces + 1] = packed
    page, indexPage = {}, {}
    Budget.check()
  end

  return {
    push = function(c, uv, shade)
      local flat = type(shade) ~= "table"
      for i = 1, 4 do
        append(c[i], uv[i], flat and shade or shade[i])
      end
      local base = quads * 4
      indexPage[#indexPage + 1] = base
      indexPage[#indexPage + 1] = base + 1
      indexPage[#indexPage + 1] = base + 2
      indexPage[#indexPage + 1] = base
      indexPage[#indexPage + 1] = base + 2
      indexPage[#indexPage + 1] = base + 3
      indices = indices + 6
      quads = quads + 1
      if quads % UPLOAD_QUADS == 0 then sealPage() end
    end,
    finish = function()
      if vertices == 0 then return nil end
      sealPage()
      if not (love and love.graphics and love.graphics.newMesh
              and love.data and love.data.newByteData) then
        error("voxel mesh allocation is unavailable", 0)
      end

      -- Passing a NUMBER creates only the fixed-size GPU buffer.  Vertex
      -- conversion happens in the bounded setVertices calls below.
      -- Check even when the final quad sealed an exactly-full page earlier:
      -- geometry may have consumed the rest of this slice afterwards, and a
      -- driver allocation must never begin on an already-expired budget.
      Budget.check()
      local ok, mesh = pcall(love.graphics.newMesh, Voxel3D.FORMAT, vertices,
                             "triangles", "static")
      if not ok then error(mesh, 0) end
      if not mesh then error("voxel mesh allocation returned nil", 0) end
      job.partialMeshes = job.partialMeshes or {}
      job.partialMeshes[#job.partialMeshes + 1] = mesh

      local function abandon(message)
        if mesh.release then pcall(mesh.release, mesh) end
        for i, partial in ipairs(job.partialMeshes) do
          if partial == mesh then table.remove(job.partialMeshes, i) break end
        end
        error(message, 0)
      end

      local first = 1
      local pageCount = #pages
      for i = 1, pageCount do
        local upload = pages[i]
        local uploadCount = #upload
        Budget.check()
        local uploaded, uploadErr = pcall(mesh.setVertices, mesh, upload,
                                           first, uploadCount)
        if not uploaded then
          -- A split water build cannot safely land only its terrain half:
          -- water quads were removed from that mesh. Fail the whole job so
          -- finishJob releases any sibling allocation and caches one failure
          -- sentinel instead of presenting a map with holes.
          abandon(uploadErr)
        end
        first = first + uploadCount
        -- Do this before the yield-capable check: cancellation or a long
        -- upload must not keep every already-consumed nested table alive.
        pages[i] = nil
        upload = nil
        -- Check after the driver call too: that is the expensive boundary,
        -- and no second page should begin after it spent the frame's slice.
        Budget.check()
      end

      -- Unlike the old Lua index table this is a compact native byte stream.
      -- Concatenation + Data construction are linear memcpy operations (the
      -- 100k-quad QA case measured below 1ms together on LOVE 11.5), and are
      -- kept adjacent to setVertexMap so cancellation cannot strand Data.
      Budget.check()
      local packed = table.concat(indexPieces)
      indexPieces = {}
      local dataOK, indexData = pcall(love.data.newByteData, packed)
      packed = nil
      if not dataOK then abandon(indexData) end
      if not indexData then abandon("voxel index allocation returned nil") end
      local mapped, mapErr = pcall(mesh.setVertexMap, mesh, indexData,
                                    "uint32", indices)
      if indexData.release then pcall(indexData.release, indexData) end
      indexData = nil
      if not mapped then abandon(mapErr) end
      Budget.check()
      return mesh
    end,
  }
end

ChunkMesher._UPLOAD_VERTICES = UPLOAD_VERTICES

local function newSink()
  return newTableSink()
end

-- -------------------------------------------------------------- geometry

-- Emit the raw geometry for `map` into `sink`. `bodyOnly` skips the
-- border ring -- the shape the 2D path's drawMapOnly has always had: a
-- neighbour map contributes its body, and only the CURRENT map supplies
-- the ring around the view.
--
-- `masks` (full variant only) lists rectangles, in this map's world
-- pixels, where connected neighbour BODIES sit: ring geometry inside them
-- is suppressed. The 2D renderer never needed this because it painted
-- neighbour bodies OVER the ring; with a depth buffer the ring's standing
-- trees would rise straight through the neighbour's flat ground -- cross
-- into Route 1 and a wall of border trees sprouts over Pallet.
--
-- Kept free of any GPU call so it can be exercised headless -- the
-- geometry is the part with the interesting invariants, and a suite that
-- needed a real GL context to check them would never run in CI.
-- `waterSink`, when given, takes the WATER SURFACE quads instead of the
-- main sink -- the one class in this world that is drawn as its own pass
-- (see Water: a mirror cannot be drawn until what it reflects exists).
-- Nothing else moves: the quads are the same quads, emitted by the same
-- corner and uv arithmetic at the same recessed height, and the shoreline
-- faces around them still belong to the GROUND that exposes them.
--
-- Omitted, water stays in the terrain mesh exactly as it always did, which
-- is what the headless geometry() below and the sun's own pass both want.
local function runGeometry(map, bodyOnly, masks, sink, waterSink, stampPlan)
  local push = sink.push
  local waterPush = waterSink and waterSink.push or nil
  local tileset = map.tileset
  local S = Structures.forMap(map)
  local elevation = elevationFor(map)
  local perRow = tileset.tilesPerRow or 16
  local atlasW = tileset.imageWidth or (perRow * 8)
  local atlasH = tileset.imageHeight or 48

  -- Tile coordinates are 8px. LedgeElevation keeps the gameplay-facing 16px
  -- cell datum in `at`, but its `atTile` view closes the half-cell of plateau
  -- that shares a collision cell with an authored lip. Snapshot queries still
  -- return zero outside the body, which is exactly the ring contract;
  -- connected map bodies derive their own datums. AO and side exposure ask
  -- for these neighbours many times, so memoize the raw reading per build.
  local rawTileBases = {}
  local function rawBaseAtTile(tx, ty)
    local k = keyOf(tx, ty)
    local hit = rawTileBases[k]
    if hit ~= nil then return hit end
    hit = type(elevation.atTile) == "function"
          and elevation:atTile(tx, ty)
          or elevation:at(math.floor(tx / 2), math.floor(ty / 2))
    rawTileBases[k] = hit
    return hit
  end

  local function rawBaseAtWorld(wx, wz)
    return rawBaseAtTile(math.floor(wx / 8), math.floor(wz / 8))
  end

  -- A collision door is the one authored point where gameplay states exactly
  -- which terrace a rigid building's floor meets. Route 4's Center is the real
  -- case: its northwest drawing tile has datum 0, while its door cell (11,5)
  -- has datum 6. Choosing the former buried the facade by one ledge course.
  --
  -- Accept only one proven answer: all recorded doors must share a datum. A
  -- doorless scenery block or a contradictory multi-door mod takes the exact
  -- historical origin path. For an accepted building, level only the tiles it
  -- already claimed as synthesized floor; lifting the model without that plot
  -- would replace "buried" with a six-pixel hollow underneath. Collision and
  -- the immutable LedgeElevation snapshot stay untouched. The RAW snapshot is
  -- retained below for the uneven-footprint instancing guard, so a building
  -- crossing a real contour still expands instead of bending through instance
  -- data.
  local buildingFloors, buildingPlacementBases = {}, {}
  local function doorBase(st)
    local samples = st.doorGroundSamples
    if type(samples) ~= "table" or #samples < 2 then return nil end
    local answer = nil
    for at = 1, #samples - 1, 2 do
      Budget.tick()
      local tx, ty = tonumber(samples[at]), tonumber(samples[at + 1])
      if tx and ty then
        local base = rawBaseAtTile(tx, ty)
        if answer == nil then answer = base
        elseif base ~= answer then return nil end
      end
    end
    return answer
  end

  for _, st in ipairs(S.buildingStamps or {}) do
    Budget.tick()
    local base = doorBase(st)
    if base ~= nil then
      buildingPlacementBases[st] = base
      local tx, ty = tonumber(st.tx), tonumber(st.ty)
      local bw, bh = tonumber(st.bw), tonumber(st.bh)
      if tx and ty and bw and bh then
        for r = 0, bh - 1 do
          for c = 0, bw - 1 do
            Budget.tick()
            local k = keyOf(tx + c, ty + r)
            local shape = S.shapeAt[k]
            if S.skip[k] and shape and shape.class == "building" then
              buildingFloors[k] = base
            end
          end
        end
      end
    end
  end

  local tileBases = {}
  local function baseAtTile(tx, ty)
    local k = keyOf(tx, ty)
    local hit = tileBases[k]
    if hit ~= nil then return hit end
    hit = buildingFloors[k]
    if hit == nil then hit = rawBaseAtTile(tx, ty) end
    tileBases[k] = hit
    return hit
  end

  local function baseAtWorld(wx, wz)
    return baseAtTile(math.floor(wx / 8), math.floor(wz / 8))
  end

  local function heightAt(tx, ty)
    local k = keyOf(tx, ty)
    local base = baseAtTile(tx, ty)
    if S.skip[k] then return base end
    local run = S.runs[k]
    if run then return base + run.h end
    local s = S.shapeAt[k]
    return base + (s and s.h or 0)
  end

  local function route4PortalV2(st, base)
    if map.id ~= "ROUTE_4" then return nil end
    local spec = CAVE_PORTAL_ROUTE4_V2[st.warpIndex]
    if not spec or st.target ~= spec.target or base ~= spec.base
        or heightAt(st.baseTx, st.baseTy - 1) ~= spec.north
        or heightAt(st.baseTx + 1, st.baseTy - 1) ~= spec.north
        or heightAt(st.baseTx - 1, st.baseTy) ~= spec.west
        or heightAt(st.baseTx + 2, st.baseTy) ~= spec.east then
      return nil
    end
    if spec.steppedWest
        and (heightAt(st.baseTx - 1, st.baseTy - 1) ~= spec.northWest
          or heightAt(st.baseTx - 2, st.baseTy) ~= spec.outerWest
          or heightAt(st.baseTx - 1, st.baseTy + 1) ~= spec.southWest) then
      return nil
    end
    return spec
  end

  -- One atlas-rect UV, optionally cropped on either axis.  Geometry normally
  -- consumes a whole 8px tile; the cave-portal reveal below also needs one
  -- exact four-pixel half-course, still at one world pixel per art texel.
  local function uvCrop(tile, uLeft, uRight, vTop, vBot)
    local ax = (tile % perRow) * 8
    local ay = math.floor(tile / perRow) * 8
    local ui = math.min(INSET, (uRight - uLeft) / 4)
    local vi = math.min(INSET, (vBot - vTop) / 4)
    return (ax + uLeft + ui) / atlasW,
           (ax + uRight - ui) / atlasW,
           (ay + vTop + vi) / atlasH, (ay + vBot - vi) / atlasH
  end
  local function uvRect(tile, vTop, vBot)
    return uvCrop(tile, 0, 8, vTop, vBot)
  end

  -- ------------------------------------------------------ ambient occlusion
  --
  -- Ambient light is what reaches a surface from the sky at large, so it is
  -- blocked by how much geometry crowds a point rather than by where the
  -- sun happens to be -- which makes it the exact complement of the shadow
  -- pass, and the reason both are worth having. The shadow map draws the
  -- long directional shadow a building throws; this draws the dark seam in
  -- every corner the sky cannot see into, at every scale finer than a
  -- shadow map texel.
  --
  -- Baked per vertex, the classic voxel way: each corner counts the
  -- neighbours that crowd it and steps down once per neighbour, and the
  -- rasteriser interpolates the steps into a smooth falloff. Costs exactly
  -- nothing at draw time, and it is resolution-independent -- a screen
  -- space pass would blur across the pixel grid this whole mode is built
  -- to keep crisp.
  --
  -- (What was here before was a one-directional contact shadow keyed to a
  -- sun in the northwest: two neighbours, one corner, top faces only.)

  -- Intensity. Both terms below are DARKENING amounts rather than
  -- multipliers, so this one number scales the whole effect: 1.0 is the
  -- barely-there first cut, and everything is expressed against it.
  local AO_STRENGTH = 2.4
  local AO_STEP = 0.09 * AO_STRENGTH      -- per crowding neighbour, max 3
  local AO_EDGE = 1 - 0.14 * AO_STRENGTH  -- creases / corners on a face
  local AO_GROUND = 0.12 * AO_STRENGTH    -- a prop's contact with the floor
  local AO_RISE = 6                       -- px over which the floor lets go
  local AO_FLOOR = 0.25                   -- never let a vertex reach black

  -- Both sinks copy a per-corner shade straight out into the vertex stream
  -- and keep no reference, so these two scratch rows are reused for every
  -- quad on the map rather than allocating a table per face -- a route
  -- builds a few hundred thousand of them.
  local aoTop = { 0, 0, 0, 0 }
  local aoSide = { 0, 0, 0, 0 }

  -- A top face's four corners, each occluded by the three cells that touch
  -- it: two edge neighbours and the diagonal between them.
  local function aoShades(tx, ty, h, shade)
    local n = heightAt(tx, ty - 1) > h
    local s = heightAt(tx, ty + 1) > h
    local e = heightAt(tx + 1, ty) > h
    local w = heightAt(tx - 1, ty) > h
    local nw = heightAt(tx - 1, ty - 1) > h
    local ne = heightAt(tx + 1, ty - 1) > h
    local sw = heightAt(tx - 1, ty + 1) > h
    local se = heightAt(tx + 1, ty + 1) > h
    if not (n or s or e or w or nw or ne or sw or se) then return shade end
    local function corner(a, b, d)
      local k = 0
      if a then k = k + 1 end
      if b then k = k + 1 end
      -- a diagonal wedged behind both of its edges adds nothing: the
      -- corner is already as enclosed as it can get, and counting it
      -- again is what turns an ordinary inside corner black
      if d and not (a and b) then k = k + 1 end
      -- floored, so cranking AO_STRENGTH deepens the seams instead of
      -- punching holes of pure black through the world
      return shade * math.max(AO_FLOOR, 1 - AO_STEP * k)
    end
    -- corners in topQuad order: NW, NE, SE, SW
    aoTop[1], aoTop[2] = corner(n, w, nw), corner(n, e, ne)
    aoTop[3], aoTop[4] = corner(s, e, se), corner(s, w, sw)
    return aoTop
  end

  -- The same idea on an upright face, where the crowding is of two kinds:
  -- the CREASE it rises out of (the band sitting on the ground, or on
  -- whatever lower neighbour exposed the face) and the INSIDE CORNERS
  -- where the columns flanking it stand proud of the band. `hl`/`hr` are
  -- those flanking heights in FACE order -- left then right as seen from
  -- outside, per LATERAL below -- so the shades line up with sideQuad's
  -- corners without the caller thinking about compass directions.
  local LATERAL = {
    [1] = { 0, 1, 0, -1 },    -- east face:  left south, right north
    [2] = { 0, -1, 0, 1 },    -- west face:  left north, right south
    [5] = { -1, 0, 1, 0 },    -- south face: left west,  right east
    [6] = { 1, 0, -1, 0 },    -- north face: left east,  right west
  }
  -- Ground contact for the prebuilt prop quads -- the per-pixel plants,
  -- signs and lone trees, and the round-tree stamps. Those arrive from
  -- Structures already finished, so the neighbour counting above has no
  -- columns to count. What it CAN say is that the ground plane itself
  -- blocks half the sky, so the closer a voxel sits to it the less ambient
  -- light reaches it -- which is what plants a prop on the floor instead
  -- of leaving it looking pasted over the top.
  local aoProp = { 0, 0, 0, 0 }
  local function groundShades(c, shade, groundY)
    if type(shade) == "table" then return shade end
    groundY = groundY or 0
    local y1, y2 = c[1][2] - groundY, c[2][2] - groundY
    local y3, y4 = c[3][2] - groundY, c[4][2] - groundY
    if math.min(y1, y2, y3, y4) >= AO_RISE then return shade end
    for i = 1, 4 do
      local t = (c[i][2] - groundY) / AO_RISE
      aoProp[i] = shade * (t >= 1 and 1 or (1 - AO_GROUND * (1 - t)))
    end
    return aoProp
  end

  local AO_CORNER = math.max(AO_FLOOR, AO_EDGE * AO_EDGE)  -- crease AND flank
  local function sideShades(hl, hr, y0, y1, crease, shade)
    if not (crease or hl > y0 or hr > y0) then return shade end
    -- corners run bottom-left, bottom-right, top-right, top-left
    local base = crease and AO_EDGE or 1
    aoSide[1] = shade * (hl > y0 and (crease and AO_CORNER or AO_EDGE) or base)
    aoSide[2] = shade * (hr > y0 and (crease and AO_CORNER or AO_EDGE) or base)
    aoSide[3] = shade * (hr > y1 and AO_EDGE or 1)
    aoSide[4] = shade * (hl > y1 and AO_EDGE or 1)
    return aoSide
  end

  -- `to` routes the quad somewhere other than the main sink -- the water
  -- surface is the only caller that ever does (see runGeometry's header).
  local function topQuad(x0, z0, h, tile, shade, to, transform)
    local u0, u1, v0, v1 = uvRect(tile, 0, 8)
    local uv
    if transform == "vflip" then
      uv = { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }
    elseif transform == "ccw" then
      -- local (u,v) -> (1-v,u)
      uv = { { u1, v0 }, { u1, v1 }, { u0, v1 }, { u0, v0 } }
    elseif transform == "cw" then
      -- local (u,v) -> (v,1-u)
      uv = { { u0, v1 }, { u0, v0 }, { u1, v0 }, { u1, v1 } }
    else
      uv = { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } }
    end
    ;(to or push)({ { x0, h, z0 }, { x0 + 8, h, z0 },
                    { x0 + 8, h, z0 + 8 }, { x0, h, z0 + 8 } },
                  uv, aoShades(x0 / 8, z0 / 8, h, shade))
  end

  -- vertical quad for face direction `d` of the tile column at (x0, z0),
  -- spanning heights [y0, y1] and showing art rows [vTop, vBot] of `tile`.
  -- Corners run bottom-left, bottom-right, top-right, top-left as seen
  -- from outside; u follows +X on the north/south faces so a door or sign
  -- never draws mirrored.
  local function sideQuad(d, x0, z0, y0, y1, tile, vTop, vBot, shade)
    local x1, z1 = x0 + 8, z0 + 8
    local c
    if d == 5 then                                       -- south, at z1
      c = { { x0, y0, z1 }, { x1, y0, z1 }, { x1, y1, z1 }, { x0, y1, z1 } }
    elseif d == 6 then                                   -- north, at z0
      c = { { x1, y0, z0 }, { x0, y0, z0 }, { x0, y1, z0 }, { x1, y1, z0 } }
    elseif d == 1 then                                   -- east, at x1
      c = { { x1, y0, z1 }, { x1, y0, z0 }, { x1, y1, z0 }, { x1, y1, z1 } }
    else                                                 -- west, at x0
      c = { { x0, y0, z0 }, { x0, y0, z1 }, { x0, y1, z1 }, { x0, y1, z0 } }
    end
    local u0, u1, v0, v1 = uvRect(tile, vTop, vBot)
    push(c, { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }, shade)
  end

  local def = map.def
  local tw, th = def.width * 4, def.height * 4         -- map size in tiles
  local r = bodyOnly and 0 or RING * 4

  -- true when the (ring) position lies under a connected neighbour's body
  local function masked(px0, pz0, px1, pz1)
    if not masks then return false end
    for _, mk in ipairs(masks) do
      if px1 > mk[1] and px0 < mk[3] and pz1 > mk[2] and pz0 < mk[4] then
        return true
      end
    end
    return false
  end

  -- The inclusive variant for OBJECT quads: a quad TOUCHING a neighbour
  -- body counts as under it. The old test took the quad's center with
  -- strict bounds, and a quad whose center sat exactly on the body's
  -- edge line escaped the mask -- stringing stray pixel fragments of
  -- otherwise-dropped border trees along every map seam.
  local function maskedClosed(px0, pz0, px1, pz1)
    if not masks then return false end
    for _, mk in ipairs(masks) do
      if px1 >= mk[1] and px0 <= mk[3] and pz1 >= mk[2] and pz0 <= mk[4] then
        return true
      end
    end
    return false
  end

  for ty = -r, th + r - 1 do
    for tx = -r, tw + r - 1 do
      Budget.tick()
      local k = keyOf(tx, ty)
      local s, tile = S.shapeAt[k], S.tileAt[k]
      local inBody = tx >= 0 and ty >= 0 and tx < tw and ty < th
      if not inBody and masked(tx * 8, ty * 8, tx * 8 + 8, ty * 8 + 8) then
        s = nil
      end

      -- Under the TREES fill the border wall is MODELLED or it is not there
      -- (see Structures' hullRingOnly): a ring cell nothing claimed would
      -- be a flat-topped box standing beside carved trunks, which reads as
      -- a painted-on plateau rather than forest. Structures already stops
      -- the ring at the carve distance; this catches the odd cell inside it
      -- that the 2x2 grouping could not take -- a canopy whose partners
      -- fall outside the shortened ring is left unclaimed, and one strip of
      -- boxes along an edge is the whole artefact this avoids.
      if not inBody and S.hideBareRing and not S.skip[k] then
        s = nil
      end

      if s and S.skip[k] then
        -- an object stands here; paint its synthesized ground and let the
        -- prebuilt prism quads (appended below) carry the art
        local g = S.ground[k]
        if g then
          local base = baseAtTile(tx, ty)
          topQuad(tx * 8, ty * 8, base, g, 1)
          -- the claimed tile is still ground at its ledge datum, and water next
          -- door still recesses below it: without the same below-ground
          -- side bands ordinary ground emits, the two-pixel shoreline
          -- face is a slit into the sky behind the mesh -- which is
          -- exactly what a building plot or a sign standing at the
          -- waterline showed. Same bands, cut from the synthesized
          -- ground's own art
          for _, side in ipairs(SIDES) do
            local nh = heightAt(tx + side[1], ty + side[2])
            if nh < base then
              local d = side[3]
              local lat = LATERAL[d]
              local hl = lat and heightAt(tx + lat[1], ty + lat[2]) or 0
              local hr = lat and heightAt(tx + lat[3], ty + lat[4]) or 0
              -- Work downward from the local floor so a six-pixel terrace
              -- exposes the same bottom six art rows as an intrinsic ledge.
              local y1 = base
              while y1 > nh do
                local y0 = math.max(nh, y1 - 8)
                if y1 > y0 then
                  sideQuad(d, tx * 8, ty * 8, y0, y1, g,
                           8 - (y1 - y0), 8,
                           sideShades(hl, hr, y0, y1, y0 <= nh,
                                      Voxel3D.FACE_SHADE[d]))
                end
                y1 = y0
              end
            end
          end
        end
      elseif s then
        local run = S.runs[k]
        local base = baseAtTile(tx, ty)
        local localH = run and run.h or s.h
        local h = base + localH
        local x0, z0 = tx * 8, ty * 8

        -- top face. A roofed volume gets a GABLE segment: the roof rises
        -- from the facade top at the south eave to a ridge across the
        -- footprint's middle, then falls back to the facade at the north
        -- edge -- so the far side sits LOW. (The first cut was a shed
        -- plane rising all the way north, which turns a building into a
        -- ramp.) The south slope wears the structure's roof rows (ridge
        -- art at the ridge, eaves art at the eave); the back slope
        -- mirrors them. Exposed east/west flanks hip: their outer edge
        -- drops toward the eave, rounding the drawn corner tiles into 45
        -- degree corners. Flat-topped volumes wear their top rows;
        -- everything else its own art.
        if run and run.rise > 0 then
          local mid = run.extent / 2
          local function gableH(d)     -- d = rows north of the south eave
            local t = d <= mid and d / mid or (run.extent - d) / (run.extent - mid)
            return base + run.h + run.rise * math.max(0, math.min(1, t))
          end
          local d0 = run.front - ty                -- rows from the south edge
          local hS = gableH(d0)
          local hN = gableH(d0 + 1)
          -- art by proximity to the ridge, mirrored over the back
          local rel = 1 - math.abs(d0 + 0.5 - mid) / math.max(mid, 0.5)
          local idx = math.min(run.roofRows - 1,
                               math.floor((1 - rel) * run.roofRows))
          local roofTile = map:tileAt(tx, run.north + idx)
          local swY, seY, neY, nwY = hS, hS, hN, hN
          if heightAt(tx - 1, ty) < base + run.h then -- west flank: hip
            swY = math.max(base + run.h, hS - 8)
            nwY = math.max(base + run.h, hN - 8)
          end
          if heightAt(tx + 1, ty) < base + run.h then -- east flank: hip
            seY = math.max(base + run.h, hS - 8)
            neY = math.max(base + run.h, hN - 8)
          end
          local u0, u1, v0, v1 = uvRect(roofTile, 0, 8)
          push({ { x0, swY, z0 + 8 }, { x0 + 8, seY, z0 + 8 },
                 { x0 + 8, neY, z0 }, { x0, nwY, z0 } },
               { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }, 0.95)
        elseif run then
          local m = math.min(2, run.extent)
          local topTile = map:tileAt(tx, run.north + ((ty - run.north) % m))
          topQuad(x0, z0, h, topTile, VOLUME_TOP_SHADE)
        else
          -- A visual-only material substitution belongs to the plan-view
          -- surface, not to collision or structure classification.  Route 8's
          -- Lavender approach uses this to turn the canonical walkable
          -- $30/$39 checker into a narrow $39 path without changing a raw map
          -- tile, one vertex or the shared OVERWORLD atlas.
          local topTile = S.topTileAt and S.topTileAt[k] or tile
          if s.art == "upright" and s.authored then
            -- Top art for a pinned box.  A furniture drawing is top-view
            -- rows over floor(h/8) face-on rows the fold stands upright;
            -- a face row's top would repeat its front art lying flat, so
            -- it wears the nearest row above the face block instead --
            -- the drawn tabletop (and whatever sits on it) stays on top,
            -- and a fully-folded structure (wall, desk) tops with its
            -- northmost row.
            local north, front = ty, ty
            while ty - north < 6 do
              local bs = S.shapeAt[keyOf(tx, north - 1)]
              if bs and bs.authored and bs.class == s.class then
                north = north - 1
              else
                break
              end
            end
            while front - ty < 6 do
              local bs = S.shapeAt[keyOf(tx, front + 1)]
              if bs and bs.authored and bs.class == s.class then
                front = front + 1
              else
                break
              end
            end
            local row = math.min(ty, front - math.floor(h / 8))
            if row < north then
              -- the whole run folded onto the face: top with the drawn
              -- row just above it when that row is furniture too (a
              -- bookcase wearing its shelf-top trim), else with the
              -- run's own top row
              local above = S.shapeAt[keyOf(tx, north - 1)]
              row = (above and above.authored and above.art == "upright")
                    and (north - 1) or north
            end
            topTile = S.tileAt[keyOf(tx, row)]
          end
          -- A profile-authored rigid course may name a separate plan-view
          -- material while keeping its original pixels on the upright face.
          -- Route 8 uses this for a grass-topped low hedge/stone boundary:
          -- the old canopy art remains on its sides, but broad connected
          -- patches no longer read as flat grey concrete from above.
          if s.topTile ~= nil then topTile = s.topTile end
          local topShade = s.art == "upright" and VOLUME_TOP_SHADE or 1
          if inBody and def.tileset == "CAVERN" and s.class == "void"
             and tile == CAVERN_UNLIT_TILE then
            topTile = CAVERN_SHADOW_FLOOR_TILE
            topShade = CAVERN_SHADOW_FLOOR_SHADE
          end
          -- water's surface, and only water's: the recessed sheet itself,
          -- never the ground's shoreline bands around it. A cell an object
          -- stands on took the branch above and paints synthesized GROUND,
          -- which is right -- a sign at the waterline stands on a plot, not
          -- on the pond.
          topQuad(x0, z0, h, topTile, topShade,
                  (s.class == "water") and waterPush or nil,
                  S.topUVAt and S.topUVAt[k] or nil)
        end

        -- sides: 8px bands wherever the neighbour is lower. Band k spans
        -- heights [8k, 8k+8) and shows one full tile of art; a partial
        -- band crops the art rows to match, so nothing ever stretches.
        for _, side in ipairs(SIDES) do
          local nh = heightAt(tx + side[1], ty + side[2])
          if nh < h then
            local d = side[3]
            -- the columns flanking this face, for the inside-corner term:
            -- fixed for the whole face, so they are read once rather than
            -- once per 8px band
            local lat = LATERAL[d]
            local hl = lat and heightAt(tx + lat[1], ty + lat[2]) or 0
            local hr = lat and heightAt(tx + lat[3], ty + lat[4]) or 0
            -- A terrace datum is the column's floor, not another authored
            -- art band. Expose any foundation below it first; then fold the
            -- structure from local band zero upward. This keeps a building
            -- lifted by 6px on the same facade rows instead of selecting its
            -- second row merely because the absolute Y crossed 8.
            local foundationTop = math.min(base, h)
            local fy1 = foundationTop
            while fy1 > nh do
              local fy0 = math.max(nh, fy1 - 8)
              sideQuad(d, x0, z0, fy0, fy1, tile,
                       8 - (fy1 - fy0), 8,
                       sideShades(hl, hr, fy0, fy1, fy0 <= nh,
                                  Voxel3D.FACE_SHADE[d]))
              fy1 = fy0
            end

            local structuralBottom = math.max(nh, base)
            for band = math.floor((structuralBottom - base) / 8),
                       math.ceil((h - base) / 8) - 1 do
              local y0 = math.max(structuralBottom, base + band * 8)
              local y1 = math.min(h, base + band * 8 + 8)
              if y1 > y0 then
                local src, shade = tile, Voxel3D.FACE_SHADE[d]
                if run then
                  -- fold the structure's artwork up this face: band k
                  -- samples the map row k tiles north of the structure's
                  -- front, clamped to its extent. The south face is the
                  -- drawing itself (full brightness); the other sides wear
                  -- the same rows darkened, so a building's flank matches
                  -- its face instead of smearing one tile
                  if d == 6 then
                    -- The north face is a synthesized back wall, not a
                    -- second facade. Never let its band selection enter the
                    -- folded door rows at the south/front end of the run.
                    local backEnd = run.doorNorth
                                      and math.max(run.north,
                                                   run.doorNorth - 1)
                                      or run.front
                    src = map:tileAt(tx, math.min(backEnd,
                                                  run.north + band))
                  else
                    src = map:tileAt(tx, math.max(run.north,
                                                  run.front - band))
                  end
                  if d == 5 then shade = 1 end
                elseif s.art == "upright" then
                  -- profile-authored upright (a pinned wall or furniture
                  -- box): fold the drawing up the face, band 0 the
                  -- structure's southmost same-class row and higher bands
                  -- the rows north of it, repeating past the top.  The
                  -- south face is the drawing itself (full brightness);
                  -- flanks and back wear the same front stack darkened, so
                  -- a desk's side matches its face instead of smearing a
                  -- different jumble per row.
                  if d == 5 then shade = 1 end
                  local front = ty
                  while front < ty + 6 do
                    local fs2 = S.shapeAt[keyOf(tx, front + 1)]
                    if fs2 and fs2.authored and fs2.class == s.class then
                      front = front + 1
                    else
                      break
                    end
                  end
                  local fk = keyOf(tx, front - band)
                  local fs = S.shapeAt[fk]
                  if fs and fs.authored and fs.class == s.class then
                    src = S.tileAt[fk]
                  end
                end
                sideQuad(d, x0, z0, y0, y1, src,
                         (band * 8 + 8) - (y1 - base),
                         (band * 8 + 8) - (y0 - base),
                         sideShades(hl, hr, y0, y1, y0 <= nh, shade))
              end
            end
          end
        end
      end
    end
  end

  -- Cinnabar's canonical checker meets its recessed water through one shallow
  -- sloped quay lip.  V4 varies the audited 8px segments by 2/4/6px, always
  -- cropping the same number of source rows: one texel remains one world
  -- pixel while the coastline stops reading as a ruler-straight rectangle.
  -- They live in this terrain sink (never the reflective water sink), add no
  -- collision/volume and touch y=-2 only at their outer line, so there is no
  -- coplanar water area to z-fight.
  for _, edge in ipairs(S.quayEdges or {}) do
    if edge.side == "south" then
      local zLand = (edge.cy + 1) * 16
      for column = 0, 1 do
        Budget.tick()
        local depth = edge.depths and edge.depths[column + 1] or 4
        local u0, u1, v0, v1 =
          uvCrop(edge.tiles[column + 1], 0, 8, 8 - depth, 8)
        local x0 = edge.cx * 16 + column * 8
        push({ { x0, 0, zLand }, { x0 + 8, 0, zLand },
               { x0 + 8, -2, zLand + depth },
               { x0, -2, zLand + depth } },
             { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } }, 1)
      end
    elseif edge.side == "west" then
      local xLand = edge.cx * 16
      for row = 0, 1 do
        Budget.tick()
        local depth = edge.depths and edge.depths[row + 1] or 4
        local u0, u1, v0, v1 =
          uvCrop(edge.tiles[row + 1], 0, 8, 8 - depth, 8)
        local z0 = edge.cy * 16 + row * 8
        push({ { xLand, 0, z0 }, { xLand, 0, z0 + 8 },
               { xLand - depth, -2, z0 + 8 },
               { xLand - depth, -2, z0 } },
             { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } }, 1)
      end
    end
  end

  -- The 104 V3 shoreline tops already passed exact map, source-tile and
  -- water-witness gates in Structures.  Finish each of those existing 8px
  -- edges with one equally gated V4 lip.  The descriptor's 2/4/6px depth is
  -- also the source crop depth, so all four bearings remain native-scale.
  -- N/S won the original corner registration; therefore these small lips do
  -- not overlap one another at a platform corner.
  for _, edge in ipairs(S.coastalEdges or {}) do
    Budget.tick()
    local depth = edge.depth
    local u0, u1, v0, v1 = uvCrop(edge.tile, 0, 8, 8 - depth, 8)
    local x0, z0 = edge.tx * 8, edge.ty * 8
    local corners
    if edge.side == "north" then
      corners = { { x0, 0, z0 }, { x0 + 8, 0, z0 },
                  { x0 + 8, -2, z0 - depth },
                  { x0, -2, z0 - depth } }
    elseif edge.side == "south" then
      corners = { { x0, 0, z0 + 8 }, { x0 + 8, 0, z0 + 8 },
                  { x0 + 8, -2, z0 + 8 + depth },
                  { x0, -2, z0 + 8 + depth } }
    elseif edge.side == "west" then
      corners = { { x0, 0, z0 }, { x0, 0, z0 + 8 },
                  { x0 - depth, -2, z0 + 8 },
                  { x0 - depth, -2, z0 } }
    elseif edge.side == "east" then
      corners = { { x0 + 8, 0, z0 + 8 }, { x0 + 8, 0, z0 },
                  { x0 + 8 + depth, -2, z0 },
                  { x0 + 8 + depth, -2, z0 + 8 } }
    end
    if corners then
      push(corners,
           { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } }, 1)
    end
  end

  -- Prebuilt quads from Structures (per-pixel voxel props, lathed
  -- columns) plus the round-tree stamps expanded in place. Keep rules,
  -- by the quad's own extent:
  --   body-only   the quad must overlap the OPEN body interval -- a
  --               neighbour's ring props must not march past its edge
  --               into this map, and a quad lying exactly ON the edge
  --               plane would z-fight the map that owns that plane.
  --   full        anything overlapping the body stays whole (props that
  --               straddle the edge no longer shed their outer half);
  --               pure ring quads drop when they touch a neighbour body
  --               (maskedClosed), which is what strings of seam pixels
  --               were: fragments of dropped border trees whose centers
  --               sat exactly on the boundary line.
  local bw, bh = tw * 8, th * 8
  local function keepQuad(x0, z0, x1, z1)
    local overBody = x1 > 0 and x0 < bw and z1 > 0 and z0 < bh
    if bodyOnly then return overBody end
    return overBody or not maskedClosed(x0, z0, x1, z1)
  end

  -- A face lying EXACTLY on a body boundary plane is ambiguous to the
  -- rect tests above: a body structure's outward facade (a Saffron row
  -- house whose front row is the map's last row, its south wall on the
  -- shared plane with Route 6) and the inward face of a ring scrap
  -- occupy the same degenerate rect, and the strict overBody plus the
  -- closed mask dropped BOTH -- which is why those facades were missing.
  -- The winding tells them apart: a face pointing AWAY from the body
  -- belongs to this map's own edge-row structure and nothing in the
  -- neighbour will ever draw that plane, so it stays; a face pointing
  -- INTO the body is the scrap the mask rules exist to kill, and falls
  -- through to them.
  local function outwardOnEdge(q, x0, z0, x1, z1)
    if z0 == z1 and (z0 == 0 or z0 == bh) and x1 > 0 and x0 < bw then
      local nz = (q[2][1] - q[1][1]) * (q[3][2] - q[1][2])
                 - (q[2][2] - q[1][2]) * (q[3][1] - q[1][1])
      return (z0 == bh and nz > 0) or (z0 == 0 and nz < 0)
    end
    if x0 == x1 and (x0 == 0 or x0 == bw) and z1 > 0 and z0 < bh then
      local nx = (q[2][2] - q[1][2]) * (q[3][3] - q[1][3])
                 - (q[2][3] - q[1][3]) * (q[3][2] - q[1][2])
      return (x0 == bw and nx > 0) or (x0 == 0 and nx < 0)
    end
    return false
  end

  local scUV = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
  local function quadUV(q)
    if q.uv then return q.uv end
    for i = 1, 4 do
      scUV[i][1], scUV[i][2] = q.u, q.v
    end
    return scUV
  end

  -- Rigid scenery samples one placement cell and carries that datum as a
  -- single translation. A point exactly on a cell's south/east boundary is
  -- biased back into the footprint it closes (not into the next object).
  local function placementBase(wx, wz)
    if wx % 16 == 0 then wx = wx - 0.001 end
    if wz % 16 == 0 then wz = wz - 0.001 end
    return baseAtWorld(wx, wz)
  end

  local function quadBase(q)
    local x0 = math.min(q[1][1], q[2][1], q[3][1], q[4][1])
    local x1 = math.max(q[1][1], q[2][1], q[3][1], q[4][1])
    local z0 = math.min(q[1][3], q[2][3], q[3][3], q[4][3])
    local z1 = math.max(q[1][3], q[2][3], q[3][3], q[4][3])
    local wx, wz = (x0 + x1) / 2, (z0 + z1) / 2
    local ax, ay, az = q[2][1] - q[1][1], q[2][2] - q[1][2],
                       q[2][3] - q[1][3]
    local bx, by, bz = q[3][1] - q[1][1], q[3][2] - q[1][2],
                       q[3][3] - q[1][3]
    local nx, nz = ay * bz - az * by, ax * by - ay * bx
    if x0 == x1 and wx % 16 == 0 then
      wx = wx + (nx < 0 and 0.001 or -0.001)
    end
    if z0 == z1 and wz % 16 == 0 then
      wz = wz + (nz < 0 and 0.001 or -0.001)
    end
    return baseAtWorld(wx, wz)
  end

  local function footprintOf(template)
    local hit = templateFootprints[template]
    if hit then return hit[1], hit[2], hit[3], hit[4] end
    local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
    for _, q in ipairs(template) do
      for i = 1, 4 do
        local c = q[i]
        x0, z0 = math.min(x0, c[1]), math.min(z0, c[3])
        x1, z1 = math.max(x1, c[1]), math.max(z1, c[3])
      end
    end
    if x0 == math.huge then x0, z0, x1, z1 = 0, 0, 0, 0 end
    hit = { x0, z0, x1, z1 }
    templateFootprints[template] = hit
    return x0, z0, x1, z1
  end

  -- A shared building model can use one Y instance component only when its
  -- footprint is one terrace. If malformed/modded art straddles a ledge, the
  -- caller expands that placement into the exact base stream instead of
  -- silently bending it through per-vertex instance data.
  local function buildingBase(st, template)
    local base = buildingPlacementBases[st]
                 or rawBaseAtWorld(st.mx + 0.001, st.mz + 0.001)
    local lx0, lz0, lx1, lz1 = footprintOf(template)
    local tx0 = math.floor((st.mx + lx0 + 0.001) / 8)
    local ty0 = math.floor((st.mz + lz0 + 0.001) / 8)
    local tx1 = lx1 == lx0 and tx0
                or math.floor((st.mx + lx1 - 0.001) / 8)
    local ty1 = lz1 == lz0 and ty0
                or math.floor((st.mz + lz1 - 0.001) / 8)
    for ty = ty0, ty1 do
      for tx = tx0, tx1 do
        local sample = rawBaseAtTile(tx, ty)
        if sample ~= base then return base, false end
      end
    end
    return base, true
  end

  -- Profiled buildings are authored as local voxel models and can occur many
  -- times on a city map. Buildings.stamp retains one shared template plus
  -- each translation, instead of materialising every translated corner in
  -- Structures. The synchronous/capability-fallback path below expands those
  -- records into the exact historical stream. The asynchronous instanced path
  -- uploads each model once and reuses the same translation in both camera and
  -- shadow shaders.
  local sc = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
  for _, st in ipairs(S.buildingStamps or {}) do
    Budget.tick()
    local template = st.quads or {}
    if #template > 0 then
      local base, uniform = buildingBase(st, template)
      if stampPlan and uniform then
        local variants = stampPlan.byTemplate[template]
        if not variants then
          variants = {}
          stampPlan.byTemplate[template] = variants
        end
        -- Buildings are body-owned geometry. Unlike border hulls, their eaves
        -- deliberately survive outside the body plane, so there is exactly one
        -- un-clipped variant per local model.
        local signature = "building"
        local group = variants[signature]
        if not group then
          local variantSink = newAsyncSink(stampPlan.job)
          group = { sink = variantSink, offsets = {}, quads = #template }
          variants[signature] = group
          stampPlan.groups[#stampPlan.groups + 1] = group
          for _, q in ipairs(template) do
            Budget.tick()
            variantSink.push({ q[1], q[2], q[3], q[4] }, quadUV(q),
                             groundShades(q, q.shade))
          end
        end
        group.offsets[#group.offsets + 1] = { st.mx, base, st.mz }
      else
        for _, q in ipairs(template) do
          Budget.tick()
          for i = 1, 4 do
            local c, out = q[i], sc[i]
            out[1], out[2], out[3] = c[1] + st.mx, c[2] + base,
                                      c[3] + st.mz
          end
          push(sc, quadUV(q), groundShades(sc, q.shade, base))
        end
      end

      -- A door-bearing OVERWORLD/FOREST building keeps the same native 2x2
      -- entrance on its synthesized north facade. Buildings supplies the
      -- exact-gated descriptor; stand the four existing tiles a hair north
      -- of the rear so they replace the plain pixels without a coplanar
      -- fight. This stays in the existing terrain/building sink: four quads,
      -- zero new draw, texture, VRAM, collision or warp state.
      local door = st.northDoor
      if door and type(door.tiles) == "table" and #door.tiles == 4 then
        local z = st.mz + door.z
        -- Compact one-storey homes use the same native 2x2 door artwork but
        -- present it as one centred rear doorway instead of a house-wide
        -- double leaf.  Only an explicit, bounded template receipt may narrow
        -- it; malformed or legacy descriptors retain the historical 16 px.
        local displayWidth = door.displayWidth
        if type(displayWidth) ~= "number"
           or displayWidth ~= math.floor(displayWidth)
           or displayWidth < 8 or displayWidth > 16 then
          displayWidth = 16
        end
        local columnWidth = displayWidth / 2
        local doorInset = (16 - displayWidth) / 2
        local heightScale = st.heightScale
        if type(heightScale) ~= "number" or heightScale ~= heightScale
           or heightScale < 1 or heightScale > 2
           or heightScale == math.huge then
          heightScale = 1
        end
        for row = 0, 1 do
          for col = 0, 1 do
            Budget.tick()
            local x0 = st.mx + door.x + doorInset + col * columnWidth
            local y0 = base + (1 - row) * 8 * heightScale
            local c = { { x0 + columnWidth, y0, z }, { x0, y0, z },
                        { x0, y0 + 8 * heightScale, z },
                        { x0 + columnWidth, y0 + 8 * heightScale, z } }
            local u0, u1, v0, v1 = uvRect(door.tiles[row * 2 + col + 1],
                                           0, 8)
            local uv = { { u0, v1 }, { u1, v1 },
                         { u1, v0 }, { u0, v0 } }
            push(c, uv, groundShades(c, Voxel3D.FACE_SHADE[6], base))
          end
        end
      end
    end
  end

  -- The canonical OVERWORLD cave drawing is a walkable door cell. Structures
  -- keeps unknown door art on the old detection path, but its nine exact
  -- data-gated placements arrive here as small terrain-atlas stamps: the
  -- original 16x16 pixels stand at the recessed north end of a shallow rock
  -- reveal, with real side walls, ceiling and a one-pixel threshold.  They are
  -- emitted into this SAME terrain sink -- no building classification, model
  -- instance, texture allocation or draw call is introduced.
  --
  -- One base tile is sampled for the complete stamp.  This is deliberately a
  -- rigid translation: Route 4's entrances sit on different ledge courses,
  -- and sampling each face separately would bend a tunnel across the contour.
  local function portalSouthFace(x0, x1, y0, y1, z, tile, vTop, vBot,
                                 shade)
    Budget.tick()
    local u0, u1, v0, v1 = uvCrop(tile, 0, x1 - x0, vTop, vBot)
    push({ { x0, y0, z }, { x1, y0, z },
           { x1, y1, z }, { x0, y1, z } },
         { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }, shade)
  end

  local function portalSideFace(x, z0, z1, y0, y1, eastFacing, shade)
    Budget.tick()
    local u0, u1, v0, v1 = uvCrop(CAVE_PORTAL_ROCK_TILE, 0, z1 - z0,
                                   0, y1 - y0)
    local corners
    if eastFacing then
      corners = { { x, y0, z0 }, { x, y0, z1 },
                  { x, y1, z1 }, { x, y1, z0 } }
    else
      corners = { { x, y0, z1 }, { x, y0, z0 },
                  { x, y1, z0 }, { x, y1, z1 } }
    end
    push(corners,
         { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }, shade)
  end

  local function portalTopFace(x0, x1, z0, z1, y, shade)
    Budget.tick()
    local u0, u1, v0, v1 = uvCrop(CAVE_PORTAL_ROCK_TILE, 0, x1 - x0,
                                   0, z1 - z0)
    push({ { x0, y, z0 }, { x1, y, z0 },
           { x1, y, z1 }, { x0, y, z1 } },
         { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } }, shade)
  end

  -- Downward complement for a carved rock course.  This is deliberately not
  -- a second top: reversing both winding and V keeps the same one-texel-per-
  -- world-pixel atlas phase while exposing only the underside of real air.
  local function portalBottomFace(x0, x1, z0, z1, y, shade)
    Budget.tick()
    local u0, u1, v0, v1 = uvCrop(CAVE_PORTAL_ROCK_TILE, 0, x1 - x0,
                                   0, z1 - z0)
    push({ { x0, y, z1 }, { x1, y, z1 },
           { x1, y, z0 }, { x0, y, z0 } },
         { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }, shade)
  end

  -- Exterior north skin for the only two canonical mouths whose ledge datum
  -- lifts the 16px terminal above the cliff course behind it (Route 4).  The
  -- ordinary pass draws with culling disabled, so unsupported terminal pixels
  -- would otherwise be visible from a north/diagonal orbit as the back of a
  -- poster.  These helpers put the retained atlas' own rock on that exterior;
  -- the terminal remains a quarter pixel farther south and therefore still
  -- wins every front-facing depth test.
  local function portalNorthFace(x0, x1, y0, y1, z, vTop, vBot, shade)
    Budget.tick()
    local u0, u1, v0, v1 = uvCrop(CAVE_PORTAL_ROCK_TILE, 0, x1 - x0,
                                   vTop, vBot)
    push({ { x1, y0, z }, { x0, y0, z },
           { x0, y1, z }, { x1, y1, z } },
         { { u1, v1 }, { u0, v1 }, { u0, v0 }, { u1, v0 } }, shade)
  end

  local function portalReturnSide(x, z0, z1, y0, y1, west, vTop, vBot,
                                  shade)
    Budget.tick()
    local u0, u1, v0, v1 = uvCrop(CAVE_PORTAL_ROCK_TILE, 0, z1 - z0,
                                   vTop, vBot)
    local corners, uv
    if west then
      corners = { { x, y0, z0 }, { x, y0, z1 },
                  { x, y1, z1 }, { x, y1, z0 } }
      uv = { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }
    else
      corners = { { x, y0, z1 }, { x, y0, z0 },
                  { x, y1, z0 }, { x, y1, z1 } }
      uv = { { u1, v1 }, { u0, v1 }, { u0, v0 }, { u1, v0 } }
    end
    push(corners, uv, shade)
  end

  for _, st in ipairs(S.portalStamps or {}) do
    Budget.tick()
    local base = rawBaseAtTile(st.baseTx, st.baseTy)
    local x0, z0 = st.cx * 16, st.cy * 16
    local backZ = z0 + CAVE_PORTAL_NUDGE
    local route4V2 = route4PortalV2(st, base)
    local frontZ = backZ + CAVE_PORTAL_DEPTH
      + (route4V2 and CAVE_PORTAL_ROUTE4_EXTRA_DEPTH or 0)

    -- Authored rear terminal, four untouched 8x8 atlas quadrants.  Bottom
    -- bands are $58/$59; top bands $48/$49, exactly as the 2D cell stores.
    for band = 0, 1 do
      for column = 0, 1 do
        local tile = (band == 0 and 0x58 or 0x48) + column
        portalSouthFace(x0 + column * 8, x0 + (column + 1) * 8,
                        base + band * 8, base + (band + 1) * 8,
                        backZ, tile, 0, 8, 1)
      end
    end

    -- Route 4 is the sole real-map exception to the usual rear-occlusion
    -- invariant. Warp #2 stands at base 12 behind a cliff ending at absolute
    -- Y=16 (12px exposed); warp #3 stands at base 6 behind the same Y=16
    -- course (6px exposed). Cover only that unsupported interval at the
    -- cliff's own z0 plane. Vertical pieces follow the portal's 8px atlas
    -- phase, the two columns stay 8px wide, and quarter-pixel side/top returns
    -- close the depth seam from diagonal views without entering the tunnel.
    if map.id == "ROUTE_4" and CAVE_PORTAL_ROUTE4_SHIELD[st.warpIndex] then
      local portalTop = base + CAVE_PORTAL_HEIGHT
      for column = 0, 1 do
        local xa, xb = x0 + column * 8, x0 + (column + 1) * 8
        local northTop = heightAt(st.baseTx + column, st.baseTy - 1)
        local y = math.max(base, northTop)
        local exposed = y < portalTop
        while y < portalTop do
          local phase = (y - base) % 8
          local length = math.min(8 - phase, portalTop - y)
          local y1 = y + length
          portalNorthFace(xa, xb, y, y1, z0, phase, phase + length,
                          Voxel3D.FACE_SHADE[6])
          portalReturnSide(column == 0 and x0 or x0 + 16,
                           z0, backZ, y, y1, column == 0,
                           phase, phase + length,
                           Voxel3D.FACE_SHADE[column == 0 and 2 or 1])
          y = y1
        end
        if exposed then
          portalTopFace(xa, xb, z0, backZ, portalTop, 0.68)
        end
      end
    end

    -- Warp #3 sits one native 8px cell east of a real 16px ridge.  Its lower
    -- shoulder occupies exactly that proven 6px flank datum; the recessed
    -- upper course then meets both the ridge's Y=16 top and the retained
    -- shield cap at portalTop.  Faces already supplied by the north/west
    -- ridge, the lower course or the backshield are omitted.  The small east
    -- return covers only the interval those neighbours do not own, so
    -- the union is watertight without a coplanar duplicate.
    if route4V2 and route4V2.steppedWest then
      local sx0 = x0 - 8
      local lowerTop = base + 8
      local portalTop = base + CAVE_PORTAL_HEIGHT
      local lowerSouth = z0 + 8
      local upperSouth = backZ
      local ridgeTop = route4V2.outerWest
      local southTop = route4V2.southWest
      local notchX = x0 - 4
      local notchTop = portalTop - 4

      -- Lower 8x8x8 shoulder: north, west and bottom are supplied by the
      -- canonical ridge/flank union.  Its top is visible only south of the
      -- recessed upper course.
      portalSouthFace(sx0, x0, southTop, lowerTop, lowerSouth,
                      CAVE_PORTAL_ROCK_TILE, southTop - base, 8,
                      Voxel3D.FACE_SHADE[5])
      portalReturnSide(x0, z0, backZ, base, southTop, false, 0,
                       southTop - base, Voxel3D.FACE_SHADE[1])
      portalReturnSide(x0, z0, backZ, southTop, lowerTop, false,
                       southTop - base, 8, Voxel3D.FACE_SHADE[1])
      portalReturnSide(x0, backZ, lowerSouth, base, southTop, false, 0,
                       southTop - base, Voxel3D.FACE_SHADE[1])
      portalReturnSide(x0, backZ, lowerSouth, southTop, lowerTop, false,
                       southTop - base, 8, Voxel3D.FACE_SHADE[1])
      portalTopFace(sx0, notchX, upperSouth, lowerSouth, lowerTop, 0.68)
      portalTopFace(notchX, x0, upperSouth, lowerSouth, lowerTop, 0.68)

      -- Recessed upper step.  Its mouth-side lower corner is real air: a
      -- native 4px half-course is removed from the east/lower quadrant while
      -- the west pier and upper band retain the ridge and shield-cap joins.
      -- Split the two L-shaped skins into rectangles and close the carved
      -- corner with only its west wall and ceiling.  The backshield's existing
      -- west return owns the east boundary from Y=16 upward; emitting the old
      -- east join there would close the notch or duplicate that surface.
      portalSouthFace(sx0, notchX, lowerTop, portalTop, upperSouth,
                      CAVE_PORTAL_ROCK_TILE, 0, 8,
                      Voxel3D.FACE_SHADE[5])
      portalSouthFace(notchX, x0, notchTop, portalTop, upperSouth,
                      CAVE_PORTAL_ROCK_TILE, 0, 4,
                      Voxel3D.FACE_SHADE[5])
      portalReturnSide(sx0, z0, upperSouth, ridgeTop, portalTop, true,
                       ridgeTop - lowerTop, 8, Voxel3D.FACE_SHADE[2])
      portalNorthFace(sx0, notchX, ridgeTop, portalTop, z0,
                      ridgeTop - lowerTop, 8, Voxel3D.FACE_SHADE[6])
      portalNorthFace(notchX, x0, notchTop, portalTop, z0,
                      notchTop - lowerTop, 8, Voxel3D.FACE_SHADE[6])
      portalReturnSide(notchX, z0, backZ, lowerTop, notchTop, false,
                       0, notchTop - lowerTop, Voxel3D.FACE_SHADE[1])
      portalBottomFace(notchX, x0, z0, backZ, notchTop,
                       Voxel3D.FACE_SHADE[4])
      portalTopFace(sx0, notchX, z0, upperSouth, portalTop, 0.68)
      portalTopFace(notchX, x0, z0, upperSouth, portalTop, 0.68)
    end

    -- The canonical reveal keeps its authored 8px + 4px courses byte-stable.
    -- The quarter-pixel lateral inset keeps both courses in front of the
    -- blocked flank faces.
    local function portalCoreDepthCourses(emit)
      for depth = 0, CAVE_PORTAL_DEPTH - 1, 8 do
        emit(depth, math.min(8, CAVE_PORTAL_DEPTH - depth))
      end
    end

    portalCoreDepthCourses(function(depth, length)
      local za, zb = backZ + depth, backZ + depth + length
      for band = 0, 1 do
        local ya, yb = base + band * 8, base + (band + 1) * 8
        portalSideFace(x0 + CAVE_PORTAL_NUDGE, za, zb, ya, yb,
                       true, Voxel3D.FACE_SHADE[2])
        portalSideFace(x0 + 16 - CAVE_PORTAL_NUDGE, za, zb, ya, yb,
                       false, Voxel3D.FACE_SHADE[1])
      end
    end)

    -- Route 4's extra native 8px of approach depth is a LOW outer jamb, not
    -- another full-height tunnel course.  Extending the upper side bands and
    -- roof to the threshold made both three-quarter views read as one tall
    -- cuboid and hid the authored dark terminal.  Keep the established 12px
    -- tunnel untouched, extend only its lower 8px side shoulders, and leave
    -- the upper half open from either flank.  These two quads remain in the
    -- terrain batch, use one texel per world pixel, and move no collision or
    -- warp authority.
    if route4V2 then
      local za = backZ + CAVE_PORTAL_DEPTH
      local zb = za + CAVE_PORTAL_ROUTE4_EXTRA_DEPTH
      local shoulderTop = base + CAVE_PORTAL_ROUTE4_SHOULDER_HEIGHT
      portalSideFace(x0 + CAVE_PORTAL_NUDGE, za, zb, base, shoulderTop,
                     true, Voxel3D.FACE_SHADE[2])
      portalSideFace(x0 + 16 - CAVE_PORTAL_NUDGE, za, zb, base, shoulderTop,
                     false, Voxel3D.FACE_SHADE[1])
    end

    -- Rock ceiling.  Split on both atlas axes so every 8px course remains a
    -- one-to-one sample: the canonical four-pixel crop stays four pixels. The
    -- low Route 4 shoulder deliberately has no outer roof, preserving the
    -- upper sightline to the mouth from both three-quarter approaches.
    portalCoreDepthCourses(function(depth, length)
      for column = 0, 1 do
        portalTopFace(x0 + column * 8, x0 + (column + 1) * 8,
                      backZ + depth, backZ + depth + length,
                      base + CAVE_PORTAL_HEIGHT, 0.68)
      end
    end)

    -- A shallow sill closes the floor/reveal join without erecting another
    -- collision-sized box in front of the opening.
    local thresholdEnd = frontZ + CAVE_PORTAL_THRESHOLD_DEPTH
    for column = 0, 1 do
      local xa, xb = x0 + column * 8, x0 + (column + 1) * 8
      portalTopFace(xa, xb, frontZ, thresholdEnd,
                    base + CAVE_PORTAL_THRESHOLD_HEIGHT, 0.85)
      portalSouthFace(xa, xb, base,
                      base + CAVE_PORTAL_THRESHOLD_HEIGHT,
                      thresholdEnd, CAVE_PORTAL_ROCK_TILE, 7, 8,
                      Voxel3D.FACE_SHADE[5])
    end
  end

  for _, q in ipairs(S.objectQuads) do
    Budget.tick()
    local x0 = math.min(q[1][1], q[2][1], q[3][1], q[4][1])
    local x1 = math.max(q[1][1], q[2][1], q[3][1], q[4][1])
    local z0 = math.min(q[1][3], q[2][3], q[3][3], q[4][3])
    local z1 = math.max(q[1][3], q[2][3], q[3][3], q[4][3])
    -- q.own: a body-anchored structure's own quad (a building placed by
    -- Buildings.build, whose scan never leaves the body). Exempt from
    -- the edge keep-rules entirely: its eave legitimately overhangs the
    -- boundary plane into the neighbour's airspace, and no variant of
    -- the neighbour will ever draw that geometry
    if q.own or outwardOnEdge(q, x0, z0, x1, z1)
       or keepQuad(x0, z0, x1, z1) then
      local base = quadBase(q)
      for i = 1, 4 do
        local c, out = q[i], sc[i]
        out[1], out[2], out[3] = c[1], c[2] + base, c[3]
      end
      push(sc, quadUV(q), groundShades(sc, q.shade, base))
    end
  end

  -- true when the rect sits entirely inside one neighbour-body rect
  local function containedInMask(x0, z0, x1, z1)
    if not masks then return false end
    for _, mk in ipairs(masks) do
      if x0 >= mk[1] and x1 <= mk[3] and z0 >= mk[2] and z1 <= mk[4] then
        return true
      end
    end
    return false
  end

  -- Round-tree stamps use one of two equivalent output paths. Synchronous
  -- geometry/probes and drivers without instancing retain the historical
  -- translated expansion below. The asynchronous instanced path records one
  -- exact clipped template variant plus compact (x,y,z) offsets. It uses these
  -- very same keep rules; only the repeated vertex copies disappear.
  -- A hull spans at most its own footprint -- one 16px cell unless the
  -- stamp carries a wider radius (the 2x2-cell canopy groups) -- so one
  -- rect test usually answers for the whole stamp: strictly interior
  -- stamps keep every quad, ring stamps buried under a neighbour body
  -- (or, body-only, ring stamps full stop) skip without touching their
  -- quads. Only stamps crossing a boundary walk quad by quad.
  for _, st in ipairs(S.roundStamps or {}) do
    Budget.tick()
    local mx, mz = st.mx, st.mz
    local base = placementBase(mx, mz)
    local sr = st.r or 8
    local sx0, sz0, sx1, sz1 = mx - sr, mz - sr, mx + sr, mz + sr
    local interior = sx0 > 0 and sx1 < bw and sz0 > 0 and sz1 < bh
    local overBody = sx1 > 0 and sx0 < bw and sz1 > 0 and sz0 < bh
    local keepAll, skipAll
    if bodyOnly then
      keepAll = interior
      skipAll = not overBody
    else
      keepAll = interior or not maskedClosed(sx0, sz0, sx1, sz1)
      skipAll = not overBody and containedInMask(sx0, sz0, sx1, sz1)
    end
    if stampPlan and not skipAll then
      local signature, flags, kept
      if keepAll then
        signature, kept = "*", #st.quads
      else
        flags, kept = {}, 0
        for qi, q in ipairs(st.quads) do
          Budget.tick()
          for i = 1, 4 do
            local c, s2 = q[i], sc[i]
            s2[1] = c[1] + mx
            s2[2] = c[2]
            s2[3] = c[3] + mz
          end
          local x0 = math.min(sc[1][1], sc[2][1], sc[3][1], sc[4][1])
          local x1 = math.max(sc[1][1], sc[2][1], sc[3][1], sc[4][1])
          local z0 = math.min(sc[1][3], sc[2][3], sc[3][3], sc[4][3])
          local z1 = math.max(sc[1][3], sc[2][3], sc[3][3], sc[4][3])
          local yes = keepQuad(x0, z0, x1, z1)
          flags[qi] = yes and "\1" or "\0"
          if yes then kept = kept + 1 end
        end
        signature = table.concat(flags)
      end

      if kept > 0 then
        local variants = stampPlan.byTemplate[st.quads]
        if not variants then
          variants = {}
          stampPlan.byTemplate[st.quads] = variants
        end
        local group = variants[signature]
        if not group then
          local variantSink = newAsyncSink(stampPlan.job)
          group = { sink = variantSink, offsets = {}, quads = kept }
          variants[signature] = group
          stampPlan.groups[#stampPlan.groups + 1] = group
          -- Local coordinates are intentional. InstanceOffset applies the
          -- translation in both the camera and sun shaders, preserving UVs,
          -- AO shade and the exact clipping signature above.
          for qi, q in ipairs(st.quads) do
            if keepAll or flags[qi] == "\1" then
              Budget.tick()
              variantSink.push({ q[1], q[2], q[3], q[4] }, quadUV(q),
                               groundShades(q, q.shade))
            end
          end
        end
        group.offsets[#group.offsets + 1] = { mx, base, mz }
      end
    elseif not skipAll then
      for _, q in ipairs(st.quads) do
        Budget.tick()
        for i = 1, 4 do
          local c, s2 = q[i], sc[i]
          s2[1] = c[1] + mx
          s2[2] = c[2] + base
          s2[3] = c[3] + mz
        end
        local ok = keepAll
        if not ok then
          local x0 = math.min(sc[1][1], sc[2][1], sc[3][1], sc[4][1])
          local x1 = math.max(sc[1][1], sc[2][1], sc[3][1], sc[4][1])
          local z0 = math.min(sc[1][3], sc[2][3], sc[3][3], sc[4][3])
          local z1 = math.max(sc[1][3], sc[2][3], sc[3][3], sc[4][3])
          ok = keepQuad(x0, z0, x1, z1)
        end
        if ok then
          push(sc, quadUV(q), groundShades(sc, q.shade, base))
        end
      end
    end
  end
end

local INSTANCE_FORMAT = {
  { "InstanceOffset", "float", 3 },
}

local function trackPartial(job, object)
  job.partialMeshes = job.partialMeshes or {}
  job.partialMeshes[#job.partialMeshes + 1] = object
end

local function releasePartialsAfter(job, keep)
  local list = job.partialMeshes or {}
  for i = #list, keep + 1, -1 do
    local object = list[i]
    if object and object.release then pcall(object.release, object) end
    list[i] = nil
  end
  if #list == 0 then job.partialMeshes = nil end
end

-- A terrain bundle deliberately looks like a mesh to the cache: it has one
-- release method and Voxel3D/ShadowMap accept it wherever they accepted the
-- old single mesh. The attached offset meshes must stay alive for as long as
-- their template meshes, so ownership is closed here rather than leaked into
-- scene code.
local function meshBundle(base, groups)
  if #groups == 0 then return base end
  local bundle = {
    __voxelMeshBundle = true,
    base = base,
    instances = groups,
    released = false,
  }
  function bundle:release()
    if self.released then return end
    self.released = true
    if self.base and self.base.release then pcall(self.base.release, self.base) end
    for _, group in ipairs(self.instances or {}) do
      if group.mesh and group.mesh.release then
        pcall(group.mesh.release, group.mesh)
      end
      if group.source and group.source.release then
        pcall(group.source.release, group.source)
      end
    end
    self.base, self.instances = nil, {}
  end
  return bundle
end

local function instancingUnsupported(message)
  error({ voxelInstancingUnsupported = true, message = message }, 0)
end

local function instanceSource(job, offsets)
  local count = #offsets
  if count == 0 then error("empty instance placement stream", 0) end
  Budget.check()
  local ok, source = pcall(love.graphics.newMesh, INSTANCE_FORMAT, count,
                           "points", "static")
  if not ok then error(source, 0) end
  if not source then error("instance offset allocation returned nil", 0) end
  trackPartial(job, source)
  if type(source.setVertices) ~= "function" then
    instancingUnsupported("instance offset uploads are unavailable")
  end
  local first = 1
  while first <= count do
    local last = math.min(count, first + UPLOAD_VERTICES - 1)
    local upload = {}
    for i = first, last do
      upload[#upload + 1] = offsets[i]
      offsets[i] = nil
    end
    Budget.check()
    local uploaded, uploadErr = pcall(source.setVertices, source, upload,
                                       first, #upload)
    upload = nil
    if not uploaded then error(uploadErr, 0) end
    Budget.check()
    first = last + 1
  end
  return source, count
end

-- Finish the handful of unique clipped hull variants and attach their compact
-- placement streams. A capability mismatch is tagged specially so runJob can
-- release every partial allocation and retry once through exact expansion.
-- Allocation/upload failures remain ordinary job failures: retrying a much
-- larger expanded forest after an out-of-memory signal would be unsafe.
local function finishStampPlan(job, base, plan)
  local instances = {}
  for _, group in ipairs(plan.groups) do
    local mesh = group.sink.finish()
    if not mesh then error("empty instanced stamp variant", 0) end
    local source, count = instanceSource(job, group.offsets)
    if type(mesh.attachAttribute) ~= "function" then
      instancingUnsupported("per-instance attributes are unavailable")
    end
    local attached, attachErr = pcall(mesh.attachAttribute, mesh,
                                      "InstanceOffset", source,
                                      "perinstance")
    if not attached then instancingUnsupported(attachErr) end
    instances[#instances + 1] = {
      mesh = mesh,
      source = source,
      count = count,
    }
    -- Placement rows are now owned by the driver's source mesh. Do not retain
    -- hundreds of tiny Lua tables beside it for the lifetime of the cache.
    group.offsets = nil
    Budget.check()
  end
  return meshBundle(base, instances)
end

-- The raw geometry for `map`: (vertex list, triangle index list, quad
-- count). Synchronous and GPU-free -- the headless suite and the probes
-- exercise the invariants through this.
--
-- `split` lifts the water surface out, as it is lifted out for the
-- reflective pass, and appends that sink's own three values -- so the suite
-- can check the same separation the GPU path relies on without a GPU.
-- Without it the water is in the first list, which is what every existing
-- caller reads.
function ChunkMesher.geometry(map, bodyOnly, masks, split)
  local sink = newTableSink()
  local waterSink = split and newTableSink() or nil
  runGeometry(map, bodyOnly, masks, sink, waterSink)
  if not waterSink then return sink.results() end
  local v, i, n = sink.results()
  local wv, wi, wn = waterSink.results()
  return v, i, n, wv, wi, wn
end

-- Build the mesh for `map` synchronously. Returns nil when there is
-- nothing to draw or meshes are unavailable (headless).
--
-- `split` asks for the water surface as a SECOND mesh, returned after the
-- terrain one -- the shape the reflective pass needs (see Water). Without
-- it the water is inside the terrain mesh, which is the historical
-- contract and what every other caller still wants.
function ChunkMesher.build(map, bodyOnly, masks, split)
  local sink = newSink()
  local waterSink = split and newSink() or nil
  runGeometry(map, bodyOnly, masks, sink, waterSink)
  return sink.finish(), waterSink and waterSink.finish() or nil
end

local function elevationAtWorld(elevation, wx, wz)
  if type(elevation.atWorld) == "function" then
    return elevation:atWorld(wx, wz)
  end
  return elevation:at(math.floor(wx / 16), math.floor(wz / 16))
end

local function baseForWorldQuad(elevation, q)
  if not elevation then return 0 end
  local x0 = math.min(q[1][1], q[2][1], q[3][1], q[4][1])
  local x1 = math.max(q[1][1], q[2][1], q[3][1], q[4][1])
  local z0 = math.min(q[1][3], q[2][3], q[3][3], q[4][3])
  local z1 = math.max(q[1][3], q[2][3], q[3][3], q[4][3])
  local wx, wz = (x0 + x1) / 2, (z0 + z1) / 2
  local ax, ay, az = q[2][1] - q[1][1], q[2][2] - q[1][2],
                     q[2][3] - q[1][3]
  local bx, by, bz = q[3][1] - q[1][1], q[3][2] - q[1][2],
                     q[3][3] - q[1][3]
  local nx, nz = ay * bz - az * by, ax * by - ay * bx
  if x0 == x1 and wx % 16 == 0 then
    wx = wx + (nx < 0 and 0.001 or -0.001)
  end
  if z0 == z1 and wz % 16 == 0 then
    wz = wz + (nz < 0 and 0.001 or -0.001)
  end
  return elevationAtWorld(elevation, wx, wz)
end

local function quadsMesh(quads, job, elevation)
  if #quads == 0 then return nil end
  if job then
    local sink = newAsyncSink(job)
    local flatUV = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
    local shifted = { { 0, 0, 0 }, { 0, 0, 0 },
                      { 0, 0, 0 }, { 0, 0, 0 } }
    for _, q in ipairs(quads) do
      Budget.tick()
      local uv
      if q.uv then
        uv = q.uv
      else
        for i = 1, 4 do flatUV[i][1], flatUV[i][2] = q.u, q.v end
        uv = flatUV
      end
      local base = baseForWorldQuad(elevation, q)
      if base ~= 0 then
        for i = 1, 4 do
          local c, out = q[i], shifted[i]
          out[1], out[2], out[3] = c[1], c[2] + base, c[3]
        end
        sink.push(shifted, uv, q.shade)
      else
        sink.push({ q[1], q[2], q[3], q[4] }, uv, q.shade)
      end
    end
    return sink.finish()
  end
  local verts, indices, n = {}, {}, 0
  for _, q in ipairs(quads) do
    Budget.tick()
    local base = baseForWorldQuad(elevation, q)
    for i = 1, 4 do
      local c = q[i]
      local uv = q.uv and q.uv[i] or { q.u, q.v }
      verts[#verts + 1] = { c[1], c[2] + base, c[3],
                            uv[1], uv[2], q.shade }
    end
    Voxel3D.pushQuad(indices, n)
    n = n + 1
  end
  return Voxel3D.newMesh(verts, indices)
end

-- The tall-grass rows as their own mesh: VoxelScene draws it AFTER the
-- characters so the southern row of a grass cell still overdraws a
-- walker's feet (characters stamp over terrain, Gen 1 style, so ordinary
-- terrain could never do this).
local function expandedGrassMesh(groups, job, elevation)
  local sink = job and newAsyncSink(job) or newTableSink()
  local sc = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
  for _, group in ipairs(groups) do
    local p = group.placements or {}
    for at = 1, #p, 2 do
      Budget.tick()
      local mx, mz = p[at], p[at + 1]
      local base = elevationAtWorld(elevation, mx + 0.001, mz + 0.001)
      for _, q in ipairs(group.quads or {}) do
        Budget.tick()
        for i = 1, 4 do
          local c, out = q[i], sc[i]
          out[1], out[2], out[3] = c[1] + mx, c[2] + base, c[3] + mz
        end
        sink.push(sc, q.uv, q.shade)
      end
    end
  end
  return sink.finish()
end

local function instancedGrassMesh(groups, job, elevation)
  local plan = { groups = {} }
  for _, authored in ipairs(groups) do
    local placements = authored.placements or {}
    if #placements > 0 and #(authored.quads or {}) > 0 then
      local sink = newAsyncSink(job)
      for _, q in ipairs(authored.quads) do
        Budget.tick()
        sink.push({ q[1], q[2], q[3], q[4] }, q.uv, q.shade)
      end
      local offsets = {}
      for at = 1, #placements, 2 do
        Budget.tick()
        local mx, mz = placements[at], placements[at + 1]
        local base = elevationAtWorld(elevation, mx + 0.001, mz + 0.001)
        offsets[#offsets + 1] = { mx, base, mz }
      end
      plan.groups[#plan.groups + 1] = {
        sink = sink,
        offsets = offsets,
        quads = #authored.quads,
      }
    end
  end
  return finishStampPlan(job, nil, plan)
end

local function buildGrassMesh(map, job, elevation)
  elevation = elevation or elevationFor(map)
  local S = Structures.forMap(map)
  local groups = S.grassGroups
  -- Compatibility with an analysis made by an older hot-loaded build and
  -- with lightweight fixtures which still provide the historical flat list.
  if not groups then return quadsMesh(S.grassQuads or {}, job, elevation) end
  if not job then return expandedGrassMesh(groups, nil, elevation) end
  if type(Voxel3D.canInstance) ~= "function" or not Voxel3D.canInstance() then
    return expandedGrassMesh(groups, job, elevation)
  end

  local keep = #(job.partialMeshes or {})
  local ok, mesh = pcall(instancedGrassMesh, groups, job, elevation)
  if ok then return mesh end
  if type(mesh) == "table" and mesh.voxelInstancingUnsupported then
    releasePartialsAfter(job, keep)
    if type(Voxel3D.rejectInstancing) == "function" then
      Voxel3D.rejectInstancing()
    end
    return expandedGrassMesh(groups, job, elevation)
  end
  error(mesh, 0)
end

-- The flower billboards as their own mesh, for the same reason as the
-- grass one: it draws AFTER the characters WITH the same camera-ward
-- pull, so a flower south of a walker occludes their feet and one north
-- of them hides behind them. Baked into the terrain mesh they lost that
-- depth fight against the pulled character card whenever the player
-- stood among flowers. Unlike grass this mesh still CASTS shadows (the
-- sun pass draws it): a handful of flowers per meadow, not thousands of
-- tufts.
local function buildFlowerMesh(map, job, elevation)
  elevation = elevation or elevationFor(map)
  return quadsMesh(Structures.forMap(map).flowerQuads, job, elevation)
end

-- Authored FIGURES (a person drawn into furniture) as one mesh each, in
-- the card's own local space -- because each one is placed by its own
-- matrix at draw time, leaned back by the camera pitch exactly like a
-- character card (VoxelScene). A figure baked into the terrain mesh could
-- not lean, and a shared mesh could not carry per-figure placement.
--
-- A list, not a mesh: `{ mesh, wx, wz, y, w }` per figure. Maps have one
-- or none, so the loop that draws them is shorter than the terrain's.
-- `w` is the card's own width in its local space (its quads start at
-- x = 0), measured here because the first-person pass yaws a card about
-- its middle -- a card yawed about its left edge swings off its seat.
local function buildFigureMeshes(map, job, elevation)
  elevation = elevation or elevationFor(map)
  local out = {}
  for _, f in ipairs(Structures.forMap(map).figures or {}) do
    Budget.check()
    local mesh = quadsMesh(f.quads, job)
    if mesh then
      local w = 0
      for _, q in ipairs(f.quads) do
        for c = 1, 4 do
          local x = q[c] and q[c][1]
          if x and x > w then w = x end
        end
      end
      local base = elevationAtWorld(elevation, f.wx + w / 2, f.wz)
      out[#out + 1] = {
        mesh = mesh, wx = f.wx, wz = f.wz, y = f.y + base, w = w,
      }
    end
  end
  return out
end

-- Figure lists hold their meshes one level down, so the generic slot
-- release cannot reach them.
local function releaseFigures(list)
  for _, f in ipairs(type(list) == "table" and list or {}) do
    if f.mesh and f.mesh.release then pcall(f.mesh.release, f.mesh) end
  end
end

-- Replace a cached slot, releasing whatever mesh it held.
local function swapSlot(c, slot, mesh)
  local old = c[slot]
  if old and old ~= mesh and old.release then pcall(old.release, old) end
  c[slot] = mesh
end

-- ------------------------------------------------------------- the cache

local function entry(id)
  local c = cache[id]
  if not c then
    c = {}
    cache[id] = c
  end
  return c
end

-- The water surface that came out of a terrain slot's own build. Kept
-- beside it rather than in a slot of its own because the two are ONE
-- answer: a full mesh drawn beside a body build's water would draw the
-- ring's ponds twice and miss the body's own.
local function waterSlot(slot)
  return slot .. "Water"
end

local function releaseEntry(c)
  for _, slot in ipairs({ "full", "body", "fullWater", "bodyWater",
                          "grass", "flowers" }) do
    local mesh = c[slot]
    if mesh and mesh.release then pcall(mesh.release, mesh) end
    c[slot] = nil
  end
  releaseFigures(c.figures)
  c.figures = nil
  c.stale = nil
end

-- ---------------------------------------------------------- async builds

local jobs = {}       -- FIFO of pending jobs
local jobIndex = {}   -- "id:slot" -> job

local function clock()
  if love and love.timer and type(love.timer.getTime) == "function" then
    return love.timer.getTime()
  end
  return 0
end

local function jobKey(id, slot)
  return id .. ":" .. slot
end

local function releasePartialJob(job)
  releasePartialsAfter(job, 0)
end

local function finishJob(job, ok, err)
  if not ok then releasePartialJob(job) end
  jobIndex[jobKey(job.id, job.slot)] = nil
  for i, j in ipairs(jobs) do
    if j == job then
      table.remove(jobs, i)
      break
    end
  end
  if not ok then
    -- name the reason: in a real session a lost build is a black map
    print("[warn] voxel mesh build failed for " .. tostring(job.id)
          .. ": " .. tostring(err))
    if (gen[job.id] or 0) == job.gen then
      local c = entry(job.id)
      if c[job.slot] then
        -- refresh() deliberately leaves the previous mesh drawable while a
        -- replacement cooks. A failed rebuild must keep that known-good
        -- fallback (and its paired water mesh) rather than overwrite the only
        -- owner with `false`, which both exposed the 2D fallback and leaked
        -- the old GPU allocation. Stop this immediate retry cycle; a later
        -- explicit refresh/invalidation may try again.
        if c.stale then
          c.stale[job.slot] = nil
          c.stale.aux = nil
          if not (c.stale.full or c.stale.body or c.stale.aux) then
            c.stale = nil
          end
        end
      else
        c[job.slot] = false
      end
    end
  end
end

local function auxComplete(c)
  return c ~= nil and c.grass ~= nil and c.flowers ~= nil
         and c.figures ~= nil
end

local function buildAux(job, map)
  local elevation = elevationFor(map)
  local function attempt(fn)
    local keep = #(job.partialMeshes or {})
    local ok, result = pcall(fn, map, job, elevation)
    if not ok then releasePartialsAfter(job, keep) end
    return ok, result
  end
  local okG, grass = attempt(buildGrassMesh)
  local okF, flowers = attempt(buildFlowerMesh)
  local okX, figures = attempt(buildFigureMeshes)
  return {
    grass = (okG and grass) or false,
    flowers = (okF and flowers) or false,
    figures = (okX and figures) or false,
  }
end

local function landAux(c, aux)
  swapSlot(c, "grass", aux.grass)
  swapSlot(c, "flowers", aux.flowers)
  releaseFigures(c.figures)
  c.figures = aux.figures
  c.requireAux = nil
  if c.stale then c.stale.aux = nil end
end

local function buildAsyncTerrain(job, useInstances)
  local sink = newAsyncSink(job)
  local waterSink = newAsyncSink(job)
  local plan = useInstances and {
    job = job,
    groups = {},
    byTemplate = {},
  } or nil
  runGeometry(job.map, job.slot == "body", job.masks, sink, waterSink,
              plan)
  local mesh = sink.finish()
  local water = waterSink.finish()
  if plan then mesh = finishStampPlan(job, mesh, plan) end
  return mesh, water
end

local function buildJobTerrain(job)
  if type(Voxel3D.canInstance) ~= "function" or not Voxel3D.canInstance() then
    return buildAsyncTerrain(job, false)
  end
  local ok, mesh, water = pcall(buildAsyncTerrain, job, true)
  if ok then return mesh, water end
  if type(mesh) == "table" and mesh.voxelInstancingUnsupported then
    -- The advertised capability was not actually usable. Close the partial
    -- bundle before doing any more allocation, make the rejection sticky for
    -- this session, and retry exactly once through the old expanded path.
    releasePartialJob(job)
    if type(Voxel3D.rejectInstancing) == "function" then
      Voxel3D.rejectInstancing()
    end
    return buildAsyncTerrain(job, false)
  end
  error(mesh, 0)
end

-- A build only lands if the map's generation still matches the one the
-- job was queued under -- invalidate/evict bump it to cancel in-flight
-- work whose inputs went stale.
local function runJob(job)
  local map = job.map
  local c = entry(job.id)
  if job.auxOnly then
    local aux = buildAux(job, map)
    if (gen[job.id] or 0) ~= job.gen then
      releasePartialJob(job)
      return
    end
    landAux(c, aux)
    job.partialMeshes = nil
    return
  end

  local mesh, water = buildJobTerrain(job)
  -- The current map is one visual answer: terrain without its tall grass is a
  -- conspicuous pop on Route 1. A neighbour may expose terrain first and warm
  -- decorations later, but promotion sets needsAtomicAux and pair()/ready()
  -- hide that cached terrain until this same budgeted job completes its aux.
  local atomicAux = job.needsAtomicAux and not auxComplete(c)
  local aux = atomicAux and buildAux(job, map) or nil
  if (gen[job.id] or 0) ~= job.gen then
    releasePartialJob(job)
    return
  end
  swapSlot(c, job.slot, mesh or false)
  swapSlot(c, waterSlot(job.slot), water or false)
  if aux then landAux(c, aux) end
  -- Ownership moved into the cache.  A later decoration failure must not
  -- release terrain that is already drawable there.
  job.partialMeshes = nil
  if c.stale then
    c.stale[job.slot] = nil
  end

  if auxComplete(c) then
    if c.stale and not (c.stale.full or c.stale.body or c.stale.aux) then
      c.stale = nil
    end
    return
  end

  -- Neighbour terrain can hand off to the cache immediately; VoxelScene keeps
  -- that body behind its semantic horizon until auxComplete(c). Only the
  -- current map takes the atomic path above. Demote and rotate so another
  -- body's terrain can warm while this job resumes its finishing overlays
  -- later, without serialising every connection ahead of the current scene.
  job.urgent = false
  coroutine.yield("terrain-ready")

  -- Decorations can now finish without delaying the first visible voxel
  -- frame. They still share the terrain job so there is no extra queue type
  -- or duplicate work when both body and full variants were requested.
  if c.grass == nil or c.flowers == nil or c.figures == nil
     or (c.stale and c.stale.aux) then
    aux = buildAux(job, map)
    if (gen[job.id] or 0) ~= job.gen then
      releasePartialJob(job)
      return
    end
    landAux(c, aux)
    job.partialMeshes = nil
  end
  if c.stale then
    if not (c.stale.full or c.stale.body or c.stale.aux) then
      c.stale = nil
    end
  end
end

-- Queue a build unless the slot is already cached or queued. Returns the
-- cached mesh when there is one (false-cached misses return nil).
-- `urgent` marks the current map's meshes: pump() gives those a bigger
-- slice and runs them before neighbour jobs. `priority` ranks ordinary
-- background work (2 = approached seam, 1 = another direct connection,
-- 0 = survey/return work); it NEVER receives the urgent time slice, so
-- smoothing a seam cannot grow the frame budget. A slot refresh() marked
-- stale queues its rebuild AND keeps handing back the old mesh, so a
-- one-block edit never drops the scene to the flat 2D path while the
-- replacement cooks.
function ChunkMesher.request(map, bodyOnly, masks, urgent, priority)
  local priorityRank = priority == true and 2
                       or (type(priority) == "number" and priority or 0)
  if priorityRank < 0 then priorityRank = 0 end
  local slot = bodyOnly and "body" or "full"
  local c = cache[map.id]
  local stale = c and c.stale and (c.stale[slot] or c.stale.aux)
  local key = jobKey(map.id, slot)
  local job = jobIndex[key]
  if job then job.live = true end -- a fresh request promotes return-cache work
  -- VoxelScene identifies the approached seam afresh every frame. Clear the
  -- old hint when that map is still queued but no longer the candidate; urgent
  -- current-map ownership remains independent.
  if job and not urgent then job.priority = priorityRank end
  if c and c[slot] ~= nil and not stale then
    if (urgent or priorityRank > 0) and not auxComplete(c) then
      c.requireAux = c.requireAux or {}
      if urgent then c.requireAux[slot] = true end
      if not job then
        job = { id = map.id, map = map, slot = slot, masks = masks,
                urgent = urgent or false, priority = priorityRank,
                live = true,
                needsAtomicAux = urgent or false, auxOnly = true,
                gen = gen[map.id] or 0 }
        jobIndex[key] = job
        jobs[#jobs + 1] = job
      else
        if urgent then
          job.urgent = true
          job.needsAtomicAux = true
        end
        if priorityRank > (job.priority or 0) then
          job.priority = priorityRank
        end
      end
      if urgent then return nil end
      return c[slot] or nil
    end
    return c[slot] or nil
  end
  if not job then
    job = { id = map.id, map = map, slot = slot, masks = masks,
            urgent = urgent or false, priority = priorityRank,
            live = true,
            needsAtomicAux = urgent or false,
            gen = gen[map.id] or 0 }
    jobIndex[key] = job
    jobs[#jobs + 1] = job
  elseif urgent then
    job.urgent = true
    job.needsAtomicAux = true
  end
  if priorityRank > (job.priority or 0) then job.priority = priorityRank end
  return (c and c[slot]) or nil
end

function ChunkMesher.pending()
  return #jobs
end

-- Advance queued builds inside a per-frame time budget. Urgent jobs (the
-- current map) come first and get the larger slice -- the first voxel
-- frame after a toggle is worth more milliseconds than a neighbour
-- popping in one frame later. `covered` says the world pass is hidden
-- this frame (a warp's fade, a menu): nothing visible can hitch, so the
-- slice opens up and a door fade swallows most of a destination build.
local URGENT_SLICE = 0.012
local IDLE_SLICE = 0.005
-- A transition may cover the world, but it does not stop the engine's own
-- fade/input/update work.  Spending 30ms here simply added that whole slice
-- to an already expensive setMap frame (about 67ms in the cold-map QA), which
-- is why a covered warp could still visibly stop for roughly 100ms.  Keep the
-- extra work below one 60Hz frame; cold maps may need a few more fade frames,
-- but no single one receives a large VASC-only spike.
local COVERED_SLICE = 0.006
local BACKGROUND_SLICE = 0.002
local LOADING_SLICE = 0.008

function ChunkMesher.pump(covered, background, loading)
  if #jobs == 0 then return end
  local function nextJob()
    local firstPriority, firstPriorityRank, firstLive = nil, 0, nil
    for _, job in ipairs(jobs) do
      if job.urgent then return job end
      local rank = type(job.priority) == "number"
                   and job.priority or (job.priority and 2 or 0)
      if job.live and rank > firstPriorityRank then
        firstPriority, firstPriorityRank = job, rank
      end
      if job.live and not firstLive then firstLive = job end
    end
    -- A retained previous neighbourhood is a return cache, never work the
    -- current view is waiting for. Keep it queued, but only spend on it after
    -- every current-live job (approached seam first) has yielded/completed.
    return firstPriority or firstLive or jobs[1]
  end
  local pick = nextJob()
  local slice = background and BACKGROUND_SLICE
                or covered and COVERED_SLICE
                or loading and LOADING_SLICE
                or (pick.urgent and URGENT_SLICE or IDLE_SLICE)
  local deadline = clock() + slice
  while pick do
    if not pick.co then
      pick.co = coroutine.create(runJob)
    end
    Budget.begin(pick.co, deadline - clock())
    local ok, yielded = coroutine.resume(pick.co, pick)
    Budget.finish()
    if not ok then
      finishJob(pick, false, yielded)
    elseif coroutine.status(pick.co) == "dead" then
      finishJob(pick, true)
    else
      if yielded == "terrain-ready" and #jobs > 1 then
        for i, queued in ipairs(jobs) do
          if queued == pick then
            table.remove(jobs, i)
            jobs[#jobs + 1] = pick
            break
          end
        end
      end
      -- `terrain-ready` is an intentional hand-off, not a spent Budget slice.
      -- Continue with the next terrain job while this frame still has room;
      -- a Budget yield (nil/other) still returns immediately as before.
      if yielded ~= "terrain-ready" then return end
    end
    if clock() >= deadline or #jobs == 0 then return end
    pick = nextJob()
    -- Once the last required terrain job handed off, do not spend the tail of
    -- its transition slice entering a non-urgent decoration build. Those old
    -- table uploads are allowed on the following idle slice; starting one here
    -- made the nominal 6ms fade budget overshoot just before the scene became
    -- drawable.
    if yielded == "terrain-ready" and not pick.urgent then return end
  end
end

-- Meshes for `map`, built SYNCHRONOUSLY on first use -- the historical
-- contract, kept for probes and any direct caller. `false` is cached for
-- a map whose mesh could not be built so a headless run does not retry
-- every frame. `masks` (the full variant's neighbour-body rects) is
-- static per map id -- a map's connections never change -- so it caches
-- like everything else.
function ChunkMesher.get(map, bodyOnly, masks)
  local slot = bodyOnly and "body" or "full"
  local c = entry(map.id)
  if c.grass == nil or c.flowers == nil or c.figures == nil
     or (c.stale and c.stale.aux) then
    local elevation = elevationFor(map)
    local okG, grass = pcall(buildGrassMesh, map, nil, elevation)
    local okF, flowers = pcall(buildFlowerMesh, map, nil, elevation)
    local okX, figures = pcall(buildFigureMeshes, map, nil, elevation)
    swapSlot(c, "grass", (okG and grass) or false)
    swapSlot(c, "flowers", (okF and flowers) or false)
    releaseFigures(c.figures)
    c.figures = (okX and figures) or false
    if c.stale then c.stale.aux = nil end
  end
  if c[slot] == nil or (c.stale and c.stale[slot]) then
    local ok, mesh, water = pcall(ChunkMesher.build, map, bodyOnly, masks,
                                  true)
    if not ok then
      print("[warn] voxel mesh build failed for " .. tostring(map.id)
            .. ": " .. tostring(mesh))
    end
    swapSlot(c, slot, (ok and mesh) or false)
    swapSlot(c, waterSlot(slot), (ok and water) or false)
    if c.stale then
      c.stale[slot] = nil
      if not (c.stale.full or c.stale.body or c.stale.aux) then
        c.stale = nil
      end
    end
    local key = jobKey(map.id, slot)
    local job = jobIndex[key]
    if job then finishJob(job, true) end
  end
  return c[slot] or nil
end

-- The cached mesh, or nil -- never builds. The async path's read side.
function ChunkMesher.peek(map, bodyOnly)
  local c = cache[map.id]
  local slot = bodyOnly and "body" or "full"
  local mesh = c and not (c.requireAux and c.requireAux[slot]) and c[slot]
  return mesh or nil
end

-- Whether an asynchronous terrain slot already has drawable geometry.
function ChunkMesher.ready(map, bodyOnly)
  local c = cache[map.id]
  local slot = bodyOnly and "body" or "full"
  -- A stale mesh is deliberately still drawable while its replacement cooks
  -- (cut trees, opened doors, edited blocks). The false failure/empty sentinel
  -- must not open a hole in the horizon union.
  if c and c.requireAux and c.requireAux[slot] then return false end
  return (c and c[slot]) or false
end

-- Whether the atomic grass/flower/figure bundle has landed. A `false` slot is
-- a valid completed result for a map with none of that geometry. The current
-- terrain request also uses this to stay atomic; VoxelScene uses it to keep a
-- terrain-ready neighbour behind the semantic horizon until every visible
-- finishing overlay is present.
function ChunkMesher.auxReady(map)
  local c = cache[map.id]
  return c ~= nil and c.grass ~= nil and c.flowers ~= nil
         and c.figures ~= nil
end

-- A slot's terrain mesh AND the water surface lifted out of it, as one
-- answer. Never builds, like peek.
--
-- Both or neither, always from the SAME slot: the water was cut out of that
-- exact geometry, so pairing a full mesh with a body build's water would
-- draw the border ring's ponds twice and leave the body's as holes. Callers
-- that fall back from one variant to the other fall back through this, so
-- there is nowhere for the two to be chosen separately.
function ChunkMesher.pair(map, bodyOnly)
  local c = cache[map.id]
  if not c then return nil, nil end
  local slot = bodyOnly and "body" or "full"
  if c.requireAux and c.requireAux[slot] then return nil, nil end
  return c[slot] or nil, c[waterSlot(slot)] or nil
end

function ChunkMesher.grass(map)
  local c = cache[map.id]
  return c and c.grass or nil
end

function ChunkMesher.flowers(map)
  local c = cache[map.id]
  return c and c.flowers or nil
end

-- Authored figures as `{ mesh, wx, wz, y, w }` records -- each placed by
-- its own leaning matrix at draw time, so they cannot share one mesh.
function ChunkMesher.figures(map)
  local c = cache[map.id]
  local list = c and c.figures
  return (type(list) == "table") and list or nil
end

-- Rebuild a map's meshes IN PLACE: the stale meshes keep drawing while
-- replacements cook, and each slot swaps as its build lands. This is
-- the block-edit path (a cut tree, a door stamp) -- invalidate() drops
-- the mesh outright, and until the async rebuild landed the scene fell
-- to the flat 2D path, a whole-world blink for a one-block edit.
function ChunkMesher.refresh(mapId)
  if not mapId then return ChunkMesher.invalidate() end
  local c = cache[mapId]
  -- nothing drawable cached: the plain drop costs nothing visible
  if not (c and (c.full or c.body)) then
    return ChunkMesher.invalidate(mapId)
  end
  invalidateElevation(mapId)
  Structures.invalidate(mapId)
  gen[mapId] = (gen[mapId] or 0) + 1
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if job.id == mapId then
      releasePartialJob(job)
      jobIndex[jobKey(job.id, job.slot)] = nil
      table.remove(jobs, i)
    end
  end
  -- false-cached slots count as stale too: a retry after a failed build
  -- is exactly a rebuild
  c.stale = { aux = true,
              full = (c.full ~= nil) or nil,
              body = (c.body ~= nil) or nil }
end

-- Evict everything outside `live` (a set of map ids): far maps' meshes
-- are released -- GPU buffer and LOVE's CPU copy both -- and their
-- Structures analysis dropped. The live set is the current map plus its
-- rendered neighbours, so memory stays bounded by what is on or near the
-- screen instead of growing with every area ever visited.
--
-- The PREVIOUS live set is retained too: warping into a building
-- collapses the set to one small interior, and evicting the town at the
-- door means rebuilding the whole neighbourhood on the way out -- a
-- flat-world flash after every house. One set of history makes the
-- round trip free while staying bounded at two neighbourhoods.
local prevLive = {}

function ChunkMesher.setLive(live)
  for id, c in pairs(cache) do
    if not live[id] then c.requireAux = nil end
    if not live[id] and not prevLive[id] then
      releaseEntry(c)
      cache[id] = nil
      gen[id] = (gen[id] or 0) + 1
      Structures.invalidate(id)
      invalidateElevation(id)
    end
  end
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if not live[job.id] and not prevLive[job.id] then
      releasePartialJob(job)
      jobIndex[jobKey(job.id, job.slot)] = nil
      table.remove(jobs, i)
      invalidateElevation(job.id)
    elseif not live[job.id] then
      -- Keep one previous neighbourhood warm for a quick door round-trip,
      -- but it is no longer the destination. An unfinished job used to retain
      -- urgent=true and win pump() over the newly entered map, extending the
      -- covered transition for work the player could no longer see.
      job.urgent = false
      job.priority = 0
      job.live = false
      job.needsAtomicAux = false
    else
      job.live = true
    end
  end
  prevLive = live
end

-- Drop one map's mesh (Cut swapped a block) or all of them (hot reload).
-- Structures' analysis is derived from the same block layer, so it drops
-- in the same breath; in-flight builds of the map are cancelled through
-- the generation counter.
function ChunkMesher.invalidate(mapId)
  Structures.invalidate(mapId)
  invalidateElevation(mapId)
  if mapId then
    local c = cache[mapId]
    if c then releaseEntry(c) end
    cache[mapId] = nil
    gen[mapId] = (gen[mapId] or 0) + 1
  else
    for _, c in pairs(cache) do releaseEntry(c) end
    cache = {}
    for id in pairs(gen) do gen[id] = gen[id] + 1 end
  end
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if mapId == nil or job.id == mapId then
      releasePartialJob(job)
      jobIndex[jobKey(job.id, job.slot)] = nil
      table.remove(jobs, i)
    end
  end
end

Assets.register(function() ChunkMesher.invalidate() end)

return ChunkMesher
