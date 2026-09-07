-- Smooth HP chase for VASC's Gen-2 ORAS battle HUD.
--
-- Crystal's native HUD is 48 pixels wide and therefore advances large HP
-- totals in ceil(maxHP / 48) integer chunks.  The shared ORAS card is almost
-- three times wider, so those cartridge-sized chunks visibly jump and can
-- appear to pause at the end.  Keep BattleState's one authoritative hpAnim
-- loop, queue hold and target; only choose a presentation step suited to the
-- wider card while that exact VASC controller owns the battle.

local V = ...
local HpPresentation = {
  installed=false,
  ticks=0,
  lastError=nil,
}

-- 72 updates keeps a full high-level bar under roughly 1.2 seconds at 60 Hz,
-- while small early-game totals retain Crystal's exact one-HP-per-update pace.
local CHASE_UPDATES = 72

local function controllerOwns(screen)
  local controller = type(V) == "table" and V.BattleControllerUI or nil
  if type(controller) ~= "table" and type(V) == "table"
      and type(V.require) == "function" then
    local ok, value = pcall(V.require, "BattleControllerUI")
    if ok then controller = value end
  end
  if type(controller) ~= "table" or type(controller.owns) ~= "function" then
    return false
  end
  local ok, owns = pcall(controller.owns, screen)
  return ok and owns == true
end

local function activeMon(screen, side)
  if type(screen.activeMon) == "function" then
    local ok, mon = pcall(screen.activeMon, screen, side)
    if ok and type(mon) == "table" then return mon end
  end
  local shown = type(screen.shownMon) == "table" and screen.shownMon[side]
  if type(shown) == "table" then return shown end
  local battle = type(screen.battle) == "table" and screen.battle or nil
  return battle and battle[side] or nil
end

local function maxHpFor(screen, side)
  local mon = activeMon(screen, side)
  return math.max(1, tonumber(mon and (mon.maxHp
    or (type(mon.stats) == "table" and mon.stats.hp))) or 1)
end

local function smoothStep(screen)
  local anim = screen.hpAnim
  if type(anim) ~= "table" or type(screen.shownHp) ~= "table" then
    return false
  end
  local side = anim.side
  local shown = tonumber(screen.shownHp[side]) or 0
  local target = tonumber(anim.to) or 0
  local step = math.max(1, maxHpFor(screen, side) / CHASE_UPDATES)
  if shown < target then
    shown = math.min(target, shown + step)
  else
    shown = math.max(target, shown - step)
  end
  -- Clamp exactly to the native target.  This both clears hpAnim on the final
  -- visible frame and prevents a floating-point tail from holding the queue.
  if math.abs(shown - target) < 0.000001 then shown = target end
  screen.shownHp[side] = shown
  if shown == target then screen.hpAnim = nil end
  HpPresentation.ticks = HpPresentation.ticks + 1
  HpPresentation.lastTick = {
    side=side, shown=shown, target=target, step=step,
  }
  return true
end

function HpPresentation.install()
  local okState, BattleState = pcall(require, "src.ui.gen2.BattleState")
  if not (okState and type(BattleState) == "table"
      and type(BattleState.stepHpAnim) == "function") then
    HpPresentation.lastError = "src.ui.gen2.BattleState.stepHpAnim unavailable"
    return false, HpPresentation.lastError
  end
  if BattleState._vascOrasHpPresentation then
    HpPresentation.installed = true
    return true
  end

  local nativeStep = BattleState.stepHpAnim
  BattleState.stepHpAnim = function(self, ...)
    if controllerOwns(self) and type(self.hpAnim) == "table" then
      return smoothStep(self)
    end
    return nativeStep(self, ...)
  end
  BattleState._vascOrasHpPresentation = true
  HpPresentation.installed = true
  HpPresentation.lastError = nil
  return true
end

function HpPresentation.status()
  local last = HpPresentation.lastTick
  return {
    installed=HpPresentation.installed,
    ticks=HpPresentation.ticks,
    lastError=HpPresentation.lastError,
    chaseUpdates=CHASE_UPDATES,
    lastTick=last and {
      side=last.side, shown=last.shown, target=last.target, step=last.step,
    } or nil,
    owner="native-hpAnim/oras-wide-step",
  }
end

HpPresentation.stepForQa = smoothStep
HpPresentation.chaseUpdates = CHASE_UPDATES

return HpPresentation
