-- Johto-private bridge from Crystal's real BattleState/AnimRunner presentation
-- seam to VASC's imported full-colour move sheets.  Native Gen-2 animation
-- timing, sounds, damage, menus and after-animation chains remain authoritative;
-- this bridge adds only a visual overlay and never imports a Kanto module.

local V = ...
local Bridge = {
  installed=false, starts=0, draws=0, projectedDraws=0,
  lastMove=nil, lastError=nil, lastProjection=nil,
}
local GB_W, GB_H = 160, 144
local unpackValues = (table and table.unpack) or unpack
local function packValues(...)
  return { n=select("#", ...), ... }
end

local function playerModule()
  if type(V) ~= "table" or type(V.require) ~= "function" then return nil end
  local ok, player = pcall(V.require, "VascBattleAnimPlayer")
  return ok and player or nil
end

local function releaseOverlay(screen)
  local overlay = screen and screen._vascMoveAnim
  if overlay and type(overlay.release) == "function" then
    pcall(overlay.release, overlay)
  end
  if screen then screen._vascMoveAnim = nil end
end

local function finite(value)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge
      or value == -math.huge then return nil end
  return value
end

local function visualPoint(visual, kind, sx, sy)
  local hull = type(visual) == "table" and visual.hull or nil
  local head = type(visual) == "table" and visual.head or nil
  local foot = type(visual) == "table" and visual.foot or nil
  if not (type(hull) == "table" and finite(hull[1])
      and finite(hull[2]) and finite(hull[3]) and finite(hull[4])) then
    return nil
  end
  local left, top = hull[1] * sx, hull[2] * sy
  local width, height = hull[3] * sx, hull[4] * sy
  local x = type(head) == "table" and finite(head.x) and head.x * sx
    or left + width * .5
  local headY = type(head) == "table" and finite(head.y) and head.y * sy
    or top
  local footY = type(foot) == "table" and finite(foot.y) and foot.y * sy
    or top + height
  if footY < headY then headY, footY = footY, headY end
  local inkHeight = math.max(1, footY - headY)
  if kind == "emitter" then
    -- Mouth/face-height origin.  Species-specific author anchors can replace
    -- this later, but this live ink hull is already markedly more accurate
    -- than the old fixed Gen-1 foot coordinate.
    return { x, headY + inkHeight * .28 }
  end
  return { x, headY + inkHeight * .55 }
end

-- Build a frame-local conversion from the exact final actor pixels back into
-- the 160x144 authoring space used by VASC move programs.  The programs keep
-- their own independent Johto copy; only their two endpoints are supplied by
-- the finished Johto shot.  Global/weather cels retain the centred GB stage.
function Bridge.projectionPlan(shot, targetW, targetH, attackerIsPlayer)
  targetW, targetH = finite(targetW), finite(targetH)
  local sourceW = type(shot) == "table" and finite(shot.pw) or nil
  local sourceH = type(shot) == "table" and finite(shot.ph) or nil
  local visuals = type(shot) == "table" and shot.actorVisuals or nil
  if not (targetW and targetH and targetW > 0 and targetH > 0
      and sourceW and sourceH and sourceW > 0 and sourceH > 0
      and type(visuals) == "table") then return nil end

  local sx, sy = targetW / sourceW, targetH / sourceH
  local pageScale = math.min(targetW / GB_W, targetH / GB_H)
  if not (pageScale > 0) then return nil end
  local offsetX = (targetW - GB_W * pageScale) * .5
  local offsetY = (targetH - GB_H * pageScale) * .5
  local function logical(point)
    return { (point[1] - offsetX) / pageScale,
             (point[2] - offsetY) / pageScale }
  end
  local playerEmitter = visualPoint(visuals.player, "emitter", sx, sy)
  local playerBody = visualPoint(visuals.player, "body", sx, sy)
  local enemyEmitter = visualPoint(visuals.enemy, "emitter", sx, sy)
  local enemyBody = visualPoint(visuals.enemy, "body", sx, sy)
  if not (playerEmitter and playerBody and enemyEmitter and enemyBody) then
    return nil
  end
  local anchors = {
    player={ emitter=logical(playerEmitter), body=logical(playerBody) },
    enemy={ emitter=logical(enemyEmitter), body=logical(enemyBody) },
  }
  local from = attackerIsPlayer and anchors.player.emitter
    or anchors.enemy.emitter
  local to = attackerIsPlayer and anchors.enemy.body or anchors.player.body
  return {
    scale=pageScale, offsetX=offsetX, offsetY=offsetY,
    anchors=anchors, from=from, to=to,
    targetW=targetW, targetH=targetH,
  }
end

