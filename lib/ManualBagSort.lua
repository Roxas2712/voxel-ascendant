-- VASC-only manual sorting for an explicitly selected ORAS Bag surface.
--
-- The Bag provider remains the sole owner of pockets, item use, quantities,
-- callbacks and persistence.  This adapter exposes one deliberate softbutton
-- and rewrites only the current pocket's positions inside the engine-owned
-- Bag.order list.  It never sorts on open or on a pocket change.

local V = ...

local M = {
  apiVersion = 1,
  schema = "voxel-ascendant/manual-oras-bag-sort/v2",
  LABEL = "SORT",
  INPUT_LABEL = "START: SORT",
  MODES = { "alphabetical", "relevance", "strength" },
  MODE_LABELS = {
    alphabetical = "A-Z",
    relevance = "RELEVANCE",
    strength = "STRENGTH ↑",
  },
}

local DE = {
  LABEL="SORTIEREN", INPUT_LABEL="START: SORTIEREN",
  MODE_LABELS={alphabetical="A-Z", relevance="RELEVANZ", strength="STÄRKE ↑"},
}
function M.labels()
  local mod=V and V.mod
  if mod and type(mod.find)=='function' then
    local ok,handle=pcall(mod.find,'translation-german-universal')
    if ok and type(handle)=='table' and type(handle.exports)=='table'
        and handle.exports.bootLanguage=='de' then return DE end
  end
  return M
end

local installed = false
local pointerUnregister
local unpackValues = table.unpack or unpack

local function copyArray(values)
  local out = {}
  for index, value in ipairs(values or {}) do out[index] = value end
  return out
end

