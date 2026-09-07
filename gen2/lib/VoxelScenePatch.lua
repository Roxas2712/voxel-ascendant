-- Pokemon Stadium Overworld Models: compatibility-first VoxelScene patcher.
--
-- v0.1.16 deliberately avoids a frozen copy of Dramatic Shape's renderer AND
-- avoids matching whole comment-heavy functions.  It reads the VoxelScene.lua
-- that is actually installed and changes three required structural seams:
--   1. posesOf() records the backing entity on each pose,
--   2. drawCast() asks OverworldStadium before drawing the 2D card,
--   3. render() prepares Stadium models immediately after pose capture.
--
-- v0.1.75 also adds best-effort player-card cleanup for red_3d_player: the
-- selector's live mesh replaces the human Gold card, its mesh shadow is added,
-- and the old player-only card ghost/shadow are suppressed when those exact
-- seams exist. Renderer drift in those cosmetic seams never blocks 3D mode.
local V = ...
local M = {}

local function safeLog(mod, level, fmt, ...)
  local log = mod and mod.log
  local fn = log and log[level]
  if type(fn) == "function" then pcall(fn, log, fmt, ...) end
end

local function readInstalled(BaseV, rel)
  local owner = BaseV and BaseV.mod
  if not owner or type(owner.read) ~= "function" then
    return nil, "Dramatic Shape exported library has no owning mod read()"
  end
  local ok, source, err = pcall(owner.read, owner, rel)
  if not ok then return nil, tostring(source) end
  if type(source) ~= "string" then
    return nil, tostring(err or "read returned no source")
  end
  if source:sub(1, 3) == "\239\187\191" then source = source:sub(4) end
  -- Make structural anchors independent of checkout line endings.
  source = source:gsub("\r\n", "\n"):gsub("\r", "\n")
  return source
end

local function countPlain(s, needle)
  local n, at = 0, 1
  while true do
    local a, b = s:find(needle, at, true)
    if not a then return n end
    n, at = n + 1, b + 1
  end
end

local function replaceOnce(s, old, new, label)
  local n = countPlain(s, old)
  if n ~= 1 then
    return nil, ((n == 0 and "missing" or "ambiguous") ..
      " VoxelScene anchor: " .. tostring(label) .. " (" .. tostring(n) .. ")")
  end
  local a, b = s:find(old, 1, true)
  return s:sub(1, a - 1) .. new .. s:sub(b + 1)
end

local function insertAfterOnce(s, needle, text, label)
  local n = countPlain(s, needle)
  if n ~= 1 then
    return nil, ((n == 0 and "missing" or "ambiguous") ..
      " VoxelScene anchor: " .. tostring(label) .. " (" .. tostring(n) .. ")")
  end
  local _, b = s:find(needle, 1, true)
  return s:sub(1, b) .. text .. s:sub(b + 1)
end

