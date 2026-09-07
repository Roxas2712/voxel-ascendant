-- Small screen-space receipt for VASC shortcut changes.
--
-- The host remains the owner of every shortcut and persisted option. Callers
-- notify this presenter only after an action succeeded; it never consumes
-- input or changes game state. The final Game draw is wrapped once so the
-- notice stays fixed in the upper-left while cameras and worlds move below it.

local M = {
  installed = false,
  shown = 0,
  duration = 1.65,
}

local state = { title = nil, value = nil, started = 0 }
local enabled = function() return true end
local unpackValues = table.unpack or unpack

local function packValues(...)
  return { n = select("#", ...), ... }
end

local function now()
  local timer = love and love.timer
  if timer and type(timer.getTime) == "function" then
    local ok, value = pcall(timer.getTime)
    if ok and type(value) == "number" then return value end
  end
  -- LÖVE always supplies timer.getTime in a real host. A zero fallback keeps
  -- static/headless contract probes inert without granting filesystem/process
  -- APIs to this content-profile mod.
  return 0
end

local function safeText(value)
  value = tostring(value or "")
  value = value:gsub("[%c]", " ")
  return value:sub(1, 48)
end

function M.notify(title, value)
  local ok, allowed = pcall(enabled)
  if not ok or allowed == false then return false end
  state.title = safeText(title)
  state.value = safeText(value)
  state.started = now()
  M.shown = M.shown + 1
  return true
end

local function drawToast()
  if not state.title then return false end
  local age = now() - state.started
  if age >= M.duration then
    state.title, state.value = nil, nil
    return false
  end
  local g = love and love.graphics
  if not (g and type(g.push) == "function" and type(g.pop) == "function"
      and type(g.rectangle) == "function" and type(g.print) == "function") then
    return false
  end

  local alpha = 1
  if age < 0.12 then alpha = math.max(0, age / 0.12) end
  if age > M.duration - 0.28 then
    alpha = math.max(0, (M.duration - age) / 0.28)
  end
  local font = type(g.getFont) == "function" and g.getFont() or nil
  local titleWidth = font and font:getWidth(state.title) or #state.title * 7
  local valueWidth = font and font:getWidth(state.value) or #state.value * 7
  local width = math.max(178, math.min(410, math.max(titleWidth, valueWidth) + 54))
  local x, y, height = 18, 18, 54

  local pushed = false
  local ok = pcall(function()
    g.push("all")
    pushed = true
    if type(g.origin) == "function" then g.origin() end
    if type(g.setCanvas) == "function" then g.setCanvas() end
    if type(g.setShader) == "function" then g.setShader() end
    if type(g.setScissor) == "function" then g.setScissor() end
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end

    g.setColor(0.015, 0.045, 0.075, 0.86 * alpha)
    g.rectangle("fill", x, y, width, height, 7, 7)
    g.setColor(0.10, 0.68, 0.88, 0.96 * alpha)
    g.rectangle("line", x, y, width, height, 7, 7)
    g.setColor(0.95, 0.39, 0.08, 0.98 * alpha)
    g.rectangle("fill", x + 1, y + 1, 7, height - 2, 6, 6)
    g.setColor(0.56, 0.84, 0.91, 0.88 * alpha)
    g.rectangle("fill", x + 18, y + 9, width - 29, 2)

    g.setColor(0.72, 0.86, 0.92, alpha)
    g.print(state.title, x + 18, y + 14)
    g.setColor(1, 1, 1, alpha)
    g.print(state.value, x + 18, y + 32)
  end)
  if pushed then pcall(g.pop) end
  return ok
end

function M.install(target, opts)
  opts = opts or {}
  if type(opts.enabled) == "function" then enabled = opts.enabled end
  if type(opts.duration) == "number" and opts.duration > 0 then
    M.duration = opts.duration
  end
  if type(target) ~= "table" or type(target.draw) ~= "function" then
    return false, "drawable game target unavailable"
  end
  local marker = rawget(target, "__vascShortcutToastV1")
  if marker == M then
    M.installed = true
    return true
  elseif marker ~= nil then
    return false, "shortcut toast draw seam owned elsewhere"
  end
  local inner = target.draw
  target.draw = function(self, ...)
    local results = packValues(inner(self, ...))
    drawToast()
    return unpackValues(results, 1, results.n)
  end
  rawset(target, "__vascShortcutToastV1", M)
  M.installed = true
  return true
end

function M.status()
  return {
    installed = M.installed,
    shown = M.shown,
    active = state.title ~= nil and (now() - state.started) < M.duration,
  }
end

M.draw = drawToast

return M
