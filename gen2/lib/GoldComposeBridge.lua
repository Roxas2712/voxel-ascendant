-- Gold/Silver official render.compose bridge.
--
-- v0.1.74 fixes Gold's START/menu overlay path correctly.  Gen 2 Game2.lua
-- composites the overworld and stack UI into ONE scene canvas; unlike Gen 1,
-- it does not expose a separable worldOverride pass.  A voxel frame therefore
-- has to own the Gold compose window, then re-draw only the live Gold stack on
-- top using the exact transform Game2:drawScene() uses for overworld overlays.
--
-- This keeps the voxel overworld visible while START/dialog/menu overlays are
-- open without painting Gold's already-composited vanilla 2D world back over it.
local mod, VoxelBridge, WildsBridge, PipelineBridge = ...
local BATTLE_PRESENTATION_KEY = "_vascGen2BattlePresentation"
local unpackValues = (table and table.unpack) or unpack

local function packValues(...)
  return { n=select("#", ...), ... }
end

local function markBattlePresentation(screen, kind)
  if type(screen) == "table" then
    screen[BATTLE_PRESENTATION_KEY] = kind
  end
end

local Bridge = {
  installed = false,
  frames = 0,
  worldFrames = 0,
  voxelFrames = 0,
  voxelOverlayFrames = 0,
  goldOverlayRedrawFrames = 0,
  goldOverlayStatesDrawn = 0,
  worldOverrideFrames = 0,
  legacyDirectFrames = 0,
  spriteFallbackFrames = 0,
  wildSpritesDrawn = 0,
  passthroughFrames = 0,
  battleFrames = 0,
  battlePendingFrames = 0,
  battleFallbackFrames = 0,
  pipelineFrames = 0,
  lastVoxelError = nil,
  lastOverlayError = nil,
  lastWildError = nil,
  lastBattleError = nil,
  lastBattleAnimationError = nil,
  composeHeartbeats = 0,
  battleCompositorReady = false,
}

local function resolveGame(host, ctx)
  -- Current Gold passes Game2 itself as the render.compose hook owner.  Prefer
  -- that object whenever generation==2 so its real stack/world are used.
  if type(host) == "table" and host.stack then
    if ctx and tonumber(ctx.generation) == 2 and host.world then return host end
    if host.world or host.overworld then return host end
  end

  -- Compatibility only: older experimental hosts may not pass Game2 directly.
  local ok2, Game2 = pcall(require, "src.core.Game2")
  if ok2 and type(Game2) == "table" and Game2.stack and Game2.world then
    return Game2
  end
  local ok1, Game = pcall(require, "src.core.Game")
  if ok1 and type(Game) == "table" then return Game end
  return nil
end

local function resolveWorld(game, host)
  local world = game and game.world
  if type(world) == "table" and world.map then return world end

  world = game and game.overworld
  if type(world) == "table" and world.map then return world end

  world = host and host.world
  if type(world) == "table" and world.map then return world end

  world = host and host.overworld
  if type(world) == "table" and world.map then return world end

  local api = mod.world
  if api and type(api.overworld) == "function" then
    local ok, publicWorld = pcall(api.overworld, api)
    if ok and type(publicWorld) == "table" and publicWorld.map then return publicWorld end
  end
  return nil
end

local function stackTop(game)
  local stack = game and game.stack
  if not stack or type(stack.top) ~= "function" then return nil end
  local ok, top = pcall(stack.top, stack)
  if ok then return top end
  return nil
end

local function isBattleScreen(screen)
  if type(screen) ~= "table" then return false end
  if VoxelBridge and type(VoxelBridge.isBattleScreen) == "function" then
    local ok, yes = pcall(VoxelBridge.isBattleScreen, screen)
    if ok then return yes == true end
  end
  -- Compatibility with the constructor receipt used by this same VASC
  -- release. Merely carrying `.battle` is intentionally insufficient because
  -- Party/Summary submenus retain that pointer too.
  return rawget(screen, "_vascGen2BattleScreenOwner") == true
end

local function presentationDimensions(ctx)
  local G = love.graphics
  if type(G.getCanvas) == "function" then
    local ok, target = pcall(G.getCanvas)
    if ok and target and type(target.getDimensions) == "function" then
      local tw, th = target:getDimensions()
      if tw and th and tw > 0 and th > 0 then return tw, th end
    end
  end
  -- Game2's physical draw target is expressed in LÖVE units. On HiDPI hosts
  -- pw/ph and getPixelDimensions() are framebuffer pixels and can be 2x the
  -- drawable area, which would crop a full-frame compose. A bound Canvas owns
  -- its exact dimensions above; the physical surface uses ww/wh only.
  local ww, wh = tonumber(ctx and ctx.ww), tonumber(ctx and ctx.wh)
  if ww and wh and ww > 0 and wh > 0 then return ww, wh end
  return G.getDimensions()
end

