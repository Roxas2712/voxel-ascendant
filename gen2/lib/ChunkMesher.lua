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
local Budget = V.require("BuildBudget")
local PerformancePolicy = V.require("Gen2PerformancePolicy")
local DeviceProfile = V.require("DeviceProfile")
local PersistentCache = V.require("Gen2MeshCache")
local MeshParts = V.require("MeshParts")

local ffi = nil
do
  local ok, mod = pcall(require, "ffi")
  if ok then ffi = mod end
end

local ChunkMesher = {}

-- Ring of border blocks meshed around the body. The explicit MAX profile
-- retains the historical eight-block/32-tile panorama; normal Gen-2 profiles
-- use a bounded apron so a cold Crystal route does not spend seconds meshing
-- scenery far outside the playable map. This is actual geometry and the
-- connected-neighbour masks below still remove overlap.
local function apronBlocks()
  local profile = "handheld"
  if DeviceProfile and type(DeviceProfile.effective) == "function" then
    local ok, value = pcall(DeviceProfile.effective)
    if ok and type(value) == "string" then profile = value end
  end
  return PerformancePolicy.apronBlocks(profile)
end

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

local cache = {}     -- map id -> { full = mesh|false, body = ..., grass = ... }
-- A failed async build used to be indistinguishable from a build that was
-- merely still pending.  Gold's compose bridge needs the actual error so it
-- can stop silently returning the flat world forever.
local lastErrors = {} -- map id -> most recent terrain-mesh build error
local gen = {}       -- map id -> generation, bumped by invalidate/evict

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

-- Same upper-face receipt as Gen1. Preserve shade/sign independently from
-- geometry: a bright vertical facade must never be mistaken for a roof.
local function weatherFacing(c)
  local ax, az = c[2][1] - c[1][1], c[2][3] - c[1][3]
  local bx, bz = c[3][1] - c[1][1], c[3][3] - c[1][3]
  return math.abs(az * bx - ax * bz) > 0.0001
end

local function weatherShade(value, facing)
  if not facing then return value end
  return value < 0 and value - 2 or value + 2
end

-- A sink accepts quads (4 corners, 4 uv pairs, flat or per-corner shade)
-- and finishes into a drawable mesh. The TABLE sink reproduces the
-- historical pure-Lua output -- geometry() returns its arrays for the
-- headless suite. The FFI sink packs the same six floats per vertex
-- straight into one growing native buffer, unindexed (v1 v2 v3 v1 v3 v4),
-- skipping ~a million short-lived Lua tables per route and LOVE's slow
-- table-by-table vertex upload.

local function newTableSink(_expectedQuads)
  local verts, indices, quads = {}, {}, 0
  return {
    push = function(c, uv, shade)
      local flat = type(shade) ~= "table"
      local facing = weatherFacing(c)
      for i = 1, 4 do
        local cc = c[i]
        local t = uv and uv[i]
        verts[#verts + 1] = { cc[1], cc[2], cc[3],
                              t and t[1] or c.u, t and t[2] or c.v,
                              weatherShade(flat and shade or shade[i], facing) }
      end
      Voxel3D.pushQuad(indices, quads)
      quads = quads + 1
    end,
    results = function()
      return verts, indices, quads
    end,
    cacheSource = function()
      return verts, indices
    end,
    finish = function()
      return Voxel3D.newMesh(verts, indices)
    end,
  }
end

local TRI_ORDER = { 1, 2, 3, 1, 3, 4 }
local unpackArgs = table.unpack or unpack

-- The Gen-2 mod sandbox deliberately hides LuaJIT's FFI module.  Falling
-- through to newTableSink in a real Gold/Silver/Crystal session made LOVE
-- walk hundreds of thousands of nested Lua vertex tables in one unyieldable
-- call.  Pack modest pages through LOVE's public Data API instead: identical
-- unindexed float32 vertices, bounded conversion/upload work, and only byte
-- strings retained between coroutine slices.
-- 512 quads are 3,072 vertices / 72 KiB.  That stays below the atomic
-- upload size which remained smooth on the slow OpenGL path, while avoiding
-- thousands of tiny ByteData objects on forest-heavy maps.
local PACKED_PAGE_QUADS = 512

