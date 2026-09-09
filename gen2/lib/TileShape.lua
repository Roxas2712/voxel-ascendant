-- Voxel world mode: resolve every tile of a tileset to an extrusion shape.
--
-- Reads the hand-authored groups in data/voxel_heights.lua and fills the
-- gaps from data the ROM extractor already emits. Resolution happens at two
-- granularities, and the order matters:
--
--   per tile   1. a group named in data/voxel_heights.lua  (hand-authored)
--   per CELL   2. the cell is water                        -> "water"
--              3. the cell is walkable                     -> "ground"
--   per tile   4. tile-level fallback: the map's water set -> "water",
--                 its walkable set -> "ground", else       -> "wall"
--
-- The cell steps (TileShape.at) are the load-bearing part. Collision in
-- this engine -- like the GB original -- is defined per 16x16 CELL, judged
-- by the cell's bottom-left 8x8 tile alone. The other three tiles of a
-- cell carry no collision meaning, and treating their walkable-list
-- membership as one (which is what a pure per-tile lookup does) misfiles
-- every decorative tile: flowers become 16px pillars, the gap tiles of a
-- fence row become wall, grass tufts extrude. A tile in a walkable cell is
-- ground the player is standing on, whatever the walkable list says about
-- it; hand-authoring (rule 1) is the only thing that overrides that.
--
-- Rule 4 covers positions whose cell IS blocked: there, walkable-listed
-- tiles (the gaps between fence posts) stay ground and the rest rise.
--
-- Every class also carries an ART mode, which is what the mesher renders:
--
--   flat     ground/water/void: a single quad, no box.
--   top      ledge/roof: a box with its art on the TOP face -- things
--            whose 2D art depicts a surface seen from above.
--   upright  wall/tree/fence/sign: a box whose SOUTH face reconstructs
--            the 2D artwork standing up (the mesher's fold-up rule) --
--            things whose 2D art depicts a surface seen face-on, which is
--            most of Gen 1: interior walls, furniture, tree canopies,
--            building facades.
--
-- Purely presentational: a shape decides how a tile DRAWS in voxel mode
-- and nothing else. Collision still reads the same walkable list it
-- always did.

-- the mod namespace (see main.lua): V.data loads a shipped data file
local V = ...

local TileShape = {}

-- class -> height fallbacks, used when data/voxel_heights.lua is missing
-- or omits a class. Same numbers the shipped file carries; a cell is 16x16.
local FALLBACK_HEIGHTS = {
  ground = 0,
  water = -2,
  void = 0,
  ledge = 6,
  fence = 10,
  sign = 12,
  wall = 16,
  tree = 16,
  -- masonry drawn TWO courses tall: the Indigo Plateau's rim and the
  -- badge-check gates down Route 23 are drawn 32px, the same height as a
  -- statue on its plinth, and read as a step in the terrain rather than a
  -- room's wall.  Same fold as `wall`, twice the height -- and its own
  -- class because `wall` is 16px for every interior in the game.
  cliff = 32,
  -- THE FOUR WALLS OF A ROOM (Structures.indoorShell).  A GSC interior
  -- draws only the wall band you can see from a top-down camera and
  -- nothing at all along its east, west and south edges, so a room meshed
  -- literally is a strip of furniture on an open plate.  This is the mass
  -- built around it -- the OUTSIDE of the box, two courses so it stands
  -- clear of the 16px band drawn inside it and reads as wall carrying on
  -- up to a ceiling rather than as a kerb.
  shell = 32,
  -- A FALL: the sheet of water between two river levels (cave tile $40,
  -- collision $33).  Not a height so much as a starting point -- the drop
  -- is however many rows of it the map draws, which is four cells at Mt.
  -- Mortar and two at Tohjo Falls, and Structures.buildFalls measures each
  -- one and raises the river above it to stand on top.  Boxed at a flat
  -- 32px it was a kerb across an otherwise level river, with the pool it
  -- pours OUT of sitting lower than the fall itself.
  waterfall = 32,
  -- RAISED GROUND: the top of a plateau, not the wall around it.  Gen 2
  -- stores no elevation at all -- a terrace and the grass below it are
  -- both collision $00 -- so the only place the drop is recorded is the
  -- art, and there it is a change of FLOOR TILE: Johto's $3C dirt is
  -- drawn nowhere but on top of a cliff.  One course, so a terrace top
  -- lands flush with the 16px cliff face that holds it up.
  terrace = 16,
  roof = 28,
  cylinder = 16,
  -- big round scenery: a 2x2-CELL drawing carved as ONE 32px voxel hull
  -- (Viridian Forest's trees). The class pins only the drawing's
  -- top-left corner tile; the other cells stay `cylinder` and are
  -- claimed by the group build (see Structures.buildCylinders)
  canopy = 32,
  -- a cylinder hull whose drawn top is a CUT FACE (tree stumps): the
  -- body builds from the bark rows and the drawn ellipse projects onto
  -- the hull's round top
  stump = 16,
  -- the same hull cut at both ends, hollowed and tapered: an OPEN bin
  -- standing on a floor (the Vermilion Gym trash cans).  The drawn mouth
  -- ellipse projects onto the round top and down the well, the drawn base
  -- ellipse is ground contact rather than body, and the plan narrows toward
  -- the floor.  Height is AUTHORED (the profile's can_height, which this
  -- pin must be kept equal to so anything riding a can lands on its rim) --
  -- the drawing's own straight run is only a couple of rows, because a GB
  -- cell spends most of itself on the opening
  can = 9,
  -- round scenery drawn ONE cell wide and TWO cells TALL, standing on one
  -- cell of plot: the Pokemon Centers' potted plants. Carved as one
  -- 16x32x16 hull in the SOUTH (pot) cell -- the drawing's upper cell is
  -- the object's height, not its depth. BOTH cells take the class; the
  -- group build anchors on the north one (Structures.buildCylinders)
  planter = 32,
  billboard = 16,
  signpost = 16,
  post = 16,
  -- a post that is STRUCTURE rather than railing: Sprout Tower's side
  -- columns carry the floor above and stand as tall as the great beam
  -- they flank.  Its own class because `post` is waist-high everywhere
  -- else in the game, and a fence is not a pillar.
  column = 32,
  grass = 0,
  flower = 0,
  -- interior furniture: face-on drawings the detector would otherwise
  -- raise to wall height (or merge into the wall).  A bed is drawn from
  -- above and lies low; tables and desks are boxes at their real height;
  -- stairs become stepped geometry rising toward the named side.
  bed = 7,
  stool = 8,
  counter = 8,
  -- the raised back band of low seating: the Center couch's west strip
  -- is drawn from above like the rest of the couch, but depicts the
  -- back and arm rising over the 8px seat
  backrest = 12,
  table = 12,
  desk = 24,
  prop = 16,
  cutout = 16,
  -- a vehicle drawn SIDE-ON: the showroom bicycles.  Standee height like
  -- every other cutout pool -- what differs is the thickness (see
  -- Structures' PINNED_DEPTH)
  bike = 16,
  console = 16,
  relief = 3,
  bookcase = 32,
  stair_e = 16,
  stair_w = 16,
  stair_down_e = 16,
  stair_down_w = 16,
}

-- class -> how the mesher draws it (see the header). The last three are
-- profile archetypes Structures.lua builds special geometry for:
--   cylinder   round-drawn cells (tree canopies) become voxel hulls cut
--              from the art's darkest-pixel outline, round in depth
--   billboard  signs, props: the art stands as a thin per-pixel voxel
--              slab, transparency respected
--   post       fence posts: the same thin per-pixel slab, but every CELL
--              stands alone in its own depth band -- a north-south fence
--              line is a march of separate posts, not one tall drawing
--              (which is what a shared cluster would make of it)
--   grass      tall grass: flat ground PLUS two thin standing rows of
--              tufts per tile (the art's top and bottom halves), each at
--              its drawn depth -- the player walks between them
local ART = {
  ground = "flat",
  water = "flat",
  void = "flat",
  ledge = "top",
  -- like a ledge and for the same reason: the drawing IS the surface you
  -- stand on, seen from above, so it rides the top face of its box rather
  -- than folding up the front of it
  terrace = "top",
  roof = "top",
  wall = "upright",
  cliff = "upright",
  waterfall = "upright",
  shell = "upright",
  tree = "upright",
  fence = "upright",
  sign = "upright",
  cylinder = "cylinder",
  canopy = "canopy",
  stump = "cylinder",
  can = "cylinder",
  planter = "planter",
  billboard = "billboard",
  -- signposts share the billboard treatment but as their own pool at a
  -- 2-voxel depth: a sign is a thin plate on a stick, and the standard
  -- 10px standee body reads as a chunk of furniture outdoors
  signpost = "billboard",
  post = "post",
  column = "post",
  grass = "grass",
  -- animated flowers: flat synthesized ground PLUS a standing cutout of
  -- the drawing's darkest tones, one voxel deep (see Structures'
  -- buildFlowers). Height 0 so a build with no pixel access degrades to
  -- the flat tile it always drew, not a box
  flower = "flower",
  -- furniture: a bed's art depicts its top surface; tables and desks are
  -- boxes whose fronts fold up (the mesher's authored-fold rule).
  -- Stools, `prop` and `cutout` are standee pools alongside `billboard`
  -- -- same per-pixel cutout, different thickness (see Structures'
  -- PINNED_DEPTH), and separate pools cluster separately so touching
  -- drawings never stack; a stool keeps its 8px height so a character
  -- standing on its (walkable) cell sits at seat height.  Stairs are a
  -- profile archetype Structures builds real steps for -- rising flights
  -- for stairs leading up, sunken stairwells for stairs leading down
  bed = "top",
  -- a backrest's art is the couch seen from above, so like the bed it
  -- rides the top face of its taller box
  backrest = "top",
  stool = "billboard",
  -- half-cell furniture: a service counter, a low couch.  One 8px band,
  -- so exactly the drawing's bottom row stands up as the front and
  -- every row above it rides the top face in drawn order -- which is
  -- also the only way to place a figure drawn INTO the furniture (the
  -- Center's seated man) without repeating him, since a taller box
  -- folds two rows upright and then repeats its north row across the
  -- top.  Reads as something you lean on rather than a wall stub
  counter = "upright",
  table = "upright",
  desk = "upright",
  prop = "billboard",
  cutout = "billboard",
  -- a bicycle is a LINE drawing seen side-on, and its negative space --
  -- the air inside the frame, between the wheel and the fork -- is what
  -- makes it read as a bicycle at all.  Its own pool at two voxels: any
  -- thicker and the side faces of neighbouring strokes close those gaps
  -- from every angle but dead-on, and six of them in a showroom come out
  -- as one dark lump (which is what the 5px `prop` pool gave)
  bike = "billboard",
  -- a machine standing on furniture: the billboard treatment with
  -- body, plus the one-object contract `cutout` has -- the drawing is
  -- ringed by the furniture it sits on, and those edges must not be
  -- extruded along with it (see Structures' component filter)
  console = "billboard",
  relief = "relief",
  -- free-standing shelves: the drawing is TALL, not deep -- Structures
  -- collapses each drawn rank onto a one-cell-deep box at full height
  bookcase = "bookcase",
  stair_e = "stair",
  stair_w = "stair",
  stair_down_e = "stair",
  stair_down_w = "stair",
}

local spec = nil          -- the loaded data file, or false when absent
local cache = {}          -- tileset id -> resolved shape list
local figCache = {}       -- tileset id -> parsed figure masks, or false
local mntCache = {}       -- tileset id -> parsed mounted masks, or false
local bgCache = {}        -- tileset id -> prop background shades, or false

-- The shape profile ships with the mod (data/voxel_heights.lua) and is read
-- through the mod's own file loader rather than package.path: a mod's
-- directory is not on it, and may live inside a mounted .love archive that
-- plain require cannot reach either.  Absent or broken degrades to the
-- derived defaults, which is a rougher-looking world rather than no world.
local function load()
  if spec == nil then
    local ok, s = pcall(V.data, "voxel_heights")
    spec = (ok and type(s) == "table") and s or false
  end
  return spec or nil
end

function TileShape.heights()
  local s = load()
  local out = {}
  for class, h in pairs(FALLBACK_HEIGHTS) do out[class] = h end
  for class, h in pairs(s and s.heights or {}) do
    if type(h) == "number" and FALLBACK_HEIGHTS[class] then out[class] = h end
  end
  return out
end

-- tile id -> class, from the hand-authored groups for one tileset. Unknown
-- class names are dropped rather than trusted: a typo in the data file
-- should degrade to the derived default, not invent a zero-height class.
local function authoredGroups(tilesetId, heights)
  local s = load()
  local entry = s and s.tilesets and s.tilesets[tilesetId]
  local out = {}
  if not entry then return out end
  for class, tiles in pairs(entry) do
    if heights[class] and type(tiles) == "table" then
      for _, t in ipairs(tiles) do out[t] = class end
    end
  end
  return out
end

-- Conditional pins: tile id -> list of { above = {tile ids}, class }.
--
-- A pin is per TILE ID, and one graphic can mean two things. The route
-- gates' $32/$33 is the case that forced this: the artist reuses it for
-- the wall's dark base course AND for every service counter's front, and
-- it is the bottom row of its cell either way. Pinned `wall` the counter
-- stands a full 16px; pinned `counter` the wall bank corrugates 16/8 for
-- sixteen rows. Neither is right, and no per-tile pin can be, because
-- forMap resolves an id to ONE shape.
--
-- What separates the two uses is what is drawn ABOVE: the wall's upper
-- course over a wall base, the counter's top over a counter front. So a
-- profile entry may carry `when_above = { [tile] = { { above = {...},
-- class = "..." } } }`, evaluated per POSITION in TileShape.at, where
-- the map and coordinates are in hand. First match wins; no match keeps
-- the tile's ordinary pin.
-- `when_below` is the mirror, and it exists because ABOVE is not always the
-- side that tells the two uses apart.  The Plateau's $0D is the case: it is
-- the gate wall's top band AND the base course under a column of rock face,
-- and scanned over both maps the tile above is $03 for 64 of the first and
-- 140 of the second -- no rule on `above` can split them.  What is BELOW
-- does, exactly: the wall's own face $0F sits under the top band and under
-- nothing else (336 vs 352, clean).
local function authoredConditions(tilesetId, heights)
  local s = load()
  local entry = s and s.tilesets and s.tilesets[tilesetId]
  if type(entry) ~= "table" then return nil end
  local out, any = {}, false

  local function collect(spec, side)
    if type(spec) ~= "table" then return end
    for tile, rules in pairs(spec) do
      if type(tile) == "number" and type(rules) == "table" then
        local list = out[tile] or {}
        for _, rule in ipairs(rules) do
          if type(rule) == "table" and heights[rule.class]
             and type(rule[side]) == "table" then
            local set = {}
            for _, t in ipairs(rule[side]) do set[t] = true end
            list[#list + 1] = { side = side, set = set, class = rule.class }
          end
        end
        if #list > 0 then
          out[tile] = list
          any = true
        end
      end
    end
  end

  collect(entry.when_above, "above")
  collect(entry.when_below, "below")
  return any and out or nil
end

local function shapeFor(class, heights, authored)
  return { class = class, h = heights[class] or 0,
           art = ART[class] or "upright",
           -- grass and flowers draw a flat ground base like any walkable
           -- tile; the standing tufts and cutouts are additive geometry
           -- from Structures
           flat = ART[class] == "flat" or class == "grass"
                  or class == "flower",
           authored = authored or false }
end

-- Resolved TILE-LEVEL shapes for the tileset `map` uses: a list indexed by
-- tile id holding { class, h, art, flat, authored }, plus `classes`, one
-- canonical shape per class for the cell-level overrides in TileShape.at.
-- Cached per tileset id -- this table depends only on the tileset record
-- and the data file, both constant for a given id. The per-map part of
-- resolution (cell walkability) lives in TileShape.at, NOT here.
function TileShape.forMap(map)
  local tileset = map.tileset
  local id = tileset.id
  if cache[id] then return cache[id] end

  local heights = TileShape.heights()
  -- Per-tileset height overrides (a tileset entry's `heights`): the class
  -- vocabulary is global but the drawings are not -- the DOJO lab tables
  -- are drawn 6px tall where the default `table` is 12 -- and the height
  -- a sprite RIDES at (VoxelScene.groundAt) must be the height the art
  -- actually stands, or the starter balls float over their own table.
  -- Same gate as the global list: known classes, numbers only.
  do
    local s = load()
    local entry = s and s.tilesets and s.tilesets[id]
    local over = entry and entry.heights
    if type(over) == "table" then
      for class, h in pairs(over) do
        if type(h) == "number" and FALLBACK_HEIGHTS[class] then
          heights[class] = h
        end
      end
    end
  end
  local authored = authoredGroups(id, heights)
  local count = math.floor((tileset.imageWidth or 128) / 8)
                * math.floor((tileset.imageHeight or 48) / 8)

  -- derived pin: a tile the tileset animates by FRAME REWRITE (the
  -- overworld's flower) is already named by its animation spec, so like
  -- tall grass it needs no profile entry anywhere. Hand-authoring still
  -- wins -- a mod animating a wall tile this way keeps its wall by
  -- listing it. Guarded because the spec seam is engine data a stub map
  -- may not carry.
  local flowerTiles = {}
  do
    local ok, declared = pcall(function()
      if tileset.animatedTiles then return tileset.animatedTiles end
      local TileRenderer = require("src.render.TileRenderer")
      return TileRenderer.defaultAnimatedTiles(tileset)
    end)
    if ok then
      for _, spec in ipairs(type(declared) == "table" and declared or {}) do
        if spec.kind == "frames" and spec.tile then
          flowerTiles[spec.tile] = true
        end
      end
    end
  end

  local shapes = { classes = {}, cond = authoredConditions(id, heights) }
  local profile = load()
  local entry = profile and profile.tilesets and profile.tilesets[id]
  shapes.caveElevation = entry and entry.cave_elevation
  for class in pairs(FALLBACK_HEIGHTS) do
    shapes.classes[class] = shapeFor(class, heights)
  end
  -- a conditional pin's own AUTHORED shape per class it can resolve to,
  -- kept apart from the shared canonical ones above (see TileShape.at)
  if shapes.cond then
    shapes.condShape = {}
    for _, rules in pairs(shapes.cond) do
      for _, rule in ipairs(rules) do
        shapes.condShape[rule.class] = shapes.condShape[rule.class]
          or shapeFor(rule.class, heights, true)
      end
    end
  end

  -- Gen 2 carries one COLLISION CLASS per 16x16 cell rather than leaning on
  -- tile ids, and the classes name what a cell IS -- tree, tall grass, door,
  -- counter.  A pin on a class therefore separates things no tile-id pin can:
  -- the lone tree and the tree WALL are drawn from the same six tiles and
  -- differ only here.  Only Gen 2 tilesets ship the table, so its presence is
  -- also the gate (map:cellTile answers a tile id without it).
  if tileset.collision then
    local s = load()
    for class, name in pairs((s and s.collision) or {}) do
      if type(class) == "number" and heights[name] then
        shapes.coll = shapes.coll or {}
        shapes.coll[class] = shapeFor(name, heights, true)
      end
    end
  end

  -- Gen 1 names water and floor by TILE ID, Gen 2 by collision class, and
  -- the two numberings overlap end to end: read as tile ids the Johto land
  -- classes cover most of the atlas, so every interior wall came out flat
  -- ground.  Where a class table exists the cell rules in TileShape.at are
  -- the whole truth and a solid tile has no business being anything but
  -- solid, so the derived per-tile pins below are Gen 1's alone.
  local perTile = not tileset.collision

  for t = 0, count - 1 do
    local class = authored[t]
    if class then
      shapes[t] = shapeFor(class, heights, true)
      if class == 'cliff' then
        shapes[t].surfaceTiles = entry and entry.cliff_surface_tiles
      end
    elseif perTile and t == tileset.grassTile then
      -- derived pin: every tileset already names its tall-grass tile, so
      -- the standing-tuft treatment needs no profile entry anywhere
      shapes[t] = shapeFor("grass", heights, true)
    elseif flowerTiles[t] then
      shapes[t] = shapeFor("flower", heights, true)
    elseif perTile and map.waterTiles and map.waterTiles[t] then
      shapes[t] = shapes.classes.water
    elseif perTile and map.walkable and map.walkable[t] then
      shapes[t] = shapes.classes.ground
    else
      shapes[t] = shapes.classes.wall
    end
  end
  shapes.count = count
  cache[id] = shapes
  return shapes
end

-- SEALED POCKETS: the inside of a mountain.
--
-- Gen 2 draws a rocky mass as a RING of solid cells around cells that are
-- still marked walkable, because in two dimensions nobody can ever stand
-- in there to find out.  Read literally that makes the mesh a kerb with a
-- pit inside it: the top of every mountain on Routes 45 and 46 came out
-- sunk to ground level, and with free movement on you could walk into one
-- from the north and stand in the hole.
--
-- So: flood the open cells inward from the map's EDGE, and whatever the
-- flood never reaches is not somewhere the game can put the player.  Fill
-- it, and the ring becomes a mass with a top.  A pocket holding a WARP is
-- left alone -- that is a walled yard with a door in it, not rock.
--
-- Keyed by map identity, not by tileset (which is what `cache` above is
-- for): the answer is a property of one map's block layout.
local sealCache = setmetatable({}, { __mode = "k" })

local function sealedCells(map)
  local hit = sealCache[map]
  if hit ~= nil then return hit or nil end
  local w, h = map.widthCells, map.heightCells
  if not (w and h and w > 0 and h > 0) then
    sealCache[map] = false
    return nil
  end

  local open, sealed = {}, {}
  for cy = 0, h - 1 do
    for cx = 0, w - 1 do
      if map:isWalkableCell(cx, cy) or map:isWaterCell(cx, cy) then
        local k = cy * w + cx
        open[k] = true
        sealed[k] = true
      end
    end
  end

  local queue, n = {}, 0
  local function seed(cx, cy)
    local k = cy * w + cx
    if sealed[k] then
      sealed[k] = nil
      n = n + 1
      queue[n] = k
    end
  end
  for cx = 0, w - 1 do seed(cx, 0); seed(cx, h - 1) end
  for cy = 0, h - 1 do seed(0, cy); seed(w - 1, cy) end

  local head = 0
  while head < n do
    head = head + 1
    local k = queue[head]
    local cx, cy = k % w, math.floor(k / w)
    seed(cx - 1, cy); seed(cx + 1, cy)
    seed(cx, cy - 1); seed(cx, cy + 1)
  end

  -- a pocket with a door -- or with somebody STANDING in it -- is somewhere
  -- the player is meant to be
  --
  -- The object-event seed is what rescues a locked room.  Team Rocket's
  -- hideout seals its middle floor behind doors the scripts `changeblock`
  -- open, so read statically the whole room is a pocket no flood can
  -- enter: B2F came out filled from wall to wall and the player stood at
  -- the bottom of a one-cell trench with the floor risen to eye height all
  -- around them.  Nothing ever stands inside a mountain, so the seed costs
  -- the terrain case nothing.
  local seeds = {}
  local warpTable = type(map.warpAt) == "table" and map.warpAt or nil
  local hasWarpAtCell = type(map.warpAtCell) == "function"
  local hasWarpAtMethod = (not warpTable) and type(map.warpAt) == "function"
  for k in pairs(sealed) do
    local cx, cy = k % w, math.floor(k / w)
    -- Gen 1 can carry a `warpAt` table; Gold's Gen-2 Map instead exposes
    -- warpAt()/warpAtCell() methods.  Never index the function value.
    local hasWarp = warpTable and warpTable[k] ~= nil
    if not hasWarp and hasWarpAtCell then
      hasWarp = map:warpAtCell(cx, cy) ~= nil
    elseif not hasWarp and hasWarpAtMethod then
      hasWarp = map:warpAt(cx, cy) ~= nil
    end
    if hasWarp then
      seeds[#seeds + 1] = k
    end
  end
  for _, obj in ipairs((map.def and map.def.objects) or {}) do
    local cx, cy = tonumber(obj.x), tonumber(obj.y)
    if cx and cy and cx >= 0 and cy >= 0 and cx < w and cy < h then
      seeds[#seeds + 1] = cy * w + cx
    end
  end
  local reachable = {}
  for _, k in ipairs(seeds) do
    if sealed[k] then reachable[#reachable + 1] = k end
  end
  for _, k in ipairs(reachable) do
    n = n + 1
    queue[n] = k
    sealed[k] = nil
  end
  while head < n do
    head = head + 1
    local k = queue[head]
    local cx, cy = k % w, math.floor(k / w)
    seed(cx - 1, cy); seed(cx + 1, cy)
    seed(cx, cy - 1); seed(cx, cy + 1)
  end

  if next(sealed) == nil then sealed = false end
  sealCache[map] = sealed
  return sealed or nil
end

-- Which cell a hop class DROPS into, as an offset FROM the lip back to the
-- hop cell.  Read off the tileset blocks, where the lip is always the $07
-- neighbour on that side: $A0 hops east over tile $3D, $A1 west over $3B,
-- $A3 south over $4C, and $A4/$A5 are the corners that do two at once.
--
-- It has to be the neighbour's class that decides, because $3B and $3D are
-- also the cliff POSTS -- the two tiles Route 45 is mostly made of -- so no
-- tile pin can tell a knee-high side lip from a cliff face.  Left as walls
-- they stood 16 tall against the south lip's 6, which is why a left- or
-- right-facing ledge looked twice the height of the one next to it.
local HOP_LIP = {
  { -1, 0, { [0xA0] = true, [0xA4] = true } },
  { 1, 0, { [0xA1] = true, [0xA5] = true } },
  { 0, -1, { [0xA3] = true, [0xA4] = true, [0xA5] = true } },
}

-- ...and outdoors, or in a tileset that asks for them (`hop_lips = true`
-- in its profile entry).  Everywhere else indoors the same classes mark a
-- step down off a raised floor whose edge is drawn as the room's own
-- full-height wall, and the knee-high reading cuts 6px notches out of
-- solid runs.  The CAVES are the exception that needed the opt-in: their
-- $A1/$A3/$A5 rows really are hops down a rock lip, and with the lip left
-- as wall -- or, once the cave profile pinned it, as `cliff` -- a ledge
-- you can jump was drawn twice the height of the same ledge outdoors.
local outdoorCache = setmetatable({}, { __mode = "k" })
local function hopLipsApply(map)
  local hit = outdoorCache[map]
  if hit == nil then
    local s = load()
    local entry = s and s.tilesets and s.tilesets[map.tileset.id]
    local ok, outdoor = pcall(function()
      return map.def ~= nil and require("src.world.gen2.Map").isOutdoor(map.def)
    end)
    hit = (entry and entry.hop_lips == true) or (ok and outdoor) or false
    outdoorCache[map] = hit
  end
  return hit
end

-- The shape of the tile at TILE coordinates (tx, ty) -- the full
-- resolution including the cell-granularity steps (see the header).
-- `shapes` is the table forMap returned for this map; `tile` is
-- map:tileAt(tx, ty), passed in because every caller already has it.
local elevationCache = setmetatable({}, { __mode = 'k' })
local caveEdges={{0,-1},{0,1},{-1,0},{1,0}}
function TileShape.invalidateElevation(mapId)
  for map in pairs(elevationCache) do
    if not mapId or map.id == mapId then elevationCache[map] = nil end
  end
end
function TileShape.elevation(map, shapes)
  if not shapes.caveElevation or not map.def or map.def.environment ~= 'CAVE' then return nil end
  local e = elevationCache[map]
  if not e or e.blocks ~= map.blocks or e.tileset ~= map.tileset then
    e = V.require('CaveElevation').build(map, shapes.caveElevation)
    -- Refuse inconsistent inferred geometry; preserve the authored fallback.
    e.valid = #e.conflicts == 0
    e.shapeCache = {}
    e.blocks, e.tileset = map.blocks, map.tileset
    elevationCache[map] = e
  end
  return e.valid and e or nil
end
-- A blocked round rock is not a floor node. Like the adjacent retaining
-- cliff, its foundation reaches the highest directly touching dry floor.
-- Requiring equal neighbours leaves alternate rocks buried along a terrace
-- edge. Never flood this height through a whole connected rock mass.
function TileShape.cavePropBase(map, shapes, cx, cy)
  local e = TileShape.elevation(map, shapes)
  if not e or cx < 0 or cy < 0 or cx >= map.widthCells or cy >= map.heightCells then return 0 end
  local base = 0
  for _,d in ipairs(caveEdges) do
    local nx,ny=cx+d[1],cy+d[2]
    if nx>=0 and ny>=0 and nx<map.widthCells and ny<map.heightCells then
      local h=e.floors[ny*e.width+nx]
      if h~=nil then base=math.max(base,h) end
    end
  end
  return base
end
local BLACKTHORN_LAVA_TILES = { [0x02]=true, [0x38]=true, [0x39]=true, [0x5b]=true }
local BLACKTHORN_LAVA_SHAPE = {class='ground',art='flat',h=0,flat=true,authored=true}
local BLACKTHORN_FLOOR_LINKS = {
  BLACKTHORN_GYM_1F={tiles={0x2c,0x2d,0x3c,0x3d},target='BLACKTHORN_GYM_2F',
    shape={class='stair_e',art='stair',h=16,flat=false,authored=true,surface='blackthorn_brick'}},
  BLACKTHORN_GYM_2F={tiles={0x40,0x41,0x42,0x43},target='BLACKTHORN_GYM_1F',
    shape={class='stair_down_e',art='stair',h=16,flat=false,authored=true,surface='blackthorn_brick'}},
}
local BLACKTHORN_SHAFT={class='floor_shaft',art='floor_shaft',h=0,depth=16,flat=false,authored=true,surface='blackthorn_brick'}
local BLACKTHORN_SHAFT_TILES={0x13,0x13,0x12,0x12}
-- The Tower atlas is also used by gyms. Only native inter-floor warps in
-- these two towers receive flights; teleport pads and reused art stay flat.
local TOWER_FLOORS={SPROUT_TOWER_1F='sprout',SPROUT_TOWER_2F='sprout',SPROUT_TOWER_3F='sprout',
  TIN_TOWER_1F='tin',TIN_TOWER_2F='tin',TIN_TOWER_3F='tin',TIN_TOWER_4F='tin',
  TIN_TOWER_5F='tin',TIN_TOWER_6F='tin',TIN_TOWER_7F='tin',TIN_TOWER_8F='tin',
  TIN_TOWER_9F='tin',TIN_TOWER_ROOF='tin'}
local TOWER_FLIGHTS={
  [0x0c]={tiles={0x0c,0x0d,0x1c,0x1d},
    shape={class='stair_n',art='stair',h=16,flat=false,authored=true,surface='tower_timber'}},
  [0x0e]={tiles={0x0e,0x0f,0x1e,0x1f},
    -- A 16-deep well over one 16px cell hides its 45-degree flight behind
    -- the floor lip at the standard 40-degree viewing elevation. Compress
    -- only this decorative descent to 8px; native warp/floor data is intact.
    shape={class='stair_down_n',art='stair',h=8,flat=false,authored=true,surface='tower_timber'}},
}
local BURNED_HOLE={class='floor_shaft',art='floor_shaft',h=0,depth=16,
  flat=false,authored=true,surface='burned_timber',sideTile=0x5e,bottomTile=0x01}
local FUCHSIA_HIDDEN_FLOOR={class='ground',art='flat',h=0,flat=true,authored=true}
function TileShape.at(map, shapes, tile, tx, ty)
  -- Native Fuchsia's invisible maze is blocked FLOOR ART, not visible
  -- masonry. Rendering it flat must never alter collision or reveal a route.
  local def=map.def
  if map.id=='FUCHSIA_GYM' and def and def.generation==2
      and def.tileset=='TILESET_LAB' and def.width==5 and def.height==9
      and def.environment=='INDOOR' and def.outdoor~=true
      and next(def.connections or {})==nil and tile==0x37
      and tx>=0 and ty>=0 and tx<map.widthCells*2 and ty<map.heightCells*2 then
    local cx,cy=math.floor(tx/2),math.floor(ty/2)
    if map:cellCollision(cx,cy)==0x07
        and map:tileAt(cx*2,cy*2)==0x37 and map:tileAt(cx*2+1,cy*2)==0x37
        and map:tileAt(cx*2,cy*2+1)==0x37 and map:tileAt(cx*2+1,cy*2+1)==0x37 then
      return FUCHSIA_HIDDEN_FLOOR
    end
  end
  -- The rival-event hole is a fall cell, not a 32px cliff. Read current
  -- collision/art so the native callback's pre-event floor stays closed.
  if map.id=='BURNED_TOWER_1F' and map.def and map.def.tileset=='TILESET_TOWER'
      and map.def.width==10 and map.def.height==9
      and tx>=20 and tx<=21 and ty>=18 and ty<=19
      and map:cellCollision(10,9)==0x60 then
    local hit=map:warpAtCell(10,9);local w=hit and hit.def
    if w and w.destMap=='BURNED_TOWER_B1F' and w.destWarp==1
        and map:tileAt(20,18)==0x5e and map:tileAt(21,18)==0x5e
        and map:tileAt(20,19)==0x01 and map:tileAt(21,19)==0x01 then
      return BURNED_HOLE
    end
  end
  local tower=TOWER_FLOORS[map.id]
  if tower and map.def and map.def.tileset=='TILESET_TOWER'
      and tx>=0 and ty>=0 and tx<map.widthCells*2 and ty<map.heightCells*2 then
    local cx,cy=math.floor(tx/2),math.floor(ty/2)
    if map:cellCollision(cx,cy)==0x72 then
      local hit=map:warpAtCell(cx,cy);local warp=hit and hit.def
      local flight=TOWER_FLIGHTS[map:tileAt(cx*2,cy*2)]
      if flight and warp and warp.destMap~=map.id and TOWER_FLOORS[warp.destMap]==tower then
        local matched=true
        for dy=0,1 do for dx=0,1 do
          if map:tileAt(cx*2+dx,cy*2+dy)~=flight.tiles[dy*2+dx+1]then matched=false end
        end end
        if matched then return flight.shape end
      end
    end
  end
  local link=BLACKTHORN_FLOOR_LINKS[map.id]
  if link and map.def and map.def.tileset=='TILESET_ELITE_FOUR_ROOM'
      and tx>=0 and ty>=0 and tx<map.widthCells*2 and ty<map.heightCells*2 then
    local cx,cy=math.floor(tx/2),math.floor(ty/2)
    local hit=map:warpAtCell(cx,cy)
    -- Gen2 Map returns a lookup receipt, not the native warp definition.
    local warp=hit and hit.def
    if warp and warp.destMap==link.target then
      local coll=map:cellCollision(cx,cy)
      local pattern=coll==0x72 and link.tiles
        or (map.id=='BLACKTHORN_GYM_2F' and coll==0x60 and BLACKTHORN_SHAFT_TILES)
      if pattern then
        local matched=true
        for dy=0,1 do for dx=0,1 do
          if map:tileAt(cx*2+dx,cy*2+dy)~=pattern[dy*2+dx+1] then matched=false end
        end end
        if matched then return coll==0x72 and link.shape or BLACKTHORN_SHAFT end
      end
    end
  end
  -- Lava is blocked to movement, but not a wall. Keep the native lava art
  -- flat without routing it through water shaders/SFX or changing collision.
  -- Verify the whole native cell, including its painted north rim ($39),
  -- not just a reusable blank atlas tile. The rim is not a tall barrier.
  if map.id=='BLACKTHORN_GYM_1F' and map.def
      and map.def.tileset=='TILESET_ELITE_FOUR_ROOM' and BLACKTHORN_LAVA_TILES[tile]
      and tx>=0 and ty>=0 and tx<map.widthCells*2 and ty<map.heightCells*2 then
    local cx,cy=math.floor(tx/2),math.floor(ty/2)
    if map:cellCollision(cx,cy)==0x07 then
      local lava=true
      for dy=0,1 do for dx=0,1 do
        if not BLACKTHORN_LAVA_TILES[map:tileAt(cx*2+dx,cy*2+dy)] then lava=false end
      end end
      if lava then return BLACKTHORN_LAVA_SHAPE end
    end
  end
  local e = TileShape.elevation(map, shapes)
  if e and tx >= 0 and ty >= 0 and tx < map.widthCells*2 and ty < map.heightCells*2 then
    local cell = math.floor(ty/2)*e.width + math.floor(tx/2)
    local wh=e.waterLevels and e.waterLevels[cell]
    if wh and wh>0 and (not shapes[tile] or shapes[tile].class=='water') then
      local key='water'..wh
      if not e.shapeCache[key]then
        local s={};for k,v in pairs(shapes.classes.water)do s[k]=v end
        s.h=wh;e.shapeCache[key]=s
      end
      return e.shapeCache[key]
    end
    local stair = e.stairs[cell]
    if stair then
      local key = 's'..stair.low
      if not e.shapeCache[key] then
        e.shapeCache[key] = {class='cave_stair',art='cave_stair',h=stair.high,
          low=stair.low,high=stair.high,authored=true,flat=false}
      end
      return e.shapeCache[key]
    end
    local h = e.floors[cell]
    if h ~= nil then
      if not e.shapeCache[h] then
        e.shapeCache[h] = {class=h>0 and 'terrace' or 'ground',
          art=h>0 and 'top' or 'flat',h=h,authored=true,flat=h==0}
      end
      return e.shapeCache[h]
    end
  end
  local s = shapes[tile]
  -- A rock retaining face must reach the connected terrace it supports.
  -- Do not propagate the height through a whole chamber or into water.
  if e and shapes.caveElevation.preserveUnconnected and s and s.class == 'cliff' then
    local cx,cy=math.floor(tx/2),math.floor(ty/2)
    local h=s.h
    for _,d in ipairs(caveEdges)do
      local nx,ny=cx+d[1],cy+d[2]
      if nx>=0 and ny>=0 and nx<map.widthCells and ny<map.heightCells then
        h=math.max(h,e.floors[ny*e.width+nx] or h)
      end
    end
    if h>s.h then
      local key='cliff'..h
      if not e.shapeCache[key]then
        local raised={};for k,v in pairs(s)do raised[k]=v end
        raised.h=h;e.shapeCache[key]=raised
      end
      s=e.shapeCache[key]
    end
  end
  -- conditional pins first: they are authored answers that need the
  -- POSITION to resolve, so they outrank both the flat pin on the same
  -- tile and the cell rules below (see authoredConditions)
  local rules = shapes.cond and shapes.cond[tile]
  if rules then
    for _, rule in ipairs(rules) do
      -- NOTE map:tileAt border-EXTENDS: one row off an edge answers the
      -- map's borderBlock, never nil.  A rule listing whatever that block
      -- draws will fire along that whole edge (it did, on the Marts).
      local n = map:tileAt(tx, rule.side == "above" and ty - 1 or ty + 1)
      if n and rule.set[n] then
        -- shapes.condShape, NOT shapes.classes: the canonical class
        -- shapes are SHARED, and `wall` in particular is the very object
        -- rule 4 hands every unauthored solid tile. Marking that one
        -- authored (which the first cut did) made every one of them skip
        -- the cell rules below, so walkable floors stopped flattening and
        -- whole rooms rose into a checkerboard of blocks.
        return shapes.condShape[rule.class]
      end
    end
  end
  if not s then return s end
  local cx = math.floor(tx / 2)
  local cy = math.floor(ty / 2)
  -- A HOP LIP outranks the tile's own pin.  The lip is drawn out of the
  -- same two tiles as the mountain face (outdoors) or the cave wall
  -- (indoors), so no pin on those tiles can know that THIS one is the
  -- knee-high edge of a ledge -- only the neighbour's class can.  Guarded
  -- on the cell being solid, which is what keeps the rule off the
  -- walkable ground the hop class itself sits on.
  if shapes.coll and shapes.classes.ledge and hopLipsApply(map)
     and not map:isWalkableCell(cx, cy) and not map:isWaterCell(cx, cy) then
    for _, rule in ipairs(HOP_LIP) do
      if rule[3][map:cellTile(cx + rule[1], cy + rule[2])] then
        return shapes.classes.ledge
      end
    end
  end
  if s.authored then return s end
  -- the inside of a mountain: solid, whatever the cell claims (see above)
  local sealed = sealedCells(map)
  if sealed and sealed[cy * map.widthCells + cx] then
    return shapes.classes.wall
  end
  -- a Gen 2 collision-class pin (see forMap) outranks the cell rules below
  -- for the same reason an authored tile does: it is a stated answer, and
  -- tall grass would otherwise flatten to the walkable ground it is
  if shapes.coll then
    local cs = shapes.coll[map:cellTile(cx, cy)]
    if cs then return cs end
  end
  if map:isWaterCell(cx, cy) then return shapes.classes.water end
  if map:isWalkableCell(cx, cy) then return shapes.classes.ground end
  return s
end

-- Hand-authored FIGURES for one tileset: a drawing painted INTO furniture,
-- cut out by an explicit pixel mask and stood up on top of it.
--
-- Every other route in this file resolves a whole 8x8 TILE, which is
-- exactly why none of them can reach a figure that shares its tiles with
-- the thing it sits on -- and the detector's segmentation cannot either
-- when the drawing has no background margin to flood from and wears the
-- same shades as its furniture.  So the profile authors the silhouette
-- pixel by pixel (see data/voxel_heights.lua):
--
--   figures = { { w      = <tiles across>,
--                 depth  = <voxels of body; ABSENT for a person>,
--                 thin   = { rows = <top rows>, depth = <voxels> },
--                 flat   = { x = { <lx0>, <lx1> }, rows = { <r0>, <r1> } },
--                 tiles  = { ...w*h tile ids, row-major... },
--                 under  = { ...w*h ids: what each tile wears once the
--                            figure is lifted off it... },
--                 pixels = { ...h*8 strings of w*8 chars, "." = not the
--                            figure... } } }
--
-- No class -- what the entry carries instead is a `depth`, or does not:
--
--   WITHOUT one it is a flat sprite card, drawn the way SpriteBillboards
--   draws a character.  That is the right reading for a PERSON: a Gen 1
--   figure is a face-on 2D icon, and extruding one reconstructs a body
--   nobody drew (see Structures.buildFigures).
--   WITH one it is an OBJECT and gets the standee treatment every other
--   solid here gets -- a per-pixel slab in world space, standing on the
--   same furniture the card would have stood on.  The Marts' cash
--   register is the case: a machine on a counter is a box, not an icon.
--
-- Two fields say which parts of such a drawing are NOT the extrusion,
-- because a solid drawn in one 16x16 GB cell still packs more than one
-- facing:
--
--   `thin` caps the thickness over the mask's top rows, for the part of
--   the drawing that is not the machine (the register's receipt curl).
--   `flat` names a rect of the mask that is a TOP-VIEW surface rather
--   than a face -- the register's keypad, whose keys lie ON its deck.
--   The rect lays horizontal one voxel proud of whatever the extrusion
--   leaves below it, at the elevation its BOTTOM row would have had,
--   with drawn row = depth row 1:1 (the mapping the lab tabletop is
--   drawn with).  So a drawing whose front elevation is an L reads as
--   one: body up the side and along the base, keys lying in the notch.
--
-- Returned normalized: `mask` as a set keyed by ly * (w * 8) + lx, so
-- Structures can read it as a bitmap without re-parsing per position.
-- A malformed entry is dropped rather than half-applied -- a typo in a
-- mask should leave the couch alone, not carve a hole in it.
--
-- `mounted` (below) carries the same four fields, so the parse is shared,
-- and so are the optional ones that give an authored mask a BODY: `depth`,
-- `thin` and `flat` above.  `depth` is left nil when unstated, because
-- absence is meaningful on a figure: no depth means the flat sprite card a
-- person is drawn as.
local function authoredMasks(list)
  local out = {}
  if type(list) ~= "table" then return out end
  for _, f in ipairs(list) do
    local ok = type(f) == "table" and type(f.w) == "number"
               and type(f.tiles) == "table" and type(f.under) == "table"
               and type(f.pixels) == "table"
    local w = ok and math.floor(f.w) or 0
    local h = (w >= 1) and (#f.tiles / w) or 0
    ok = ok and w >= 1 and h >= 1 and h == math.floor(h)
         and #f.under == #f.tiles and #f.pixels == h * 8
    if ok then
      for i = 1, h * 8 do
        local row = f.pixels[i]
        if type(row) ~= "string" or #row ~= w * 8 then
          ok = false
          break
        end
      end
    end
    if ok then
      local mask, n = {}, 0
      for ly = 0, h * 8 - 1 do
        local row = f.pixels[ly + 1]
        for lx = 0, w * 8 - 1 do
          if row:sub(lx + 1, lx + 1) ~= "." then
            mask[ly * (w * 8) + lx] = true
            n = n + 1
          end
        end
      end
      local depth = tonumber(f.depth)
      local thin = nil
      if type(f.thin) == "table" and tonumber(f.thin.rows)
         and tonumber(f.thin.depth) then
        thin = { rows = math.floor(tonumber(f.thin.rows)),
                 depth = math.floor(tonumber(f.thin.depth)) }
      end
      local flat = nil
      if type(f.flat) == "table" and type(f.flat.x) == "table"
         and type(f.flat.rows) == "table" then
        flat = { x0 = math.floor(f.flat.x[1]), x1 = math.floor(f.flat.x[2]),
                 r0 = math.floor(f.flat.rows[1]),
                 r1 = math.floor(f.flat.rows[2]) }
      end
      if n > 0 then
        out[#out + 1] = { w = w, h = h, n = n, mask = mask,
                          tiles = f.tiles, under = f.under,
                          depth = depth and math.floor(depth) or nil,
                          thin = thin, flat = flat }
      end
    end
  end
  return out
end

function TileShape.figures(tilesetId)
  local hit = figCache[tilesetId]
  if hit ~= nil then return hit or nil end

  local s = load()
  local entry = s and s.tilesets and s.tilesets[tilesetId]
  local out = authoredMasks(entry and entry.figures)

  figCache[tilesetId] = (#out > 0) and out or false
  return figCache[tilesetId] or nil
end

-- Hand-authored MOUNTED objects for one tileset: a thing drawn INTO the
-- wall band it hangs on, cut out by an explicit pixel mask and stood
-- proud of the wall's face.
--
-- Same authoring problem as `figures` and the same answer -- a class pin
-- resolves a whole 8x8 tile, and the detector cannot segment a drawing
-- that has no background margin to flood from.  The Bike Shop's two wall
-- bicycles are the case: the shop's striped wall panel runs BEHIND them,
-- and its #555 stripes are a flood boundary, so a silhouette flood comes
-- back with the stripes attached to the bike.
--
-- Two things differ from a figure, and both follow from the object being
-- an object rather than a character:
--
--   it keeps its DRAWN ELEVATION.  A figure stands on its own feet; a
--   mounted thing sits where the wall band draws it, so a bicycle hung
--   clear of the floor stays hung.
--   it has THICKNESS (`depth`, default 2), and it is built in world
--   space as a per-pixel slab jutting south of the band -- not as a
--   camera-facing sprite card.  A bicycle drawn side-on is a plane
--   parallel to the wall, not a face-on icon.
--
--   mounted = { { w      = <tiles across>,
--                 depth  = <voxels it juts into the room>,
--                 tiles  = { ...w*h tile ids, row-major... },
--                 under  = { ...w*h ids: what each tile wears once the
--                            object is lifted off it (the plain panel)... },
--                 pixels = { ...h*8 strings of w*8 chars, "." = wall... } } }
function TileShape.mounted(tilesetId)
  local hit = mntCache[tilesetId]
  if hit ~= nil then return hit or nil end

  local s = load()
  local entry = s and s.tilesets and s.tilesets[tilesetId]
  local out = authoredMasks(entry and entry.mounted)

  mntCache[tilesetId] = (#out > 0) and out or false
  return mntCache[tilesetId] or nil
end

-- Which GB shades count as BACKGROUND for a pinned per-pixel prop, per tile
-- (a tileset entry's prop_bg). Returns tile id -> set of shade names, or nil.
--
-- Structures normally votes on this by reading the shades that touch the
-- drawing's own bounding box, which is right whenever the drawing has a
-- margin of floor around it and wrong when it does not: a prop whose body
-- reaches its own edge votes itself out. Naming the shades is the override,
-- and it is keyed by TILE because the answer is per drawing rather than per
-- tileset -- two props in one atlas can want opposite calls on the same
-- shade (see the POKECENTER entry).
--
--   prop_bg = { { tiles = { ...ids... }, shades = { "light", "white" } } }
--
-- Only the four GB shade names exist, plus `none` -- anything else is
-- dropped, so a typo degrades to the ordinary vote rather than emptying the
-- background.
--
-- `none` says the drawing has NO background: nothing floods and the pin is
-- voxelized entire. It is the answer for a drawing that fills its own cell
-- edge to edge, where there is no margin for the vote to read and every
-- shade the object uses is also the floor's -- Sprout Tower's statues are
-- gilded in the same shade the floorboards are planked in, so any shade
-- named background takes half the statue with it.
local SHADES = { black = true, dark = true, light = true, white = true,
                 none = true }

-- Explicit outline pixels whose shade also occurs in the surrounding ground.
-- Sparse per-tile coordinates avoid retaining a whole cast-shadow shade.
function TileShape.propSolidPixels(tilesetId)
  local s=load()
  local entry=s and s.tilesets and s.tilesets[tilesetId]
  local rules=entry and entry.prop_solid_pixels
  if type(rules)~="table" then return nil end
  local out={}
  for _,rule in ipairs(rules) do
    if type(rule)=="table" and type(rule.tile)=="number" and type(rule.pixels)=="table" then
      local points={}
      for _,p in ipairs(rule.pixels) do
        local x,y=type(p)=="table" and p[1],type(p)=="table" and p[2]
        if type(x)=="number" and type(y)=="number" and x>=0 and x<8
            and y>=0 and y<8 and x%1==0 and y%1==0 then points[y*8+x]=true end
      end
      out[rule.tile]=points
    end
  end
  return out
end

function TileShape.propBg(tilesetId)
  local hit = bgCache[tilesetId]
  if hit ~= nil then return hit or nil end

  local s = load()
  local entry = s and s.tilesets and s.tilesets[tilesetId]
  local list = entry and entry.prop_bg
  local out, any = {}, false
  if type(list) == "table" then
    for _, rule in ipairs(list) do
      if type(rule) == "table" and type(rule.tiles) == "table"
         and type(rule.shades) == "table" then
        local set, n = {}, 0
        for _, name in ipairs(rule.shades) do
          if SHADES[name] then
            set[name] = true
            n = n + 1
          end
        end
        if n > 0 then
          for _, t in ipairs(rule.tiles) do
            if type(t) == "number" then
              out[t] = set
              any = true
            end
          end
        end
      end
    end
  end

  bgCache[tilesetId] = any and out or false
  return bgCache[tilesetId] or nil
end

-- A fence is drawn twice over: face on for its east-west runs (pickets with
-- daylight between them) and END ON for its north-south ones (one 8px column
-- repeated seamlessly, nothing to see through).  `rail_face` names the FACE-ON
-- tiles, top row first, so Structures can build the end-on run as a thin panel
-- wearing the face-on art on its flanks rather than as a cell-wide kerb.
-- Returns the tile list, or nil when the tileset states none.
function TileShape.railFace(tilesetId)
  local s = load()
  local entry = s and s.tilesets and s.tilesets[tilesetId]
  local list = entry and entry.rail_face
  if type(list) ~= "table" then return nil end
  local out = {}
  for _, t in ipairs(list) do
    if type(t) == "number" then out[#out + 1] = t end
  end
  return #out > 0 and out or nil
end

-- Complete floor-standing props must not inherit the height of adjacent
-- furniture. This is opt-in per source drawing; existing props keep their
-- automatic support behaviour.
function TileShape.propGrounded(tilesetId, tile)
  local s = load()
  local entry = s and s.tilesets and s.tilesets[tilesetId]
  for _, id in ipairs(entry and entry.prop_grounded or {}) do
    if id == tile then return true end
  end
  return false
end

-- What a bookcase rank does with the rows it VACATES -- the ones behind the
-- one-cell-deep box it collapses onto (a tileset entry's
-- bookcase_backfill).  Returns the mode name, or nil for the default.
--
--   "above"   hand them the cell immediately above the run: its shape and
--             its art.  A wall set INTO a terrace wants this -- the ground
--             behind it is more terrace, not a trench.
--   nil       skip them and paint the map's commonest ground underneath,
--             which is right for a free-standing shelf against a wall.
--
-- Per tileset because it is a statement about what the drawing depicts, and
-- the answer differs: the Mart's racks and Red's shelves stand in a room,
-- the Plateau's gate walls are cut into a hillside.
function TileShape.bookcaseBackfill(tilesetId)
  local s = load()
  local entry = s and s.tilesets and s.tilesets[tilesetId]
  local mode = entry and entry.bookcase_backfill
  return mode == "above" and mode or nil
end

--- Does this tileset's `bookcase` run carry the measured pane RELIEF on
--- its front (a tileset entry's bookcase_relief)?  Default yes: the class
--- almost always collapses a shelf, a rack or a display case, and every
--- one of those seals its contents behind a frame that should stand proud
--- of them.
---
--- A tileset says `bookcase_relief = false` when it borrows the collapse
--- for something that is NOT a shelf -- the League's gate walls and
--- pilasters, Bill's transporter drums -- where the drawing's light
--- regions are the masonry and the barrel, not panes, and sinking them
--- carves the surface instead of describing it.
function TileShape.bookcaseRelief(tilesetId)
  local s = load()
  local entry = s and s.tilesets and s.tilesets[tilesetId]
  return not (entry and entry.bookcase_relief == false)
end

-- Drop the cache: a mod that shadows data/voxel_heights.lua or a tileset
-- record needs the next lookup to re-resolve (hot reload, mod toggle).
function TileShape.invalidate()
  elevationCache = setmetatable({}, { __mode = 'k' })
  spec = nil
  cache = {}
  sealCache = setmetatable({}, { __mode = "k" })
  figCache = {}
  mntCache = {}
  bgCache = {}
end

return TileShape
