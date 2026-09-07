-- Gen-2 capture-ball presentation segment.
--
-- Gen2KascQol continues to own the native item/palette marker seam. This
-- module consumes that marker at BattleAnimView's public object-draw seam and
-- replaces only the four native ball tiles. Native OAM owns trajectory,
-- bounce, catch timing and result; sparkles and impact objects stay native.

local C = ... or {}
local mod = C.mod

local M = {
  installed=false,
  spriteDraws=0,
  lastBallSprite=nil,
  lastError=nil,
}

local BALL_MARKER = "VASC_GEN2_BALL:"
local BALL_SPRITES = {
  POKE_BALL="poke_ball", GREAT_BALL="great_ball",
  ULTRA_BALL="ultra_ball", MASTER_BALL="master_ball",
  PARK_BALL="safari_ball", FAST_BALL="fast_ball",
  LEVEL_BALL="level_ball", LURE_BALL="lure_ball",
  HEAVY_BALL="heavy_ball", LOVE_BALL="love_ball",
  FRIEND_BALL="friend_ball", MOON_BALL="moon_ball",
}
local SHEET_W, SHEET_H = 32, 64
-- The supplied 32px cell has a heavy bright silhouette. Half scale reads as
-- the native 14-16px Gen-2 ball beside the projected battler; 4/7 looked a
-- little oversized even though its mathematical cell bounds still fit.
local SPRITE_SCALE = .45