local function presentationFrameDelta(ctx)
  local dt = tonumber(ctx and (ctx.dt or ctx.frameDt))
  if not dt then
    local timer = love and love.timer
    if timer and type(timer.getDelta) == "function" then
      local ok, value = pcall(timer.getDelta)
      if ok then dt = tonumber(value) end
    end
  end
  -- Older compose hosts expose no timing field. Keep them usable, while the
  -- current engine and LÖVE path always advance the camera with real elapsed
  -- time instead of tying it to the monitor's render frequency.
  if not dt then dt = 1 / 60 end
  return math.max(0, math.min(0.1, dt))
end

local function reset2D(G)
  if type(G.origin) == "function" then pcall(G.origin) end
  if type(G.setShader) == "function" then pcall(G.setShader) end
  if type(G.setScissor) == "function" then pcall(G.setScissor) end
  if type(G.setDepthMode) == "function" then pcall(G.setDepthMode) end
  if type(G.setBlendMode) == "function" then pcall(G.setBlendMode, "alpha") end
  if type(G.setColor) == "function" then pcall(G.setColor, 1, 1, 1, 1) end
end

local function withGraphicsState(fn)
  local G = love.graphics
  local originalPush, originalPop = G.push, G.pop
  if type(originalPush) ~= "function" or type(originalPop) ~= "function" then
    return pcall(fn, G)
  end

  local originalFields = {}
  for key, value in pairs(G) do
    originalFields[key] = { value=value }
  end
  originalFields.push = { value=originalPush }
  originalFields.pop = { value=originalPop }

  local pushed, pushErr = pcall(originalPush, "all")
  if not pushed then
    return false, "graphics guard push failed: " .. tostring(pushErr)
  end

  local depth = 1
  local function trackedPush(...)
    local values = packValues(originalPush(...))
    depth = depth + 1
    return unpackValues(values, 1, values.n)
  end
  local function trackedPop(...)
    if depth <= 1 then
      error("Gen-2 compose renderer crossed its graphics guard", 0)
    end
    local values = packValues(originalPop(...))
    depth = depth - 1
    return unpackValues(values, 1, values.n)
  end

  local installed, installErr = pcall(function()
    G.push = trackedPush
    G.pop = trackedPop
  end)
  if not installed then
    pcall(function()
      G.push = originalPush
      G.pop = originalPop
    end)
    pcall(originalPop)
    return false, "graphics guard install failed: " .. tostring(installErr)
  end

  local results = packValues(pcall(function()
    reset2D(G)
    return fn(G)
  end))

  local restored, restoreErr = pcall(function()
    local repairs = {}
    for key, value in pairs(G) do
      local original = originalFields[key]
      if type(value) == "function"
          and (not original or original.value ~= value) then
        repairs[#repairs + 1] = {
          key=key, value=original and original.value or nil,
        }
      end
    end
    for key, original in pairs(originalFields) do
      if type(original.value) == "function" and G[key] ~= original.value then
        repairs[#repairs + 1] = { key=key, value=original.value }
      end
    end
    for _, repair in ipairs(repairs) do G[repair.key] = repair.value end
  end)

  local cleanupErr
  for _ = 1, depth do
    local ok, reason = pcall(originalPop)
    if not ok then
      cleanupErr = reason
      break
    end
  end
  if not restored or cleanupErr ~= nil then
    local primary = results[1] and nil or results[2]
    local detail = tostring(restoreErr or cleanupErr)
    if primary ~= nil then detail = tostring(primary) .. "; " .. detail end
    return false, "graphics guard cleanup failed: " .. detail
  end
  return unpackValues(results, 1, results.n)
end

local function drawCanvasFull(canvas, ctx)
  if not canvas then return false end
  local G = love.graphics
  local ww, wh = presentationDimensions(ctx)
  local cw, ch = canvas:getDimensions()
  if not (cw and ch and cw > 0 and ch > 0) then return false end
  G.setColor(1, 1, 1, 1)
  G.draw(canvas, 0, 0, 0, ww / cw, wh / ch)
  return true
end

local function installWorldOverride(host, ctx, canvas)
  -- Gen 1 / experimental compatibility only.  Current Gold Game2 deliberately
  -- has no setWorldOverride because worldCanvas and uiCanvas are the same scene.
  local renderer = (ctx and ctx.renderer)
    or (type(host) == "table" and host.setWorldOverride and host)
  if not (renderer and type(renderer.setWorldOverride) == "function") then
    return false
  end
  local ok = pcall(renderer.setWorldOverride, renderer, canvas)
  return ok and renderer.worldOverride ~= nil
end

local function goldOverlayStateCount(game)
  local stack = game and game.stack
  local states = stack and stack.states
  if type(states) ~= "table" or #states == 0 then return 0 end

  local base = 1
  if type(stack.visibleBase) == "function" then
    local ok, value = pcall(stack.visibleBase, stack)
    if ok and tonumber(value) then
      base = math.max(1, math.min(#states, math.floor(tonumber(value))))
    end
  end
  return math.max(0, #states - base + 1)
end

local function drawGoldOverlayStack(game, world, ctx)
  local stack = game and game.stack
  if not stackTop(game) then return true, 0 end
  if not (stack and type(stack.draw) == "function") then
    return false, 0, "Gold stack has no draw()"
  end
  if not (world and type(world.fitScale) == "function") then
    return false, 0, "Gold world has no fitScale()"
  end

  local ww, wh = tonumber(ctx and ctx.ww), tonumber(ctx and ctx.wh)
  if not (ww and wh and ww > 0 and wh > 0) then
    ww, wh = love.graphics.getDimensions()
  end

  local okScale, scale = pcall(world.fitScale, world)
  scale = okScale and tonumber(scale) or nil
  if not (scale and scale > 0) then
    return false, 0, "Gold world fitScale() returned an invalid scale"
  end

  -- Mirror Game2:drawScene's live-overworld overlay branch exactly:
  -- center a 160x144 UI at world:fitScale(), then draw the visible stack.
  local G = love.graphics
  local okDraw, drawn, count, drawErr = withGraphicsState(function()
    G.translate(math.floor((ww - 160 * scale) / 2),
                math.floor((wh - 144 * scale) / 2))
    G.scale(scale, scale)
    stack:draw()
    return true, goldOverlayStateCount(game), nil
  end)
  if not okDraw then return false, 0, tostring(drawn) end
  if not drawn then return false, 0, tostring(drawErr) end
  return true, tonumber(count) or 0
end

local function drawGoldVoxelFrame(canvas, game, world, ctx)
  local ok, result, overlayCount, overlayErr = withGraphicsState(function()
    if not drawCanvasFull(canvas, ctx) then
      return false, 0, "voxel renderer returned an unusable canvas"
    end

    local okOverlay, count, err = drawGoldOverlayStack(game, world, ctx)
    if okOverlay and VoxelBridge and type(VoxelBridge.drawCameraSlider) == "function" then
      -- Android-only camera-mode slider. Drawn after Gold's stack so the
      -- control remains visible over the voxel world, but the slider itself
      -- hides whenever a menu/overlay is on top (its visibility gate lives in
      -- GoldVoxelBridge). Desktop never draws it and keeps F6 instead.
      pcall(VoxelBridge.drawCameraSlider, ctx)
    end
    if not okOverlay then return false, 0, err end
    return true, count, nil
  end)
  if not ok then return false, 0, tostring(result) end
  return result, overlayCount or 0, overlayErr
end

local function drawGoldBattleFrame(shot, ctx, game)
  local canvas = shot and shot.canvas
  local ui = ctx and ctx.sceneCanvas
  if not (canvas and ui) then return false end
  local G = love.graphics
  local controllerUI = mod.exports and mod.exports.battleControllerUI
  local top = stackTop(game)
  local screen = nil
  if VoxelBridge and type(VoxelBridge.battleScreen) == "function" then
    local okLive, live = pcall(VoxelBridge.battleScreen)
    if okLive and type(live) == "table" then screen = live end
  end
  if not screen and isBattleScreen(top) then screen = top end
  local visibleBattle = screen ~= nil and top == screen
  local nativeFallbackScreen = nil
  local nativeFallbackPermanent = false
  local ok, err = withGraphicsState(function()
    if not drawCanvasFull(canvas, ctx) then error("unusable 3D battle canvas") end

    -- Crystal's custom move player originally drew only into Gold's native
    -- 160x144 scene canvas.  ORAS voxel battles intentionally suppress that
    -- canvas, so project the same Johto-owned animation onto the completed
    -- panorama here, before status cards and the command dock are painted.
    local battleAnimations = mod.exports
      and mod.exports.gen2VascBattleAnimations or nil
    local projection = shot
    local projectionReceipt = controllerUI and controllerUI.sceneReceipt
    if type(shot.actorVisuals) ~= "table"
        and type(projectionReceipt) == "table"
        and projectionReceipt.screen == screen
        and projectionReceipt.battle == screen.battle
        and type(projectionReceipt.projection) == "table" then
      projection = projectionReceipt.projection
    end
    if visibleBattle and VoxelBridge
        and type(VoxelBridge.drawCaptureAnimation) == "function" then
      local ww, wh = presentationDimensions(ctx)
      pcall(VoxelBridge.drawCaptureAnimation, screen, projection, ww, wh)
    end
    if visibleBattle and battleAnimations
        and type(battleAnimations.drawProjected) == "function" then
      local ww, wh = presentationDimensions(ctx)
      local okAnim, drawn, animErr = pcall(
        battleAnimations.drawProjected, screen, shot, ww, wh)
      if not okAnim then
        Bridge.lastBattleAnimationError = tostring(drawn)
      elseif drawn == false and animErr ~= "inactive" then
        Bridge.lastBattleAnimationError = tostring(animErr)
      else
        Bridge.lastBattleAnimationError = nil
      end
    end

    -- Ordinary battles may replace only the DRAWING of Gold's native canvas.
    -- The engine remains the input/rules owner; BattleControllerUI is never
    -- installed as an input wrapper. Pushed PARTY screens and all special
    -- battles deliberately fall through to the complete native canvas.
    -- Presentation ownership is exact to one concrete BattleState. A pushed
    -- submenu may expose the same logic battle, and a later encounter may even
    -- reuse that logic table; neither may inherit the old screen's ORAS HUD.
    local owned = false
    local ownershipEvaluated = false
    if visibleBattle and controllerUI and type(controllerUI.owns) == "function" then
      local okOwn, yes = pcall(controllerUI.owns, screen)
      ownershipEvaluated = okOwn
      owned = okOwn and yes == true
    end

    local customDrawn = false
    if owned and controllerUI and type(controllerUI.sceneHasHud) == "function" then
      -- The receipt is exact to this BattleState and this rendered canvas.
      -- A process-global boolean can otherwise leak from the previous frame
      -- or encounter and suppress Gold's canvas even though the current ORAS
      -- HUD was never drawn (or accept the wrong encounter's HUD).
      local okScene, yes = pcall(controllerUI.sceneHasHud, screen, canvas)
      customDrawn = okScene and yes == true
    end
    if owned and not customDrawn and controllerUI then
      -- Compatibility path for a renderer revision that bypasses VoxelScene's
      -- post-weather insertion point. This invokes drawing only. ARENA and
      -- DISCS are rendered by BattleScene instead of VoxelScene, so the HUD
      -- must receive that finished shot's exact actor projection here. Without
      -- it the same head-attached status cards used by MAP fell back to the
      -- semantic top corners even though BattleScene had already published
      -- both rendered actor hulls and heads.
      local draw = controllerUI.drawFull or controllerUI.draw
      if type(draw) == "function" then
        local drawCtx = {}
        for key, value in pairs(ctx or {}) do drawCtx[key] = value end
        -- This compatibility HUD is painted after the scene Canvas has been
        -- presented, so it owns the final LÖVE drawable rather than the
        -- shot/framebuffer coordinate space.  On Retina/iOS, shot.pw/ph can
        -- be twice the final target and previously pushed the HUD off-screen.
        drawCtx.ww, drawCtx.wh = presentationDimensions(ctx)
        -- BattleScene's finished ARENA/DISCS shot owns the pixels, while the
        -- actor projection used by the head-attached HUD is published by the
        -- controller's exact scene receipt.  A shot without actorVisuals is
        -- not a usable projection: passing it here silently sent the player's
        -- status card to the semantic bottom-left fallback on wide screens.
        -- Keep the shot when it really contains actor geometry (MAP and newer
        -- renderers), otherwise use only the receipt for this same live battle.
        local projection = shot
        local receipt = controllerUI.sceneReceipt
        if type(shot.actorVisuals) ~= "table"
            and type(receipt) == "table"
            and receipt.screen == screen
            and receipt.battle == screen.battle
            and type(receipt.projection) == "table"
            and type(receipt.projection.actorVisuals) == "table" then
          projection = receipt.projection
        end
        drawCtx.projection = projection
        local okDraw, yes = pcall(draw, screen, drawCtx)
        customDrawn = okDraw and yes == true
      end
    end

    -- STANDARD HUD is independent from battle architecture: its transparent
    -- native Gold UI overlays the already staged MAP/ARENA/DISCS shot. GAME
    -- DEFAULT never reaches this branch (it has no shot). Special flows,
    -- pushed native screens and ORAS renderer failures still fail open to the
    -- complete cartridge frame.
    if not customDrawn then
      -- Only the exact visible BattleState changes architecture permanently.
      -- A native Party/Summary page above an otherwise healthy voxel battle
      -- must disappear back into that same voxel battle when popped.
      if visibleBattle and shot.nativeHud == true then
        if not drawCanvasFull(ui, ctx) then
          error("unusable native Gen-2 staged HUD canvas")
        end
      elseif visibleBattle then
        nativeFallbackScreen = screen
        -- A same-screen native workflow (four-move replacement, evolution
        -- choice, etc.) is temporary. It may borrow Gold's complete panel for
        -- this frame, but must return to the already healthy voxel encounter
        -- afterwards. Only a missing/broken controller or a failed custom draw
        -- is an architectural failure that permanently latches this battle to
        -- native.
        nativeFallbackPermanent = not (ownershipEvaluated and not owned)
        local ww, wh = presentationDimensions(ctx)
        if not (VoxelBridge
            and type(VoxelBridge.drawNativeBattleFallback) == "function") then
          error("complete native Gen-2 battle redraw is unavailable")
        end
        local redrawn, redrawErr = VoxelBridge.drawNativeBattleFallback(ww, wh)
        if redrawn ~= true then
          error(tostring(redrawErr or "complete native Gen-2 battle redraw declined"))
        end
      elseif not drawCanvasFull(ui, ctx) then
        error("unusable native Gen-2 submenu canvas")
      end
    end
  end)
  if not ok then
    local voxelErr = tostring(err)

    -- A successful shot makes GoldBattleState leave its native 160x144 paper
    -- transparent. If the window-sized voxel/UI composite then fails halfway
    -- through, simply calling the remaining compose chain would put that
    -- transparent canvas over a partial/empty physical frame. Reconstruct the
    -- cartridge fallback explicitly by re-entering Gold's complete battle
    -- renderer with every live-world override suspended. Trainer/Pokemon pics,
    -- background, commands, HUD, dialogue and animations are all restored.
    local okNative, nativeErr = withGraphicsState(function()
      local ww, wh = presentationDimensions(ctx)
      if VoxelBridge and type(VoxelBridge.drawNativeBattleFallback) == "function" then
        local drawn, nativeDrawErr = VoxelBridge.drawNativeBattleFallback(ww, wh)
        if drawn then return end
        error(tostring(nativeDrawErr or "native Gen-2 battle redraw declined"))
      end
      G.setColor(1, 1, 1, 1)
      G.rectangle("fill", 0, 0, ww, wh)
      if not drawCanvasFull(ui, ctx) then error("unusable native Gen-2 battle UI fallback canvas") end
    end)
    if not okNative then
      Bridge.lastBattleError = voxelErr .. "; native fallback: "
        .. tostring(nativeErr)
      return false, nil
    end
    Bridge.lastBattleError = voxelErr
    return true, visibleBattle and screen or nil, true
  end
  Bridge.lastBattleError = nil
  return true, nativeFallbackScreen, nativeFallbackPermanent
end

local function drawPendingBattleCover(ctx)
  local ok, drawn = withGraphicsState(function(G)
    local ww, wh = presentationDimensions(ctx)
    G.setColor(0, 0, 0, 1)
    G.rectangle("fill", 0, 0, ww, wh)
    return true
  end)
  return ok and drawn == true
end

local function composeCore(nextFn, host, ctx)
  Bridge.frames = Bridge.frames + 1

  -- Battle updates must run even though Game2 reports worldActive=false for an
  -- opaque BattleState. All ordinary Gen-2 menus/dialogs keep the engine's
  -- native opacity and composition rules.
  local game = resolveGame(host, ctx)
  local worldActive = ctx and ctx.worldActive == true
  if worldActive then
    local controllerUI = mod.exports and mod.exports.battleControllerUI
    if controllerUI and type(controllerUI.clearSceneHudFlag) == "function" then
      -- A scene receipt belongs to one BattleState/canvas pair. Retire it as
      -- soon as Game2 hands composition back to free roam so diagnostics and
      -- the following encounter cannot observe the previous battle as drawn.
      pcall(controllerUI.clearSceneHudFlag)
    end
  end
  if VoxelBridge and type(VoxelBridge.setGame) == "function" then
    pcall(VoxelBridge.setGame, game)
  end
  local top = stackTop(game)
  local topIsBattle = isBattleScreen(top)
  local boundBattleScreen = nil
  if VoxelBridge and type(VoxelBridge.battleScreen) == "function" then
    local okScreen, value = pcall(VoxelBridge.battleScreen)
    if okScreen and isBattleScreen(value) then boundBattleScreen = value end
  end
  if not worldActive and topIsBattle
      and VoxelBridge and type(VoxelBridge.ensureBattle) == "function" then
    -- The compose callback itself is the authoritative proof that a future
    -- live-world shot can be placed under Gold's canvas. Fast-forward drivers
    -- and very fast devices can push BattleState before any physical draw;
    -- recover that exact screen on this first heartbeat.
    pcall(VoxelBridge.ensureBattle, top)
  end
  local world = resolveWorld(game, host)
  if VoxelBridge and type(VoxelBridge.updateBattle) == "function" then
    local okUpdate, updated, updateErr = pcall(
      VoxelBridge.updateBattle, presentationFrameDelta(ctx),
      boundBattleScreen or (topIsBattle and top or nil))
    if (not okUpdate or updated == false)
        and not worldActive
        and (boundBattleScreen ~= nil or topIsBattle) then
      local reason = okUpdate and updateErr or updated
      local fallbackOwner = boundBattleScreen or top
      if VoxelBridge and type(VoxelBridge.failBattleToNative) == "function" then
        -- updateBattle normally performs this latch itself. Repeating the
        -- exact-owner request is intentionally idempotent and also covers an
        -- exception thrown by an older/custom bridge before it could react.
        pcall(VoxelBridge.failBattleToNative, fallbackOwner, reason)
      end
      Bridge.lastBattleError = tostring(reason or "Gen-2 battle update failed")
      Bridge.battleFallbackFrames = Bridge.battleFallbackFrames + 1
      Bridge.passthroughFrames = Bridge.passthroughFrames + 1
      markBattlePresentation(fallbackOwner, "native")
      -- Do not evaluate battlePending after a failed update. The complete
      -- cartridge renderer owns this very frame, so a preceding cold cover is
      -- the only black frame this encounter can ever have.
      return nextFn(host, ctx)
    end
  end
  if not worldActive and VoxelBridge
     and type(VoxelBridge.battleShot) == "function" then
    local okShot, shot = pcall(VoxelBridge.battleShot)
    if okShot and shot and shot.canvas then
      local handled, nativeFallbackScreen, permanentNative =
        drawGoldBattleFrame(shot, ctx, game)
      if handled then
        -- Preserve the exact target Game2 restored before entering compose.
        -- On desktop that target is the physical surface; Android's optional
        -- whole-frame flip deliberately supplies its own Canvas. Game2 draws
        -- HUD/touch controls onto the same target after a handled compose, so
        -- rebinding nil here would split the frame and let the rotated blit
        -- overwrite those controls.
        if nativeFallbackScreen ~= nil then
          Bridge.battleFallbackFrames = Bridge.battleFallbackFrames + 1
          if permanentNative == true then
            markBattlePresentation(nativeFallbackScreen, "native")
          end
        else
          Bridge.battleFrames = Bridge.battleFrames + 1
          if top == boundBattleScreen then
            markBattlePresentation(boundBattleScreen, "voxel")
          end
        end
        return true
      end
      Bridge.battleFallbackFrames = Bridge.battleFallbackFrames + 1
    end
  end

  if not worldActive and topIsBattle
      and VoxelBridge and type(VoxelBridge.battlePending) == "function" then
    local okPending, pending = pcall(VoxelBridge.battlePending, top)
    if okPending and pending == true and drawPendingBattleCover(ctx) then
      -- A cold BODY/FULL mesh may need several cooperative slices. Keep the
      -- transition's black reveal cover on the physical frame until the exact
      -- BattleState has a complete voxel shot; never expose its native
      -- cartridge canvas for those otherwise-visible first frames.
      Bridge.battlePendingFrames = Bridge.battlePendingFrames + 1
      markBattlePresentation(top, "pending")
      return true
    end
  end

  -- Current desktop Gold renders the voxel world earlier through the official
  -- render_pipelines drawWorld seam. In that case sceneCanvas already contains
  -- the 3D world plus Gold's normal overlay stack; rendering VoxelScene again
  -- here would double the GPU work and can overwrite the pipeline composite.
  -- Older Gold builds never call the drawWorld callback, so this bit stays
  -- false and the long-standing compose renderer below remains the fallback.
  if PipelineBridge and type(PipelineBridge.consumeRenderedFrame) == "function" then
    local okPipeline, rendered = pcall(PipelineBridge.consumeRenderedFrame, ctx, world)
    if okPipeline and rendered then
      Bridge.pipelineFrames = Bridge.pipelineFrames + 1
      Bridge.voxelFrames = Bridge.voxelFrames + 1
      Bridge.lastVoxelError = nil
      if not worldActive and topIsBattle then
        markBattlePresentation(top, "native")
      end
      local result = nextFn(host, ctx)
      if VoxelBridge and type(VoxelBridge.drawCameraSlider) == "function" then
        pcall(VoxelBridge.drawCameraSlider, ctx)
      end
      return result
    end
  end

  -- Game2 marks only its live overworld branch worldActive=true.  Opaque/full-
  -- screen Gold pages are already excluded by Game2 before this hook runs.
  if not worldActive then
    Bridge.passthroughFrames = Bridge.passthroughFrames + 1
    -- This exact BattleState has now reached Gold's native present chain. It
    -- may stay native, but must never be hidden by a later black warm-up cover
    -- and switched to voxel halfway through the same encounter.
    if topIsBattle then
      markBattlePresentation(top, "native")
    end
    return nextFn(host, ctx)
  end

  if not (world and world.map) then
    Bridge.passthroughFrames = Bridge.passthroughFrames + 1
    return nextFn(host, ctx)
  end

  Bridge.worldFrames = Bridge.worldFrames + 1
  local isGold = tonumber(ctx.generation) == 2
  local hasOverlay = stackTop(game) ~= nil

  if VoxelBridge and type(VoxelBridge.renderFrame) == "function" then
    -- Hand the renderer the ACTUAL live Game2 owner. Gold's World is not a
    -- Gen-1 singleton, and first/third-person camera gates/input need the same
    -- stack object whose overlays are composited below.
    local okVoxel, canvas, voxelErr, voxelStatus =
      pcall(VoxelBridge.renderFrame, world, ctx)
    if okVoxel and canvas then
      if isGold then
        -- Gold's sceneCanvas/worldCanvas/uiCanvas are the same finished texture.
        -- Own the compose frame, paint voxels first, then re-draw ONLY the stack
        -- UI at the same transform Game2 uses.  This is the v0.1.74 pause fix.
        local okFrame, overlayCount, overlayErr = drawGoldVoxelFrame(
          canvas, game, world, ctx)
        if okFrame then
          Bridge.voxelFrames = Bridge.voxelFrames + 1
          Bridge.legacyDirectFrames = Bridge.legacyDirectFrames + 1
          if hasOverlay then
            Bridge.voxelOverlayFrames = Bridge.voxelOverlayFrames + 1
            Bridge.goldOverlayRedrawFrames = Bridge.goldOverlayRedrawFrames + 1
            Bridge.goldOverlayStatesDrawn = Bridge.goldOverlayStatesDrawn
              + (tonumber(overlayCount) or 0)
          end
          Bridge.lastVoxelError = nil
          Bridge.lastOverlayError = nil
          return true
        end
        voxelErr = overlayErr or "Gold voxel/UI composite failed"
        Bridge.lastOverlayError = voxelErr
      else
        -- Gen 1 / experimental compatibility path where separate world + UI
        -- passes really do exist.
        if installWorldOverride(host, ctx, canvas) then
          Bridge.voxelFrames = Bridge.voxelFrames + 1
          Bridge.worldOverrideFrames = Bridge.worldOverrideFrames + 1
          if hasOverlay then Bridge.voxelOverlayFrames = Bridge.voxelOverlayFrames + 1 end
          Bridge.lastVoxelError = nil
          return nextFn(host, ctx)
        end
        if not hasOverlay and drawCanvasFull(canvas, ctx) then
          Bridge.voxelFrames = Bridge.voxelFrames + 1
          Bridge.legacyDirectFrames = Bridge.legacyDirectFrames + 1
          Bridge.lastVoxelError = nil
          return true
        end
        voxelErr = hasOverlay
          and "legacy compose API cannot preserve UI over direct voxel canvas"
          or "voxel renderer returned an unusable canvas"
      end
    elseif not okVoxel then
      voxelErr = tostring(canvas)
    end
    -- A cold destination mesh is not permission to expose one native 2D map
    -- frame between two voxel maps. Repaint the preceding complete voxel
    -- canvas only while the renderer explicitly reports a pending warm-up.
    if okVoxel and canvas == nil and voxelStatus == "pending" and isGold
        and type(VoxelBridge.transitionHoldCanvas) == "function" then
      local okHold, held = pcall(VoxelBridge.transitionHoldCanvas, world)
      if okHold and held then
        local okFrame, overlayCount, overlayErr = drawGoldVoxelFrame(
          held, game, world, ctx)
        if okFrame then
          Bridge.voxelFrames = Bridge.voxelFrames + 1
          Bridge.legacyDirectFrames = Bridge.legacyDirectFrames + 1
          if hasOverlay then
            Bridge.voxelOverlayFrames = Bridge.voxelOverlayFrames + 1
            Bridge.goldOverlayRedrawFrames = Bridge.goldOverlayRedrawFrames + 1
            Bridge.goldOverlayStatesDrawn = Bridge.goldOverlayStatesDrawn
              + (tonumber(overlayCount) or 0)
          end
          Bridge.lastVoxelError = nil
          Bridge.lastOverlayError = nil
          return true
        end
        Bridge.lastOverlayError = overlayErr
      end
    end
    Bridge.lastVoxelError = voxelErr
  end

  -- If voxel rendering is unavailable, preserve Gold's already-composited scene
  -- and the existing visible-Wilds sprite fallback behavior.
  local visible = WildsBridge and type(WildsBridge.visibleEntities) == "function"
    and WildsBridge.visibleEntities(world) or {}
  if type(visible) == "table" and #visible > 0
     and ctx.sceneCanvas and WildsBridge
     and type(WildsBridge.drawFallback) == "function" then
    drawCanvasFull(ctx.sceneCanvas, ctx)
    local okWild, drawn, wildErr = pcall(WildsBridge.drawFallback, world)
    if okWild then
      Bridge.spriteFallbackFrames = Bridge.spriteFallbackFrames + 1
      Bridge.wildSpritesDrawn = Bridge.wildSpritesDrawn + (tonumber(drawn) or 0)
      Bridge.lastWildError = wildErr
    else
      Bridge.lastWildError = tostring(drawn)
    end
    return true
  end

  Bridge.passthroughFrames = Bridge.passthroughFrames + 1
  return nextFn(host, ctx)
end

local function isAndroid()
  -- love.system is a blocked proxy member in current mod sandboxes, so even
  -- reading it must be protected. Engine Platform is the authoritative path.
  local okNative, nativeName = pcall(function()
    local sys = love and love.system
    return sys and sys.getOS and sys.getOS()
  end)
  if okNative and (nativeName == "Android" or nativeName == "iOS") then
    return nativeName == "Android"
  end
  local okPlatform, Platform = pcall(require, "src.core.Platform")
  if okPlatform and type(Platform) == "table" and type(Platform.detect) == "function" then
    local okDetect, info = pcall(Platform.detect)
    if okDetect and type(info) == "table" and type(info.os) == "string" then
      return string.lower(info.os) == "android"
    end
  end
  if okNative and type(nativeName) == "string" then
    return string.lower(nativeName) == "android"
  end
  local okGlobal, platform = pcall(rawget, _G, "PLATFORM")
  return okGlobal and type(platform) == "string"
    and string.lower(platform) == "android"
end

local function screenFlipEnabled()
  if not isAndroid() then return false end
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return false end
  local ok, value = pcall(options.get, options, "screenFlip")
  return ok and value == true
end

local flipCanvas, flipW, flipH
local function ensureFlipCanvas(w, h)
  if flipCanvas and flipW == w and flipH == h then return flipCanvas end
  local G = love and love.graphics
  if not (G and type(G.newCanvas) == "function") then return nil end
  local ok, canvas = pcall(G.newCanvas, w, h)
  if not ok or not canvas then return nil end
  flipCanvas, flipW, flipH = canvas, w, h
  if type(canvas.setFilter) == "function" then pcall(canvas.setFilter, canvas, "nearest", "nearest") end
  return canvas
end

-- Screen flip is applied around the *entire* render.compose chain. This makes
-- the setting rotate the finished Android presentation rather than only the
-- voxel world, so Gold menus, Stadium battle HUD and fallback 2D screens all
-- keep the same orientation. It is intentionally a presentation transform:
-- when the physical device itself is held in reverse-landscape, Android's
-- locked coordinate frame already maps touches to the corresponding rotated
-- on-screen controls.
local function compose(nextFn, host, ctx)
  -- v0.2.56: Android screenFlip is owned by AndroidFullFrameFlip around the
  -- entire Game2:draw call.  Keeping a second rotation here would double-flip
  -- the world while leaving Game2's later HUD/touch layer inconsistent.
  Bridge.composeHeartbeats = Bridge.composeHeartbeats + 1
  if not Bridge.battleCompositorReady
      and VoxelBridge and type(VoxelBridge.setBattleCompositorReady) == "function" then
    local ok, ready = pcall(VoxelBridge.setBattleCompositorReady, true)
    Bridge.battleCompositorReady = ok and ready == true
  end
  local result = composeCore(nextFn, host, ctx)
  return result
end

function Bridge.install()
  if Bridge.installed then return true end
  if not (mod.hooks and type(mod.hooks.wrap) == "function") then
    return false, "mod.hooks:wrap is unavailable"
  end
  local ok, err = pcall(function()
    mod.hooks:wrap("render.compose", compose, 1000)
  end)
  if not ok then return false, tostring(err) end
  Bridge.installed = true
  if VoxelBridge and type(VoxelBridge.setBattleCompositorReady) == "function" then
    pcall(VoxelBridge.setBattleCompositorReady, false)
  end
  if mod.log and type(mod.log.info) == "function" then
    pcall(mod.log.info, mod.log,
      "Gold render.compose bridge installed (voxel + Gold overlay-stack redraw)")
  end
  return true
end

function Bridge.status()
  return {
    installed = Bridge.installed,
    frames = Bridge.frames,
    worldFrames = Bridge.worldFrames,
    voxelFrames = Bridge.voxelFrames,
    voxelOverlayFrames = Bridge.voxelOverlayFrames,
    goldOverlayRedrawFrames = Bridge.goldOverlayRedrawFrames,
    goldOverlayStatesDrawn = Bridge.goldOverlayStatesDrawn,
    worldOverrideFrames = Bridge.worldOverrideFrames,
    legacyDirectFrames = Bridge.legacyDirectFrames,
    spriteFallbackFrames = Bridge.spriteFallbackFrames,
    wildSpritesDrawn = Bridge.wildSpritesDrawn,
    battleFrames = Bridge.battleFrames,
    battlePendingFrames = Bridge.battlePendingFrames,
    battleFallbackFrames = Bridge.battleFallbackFrames,
    pipelineFrames = Bridge.pipelineFrames,
    passthroughFrames = Bridge.passthroughFrames,
    lastVoxelError = Bridge.lastVoxelError,
    lastOverlayError = Bridge.lastOverlayError,
    lastWildError = Bridge.lastWildError,
    lastBattleError = Bridge.lastBattleError,
    lastBattleAnimationError = Bridge.lastBattleAnimationError,
    composeHeartbeats = Bridge.composeHeartbeats,
    battleCompositorReady = Bridge.battleCompositorReady,
    flipFrames = Bridge.flipFrames or 0,
    lastFlipError = Bridge.lastFlipError,
  }
end

Bridge._compose = compose
Bridge._withGraphicsState = withGraphicsState
return Bridge