local function currentIds(list)
  local source = rawget(list, "__pocketIds")
  local out = {}
  if type(source) == "table" then
    for _, id in ipairs(source) do out[#out + 1] = id end
  else
    for _, item in ipairs(type(list.items) == "table" and list.items or {}) do
      if type(item) == "table" and item.value ~= nil then
        out[#out + 1] = item.value
      end
    end
  end
  return out
end

local function itemName(game, id)
  local items = game and game.data and game.data.items
  local def = type(items) == "table" and items[id] or nil
  local name = type(def) == "table" and def.name or nil
  return tostring(name or id):upper()
end

-- The third mode is deliberately not a second spelling of alphabetical.
-- These ranks express the useful low-to-high progression players expect in
-- the Ball pocket; specialty balls sit between Great and Ultra because their
-- strength is situational, while MASTER BALL is always the final row.
local BALL_STRENGTH = {
  POKE_BALL=10, SAFARI_BALL=15, GREAT_BALL=20,
  LEVEL_BALL=30, LURE_BALL=31, MOON_BALL=32, FRIEND_BALL=33,
  FAST_BALL=34, HEAVY_BALL=35, LOVE_BALL=36,
  PARK_BALL=37, SPORT_BALL=38, NET_BALL=39, NEST_BALL=40,
  REPEAT_BALL=41, TIMER_BALL=42, DIVE_BALL=43, LUXURY_BALL=44,
  PREMIER_BALL=45, DUSK_BALL=46, HEAL_BALL=47, QUICK_BALL=48,
  CHERISH_BALL=49, DREAM_BALL=50, BEAST_BALL=51,
  ULTRA_BALL=80, MASTER_BALL=1000,
}

local MEDICINE_STRENGTH = {
  POTION=10, BERRY=12, FRESH_WATER=15, SUPER_POTION=20,
  SODA_POP=25, LEMONADE=30, MOOMOO_MILK=35,
  HYPER_POTION=40, MAX_POTION=50, FULL_RESTORE=60,
  REVIVE=70, MAX_REVIVE=80,
}

local RELEVANCE = {
  FULL_RESTORE=10, MAX_REVIVE=11, REVIVE=12, MAX_POTION=13,
  HYPER_POTION=14, SUPER_POTION=15, POTION=16,
  FULL_HEAL=20, ANTIDOTE=21, BURN_HEAL=22, ICE_HEAL=23,
  AWAKENING=24, PARLYZ_HEAL=25,
  MAX_ELIXER=30, ELIXER=31, MAX_ETHER=32, ETHER=33,
  ESCAPE_ROPE=40, REPEL=41, SUPER_REPEL=42, MAX_REPEL=43,
  RARE_CANDY=50, EXP_SHARE=51,
}

local function normalizedId(id)
  return tostring(id or ""):upper():gsub("[^A-Z0-9]+", "_")
end

local function itemDefinition(game, id)
  local items = game and game.data and game.data.items
  return type(items) == "table" and items[id] or nil
end

local function numberOr(value, fallback)
  value = tonumber(value)
  return value ~= nil and value or fallback
end

local function quantityOf(game, id)
  local save = game and game.save
  local inventory = save and save.inventory
  return type(inventory) == "table" and numberOr(inventory[id], 0) or 0
end

local function compareName(game, a, b)
  local an, bn = itemName(game, a), itemName(game, b)
  if an == bn then return tostring(a) < tostring(b) end
  return an < bn
end

local function strengthKey(game, id)
  local key = normalizedId(id)
  local def = itemDefinition(game, id)
  if BALL_STRENGTH[key] then return 0, BALL_STRENGTH[key] end
  if MEDICINE_STRENGTH[key] then return 1, MEDICINE_STRENGTH[key] end
  return 2, numberOr(def and def.price,
    numberOr(def and def.index, math.huge))
end

local function relevanceKey(game, id)
  local key = normalizedId(id)
  local def = itemDefinition(game, id)
  if RELEVANCE[key] then return RELEVANCE[key] end
  if BALL_STRENGTH[key] then return 100 + BALL_STRENGTH[key] end
  if key:match("^HM_") then return 300 end
  if key:match("^TM_") then return 310 end
  local usable = def and (def.fieldMenu or def.battleMenu)
  if usable and tostring(usable):upper() ~= "NOUSE" then return 200 end
  return 500 - math.min(99, quantityOf(game, id))
end

function M.sortIds(ids, game, mode)
  local result = copyArray(ids)
  mode = mode or "alphabetical"
  table.sort(result, function(a, b)
    if mode == "strength" then
      local af, ar = strengthKey(game, a)
      local bf, br = strengthKey(game, b)
      if af ~= bf then return af < bf end
      if ar ~= br then return ar < br end
    elseif mode == "relevance" then
      local ar, br = relevanceKey(game, a), relevanceKey(game, b)
      if ar ~= br then return ar < br end
      local aq, bq = quantityOf(game, a), quantityOf(game, b)
      if aq ~= bq then return aq > bq end
    end
    return compareName(game, a, b)
  end)
  return result
end

function M.nextMode(owner, pocket)
  if type(owner) ~= "table" then return M.MODES[1], 1 end
  pocket = tostring(pocket or rawget(owner, "__pocketIndex") or 1)
  local byPocket = rawget(owner, "__vascManualBagSortModes")
  if type(byPocket) ~= "table" then
    byPocket = {}
    owner.__vascManualBagSortModes = byPocket
  end
  local index = (tonumber(byPocket[pocket]) or 0) % #M.MODES + 1
  byPocket[pocket] = index
  owner.__vascManualBagSortModeIndex = index
  owner.__vascManualBagSortMode = M.MODES[index]
  owner.__vascManualBagSortModeLabel = M.labels().MODE_LABELS[M.MODES[index]]
  return M.MODES[index], index
end

local function buttonRect(list)
  local wide = rawget(list, "__vascOrasBagWidePresentation") == true
    or rawget(list, "__vascOrasFrlgBagWidePresentation") == true
  -- Keep the action in the Bag header, immediately before the money field.
  -- The help panel below remains entirely available for the selected item's
  -- description and no longer looks like it owns the action.
  -- Leave a deliberate text gutter around START: SORTIEREN.  The narrower
  -- R24 rectangle technically fit the hit target, but the real pixel font
  -- overran both rounded edges at the reviewed 512x288 presentation.
  if wide then return 276, 17, 156, 18 end
  return 76, 3, 68, 12
end

M.buttonRect = buttonRect

local function contains(rect, x, y)
  return type(x) == "number" and type(y) == "number"
    and x >= rect[1] and y >= rect[2]
    and x < rect[1] + rect[3] and y < rect[2] + rect[4]
end

local function orderFor(list)
  local game = list and list.game
  local save = game and game.save
  if type(save) ~= "table" or type(save.inventory) ~= "table" then
    return nil, "bag-save-unavailable"
  end
  local ok, Bag = pcall(require, "src.inventory.Bag")
  if not ok or type(Bag) ~= "table" or type(Bag.order) ~= "function" then
    return nil, "bag-order-unavailable"
  end
  local ordered, order = pcall(Bag.order, save, rawget(list, "bagData"))
  if not ordered or type(order) ~= "table" then
    return nil, "bag-order-failed"
  end
  return order
end

function M.sortCurrentPocket(list)
  if type(list) ~= "table" or list.__vascManualBagSort ~= true then
    return false, "not-decorated"
  end
  local custom = rawget(list, "__vascManualBagSortCustomAction")
  if type(custom) == "function" then return custom(list) end
  local order, reason = orderFor(list)
  if not order then return false, reason end
  local ids = currentIds(list)
  if #ids < 2 then return true, "unchanged" end

  local member = {}
  for _, id in ipairs(ids) do member[id] = true end
  local pocket = rawget(list, "__vascOrasBagPocketId")
    or rawget(list, "__vascOrasFrlgBagPocketId")
    or rawget(list, "__pocketIndex") or 1
  local mode = M.nextMode(list, pocket)
  ids = M.sortIds(ids, list.game, mode)

  local before = copyArray(order)
  local selectedRow = type(list.items) == "table" and list.items[list.index]
  local selected = type(selectedRow) == "table" and selectedRow.value or nil
  local rebuilt
  if type(list.__project) ~= "function" then
    local byId, slots = {}, {}
    rebuilt = copyArray(list.items)
    for index, item in ipairs(rebuilt) do
      if type(item) == "table" and item.value ~= nil and member[item.value] then
        if byId[item.value] then return false, "pocket-rows-mismatch" end
        byId[item.value] = item
        slots[#slots + 1] = index
      end
    end
    if #slots ~= #ids then return false, "pocket-rows-mismatch" end
    for index, id in ipairs(ids) do
      if not byId[id] then return false, "pocket-rows-mismatch" end
      rebuilt[slots[index]] = byId[id]
    end
  end
  local nextId = 1
  for index, id in ipairs(order) do
    if member[id] then
      order[index] = ids[nextId]
      nextId = nextId + 1
    end
  end
  if nextId ~= #ids + 1 then
    for index, id in ipairs(before) do order[index] = id end
    return false, "pocket-order-mismatch"
  end

  if type(list.__project) == "function" then
    local projected, projectError = pcall(list.__project)
    if not projected then
      for index = #order, 1, -1 do order[index] = nil end
      for index, id in ipairs(before) do order[index] = id end
      pcall(list.__project)
      list.__vascManualBagSortLastError = tostring(projectError)
      return false, "project-failed"
    end
  else
    -- Native bags include CANCEL (no item id); other providers may include
    -- headers. Keep those rows and their callbacks in their original slots.
    list.items = rebuilt
  end

  if selectedRow ~= nil then
    for index, item in ipairs(list.items or {}) do
      if item == selectedRow or (selected ~= nil
          and type(item) == "table" and item.value == selected) then
        list.index = index
        break
      end
    end
  end
  list.scroll = math.max(0, math.min(tonumber(list.scroll) or 0,
    math.max(0, #(list.items or {}) - (tonumber(list.rows) or 1))))
  list.__vascManualBagSortCount =
    (list.__vascManualBagSortCount or 0) + 1
  list.__vascManualBagSortPocket = rawget(list, "__pocketIndex") or 1
  return true, "sorted", mode
end

local function drawButton(list, Font)
  local g = love and love.graphics
  if not (g and type(g.rectangle) == "function"
      and type(g.setColor) == "function" and Font
      and type(Font.draw) == "function") then return end
  local x, y, w, h = buttonRect(list)
  local wide = rawget(list, "__vascOrasBagWidePresentation") == true
    or rawget(list, "__vascOrasFrlgBagWidePresentation") == true
  local focused = list.__vascManualBagSortFocused == true
  local previousColor
  local previousWidth
  if type(g.getColor) == "function" then
    previousColor = { g.getColor() }
  end
  if type(g.getLineWidth) == "function" then previousWidth = g.getLineWidth() end
  local accent = rawget(list, "__vascOrasBagAccent")
    or rawget(list, "__vascOrasFrlgBagAccent") or "blue"
  local colors = {
    red={ 1.00, 0.67, 0.63 },
    blue={ 0.62, 0.81, 0.91 },
    green={ 0.65, 0.86, 0.69 },
  }
  local fill = focused and (colors[accent] or colors.blue)
    or { 0.72, 0.78, 0.82 }
  g.setColor(0.02, 0.05, 0.09, 0.28)
  g.rectangle("fill", x + 2, y + 2, w, h, 3, 3)
  g.setColor(fill[1], fill[2], fill[3], focused and 0.98 or 0.86)
  g.rectangle("fill", x, y, w, h, 3, 3)
  g.setColor(0.02, 0.05, 0.09, 0.92)
  if type(g.setLineWidth) == "function" then g.setLineWidth(1) end
  g.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 3, 3)
  if previousColor then
    g.setColor(unpackValues(previousColor))
  else
    g.setColor(1, 1, 1, 1)
  end
  local labels=M.labels()
  local modeLabel = labels.MODE_LABELS[rawget(list, "__vascManualBagSortMode")]
  local label
  if wide then
    label = modeLabel and ("START: " .. modeLabel) or labels.INPUT_LABEL
  else
    local compact = {
      alphabetical="A-Z", relevance="REL", strength="RANK",
    }
    local mode = rawget(list, "__vascManualBagSortMode")
    label = mode and ("START:" .. (compact[mode] or "SORT")) or "START:SORT"
  end
  local width = type(Font.width) == "function" and Font.width(label) or 0
  Font.draw(label, math.floor(x + (w - width) / 2), y + math.floor((h - 8) / 2))
  if previousWidth and type(g.setLineWidth) == "function" then
    g.setLineWidth(previousWidth)
  end
  g.setColor(1, 1, 1, 1)
end

local function wrapListBoundary(list, delta)
  if rawget(list, "swapIndex") ~= nil then return false end
  local items = type(list.items) == "table" and list.items or {}
  local count = #items
  if count < 1 then return false end
  local index = math.max(1, math.min(count,
    math.floor(tonumber(list.index) or 1)))
  if delta > 0 and index == count then
    list.index, list.scroll = 1, 0
    return true
  end
  if delta < 0 and index == 1 then
    list.index = count
    list.scroll = math.max(0, count - math.max(1,
      math.floor(tonumber(list.rows) or 1)))
    return true
  end
  return false
end

function M.decorate(list, opts)
  opts = opts or {}
  if type(list) ~= "table" or list.__vascManualBagSort == true then
    return list, false, list and "already-decorated" or "invalid-list"
  end
  if not (list.__vascOrasBagPresentation
      or list.__vascOrasFrlgBagPresentation) then
    return list, false, "not-vasc-oras-bag"
  end
  local draw = list.draw
  if type(draw) ~= "function" then return list, false, "not-drawable" end
  local drawWidescreen = type(list.drawWidescreen) == "function"
    and list.drawWidescreen or nil
  local update = list.update
  local Font = opts.Font
  list.__vascManualBagSort = true
  list.__vascManualBagSortSchema = M.schema
  list.__vascManualBagSortOriginalDraw = draw
  list.__vascManualBagSortOriginalDrawWidescreen = drawWidescreen
  list.__vascManualBagSortOriginalUpdate = update
  list.__vascManualBagSortCustomAction = opts.sort
  list.__vascManualBagSortAction = function(self)
    return M.sortCurrentPocket(self or list)
  end
  local function drawWithButton(drawer, self, ...)
    local results = { n = 0 }
    local function capture(...)
      results.n = select("#", ...)
      for index = 1, results.n do results[index] = select(index, ...) end
    end
    capture(drawer(self, ...))
    drawButton(self, Font)
    return unpackValues(results, 1, results.n)
  end
  list.draw = function(self, ...)
    return drawWithButton(draw, self, ...)
  end
  -- MobileMenuPresentation deliberately selects the separately authored wide
  -- renderer. Keep the exact same visible/action wrapper on that path; only
  -- wrapping `draw` made the PC button disappear on Gen 1/2 phones.
  if drawWidescreen then
    list.drawWidescreen = function(self, ...)
      return drawWithButton(drawWidescreen, self, ...)
    end
  end
  if type(update) == "function" then
    list.update = function(self, ...)
      local input = self.game and self.game.input
      local usable = input and type(input.wasPressed) == "function"
      local pressedStart = usable and input:wasPressed("start")
      local pressedUp = usable and input:wasPressed("up")
      local pressedDown = usable and input:wasPressed("down")
      -- START is dedicated to the explicit sort action while the normal item
      -- list owns the screen. LEFT/RIGHT are never intercepted: they remain
      -- pure previous/next-pocket navigation. SELECT likewise remains the
      -- provider's item-move action, and B remains its normal close/cancel.
      if rawget(self, "swapIndex") == nil and pressedStart then
        M.focus(self, false)
        return self:__vascManualBagSortAction()
      end
      if pressedDown and wrapListBoundary(self, 1) then return nil end
      if pressedUp and wrapListBoundary(self, -1) then return nil end
      M.focus(self, false)
      return update(self, ...)
    end
  end
  return list, true
end

function M.focus(list, focused)
  if type(list) ~= "table" or list.__vascManualBagSort ~= true then
    return false
  end
  list.__vascManualBagSortFocused = focused == true
  return true
end

function M.installPointer(mod, opts)
  if installed then return true end
  if not (type(mod) == "table" and mod.hooks
      and type(mod.hooks.wrap) == "function") then
    return false, "pointer-hook-unavailable"
  end
  local pointerToLogical = opts and opts.pointerToLogical
  local ok, token = pcall(mod.hooks.wrap, mod.hooks,
    "input.pointer", function(nextInput, game, pointer)
    local downstream = nextInput(game, pointer)
    if downstream == true or type(pointer) ~= "table"
        or pointer.insideGame == false then return downstream end
    local top = game and game.stack and type(game.stack.top) == "function"
      and game.stack:top() or nil
    if type(top) == "table" and type(top.__vascManualBagSortProxy) == "table" then
      top = top.__vascManualBagSortProxy
    end
    if type(top) ~= "table" or top.__vascManualBagSort ~= true then
      return downstream
    end
    local x, y = pointer.gameX or pointer.x, pointer.gameY or pointer.y
    if type(pointerToLogical) == "function" then
      local ok, lx, ly = pcall(pointerToLogical, top, x, y)
      if ok and type(lx) == "number" and type(ly) == "number" then
        x, y = lx, ly
      end
    end
    local bx, by, bw, bh = buttonRect(top)
    local over = contains({ bx, by, bw, bh }, x, y)
    if pointer.phase == "moved" then M.focus(top, over) end
    if pointer.phase == "pressed" and over
        and (pointer.source ~= "mouse" or pointer.button == nil
          or pointer.button == 1) then
      M.focus(top, true)
      local ok = top:__vascManualBagSortAction()
      return ok == true or downstream
    end
    return downstream
  end, 850)
  if not ok then return false, tostring(token) end
  pointerUnregister = token
  installed = true
  return true
end

function M.health()
  return {
    schema=M.schema,
    ok=installed,
    state=installed and "active" or "inactive",
    hookRegistered=installed,
    removable=type(pointerUnregister) == "function",
  }
end

function M.deactivate()
  if not installed then return true end
  if type(pointerUnregister) ~= "function" then
    return false, "pointer-hook-not-removable"
  end
  local ok, reason = pcall(pointerUnregister)
  if not ok then return false, tostring(reason) end
  pointerUnregister = nil
  installed = false
  return true
end

return M