local function itemForMarker(name)
  if type(name) ~= "string"
      or name:sub(1, #BALL_MARKER) ~= BALL_MARKER then return nil end
  local itemId = name:sub(#BALL_MARKER + 1)
  return BALL_SPRITES[itemId] and itemId or nil
end

local function loadModule(name)
  local ok, value = pcall(require, name)
  if ok and type(value) == "table" then return value end
  return nil, tostring(value or (name .. " unavailable"))
end

function M.install()
  if M.installed then return true end
  local BattleAnimView, loadErr = loadModule("src.ui.gen2.BattleAnimView")
  if not BattleAnimView or type(BattleAnimView.drawObjects) ~= "function" then
    M.lastError = loadErr or "BattleAnimView.drawObjects unavailable"
    return false, M.lastError
  end

  local bridge = rawget(BattleAnimView, "__vascGen2CaptureBallPresentation")
  if type(bridge) ~= "table" then
    bridge = {
      originalDrawObjects=BattleAnimView.drawObjects,
      quads={},
      phaseStarts=setmetatable({}, { __mode="k" }),
    }

    local function imageFor(view, itemId)
      local stem = BALL_SPRITES[itemId]
      if not stem or type(view.image) ~= "function" then return nil end
      local path = mod and mod.path
        and (mod.path .. "/assets/journeys_balls/" .. stem .. ".png")
      if not path then return nil end
      local ok, image = pcall(view.image, view, path)
      return ok and image or nil, path
    end

    local function quadFor(itemId, image)
      local quad = bridge.quads[itemId]
      local G = love and love.graphics
      if not quad and G and type(G.newQuad) == "function" then
        local iw, ih = image:getDimensions()
        quad = G.newQuad(0, 0, SHEET_W, SHEET_H, iw, ih)
        bridge.quads[itemId] = quad
      end
      return quad
    end

    local function captureState(runner)
      local structs = runner and runner.objects and runner.objects.structs
      for _, state in ipairs(type(structs) == "table" and structs or {}) do
        if state and state.index ~= 0
            and (state.func == "BATTLE_ANIM_FUNC_POKEBALL"
              or state.func == "BATTLE_ANIM_FUNC_POKEBALL_BLOCKED") then
          return tonumber(state.jt) or 0
        end
      end
      return 0
    end

    local function drawBall(view, runner, itemId, minX, minY, image, path)
      local G = love and love.graphics
      local quad = image and quadFor(itemId, image)
      if not (quad and G and type(G.draw) == "function") then return false end

      local x, y = minX - 8, minY - 16
      local ticks = math.max(0, tonumber(runner.frames) or 0)
      local state = captureState(runner)
      local phase = bridge.phaseStarts[runner]
      if not phase then
        phase = {}
        bridge.phaseStarts[runner] = phase
      end
      -- State 5 is the native stable ground/shake phase. State 2 still draws
      -- the target into the ball and state 4 is the descending bounce.
      local rawLanded = state >= 5
      local rawCaught = tonumber(runner.var) == 1
        or (runner.stopped == true and runner.keepSprites == true)
      if rawLanded and phase.ground == nil then phase.ground = ticks end
      if rawCaught then phase.caught = true end
      -- BattleState can clear/recycle the native object state while the final
      -- "Gotcha" line is still visible.  Latch the furthest reached phase for
      -- this exact runner so the retained ball cannot jump back into its throw
      -- rotation after a confirmed catch.
      local landed = phase.ground ~= nil
      local caught = phase.caught == true
      local groundTicks = math.max(0, ticks - (phase.ground or ticks))

      local angle, lateral = 0, 0
      if not landed then
        -- Restrained rotation while the engine moves the ball along its arc.
        angle = ticks * .055
      elseif not caught then
        -- Strong, rhythmic 0.6-second ground shake without full rotations.
        local beat = groundTicks * (math.pi * 2 / 36)
        angle = math.sin(beat) * .30
        lateral = math.sin(beat) * 1.75
      end

      if type(G.setColor) == "function" then G.setColor(1, 1, 1, 1) end
      if type(G.push) == "function" then G.push() end
      if type(G.translate) == "function" then
        G.translate(x + 8 + lateral, y + 8)
      end
      if type(G.rotate) == "function" then G.rotate(angle) end
      G.draw(image, quad, -16 * SPRITE_SCALE, -32 * SPRITE_SCALE,
        0, SPRITE_SCALE, SPRITE_SCALE)

      -- No lamp during throw/draw-in/bounce. Blue starts on the ground and
      -- turns white only after the native capture result confirms success.
      local buttonY = 1.5
      if landed and type(G.circle) == "function"
          and type(G.setColor) == "function" then
        G.setColor(.04, .07, .10, 1)
        G.circle("fill", 0, buttonY, 2.5)
        G.setColor(caught and 1 or .08, caught and 1 or .62,
          caught and 1 or 1, 1)
        G.circle("fill", 0, buttonY, 1.8)
        G.setColor(1, 1, 1, caught and .55 or .35)
        G.circle("fill", -.5, buttonY-.5, .43)
      end
      if type(G.pop) == "function" then G.pop() end
      if type(G.setColor) == "function" then G.setColor(1, 1, 1, 1) end

      M.spriteDraws = M.spriteDraws + 1
      M.lastBallSprite = {
        itemId=itemId, path=path, frame=0, x=x, y=y,
        captureState=state, landed=landed, caught=caught,
        angle=angle, lateral=lateral, buttonVisible=landed,
        buttonY=buttonY,
        buttonColor=not landed and "off" or caught and "white" or "blue",
      }
      return true
    end

    local function sameOam(left, right)
      return type(left) == "table" and type(right) == "table"
        and left.x == right.x and left.y == right.y
        and left.tile == right.tile and left.attr == right.attr
    end

    local function retainedBallObject(phase, obj, consumed)
      local signatures = phase and phase.ballOam
      for index, signature in ipairs(type(signatures) == "table"
          and signatures or {}) do
        if not consumed[index] and sameOam(signature, obj) then
          consumed[index] = true
          return true
        end
      end
      return false
    end

    bridge.drawObjects = function(view, runner, battle, ...)
      local oam = type(runner) == "table" and type(runner.oam) == "function"
        and runner:oam() or nil
      local kept, itemId, minX, minY = {}, nil, nil, nil
      local marked = {}
      if type(oam) == "table" then
        for _, obj in ipairs(oam) do
          local ballId = itemForMarker(obj and obj.palette)
          if ballId then
            itemId = itemId or ballId
            minX = math.min(minX or obj.x, obj.x)
            minY = math.min(minY or obj.y, obj.y)
            marked[#marked + 1] = {
              x=obj.x, y=obj.y, tile=obj.tile, attr=obj.attr,
            }
          else
            kept[#kept + 1] = obj
          end
        end
      end
      local phase = type(runner) == "table" and bridge.phaseStarts[runner] or nil
      if itemId and not phase then
        phase = {}
        bridge.phaseStarts[runner] = phase
      end
      if itemId and phase then
        phase.itemId = itemId
        phase.ballOam = marked
      elseif not itemId and phase and phase.itemId
          and runner.stopped == true and runner.keepSprites == true
          and type(oam) == "table" then
        -- Gold's native keepsprites terminal step deliberately repaints every
        -- retained OAM entry with PAL_BATTLE_OB_ENEMY.  The typed marker thus
        -- disappears on the exact frame that confirms a successful catch,
        -- which used to make the native ball reappear and leave our last
        -- status blue. Rebind only the exact OAM tuples previously owned by
        -- this runner; unrelated sparkles/effects remain in the native list.
        kept, minX, minY = {}, nil, nil
        local consumed, recovered = {}, false
        for _, obj in ipairs(oam) do
          if retainedBallObject(phase, obj, consumed) then
            recovered = true
            minX = math.min(minX or obj.x, obj.x)
            minY = math.min(minY or obj.y, obj.y)
          else
            kept[#kept + 1] = obj
          end
        end
        if recovered then itemId = phase.itemId end
      end
      if not itemId then
        return bridge.originalDrawObjects(view, runner, battle, ...)
      end

      -- Asset failure is a strict native fail-open; suppress nothing.
      local image, path = imageFor(view, itemId)
      if not image then
        return bridge.originalDrawObjects(view, runner, battle, ...)
      end
      local proxy = setmetatable({ oam=function() return kept end },
        { __index=runner })
      bridge.originalDrawObjects(view, proxy, battle, ...)
      drawBall(view, runner, itemId, minX, minY, image, path)
    end

    BattleAnimView.drawObjects = bridge.drawObjects
    BattleAnimView.__vascGen2CaptureBallPresentation = bridge
  end

  M.installed = true
  M.lastError = nil
  return true
end

function M.status()
  return {
    installed=M.installed,
    spriteDraws=M.spriteDraws,
    lastBallSprite=M.lastBallSprite,
    nativeTrajectory=true,
    nativeCatchResult=true,
    lastError=M.lastError,
  }
end

return M
