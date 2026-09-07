-- Overworld battles: where the fight is staged.
--
-- A battle in this mod happens ON THE MAP, so it needs a patch of ground
-- clear enough to stand two Pokemon on and point a camera down. This module
-- finds it: the nearest patch of open cells, in the shape below.
--
--     x x x
--     x O x        O   the enemy's mon
--     x x x
--     x x x
--     x P x        P   the player's mon
--     x x x
--
-- Every `x` is an OPEN cell -- one with no obstruction, i.e. one the player
-- could walk onto. The two mons stand three cells apart down the middle
-- column, with a one-cell apron all round so the camera looks across floor
-- rather than into a wall.
--
-- When no map has room for that -- a corridor, a cave, a shop floor -- the
-- search relaxes to the narrow shape, which is the same three-cell gap with
-- the apron given up:
--
--     O
--     x
--     x
--     P
--
-- and if even that will not fit, the caller gets nil and the battle draws
-- the way it always did. A mod that cannot find a stage does not invent
-- one.
--
-- Nothing here MOVES anybody: the arena is where the CAMERA goes and where
-- the two mons are staged for the shot. The player's own cell, the party,
-- every script and flag are exactly where the battle left them, which is
-- what keeps a trainer's post-battle dialogue talking to someone still
-- standing in front of them.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local BattleArena = {}

-- ------- the authored spot
--
-- Every map gets ONE place its battles happen, chosen once and written down
-- in data/battle_arenas.lua, rather than whatever clearing happens to be
-- nearest to wherever the fight started. Two reasons.
--
-- A fight should look the same every time it happens somewhere. Picking the
-- nearest patch means Route 1 has a dozen different battle scenes depending
-- on which step of the grass you were on, some of them behind a tree.
--
-- And "open ground" is not the same question as "you can SEE the two of
-- them". The camera is low and a long way back, so a hedge, a ledge lip or a
-- building corner anywhere along that line hides a mon completely while the
-- cells it stands on are perfectly walkable. That is what `clearance` below
-- measures, and it is what the authored list is chosen against.
--
-- A map with no entry falls back to the search, so a mod that adds maps, or
-- an entry that goes stale, degrades to the old behaviour rather than to no
-- battle.
-- An entry may also name ANOTHER MAP to stage on:
--
--   ["MT_MOON_B2F"] = { map = "MT_MOON_1F", x = 12, y = 8, shape = "wide" }
--
-- because some maps simply have nowhere to put a fight. A cave's lower floor
-- can be nothing but two-cell-wide corridors between rock walls; a gym is a
-- room full of furniture. Rather than stage a battle there badly -- both
-- Pokemon behind a boulder -- the fight is shot on a floor of the SAME cave,
-- or a floor of the same building, that does have the room for it. It is the
-- same place, and no worse a fiction than a battle happening on ground the
-- player is not standing on, which is what every one of these already is.
local authored = nil
local overrides = {}

local function authoredFor(mapId)
  -- `~= nil`, not truthiness: `false` is a meaningful entry here (an
  -- authored refusal), so it has to reach the caller rather than read as
  -- "nothing set" and fall through to the data file
  local forced = overrides[mapId]
  if forced ~= nil then return forced end
  if authored == nil then
    local ok, list = pcall(V.data, "battle_arenas")
    authored = (ok and type(list) == "table") and list or false
  end
  if not authored then return nil end
  return authored[mapId]
end

BattleArena.authoredFor = authoredFor

-- The bundled catalogue predates the Gold/Crystal map runtime and contains
-- Red/Blue/Yellow coordinates.  Several names exist in both generations
-- (ROUTE_1, PEWTER_GYM, ...), but the geometry behind those names does not.
-- Treating a matching string as a matching map is what put Gen-2 combatants
-- into hedges and walls.  Gold therefore accepts only entries explicitly
-- marked for Gen 2; runtime authoring overrides remain intentional and are
-- always eligible.
local function goldAuthoredEntry(entry)
  if type(entry) ~= "table" then return false end
  local generation = tonumber(entry.generation or entry.gen)
  local game = tostring(entry.game or entry.edition or ""):lower()
  return entry.gen2 == true or generation == 2
      or game == "gen2" or game == "gsc" or game == "gold"
      or game == "silver" or game == "crystal"
