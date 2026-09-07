-- VASC integrated Species Surf Cinematic.
--
-- Internal Gen-1 presentation module for Pokemon Red, Blue and Yellow. The game
-- remains the sole owner of SURF validation, movement, encounters, music and
-- map transitions. While Voxel Ascendant owns the world pass, this module swaps
-- only the render-time surfing sheet for one built from the current player
-- art and the Pokemon that actually used SURF.

local V = ...

local KantoAscendantCompat = V.require
  and V.require("KantoAscendantCompat")
  or { fieldTech = function() return nil end }

local SpeciesSurfCinematic = {
  VERSION = "0.3.1",
}

local installed = false

function SpeciesSurfCinematic.install()
  local mod = V.mod
  if installed then
    local exports = mod.exports and mod.exports.speciesCinematics
    return true, exports and exports.surf
  end
  local GameVersion = require("src.core.GameVersion")
  local edition = GameVersion.get()
  if edition ~= "red" and edition ~= "blue" and edition ~= "yellow" then
    mod.log:info("VASC Species Surf Cinematic: nur fuer Rot, Blau und Gelb")
    return false, "unsupported-edition"
  end

  local Game = require("src.core.Game")
  local OverworldState = require("src.world.OverworldController")
  local Stats = require("src.pokemon.Stats")
  local Pipelines = require("src.render.Pipelines")
  local PaletteFX = require("src.render.PaletteFX")

  local PIPELINE_ID = "voxel"
  local WORLD_DIR = "assets/vasc_runtime/followsprites_runtime"
  local CINEMATIC_DIR = "assets/species_cinematics/directional"
  local NATIONAL_DEX_MAX = 386
  local PIKACHU_DEX = 25
  local RAICHU_DEX = 26
  local GOROCHU_DEX = 1026
  local FIELD_KIT_JETSKI = {
    species = "FIELD_KIT_JETSKI",
    fieldKitJetski = true,
  }
  local MOUNT_FRAMES = 44
  local RECALL_FRAMES = 50
  local MAX_TRANSIENT_DRAW_FAILURES = 3
  -- VASC's world geometry deliberately remains a 16x16 billboard, but its
  -- UVs are normalized from a 16x96 carrier.  A same-ratio 64x384 Canvas is
  -- therefore a four-times-denser texture on that exact card: depth,
  -- occlusion, shadow and reflection stay native while the authored 32/64px
  -- side sprites no longer have to be crushed into a 16px frame.
  local COMPOSITE_CELL = 64
  local COMPOSITE_FRAMES = 6
  local COMPOSITE_HEIGHT = COMPOSITE_CELL * COMPOSITE_FRAMES
  -- Directional 4x4 atlas rows. The six-frame overworld carrier contains
  -- DOWN, UP and canonical LEFT twice; VASC mirrors LEFT for live RIGHT.
  local CINEMATIC_ROW = { down = 0, side = 1, up = 3 }
  local unpackValues = table.unpack or unpack

  local pendingByWorld = setmetatable({}, { __mode = "k" })
  local fieldKitByWorld = setmetatable({}, { __mode = "k" })
  local scopedByWorld = setmetatable({}, { __mode = "k" })
  local armedByWorld = setmetatable({}, { __mode = "k" })
  local activeByWorld = setmetatable({}, { __mode = "k" })
  local suppressedByWorld = setmetatable({}, { __mode = "k" })
  local bundleCache = {}
  local imageCache = {}
  local voxelLevel = 0
  local warnedVoxelOff = false

  local function pack(...)
    return { n = select("#", ...), ... }
  end

  local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
  end

  local function smooth(v)
    v = clamp(v, 0, 1)
    return v * v * (3 - 2 * v)
  end

  local function lerp(a, b, t)
    return a + (b - a) * t
  end

  local function pokemonDef(mon)
    local species = type(mon) == "table" and mon.species or nil
    return species and Game.data and Game.data.pokemon
      and Game.data.pokemon[species] or nil
  end

  local function speciesDex(mon)
    if type(mon) ~= "table" then return nil end
    local def = pokemonDef(mon)
    if type(def) ~= "table" then return nil end
    -- Kanto Ascendant stores several extended species in private runtime
    -- slots.  Their National-Dex artwork identity is exposed separately and
    -- must win over def.dex, otherwise a Hoenn user can display as an
    -- unrelated Kanto/Johto species.
    local artworkDex
    if def.sourceDex ~= nil then
      artworkDex = def.sourceDex
    elseif def.nationalDex ~= nil then
      artworkDex = def.nationalDex
    elseif def.dexNumber ~= nil then
      artworkDex = def.dexNumber
    else
      artworkDex = def.dex ~= nil and def.dex or def.number
    end
    local dex = tonumber(artworkDex)
    if not dex or dex ~= math.floor(dex) then return nil end
    -- Gorochu is KASC's one intentional guest identity beyond the National
    -- Dex catalog.  Require both the species key and #1026 so an unrelated
    -- private runtime slot can never borrow its artwork.
    if mon.species == "GOROCHU" and dex == GOROCHU_DEX then return dex end
    if dex < 1 or dex > NATIONAL_DEX_MAX then return nil end
    return dex
  end

  local function knowsMove(mon, wanted)
    for _, move in ipairs(type(mon) == "table" and mon.moves or {}) do
      local id = type(move) == "table" and (move.id or move.move) or move
      if id == wanted then return true end
    end
    return false
  end

  local function hasType(def, wanted)
    for _, id in ipairs(type(def) == "table" and def.types or {}) do
      if id == wanted then return true end
    end
    return false
  end

  local function isShiny(mon)
    if type(mon) ~= "table" then return false end
    if mon.shiny == true or mon.isShiny == true then return true end
    local ok, shiny = pcall(Stats.isShiny, mon.dvs)
    return ok and shiny == true
  end

  local function spriteKey(mon)
    local dex = speciesDex(mon)
    if not dex then return nil end
    return string.format("%03d-%s", dex,
      isShiny(mon) and "shiny" or "normal")
  end

  local function profileFor(mon)
    local def = pokemonDef(mon) or {}
    local entry = def.dexEntry or {}
    local inches = (tonumber(entry.heightFt) or 0) * 12
      + (tonumber(entry.heightIn) or 0)
    local metres = tonumber(entry.heightM)
      or (inches > 0 and inches * 0.0254 or 1)
    local dex = speciesDex(mon)
    local water = hasType(def, "WATER")
    local mode
    if dex == PIKACHU_DEX then
      -- Surfing Pikachu owns the nose of the board and visibly balances
      -- there; it is not the generic small/non-Water passenger profile.
      mode = "pikachu_board"
    elseif dex == RAICHU_DEX
        or (dex == GOROCHU_DEX and mon.species == "GOROCHU") then
      -- Pikachu keeps the one-off Surfing-Pikachu pose. Its evolutions may
      -- still use SURF, but ride the ordinary shared trainer/Pokemon board.
      mode = "board"
    elseif metres >= 1.35 then
      mode = "mount"
    elseif water then
      mode = "tow"
    else
      mode = "board"
    end
    return { mode = mode, water = water, metres = metres }
  end

  local function voxelUsable()
    local levelOK, level = pcall(Pipelines.level, PIPELINE_ID)
    voxelLevel = levelOK and (tonumber(level) or 0) or 0
    if voxelLevel <= 0 then return false end

    -- Gen1Recomp keeps the selected level after a render callback has thrown,
    -- even though that pipeline is then retired for the rest of the session.
    -- Its update/draw callbacks (including our visible-frame watchdog) will no
    -- longer run in that state. Newer engines expose the authoritative signal;
    -- a missing API deliberately retains compatibility with older releases.
    if type(Pipelines.eligible) == "function" then
      local eligibleOK, eligible = pcall(Pipelines.eligible, PIPELINE_ID)
      if not eligibleOK or eligible ~= true then return false end
    end
    return true
  end

  local function voxelActive()
    if not voxelUsable() then return false end
    -- A positive and eligible VOXEL can still lose the world pass to a
    -- higher-priority renderer in a malformed/third-party configuration. The
    -- cinematic must not take a lock unless its callbacks can actually draw.
    if type(Pipelines.worldPipeline) == "function" then
      local worldOK, id = pcall(Pipelines.worldPipeline)
      return worldOK and id == PIPELINE_ID
    end
    -- Very old engines expose only the persisted level. Keep their former
    -- behavior instead of making the extension depend on a newer API seam.
    return true
  end

  local function stackTop()
    local stack = Game and Game.stack
    if not stack or type(stack.top) ~= "function" then return nil end
    local ok, top = pcall(stack.top, stack)
    return ok and top or nil
  end

  local function surfUser(ow)
    if not ow or type(ow.partyKnows) ~= "function" then return nil end
    local ok, mon = pcall(ow.partyKnows, ow, "SURF")
    return ok and mon or nil
  end

  local function loadImage(rel)
    local path = mod.assets:path(rel)
    local cached = imageCache[rel]
    if cached then return cached, path end
    local ok, image = pcall(love.graphics.newImage, path)
    if not ok or not image then
      return nil
    end
    if image.setFilter then image:setFilter("nearest", "nearest") end
    imageCache[rel] = image
    return image, path
  end

  local function quads(image, cell, count)
    local iw, ih = image:getDimensions()
    local out = {}
    for i = 0, count - 1 do
      local x = (i % math.max(1, math.floor(iw / cell))) * cell
      local y = math.floor(i / math.max(1, math.floor(iw / cell))) * cell
      out[i] = love.graphics.newQuad(x, y, cell, cell, iw, ih)
    end
    return out
  end

  local function newCompositeCanvas()
    if not love.graphics.newCanvas then return nil end
    -- Keep an exact 1:6 UV sheet on HiDPI/mobile. Older LOVE builds that do
    -- not accept settings retain the compatible fallback.
    local ok, canvas = pcall(love.graphics.newCanvas,
      COMPOSITE_CELL, COMPOSITE_HEIGHT,
      { dpiscale = 1 })
    if not ok then
      ok, canvas = pcall(love.graphics.newCanvas,
        COMPOSITE_CELL, COMPOSITE_HEIGHT)
    end
    if not ok or not canvas then return nil end
    if canvas.setFilter then canvas:setFilter("nearest", "nearest") end
    return canvas
  end

  local function attachRenderer(bundle, imagePath)
    local renderer = {
      def = {
        -- Rebound to the current trainer sheet inside buildComposite.  This
        -- initial path is only a safe carrier for the first mesh probe.
        image = imagePath,
        frames = 6,
        walker = true,
        trueColor = true,
        id = "VASC_SPECIES_SURF_" .. bundle.key,
      },
      image = bundle.canvas,
      frames = {},
    }
    for f = 0, COMPOSITE_FRAMES - 1 do
      renderer.frames[f] = love.graphics.newQuad(0, f * COMPOSITE_CELL,
        COMPOSITE_CELL, COMPOSITE_CELL,
        COMPOSITE_CELL, COMPOSITE_HEIGHT)
    end
    function renderer:resolveImage()
      return bundle.canvas
    end
    bundle.renderer = renderer
    return bundle
  end

  local function loadToolBundle(ow)
    local p = ow and ow.player
    local carrier = p and p.surfSprite and p.surfSprite.def
      and p.surfSprite.def.image
    carrier = carrier or (p and p.sprite and p.sprite.def
      and p.sprite.def.image)
    if type(carrier) ~= "string" or carrier == "" then return nil end

    local key = "field-kit"
    local cached = bundleCache[key]
    if cached then
      if cached.renderer then cached.renderer.def.image = carrier end
      return cached
    end
    local canvas = newCompositeCanvas()
    if not canvas then return nil end
    local bundle = {
      key = key,
      canvas = canvas,
      profile = { mode = "field_kit_jetski", water = false, metres = 0 },
      toolUser = true,
    }
    bundleCache[key] = attachRenderer(bundle, carrier)
    return bundle
  end

  local function loadBundle(mon, toolUser, ow)
    if toolUser then return loadToolBundle(ow) end
    local key = spriteKey(mon)
    if not key then return nil end
    if bundleCache[key] then return bundleCache[key] end

    local worldRel = WORLD_DIR .. "/" .. key .. ".png"
    local worldImage, worldPath = loadImage(worldRel)
    if not worldImage then return nil end
    local iw, ih = worldImage:getDimensions()
    if iw ~= 16 or ih < 96 then return nil end

    local cinematicRel = CINEMATIC_DIR .. "/" .. key .. ".png"
    local cinematicImage = loadImage(cinematicRel)
    local cinematicQuads, cinematicCell
    local cinematicMirrorRows
    if cinematicImage then
      local cw, ch = cinematicImage:getDimensions()
      if cw == ch and cw % 4 == 0 then
        cinematicCell = cw / 4
        cinematicQuads = quads(cinematicImage, cinematicCell, 16)
      elseif key:sub(1, 4) == "1026" and cw == 16 and ch == 96 then
        -- KASC authors Gorochu as six Gen1Recomp walker poses rather than a
        -- 4x4 cinematic atlas. Expand those six poses logically, preserving
        -- exact pixels; the authored side pose faces left, so only RIGHT is
        -- mirrored at draw time.
        local frames = {
          [0] = { 0, 3, 0, 3 },
          [1] = { 2, 5, 2, 5 },
          [2] = { 2, 5, 2, 5 },
          [3] = { 1, 4, 1, 4 },
        }
        cinematicCell = 16
        cinematicQuads = {}
        cinematicMirrorRows = { [2] = true }
        for row = 0, 3 do
          for col = 0, 3 do
            local frame = frames[row][col + 1]
            cinematicQuads[row * 4 + col] = love.graphics.newQuad(
              0, frame * 16, 16, 16, cw, ch)
          end
        end
      end
    end
    -- Every packaged species has a cinematic sheet. Treat an absent or
    -- temporarily unreadable one as a failed attempt rather than caching a
    -- permanently reduced world-sprite-only bundle for the whole session.
    if not cinematicQuads then return nil end

    local canvas = newCompositeCanvas()
    if not canvas then return nil end
    local bundle = {
      key = key,
      worldImage = worldImage,
      worldPath = worldPath,
      worldQuads = quads(worldImage, 16, 6),
      cinematicImage = cinematicImage,
      cinematicQuads = cinematicQuads,
      cinematicCell = cinematicCell,
      cinematicMirrorRows = cinematicMirrorRows,
      canvas = canvas,
      profile = profileFor(mon),
    }
    bundleCache[key] = attachRenderer(bundle, worldPath)
    return bundle
  end

  local function acquireLock(ow, shot)
    local p = ow and ow.player
    if not (p and shot) or shot.ownsLock then return end
    if not p.inputLocked then
      p.inputLocked = true
      shot.ownsLock = true
      shot.lockPlayer = p
    end
  end

  local function releaseLock(ow, shot)
    local p = shot and (shot.lockPlayer or (ow and ow.player))
    if shot and shot.ownsLock and p then
      -- Native Fly/Teleport takes ownership of the same Boolean after Surf.
      -- Never clear a newer transition's lock merely because this visual
      -- attachment happened to acquire it first.
      local foreignOwner = ow and (ow.flyAnim or ow.flyArrive
        or ow.transitioning or p.spinning)
      if not foreignOwner then p.inputLocked = false end
      shot.ownsLock = false
    end
  end

  local function abort(ow, suppress)
    local shot = ow and activeByWorld[ow]
    if shot then releaseLock(ow, shot) end
    if ow then
      if suppress and ow.player and ow.player.surfing then
        suppressedByWorld[ow] = true
      end
      pendingByWorld[ow] = nil
      scopedByWorld[ow] = nil
      armedByWorld[ow] = nil
      activeByWorld[ow] = nil
    end
  end

  local function drawFailure(ow, shot)
    if not (ow and shot and activeByWorld[ow] == shot) then return true end
    shot.drawFailures = (tonumber(shot.drawFailures) or 0) + 1
    if shot.drawFailures >= MAX_TRANSIENT_DRAW_FAILURES then
      abort(ow, true)
      return true
    end
    -- Canvas creation, an asset upload and the first world pass can each miss
    -- once while the native white-flash closes the party menu. Keep the exact
    -- armed Surf owner for a bounded clean retry instead of suppressing the
    -- complete crossing after that one transitional frame.
    return false
  end

  local function begin(ow, mon, armed)
    if not (ow and ow.player and mon and voxelActive()) then return nil end
    -- KASC's FIELD KIT deliberately returns a virtual partyKnows result with
    -- no SURF move. It represents the tool, not the lead Pokemon: render the
    -- current trainer driving a compact jet ski rather than inventing a
    -- Pokemon user.
    local toolUser = mon == FIELD_KIT_JETSKI
      or mon.fieldKitJetski == true
      or not knowsMove(mon, "SURF")
    local bundle = loadBundle(mon, toolUser, ow)
    if not bundle then return nil end
    local shot = {
      mon = mon,
      toolUser = toolUser,
      bundle = bundle,
      phase = armed and "mount" or "ride",
      frame = 0,
      renderedSinceUpdate = false,
      originX = ow.player.px,
      originY = ow.player.py,
      waterX = armed and armed.fx or ow.player.cellX,
      waterY = armed and armed.fy or ow.player.cellY,
      mapId = ow.map and ow.map.id,
    }
    activeByWorld[ow] = shot
    if shot.phase == "mount" then acquireLock(ow, shot) end
    return shot
  end

  local function syncWorld(ow)
    local p = ow and ow.player
    if not p then return end
    local shot = activeByWorld[ow]
    if not p.surfing then
      suppressedByWorld[ow] = nil
      -- A failed native attempt must not leak its selected user into the next
      -- unrelated SURF action. While surfing remains active, however, retain
      -- it so a one-off image/canvas failure can retry on the following tick.
      local armed = armedByWorld[ow]
      if not shot and armed and armed.sawSurfing then
        armedByWorld[ow] = nil
      end
    end

    -- Levels, world-pass ownership and renderer eligibility can change while
    -- a transition is on screen. Never leave a visual-only mount/recall lock
    -- behind when VASC cedes or loses the world pipeline.
    if (shot or armedByWorld[ow]) and not voxelActive() then
      if voxelUsable() then
        -- Transitions and an in-flight camera-rung change can temporarily
        -- remove the overworld pass while the selected VOXEL renderer remains
        -- healthy. Keep the exact Field-Kit/Pokemon provenance armed; clearing
        -- it here made a later 3RD frame reconstruct generic native SURF art.
        -- No temporary sprite pointer is installed outside drawWorld. A
        -- mount/recall lock is visual ownership too, so release it while no
        -- Voxel frame can advance; the exact shot/provenance remains bounded
        -- by the existing cold-frame timeout and may resume safely.
        if shot then
          releaseLock(ow, shot)
          shot.worldPassPaused = true
        end
        return
      end
      abort(ow, true)
      return
    end

    if shot and shot.worldPassPaused then
      shot.worldPassPaused = nil
      if shot.phase == "mount" or shot.phase == "recall" then
        acquireLock(ow, shot)
      end
    end

    local currentMapId = ow.map and ow.map.id
    if shot and shot.mapId and currentMapId ~= shot.mapId then
      if shot.phase == "recall" then
        -- A connection-strip landing has rebased both maps' coordinate
        -- systems. Let the native cross-map step finish without drawing a
        -- recall at an obsolete world coordinate.
        abort(ow)
        return
      end
      shot.waterX = p.targetX or p.cellX
      shot.waterY = p.targetY or p.cellY
      shot.mapId = currentMapId
    end

    -- Fly/Dig/Teleport and similar departures own their own presentation.
    -- Dropping the surf attachment here avoids carrying it through a warp.
    if shot and (ow.flyAnim or p.spinning) then
      abort(ow, true)
      return
    end

    if p.surfing then
      if not shot then
        if suppressedByWorld[ow] then return end
        local armed = armedByWorld[ow]
        if armed then armed.sawSurfing = true end
        local mon = armed and armed.mon or surfUser(ow)
        shot = begin(ow, mon, armed)
        if shot and armed then armedByWorld[ow] = nil end
      elseif shot.phase == "recall" then
        releaseLock(ow, shot)
        shot.phase, shot.frame = "mount", 0
        shot.renderedSinceUpdate = false
        acquireLock(ow, shot)
      end
      if shot then
        shot.mapId = ow.map and ow.map.id
        shot.lastX, shot.lastY = p.px, p.py
      end
    elseif shot and shot.phase ~= "recall" then
      shot.phase, shot.frame = "recall", 0
      shot.renderedSinceUpdate = false
      shot.lastX, shot.lastY = p.px, p.py
      -- Keep the Pokemon at the last water footprint while the native
      -- scripted step carries the trainer onto land.
      shot.recallX, shot.recallY = p.px, p.py
      acquireLock(ow, shot)
    end
  end

  local function advance(ow, dt)
    syncWorld(ow)
    local shot = activeByWorld[ow]
    if not shot then return end
    local frames = math.max(0, tonumber(dt) or 0) * 60
    shot.waitFrames = (shot.waitFrames or 0) + frames
    if not shot.renderedSinceUpdate then
      if shot.waitFrames >= 600 then abort(ow, true) end
      return
    end
    shot.renderedSinceUpdate = false
    shot.waitFrames = 0
    -- One long display hitch may catch up a little, but can never skip a
    -- complete visible mount/recall in one rendered image.
    shot.frame = shot.frame + math.min(frames, 3)
    if shot.phase == "mount" and shot.frame >= MOUNT_FRAMES then
      shot.phase, shot.frame = "ride", 0
      releaseLock(ow, shot)
    elseif shot.phase == "recall" and shot.frame >= RECALL_FRAMES then
      abort(ow)
    end
  end

  local function setColor(g, r, gg, b, a)
    g.setColor(r, gg, b, a == nil and 1 or a)
  end

  local function drawFrame(g, image, quad, x, y, scale, alpha)
    if not (image and quad) then return end
    setColor(g, 1, 1, 1, alpha)
    g.draw(image, quad, x, y, 0, scale, scale)
  end

  local function buildComposite(ow, shot, ctx)
    local p, bundle = ow.player, shot.bundle
    local source = p and p.sprite
    if not (source and source.resolveImage and source.frames) then return false end
    if source.def and type(source.def.image) == "string" then
      -- SpriteBillboards needs a real Assets.image path only to build the UV
      -- card. Reuse the already proven trainer carrier; normalized 1:6 UVs
      -- make resolveImage's denser 64x384 Canvas texture-compatible.
      bundle.renderer.def.image = source.def.image
    end
    local okImage, playerImage = pcall(source.resolveImage, source)
    if not okImage or not playerImage then return false end
    local playerColors
    if ctx and type(ctx.spriteColors) == "function"
        and not (source.def and source.def.trueColor) then
      local okColors, colors = pcall(ctx.spriteColors, ow.map)
      if okColors then playerColors = colors end
    end
    local playerShader
    if playerColors and type(PaletteFX.shader) == "function" then
      local okShader, shader = pcall(PaletteFX.shader)
      if okShader and shader then
        local okSend = type(PaletteFX.sendColors) ~= "function"
          or pcall(PaletteFX.sendColors, shader, playerColors)
        if okSend then playerShader = shader end
      end
    end

    local monAlpha = 1
    local boardAlpha = 1
    local seat = 1
    if shot.phase == "mount" then
      monAlpha = smooth((shot.frame - 20) / 18)
      boardAlpha = smooth((shot.frame - 6) / 18)
      seat = smooth((shot.frame - 18) / 18)
    elseif shot.phase == "recall" then
      monAlpha = 1 - smooth((shot.frame - 20) / 18)
      boardAlpha = 1 - smooth((shot.frame - 32) / 14)
    end

    local g = love.graphics
    if not (g.push and g.pop and g.setCanvas and g.clear and g.draw
        and g.origin and g.scale) then
      return false
    end
    local oldCanvas = g.getCanvas and g.getCanvas() or nil
    g.push("all")
    local ok, err = pcall(function()
      g.setCanvas(bundle.canvas)
      -- VASC/Fly may enter this nested draw with a world-card scissor still
      -- active. Canvas clear obeys that inherited rectangle, so reset it
      -- before clearing or stale pixels from an older Surf frame survive.
      if g.setScissor then g.setScissor() end
      g.clear(0, 0, 0, 0)
      if g.setBlendMode then g.setBlendMode("alpha") end
      if g.setShader then g.setShader() end
      -- Author in the familiar 16px world coordinate space while rasterizing
      -- directly into a 4x-density texture. This is one transform, not a
      -- low-resolution intermediate upscale, so every source texel survives.
      g.origin()
      g.scale(COMPOSITE_CELL / 16, COMPOSITE_CELL / 16)
      local function drawPlayer(quad, x, y, scale)
        if playerShader and g.setShader then g.setShader(playerShader) end
        drawFrame(g, playerImage, quad, x, y, scale, 1)
        if playerShader and g.setShader then g.setShader() end
      end
      local cinematicCell = bundle.cinematicCell or 16
      local cinematicCol = math.floor((shot.frame or 0) / 7) % 4
      local function drawPokemon(direction, centerX, bottomY, targetSize, alpha)
        local row = CINEMATIC_ROW[direction] or CINEMATIC_ROW.down
        local quad = bundle.cinematicQuads
          and bundle.cinematicQuads[row * 4 + cinematicCol]
        if not (bundle.cinematicImage and quad) then return end
        local size = targetSize / cinematicCell
        local drawScaleX = size
        local drawX = centerX - targetSize * 0.5
        if bundle.cinematicMirrorRows
            and bundle.cinematicMirrorRows[row] then
          drawScaleX = -size
          drawX = centerX + targetSize * 0.5
        end
        setColor(g, 1, 1, 1, alpha)
        g.draw(bundle.cinematicImage, quad, drawX,
          bottomY - targetSize, 0, drawScaleX, size)
      end
      for f = 0, 5 do
        local y = f * 16
        local moving = f >= 3
        local profile = bundle.profile
        local pose = f % 3
        local direction = pose == 0 and "down"
          or (pose == 1 and "up" or "side")
        -- LOVE's scissor is expressed in physical Canvas pixels and is not
        -- transformed by g.scale, hence the explicit dense coordinates.
        if g.setScissor then
          g.setScissor(0, f * COMPOSITE_CELL,
            COMPOSITE_CELL, COMPOSITE_CELL)
        end

        -- Back wake and flotation surface.  They live in the same card as
        -- the cast, so VASC reflects, shadows and occludes the whole mount.
        setColor(g, 0.82, 0.95, 1, 0.72 * boardAlpha)
        if profile.mode == "field_kit_jetski" and direction ~= "side" then
          local wakeY = direction == "up" and y + 13.25 or y + 4.25
          g.rectangle("fill", moving and 5 or 6, wakeY,
            moving and 6 or 4, moving and 0.75 or 0.5)
          setColor(g, 0.48, 0.83, 0.96, 0.58 * boardAlpha)
          g.rectangle("fill", moving and 6 or 6.5,
            direction == "up" and y + 14.25 or y + 3.5,
            moving and 4 or 3, 0.25)
        else
          g.rectangle("fill", moving and 0 or 2, y + 12.5,
            moving and 16 or 12, moving and 0.75 or 0.5)
          setColor(g, 0.48, 0.83, 0.96, 0.58 * boardAlpha)
          g.rectangle("fill", moving and 8 or 4, y + 13.5,
            moving and 8 or 8, 0.25)
        end
        if profile.mode == "field_kit_jetski" then
          -- Canonically LEFT-facing Field Kit machine. Quarter-unit details
          -- become individual pixels on the dense texture; unlike the former
          -- 16px rectangles, the chine, bow, intake and trim stay readable in
          -- VASC's close camera. RIGHT mirrors this complete machine in VASC.
          if direction == "side" then
            setColor(g, 0.03, 0.16, 0.25, boardAlpha)
            g.rectangle("fill", 1, y + 9, 14, 3.75)
            g.rectangle("fill", 1, y + 7.5, 4.5, 2.25)
            g.rectangle("fill", 3, y + 6.75, 2.75, 1.5)
            g.rectangle("fill", 5, y + 12.5, 8.5, 1)
            setColor(g, 0.12, 0.61, 0.78, boardAlpha)
            g.rectangle("fill", 1.75, y + 9, 11.75, 0.75)
            g.rectangle("fill", 2.5, y + 8.25, 3, 0.5)
            setColor(g, 0.45, 0.87, 0.96, boardAlpha)
            g.rectangle("fill", 2, y + 9, 7.5, 0.25)
            setColor(g, 0.91, 0.20, 0.16, boardAlpha)
            g.rectangle("fill", 4.25, y + 11.25, 7.5, 0.5)
            setColor(g, 0.96, 0.64, 0.18, boardAlpha)
            g.rectangle("fill", 2.25, y + 10.5, 1.25, 0.5)
            setColor(g, 0.05, 0.08, 0.11, boardAlpha)
            g.rectangle("fill", 7, y + 7, 6, 1.75)
            setColor(g, 0.17, 0.22, 0.25, boardAlpha)
            g.rectangle("fill", 7.75, y + 7, 4.5, 0.5)
          else
            -- Front/back Field Kit silhouette. These two authored rows make
            -- north/south movement visible instead of reusing the sideways
            -- machine for every direction.
            setColor(g, 0.03, 0.16, 0.25, boardAlpha)
            g.rectangle("fill", 5, y + 7, 6, 6.5)
            g.rectangle("fill", 4, y + 9.5, 8, 3.25)
            g.rectangle("fill", 5.75, y + 6.25, 4.5, 1.5)
            setColor(g, 0.12, 0.61, 0.78, boardAlpha)
            g.rectangle("fill", 5.5, y + 8, 5, 4.5)
            setColor(g, 0.45, 0.87, 0.96, boardAlpha)
            g.rectangle("fill", 6, y + 8, 4, 0.35)
            setColor(g, 0.91, 0.20, 0.16, boardAlpha)
            g.rectangle("fill", 4.75, y + 11.25, 6.5, 0.6)
            setColor(g, 0.96, 0.64, 0.18, boardAlpha)
            g.rectangle("fill", 7, y + 12.25, 2, 0.55)
          end
        elseif profile.mode ~= "mount" then
          if profile.mode == "pikachu_board" then
            setColor(g, 0.08, 0.43, 0.66, boardAlpha)
          else
            setColor(g, 0.08, 0.34, 0.58, boardAlpha)
          end
          g.rectangle("fill", profile.mode == "pikachu_board" and 0 or 2,
            y + 10, profile.mode == "pikachu_board" and 16 or 12, 2.75)
          if profile.mode == "pikachu_board" then
            setColor(g, 0.66, 0.91, 1, boardAlpha)
          else
            setColor(g, 0.85, 0.94, 0.96, boardAlpha)
          end
          g.rectangle("fill", profile.mode == "pikachu_board" and 1 or 3,
            y + 10, profile.mode == "pikachu_board" and 14 or 10, 0.5)
          setColor(g, 0.03, 0.14, 0.25, boardAlpha)
          g.rectangle("fill", profile.mode == "pikachu_board" and 2 or 4,
            y + 12.75, profile.mode == "pikachu_board" and 12 or 8, 0.5)
        end

        -- The composite itself supplies motion through wake, mount and water
        -- timing. Keep the trainer on the standing DOWN/UP/LEFT poses so Red
        -- does not walk in place while swimming.
        local playerQuad = source.frames[pose] or source.frames[0]
        if profile.mode == "mount" then
          drawPokemon(direction, 7.4, y + 15, 14.2, monAlpha)
          drawPlayer(playerQuad, math.floor(lerp(0, 5, seat) + 0.5),
            y - math.sin(seat * math.pi) * 4,
            lerp(1, 0.64, seat))
        elseif profile.mode == "field_kit_jetski" then
          -- The tool is the SURF user. Keep the live KASC/player skin and
          -- seat that trainer alone behind the jet ski's handlebars.
          local lean = moving and 1 or 0
          local riderX = direction == "side" and (2 + lean) or 2.25
          drawPlayer(playerQuad, riderX,
            y + 1 - math.sin(seat * math.pi) * 4,
            lerp(1, 0.72, seat))
          -- Foreground steering column and handlebar sit over the rider's
          -- lower arm; drawing them last makes the seating pose legible.
          setColor(g, 0.04, 0.07, 0.09, boardAlpha)
          if direction == "side" then
            g.rectangle("fill", 5, y + 5.25, 0.75, 3.75)
            g.rectangle("fill", 3.5, y + 5, 3.25, 0.5)
          else
            g.rectangle("fill", 7.625, y + 5.25, 0.75, 3.25)
            g.rectangle("fill", 5.5, y + 5, 5, 0.5)
          end
          setColor(g, 0.54, 0.84, 0.90, boardAlpha)
          g.rectangle("fill", direction == "side" and 3.75 or 5.75,
            y + 5, 1, 0.25)
        elseif profile.mode == "pikachu_board" then
          -- Surfing Pikachu balances on the nose while the trainer crouches
          -- behind it.  Moving frames alternate the lean and leave yellow
          -- spray sparks, making #025 visibly distinct from generic boarders.
          local lean = moving and (f % 2 == 0 and -1 or 1) or 0
          drawPokemon(direction, 4.6, y + 14 + lean, 9.2, monAlpha)
          drawPlayer(playerQuad, 7,
            y + 2 - math.sin(seat * math.pi) * 4,
            lerp(1, 0.55, seat))
          if moving then
            setColor(g, 1, 0.88, 0.12, 0.9 * monAlpha)
            g.rectangle("fill", 1, y + 13, 2, 1)
            g.rectangle("fill", 13, y + 12, 1, 1)
          end
        elseif profile.mode == "tow" then
          drawPokemon(direction, 4.8, y + 14, 9.6, monAlpha)
          drawPlayer(playerQuad, math.floor(lerp(0, 5, seat) + 0.5),
            y + lerp(0, 1, seat) - math.sin(seat * math.pi) * 4,
            lerp(1, 0.70, seat))
        else
          drawPokemon(direction, 4.9, y + 14, 9.8, monAlpha)
          drawPlayer(playerQuad, math.floor(lerp(0, 6, seat) + 0.5),
            y + lerp(0, 1, seat) - math.sin(seat * math.pi) * 4,
            lerp(1, 0.68, seat))
        end

        setColor(g, 1, 1, 1, 0.86 * boardAlpha)
        if moving then
          g.rectangle("fill", 0, y + 14, 4, 0.5)
          g.rectangle("fill", 12, y + 14, 4, 0.5)
          g.rectangle("fill", 7, y + 15, 2, 0.25)
        else
          g.rectangle("fill", 3, y + 14, 3, 0.5)
          g.rectangle("fill", 10, y + 14, 3, 0.5)
        end
      end
      if g.setScissor then g.setScissor() end
    end)
    -- `setCanvas` and `pop` are independent cleanup obligations. Run both
    -- even when composition threw (or canvas restoration itself fails), then
    -- report the original error first. This is the graphics equivalent of a
    -- finally block and prevents one bad asset from leaking state into Fly.
    local canvasOK, canvasErr
    if oldCanvas then
      canvasOK, canvasErr = pcall(g.setCanvas, oldCanvas)
    else
      canvasOK, canvasErr = pcall(g.setCanvas)
    end
    local popOK, popErr = pcall(g.pop)
    if not ok then error(err, 0) end
    if not canvasOK then error(canvasErr, 0) end
    if not popOK then error(popErr, 0) end
    return true
  end

  local ROW = { down = 0, left = 1, right = 2, up = 3 }

  local function drawBall(g, x, y, scale, alpha)
    setColor(g, 0.16, 0.16, 0.20, alpha)
    g.rectangle("fill", x - 3 * scale, y - 3 * scale, 6 * scale, 6 * scale)
    setColor(g, 0.95, 0.20, 0.20, alpha)
    g.rectangle("fill", x - 2 * scale, y - 2 * scale, 4 * scale, 2 * scale)
    setColor(g, 0.98, 0.98, 0.92, alpha)
    g.rectangle("fill", x - 2 * scale, y, 4 * scale, 2 * scale)
    setColor(g, 0.15, 0.15, 0.18, alpha)
    g.rectangle("fill", x - scale, y - scale, 2 * scale, 2 * scale)
  end

  local function drawSurfFx(ow, shot, project, displayScale, ctx)
    if shot.phase == "ride" then return false end
    local p, bundle = ow.player, shot.bundle
    if not (p and type(project) == "function") then return false end
    local wx, wy
    if shot.phase == "mount" and shot.waterX and shot.waterY then
      wx, wy = shot.waterX * 16 + 8, shot.waterY * 16 + 15
    elseif shot.phase == "recall" and shot.recallX and shot.recallY then
      wx, wy = shot.recallX + 8, shot.recallY + 15
    else
      wx, wy = (p.px or shot.lastX or 0) + 8,
        (p.py or shot.lastY or 0) + 15
    end
    local okProject, sx, sy = pcall(project, wx, wy)
    if not okProject or type(sx) ~= "number" or type(sy) ~= "number" then
      return false
    end
    local aaFactor = 1
    if tonumber(ctx and ctx.scale) and tonumber(displayScale) then
      aaFactor = math.max(1, displayScale / ctx.scale)
    end
    local canvasW, canvasH
    local activeCanvas = love.graphics.getCanvas and love.graphics.getCanvas()
    if activeCanvas and type(activeCanvas.getDimensions) == "function" then
      local okSize, w, h = pcall(activeCanvas.getDimensions, activeCanvas)
      if okSize then canvasW, canvasH = tonumber(w), tonumber(h) end
    elseif activeCanvas and type(activeCanvas.getWidth) == "function"
        and type(activeCanvas.getHeight) == "function" then
      local okW, w = pcall(activeCanvas.getWidth, activeCanvas)
      local okH, h = pcall(activeCanvas.getHeight, activeCanvas)
      if okW and okH then canvasW, canvasH = tonumber(w), tonumber(h) end
    end
    if not (canvasW and canvasH)
        and type(love.graphics.getPixelDimensions) == "function" then
      local okSize, w, h = pcall(love.graphics.getPixelDimensions)
      if okSize then
        canvasW, canvasH = tonumber(w) and w * aaFactor,
          tonumber(h) and h * aaFactor
      end
    end
    canvasW = canvasW
      or (tonumber(ctx and (ctx.width or ctx.w)) or 320) * aaFactor
    canvasH = canvasH
      or (tonumber(ctx and (ctx.height or ctx.h)) or 288) * aaFactor
    local rawScale = tonumber(displayScale) or 1
    local margin = math.max(96, 40 * math.max(rawScale, 0))
    if sx < -margin or sx > canvasW + margin
        or sy < -margin or sy > canvasH + margin then
      return false
    end
    local okPlayer, playerSx, playerSy = pcall(project,
      (p.px or shot.lastX or 0) + 8, (p.py or shot.lastY or 0) + 15)
    if not okPlayer or type(playerSx) ~= "number"
        or type(playerSy) ~= "number" then
      playerSx, playerSy = sx, sy
    end

    local g = love.graphics
    local scale = math.max(0.01, rawScale)
    g.push("all")
    local ok, err = pcall(function()
      if g.setBlendMode then g.setBlendMode("alpha") end
      local f = shot.frame
      local splash = shot.phase == "mount"
        and (1 - smooth((f - 24) / 18))
        or (1 - smooth((f - 10) / 25))
      setColor(g, 0.82, 0.96, 1, 0.8 * splash)
      g.rectangle("fill", sx - 12 * scale, sy - scale, 8 * scale, scale)
      g.rectangle("fill", sx + 4 * scale, sy - scale, 8 * scale, scale)
      g.rectangle("fill", sx - 7 * scale, sy - 4 * scale, 2 * scale, 2 * scale)
      g.rectangle("fill", sx + 6 * scale, sy - 5 * scale, 2 * scale, 2 * scale)

      if shot.toolUser and shot.phase == "recall" then
        local toolAlpha = 1 - smooth((f - 28) / 16)
        -- The Field Kit gets its own machine language rather than borrowing
        -- Pikachu's or another Pokemon's board: hull, nose, accent, saddle
        -- and handlebars form a readable little pixel jet ski.
        setColor(g, 0.03, 0.16, 0.25, toolAlpha)
        g.rectangle("fill", sx - 14 * scale, sy - 4 * scale,
          28 * scale, 6 * scale)
        g.rectangle("fill", sx + 8 * scale, sy - 7 * scale,
          7 * scale, 4 * scale)
        setColor(g, 0.12, 0.61, 0.78, toolAlpha)
        g.rectangle("fill", sx - 11 * scale, sy - 4 * scale,
          22 * scale, scale)
        setColor(g, 0.91, 0.20, 0.16, toolAlpha)
        g.rectangle("fill", sx - 11 * scale, sy, 13 * scale, scale)
        setColor(g, 0.05, 0.08, 0.11, toolAlpha)
        g.rectangle("fill", sx - 8 * scale, sy - 10 * scale,
          11 * scale, 4 * scale)
        g.rectangle("fill", sx + 5 * scale, sy - 13 * scale,
          2 * scale, 9 * scale)
        g.rectangle("fill", sx + 3 * scale, sy - 14 * scale,
          7 * scale, 2 * scale)
      end

      local image, qs = bundle.cinematicImage, bundle.cinematicQuads
      if image and qs and shot.phase == "recall" then
        -- Recall happens after native surfing has already ended, so the dense
        -- world card no longer exists. Keep this one projected exit sprite,
        -- but force a real profile instead of regressing to front/back art.
        local row = p.facing == "right" and ROW.right or ROW.left
        local col = math.floor(f / 7) % 4
        local quad = qs[row * 4 + col]
        local alpha = 1 - smooth((f - 25) / 16)
        local size = lerp(0.72, 0.42, smooth((f - 25) / 16)) * scale
        if alpha > 0.01 then
          if bundle.profile.mode == "pikachu_board" then
            setColor(g, 0.08, 0.43, 0.66, alpha)
            g.rectangle("fill", sx - 13 * scale, sy - 3 * scale,
              26 * scale, 4 * scale)
            setColor(g, 0.66, 0.91, 1, alpha)
            g.rectangle("fill", sx - 9 * scale, sy - 3 * scale,
              18 * scale, scale)
          end
          setColor(g, 1, 1, 1, alpha)
          local cell = bundle.cinematicCell or 32
          local drawScaleX = size
          local drawX = sx - cell * 0.5 * size
          if bundle.cinematicMirrorRows
              and bundle.cinematicMirrorRows[row] then
            drawScaleX = -size
            drawX = sx + cell * 0.5 * size
          end
          g.draw(image, quad, drawX, sy - cell * 0.84 * size,
            0, drawScaleX, size)
        end
      end

      if shot.phase == "recall" and bundle.profile.mode ~= "mount"
          and not shot.toolUser then
        local boardAlpha = 1 - smooth((f - 30) / 14)
        setColor(g, 0.08, 0.34, 0.58, boardAlpha)
        g.rectangle("fill", sx - 12 * scale, sy - 2 * scale,
          24 * scale, 3 * scale)
        setColor(g, 0.88, 0.96, 0.98, boardAlpha)
        g.rectangle("fill", sx - 10 * scale, sy - 2 * scale,
          20 * scale, scale)
      end

      if not shot.toolUser then
        local t, handX, handY, waterX, waterY, bx, by
        handX, handY = playerSx + 7 * scale, playerSy - 15 * scale
        waterX, waterY = sx - 7 * scale, sy - 17 * scale
        if shot.phase == "mount" then
          t = smooth(clamp((f - 1) / 20, 0, 1))
          bx = lerp(handX, waterX, t)
          by = lerp(handY, waterY, t) - math.sin(t * math.pi) * 8 * scale
        else
          local throw = smooth(clamp((f - 12) / 12, 0, 1))
          local back = smooth(clamp((f - 32) / 15, 0, 1))
          if f < 32 then
            bx = lerp(handX, waterX, throw)
            by = lerp(handY, waterY, throw)
              - math.sin(throw * math.pi) * 8 * scale
          else
            bx = lerp(waterX, handX, back)
            by = lerp(waterY, handY, back)
              - math.sin(back * math.pi) * 7 * scale
          end
        end
        if shot.phase == "mount" or f >= 12 then
          drawBall(g, bx, by, math.max(1, math.floor(scale)), 1)
        end
      end
    end)
    g.pop()
    if not ok then error(err, 0) end
    return true
  end

  -- Remember the exact Pokemon whose submenu contains SURF.  The candidate
  -- is accepted only while that same PartyMenu is still at the stack top;
  -- cancelling the submenu can therefore never affect a later quick action.
  mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
    local out = next(game, items, mon, ctx)
    if type(out) ~= "table" or (ctx and ctx.battle) then return out end
    for _, item in ipairs(out) do
      if item.action == "surf" then
        local ow = (ctx and ctx.overworld) or (game and game.overworld)
        if ow then pendingByWorld[ow] = { mon = mon, menu = ctx and ctx.menu } end
        break
      end
    end
    return out
  end)

  -- FIELD KIT is an explicit tool choice. Even when the party happens to
  -- contain a SURF user, choosing that KASC row must show the jet ski rather
  -- than silently falling back to the first Pokemon. Scope a sentinel only
  -- around KASC's public action/menu call; ordinary Pokemon submenu SURF
  -- keeps its selected species cinematic.
  do
    local fieldTech = KantoAscendantCompat.fieldTech(mod)
    if type(fieldTech) == "table" and type(fieldTech.open) == "function"
        and type(fieldTech.activate) == "function"
        and type(fieldTech.useFieldMove) == "function" then
      local function withFieldKit(game, fn, ...)
        local ow = game and game.overworld
        local previous = ow and fieldKitByWorld[ow] or nil
        if ow then fieldKitByWorld[ow] = true end
        local results = pack(pcall(fn, game, ...))
        if ow then fieldKitByWorld[ow] = previous end
        if not results[1] then error(results[2], 0) end
        return unpackValues(results, 2, results.n)
      end

      -- Menu callbacks are `(item, menu, ...)`, not service methods whose
      -- first argument is `game`. Feeding `game` into KASC's onChoose shifted
      -- every argument by one, so the visible FIELD:SURF row never reached
      -- its native action and VASC could only show the pre-existing native
      -- surf card. Keep the same ownership scope without altering the menu's
      -- established calling convention.
      local function withFieldKitMenu(game, fn, ...)
        local ow = game and game.overworld
        local previous = ow and fieldKitByWorld[ow] or nil
        if ow then fieldKitByWorld[ow] = true end
        local results = pack(pcall(fn, ...))
        if ow then fieldKitByWorld[ow] = previous end
        if not results[1] then error(results[2], 0) end
        return unpackValues(results, 2, results.n)
      end

      local bridge = fieldTech.__vascSpeciesSurfFieldKitBridge
      if not bridge then
        bridge = {
          open = fieldTech.open,
          activate = fieldTech.activate,
          useFieldMove = fieldTech.useFieldMove,
        }
        fieldTech.__vascSpeciesSurfFieldKitBridge = bridge

        fieldTech.open = function(game, ...)
          local results = pack(bridge.open(game, ...))
          local provider = bridge.provider
          if provider then provider.wrapMenu(game) end
          return unpackValues(results, 1, results.n)
        end
        fieldTech.activate = function(game, moveId, ...)
          local provider = bridge.provider
          if provider and moveId == "SURF" then
            return provider.withFieldKit(game, bridge.activate, moveId, ...)
          end
          return bridge.activate(game, moveId, ...)
        end
        fieldTech.useFieldMove = function(game, moveId, ...)
          local provider = bridge.provider
          if provider and moveId == "SURF" then
            return provider.withFieldKit(
              game, bridge.useFieldMove, moveId, ...)
          end
          return bridge.useFieldMove(game, moveId, ...)
        end
      end

      bridge.provider = {
        withFieldKit = withFieldKit,
        wrapMenu = function(game)
          local stack = game and game.stack
          local menu = stack and type(stack.top) == "function"
            and stack:top() or nil
          if not (type(menu) == "table" and type(menu.items) == "table"
              and type(menu.onChoose) == "function") then return false end
          local hasSurf = false
          for _, item in ipairs(menu.items) do
            if item and item.toolId == "FIELD:SURF" then
              hasSurf = true
              break
            end
          end
          if not hasSurf then return false end
          if menu.__vascSpeciesSurfFieldKitMenu then return true end
          menu.__vascSpeciesSurfFieldKitMenu = true
          local originalChoose = menu.onChoose
          menu.onChoose = function(item, ...)
            if item and item.value == "SURF" then
              return withFieldKitMenu(game, originalChoose, item, ...)
            end
            return originalChoose(item, ...)
          end
          return true
        end,
      }
    end
  end

  -- A scoped partyKnows bridge lets native trySurf keep its own text and
  -- callbacks while naming the Pokemon selected by the user rather than the
  -- first SURF user in party order.  Outside that one call it is transparent.
  local partyBridge = OverworldState.__vascSpeciesSurfPartyKnowsBridge
  if not partyBridge then
    partyBridge = { original = OverworldState.partyKnows }
    OverworldState.__vascSpeciesSurfPartyKnowsBridge = partyBridge
    OverworldState.partyKnows = function(self, moveId, ...)
      local provider = partyBridge.provider
      local selected = provider and provider.selected(self, moveId) or nil
      if selected then return selected end
      return partyBridge.original(self, moveId, ...)
    end
  end
  partyBridge.provider = {
    selected = function(ow, moveId)
      return moveId == "SURF" and scopedByWorld[ow] or nil
    end,
  }

  -- Wrap the public controller seam once.  Providers are replaceable so F5
  -- reloads do not stack wrappers or retain stale weak tables/input locks.
  local tryBridge = OverworldState.__vascSpeciesSurfTryBridge
  if not tryBridge then
    tryBridge = { original = OverworldState.trySurf }
    OverworldState.__vascSpeciesSurfTryBridge = tryBridge
    OverworldState.trySurf = function(self, fx, fy, ...)
      local provider = tryBridge.provider
      local mon = provider and provider.choose(self) or nil
      local previous = provider and provider.setScoped(self, mon) or nil
      local result = pack(pcall(tryBridge.original, self, fx, fy, ...))
      if provider then provider.restoreScoped(self, previous) end
      if not result[1] then error(result[2], 0) end
      if provider and mon then provider.arm(self, mon, fx, fy) end
      return unpackValues(result, 2, result.n)
    end
  end

  local previousProvider = tryBridge.provider
  if previousProvider and previousProvider.cleanup then
    pcall(previousProvider.cleanup)
  end
  tryBridge.provider = {
    choose = function(ow)
      local candidate = pendingByWorld[ow]
      pendingByWorld[ow] = nil
      if not voxelUsable() then
        if not warnedVoxelOff and mod.log and type(mod.log.warn) == "function" then
          warnedVoxelOff = true
          mod.log:warn(
            "SURFER-Cinematic inaktiv: VOXEL ist AUS oder nicht renderfaehig")
        end
        return nil
      end
      if fieldKitByWorld[ow] then return FIELD_KIT_JETSKI end
      if candidate and candidate.mon and candidate.menu
          and stackTop() == candidate.menu
          and knowsMove(candidate.mon, "SURF") then
        return candidate.mon
      end
      return surfUser(ow)
    end,
    setScoped = function(ow, mon)
      local previous = scopedByWorld[ow]
      -- FIELD KIT owns only VASC's visual choice. Native trySurf must still
      -- resolve its ordinary party Pokemon for engine text/data lookups; the
      -- virtual jet-ski token is armed after that call and never leaks into
      -- the game's partyKnows contract.
      if mon == FIELD_KIT_JETSKI then
        scopedByWorld[ow] = nil
      else
        scopedByWorld[ow] = mon
      end
      return previous
    end,
    restoreScoped = function(ow, previous)
      scopedByWorld[ow] = previous
    end,
    arm = function(ow, mon, fx, fy)
      suppressedByWorld[ow] = nil
      armedByWorld[ow] = { mon = mon, fx = fx, fy = fy }
    end,
    cleanup = function()
      local worlds = {}
      for ow in pairs(activeByWorld) do worlds[#worlds + 1] = ow end
      for _, ow in ipairs(worlds) do abort(ow) end
    end,
  }

  local updateBridge = OverworldState.__vascSpeciesSurfUpdateBridge
  if not updateBridge then
    updateBridge = { original = OverworldState.update }
    OverworldState.__vascSpeciesSurfUpdateBridge = updateBridge
    OverworldState.update = function(self, ...)
      local provider = updateBridge.provider
      local result = pack(pcall(updateBridge.original, self, ...))
      if not result[1] then
        -- Cleanup is best-effort and must never replace the engine-owned
        -- exception. It releases only Surf's own lock/state; native controller
        -- and renderer pointers remain untouched.
        if provider and type(provider.failed) == "function" then
          pcall(provider.failed, self)
        end
        error(result[2], 0)
      end
      if provider and type(provider.sync) == "function" then
        local syncResult = pack(pcall(provider.sync, self))
        if not syncResult[1] then
          if type(provider.failed) == "function" then
            pcall(provider.failed, self)
          end
          error(syncResult[2], 0)
        end
      end
      return unpackValues(result, 2, result.n)
    end
  end
  updateBridge.provider = {
    sync = function(ow)
      syncWorld(ow)
      local shot = activeByWorld[ow]
      if shot and shot.ownsLock and shot.lockPlayer then
        shot.lockPlayer.inputLocked = true
      end
    end,
    failed = function(ow) abort(ow, true) end,
  }

  local registry = mod.content and mod.content.render_pipelines
  local voxel = registry and registry:get(PIPELINE_ID)
  if type(voxel) ~= "table" or type(voxel.drawWorld) ~= "function" then
    tryBridge.provider = nil
    updateBridge.provider = nil
    partyBridge.provider = nil
    mod.log:error("VASC-Pipeline 'voxel' nicht gefunden")
    return false, "voxel-pipeline-unavailable"
  end

  local baseUpdate = voxel.update
  local baseDrawWorld = voxel.drawWorld
  local function drawPredecessor(ctx)
    -- A predecessor owns its own error policy. Re-entering VASC/Fly after an
    -- exception can duplicate controller updates or resume a half-open GPU
    -- scene, so Surf never retries someone else's callback.
    return baseDrawWorld(ctx)
  end
  registry:patch(PIPELINE_ID, {
    update = function(dt, level)
      voxelLevel = tonumber(level) or 0
      local ow = Game and Game.overworld
      if baseUpdate then
        local ok, err = pcall(baseUpdate, dt, level)
        if not ok then
          if ow then abort(ow, true) end
          error(err, 0)
        end
      end
      if ow then
        local advanceOK, advanceError = pcall(advance, ow, dt)
        if not advanceOK then
          -- Surf is presentation-only. A regression in its own timeline must
          -- release ownership without retiring the shared VOXEL/Fly pipeline.
          abort(ow, true)
          mod.log:error("Surf-Cinematic-Update fehlgeschlagen: %s",
            tostring(advanceError))
        end
      end
    end,

    drawWorld = function(ctx)
      local ow = ctx and ctx.state
      if ow then
        local syncOK, syncError = pcall(syncWorld, ow)
        if not syncOK then
          abort(ow, true)
          mod.log:error("Surf-Cinematic-Synchronisierung fehlgeschlagen: %s",
            tostring(syncError))
          return drawPredecessor(ctx)
        end
      end
      local shot = ow and activeByWorld[ow]
      if not (shot and ow.player and voxelActive()) then
        return drawPredecessor(ctx)
      end

      local p = ow.player
      local originalSurfSprite = p.surfSprite
      local originalWalkSprite = p.sprite
      local originalForceVisible = p.__vascSpeciesSurfForceVisible
      local originalDrawFx = ctx.drawFx
      if p.surfing then
        local compositeOK = false
        local okComposite, compositeErr = pcall(function()
          compositeOK = buildComposite(ow, shot, ctx)
        end)
        if not okComposite or not compositeOK then
          drawFailure(ow, shot)
          if not okComposite then
            mod.log:error("Surf-Komposit fehlgeschlagen: %s", tostring(compositeErr))
          end
          return drawPredecessor(ctx)
        end
      end

      if p.surfing then
        p.surfSprite = shot.bundle.renderer
        -- A selected 3RD camera may briefly collapse its boom while it is
        -- recomputed after SURF/zoom changes.  The ordinary camera contract
        -- treats that instant like 1ST and hides the player card; mark this
        -- render-scoped composite so VoxelScene can keep the complete
        -- rider/mount card visible in 3RD without changing genuine 1ST.
        p.__vascSpeciesSurfForceVisible = true
      end

      if type(originalDrawFx) == "function" then
        ctx.drawFx = function(project, displayScale)
          local okNative, nativeErr = pcall(originalDrawFx, project, displayScale)
          if not okNative then error(nativeErr, 0) end
          local okFx, fxErr = pcall(drawSurfFx, ow, shot, project,
            displayScale, ctx)
          if not okFx then
            drawFailure(ow, shot)
            mod.log:error("Surf-Cinematic-Zeichnung fehlgeschlagen: %s",
              tostring(fxErr))
          end
        end
      end

      local ok, canvas = pcall(baseDrawWorld, ctx)
      ctx.drawFx = originalDrawFx
      p.surfSprite = originalSurfSprite
      p.sprite = originalWalkSprite
      p.__vascSpeciesSurfForceVisible = originalForceVisible
      if not ok then
        drawFailure(ow, shot)
        -- This call ran with Surf's temporary card. Swallow exactly this one
        -- frame after restoring every pointer, so Gen1Recomp does not retire
        -- the shared VOXEL pipeline (and Fly with it). A bounded clean retry
        -- may rebuild the Surf card on the next frame; repeated faults suppress
        -- only this crossing.
        mod.log:error("Surf-Renderer verworfen, nativer Fallback fuer diesen Frame: %s",
          tostring(canvas))
        return nil
      end
      if canvas ~= nil and activeByWorld[ow] == shot then
        shot.drawFailures = 0
        shot.renderedSinceUpdate = true
      end
      return canvas
    end,
  })

  mod.exports.speciesCinematics = mod.exports.speciesCinematics or {
    apiVersion = 1,
  }
  local public = {
    active = true,
    version = SpeciesSurfCinematic.VERSION,
    abort = abort,
  }
  public.status = function(ow)
    local shot = ow and activeByWorld[ow]
    return shot and {
      phase = shot.phase,
      frame = shot.frame,
      species = shot.mon and shot.mon.species,
      mode = shot.bundle and shot.bundle.profile.mode,
      shiny = shot.bundle and shot.bundle.key
        and shot.bundle.key:find("shiny", 1, true) ~= nil,
      fieldKit = shot.toolUser == true,
    } or nil
  end
  mod.exports.speciesCinematics.surf = public
  installed = true
  mod.log:info("VASC Species Surf Cinematic fuer Pokemon %s geladen", edition)
  return true, public
end

return SpeciesSurfCinematic