local POSES = [====[local function posesOf(state, spriteColors)
  -- Claim Wilds' emergency 2D bodies before its overlay gets a chance to draw
  -- a second copy.  This function is non-throwing in v0.1.16.
  OverworldStadium.safeClaimWilds(state)

  local colors = spriteColors(state.map)
  local posed = {}
  local me = nil

  for gi, g in ipairs(state.ghosts or {}) do
    local npc = g and g.npc
    if npc and type(npc.pose) == "function" then
      local sprite, vx, vy, facing, phase, flip = npc:pose()
      local ghostMap = g.map or state.map
      posed[#posed + 1] = {
        sprite = sprite, px = (vx or npc.px or 0) + (g.ox or 0),
        py = (npc.py or vy or 0) + (g.oy or 0),
        facing = facing, phase = phase, flip = flip,
        gh = groundAt(ghostMap, npc.cellX, npc.cellY),
        lift = (npc.py or vy or 0) - (vy or npc.py or 0),
        colors = spriteColors(ghostMap),
        entity = npc, entityIndex = gi,
        mapId = ghostMap and ghostMap.id,
      }
    end
  end

  for ei, e in ipairs(state.entities or {}) do
    -- Dramatic Shape normally omits the player during Fly because the engine's
    -- 2D Fly overlay draws it separately. Followers EX can turn the PLAYER
    -- entity itself into a Pokemon; in that case keep it in the Stadium cast
    -- even while flyAnim is active. Ordinary human players still follow the
    -- stock skip rule, avoiding a duplicate trainer.
    local playerPokemonDuringFly = e == state.player and type(e) == "table"
      and (e._pokepcAsPokemon == true or e._pokepcControlSpecies ~= nil
           or e.pokepcControlSpecies ~= nil)
    local battleOwnsPlayerTrainer = state._stadiumLiveBattle
      and e == state.player
    if not battleOwnsPlayerTrainer
        and not (state.flyAnim and e == state.player and not playerPokemonDuringFly) then
      local okPose, sprite, vx, vy, facing, phase, flip = false, nil, nil, nil, nil, nil, nil
      if type(e.pose) == "function" then
        okPose, sprite, vx, vy, facing, phase, flip = pcall(e.pose, e)
      end

      if (not okPose or sprite == nil) and OverworldStadium.canRescuePose(e) then
        if type(e.getWorldSprite) == "function" then
          local okSprite, got = pcall(e.getWorldSprite, e)
          if okSprite and got then sprite = got end
        end
        sprite = sprite or e.sprite
        vx = vx or e.px or 0
        vy = vy or e.py or 0
        facing = facing or e.facing or "down"
        phase = phase or e.phase or 0
        flip = flip == true or e.stepFlip == true or e.flip == true
        okPose = true
      end

      -- Preserve Dramatic Shape's normal behavior for an ordinary non-Pokemon
      -- whose pose() genuinely failed.  Stadium compatibility must not hide a
      -- renderer bug elsewhere in the world.
      if not okPose then
        error(sprite or "entity pose failed", 0)
      end

      local px = vx or e.px or 0
      local py = e.py or vy or 0
      local lift = py - (vy or py)
      local cellX, cellY = e.cellX, e.cellY
      if type(cellX) ~= "number" then cellX = math.floor(px / 16) end
      if type(cellY) ~= "number" then cellY = math.floor(py / 16) end
      local okGround, gh = pcall(groundAt, state.map, cellX, cellY)
      if not okGround then gh = 0 end

      -- During a live-world battle, render the trainer beside and slightly
      -- behind their Pokemon instead of leaving the overworld body directly in
      -- the combat line. The underlying Gold player remains at the encounter
      -- coordinate; only this captured visual pose is displaced.
      if e == state.player and state._stadiumLiveBattle then
        local okBattle, OB = pcall(V.require, "OverworldBattle")
        local arena = okBattle and OB and type(OB.arena) == "function" and OB.arena() or nil
        local stand = arena and arena.trainerStand
        if stand then
          px, py = stand[1], stand[2]

          -- IMPORTANT: trainerStand is a presentation-only X/Z offset.  It can
          -- legitimately land over a tree, cliff, roof edge, water lip, or some
          -- other raised voxel even though the REAL Gold player is standing on
          -- ordinary walkable ground.  Sampling groundAt() from trainerStand
          -- therefore hoisted the trainer onto that scenery and made them look
          -- like they were floating higher and higher as the battle camera
          -- exposed the mismatch.
          --
          -- Keep the horizontal battle composition, but pin the trainer's feet
          -- to the ACTUAL encounter/player ground.  arena.trainer is the real
          -- pre-battle player position captured before the visual displacement.
          local groundAnchor = arena.trainer or stand
          local groundCellX = math.floor((tonumber(groundAnchor[1]) or px) / 16)
          local groundCellY = math.floor((tonumber(groundAnchor[2]) or py) / 16)
          local okStandGround, standGh = pcall(groundAt, state.map,
                                                groundCellX, groundCellY)
          if okStandGround then gh = standGh end

          -- Battle trainer placement is static.  Never carry a half-finished
          -- overworld step/ledge-hop lift into the displaced battle pose.
          lift = 0
          cellX, cellY = math.floor(px / 16), math.floor(py / 16)
          -- Face the battle line rather than the trainer's stale overworld facing.
          local mon = arena.player
          local foe = arena.enemy
          if mon and foe then
            local dx, dz = foe[1] - mon[1], foe[2] - mon[2]
            if math.abs(dx) > math.abs(dz) then
              facing = dx > 0 and "right" or "left"
            else
              facing = dz > 0 and "down" or "up"
            end
          end
        end
      end

      posed[#posed + 1] = {
        sprite = sprite, px = px, py = py,
        facing = facing, phase = phase, flip = flip,
        gh = gh, lift = lift, colors = colors,
        entity = e, entityIndex = ei,
        mapId = state.map and state.map.id,
      }
      if e == state.player then
        me = posed[#posed]
        me.isPlayer = true
        if state._stadiumLiveBattle then
          -- Freeze every visual-walk bridge while the battle owns the pose.
          -- Otherwise a movement bit captured on the encounter frame can keep
          -- feeding bob/step animation to external 3D trainer skins.
          me.stadiumBattleGrounded = true
          me.stadiumVisualMoving = false
          me.stadiumVisualAnimDist = 0
        else
          -- Preserve the frame-local free-locomotion bridge from the source
          -- renderer. This POSES template replaces posesOf() wholesale, so
          -- omitting these fields makes both Gold's card and external player
          -- models receive a moving position with a standing pose.
          me.stadiumVisualMoving = state._stadiumFreeMoveActive == true
            and state._stadiumFreeVisualMoving == true
          me.stadiumVisualAnimDist = tonumber(state._stadiumFreeAnimDist) or 0
          if me.stadiumVisualMoving then
            local clock = tonumber(e.animClock) or 0
            local cycle = clock % 16
            me.phase = (cycle >= 4 and cycle < 12) and 1 or 0
            me.flip = math.floor(clock / 16) % 2 == 1
            me.stadiumVisualPhase = me.phase
            me.stadiumVisualFlip = me.flip
          end
        end
      end
    end
  end
  return posed, me
end]====]

-- Find the actual posesOf function by its declaration and its own return. This
-- survives comment changes and additions around the function across releases.
local function patchPoses(source)
  local start = source:find("local function posesOf", 1, true)
  if not start then return nil, "missing VoxelScene posesOf()" end
  local retA, retB = source:find("  return posed, me\nend", start, true)
  if not retA then
    retA, retB = source:find("return posed, me\nend", start, true)
  end
  if not retA then return nil, "could not locate end of VoxelScene posesOf()" end
  return source:sub(1, start - 1) .. POSES .. source:sub(retB + 1)
end

-- Replace only the character loop inside drawCast, leaving every terrain,
-- figure, grass, glass and reflection detail from the installed DS untouched.
local function patchCastLoop(source)
  -- Newer Dramatic Shape releases route character drawing through drawCast().
  -- Patch that seam when present.
  local fn = source:find("local function drawCast", 1, true)
  if fn then
    local a = source:find("  local hideMe = FirstPerson.hidePlayer()", fn, true)
    if not a then
      a = source:find("local hideMe = FirstPerson.hidePlayer()", fn, true)
    end
    if not a then return nil, "missing drawCast player-hide seam" end

    local glass = source:find("  Voxel3D.glass(true)", a, true)
    if not glass then glass = source:find("Voxel3D.glass(true)", a, true) end
    if not glass then return nil, "missing drawCast glass restore seam" end

    local block = [====[  local hideMe = FirstPerson.hidePlayer()
  local player = state and state.player
  if hideMe and player and player.__vascSpeciesSurfForceVisible
      and type(Voxel.isThirdPerson) == "function"
      and Voxel.isThirdPerson(Voxel.level) then
    hideMe = false
  end
  for _, p in ipairs(posed) do
    if not (p.isPlayer and hideMe) and not OverworldStadium.safeShouldHidePose(p) then
      -- The selector's Gold renderer lives on Player, but this standalone voxel
      -- scene bypasses Player:draw().  Give the selected 3D skin first refusal
      -- for the player pose, then Stadium Pokemon, then the stock sprite card.
      local playerSkin = p.isPlayer and OverworldStadium.safeDrawPlayerSkin(p)
      if not playerSkin and not OverworldStadium.safeDraw(p) and p.sprite then
        OverworldStadium.drawStockPlayerCard(
          p, VoxelScene, drawEntity, viewFacing(p))
      end
    end
  end
]====]
    return source:sub(1, a - 1) .. block .. source:sub(glass), "drawCast"
  end

  -- Older/derived forks (notably the 1.0.x renderer family) have no
  -- drawCast() helper. Their final character pass lives directly inside
  -- VoxelScene.render(). Replace ONLY that exact final loop; shadow/signature
  -- loops remain untouched. This keeps the same fork's terrain/camera code.
  local variants = {
[====[  for _, p in ipairs(posed) do
    drawEntity(p.sprite, p.px, p.py, p.facing, p.phase, p.flip, p.gh,
               p.colors, p.lift)
  end
]====],
[====[  for _, p in ipairs(posed) do
    drawEntity(p.sprite, p.px, p.py, p.facing, p.phase, p.flip, p.gh, p.colors, p.lift)
  end
]====],
  }

  local old
  for _, candidate in ipairs(variants) do
    if countPlain(source, candidate) == 1 then
      old = candidate
      break
    end
  end
  if not old then
    return nil, "missing both modern drawCast seam and legacy render character loop"
  end

  local block = [====[  for _, p in ipairs(posed) do
    if not OverworldStadium.safeShouldHidePose(p) then
      local playerSkin = p.isPlayer and OverworldStadium.safeDrawPlayerSkin(p)
      if not playerSkin and not OverworldStadium.safeDraw(p) and p.sprite then
        OverworldStadium.drawStockPlayerCard(
          p, VoxelScene, drawEntity, p.facing)
      end
    end
  end
]====]
  local a, b = source:find(old, 1, true)
  return source:sub(1, a - 1) .. block .. source:sub(b + 1), "legacy-render"
end

local function patchPrepare(source)
  local needle = "  local posed, me = posesOf(state, spriteColors)"
  local n = countPlain(source, needle)
  if n ~= 1 then
    needle = "local posed, me = posesOf(state, spriteColors)"
    n = countPlain(source, needle)
  end
  if n ~= 1 then return nil, "missing/ambiguous render pose-capture seam" end
  local _, b = source:find(needle, 1, true)
  local insertion = [====[
  -- Skin Stadium overworld models once.  Main eye, reflection and shadow
  -- passes consume the prepared geometry.  This call is deliberately safe.
  OverworldStadium.safePrepare(posed)]====]
  return source:sub(1, b) .. insertion .. source:sub(b + 1)
end

-- When the Skin Selector owns the player, suppress Dramatic Shape's two
-- player-only CARD effects as well.  Otherwise the selected 3D mesh is correct
-- in the solid/reflection passes but the original Gold trainer can still flash
-- as the occlusion ghost or leave a second flat shadow under the mesh.
-- These are cosmetic/best-effort seams so renderer drift cannot disable the
-- main compatibility path.
local function patchPlayerSkinCardArtifactsBestEffort(source)
  local ghostPatched = false
  local shadowCardPatched = false

  local ghostOld = [====[  if me and not FirstPerson.hidePlayer() then
    Voxel3D.beginGhost()]====]
  local ghostNew = [====[  if me and not FirstPerson.hidePlayer()
     and not OverworldStadium.safePlayerSkinActive(me) then
    Voxel3D.beginGhost()]====]
  if countPlain(source, ghostOld) == 1 then
    local a, b = source:find(ghostOld, 1, true)
    source = source:sub(1, a - 1) .. ghostNew .. source:sub(b + 1)
    ghostPatched = true
  end

  local fn = source:find("local function castShadows", 1, true)
  if fn then
    local old = [====[    if mesh then
      ShadowMap.draw(mesh, p.sprite:resolveImage(),]====]
    local a, b = source:find(old, fn, true)
    if a then
      local new = [====[    if mesh and not (p.isPlayer and OverworldStadium.safePlayerSkinActive(p)) then
      ShadowMap.draw(mesh, p.sprite:resolveImage(),]====]
      source = source:sub(1, a - 1) .. new .. source:sub(b + 1)
      shadowCardPatched = true
    end
  end

  return source, ghostPatched, shadowCardPatched
end

local function patchShadowBestEffort(source)
  -- Do not make these anchors prerequisites for visible overworld models.
  -- Different Dramatic Shape releases have changed the shadow implementation
  -- several times.  If this seam exists, add real model geometry to the SUN
  -- pass; otherwise the normal DS sprite shadow remains as a harmless fallback.
  local fn = source:find("local function castShadows", 1, true)
  if not fn then return source, false end
  local a, b = source:find("  ShadowMap.sprites(false)", fn, true)
  if not a then a, b = source:find("ShadowMap.sprites(false)", fn, true) end
  if not a then return source, false end
  local insert = [====[
  -- Stadium/selector overworld geometry is outside the sprite-card flag.
  for _, p in ipairs(posed or {}) do
    if p.isPlayer then OverworldStadium.safeCastPlayerSkin(p, ShadowMap) end
    if p.stadiumMon then OverworldStadium.safeCast(p, ShadowMap) end
  end]====]
  return source:sub(1, b) .. insert .. source:sub(b + 1), true
end

function M.install(ds, BaseV, namespace, Stadium)
  local scene = BaseV and BaseV.require and BaseV.require("VoxelScene")
  if type(scene) ~= "table" or type(scene.render) ~= "function" then
    return false, "Dramatic Shape VoxelScene is unavailable"
  end
  if scene._stadiumOverworldStructuralPatch then return true end

  local source, err = readInstalled(BaseV, "lib/VoxelScene.lua")
  if not source then return false, err end

  -- Required bridge and table identity. These are tiny, stable declarations.
  source, err = insertAfterOnce(source,
    'local Pokedex = V.require("Pokedex")',
    '\nlocal OverworldStadium = assert(V.OverworldStadium, "VASC4J: Stadium bridge missing")',
    "Pokedex module bridge")
  if not source then
    -- Some DS revisions do not require Pokedex from VoxelScene. Put the bridge
    -- immediately after the namespace line instead.
    local originalSource = readInstalled(BaseV, "lib/VoxelScene.lua")
    source = originalSource
    source, err = insertAfterOnce(source, "local V = ...",
      '\nlocal OverworldStadium = assert(V.OverworldStadium, "VASC4J: Stadium bridge missing")',
      "namespace module bridge")
    if not source then return false, err end
  end

  source, err = replaceOnce(source, "local VoxelScene = {}",
    'local VoxelScene = assert(V.OriginalVoxelScene, "VASC4J: original VoxelScene missing")',
    "VoxelScene table")
  if not source then return false, err end

  source, err = patchPoses(source)
  if not source then return false, err end
  local castPatchMode
  source, castPatchMode = patchCastLoop(source)
  if not source then return false, castPatchMode end
  source, err = patchPrepare(source)
  if not source then return false, err end

  local playerGhostSuppressed, playerCardShadowSuppressed
  source, playerGhostSuppressed, playerCardShadowSuppressed =
    patchPlayerSkinCardArtifactsBestEffort(source)

  local shadowIntegrated
  source, shadowIntegrated = patchShadowBestEffort(source)

  -- We intentionally do NOT replace scene.render with a global pcall/fallback
  -- anymore.  Every Stadium operation inserted above is non-throwing, so one
  -- broken model falls back to its own sprite instead of disabling every 3D
  -- Pokemon for the rest of the boot.
  namespace.OriginalVoxelScene = scene
  local chunk, compileErr = load(source,
    "@" .. tostring((BaseV and BaseV.path) or "DRAMATIC_SHAPE") ..
    "/lib/VoxelScene.lua+stadium-overworld-v16")
  if not chunk then
    return false, "patched VoxelScene did not compile: " .. tostring(compileErr)
  end

  local original = {
    render = scene.render,
    prefetch = scene.prefetch,
    invalidate = scene.invalidate,
  }
  local ok, returned = pcall(chunk, namespace)
  if not ok then
    scene.render, scene.prefetch, scene.invalidate =
      original.render, original.prefetch, original.invalidate
    return false, "patched VoxelScene failed to initialize: " .. tostring(returned)
  end
  if returned ~= scene or type(scene.render) ~= "function" then
    scene.render, scene.prefetch, scene.invalidate =
      original.render, original.prefetch, original.invalidate
    return false, "patched VoxelScene did not preserve table identity"
  end

  -- Stadium is an overlay on top of the voxel world, never a prerequisite for
  -- the voxel world itself.  If the structural Pokemon patch throws for an
  -- unexpected Gen-2 entity/map, retry that frame with the untouched Gen-2
  -- VoxelScene renderer instead of letting Gen2Recomped retire the entire
  -- `voxel` pipeline and drop back to flat 2D for the rest of the session.
  local patchedRender = scene.render
  local stadiumRenderErrorLogged = false
  local baseRenderErrorLogged = false
  scene.render = function(...)
    local okPatched, out = pcall(patchedRender, ...)
    if okPatched then return out end
    if not stadiumRenderErrorLogged then
      stadiumRenderErrorLogged = true
      safeLog(namespace.mod, "error",
        "Stadium VoxelScene overlay failed; preserving voxel world with the unpatched Gen-2 renderer: %s",
        tostring(out))
    end

    local okBase, baseOut = pcall(original.render, ...)
    if okBase then return baseOut end
    if not baseRenderErrorLogged then
      baseRenderErrorLogged = true
      safeLog(namespace.mod, "error",
        "Base Gen-2 VoxelScene renderer also failed: %s", tostring(baseOut))
    end
    return nil
  end

  scene._stadiumOverworldStructuralPatch = true
  scene._stadiumOverworldDynamicPatch = true
  scene._stadiumOverworldOwnsWildFilter = true
  -- Wilds uses this as the guard around its emergency-2D filter. We claim a
  -- valid Stadium body ourselves, so letting that outer filter run would hide
  -- the entity before posesOf() can see it.
  scene._owwildRenderWrapped = true

  M.shadowIntegrated = shadowIntegrated and true or false
  safeLog(namespace.mod, "info",
    "Stadium overworld structural renderer installed (layout: %s, 3D shadow seam: %s)",
    tostring(castPatchMode or "unknown"), tostring(M.shadowIntegrated))
  return true
end

return M