-- Draw after GoldComposeBridge has placed the final panorama/voxel canvas and
-- before the ORAS HUD.  Drawing in BattleState.drawSceneBody remains useful
-- for native 2-D presentation, but that canvas is intentionally suppressed by
-- a VASC world battle and cannot be the only custom-animation destination.
function Bridge.drawProjected(screen, shot, targetW, targetH)
  local overlay = type(screen) == "table" and screen._vascMoveAnim or nil
  if not (overlay and overlay.custom == true and not overlay:isDone()) then
    return false, "inactive"
  end
  local plan = Bridge.projectionPlan(
    shot, targetW, targetH, overlay.attackerIsPlayer == true)
  if not plan then
    Bridge.lastError = "final Johto actor projection unavailable"
    return false, Bridge.lastError
  end
  local Player = playerModule()
  local G = love and love.graphics
  if not (Player and type(Player.setFrameAnchors) == "function"
      and type(Player.clearFrameAnchors) == "function"
      and G and type(G.push) == "function" and type(G.pop) == "function"
      and type(G.translate) == "function" and type(G.scale) == "function") then
    Bridge.lastError = "projected Johto animation graphics seam unavailable"
    return false, Bridge.lastError
  end

  local pushed = false
  local ok, visible = xpcall(function()
    local pushOk = pcall(G.push, "all")
    if not pushOk then G.push() end
    pushed = true
    G.translate(plan.offsetX, plan.offsetY)
    G.scale(plan.scale, plan.scale)
    Player.setFrameAnchors(plan.anchors)
    return overlay:drawCustom()
  end, function(err) return tostring(err) end)
  Player.clearFrameAnchors()
  if pushed then pcall(G.pop) end
  if not ok then
    Bridge.lastError = tostring(visible)
    return false, Bridge.lastError
  end
  if visible == false then
    Bridge.lastError = "projected Johto animation drew no usable cel"
    return false, Bridge.lastError
  end
  Bridge.projectedDraws = Bridge.projectedDraws + 1
  Bridge.lastProjection = {
    move=Bridge.lastMove,
    side=overlay.attackerIsPlayer and "player" or "enemy",
    from={ plan.from[1], plan.from[2] },
    to={ plan.to[1], plan.to[2] },
    scale=plan.scale,
  }
  Bridge.lastError = nil
  return true
end

function Bridge.install()
  local okState, BattleState = pcall(require, "src.ui.gen2.BattleState")
  local Player = playerModule()
  if not (okState and type(BattleState) == "table") then
    Bridge.lastError = "src.ui.gen2.BattleState unavailable"
    return false, Bridge.lastError
  end
  if not (Player and type(Player.newGen2Overlay) == "function") then
    Bridge.lastError = "Johto VASC overlay constructor unavailable"
    return false, Bridge.lastError
  end
  if BattleState._vascGen2MoveOverlay then
    Bridge.installed = true
    return true
  end

  local innerAnimForMove = BattleState.animForMove
  local innerUpdate = BattleState.update
  local innerDrawSceneBody = BattleState.drawSceneBody
  if type(innerAnimForMove) ~= "function" or type(innerUpdate) ~= "function"
      or type(innerDrawSceneBody) ~= "function" then
    Bridge.lastError = "Crystal battle animation seams incomplete"
    return false, Bridge.lastError
  end

  BattleState.animForMove = function(self, moveId, side, ...)
    local started = innerAnimForMove(self, moveId, side, ...)
    releaseOverlay(self)
    if started and moveId ~= nil and (side == "player" or side == "enemy") then
      local okOverlay, overlay = pcall(
        Player.newGen2Overlay, moveId, side == "player")
      if okOverlay and overlay then
        self._vascMoveAnim = overlay
        self._vascMoveAnimId = moveId
        self._vascMoveAnimSide = side
        Bridge.starts = Bridge.starts + 1
        Bridge.lastMove = tostring(moveId)
        Bridge.lastError = nil
      elseif not okOverlay then
        Bridge.lastError = tostring(overlay)
      end
    end
    return started
  end

  BattleState.update = function(self, ...)
    local overlay = self and self._vascMoveAnim
    if overlay then
      local okUpdate, updateErr = pcall(overlay.update, overlay)
      if not okUpdate then
        Bridge.lastError = tostring(updateErr)
        releaseOverlay(self)
      elseif overlay:isDone() then
        releaseOverlay(self)
      end
    end
    return innerUpdate(self, ...)
  end

  BattleState.drawSceneBody = function(self, ...)
    local results = packValues(innerDrawSceneBody(self, ...))
    local overlay = self and self._vascMoveAnim
    if overlay and overlay.custom == true and not overlay:isDone() then
      local okDraw, visible = pcall(overlay.drawCustom, overlay)
      if okDraw and visible ~= false then
        Bridge.draws = Bridge.draws + 1
      elseif not okDraw then
        Bridge.lastError = tostring(visible)
        releaseOverlay(self)
      end
    end
    return unpackValues(results, 1, results.n)
  end

  BattleState._vascGen2MoveOverlay = true
  Bridge.installed = true
  Bridge.lastError = nil
  return true
end

function Bridge.status()
  return {
    installed=Bridge.installed,
    starts=Bridge.starts,
    draws=Bridge.draws,
    projectedDraws=Bridge.projectedDraws,
    lastMove=Bridge.lastMove,
    lastError=Bridge.lastError,
    lastProjection=Bridge.lastProjection,
    independent="gen2/lib/Gen2VascBattleAnimations.lua",
  }
end

return Bridge
