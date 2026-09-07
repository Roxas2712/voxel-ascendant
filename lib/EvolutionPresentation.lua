-- Clean Gen-1 EvolutionState composition above a retained wide VASC battle.
--
-- EvolutionState intentionally clears only the classic top 160x96 area so
-- its native "is evolving" TextBox remains visible below.  During a wide
-- battle the engine centers that classic overlay, leaving the battle/HUD in
-- both side margins.  Paint only those margins; evolution rules, timing,
-- cancellation, sprites and stack ownership stay engine-owned.

local M = {
  apiVersion = 1,
  schema = "voxel-ascendant/gen1-evolution-wide-backdrop/v1",
}

local installed = false
local eventUnregister

local function evolutionClass()
  local ok, value = pcall(require, "src.ui.EvolutionState")
  return ok and type(value) == "table" and value or nil
end

function M.isEvolutionState(state)
  local class = evolutionClass()
  if not class or type(state) ~= "table" then return false end
  local mt = getmetatable(state)
  return mt == class or type(mt) == "table" and rawget(mt, "__index") == class
end

local function uiWidth()
  local ok, Renderer = pcall(require, "src.render.Renderer")
  if not ok or type(Renderer) ~= "table"
      or type(Renderer.uiSize) ~= "function" then return 160 end
  local sized, width = pcall(Renderer.uiSize, Renderer)
  return sized and tonumber(width) or 160
end

local function drawWideMargins()
  local width = uiWidth()
  local offset = math.max(0, math.floor((width - 160) / 2))
  if offset == 0 then return false end
  local g = love and love.graphics
  if not (g and type(g.setColor) == "function"
      and type(g.rectangle) == "function") then return false end
  g.setColor(1, 1, 1, 1)
  -- Game has already translated the classic state by +offset.
  g.rectangle("fill", -offset, 0, offset, 144)
  g.rectangle("fill", 160, 0, width - 160 - offset, 144)
  return true
end

function M.decorate(state)
  if not M.isEvolutionState(state) then return state, false, "not-evolution" end
  if state.__vascEvolutionPresentation then
    return state, false, "already-decorated"
  end
  local draw = state.draw
  if type(draw) ~= "function" then return state, false, "not-drawable" end
  state.__vascEvolutionPresentation = true
  state.__vascEvolutionPresentationSchema = M.schema
  state.__vascEvolutionPresentationOriginalDraw = draw
  state.draw = function(self, ...)
    self.__vascEvolutionWideMarginsDrawn = drawWideMargins() or nil
    return draw(self, ...)
  end
  return state, true
end

function M.install(mod)
  if installed then return true end
  if not (type(mod) == "table" and mod.events
      and type(mod.events.on) == "function") then
    return false, "screen-events-unavailable"
  end
  local ok, token = pcall(mod.events.on, mod.events,
    "screen.pushed", function(event)
    local state = type(event) == "table" and event.state or nil
    local ok, result, decorated = pcall(M.decorate, state)
    if not ok and mod.log and type(mod.log.warn) == "function" then
      pcall(mod.log.warn, mod.log,
        "VASC Evolution presentation failed open: %s", tostring(result))
    end
  end)
  if not ok then return false, tostring(token) end
  eventUnregister = token
  installed = true
  return true
end

function M.health()
  return {
    schema=M.schema,
    ok=installed,
    state=installed and "active" or "inactive",
    eventRegistered=installed,
    removable=type(eventUnregister) == "function",
  }
end

function M.deactivate()
  if not installed then return true end
  if type(eventUnregister) ~= "function" then
    return false, "screen-event-not-removable"
  end
  local ok, reason = pcall(eventUnregister)
  if not ok then return false, tostring(reason) end
  eventUnregister = nil
  installed = false
  return true
end

return M