end

BattleArena.goldAuthoredEntry = goldAuthoredEntry

-- Force one map's entry at runtime, ahead of the data file. The authoring
-- tool's handle: it is how a spot chosen by eye is staged and photographed
-- before it is written down, and the only way to check a cross-floor entry
-- without editing the shipped list first. Pass nil to drop it again.
function BattleArena.setOverride(mapId, entry)
  overrides[mapId] = entry
end

-- Cell size in world pixels, the unit every coordinate here is in when it
-- crosses into the renderer (Map's walk grid is 16px cells).
local CELL = 16

-- The two shapes, in preference order. `w`/`h` are in cells; `enemy` and
-- `player` are the offsets, from the shape's north-west corner, of the two
-- cells a mon stands on.
BattleArena.SHAPES = {
  { id = "wide",   w = 3, h = 7, enemy = { 1, 1 }, player = { 1, 4 } },
  { id = "narrow", w = 1, h = 5, enemy = { 0, 0 }, player = { 0, 3 } },
}

-- ------- which way round the fight stands
--
-- Both shapes above are drawn north-south, with the foe at the top and the
-- player below it, and the camera is solved for that: it sits off the
-- player's shoulder, low and back down the arena's own axis. `turn` swings
-- the WHOLE staging a quarter at a time -- the footprint, the two cells, and
-- the camera with them -- so the composition on screen is identical and only
-- the ground under it is different.
--
-- It buys two things.
--
-- A footprint that FITS. The wide shape is three cells by six; an east-west
-- corridor two cells deep has no room for it standing up and all the room in
-- the world for it lying down. Half the maps in Kanto run the other way from
-- the one shape this mode was drawn in.
--
-- And a BACKDROP. A quarter turn moves the camera to a different side of the
-- same patch of ground, so the wall behind the pair becomes the window
-- behind them, or the cliff becomes the valley. Nothing about the shot's
-- geometry changes -- the mons land on the same two screen anchors at the
-- same size -- so this is purely a choice about what is behind them, made
-- per map by somebody looking at it.
--
-- Written in DEGREES in data/battle_arenas.lua (`turn = 90`) because that is
-- what it is; handled as quarter turns everywhere below.
local function quarters(turn)
  local q = math.floor(((tonumber(turn) or 0) / 90) + 0.5)
  return ((q % 4) + 4) % 4
end

BattleArena.quarters = quarters

-- The footprint a shape covers once turned: a quarter or three of a turn
-- swaps how far it reaches in each direction, which is the whole reason a
-- corridor takes one and not the other.
function BattleArena.extent(shape, turn)
  if quarters(turn) % 2 == 1 then return shape.h, shape.w end
  return shape.w, shape.h
end

-- Where a cell offset inside the shape ends up under the same turn, measured
-- from the turned footprint's own north-west corner -- so the corner an entry
-- names stays the corner, whichever way the fight faces from it.
local function spin(shape, turn, ox, oy)
  local q = quarters(turn)
  if q == 1 then return shape.h - 1 - oy, ox end
  if q == 2 then return shape.w - 1 - ox, shape.h - 1 - oy end
  if q == 3 then return oy, shape.w - 1 - ox end
  return ox, oy
end

-- Whether a cell is open ground for the purpose above.
--
-- "Open" is the walk test the player themselves answer to, so an arena can
-- never be laid over a wall, a counter, a tree or a ledge face. Water counts
-- only for a surfer, which is the one case where the player is standing on
-- it too -- a sea battle staged on the beach half a route away would read as
-- a teleport.
--
-- Warp cells are excluded on top of that. They are walkable by definition
-- (they are the doormat), and a fight framed in a doorway both looks wrong
-- and puts the camera inside the building's geometry.
--
-- And TALL GRASS is excluded, which is the surprising one, because grass is
-- where wild battles come from and standing in it is the obvious place to
-- have one. It does not survive contact with the camera. Grass is real
-- geometry in this mode -- a row of tufts about knee height on a Pokemon --
-- drawn with the same camera-ward bias that lets it overdraw a walking
-- character's feet in the free-roam world. From a camera nearly level with
-- the floor that bias stops being feet-deep: the tufts on and around a mon's
-- own tile stand between it and the lens and eat most of the sprite.
--
-- So the arena is laid on bare ground -- the whole footprint, not just the
-- two cells a mon stands on, because the apron south of the near mon is
-- exactly the row whose grass would cover it. Grass FURTHER back toward the
-- camera is fine and stays: it is far enough forward to project low and wide
-- across the bottom of the frame, where it reads as a field rather than as
-- something in the way.
local function openCell(map, cx, cy, surfing)
  if not map:inBounds(cx, cy) then return false end
  if map:warpAtCell(cx, cy) then return false end
  if map:isWarpTileCell(cx, cy) then return false end
  if map.isGrassCell and map:isGrassCell(cx, cy) then return false end
  if map:isWalkableCell(cx, cy) then return true end
  return (surfing and map:isWaterCell(cx, cy)) or false
end

BattleArena.openCell = openCell

-- The map's open cells as one flat boolean grid, so the rectangle test
-- below is a lookup rather than a tileset walk per cell. Built once per
-- search; a battle asks for one.
local function openGrid(map, surfing)
  local w, h = map.widthCells, map.heightCells
  local grid = {}
  for cy = 0, h - 1 do
    local row = cy * w
    for cx = 0, w - 1 do
      grid[row + cx] = openCell(map, cx, cy, surfing)
    end
  end
  return grid, w, h
end

local function fits(grid, gw, x, y, w, h)
  for cy = y, y + h - 1 do
    local row = cy * gw
    for cx = x, x + w - 1 do
      if not grid[row + cx] then return false end
    end
  end
  return true
end

-- Build the record the renderer reads: the two mons' cells and, in world
-- pixels, the centre of each and of the pair.
local function place(shape, x, y, turn)
  local eox, eoy = spin(shape, turn, shape.enemy[1], shape.enemy[2])
  local pox, poy = spin(shape, turn, shape.player[1], shape.player[2])
  local ex, ey = x + eox, y + eoy
  local px, py = x + pox, y + poy
  local w, h = BattleArena.extent(shape, turn)
  local arena = {
    shape = shape.id,
    -- carried in degrees, so everything downstream that reasons about the
    -- shot -- the camera's base yaw above all -- reads the same number the
    -- data file was written with
    turn = quarters(turn) * 90,
    x = x, y = y, w = w, h = h,
    enemyCell = { ex, ey },
    playerCell = { px, py },
    -- world-pixel centres of the two cells a mon stands on
    enemy = { ex * CELL + CELL / 2, ey * CELL + CELL / 2 },
    player = { px * CELL + CELL / 2, py * CELL + CELL / 2 },
  }
  arena.mid = { (arena.enemy[1] + arena.player[1]) / 2,
                (arena.enemy[2] + arena.player[2]) / 2 }
  return arena
end

-- ------- can the two of them actually be SEEN there
--
-- The camera sits low and far back on one side, so what hides a mon is not
-- what is on its own tile -- it is anything TALL between the camera and it.
-- A tree two cells to the south-east blocks the near mon completely while
-- every cell of the arena is open ground.
--
-- So the line from the eye to each mon is walked in short steps and the
-- terrain height under each step is compared with how high the line is
-- there. Three lines per mon -- to its feet, its middle and its head --
-- because a hedge that clears the head still cuts the body in half.
--
-- Grass and flowers are deliberately not obstacles: they stand at ankle
-- height, they are what a field looks like, and a mon standing in them
-- reads as standing in a field rather than as being hidden by one.
BattleArena.SAMPLE_STEP = 4      -- world pixels along the line
BattleArena.MON_H = 16           -- how tall a mon stands, in world pixels
BattleArena.CLEAR_EPS = 1.5      -- slack, so a flush kerb is not an obstacle
BattleArena.CAMERA_RADIUS = 3    -- small near-plane/body clearance in pixels
BattleArena.CAMERA_EDGE_MARGIN = 8 -- keep the lens away from rendered void
BattleArena.SOLID_H = 48         -- conservative tree/wall/building column
BattleArena.BORDER_H = 64        -- the map's sky/border is not a camera lane
BattleArena.DECOR_H = 12         -- grass standees can hide a small species
BattleArena.FLOOR_TOLERANCE = 2  -- one battle court, not two ledge levels
BattleArena.MIN_MARK_DISTANCE = 40 -- 2.5 cells; never shoulder-to-shoulder

local function heightAt(map, wx, wz)
  local cx, cy = math.floor(wx / CELL), math.floor(wz / CELL)
  if not map:inBounds(cx, cy) then
    -- off the map the border ring is drawn, and on most outdoor maps that
    -- ring is trees; treat it as solid so an arena is never framed through it
    return BattleArena.BORDER_H
  end
  local ok, h = pcall(V.require("VoxelScene").groundAt, map, cx, cy)
  h = (ok and tonumber(h)) or 0
  -- A tree/building collision cell can stand above otherwise level ground;
  -- groundAt alone therefore cannot describe whether a camera is inside it.
  -- Use Gold's own collision facts as a conservative presentation column.
  if type(map.isWalkableCell) == "function" then
    local okWalk, walkable = pcall(map.isWalkableCell, map, cx, cy)
    local water = false
    if type(map.isWaterCell) == "function" then
      local okWater, value = pcall(map.isWaterCell, map, cx, cy)
      water = okWater and value and true or false
    end
    if okWalk and not walkable and not water then
      h = h + BattleArena.SOLID_H
    end
  end
  if type(map.isGrassCell) == "function" then
    local okGrass, grass = pcall(map.isGrassCell, map, cx, cy)
    if okGrass and grass then h = h + BattleArena.DECOR_H end
  end
  return h
end

BattleArena.heightAt = heightAt

local function markDistanceOK(arena)
  if not (arena and arena.player and arena.enemy) then return false end
  local dx = (tonumber(arena.player[1]) or 0)
           - (tonumber(arena.enemy[1]) or 0)
  local dz = (tonumber(arena.player[2]) or 0)
           - (tonumber(arena.enemy[2]) or 0)
  return dx * dx + dz * dz
      >= BattleArena.MIN_MARK_DISTANCE * BattleArena.MIN_MARK_DISTANCE
end

BattleArena.markDistanceOK = markDistanceOK

-- Both actors and the complete footprint must share one real floor. This is
-- the generic map-change check that keeps a trainer/Pokemon pair out of a
-- recess or astride a ledge without changing a single native collision tile.
local function floorProfile(map, arena)
  if not (map and arena and markDistanceOK(arena)) then return nil end
  local low, high
  for cy = arena.y, arena.y + arena.h - 1 do
    for cx = arena.x, arena.x + arena.w - 1 do
      local h = heightAt(map, cx * CELL + CELL / 2,
                         cy * CELL + CELL / 2)
      low, high = low and math.min(low, h) or h,
                  high and math.max(high, h) or h
      if high - low > BattleArena.FLOOR_TOLERANCE then return nil end
    end
  end
  return (low + high) * 0.5
end

BattleArena.floorProfile = floorProfile

-- Whether the segment from `eye` to (tx, ty, tz) clears the terrain.
local function lineClear(map, eye, tx, ty, tz)
  local dx, dy, dz = tx - eye[1], ty - eye[2], tz - eye[3]
  local len = math.sqrt(dx * dx + dy * dy + dz * dz)
  if len <= 1 then return true end
  local steps = math.ceil(len / BattleArena.SAMPLE_STEP)
  -- skip the ends: the eye is in open air by construction and the last step
  -- is the mon's own tile, which it is standing on
  for i = 1, steps - 1 do
    local t = i / steps
    local wx = eye[1] + dx * t
    local wy = eye[2] + dy * t
    local wz = eye[3] + dz * t
    if heightAt(map, wx, wz) > wy + BattleArena.CLEAR_EPS then return false end
  end
  return true
end

-- Public, shared visibility vocabulary for arena selection and the smart
-- camera.  Three means feet/body/head are all visible; zero means terrain
-- blocks the whole actor.  This stays presentation-only and never changes
-- collision or the native battle state.
function BattleArena.visibility(map, eye, mark, groundY, height)
  if not (map and type(map.inBounds) == "function"
      and type(eye) == "table" and type(mark) == "table") then
    return 3
  end
  groundY = tonumber(groundY) or 0
  height = math.max(4, tonumber(height) or BattleArena.MON_H)
  local score = 0
  for _, hy in ipairs({ 1, height * 0.5, height }) do
    if lineClear(map, eye, mark[1], groundY + hy, mark[2]) then
      score = score + 1
    end
  end
  return score
end

-- A camera may look past foreground scenery, but its eye must not be outside
-- the rendered map or inside a solid column.  This is the missing safeguard
-- behind the sky/tree shots seen when a Kanto-authored seat happened to fit a
-- Johto floor rectangle.
function BattleArena.cameraClear(map, eye, edgeMargin)
  if not (map and type(map.inBounds) == "function"
      and type(eye) == "table") then return true end
  local wx, wy, wz = tonumber(eye[1]) or 0, tonumber(eye[2]) or 0,
                     tonumber(eye[3]) or 0
  local margin = tonumber(edgeMargin)
  if margin == nil then margin = BattleArena.CAMERA_EDGE_MARGIN end
  margin = math.max(0, margin)
  if wx < margin or wz < margin
      or wx >= map.widthCells * CELL - margin
      or wz >= map.heightCells * CELL - margin then return false end
  -- Protect a small camera body, not merely an infinitely thin eye point.
  for _, offset in ipairs({
    { 0, 0 }, { BattleArena.CAMERA_RADIUS, 0 },
    { -BattleArena.CAMERA_RADIUS, 0 }, { 0, BattleArena.CAMERA_RADIUS },
    { 0, -BattleArena.CAMERA_RADIUS },
  }) do
    local x, z = wx + offset[1], wz + offset[2]
    local cx, cy = math.floor(x / CELL), math.floor(z / CELL)
    if not map:inBounds(cx, cy) or heightAt(map, x, z) + 3 >= wy then
      return false
    end
  end
  return true
end

-- Validate a real camera move as well as its destination; a safe point behind
-- a house is not a valid orbit if reaching it crosses that house.
function BattleArena.cameraPathClear(map, fromEye, toEye)
  if not (type(fromEye) == "table" and type(toEye) == "table") then return true end
  if not (map and type(map.inBounds) == "function") then return true end
  local dx = (toEye[1] or 0) - (fromEye[1] or 0)
  local dy = (toEye[2] or 0) - (fromEye[2] or 0)
  local dz = (toEye[3] or 0) - (fromEye[3] or 0)
  local len = math.sqrt(dx * dx + dy * dy + dz * dz)
  local steps = math.max(1, math.ceil(len / BattleArena.SAMPLE_STEP))
  for i = 0, steps do
    local t = i / steps
    if not BattleArena.cameraClear(map, {
      (fromEye[1] or 0) + dx * t,
      (fromEye[2] or 0) + dy * t,
      (fromEye[3] or 0) + dz * t,
    }) then return false end
  end
  return true
end

local function cameraSeatClear(map, arena)
  local BattleCam = V.require("BattleCam")
  local groundY = tonumber(arena.anchorHeight) or floorProfile(map, arena)
  if groundY == nil then return false end
  local ok, rig = pcall(BattleCam.rig, arena, groundY, true)
  if not (ok and rig and rig.eye) then return true end
  return BattleArena.cameraClear(map, rig.eye)
end

-- Whether both mons would be in plain view from the battle camera.
function BattleArena.clearance(map, arena)
  local BattleCam = V.require("BattleCam")
  -- the CANONICAL shot: whether a fight fits somewhere is a fact about the
  -- ground, so it must not depend on the drift's phase or on where the
  -- player last swung the camera (see BattleCam.rig's third argument)
  local groundY = tonumber(arena.anchorHeight) or floorProfile(map, arena)
  if groundY == nil then return false end
  local ok, rig = pcall(BattleCam.rig, arena, groundY, true)
  if not (ok and rig and rig.eye) then return true end
  local eye = rig.eye
  if not BattleArena.cameraClear(map, eye) then return false end
  for _, mark in ipairs({ arena.player, arena.enemy }) do
    if BattleArena.visibility(map, eye, mark, groundY) < 3 then return false end
  end
  return true
end

-- The nearest arena to (fromX, fromY) -- the player's cell -- or nil when
-- the map has room for neither shape.
--
-- Distance is measured from the player to the arena's MIDPOINT, so "nearest"
-- means the fight is staged as close to where it was triggered as the ground
-- allows, rather than merely having a corner nearby.
--
-- Both shapes are searched over the whole map before the next one is tried:
-- a wide arena on the far side of a route still beats a narrow one
-- underfoot, because the wide one is the shot this mode is framed for.
function BattleArena.find(map, fromX, fromY, surfing)
  if not (map and map.widthCells) then return nil end

  -- the authored spot wins outright when the map has one and it still holds
  local forced = overrides[map.id]
  local pick = authoredFor(map.id)
  -- The shipped table is a Gen-1 catalogue.  A runtime override is made
  -- against the live map and remains valid; a future shipped Gen-2 entry must
  -- identify itself explicitly so name collisions can never recur silently.
  if V.game and V.game.world and forced == nil
      and not goldAuthoredEntry(pick) then
    pick = nil
  end
  -- `false` is an authored REFUSAL: a map looked at and found to have nowhere
  -- a fight can be seen, with no other floor to borrow. Declining is the
  -- honest answer -- the battle draws on the plain screen -- and it has to be
  -- said explicitly, because the fallback search below would otherwise go and
  -- find one of the bad spots that were already rejected by eye.
  if pick == false then return nil end
  if pick then
    local shape = nil
    for _, s in ipairs(BattleArena.SHAPES) do
      if s.id == (pick.shape or "wide") then shape = s end
    end
    -- an entry may point at another floor of the same cave or building; the
    -- arena is then measured against THAT map, and carries it
    local host = map
    if shape and pick.map and pick.map ~= map.id then
      -- Gold maps are not loaded by src.world.MapLoader, and a borrowed
      -- Red/Blue floor is never a safe substitute for a Johto/Kanto-GSC map.
      -- Until a Gen-2 arena author marks and validates such a floor, fall
      -- through to the current-map search instead of fabricating one.
      if V.game and V.game.world then shape = nil end
    end
    if shape and pick.map and pick.map ~= map.id then
      local ok, other = pcall(function()
        local Game = require("src.core.Game")
        return require("src.world.MapLoader").load(Game.data, pick.map)
      end)
      host = (ok and other) or nil
    end
    if shape and host and type(pick.x) == "number"
        and type(pick.y) == "number"
        and pick.x == math.floor(pick.x) and pick.y == math.floor(pick.y) then
      -- An authored spot is checked with WATER COUNTING AS GROUND, whatever
      -- the player is doing. The surfing test exists to stop the automatic
      -- search staging a walker's fight out at sea; an authored entry was
      -- chosen and looked at by a person, so if it is on water that is the
      -- point of it -- the surf routes fight in the middle of their own
      -- ocean rather than on a scrap of beach at the edge of the map. Land
      -- entries are unaffected: land passes the test either way.
      local grid, gw = openGrid(host, true)
      -- measured against the TURNED footprint: an entry that lies the arena
      -- down an east-west corridor covers different ground from the one that
      -- stands it up, and the fit test is the thing that has to know
      local fw, fh = BattleArena.extent(shape, pick.turn)
      if fits(grid, gw, pick.x, pick.y, fw, fh) then
        local arena = place(shape, pick.x, pick.y, pick.turn)
        arena.map = host
        arena.anchorHeight = floorProfile(host, arena)
        -- which camera rig this spot is framed for; nil is the default long
        -- lens, "close" the short one small rooms need (see BattleCam)
        arena.cam = pick.cam
        arena.anchorSource = forced ~= nil and "runtime-override"
          or "authored-gen2"
        -- Authored does not mean unchecked. Map edits and replacement packs
        -- can put a tree or wall in yesterday's clear sight line.  If the
        -- author did not require a lens, the compact wide rig gets one honest
        -- retry before this entry degrades to the live search.
        if arena.anchorHeight ~= nil
            and BattleArena.clearance(host, arena) then return arena end
        if pick.cam == nil then
          arena.cam = "wide"
          if BattleArena.clearance(host, arena) then return arena end
        end
      end
    end
  end

  local found = BattleArena.search(map, fromX, fromY, surfing)
  if found then found.map = map end
  return found
end

-- The arena at a given north-west corner, whatever the map says about it.
-- The authoring tool's manual override: a spot chosen by eye rather than by
-- the search, so it can be photographed and judged before it is written down.
function BattleArena.at(x, y, shapeId, turn)
  for _, shape in ipairs(BattleArena.SHAPES) do
    if shape.id == (shapeId or "wide") then
      return place(shape, x, y, turn)
    end
  end
  return nil
end

-- The nearest arena the map can offer, preferring one the pair can be SEEN
-- in. Two passes rather than one score: a clear arena on the far side of a
-- route beats an obstructed one underfoot, because being able to see the
-- fight is the point, but an obstructed one still beats no battle at all.
function BattleArena.search(map, fromX, fromY, surfing, wantClear)
  local grid, gw, gh = openGrid(map, surfing)
  -- Search every shape for a clear shot before accepting an obstructed one.
  -- Within each pass the wide authored composition still wins over narrow.
  for _, needClear in ipairs({ true, false }) do
    for _, shape in ipairs(BattleArena.SHAPES) do
      local best, bestD = nil, nil
      -- A corridor may only fit when the whole arena is turned. Test the four
      -- actual compositions, not merely the unrotated footprint.
      for _, turn in ipairs({ 0, 90, 180, 270 }) do
        local fw, fh = BattleArena.extent(shape, turn)
        for y = 0, gh - fh do
          for x = 0, gw - fw do
            if fits(grid, gw, x, y, fw, fh) then
              local mx = x + (fw - 1) / 2
              local my = y + (fh - 1) / 2
              local dx, dy = mx - (tonumber(fromX) or 0),
                                   my - (tonumber(fromY) or 0)
              local d = dx * dx + dy * dy
              if not bestD or d < bestD then
                local cand = place(shape, x, y, turn)
                local accepted = false
                -- Bind every accepted candidate to the floor that was
                -- actually inspected. BattleScene then uses the same level
                -- for actors and camera instead of recomputing from only one
                -- mark after a map/arena transition.
                cand.anchorHeight = floorProfile(map, cand)
                -- Default/tele first; small rooms receive the same bounded
                -- wide-lens fallback as reviewed Kanto arenas.
                for _, lens in ipairs({ false, "wide" }) do
                  cand.cam = lens or nil
                  local seat = cand.anchorHeight ~= nil
                    and cameraSeatClear(map, cand)
                  if seat and (not needClear
                      or BattleArena.clearance(map, cand)) then
                    accepted = true
                    break
                  end
                end
                if accepted then
                  cand.anchorSource = needClear and "dynamic-gen2-clear"
                    or "dynamic-gen2-obstructed"
                  best, bestD = cand, d
                end
              end
            end
          end
        end
      end
      if best then return best end
    end
    if wantClear and needClear then return nil end
  end
  return nil
end

return BattleArena