local function newPackedSink(expectedQuads)
  local pages, page = {}, {}
  local vertices, quads = 0, 0

  local function append(cc, u, v, shade)
    page[#page + 1] = cc[1]
    page[#page + 1] = cc[2]
    page[#page + 1] = cc[3]
    page[#page + 1] = u
    page[#page + 1] = v
    page[#page + 1] = shade
    vertices = vertices + 1
  end

  local function sealPage()
    if #page == 0 then return end
    Budget.check()
    local pieces = {}
    -- Keep each pack call comfortably below LuaJIT's argument ceiling and
    -- yield between chunks.  The resulting strings concatenate to the exact
    -- native float stream accepted by Mesh:setVertices(ByteData).
    local VALUES = 1536
    for at = 1, #page, VALUES do
      local last = math.min(at + VALUES - 1, #page)
      local ok, packed = pcall(love.data.pack, "string",
        "=" .. string.rep("f", last - at + 1),
        unpackArgs(page, at, last))
      if not ok then error(packed, 0) end
      pieces[#pieces + 1] = packed
      Budget.check()
    end
    pages[#pages + 1] = {
      packed = table.concat(pieces),
      count = #page / 6,
    }
    page = {}
    Budget.check()
  end

  local sink = {
    kind = "packed",
    push = function(c, uv, shade)
      local flat = type(shade) ~= "table"
      local facing = weatherFacing(c)
      for k = 1, 6 do
        local i = TRI_ORDER[k]
        local t = uv and uv[i]
        append(c[i], t and t[1] or c.u, t and t[2] or c.v,
               weatherShade(flat and shade or shade[i], facing))
      end
      quads = quads + 1
      if quads % PACKED_PAGE_QUADS == 0 then sealPage() end
    end,
    vertexCount = function() return vertices end,
    rawBytes = function()
      sealPage()
      local pieces = {}
      for i, upload in ipairs(pages) do pieces[i] = upload.packed end
      return table.concat(pieces)
    end,
  }

  sink.finish = function()
    if vertices == 0 then return nil end
    sealPage()
    local meshes, pageAt = {}, 1
    while pageAt <= #pages do
      local partCount, pageLast = 0, pageAt - 1
      while pageLast + 1 <= #pages do
        local nextCount = pages[pageLast + 1].count
        if partCount > 0
            and partCount + nextCount > MeshParts.MAX_VERTICES then break end
        partCount = partCount + nextCount
        pageLast = pageLast + 1
      end

      Budget.phase("mesh-upload:new-part:" .. tostring(partCount))
      Budget.check()
      local ok, mesh = pcall(love.graphics.newMesh, Voxel3D.FORMAT,
                             partCount, "triangles", "static")
      if not ok or not mesh then
        MeshParts.release(meshes)
        error(mesh or "mesh allocation failed", 0)
      end

      local first = 1
      for i = pageAt, pageLast do
        local upload = pages[i]
        local packed = upload.packed
        upload.packed = nil
        Budget.phase("mesh-upload:set:" .. tostring(upload.count))
        Budget.check()
        local dataOK, data = pcall(love.data.newByteData, packed)
        packed = nil
        if not dataOK or not data then
          if mesh.release then pcall(mesh.release, mesh) end
          MeshParts.release(meshes)
          error(data or "vertex ByteData allocation failed", 0)
        end
        local setOK, setErr = pcall(mesh.setVertices, mesh, data, first,
                                    upload.count)
        if data.release then pcall(data.release, data) end
        if not setOK then
          if mesh.release then pcall(mesh.release, mesh) end
          MeshParts.release(meshes)
          error(setErr, 0)
        end
        first = first + upload.count
        pages[i] = nil
        Budget.check()
      end
      meshes[#meshes + 1] = mesh
      pageAt = pageLast + 1
      Budget.check()
    end
    return MeshParts.wrap(meshes)
  end

  return sink
end

local function newFfiSink(expectedQuads)
  -- Retained decoration lists already know their final quad count.  Reserve
  -- that native buffer once so a dense forest does not repeatedly double and
  -- memcpy an ever-growing grass mesh inside a visible frame.
  local cap = math.max(4096 * 6,
    math.max(0, tonumber(expectedQuads) or 0) * 6)
  local buf = ffi.new("float[?]", cap * 6)
  local n = 0
  local sink
  sink = {
    push = function(c, uv, shade)
      local facing = weatherFacing(c)
      if n + 6 > cap then
        local grown = ffi.new("float[?]", cap * 2 * 6)
        ffi.copy(grown, buf, n * 6 * 4)
        buf, cap = grown, cap * 2
      end
      local flat = type(shade) ~= "table"
      local base = n * 6
      for k = 1, 6 do
        local i = TRI_ORDER[k]
        local cc = c[i]
        local t = uv and uv[i]
        buf[base] = cc[1]
        buf[base + 1] = cc[2]
        buf[base + 2] = cc[3]
        buf[base + 3] = t and t[1] or c.u
        buf[base + 4] = t and t[2] or c.v
        buf[base + 5] = weatherShade(flat and shade or shade[i], facing)
        base = base + 6
      end
      n = n + 6
    end,
    finish = function()
      if n == 0 then return nil end
      -- upload in slices with budget ticks between: a route-sized mesh
      -- is ~10-20MB and one atomic setVertices was the last remaining
      -- frame spike. The mesh is not cached (so never drawn) until the
      -- whole upload lands, and LuaJIT yields fine across pcall.
      Budget.phase("mesh-upload:prepare:" .. tostring(n))
      local ok, mesh = pcall(function()
        Budget.phase("mesh-upload:new:" .. tostring(n))
        local m = love.graphics.newMesh(Voxel3D.FORMAT, n,
                                        "triangles", "static")
        Budget.phase("mesh-upload:set:" .. tostring(n))
        -- Keep the GPU upload genuinely cooperative on slower/OpenGL-backed
        -- Macs.  Even a 16k-vertex setVertices call reached 400 ms under the
        -- memory pressure of Ilex Forest, after which Budget.check() was
        -- necessarily too late.  4k keeps each atomic upload near 96 KiB
        -- while preserving one final mesh and an all-at-once cache swap.
        local CHUNK = 4096
        local i = 0
        while i < n do
          local count = math.min(CHUNK, n - i)
          local bytes = count * 6 * 4
          local data = love.data.newByteData(bytes)
          ffi.copy(data:getFFIPointer(), buf + i * 6, bytes)
          m:setVertices(data, i + 1)
          data:release()
          i = i + count
          Budget.check()
        end
        return m
      end)
      return ok and mesh or nil
    end,
    vertexCount = function() return n end,
    rawBytes = function()
      if n == 0 then return "" end
      return ffi.string(buf, n * 6 * 4)
    end,
    kind = "ffi",
  }
  return sink
end

local function newSink(expectedQuads)
  if ffi and love and love.data and love.data.newByteData
     and love.graphics and love.graphics.newMesh then
    return newFfiSink(expectedQuads)
  end
  if love and love.data and type(love.data.pack) == "function"
      and love.data.newByteData and love.graphics
      and love.graphics.newMesh then
    return newPackedSink(expectedQuads)
  end
  return newTableSink(expectedQuads)
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
  -- BODY owns a separate body-only structure analysis.  Reusing FULL's
  -- synthetic apron here was both the cold-start bottleneck and the source of
  -- giant boundary-tree fragments in the first drawable voxel frame.
  Budget.phase("structure-analysis")
  local S = Structures.forMap(map, bodyOnly == true)
  Budget.phase("terrain-geometry")
  local perRow = tileset.tilesPerRow or 16
  local atlasW = tileset.imageWidth or (perRow * 8)
  local atlasH = tileset.imageHeight or 48

  local function heightAt(tx, ty)
    local k = keyOf(tx, ty)
    if S.skip[k] then return S.groundHeights and S.groundHeights[k] or 0 end
    local run = S.runs[k]
    if run then return run.h end
    local s = S.shapeAt[k]
    return s and s.h or 0
  end

  -- one atlas-rect UV, optionally cropped to art rows [vTop, vBot] of 8
  local function uvRect(tile, vTop, vBot)
    local ax = (tile % perRow) * 8
    local ay = math.floor(tile / perRow) * 8
    local vi = math.min(INSET, (vBot - vTop) / 4)
    return (ax + INSET) / atlasW, (ax + 8 - INSET) / atlasW,
           (ay + vTop + vi) / atlasH, (ay + vBot - vi) / atlasH
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
  local function groundShades(c, shade, baseY)
    if type(shade) == "table" then return shade end
    baseY = baseY or 0
    local y1, y2, y3, y4 = c[1][2], c[2][2], c[3][2], c[4][2]
    if math.min(y1, y2, y3, y4) - baseY >= AO_RISE then return shade end
    for i = 1, 4 do
      -- Contact darkening reaches its maximum at the support plane. Authored
      -- shafts/stairs extend below it; extrapolation there turned lighting
      -- negative (and inverted the packed caster sign). Their own face shades
      -- already describe the well's darkness. Leave above-floor AO unchanged.
      local t = math.max(0, (c[i][2] - baseY) / AO_RISE)
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
  local function topQuad(x0, z0, h, tile, shade, to)
    local u0, u1, v0, v1 = uvRect(tile, 0, 8)
    ;(to or push)({ { x0, h, z0 }, { x0 + 8, h, z0 },
                    { x0 + 8, h, z0 + 8 }, { x0, h, z0 + 8 } },
                  { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } },
                  aoShades(x0 / 8, z0 / 8, h, shade))
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
  -- Resolve once per job: changing a profile cannot resize a running
  -- coroutine halfway through its loops.
  local r = bodyOnly and 0 or apronBlocks() * 4

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
          local baseY = S.groundHeights and S.groundHeights[k] or 0
          topQuad(tx * 8, ty * 8, baseY, g, 1)
          -- The claimed tile is ground at its support level; water next
          -- door still recesses below it. Without the same exposed
          -- side bands ordinary ground emits, the two-pixel shoreline
          -- face is a slit into the sky behind the mesh -- which is
          -- exactly what a building plot or a sign standing at the
          -- waterline showed. Same bands, cut from the synthesized
          -- ground's own art
          for _, side in ipairs(SIDES) do
            local nh = heightAt(tx + side[1], ty + side[2])
            if nh < baseY then
              local d = side[3]
              local lat = LATERAL[d]
              local hl = lat and heightAt(tx + lat[1], ty + lat[2]) or 0
              local hr = lat and heightAt(tx + lat[3], ty + lat[4]) or 0
              for band = math.floor(nh / 8), math.ceil(baseY / 8) - 1 do
                local y0 = math.max(nh, band * 8)
                local y1 = math.min(baseY, band * 8 + 8)
                if y1 > y0 then
                  sideQuad(d, tx * 8, ty * 8, y0, y1, g,
                           (band * 8 + 8) - y1, (band * 8 + 8) - y0,
                           sideShades(hl, hr, y0, y1, y0 <= nh,
                                      Voxel3D.FACE_SHADE[d]))
                end
              end
            end
          end
        end
      elseif s then
        local run = S.runs[k]
        local h = run and run.h or s.h
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
            return run.h + run.rise * math.max(0, math.min(1, t))
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
          if heightAt(tx - 1, ty) < run.h then     -- west flank: hip
            swY = math.max(run.h, hS - 8)
            nwY = math.max(run.h, hN - 8)
          end
          if heightAt(tx + 1, ty) < run.h then     -- east flank: hip
            seY = math.max(run.h, hS - 8)
            neY = math.max(run.h, hN - 8)
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
          local topTile = tile
          if s.art == "upright" and s.authored then
            -- Top art for a pinned box.  A furniture drawing is top-view
            -- rows over ceil(h/8) face-on rows the fold stands upright;
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
            -- A six-pixel desk still consumes one (cropped) face row.
            -- floor(6/8) kept that face on the lid as a second keyboard,
            -- drawer or bench front instead of extending the tabletop.
            local row = math.min(ty, front - math.ceil(h / 8))
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
            if s.surfaceTiles then topTile = s.surfaceTiles[topTile] or topTile end
          end
          -- water's surface, and only water's: the recessed sheet itself,
          -- never the ground's shoreline bands around it. A cell an object
          -- stands on took the branch above and paints synthesized GROUND,
          -- which is right -- a sign at the waterline stands on a plot, not
          -- on the pond.
          topQuad(x0, z0, h, topTile,
                  s.art == "upright" and VOLUME_TOP_SHADE or 1,
                  (s.class == "water") and waterPush or nil)
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
            for band = math.floor(nh / 8), math.ceil(h / 8) - 1 do
              local y0 = math.max(nh, band * 8)
              local y1 = math.min(h, band * 8 + 8)
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
                    src = map:tileAt(tx, math.min(run.front,
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
                  -- A profile may distinguish outline/fill rock art from
                  -- exposed material. Only remap the selected upright source:
                  -- objects, stairs, walkable floors and heights are unchanged.
                  if s.surfaceTiles then src = s.surfaceTiles[src] or src end
                end
                sideQuad(d, x0, z0, y0, y1, src,
                         (band * 8 + 8) - y1, (band * 8 + 8) - y0,
                         sideShades(hl, hr, y0, y1, y0 <= nh, shade))
              end
            end
          end
        end
      end
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

  local objectQuads = S.objectQuads or {}
  local consumeQuads = sink.kind == "ffi" or sink.kind == "packed"
  for qi = 1, #objectQuads do
    local q = objectQuads[qi]
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
      push(q, quadUV(q), groundShades(q, q.shade))
    end
    -- The FFI sink has copied every scalar already.  Release this expanded
    -- face immediately so the incremental collector can reclaim it during
    -- later cooperative yields instead of retaining the whole route until
    -- the analysis cache is evicted.
    if consumeQuads and not stampPlan then objectQuads[qi] = nil end
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

  -- round-tree stamps: the shared hull template translated per cell,
  -- through reusable scratch corners so expansion allocates nothing.
  -- A hull spans at most its own footprint -- one 16px cell unless the
  -- stamp carries a wider radius (the 2x2-cell canopy groups) -- so one
  -- rect test usually answers for the whole stamp: strictly interior
  -- stamps keep every quad, ring stamps buried under a neighbour body
  -- (or, body-only, ring stamps full stop) skip without touching their
  -- quads. Only stamps crossing a boundary walk quad by quad.
  local sc = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
  local roundStamps = S.roundStamps or {}
  for si = 1, #roundStamps do
    local st = roundStamps[si]
    local mx, my, mz = st.mx, st.my or 0, st.mz
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
            s2[2] = c[2] + my
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
          group = { sink = newSink(kept), offsets = {}, quads = kept }
          variants[signature] = group
          stampPlan.groups[#stampPlan.groups + 1] = group
          for qi, q in ipairs(st.quads) do
            if keepAll or flags[qi] == "\1" then
              Budget.tick()
              group.sink.push({ q[1], q[2], q[3], q[4] }, quadUV(q),
                              groundShades(q, q.shade))
            end
          end
        end
        group.offsets[#group.offsets + 1] = { mx, my, mz }
      end
    elseif not skipAll then
      for _, q in ipairs(st.quads) do
        Budget.tick()
        for i = 1, 4 do
          local c, s2 = q[i], sc[i]
          s2[1] = c[1] + mx
          s2[2] = c[2] + my
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
          push(sc, quadUV(q), groundShades(sc, q.shade, my))
        end
      end
    end
    if consumeQuads and not stampPlan then roundStamps[si] = nil end
  end
end

local INSTANCE_FORMAT = {
  { "InstanceOffset", "float", 3 },
}

local function releaseObject(object)
  if object and type(object.release) == "function" then
    pcall(object.release, object)
  end
end

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
    releaseObject(self.base)
    for _, group in ipairs(self.instances or {}) do
      releaseObject(group.owner)
      releaseObject(group.source)
    end
    self.base, self.instances = nil, {}
  end
  return bundle
end

local function instancingUnsupported(message)
  error({ voxelInstancingUnsupported = true, message = tostring(message) }, 0)
end

local function instanceSource(offsets)
  local count = #offsets
  if count == 0 then instancingUnsupported("empty placement stream") end
  Budget.check()
  local ok, source = pcall(love.graphics.newMesh, INSTANCE_FORMAT, count,
                           "points", "static")
  if not ok or not source then instancingUnsupported(source) end
  local first = 1
  while first <= count do
    local n = math.min(4096, count - first + 1)
    local upload = {}
    for i = first, first + n - 1 do
      upload[#upload + 1] = offsets[i]
    end
    local setOK, setErr = pcall(source.setVertices, source, upload, first, n)
    if not setOK then
      releaseObject(source)
      instancingUnsupported(setErr)
    end
    first = first + n
    Budget.check()
  end
  return source, count
end

local function finishStampPlan(base, plan)
  local groups = {}
  local function cleanup()
    for _, group in ipairs(groups) do
      releaseObject(group.owner)
      releaseObject(group.source)
    end
  end
  for _, planned in ipairs(plan.groups) do
    local okOwner, owner = pcall(planned.sink.finish)
    if not okOwner or not owner then
      cleanup()
      instancingUnsupported(owner or "empty tree template")
    end
    local okSource, source, count = pcall(instanceSource, planned.offsets)
    if not okSource then
      releaseObject(owner)
      cleanup()
      error(source, 0)
    end
    local meshes = owner.__voxelMeshParts and owner.parts or { owner }
    for _, mesh in ipairs(meshes) do
      if type(mesh.attachAttribute) ~= "function" then
        releaseObject(owner); releaseObject(source); cleanup()
        instancingUnsupported("per-instance attributes unavailable")
      end
      local attached, attachErr = pcall(mesh.attachAttribute, mesh,
                                        "InstanceOffset", source,
                                        "perinstance")
      if not attached then
        releaseObject(owner); releaseObject(source); cleanup()
        instancingUnsupported(attachErr)
      end
    end
    groups[#groups + 1] = {
      owner = owner,
      meshes = meshes,
      source = source,
      count = count,
    }
    Budget.check()
  end
  return meshBundle(base, groups)
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

local function quadsMesh(quads)
  if #quads == 0 then return nil end
  local count = #quads
  local phase = type(Budget.phase) == "function" and Budget.phase() or "aux"
  Budget.phase(phase .. ":allocate")
  local sink = newSink(count)
  Budget.phase(phase .. ":pack")
  for i = 1, count do
    local q = quads[i]
    -- Point-sampled decoration quads carry only scalar u/v fields.  Passing
    -- those directly avoids allocating two short-lived Lua tables per quad
    -- (70k+ objects on a dense route), which previously triggered visible
    -- full-GC pauses while the destination map was appearing.
    sink.push(q, q.uv, q.shade)
    if sink.kind == "ffi" or sink.kind == "packed" then quads[i] = nil end
    Budget.tick()
  end
  Budget.phase(phase .. ":upload")
  return sink.finish()
end

-- The tall-grass rows as their own mesh: VoxelScene draws it AFTER the
-- characters so the southern row of a grass cell still overdraws a
-- walker's feet (characters stamp over terrain, Gen 1 style, so ordinary
-- terrain could never do this).
local function buildGrassMesh(map)
  local quads = Structures.forMap(map, true).grassQuads
  Budget.phase("aux-grass:" .. tostring(#quads))
  return quadsMesh(quads)
end

-- The flower billboards as their own mesh, for the same reason as the
-- grass one: it draws AFTER the characters WITH the same camera-ward
-- pull, so a flower south of a walker occludes their feet and one north
-- of them hides behind them. Baked into the terrain mesh they lost that
-- depth fight against the pulled character card whenever the player
-- stood among flowers. Unlike grass this mesh still CASTS shadows (the
-- sun pass draws it): a handful of flowers per meadow, not thousands of
-- tufts.
local function buildFlowerMesh(map)
  local quads = Structures.forMap(map, true).flowerQuads
  Budget.phase("aux-flowers:" .. tostring(#quads))
  return quadsMesh(quads)
end

-- One movable upper shaft; the fixed 32px collar is already in terrain.
-- An absent/failed upper upload leaves that valid low fallback visible.
local function buildTowerPillarMesh(map)
  local pillar = Structures.forMap(map, true).towerPillar
  if not pillar then return nil end
  Budget.phase("aux-tower-pillar")
  return quadsMesh(pillar.quads)
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
local function buildFigureMeshes(map, job)
  local out = {}
  if job then job.partialMaskFigures = out end
  for _, f in ipairs(Structures.forMap(map, true).figures or {}) do
    local mesh = quadsMesh(f.quads)
    if mesh then
      local w = 0
      for _, q in ipairs(f.quads) do
        for c = 1, 4 do
          local x = q[c] and q[c][1]
          if x and x > w then w = x end
        end
      end
      out[#out + 1] = { mesh = mesh, wx = f.wx, wz = f.wz, y = f.y, w = w }
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
                          "grass", "flowers", "towerPillar" }) do
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
local perf = { maxResumeMs = 0, maxPhase = nil, maxMapId = nil,
  maxSlot = nil, lastResumeMs = 0, lastPhase = nil }

local clock = (love and love.timer and love.timer.getTime) or os.clock

local function jobKey(id, slot)
  return id .. ":" .. slot
end

-- OPEN WORLD admits neighbors incrementally. FULL is not a map-id-only
-- resource: its synthetic border must follow the current neighbor masks.
-- Own a canonical snapshot, including for jobs suspended across frames.
local function maskSnapshot(masks)
  local rows, seen = {}, {}
  for _, r in ipairs(masks or {}) do
    local key = table.concat({r[1], r[2], r[3], r[4]}, ",")
    if not seen[key] then
      rows[#rows + 1] = {key=key, rect={r[1], r[2], r[3], r[4]}}
      seen[key] = true
    end
  end
  table.sort(rows, function(a,b) return a.key < b.key end)
  local keys, copy = {}, {}
  for i, row in ipairs(rows) do keys[i], copy[i] = row.key, row.rect end
  return table.concat(keys, ";"), copy
end

local function releasePartialMaskJob(job)
  for _, mesh in pairs(job.partialMaskMeshes or {}) do
    if mesh and mesh.release then pcall(mesh.release, mesh) end
  end
  job.partialMaskMeshes = nil
  releaseFigures(job.partialMaskFigures)
  job.partialMaskFigures = nil
end

local function prepareFullMasks(map, masks)
  local signature, snapshot = maskSnapshot(masks)
  local c = entry(map.id)
  if c.fullMaskKey ~= signature then
    local key = jobKey(map.id, "full")
    local oldJob = jobIndex[key]
    if oldJob then
      releasePartialMaskJob(oldJob)
      jobIndex[key] = nil
      for i=#jobs,1,-1 do if jobs[i]==oldJob then table.remove(jobs,i) end end
      -- Only the cancelled FULL construction data; a live BODY keeps its own.
      Structures.releaseAux(map, false)
    end
    -- Wrong seam geometry must not remain visible as a stale refresh. Keep
    -- the playable BODY and all native grass/flower/figure caches intact.
    swapSlot(c, "full", nil)
    swapSlot(c, "fullWater", nil)
    if c.stale then c.stale.full = nil end
    c.fullMaskKey = signature
    lastErrors[map.id] = nil
  end
  return snapshot
end

local function finishJob(job, ok, err)
  jobIndex[jobKey(job.id, job.slot)] = nil
  for i, j in ipairs(jobs) do
    if j == job then
      table.remove(jobs, i)
      break
    end
  end
  if not ok then
    releasePartialMaskJob(job)
    -- name the reason: in a real session a lost build is a black map
    lastErrors[job.id] = tostring(err)
    print("[warn] voxel mesh build failed for " .. tostring(job.id)
          .. ": " .. tostring(err))
    if (gen[job.id] or 0) == job.gen then
      entry(job.id)[job.slot] = false
    end
  else
    lastErrors[job.id] = nil
  end
end

-- A build only lands if the map's generation still matches the one the
-- job was queued under -- invalidate/evict bump it to cancel in-flight
-- work whose inputs went stale.
local function runJob(job)
  local map = job.map
  local c = entry(job.id)
  if not job.cacheChecked then
    Budget.phase("cache-load")
    job.cacheChecked = true
    local okCache, mesh, water = pcall(PersistentCache.load,
      map, job.slot, job.masks)
    if okCache and mesh then
      swapSlot(c, job.slot, mesh)
      swapSlot(c, waterSlot(job.slot), water or false)
    end
  end
  -- Produce the playable terrain first. Grass, flowers and embedded figures
  -- may then complete behind an already usable Johto map.
  if c[job.slot] == nil or (c.stale and c.stale[job.slot]) then
    local useInstances = type(Voxel3D.canInstance) == "function"
      and Voxel3D.canInstance() == true
    local plan = useInstances and { groups = {}, byTemplate = {} } or nil
    local sink, waterSink = newSink(), newSink()
    runGeometry(map, job.slot == "body", job.masks, sink, waterSink, plan)

    -- On capable GPUs the hundreds of repeated Johto tree hulls are one
    -- template plus compact translations.  If a driver advertises
    -- instancing but rejects the per-instance attribute, close every partial
    -- allocation and retry once through the exact historical expansion.
    local mesh, water
    if plan then
      mesh, water = sink.finish(), waterSink.finish()
      local okBundle, bundled = pcall(finishStampPlan, mesh, plan)
      if okBundle then
        mesh = bundled
      elseif type(bundled) == "table"
          and bundled.voxelInstancingUnsupported then
        releaseObject(mesh)
        releaseObject(water)
        mesh, water = nil, nil
        if type(Voxel3D.rejectInstancing) == "function" then
          Voxel3D.rejectInstancing()
        end
        plan = nil
        sink, waterSink = newSink(), newSink()
        runGeometry(map, job.slot == "body", job.masks, sink, waterSink)
      else
        releaseObject(mesh)
        releaseObject(water)
        error(bundled, 0)
      end
    end
    Structures.releaseGeometry(map, job.slot == "body")
    -- Serialising a route-sized FFI vertex buffer can copy tens of megabytes
    -- in one main-thread call.  Older builds performed that copy even when
    -- the persistent cache option was OFF; Cache.enqueue() then rejected the
    -- already-created string.  Apart from wasting memory this produced the
    -- visible 100-500 ms hitch at the end of a cold BODY build.  Ask the cache
    -- owner before materialising either stream, so disabled/unavailable cache
    -- paths remain allocation-free.
    local cacheAvailable = type(PersistentCache.available) == "function"
      and PersistentCache.available() == true
    -- The current persistent format is an expanded vertex stream. Never
    -- serialize only the non-instanced base of a bundle (which would reload
    -- without its forests). Expanded/fallback builds retain cache parity.
    if not plan and cacheAvailable and sink.rawBytes and sink.vertexCount then
      local okEnqueue, enqueued = pcall(PersistentCache.enqueue,
        map, job.slot, job.masks,
        sink.rawBytes(), sink.vertexCount(),
        waterSink.rawBytes and waterSink.rawBytes() or "",
        waterSink.vertexCount and waterSink.vertexCount() or 0)
      if not okEnqueue and type(PersistentCache.noteFailure) == "function" then
        PersistentCache.noteFailure(enqueued)
      end
    elseif not plan and cacheAvailable and job.slot == "body" and job.urgent
        and sink.cacheSource and waterSink.cacheSource
        and type(PersistentCache.enqueueTable) == "function" then
      local terrainVerts, terrainIndices = sink.cacheSource()
      local waterVerts, waterIndices = waterSink.cacheSource()
      local okEnqueue, enqueued = pcall(PersistentCache.enqueueTable,
        map, job.slot, job.masks, terrainVerts, terrainIndices,
        waterVerts, waterIndices)
      if not okEnqueue and type(PersistentCache.noteFailure) == "function" then
        PersistentCache.noteFailure(enqueued)
      end
    end
    if not plan then
      Budget.phase("mesh-upload:call:" .. tostring(
        sink.vertexCount and sink.vertexCount() or "table"))
      mesh, water = sink.finish(), waterSink.finish()
    end
    -- The native staging buffers can be many megabytes.  Do not keep them
    -- alive while the auxiliary grass/flower meshes are packed below.
    sink, waterSink = nil, nil
    job.partialMaskMeshes = {mesh, water}
    Budget.check()
    if (gen[job.id] or 0) ~= job.gen then
      if mesh and mesh.release then pcall(mesh.release, mesh) end
      if water and water.release then pcall(water.release, water) end
      job.partialMaskMeshes = nil
      return
    end
    swapSlot(c, job.slot, mesh or false)
    swapSlot(c, waterSlot(job.slot), water or false)
    job.partialMaskMeshes = nil
    if c.stale then c.stale[job.slot] = nil end
  end
  if c.grass == nil or c.flowers == nil or c.figures == nil or c.towerPillar == nil
     or (c.stale and c.stale.aux) then
    Budget.phase("aux-grass")
    local okG, grass = pcall(buildGrassMesh, map)
    job.partialMaskMeshes = {okG and grass or nil}
    Budget.phase("aux-flowers")
    local okF, flowers = pcall(buildFlowerMesh, map)
    job.partialMaskMeshes[2] = okF and flowers or nil
    Budget.phase("aux-figures")
    local okX, figures = pcall(buildFigureMeshes, map, job)
    if not okX then
      releaseFigures(job.partialMaskFigures)
      job.partialMaskFigures = nil
    end
    local okT, tower = pcall(buildTowerPillarMesh, map)
    job.partialMaskMeshes[3] = okT and tower or nil
    if (gen[job.id] or 0) ~= job.gen then
      if okG and grass and grass.release then pcall(grass.release, grass) end
      if okF and flowers and flowers.release then
        pcall(flowers.release, flowers)
      end
      if okX then releaseFigures(figures) end
      if okT and tower and tower.release then pcall(tower.release, tower) end
      job.partialMaskMeshes, job.partialMaskFigures = nil, nil
      return
    end
    swapSlot(c, "grass", (okG and grass) or false)
    swapSlot(c, "flowers", (okF and flowers) or false)
    swapSlot(c, "towerPillar", (okT and tower) or false)
    job.partialMaskMeshes = nil
    releaseFigures(c.figures)
    c.figures = (okX and figures) or false
    job.partialMaskFigures = nil
    if c.stale then c.stale.aux = nil end
  end
  -- BODY and FULL may be suspended independently.  Release only this job's
  -- construction tables; releasing both here can invalidate the sibling
  -- coroutine while it is still inside runGeometry().
  Structures.releaseAux(map, job.slot == "body")
  if c.stale then
    c.stale[job.slot] = nil
    if not (c.stale.full or c.stale.body or c.stale.aux) then
      c.stale = nil
    end
  end
end

-- Queue a build unless the slot is already cached or queued. Returns the
-- cached mesh when there is one (false-cached misses return nil).
-- `urgent` marks visible/current-map work: pump() gives it a bigger slice and
-- runs it before neighbour jobs. `priority` ranks jobs inside that class; the
-- Gen-2 entry gate uses a higher rank for the newly entered map's BODY so a
-- leftover full-apron job from the previous map cannot starve it. A slot refresh() marked
-- stale queues its rebuild AND keeps handing back the old mesh, so a
-- one-block edit never drops the scene to the flat 2D path while the
-- replacement cooks.
function ChunkMesher.request(map, bodyOnly, masks, urgent, priority)
  local slot = bodyOnly and "body" or "full"
  if not bodyOnly then masks = prepareFullMasks(map, masks) end
  local rank = math.max(0, tonumber(priority) or 0)
  local c = cache[map.id]
  local stale = c and c.stale and (c.stale[slot] or c.stale.aux)
  if c and c[slot] ~= nil and not stale then return c[slot] or nil end
  local key = jobKey(map.id, slot)
  local job = jobIndex[key]
  if not job then
    job = { id = map.id, map = map, slot = slot, masks = masks,
            urgent = urgent or false, priority = rank,
            gen = gen[map.id] or 0 }
    jobIndex[key] = job
    jobs[#jobs + 1] = job
  elseif urgent then
    job.urgent = true
  end
  if rank > (job.priority or 0) then job.priority = rank end
  return (c and c[slot]) or nil
end

function ChunkMesher.pending()
  return #jobs
end

-- Most recent terrain build failure for a map, if any.  A nil value means
-- there is no known failure; callers can then distinguish true async pending
-- from a false-cached build that will never become drawable.
function ChunkMesher.lastError(mapId)
  return mapId and lastErrors[mapId] or nil
end

-- Advance queued builds inside a per-frame time budget. Urgent jobs (the
-- current map) come first and get the larger slice -- the first voxel
-- frame after a toggle is worth more milliseconds than a neighbour
-- popping in one frame later. `covered` says the world pass is hidden
-- this frame (a warp's fade, a menu): nothing visible can hitch, so the
-- slice opens up and a door fade swallows most of a destination build.
local function buildSlices()
  local profile = "handheld"
  if DeviceProfile and type(DeviceProfile.effective) == "function" then
    local ok, value = pcall(DeviceProfile.effective)
    if ok and type(value) == "string" then profile = value end
  end
  return PerformancePolicy.slices(profile)
end

ChunkMesher._buildSlices = buildSlices

function ChunkMesher.pump(covered)
  PersistentCache.pump(covered == true)
  if #jobs == 0 then return end
  local pick = jobs[1]
  for _, j in ipairs(jobs) do
    local pickUrgent, jobUrgent = pick.urgent == true, j.urgent == true
    if (jobUrgent and not pickUrgent)
        or (jobUrgent == pickUrgent
          and (j.priority or 0) > (pick.priority or 0)) then
      pick = j
    end
  end
  local urgentSlice, idleSlice, coveredSlice = buildSlices()
  local slice = covered and coveredSlice
                or (pick.urgent and urgentSlice or idleSlice)
  local deadline = clock() + slice
  while pick do
    if not pick.co then
      pick.co = coroutine.create(runJob)
    end
    Budget.begin(pick.co, deadline - clock())
    local memoryBefore = collectgarbage("count")
    local resumeStarted = clock()
    local ok, err = coroutine.resume(pick.co, pick)
    local resumeMs = (clock() - resumeStarted) * 1000
    local memoryAfter = collectgarbage("count")
    local phase = type(Budget.phase) == "function" and Budget.phase() or nil
    perf.lastResumeMs, perf.lastPhase = resumeMs, phase
    if resumeMs > perf.maxResumeMs then
      perf.maxResumeMs, perf.maxPhase = resumeMs, phase
      perf.maxMapId, perf.maxSlot = pick.id, pick.slot
    end
    if resumeMs >= 75 then
      print(("[warn] Gen-2 voxel build slice overrun %.2f ms at %s/%s (%s; heap %.1f -> %.1f KiB)")
        :format(resumeMs, tostring(pick.id), tostring(pick.slot),
          tostring(phase or err or "unknown"), memoryBefore, memoryAfter))
    end
    Budget.finish()
    if not ok then
      finishJob(pick, false, err)
    elseif coroutine.status(pick.co) == "dead" then
      finishJob(pick, true)
    else
      return   -- slice spent mid-build; resume next frame
    end
    if clock() >= deadline or #jobs == 0 then return end
    pick = jobs[1]
    for _, j in ipairs(jobs) do
      local pickUrgent, jobUrgent = pick.urgent == true, j.urgent == true
      if (jobUrgent and not pickUrgent)
          or (jobUrgent == pickUrgent
            and (j.priority or 0) > (pick.priority or 0)) then
        pick = j
      end
    end
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
  if not bodyOnly then masks = prepareFullMasks(map, masks) end
  local c = entry(map.id)
  if c.grass == nil or c.flowers == nil or c.figures == nil or c.towerPillar == nil
     or (c.stale and c.stale.aux) then
    local okG, grass = pcall(buildGrassMesh, map)
    local okF, flowers = pcall(buildFlowerMesh, map)
    local okX, figures = pcall(buildFigureMeshes, map)
    local okT, tower = pcall(buildTowerPillarMesh, map)
    swapSlot(c, "grass", (okG and grass) or false)
    swapSlot(c, "flowers", (okF and flowers) or false)
    swapSlot(c, "towerPillar", (okT and tower) or false)
    releaseFigures(c.figures)
    c.figures = (okX and figures) or false
    if c.stale then c.stale.aux = nil end
  end
  if c[slot] == nil or (c.stale and c.stale[slot]) then
    local ok, mesh, water = pcall(ChunkMesher.build, map, bodyOnly, masks,
                                  true)
    if not ok then
      lastErrors[map.id] = tostring(mesh)
      print("[warn] voxel mesh build failed for " .. tostring(map.id)
            .. ": " .. tostring(mesh))
    else
      lastErrors[map.id] = nil
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
    if job then finishJob(job, ok, (not ok) and mesh or nil) end
  end
  Structures.releaseGeometry(map, bodyOnly == true)
  Structures.releaseAux(map, bodyOnly == true)
  return c[slot] or nil
end

-- The cached mesh, or nil -- never builds. The async path's read side.
function ChunkMesher.peek(map, bodyOnly)
  local c = cache[map.id]
  local mesh = c and c[bodyOnly and "body" or "full"]
  return mesh or nil
end

-- A first/current frame is one visual bundle, not just a terrain pointer.
-- False is a completed empty auxiliary slot; nil means the grass/flower/
-- figure pass is still being analysed or uploaded and must not be exposed.
local function auxReady(c)
  return c ~= nil and c.grass ~= nil and c.flowers ~= nil
    and c.figures ~= nil and c.towerPillar ~= nil
end

function ChunkMesher.auxReady(map)
  return auxReady(cache[map.id])
end

function ChunkMesher.ready(map, bodyOnly)
  local c = cache[map.id]
  local slot = bodyOnly and "body" or "full"
  return c ~= nil and c[slot] ~= nil and c[slot] ~= false and auxReady(c)
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

-- Read-only: never rebuild from draw, reflection, or shadow callbacks.
function ChunkMesher.towerPillar(map)
  local c = map and cache[map.id]
  return c and c.towerPillar or nil
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
  Structures.invalidate(mapId)
  gen[mapId] = (gen[mapId] or 0) + 1
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if job.id == mapId then
      releasePartialMaskJob(job)
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

function ChunkMesher.setLive(live, forgetPrevious)
  -- Normal streaming keeps one previous neighbourhood warm for cheap
  -- house/door round trips. OPEN WORLD -> OFF is different: the user is
  -- explicitly asking to shed the expensive far-world residency now, so the
  -- caller may discard that one-generation grace set before eviction.
  if forgetPrevious then prevLive = {} end
  for id, c in pairs(cache) do
    if not live[id] and not prevLive[id] then
      releaseEntry(c)
      cache[id] = nil
      gen[id] = (gen[id] or 0) + 1
      Structures.invalidate(id)
    end
  end
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if not live[job.id] and not prevLive[job.id] then
      releasePartialMaskJob(job)
      jobIndex[jobKey(job.id, job.slot)] = nil
      table.remove(jobs, i)
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
  if mapId then
    lastErrors[mapId] = nil
    local c = cache[mapId]
    if c then releaseEntry(c) end
    cache[mapId] = nil
    gen[mapId] = (gen[mapId] or 0) + 1
  else
    for _, c in pairs(cache) do releaseEntry(c) end
    cache = {}
    lastErrors = {}
    for id in pairs(gen) do gen[id] = gen[id] + 1 end
  end
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if mapId == nil or job.id == mapId then
      releasePartialMaskJob(job)
      jobIndex[jobKey(job.id, job.slot)] = nil
      table.remove(jobs, i)
    end
  end
end

-- v0.2.66 recovery: persistent disk cache is intentionally removed from the
-- live mesher path. Keep these compatibility probes so newer status/debug code
-- can ask about it without reintroducing any cache I/O or cache-era geometry.
function ChunkMesher.diskCacheStatus()
  local status = PersistentCache.status()
  status.maxResumeMs = perf.maxResumeMs
  status.maxResumePhase = perf.maxPhase
  status.maxResumeMapId = perf.maxMapId
  status.maxResumeSlot = perf.maxSlot
  status.lastResumeMs = perf.lastResumeMs
  status.lastResumePhase = perf.lastPhase
  return status
end

function ChunkMesher.clearDiskCache()
  return false
end

Assets.register(function() ChunkMesher.invalidate() end)

return ChunkMesher
