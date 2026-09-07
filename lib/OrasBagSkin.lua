-- Opt-in ORAS presentation for an already constructed Bag ListMenu.
--
-- This module owns drawing only: update, input, item/pocket projection and all
-- callbacks stay on the supplied list.  By default it yields to Useful Bag,
-- FireRed/KASC and other explicit bag render owners.  `force = true` is the
-- caller's deliberate escape hatch when replacing another presentation.
-- An `enabled(list)` option may switch the presentation live; false or an
-- evaluator error delegates straight to the exact draw captured at decorate.

local M = {
  apiVersion = 1,
  owner = "voxel_ascendant.oras_bag",
  width = 160,
  height = 144,
  assetPath = "assets/ui/dp-bag-6961.png",
}
M.OWNER, M.WIDTH, M.HEIGHT = M.owner, M.width, M.height
M.WIDE_WIDTH, M.WIDE_HEIGHT = 512, 288
M.ASSET_PATH = M.assetPath
M.POCKET_ICON_ASSET_PATH = "assets/ui/bag-pocket-icons.png"
M.POCKET_ICON_ATLAS = { cell = 34, display = 12, columns = 6, rows = 2,
  width = 204, height = 68 }

-- Deterministically derived from The Spriters Resource asset 6961
-- (Pokémon Diamond/Pearl Bag, 743x442).  The shipped atlas contains only the
-- sixteen Bag crops, with the flat sheet background made transparent and the
-- source pixels copied 1:1.  No watermark, trainer
-- art or source UI furniture is included.
local ATLAS = { cellWidth = 72, cellHeight = 64, width = 576, height = 128 }
local SHEET_POCKET_SLOT = {
  balls = 1, medicine = 2, berries = 3, key = 4,
  mail = 5, tms = 6, items = 7, battle = 8,
}
local POCKET_ORDER = { "items", "medicine", "balls", "tms", "battle", "key" }
local POCKET_ICON_SLOT = {
  items = 0, medicine = 1, balls = 2, tms = 3, battle = 4, key = 5,
}
M.ATLAS = ATLAS
M.SHEET_POCKET_SLOT = SHEET_POCKET_SLOT
M.POCKET_ORDER = POCKET_ORDER
M.POCKET_ICON_SLOT = POCKET_ICON_SLOT
M.RECOLOR_SCOPE = "exact_accent_and_body_swatches_only"
M.ACCENTS = { "auto", "red", "blue", "green" }
M.BODIES = {
  "auto", "oras", "red", "blue", "yellow", "gold", "silver", "crystal",
}
M.FORMS = { "auto", "round", "handle" }

local unpackValues = table.unpack or unpack

local function packed(...)
  return { n = select("#", ...), ... }
end

local function traceback(message)
  if debug and type(debug.traceback) == "function" then
    return debug.traceback(tostring(message), 2)
  end
  return tostring(message)
end

local function safeRequire(name)
  local ok, value = pcall(require, name)
  if ok and type(value) == "table" then return value end
  return nil
end

-- The mod sandbox exposes LÖVE through the chunk environment's indexed
-- proxy.  It is intentionally not guaranteed to be stored directly in `_G`,
-- so rawget(_G, "love") disables the ORAS wide renderer on iOS and leaks the
-- provider's old 160x144 Bag.  Always use the supported indexed access.
local function loveRuntime()
  local ok, value = pcall(function() return love end)
  return ok and type(value) == "table" and value or nil
end

local SELF_KEYS = {
  __vascOrasBagPresentation = true,
  __vascOrasBagSkin = true,
  __vascOrasBagOwner = true,
  __vascOrasBagNativeDraw = true,
  __vascOrasBagConfig = true,
  __vascOrasBagForced = true,
  __vascOrasBagLastError = true,
  __vascOrasBagAssetPath = true,
  __vascOrasBagPocketIconAssetPath = true,
  __vascOrasBagPocketCount = true,
  __vascOrasBagPocketId = true,
  __vascOrasBagSpriteSlot = true,
  __vascOrasBagCharacter = true,
  __vascOrasBagAccent = true,
  __vascOrasBagBody = true,
  __vascOrasBagForm = true,
  __vascOrasBagAnimation = true,
  __vascOrasBagWidePresentation = true,
  __vascOrasBagLayoutWidth = true,
  __vascOrasBagLayoutHeight = true,
  __ascendantOrasBag = true,
  __ascendantGlobalUiSkinSkip = true,
}

local OWNER_FIELDS = {
  __bagOwner = true,
  __bagSkinOwner = true,
  __bagPresentationOwner = true,
  bagOwner = true,
  bagSkinOwner = true,
  bagPresentationOwner = true,
}

local function classifyMarker(key, value, ignoredOwner)
  if type(key) ~= "string" or not value or SELF_KEYS[key] then return nil end
  local lower = key:lower()
  if lower:match("^__usefulbag") then return "useful_bag" end
  if lower:match("^__vascorasfrlgbag") then
    if ignoredOwner == "voxel_ascendant.oras_frlg_bag" then return nil end
    return "voxel_ascendant.oras_frlg_bag"
  end
  if lower:match("^__firered") or lower:match("^__frlg") then
    return "frlg_bag"
  end
  if lower:match("^__ascendantmodernbag")
      or lower:match("^__ascendantbag")
      or lower:match("^__kantoascendantbag")
      or lower:match("^__kascbag") then
    return "kasc_bag"
  end
  if lower:match("^__custombag") then return "custom_bag" end
  if OWNER_FIELDS[key] and type(value) == "string" and value ~= "" then
    local owner = value:lower()
    if owner ~= M.owner then return "declared_bag:" .. owner end
  end
  return nil
end

local function markerTables(list)
  local found, seen = {}, {}
  local function add(value)
    if type(value) == "table" and not seen[value] then
      seen[value] = true
      found[#found + 1] = value
    end
  end
  add(list)
  local cursor = list
  while type(cursor) == "table" do
    local mt = getmetatable(cursor)
    if type(mt) ~= "table" or seen[mt] then break end
    add(mt)
    local index = rawget(mt, "__index")
    if type(index) == "table" then add(index) end
    cursor = type(index) == "table" and index or mt
  end
  return found
end

local function externalOwnerOf(list, ignoredOwner)
  if type(list) ~= "table" then return nil end
  for _, source in ipairs(markerTables(list)) do
    for key, value in pairs(source) do
      local owner = classifyMarker(key, value, ignoredOwner)
      if owner then return owner, key end
    end
  end
  return nil
end

local function battleBelow(list)
  local game = type(list) == "table" and rawget(list, "game") or nil
  local stack = type(game) == "table" and game.stack or nil
  local states = type(stack) == "table" and stack.states or nil
  if type(states) ~= "table" then return false end
  local found = false
  for index = #states, 1, -1 do
    local state = states[index]
    if state == list then
      found = true
    elseif found and type(state) == "table" and state.isBattle == true then
      return true
    end
  end
  return false
end

local SIX_POCKET_OWNERS = {
  useful_bag = true,
  frlg_bag = true,
  kasc_bag = true,
}

local function hasKnownSixPocketOwner(list)
  if type(list) ~= "table" then return false end
  for _, source in ipairs(markerTables(list)) do
    for key, value in pairs(source) do
      if SIX_POCKET_OWNERS[classifyMarker(key, value)] then return true end
    end
  end
  return false
end

function M.externalOwnerOf(list, ignoredOwner)
  return externalOwnerOf(list, ignoredOwner)
end

function M.ownerOf(list)
  if type(list) ~= "table" then return nil end
  if rawget(list, "__vascOrasBagPresentation")
      and rawget(list, "__vascOrasBagOwner") == M.owner then
    return M.owner, "__vascOrasBagPresentation"
  end
  return externalOwnerOf(list)
end

function M.isDecorated(list)
  return type(list) == "table"
    and rawget(list, "__vascOrasBagPresentation") == true
    and rawget(list, "__vascOrasBagOwner") == M.owner
end

function M.yieldReason(list, opts)
  opts = type(opts) == "table" and opts or {}
  if opts.force == true then return nil end
  local owner, marker = externalOwnerOf(list)
  if owner then return "external_owner:" .. owner, marker end
  return nil
end

M.shouldYield = function(list, opts)
  local reason, marker = M.yieldReason(list, opts)
  return reason ~= nil, reason, marker
end

function M.canDecorate(list, opts)
  if type(list) ~= "table" then return false, "invalid_list" end
  if M.isDecorated(list) then return false, "already_decorated" end
  if type(rawget(list, "draw") or list.draw) ~= "function" then
    return false, "missing_draw"
  end
  if type(rawget(list, "items") or list.items) ~= "table" then
    return false, "missing_items"
  end
  local reason, marker = M.yieldReason(list, opts)
  if reason then return false, reason, marker end
  return true
end

M.canDecorateBag = M.canDecorate

-- Same authored roles as OrasStoragePresentation, kept as exact RGB ratios.
local C = {
  navy      = {  12 / 255,  37 / 255,  84 / 255, 1 }, -- #0C2554
  navy2     = {   5 / 255,  24 / 255,  61 / 255, 1 }, -- #05183D
  blue      = {  23 / 255,  75 / 255, 142 / 255, 1 }, -- #174B8E
  orange    = { 244 / 255,  91 / 255,  12 / 255, 1 }, -- #F45B0C
  orange2   = { 255 / 255, 145 / 255,  22 / 255, 1 }, -- #FF9116
  gold      = { 255 / 255, 194 / 255,  44 / 255, 1 }, -- #FFC22C
  cream     = { 255 / 255, 247 / 255, 218 / 255, 1 }, -- #FFF7DA
  paper     = { 255 / 255, 252 / 255, 236 / 255, 1 }, -- #FFFCEC
  glass     = { 158 / 255, 215 / 255, 244 / 255, 1 }, -- #9ED7F4
  glass2    = { 202 / 255, 238 / 255, 251 / 255, 1 }, -- #CAEEFB
  sky       = {  31 / 255, 158 / 255, 219 / 255, 1 }, -- #1F9EDB
  skyLight  = { 100 / 255, 207 / 255, 240 / 255, 1 }, -- #64CFF0
  sea       = {   5 / 255, 113 / 255, 183 / 255, 1 }, -- #0571B7
  ink       = {   5 / 255,  24 / 255,  61 / 255, 1 },
  white     = { 1, 1, 1, 1 },
  shadow    = {   5 / 255,  24 / 255,  61 / 255, 0.30 },
}

local function color(g, value)
  g.setColor(value[1], value[2], value[3], value[4])
end

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

local function pixel(value)
  if value < 0 then return math.ceil(value - 0.5) end
  return math.floor(value + 0.5)
end

local function integer(value, fallback)
  value = tonumber(value)
  if not value then return fallback end
  return math.floor(value)
end

local function fontWidth(Font, value)
  local text = tostring(value or "")
  local ok, width = pcall(Font.width, text)
  if ok and type(width) == "number" then return width end
  return #text * 8
end

local function truncate(Font, value, budget)
  local text = tostring(value or "")
  if fontWidth(Font, text) <= budget then return text end
  if type(Font.split) == "function" and type(Font.spansFitting) == "function" then
    local spans = Font.split(text)
    local fit = Font.spansFitting(spans, math.max(0, budget - 8))
    if fit < 1 then return "." end
    return text:sub(1, spans[fit].to) .. "."
  end
  local count = math.max(1, math.floor(budget / 8) - 1)
  return text:sub(1, count) .. "."
end

local function languageOf(list, config)
  local value = config.language or rawget(list, "language")
    or rawget(list, "__language")
  if value == nil then
    local game = rawget(list, "game")
    local save = type(game) == "table" and game.save or nil
    local options = type(save) == "table" and save.options or nil
    value = type(options) == "table" and options.language
      or (type(game) == "table" and game.language)
  end
  value = tostring(value or "en"):lower()
  return value:match("^de") and "de" or "en"
end

local function tr(language, english, german)
  return language == "de" and german or english
end

local function localizedBagTitle(value, language)
  value = tostring(value or "")
  if language ~= "de" then return value end
  return ({
    ["BAG"]="TASCHE", ["ITEM"]="GEGENSTAND",
    ["ITEMS"]="GEGENSTÄNDE",
    ["MEDICINE"]="MEDIZIN", ["MEDS"]="MEDIZIN",
    ["BALLS"]="BÄLLE", ["POKé BALLS"]="POKéBÄLLE",
    ["BATTLE"]="KAMPF", ["BATTLE ITEMS"]="KAMPF-GEGENSTÄNDE",
    ["KEY ITEMS"]="BASIS-GEGENSTÄNDE",
    ["BASIS-ITEMS"]="BASIS-GEGENSTÄNDE",
  })[value] or value
end

local function timeNow()
  local loveRef = loveRuntime()
  local timer = loveRef and loveRef.timer
  if timer and type(timer.getTime) == "function" then
    local ok, value = pcall(timer.getTime)
    if ok and type(value) == "number" then return value end
  end
  return 0
end

local function pingPongOffset(time, overflow, hold, speed)
  if not overflow or overflow <= 0 then return 0 end
  hold, speed = hold or 1.25, speed or 15
  local travel = overflow / speed
  local cycle = hold * 2 + travel * 2
  local phase = (time or 0) % cycle
  if phase < hold then return 0 end
  phase = phase - hold
  if phase < travel then
    local progress = travel > 0 and phase / travel or 1
    progress = progress * progress * (3 - 2 * progress)
    return -overflow * progress
  end
  phase = phase - travel
  if phase < hold then return -overflow end
  local progress = travel > 0 and (phase - hold) / travel or 1
  progress = clamp(progress, 0, 1)
  progress = progress * progress * (3 - 2 * progress)
  return -overflow * (1 - progress)
end

local function scissorState(g)
  if type(g.getScissor) ~= "function" then return nil end
  local values = packed(pcall(g.getScissor))
  if not values[1] then return nil end
  return {
    known = true,
    active = values[2] ~= nil,
    values = { values[2], values[3], values[4], values[5] },
  }
end

local function restoreScissor(g, state)
  if type(g.setScissor) ~= "function" then return end
  if state and state.known and state.active then
    pcall(g.setScissor, unpackValues(state.values, 1, 4))
  else
    pcall(g.setScissor)
  end
end

local function withScissor(g, x, y, width, height, callback)
  if type(g.setScissor) ~= "function" then return callback(false) end
  local previous = scissorState(g)
  g.setScissor(x, y, width, height)
  local ok, returned = xpcall(function()
    return packed(callback(true))
  end, traceback)
  restoreScissor(g, previous)
  if not ok then error(returned, 0) end
  return unpackValues(returned, 1, returned.n)
end

local function graphicsState(g)
  local state = { scissor = scissorState(g) }
  if type(g.getColor) == "function" then
    local values = packed(pcall(g.getColor))
    if values[1] then state.color = { values[2], values[3], values[4], values[5] } end
  end
  if type(g.getLineWidth) == "function" then
    local ok, width = pcall(g.getLineWidth)
    if ok then state.lineWidth = width end
  end
  if type(g.getShader) == "function" then
    local ok, shader = pcall(g.getShader)
    if ok then state.shaderKnown, state.shader = true, shader end
  end
  return state
end

local function restoreGraphics(g, state)
  restoreScissor(g, state.scissor)
  if state.shaderKnown and type(g.setShader) == "function" then
    if state.shader ~= nil then pcall(g.setShader, state.shader)
    else pcall(g.setShader) end
  end
  if state.lineWidth ~= nil and type(g.setLineWidth) == "function" then
    pcall(g.setLineWidth, state.lineWidth)
  end
  if state.color then
    pcall(g.setColor, unpackValues(state.color, 1, 4))
  else
    pcall(g.setColor, 1, 1, 1, 1)
  end
end

local function restoreCanvas(g, canvas)
  if canvas ~= nil then g.setCanvas(canvas) else g.setCanvas() end
end

local function resolveWideLayer(config, g)
  if type(g) ~= "table" or type(g.newCanvas) ~= "function"
      or type(g.setCanvas) ~= "function" or type(g.getCanvas) ~= "function"
      or type(g.push) ~= "function" or type(g.pop) ~= "function"
      or type(g.clear) ~= "function" or type(g.draw) ~= "function" then
    return nil, "D/P ORAS WIDE Bag staging canvas is unavailable"
  end
  local okCanvas, canvasOrError = pcall(g.getCanvas)
  if not okCanvas then return nil, tostring(canvasOrError) end
  local layer = config.wideLayer
  if layer then
    if type(layer.getDimensions) ~= "function" then
      layer = nil
    else
      local ok, width, height = pcall(layer.getDimensions, layer)
      if not ok or width ~= M.WIDE_WIDTH or height ~= M.WIDE_HEIGHT then
        layer = nil
      end
    end
  end
  if not layer then
    local ok, created = pcall(g.newCanvas, M.WIDE_WIDTH, M.WIDE_HEIGHT,
      { dpiscale=1 })
    if not ok or not created then
      return nil, tostring(created or
        "D/P ORAS WIDE Bag canvas allocation failed")
    end
    layer, config.wideLayer = created, created
    if type(layer.setFilter) == "function" then
      pcall(layer.setFilter, layer, "nearest", "nearest")
    end
  end
  return layer
end

-- Wide layouts are staged offscreen. If any provider/font/graphics call
-- throws, no partial 512x288 furniture has touched the authoritative target;
-- the controller can fail open to its complete native renderer instead.
local function drawWideAtomically(config, g, callback)
  local layer, layerError = resolveWideLayer(config, g)
  if not layer then return false, layerError end

  local okCanvas, previousCanvas = pcall(g.getCanvas)
  if not okCanvas then return false, previousCanvas end
  local pushed, returned = false, nil
  local ok, err = xpcall(function()
    g.push("all")
    pushed = true
    g.setCanvas(layer)
    if type(g.origin) == "function" then g.origin() end
    if type(g.setShader) == "function" then g.setShader() end
    if type(g.setScissor) == "function" then g.setScissor() end
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
    g.clear(0, 0, 0, 0)
    returned = packed(callback())
    g.pop()
    pushed = false
    restoreCanvas(g, previousCanvas)

    g.push("all")
    pushed = true
    if type(g.origin) == "function" then g.origin() end
    if type(g.setShader) == "function" then g.setShader() end
    if type(g.setScissor) == "function" then g.setScissor() end
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
    g.setColor(1, 1, 1, 1)
    g.draw(layer, 0, 0)
    g.pop()
    pushed = false
  end, traceback)
  if pushed then pcall(g.pop) end
  pcall(restoreCanvas, g, previousCanvas)
  if not ok then return false, err end
  return true, returned
end

-- A draw-time failure happens after the renderer selected 512x288 for the
-- frame. Stage the complete native 160x144 provider at exact 2x scale so that
-- fail-open is still coherent; the following frame returns to native uiSize.
local function drawNativeWideFallback(config, g, callback)
  if type(g) ~= "table" or type(g.translate) ~= "function"
      or type(g.scale) ~= "function" then
    return false, "D/P ORAS WIDE Bag native fallback transform is unavailable"
  end
  local ok, returned = drawWideAtomically(config, g, function()
    g.translate(math.floor((M.WIDE_WIDTH - M.WIDTH * 2) / 2), 0)
    g.scale(2, 2)
    return callback()
  end)
  if ok then
    local PaletteFX = config.PaletteFX or safeRequire("src.render.PaletteFX")
    if PaletteFX and type(PaletteFX.markTrueColor) == "function" then
      pcall(PaletteFX.markTrueColor, 0, 0, M.WIDE_WIDTH, M.WIDE_HEIGHT)
    end
  end
  return ok, returned
end

local function panel(g, x, y, width, height, outside, inside, radius)
  radius = radius or 3
  color(g, C.shadow)
  g.rectangle("fill", x + 1, y + 2, width, height, radius, radius)
  color(g, outside)
  g.rectangle("fill", x, y, width, height, radius, radius)
  color(g, inside)
  g.rectangle("fill", x + 2, y + 2,
    math.max(0, width - 4), math.max(0, height - 4),
    math.max(0, radius - 1), math.max(0, radius - 1))
end

-- Integer scanlines keep the cursor sharp even when no shared renderer was
-- injected by OrasUiSkin. No antialiased primitive is used on the normal path.
local function drawPokeBall(g, cx, cy, radius, active, hollow)
  radius = math.max(2, math.floor(radius))
  cx, cy = pixel(cx), pixel(cy)
  for dy = -radius, radius do
    local half = math.floor(math.sqrt(math.max(
      0, radius * radius - dy * dy)))
    if not hollow then
      color(g, dy < 0 and (active and C.orange2 or C.orange) or C.cream)
      g.rectangle("fill", cx - half, cy + dy, half * 2 + 1, 1)
    end
    color(g, C.navy)
    g.rectangle("fill", cx - half, cy + dy, 1, 1)
    if half > 0 then g.rectangle("fill", cx + half, cy + dy, 1, 1) end
  end
  color(g, C.navy)
  g.rectangle("fill", cx - radius, cy, radius * 2 + 1, 1)
  local button = math.max(1, math.floor(radius * 0.34))
  g.rectangle("fill", cx - button, cy - button,
    button * 2 + 1, button * 2 + 1)
  color(g, hollow and C.paper or C.white)
  g.rectangle("fill", cx, cy, 1, 1)
end

local function renderPokeBall(config, g, cx, cy, radius, active, hollow)
  if type(config and config.drawPokeBall) == "function" then
    local ok = pcall(config.drawPokeBall,
      g, cx, cy, radius, active, hollow)
    if ok then return end
  end
  drawPokeBall(g, cx, cy, radius, active, hollow)
end

-- Emergency fallback for a missing pocket-icon atlas or a draw backend that
-- cannot render images. The packaged ORAS and FRLG presentations normally use
-- the shared exact-source D/P raster atlas below; this keeps direct adapters
-- fail-soft without making procedural geometry the visible release path.
local function drawPocketIcon(g, pocketId, cx, cy, active)
  pocketId = tostring(pocketId or "items"):lower()
  if pocketId == "ball" then pocketId = "balls" end
  if pocketId == "tm" or pocketId == "hm" then pocketId = "tms" end
  cx, cy = pixel(cx), pixel(cy)

  if pocketId == "balls" then
    drawPokeBall(g, cx, cy, 3, active == true, false)
    return
  end

  local fill = active and C.orange2 or C.cream
  color(g, C.navy)
  if pocketId == "medicine" then
    g.rectangle("fill", cx - 1, cy - 4, 3, 1)
    g.rectangle("fill", cx - 2, cy - 3, 5, 7)
    color(g, fill)
    g.rectangle("fill", cx - 1, cy - 2, 3, 5)
    color(g, active and C.cream or C.orange)
    g.rectangle("fill", cx, cy - 1, 1, 3)
    g.rectangle("fill", cx - 1, cy, 3, 1)
  elseif pocketId == "tms" then
    g.rectangle("fill", cx - 3, cy - 3, 7, 7)
    color(g, fill)
    g.rectangle("fill", cx - 2, cy - 2, 5, 5)
    color(g, C.navy)
    g.rectangle("fill", cx, cy, 1, 1)
    g.rectangle("fill", cx + 2, cy - 2, 1, 2)
  elseif pocketId == "battle" then
    g.rectangle("fill", cx, cy - 4, 1, 9)
    g.rectangle("fill", cx - 4, cy, 9, 1)
    g.rectangle("fill", cx - 2, cy - 2, 5, 5)
    color(g, fill)
    g.rectangle("fill", cx - 1, cy - 1, 3, 3)
  elseif pocketId == "key" then
    g.rectangle("fill", cx - 3, cy - 2, 4, 5)
    g.rectangle("fill", cx, cy, 6, 1)
    g.rectangle("fill", cx + 3, cy, 1, 3)
    g.rectangle("fill", cx + 5, cy, 1, 2)
    color(g, fill)
    g.rectangle("fill", cx - 2, cy - 1, 2, 3)
  elseif pocketId == "berries" then
    g.rectangle("fill", cx - 2, cy - 3, 5, 7)
    g.rectangle("fill", cx - 3, cy - 2, 7, 5)
    g.rectangle("fill", cx, cy - 4, 3, 2)
    color(g, fill)
    g.rectangle("fill", cx - 2, cy - 1, 5, 3)
    color(g, active and C.cream or C.orange)
    g.rectangle("fill", cx, cy, 1, 1)
  else
    -- General items: a compact handled satchel.
    g.rectangle("fill", cx - 1, cy - 4, 3, 2)
    g.rectangle("fill", cx - 3, cy - 2, 7, 6)
    color(g, fill)
    g.rectangle("fill", cx - 2, cy - 1, 5, 4)
    color(g, active and C.cream or C.orange)
    g.rectangle("fill", cx, cy, 1, 2)
  end
end

local function normalizePocketIconId(pocketId)
  pocketId = tostring(pocketId or "items"):lower()
  if pocketId == "ball" or pocketId == "poke_balls" then return "balls" end
  if pocketId == "tm" or pocketId == "hm" or pocketId == "tms_hms" then
    return "tms"
  end
  if pocketId == "battle_items" then return "battle" end
  if pocketId == "key_items" then return "key" end
  return POCKET_ICON_SLOT[pocketId] and pocketId or "items"
end

local function pocketIconImageOf(config)
  if type(config) ~= "table" then return nil end
  if config.pocketIconImageResolved then return config.pocketIconImage or nil end
  config.pocketIconImageResolved = true
  local image = config.pocketIconImage
  if not image and type(config.loadImage) == "function" then
    local ok, loaded = pcall(config.loadImage, M.POCKET_ICON_ASSET_PATH)
    if ok then image = loaded
    else config.pocketIconImageError = tostring(loaded) end
  end
  if not image then return nil end
  if type(image.setFilter) == "function" then
    pcall(image.setFilter, image, "nearest", "nearest")
  end
  local ok, width, height = pcall(function()
    return image:getWidth(), image:getHeight()
  end)
  if not ok or width ~= M.POCKET_ICON_ATLAS.width
      or height ~= M.POCKET_ICON_ATLAS.height then
    config.pocketIconImageError = "invalid Bag pocket-icon atlas dimensions"
    config.pocketIconImage = nil
    return nil
  end
  config.pocketIconImage = image
  return image
end

local function pocketIconQuadOf(config, g, slot, state)
  if type(g.newQuad) ~= "function" then return nil end
  config.pocketIconQuads = config.pocketIconQuads or {}
  local key = tostring(slot) .. ":" .. tostring(state)
  if config.pocketIconQuads[key] then return config.pocketIconQuads[key] end
  local cell = M.POCKET_ICON_ATLAS.cell
  local ok, quad = pcall(g.newQuad, slot * cell, state * cell, cell, cell,
    M.POCKET_ICON_ATLAS.width, M.POCKET_ICON_ATLAS.height)
  if not ok or not quad then return nil end
  config.pocketIconQuads[key] = quad
  return quad
end

local function drawPocketIconImage(config, g, pocketId, cx, cy, active)
  local image = pocketIconImageOf(config)
  if not image or type(g.draw) ~= "function" then return false end
  local id = normalizePocketIconId(pocketId)
  local state = active == true and 1 or 0
  local quad = pocketIconQuadOf(config, g, POCKET_ICON_SLOT[id], state)
  if not quad then return false end
  local display = clamp(integer(config.pocketIconDisplay,
    M.POCKET_ICON_ATLAS.display), M.POCKET_ICON_ATLAS.display, 34)
  local scale = display / M.POCKET_ICON_ATLAS.cell
  local half = math.floor(display / 2)
  g.setColor(1, 1, 1, 1)
  -- The exact 34px D/P source cell stays untouched in the atlas. Nearest
  -- filtering presents it at 12px on the native 160x144 rail and 24px on the
  -- separately composed wide rail: large enough to retain its bottle/Poke
  -- Ball/disc/star/key identity, but without overlap.
  -- Even-width placement is right-biased so both edge cells remain in-panel.
  return pcall(g.draw, image, quad, pixel(cx) - half + 1, pixel(cy) - half,
    0, scale, scale)
end

local function renderPocketIcon(config, g, pocketId, cx, cy, active)
  if type(config and config.drawPocketIcon) == "function" then
    local ok = pcall(config.drawPocketIcon,
      g, pocketId, pixel(cx), pixel(cy), active == true)
    if ok then return end
  end
  if drawPocketIconImage(config, g, pocketId, cx, cy, active) then return end
  drawPocketIcon(g, pocketId, cx, cy, active)
end

M.drawPocketIcon = drawPocketIcon
M.drawPocketIconImage = drawPocketIconImage
M.renderPocketIcon = renderPocketIcon

local function drawCoast(g)
  color(g, C.sky)
  g.rectangle("fill", 0, 0, M.width, M.height)
  color(g, C.paper)
  g.rectangle("fill", 0, 38, 68, 53)
  color(g, C.skyLight)
  g.rectangle("fill", 0, 42, 68, 49)
  color(g, C.sea)
  for y = 47, 87, 10 do
    g.rectangle("fill", (y % 20 == 7) and 2 or 13, y, 42, 1)
  end
  color(g, C.glass2)
  for y = 51, 81, 10 do
    g.rectangle("fill", (y % 20 == 1) and 10 or 1, y, 36, 1)
  end
  color(g, C.sky)
  g.rectangle("fill", 0, 0, 2, 91)
end

local BAG_PALETTES = {
  red = {
    dark = { 0.35, 0.06, 0.10 },
    mid = { 0.82, 0.16, 0.19 },
    light = { 1.00, 0.45, 0.34 },
  },
  blue = {
    dark = { 0.02, 0.12, 0.31 },
    mid = { 0.09, 0.29, 0.56 },
    light = { 0.39, 0.81, 0.94 },
  },
  green = {
    dark = { 0.03, 0.23, 0.16 },
    mid = { 0.10, 0.53, 0.32 },
    light = { 0.49, 0.84, 0.50 },
  },
}
M.CHARACTER_PALETTES = BAG_PALETTES

local BODY_PALETTES = {
  red = {
    dark = { 0.35, 0.06, 0.10 },
    mid = { 0.82, 0.16, 0.19 },
    light = { 1.00, 0.45, 0.34 },
  },
  blue = {
    dark = { 0.02, 0.12, 0.31 },
    mid = { 0.09, 0.29, 0.56 },
    light = { 0.39, 0.81, 0.94 },
  },
  yellow = {
    dark = { 0.42, 0.27, 0.02 },
    mid = { 0.88, 0.62, 0.05 },
    light = { 1.00, 0.88, 0.27 },
  },
  gold = {
    dark = { 0.34, 0.22, 0.05 },
    mid = { 0.70, 0.49, 0.10 },
    light = { 0.94, 0.75, 0.30 },
  },
  silver = {
    dark = { 0.24, 0.30, 0.39 },
    mid = { 0.55, 0.63, 0.72 },
    light = { 0.87, 0.92, 0.96 },
  },
  crystal = {
    dark = { 0.03, 0.26, 0.31 },
    mid = { 0.16, 0.62, 0.70 },
    light = { 0.55, 0.91, 0.94 },
  },
}
-- ORAS preserves the authored source pixels instead of inventing a palette.
BODY_PALETTES.oras = BODY_PALETTES.gold
M.BODY_PALETTES = BODY_PALETTES

-- Accent inserts and body cloth use two disjoint exact authored swatch masks.
-- Greys, highlights, outlines and alpha cannot enter either mask. Both stay
-- local to Bag draw and the caller's shader is restored after every sprite.
local BAG_RECOLOR_SHADER = [[
extern vec3 bagDark;
extern vec3 bagMid;
extern vec3 bagLight;
extern float recolorAmount;
extern vec3 bodyDark;
extern vec3 bodyMid;
extern vec3 bodyLight;
extern float bodyRecolorAmount;

float exactPaletteColour(vec3 pixel, vec3 paletteColour) {
  vec3 difference = abs(pixel - paletteColour);
  return 1.0 - step(0.006, max(max(difference.r, difference.g), difference.b));
}

vec4 effect(vec4 drawColor, Image texture, vec2 textureCoords, vec2 screenCoords) {
  vec4 pixel = Texel(texture, textureCoords);
  float accentPixel = max(max(max(
    exactPaletteColour(pixel.rgb, vec3(152.0, 56.0, 56.0) / 255.0),
    exactPaletteColour(pixel.rgb, vec3(176.0, 64.0, 64.0) / 255.0)),
    max(
      exactPaletteColour(pixel.rgb, vec3(192.0, 80.0, 64.0) / 255.0),
      exactPaletteColour(pixel.rgb, vec3(224.0, 88.0, 88.0) / 255.0))),
    max(
      exactPaletteColour(pixel.rgb, vec3(232.0, 112.0, 104.0) / 255.0),
      exactPaletteColour(pixel.rgb, vec3(232.0, 160.0, 104.0) / 255.0)));
  float bodyPixel = max(max(max(
    exactPaletteColour(pixel.rgb, vec3(232.0, 208.0, 104.0) / 255.0),
    exactPaletteColour(pixel.rgb, vec3(224.0, 176.0, 88.0) / 255.0)),
    max(
      exactPaletteColour(pixel.rgb, vec3(192.0, 160.0, 64.0) / 255.0),
      exactPaletteColour(pixel.rgb, vec3(160.0, 128.0, 56.0) / 255.0))),
    max(
      exactPaletteColour(pixel.rgb, vec3(136.0, 112.0, 56.0) / 255.0),
      exactPaletteColour(pixel.rgb, vec3(112.0, 88.0, 48.0) / 255.0)));
  float luminance = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
  vec3 lowShade = mix(bagDark, bagMid, smoothstep(0.18, 0.58, luminance));
  vec3 target = mix(lowShade, bagLight, smoothstep(0.58, 0.94, luminance));
  pixel.rgb = mix(pixel.rgb, target, accentPixel * recolorAmount);
  vec3 bodyLowShade = mix(bodyDark, bodyMid,
    smoothstep(0.18, 0.58, luminance));
  vec3 bodyTarget = mix(bodyLowShade, bodyLight,
    smoothstep(0.58, 0.94, luminance));
  pixel.rgb = mix(pixel.rgb, bodyTarget, bodyPixel * bodyRecolorAmount);
  return pixel * drawColor;
}
]]

local SOURCE_ACCENT_COLOURS = {
  { 152, 56, 56 }, { 176, 64, 64 }, { 192, 80, 64 },
  { 224, 88, 88 }, { 232, 112, 104 }, { 232, 160, 104 },
}
M.SOURCE_ACCENT_COLOURS = SOURCE_ACCENT_COLOURS

local SOURCE_BODY_COLOURS = {
  { 232, 208, 104 }, { 224, 176, 88 }, { 192, 160, 64 },
  { 160, 128, 56 }, { 136, 112, 56 }, { 112, 88, 48 },
}
M.SOURCE_BODY_COLOURS = SOURCE_BODY_COLOURS

function M.isAccentSourcePixel(red, green, blue)
  red, green, blue = math.floor(tonumber(red) or -1),
    math.floor(tonumber(green) or -1), math.floor(tonumber(blue) or -1)
  for _, source in ipairs(SOURCE_ACCENT_COLOURS) do
    if red == source[1] and green == source[2] and blue == source[3] then
      return true
    end
  end
  return false
end

function M.isBodySourcePixel(red, green, blue)
  red, green, blue = math.floor(tonumber(red) or -1),
    math.floor(tonumber(green) or -1), math.floor(tonumber(blue) or -1)
  for _, source in ipairs(SOURCE_BODY_COLOURS) do
    if red == source[1] and green == source[2] and blue == source[3] then
      return true
    end
  end
  return false
end

local function normalizeCharacter(value)
  if type(value) == "table" then
    value = value.id or value.character or value.name or value.value
  end
  value = tostring(value or ""):upper()
  if value == "GREEN" or value == "LEAF" then return "green" end
  if value == "BLUE" then return "blue" end
  return "red"
end

local function characterOf(list, config)
  local resolver = config.resolveCharacter
  if resolver == nil then resolver = config.kascCharacter end
  local value = resolver
  if type(resolver) == "function" then
    local ok, result = pcall(resolver, list)
    if ok then value = result else config.characterError = tostring(result) end
  end
  return normalizeCharacter(value)
end

M.normalizeCharacter = normalizeCharacter

local function optionValue(config, key, list, character)
  local value = config[key]
  if type(value) ~= "function" then return value end
  local ok, result = pcall(value, list, character)
  if ok then return result end
  config[key .. "Error"] = tostring(result)
  return nil
end

local function normalizeAccent(value, character)
  character = normalizeCharacter(character)
  value = tostring(value or "auto"):lower()
  if BAG_PALETTES[value] then
    return value
  end
  return character == "green" and "green"
    or character == "blue" and "blue" or "red"
end

local function normalizeBody(value)
  value = tostring(value or "auto"):lower()
  if BODY_PALETTES[value] then return value end
  return "oras"
end

local function normalizeForm(value, character)
  character = normalizeCharacter(character)
  value = tostring(value or "auto"):lower()
  if value == "round" or value == "male" then return "round" end
  if value == "handle" or value == "female" or value == "rectangular" then
    return "handle"
  end
  return character == "green" and "handle" or "round"
end

local function bagChoices(list, config, character)
  return normalizeAccent(optionValue(
      config, "resolveAccent", list, character), character),
    normalizeForm(optionValue(
      config, "resolveForm", list, character), character),
    normalizeBody(optionValue(
      config, "resolveBody", list, character))
end

M.normalizeAccent = normalizeAccent
M.normalizeForm = normalizeForm
M.normalizeBody = normalizeBody

local function resolveBagImage(config)
  if config.imageResolved then return config.image or nil end
  config.imageResolved = true
  local image = config.image
  if not image and type(config.loadImage) == "function" then
    local ok, loaded = pcall(config.loadImage, M.ASSET_PATH)
    if ok then image = loaded else config.imageError = tostring(loaded) end
  end
  if not image then return nil end
  if type(image.setFilter) == "function" then
    pcall(image.setFilter, image, "nearest", "nearest")
  end
  local ok, width, height = pcall(function()
    return image:getWidth(), image:getHeight()
  end)
  if not ok or width < ATLAS.width or height < ATLAS.height then
    config.imageError = "invalid DP Bag atlas dimensions"
    return nil
  end
  config.image = image
  config.imageWidth, config.imageHeight = width, height
  return image
end

local function recolorShader(g, config, character, body)
  if config.shaderFailed or type(g.setShader) ~= "function"
      or type(g.newShader) ~= "function" then return nil end
  if not config.shader then
    local ok, shader = pcall(g.newShader, BAG_RECOLOR_SHADER)
    if not ok or not shader then
      config.shaderFailed = true
      config.shaderError = tostring(shader)
      return nil
    end
    config.shader = shader
  end
  local palette = BAG_PALETTES[character] or BAG_PALETTES.red
  local bodyPalette = BODY_PALETTES[body] or BODY_PALETTES.oras
  local ok, err = pcall(function()
    config.shader:send("bagDark", palette.dark)
    config.shader:send("bagMid", palette.mid)
    config.shader:send("bagLight", palette.light)
    config.shader:send("recolorAmount",
      character == "red" and 0 or 1)
    config.shader:send("bodyDark", bodyPalette.dark)
    config.shader:send("bodyMid", bodyPalette.mid)
    config.shader:send("bodyLight", bodyPalette.light)
    config.shader:send("bodyRecolorAmount", body == "oras" and 0 or 1)
  end)
  if not ok then
    config.shaderFailed = true
    config.shaderError = tostring(err)
    return nil
  end
  return config.shader
end

local function frameQuad(g, config, form, slot)
  if type(g.newQuad) ~= "function" then return nil end
  local key = form .. ":" .. tostring(slot)
  config.quads = config.quads or {}
  if config.quads[key] then return config.quads[key] end
  -- The source sheet's top rectangular handled row is Green's default; the
  -- lower circular row is Red/Blue's default. Form overrides stay independent
  -- from the accent palette.
  local row = form == "handle" and 0 or 1
  local ok, quad = pcall(g.newQuad,
    (slot - 1) * ATLAS.cellWidth, row * ATLAS.cellHeight,
    ATLAS.cellWidth, ATLAS.cellHeight,
    config.imageWidth, config.imageHeight)
  if not ok or not quad then return nil end
  config.quads[key] = quad
  return quad
end

local function drawAtlasFrame(g, config, frame, x, y, alpha, scale)
  local image = resolveBagImage(config)
  if not image or type(g.draw) ~= "function" then return false end
  local quad = frameQuad(g, config, frame.form, frame.slot)
  if not quad then return false end

  local shader = recolorShader(g, config, frame.accent, frame.body)
  local previousKnown, previousShader = false, nil
  if shader and type(g.getShader) == "function" then
    local ok, value = pcall(g.getShader)
    if ok then previousKnown, previousShader = true, value end
  end
  if shader then g.setShader(shader) end
  g.setColor(1, 1, 1, clamp(alpha or 1, 0, 1))
  scale = math.max(1, integer(scale, 1))
  local ok = pcall(g.draw, image, quad,
    math.floor(x + 0.5), math.floor(y + 0.5), 0, scale, scale)
  if shader then
    if previousKnown and previousShader ~= nil then g.setShader(previousShader)
    else g.setShader() end
  end
  return ok
end

local function frameFor(accent, form, body, pocketId)
  return {
    accent = accent,
    body = body,
    form = form,
    slot = SHEET_POCKET_SLOT[pocketId] or SHEET_POCKET_SLOT.items,
    pocketId = pocketId,
  }
end

local function easeOutCubic(value)
  value = clamp(value, 0, 1)
  return 1 - (1 - value) * (1 - value) * (1 - value)
end

local function bagAnimation(config, frame, now)
  if not config.openedAt then config.openedAt = now end
  local token = frame.accent .. ":" .. frame.body .. ":"
    .. frame.form .. ":" .. frame.slot
  if not config.currentFrame then
    config.currentFrame = frame
    config.currentToken = token
  elseif config.currentToken ~= token then
    config.currentFrame = frame
    config.currentToken = token
    config.pocketChangedAt = now
  else
    config.currentFrame = frame
  end

  local opening = clamp((now - config.openedAt) / 0.30, 0, 1)
  local settle = math.floor(-6 * (1 - easeOutCubic(opening)) + 0.5)
  local transition = 1
  local offsetX, offsetY = 0, 0
  if config.pocketChangedAt then
    transition = clamp((now - config.pocketChangedAt) / 0.24, 0, 1)
    local changed = math.max(0, now - config.pocketChangedAt)
    if changed < 0.05 then offsetX = 3
    elseif changed < 0.10 then offsetX = -1
    elseif changed < 0.15 then offsetY = -2 end
  end
  return opening, transition, settle, offsetX, offsetY
end

local function drawDpBag(g, list, config, pocketId,
    character, accent, form, body, now, scale, originX, originY)
  local frame = frameFor(accent, form, body, pocketId)
  local opening, transition, settle, offsetX, offsetY =
    bagAnimation(config, frame, now)
  -- A single-pixel crest keeps the settled Bag alive without ever softening
  -- the 1:1 sprite through fractional scaling or coordinates.
  local idle = opening >= 1 and math.sin(now * 1.7) > 0.72 and -1 or 0
  scale = math.max(1, integer(scale, 1))
  originX, originY = integer(originX, -1), integer(originY, 2)
  local y = originY + (settle + idle) * scale
  -- Always draw one fully opaque source sprite. Pocket changes use only a
  -- short whole-pixel slide/bounce, avoiding a translucent double-Bag ghost.
  local drew = drawAtlasFrame(g, config, config.currentFrame,
    originX + offsetX * scale, y + offsetY * scale, 1, scale)

  list.__vascOrasBagCharacter = character
  list.__vascOrasBagAccent = accent
  list.__vascOrasBagForm = form
  list.__vascOrasBagBody = body
  list.__vascOrasBagSpriteSlot = frame.slot
  list.__vascOrasBagAnimation = {
    opening = opening,
    pocket = transition,
    settleY = settle,
    slideX = offsetX,
    bounceY = offsetY,
    idleY = idle,
    form = frame.form,
  }
  return drew
end

local POCKET_NAMES = {
  items = { en = "ITEMS", de = "GEGENST." },
  medicine = { en = "MEDS", de = "MEDIZ." },
  balls = { en = "BALLS", de = "BÄLLE" },
  tms = { en = "TMs", de = "TMs" },
  battle = { en = "BATTLE", de = "KAMPF" },
  key = { en = "KEY", de = "BASIS" },
}

local function pocketInfo(list, language)
  -- `__pocketIds` on real Useful/KASC lists are ITEM ids in the current
  -- pocket, never pocket metadata.  Only explicit pocket collections count.
  local collection = rawget(list, "__pockets") or rawget(list, "pockets")
  local knownOwner = hasKnownSixPocketOwner(list)
  local count = knownOwner and #POCKET_ORDER or integer(
    rawget(list, "__pocketCount") or rawget(list, "pocketCount"), nil)
  if not count and type(collection) == "table" then count = #collection end
  count = clamp(count or 1, 1, 6)
  local index = clamp(integer(rawget(list, "__pocketIndex")
    or rawget(list, "pocketIndex"), 1), 1, count)
  local entry = not knownOwner and type(collection) == "table"
    and collection[index] or nil
  local id = knownOwner and POCKET_ORDER[index]
    or (type(entry) == "table" and (entry.id or entry.key) or entry)
  id = id or rawget(list, "__pocketId") or rawget(list, "pocketId")
  id = tostring(id or "items"):lower()
  local named = POCKET_NAMES[id]
  local label = (named and named[language])
    or rawget(list, "__pocketLabel") or rawget(list, "pocketLabel")
    or (type(entry) == "table" and (entry.shortLabel or entry.label or entry.name))
    or tr(language, "BAG", "BEUTEL")
  return count, index, tostring(label), id,
    SHEET_POCKET_SLOT[id] or SHEET_POCKET_SLOT.items
end

M.pocketInfo = pocketInfo

local function pocketIdAt(list, index)
  if hasKnownSixPocketOwner(list) then return POCKET_ORDER[index] or "items" end
  local collection = rawget(list, "__pockets") or rawget(list, "pockets")
  local entry = type(collection) == "table" and collection[index] or nil
  local id = type(entry) == "table" and (entry.id or entry.key) or entry
  if id == nil and index == integer(rawget(list, "__pocketIndex")
      or rawget(list, "pocketIndex"), 1) then
    id = rawget(list, "__pocketId") or rawget(list, "pocketId")
  end
  return tostring(id or "items"):lower()
end

M.pocketIdAt = pocketIdAt

local function drawPocketRail(g, config, list, count, active)
  local available = 57
  local step = count > 1 and available / (count - 1) or 0
  for index = 1, count do
    local x = pixel(5 + (index - 1) * step)
    if index == active then
      color(g, C.orange2)
      g.rectangle("fill", x - 4, 83, 9, 9, 2, 2)
    end
    renderPocketIcon(config, g, pocketIdAt(list, index), x, 87,
      index == active)
  end
end

local function splitParagraphs(value)
  local text = tostring(value or ""):gsub("\f", "\n")
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
  return lines
end

local function wrapText(Font, value, budget, maxLines)
  local output = {}
  for _, paragraph in ipairs(splitParagraphs(value)) do
    local line = ""
    for word in paragraph:gmatch("%S+") do
      local candidate = line == "" and word or (line .. " " .. word)
      if fontWidth(Font, candidate) <= budget then
        line = candidate
      else
        if line ~= "" then output[#output + 1] = line end
        line = fontWidth(Font, word) <= budget and word
          or truncate(Font, word, budget)
      end
      if maxLines and #output >= maxLines then break end
    end
    if (not maxLines or #output < maxLines) and line ~= "" then
      output[#output + 1] = line
    elseif paragraph == "" and (not maxLines or #output < maxLines) then
      output[#output + 1] = ""
    end
    if maxLines and #output >= maxLines then break end
  end
  if #output == 0 then output[1] = "" end
  return output
end

local function descriptionScroll(config, key, now, lineCount)
  if config.descriptionKey ~= key then
    config.descriptionKey = key
    config.descriptionChangedAt = now
  end
  local overflow = math.max(0, (lineCount - 3) * 10)
  return pingPongOffset(math.max(0,
    now - (config.descriptionChangedAt or now)), overflow, 1.5, 5)
end

local function resultText(value)
  if type(value) == "string" and value ~= "" then return value end
  if type(value) ~= "table" then return nil end
  if type(value.text) == "string" then return value.text end
  if type(value.description) == "string" then return value.description end
  local lines = {}
  for _, line in ipairs(value) do
    if type(line) == "string" then lines[#lines + 1] = line end
  end
  return #lines > 0 and table.concat(lines, "\n") or nil
end

local function callDescription(provider, item, list)
  if type(provider) ~= "function" then return nil end
  local ok, value = pcall(provider, item, list)
  value = ok and resultText(value) or nil
  if value then return value end
  if item and item.value ~= nil then
    ok, value = pcall(provider, item.value, item, list)
    value = ok and resultText(value) or nil
    if value then return value end
  end
  return nil
end

local function descriptionOf(list, item, config, language)
  local text = callDescription(config.describeItem, item, list)
  if not text and type(rawget(list, "describeItem")) == "function" then
    text = callDescription(rawget(list, "describeItem"), item, list)
  end
  if not text and item then
    text = resultText(item.description) or resultText(item.desc)
    local game = rawget(list, "game")
    local data = type(game) == "table" and game.data or nil
    local definitions = type(data) == "table" and data.items or nil
    local definition = type(definitions) == "table" and definitions[item.value]
    if not text and type(definition) == "table" then
      text = resultText(definition.description) or resultText(definition.desc)
    end
  end
  return text or tr(language, "Choose an item.", "Wähle ein Item.")
end

local function drawMovingLabel(g, Font, value, x, y, budget, selected, time)
  local text = tostring(value or "")
  local width = fontWidth(Font, text)
  if width <= budget or not selected or type(g.setScissor) ~= "function" then
    Font.draw(truncate(Font, text, budget), x, y)
    return
  end
  withScissor(g, x, y, budget, 8, function()
    Font.draw(text, x + pixel(pingPongOffset(
      time, width - budget, 1.5, 8)), y)
  end)
end

local function listWindow(list, count)
  local rows = clamp(integer(rawget(list, "rows") or list.rows, 5), 1, 5)
  local selected = count > 0
    and clamp(integer(rawget(list, "index") or list.index, 1), 1, count) or 1
  local first = clamp(integer(rawget(list, "scroll") or list.scroll, 0) + 1,
    1, math.max(1, count - rows + 1))
  if selected < first then first = selected end
  if selected > first + rows - 1 then first = selected - rows + 1 end
  first = clamp(first, 1, math.max(1, count - rows + 1))
  return first, rows, selected
end

local function moneyText(list)
  local value
  if type(rawget(list, "money")) == "function" then
    local ok, result = pcall(rawget(list, "money"))
    if ok then value = result end
  end
  if value == nil then
    local game = rawget(list, "game")
    local save = type(game) == "table" and game.save or nil
    value = type(save) == "table" and save.money or nil
  end
  value = tonumber(value)
  return value and ("¥%d"):format(math.max(0, math.floor(value))) or nil
end

local function drawWideCoast(g)
  color(g, C.sky)
  g.rectangle("fill", 0, 0, M.WIDE_WIDTH, M.WIDE_HEIGHT)
  color(g, C.skyLight)
  g.rectangle("fill", 0, 184, M.WIDE_WIDTH, 104)
  color(g, C.sea)
  g.rectangle("fill", 0, 210, M.WIDE_WIDTH, 78)
  color(g, C.glass2)
  for _, cloud in ipairs({
      { 18, 30, 86, 16 }, { 91, 20, 132, 18 },
      { 348, 24, 108, 17 }, { 434, 39, 61, 13 },
    }) do
    g.rectangle("fill", cloud[1], cloud[2], cloud[3], cloud[4], 8, 8)
  end
  color(g, C.skyLight)
  for y = 222, 282, 15 do
    g.rectangle("fill", 10 + (y * 3) % 47, y, 116, 2)
    g.rectangle("fill", 292 + (y * 5) % 61, y + 5, 142, 2)
  end
end

local function wideListWindow(list, count, rows)
  rows = math.max(1, integer(rows, 9))
  local selected = count > 0
    and clamp(integer(rawget(list, "index") or list.index, 1), 1, count) or 1
  -- Native owns a shorter controller window. Deriving the wider presentation
  -- from its authoritative selection avoids scrolling the nine-row view two
  -- rows before the cursor actually reaches its bottom.
  local first = clamp(selected - rows + 1,
    1, math.max(1, count - rows + 1))
  return first, rows, selected
end

-- A separately authored 512x288 surface. The Bag and pocket artwork use
-- nearest-neighbour integer presentation, while every panel and text budget
-- is recomposed for widescreen; no 160x144 canvas is stretched.
local function drawWidePresentation(list, config)
  local loveRef = loveRuntime()
  local g = loveRef and loveRef.graphics
  local Font = config.Font or safeRequire("src.render.Font")
  if type(g) ~= "table" or type(g.setColor) ~= "function"
      or type(g.rectangle) ~= "function"
      or type(Font) ~= "table" or type(Font.draw) ~= "function"
      or type(Font.width) ~= "function" then
    error("D/P ORAS WIDE Bag graphics are unavailable", 0)
  end
  local items = rawget(list, "items") or list.items
  if type(items) ~= "table" then
    error("D/P ORAS WIDE Bag items are unavailable", 0)
  end

  local language = languageOf(list, config)
  local pocketCount, pocketIndex, pocketLabel, pocketId =
    pocketInfo(list, language)
  local character = characterOf(list, config)
  local accent, form, body = bagChoices(list, config, character)
  local now = timeNow()
  config.pocketIconDisplay = 24

  drawWideCoast(g)
  panel(g, 12, 10, 488, 34, C.navy, C.paper, 5)
  color(g, C.orange)
  g.rectangle("fill", 15, 13, 4, 28, 2, 2)
  color(g, C.ink)
  Font.draw("D/P ORAS WIDE", 28, 23)
  local title = truncate(Font, localizedBagTitle(rawget(list, "title")
    or list.title or tr(language, "BAG", "BEUTEL"), language), 188)
  Font.draw(title, 170, 23)
  local money = moneyText(list)
  if money then Font.draw(truncate(Font, money, 112),
    488 - fontWidth(Font, truncate(Font, money, 112)), 23) end

  panel(g, 12, 52, 160, 142, C.navy, C.glass2, 6)
  if not drawDpBag(g, list, config, pocketId,
      character, accent, form, body, now, 2, 20, 58) then
    error("D/P ORAS WIDE Bag atlas frame is unavailable", 0)
  end
  panel(g, 12, 200, 160, 39, C.navy, C.cream, 5)
  local railStep = pocketCount > 1 and 132 / (pocketCount - 1) or 0
  for index = 1, pocketCount do
    local x = pixel(26 + (index - 1) * railStep)
    if index == pocketIndex then
      color(g, C.orange2)
      g.rectangle("fill", x - 14, 205, 28, 29, 5, 5)
    end
    renderPocketIcon(config, g, pocketIdAt(list, index), x, 219,
      index == pocketIndex)
  end
  panel(g, 12, 245, 160, 31, C.navy, C.paper, 4)
  color(g, C.orange)
  g.rectangle("fill", 16, 249, 3, 23, 1, 1)
  color(g, C.ink)
  Font.draw(tr(language, "L/R POCKET", "L/R FACH"), 25, 250)
  Font.draw(tr(language, "A OK  B BACK", "A OK  B ZUR."), 25, 262)

  panel(g, 184, 52, 316, 153, C.navy, C.paper, 6)
  color(g, C.orange)
  g.rectangle("fill", 188, 56, 308, 24, 4, 4)
  renderPocketIcon(config, g, pocketId, 204, 68, true)
  color(g, C.ink)
  local countText = tostring(pocketIndex) .. "/" .. tostring(pocketCount)
  local countX = 488 - fontWidth(Font, countText)
  Font.draw(truncate(Font, pocketLabel, math.max(16, countX - 228)), 222, 64)
  Font.draw(countText, countX, 64)

  local count = #items
  local first, rows, selected = wideListWindow(list, count, 9)
  if count == 0 then
    renderPokeBall(config, g, 300, 139, 12, false, true)
    color(g, C.ink)
    Font.draw(tr(language, "THIS POCKET IS EMPTY", "DIESES FACH IST LEER"),
      325, 135)
  else
    for row = 1, rows do
      local index = first + row - 1
      local item = items[index]
      if not item then break end
      local y = 87 + (row - 1) * 12
      local active = index == selected
      if active then
        color(g, C.orange2)
        g.rectangle("fill", 190, y - 2, 303, 11, 3, 3)
      end
      local right = truncate(Font, tostring(item.right or ""), 64)
      local rightWidth = right ~= "" and fontWidth(Font, right) or 0
      local rightX = 487 - rightWidth
      local labelX = 204
      local budget = math.max(16, rightX - labelX
        - (right ~= "" and 8 or 0))
      local swapped = rawget(list, "swapIndex") == index
      if active or swapped then
        renderPokeBall(config, g, 197, y + 3, 3,
          active, swapped and not active)
      end
      local tickerKey = pocketId .. ":wide:" .. tostring(index) .. ":"
        .. tostring(item.label or item.value or "")
      if active and config.itemTickerKey ~= tickerKey then
        config.itemTickerKey, config.itemTickerChangedAt = tickerKey, now
      end
      color(g, C.ink)
      drawMovingLabel(g, Font, item.label or item.value or "", labelX, y,
        budget, active, now - (config.itemTickerChangedAt or now))
      if right ~= "" then
        if active then
          color(g, C.paper)
          g.rectangle("fill", rightX - 2, y - 1, rightWidth + 4, 9, 2, 2)
          color(g, C.ink)
        end
        Font.draw(right, rightX, y)
      end
    end
    if count > rows then
      color(g, C.sea)
      g.rectangle("fill", 494, 86, 2, 108)
      local thumb = math.max(10, math.floor(108 * rows / count))
      local progress = count > 1 and (selected - 1) / (count - 1) or 0
      color(g, C.orange)
      g.rectangle("fill", 493, 86 + math.floor((108 - thumb) * progress),
        4, thumb, 2, 2)
    end
  end

  panel(g, 184, 211, 316, 65, C.navy, C.cream, 6)
  color(g, C.orange)
  g.rectangle("fill", 189, 216, 4, 54, 2, 2)
  color(g, C.ink)
  Font.draw(tr(language, "ITEM HELP", "GEGENSTAND-HILFE"), 201, 217)
  local item = count > 0 and items[selected] or nil
  local description = item and descriptionOf(list, item, config, language)
    or tr(language, "This pocket is empty.", "Dieses Fach ist leer.")
  local lines = wrapText(Font, description, 286)
  local descriptionKey = pocketId .. ":wide:" .. tostring(selected) .. ":"
    .. tostring(item and item.value or "empty") .. ":" .. description
  if config.descriptionKey ~= descriptionKey then
    config.descriptionKey, config.descriptionChangedAt = descriptionKey, now
  end
  local verticalOffset = pixel(pingPongOffset(math.max(0,
    now - (config.descriptionChangedAt or now)),
    math.max(0, (#lines - 4) * 10), 1.5, 5))
  withScissor(g, 200, 229, 288, 40, function()
    for index, line in ipairs(lines) do
      Font.draw(truncate(Font, line, 286), 201,
        230 + (index - 1) * 10 + verticalOffset)
    end
  end)

  list.__vascOrasBagPocketCount = pocketCount
  list.__vascOrasBagPocketId = pocketId
  list.__vascOrasBagWidePresentation = true
  list.__vascOrasBagLayoutWidth = M.WIDE_WIDTH
  list.__vascOrasBagLayoutHeight = M.WIDE_HEIGHT
  local PaletteFX = config.PaletteFX or safeRequire("src.render.PaletteFX")
  if PaletteFX and type(PaletteFX.markTrueColor) == "function" then
    pcall(PaletteFX.markTrueColor, 0, 0, M.WIDE_WIDTH, M.WIDE_HEIGHT)
  end
end

local function drawPresentation(list, config)
  local loveRef = loveRuntime()
  local g = loveRef and loveRef.graphics
  local Font = config.Font or safeRequire("src.render.Font")
  if type(g) ~= "table" or type(g.setColor) ~= "function"
      or type(g.rectangle) ~= "function"
      or type(Font) ~= "table" or type(Font.draw) ~= "function"
      or type(Font.width) ~= "function" then
    error("ORAS Bag graphics are unavailable", 0)
  end

  local items = rawget(list, "items") or list.items
  if type(items) ~= "table" then error("ORAS Bag items are unavailable", 0) end
  local language = languageOf(list, config)
  local pocketCount, pocketIndex, pocketLabel, pocketId =
    pocketInfo(list, language)
  local now = timeNow()
  local character = characterOf(list, config)
  local accent, form, body = bagChoices(list, config, character)

  drawCoast(g)
  panel(g, 1, 1, 67, 66, C.navy, C.glass2, 4)
  if not drawDpBag(g, list, config, pocketId,
      character, accent, form, body, now) then
    error("D/P ORAS Bag atlas frame is unavailable", 0)
  end
  list.__vascOrasBagPocketCount = pocketCount
  list.__vascOrasBagPocketId = pocketId

  -- The engine font is a dark bitmap texture, so every text-bearing strip is
  -- deliberately paper/cream rather than relying on a shader recolour.
  panel(g, 2, 68, 65, 13, C.navy, C.cream, 3)
  color(g, C.orange)
  g.rectangle("fill", 3, 79, 63, 2)
  color(g, C.ink)
  Font.draw(truncate(Font, pocketLabel, 54), 7, 70)
  drawPocketRail(g, config, list, pocketCount, pocketIndex)

  panel(g, 69, 1, 89, 18, C.navy, C.cream, 2)
  color(g, C.gold)
  g.rectangle("fill", 71, 3, 2, 14)
  color(g, C.orange)
  g.rectangle("fill", 71, 17, 87, 2)
  color(g, C.ink)
  Font.draw(truncate(Font, localizedBagTitle(rawget(list, "title")
    or list.title or tr(language, "BAG", "BEUTEL"), language), 76), 76, 5)

  panel(g, 69, 21, 89, 68, C.navy, C.paper, 4)
  local count = #items
  local first, rows, selected = listWindow(list, count)
  if count == 0 then
    renderPokeBall(config, g, 88, 54, 8, false, true)
    color(g, C.ink)
    Font.draw(tr(language, "EMPTY", "FACH"), 105, 46)
    if language == "de" then Font.draw("LEER", 109, 57) end
  else
    local rowHeight = math.floor(60 / rows)
    rowHeight = clamp(rowHeight, 12, 15)
    for row = 1, rows do
      local index = first + row - 1
      local item = items[index]
      if not item then break end
      local y = 25 + (row - 1) * rowHeight
      local active = index == selected
      if active then
        color(g, C.orange2)
        g.rectangle("fill", 72, y - 2, 83, 11, 3, 3)
        color(g, C.cream)
        g.rectangle("fill", 81, y + 8, 70, 1)
      end
      local right = truncate(Font, tostring(item.right or ""), 32)
      local rightWidth = right ~= "" and fontWidth(Font, right) or 0
      local rightX = 153 - rightWidth
      local labelX = 81
      local labelBudget = math.max(8, rightX - labelX - (right ~= "" and 2 or 0))
      local swapped = rawget(list, "swapIndex") == index
      if active or swapped then
        renderPokeBall(config, g, 77, y + 3, 3,
          active, swapped and not active)
      end
      color(g, active and C.navy or C.ink)
      local tickerKey = pocketId .. ":" .. tostring(index) .. ":"
        .. tostring(item.label or item.value or "")
      if active and config.itemTickerKey ~= tickerKey then
        config.itemTickerKey = tickerKey
        config.itemTickerChangedAt = now
      end
      drawMovingLabel(g, Font, item.label or item.value or "", labelX, y,
        labelBudget, active,
        now - (config.itemTickerChangedAt or now))
      if right ~= "" then
        if active then
          color(g, C.paper)
          g.rectangle("fill", rightX - 1, y - 1, rightWidth + 2, 9, 2, 2)
          color(g, C.ink)
        end
        Font.draw(right, rightX, y)
      end
    end

    if count > rows then
      local trackY, trackH = 25, 58
      color(g, C.sea)
      g.rectangle("fill", 156, trackY, 1, trackH)
      local thumbH = math.max(5, math.floor(trackH * rows / count))
      local progress = count > 1 and (selected - 1) / (count - 1) or 0
      color(g, C.orange)
      g.rectangle("fill", 155, trackY + math.floor((trackH - thumbH) * progress),
        3, thumbH, 1, 1)
    end
  end

  panel(g, 2, 92, 156, 50, C.navy, C.cream, 4)
  local item = count > 0 and items[selected] or nil
  color(g, C.orange)
  g.rectangle("fill", 5, 95, 3, 29, 1, 1)
  color(g, C.ink)
  local description = item and descriptionOf(list, item, config, language)
    or tr(language, "This pocket is empty.", "Dieses Fach ist leer.")
  local lines = wrapText(Font, description, 140)
  local descriptionKey = pocketId .. ":" .. tostring(selected) .. ":"
    .. tostring(item and item.value or "empty") .. ":" .. description
  local verticalOffset = pixel(descriptionScroll(
    config, descriptionKey, now, #lines))
  withScissor(g, 10, 95, 142, 30, function()
    for index, line in ipairs(lines) do
      Font.draw(truncate(Font, line, 140), 11,
        96 + (index - 1) * 10 + verticalOffset)
    end
  end)

  panel(g, 4, 127, 152, 12, C.navy, C.paper, 2)
  color(g, C.orange)
  g.rectangle("fill", 6, 129, 2, 8)
  color(g, C.ink)
  local money = moneyText(list)
  if money then money = truncate(Font, money, 48) end
  local moneyX = money and (152 - fontWidth(Font, money)) or 152
  local hint = tr(language, "A OK  B BACK", "A OK  B ZUR.")
  Font.draw(truncate(Font, hint, math.max(8, moneyX - 13)), 10, 130)
  if money then Font.draw(money, moneyX, 130) end

  -- Keep the authored colors out of the optional Game Boy palette shader
  -- without replacing the list's palette-provider method.
  local PaletteFX = config.PaletteFX or safeRequire("src.render.PaletteFX")
  if PaletteFX and type(PaletteFX.markTrueColor) == "function" then
    pcall(PaletteFX.markTrueColor, 0, 0, M.width, M.height)
  end
end

function M.decorate(list, opts)
  opts = type(opts) == "table" and opts or {}
  local allowed, reason, marker = M.canDecorate(list, opts)
  if not allowed then return list, false, reason, marker end

  local nativeDraw = rawget(list, "draw") or list.draw
  local config = {
    describeItem = opts.describeItem,
    enabled = opts.enabled,
    language = opts.language,
    image = opts.image,
    loadImage = opts.loadImage,
    resolveCharacter = opts.resolveCharacter,
    kascCharacter = opts.kascCharacter,
    resolveAccent = opts.resolveAccent ~= nil and opts.resolveAccent
      or opts.bagColor or opts.accent,
    resolveForm = opts.resolveForm ~= nil and opts.resolveForm
      or opts.bagForm or opts.form,
    resolveBody = opts.resolveBody ~= nil and opts.resolveBody
      or opts.bagBody or opts.body,
    drawPokeBall = opts.drawPokeBall,
    drawPocketIcon = opts.drawPocketIcon,
    pocketIconImage = opts.pocketIconImage,
    Font = opts.Font, -- dependency injection for headless contract tests
    PaletteFX = opts.PaletteFX,
    wide = opts.wide == true,
  }

  list.__vascOrasBagNativeDraw = nativeDraw
  list.__vascOrasBagConfig = config
  list.__vascOrasBagForced = opts.force == true
  list.__vascOrasBagOwner = M.owner
  list.__vascOrasBagPresentation = true
  list.__vascOrasBagSkin = true
  list.__vascOrasBagAssetPath = M.ASSET_PATH
  list.__vascOrasBagPocketIconAssetPath = M.POCKET_ICON_ASSET_PATH
  list.__vascOrasBagWidePresentation = config.wide
  list.__vascOrasBagLayoutWidth = config.wide and M.WIDE_WIDTH or M.WIDTH
  list.__vascOrasBagLayoutHeight = config.wide and M.WIDE_HEIGHT or M.HEIGHT
  list.__ascendantOrasBag = true
  -- If the global native-box skin sees this state after decoration, this
  -- explicit owner flag prevents two presentation layers from stacking.
  list.__ascendantGlobalUiSkinSkip = true

  local nativeUiSize = rawget(list, "uiSize") or list.uiSize
  local nativeDrawsWidescreen = rawget(list, "drawsWidescreen")
    or list.drawsWidescreen
  local nativeWantsFillScale = rawget(list, "wantsFillScale")
    or list.wantsFillScale
  local nativeIsWideBattleLayout = rawget(list, "isWideBattleLayout")
    or list.isWideBattleLayout
  local nativeSgbPalettes = rawget(list, "sgbPalettes") or list.sgbPalettes

  local function enabledFor(self, liveConfig)
    if liveConfig.enabled == nil then return true end
    if type(liveConfig.enabled) ~= "function" then
      return liveConfig.enabled == true
    end
    local ok, value = pcall(liveConfig.enabled, self)
    if ok then return value == true end
    self.__vascOrasBagLastError = tostring(value)
    return false
  end

  local function wideEnabledFor(self, liveConfig)
    if not liveConfig.wide or liveConfig.wideFailed then return false end
    if not enabledFor(self, liveConfig) then return false end
    if not rawget(self, "__vascOrasBagForced")
        and externalOwnerOf(self) then return false end
    if not resolveBagImage(liveConfig) then
      self.__vascOrasBagLastError = liveConfig.imageError
        or "D/P ORAS Bag atlas is unavailable"
      liveConfig.wideFailed = true
      self.__vascOrasBagWidePresentation = false
      self.__vascOrasBagLayoutWidth = M.WIDTH
      self.__vascOrasBagLayoutHeight = M.HEIGHT
      return false
    end
    local loveRef = loveRuntime()
    local graphics = loveRef and loveRef.graphics
    local _, layerError = resolveWideLayer(liveConfig, graphics)
    if layerError then
      self.__vascOrasBagLastError = layerError
      liveConfig.wideFailed = true
      self.__vascOrasBagWidePresentation = false
      self.__vascOrasBagLayoutWidth = M.WIDTH
      self.__vascOrasBagLayoutHeight = M.HEIGHT
      return false
    end
    return true
  end

  if config.wide then
    list.uiSize = function(self, ...)
      local live = rawget(self, "__vascOrasBagConfig") or config
      if wideEnabledFor(self, live) then
        return M.WIDE_WIDTH, M.WIDE_HEIGHT
      end
      if type(nativeUiSize) == "function" then return nativeUiSize(self, ...) end
      return M.WIDTH, M.HEIGHT
    end
    list.drawsWidescreen = function(self, ...)
      local live = rawget(self, "__vascOrasBagConfig") or config
      if wideEnabledFor(self, live) then return true end
      if type(nativeDrawsWidescreen) == "function" then
        local ok, value = pcall(nativeDrawsWidescreen, self, ...)
        return ok and value == true
      end
      return false
    end
    list.wantsFillScale = function(self, ...)
      local live = rawget(self, "__vascOrasBagConfig") or config
      if wideEnabledFor(self, live) then return true end
      if type(nativeWantsFillScale) == "function" then
        local ok, value = pcall(nativeWantsFillScale, self, ...)
        return ok and value == true
      end
      return false
    end
    list.isWideBattleLayout = function(self, ...)
      local live = rawget(self, "__vascOrasBagConfig") or config
      if wideEnabledFor(self, live) and battleBelow(self) then return true end
      if type(nativeIsWideBattleLayout) == "function" then
        local ok, value = pcall(nativeIsWideBattleLayout, self, ...)
        return ok and value == true
      end
      return false
    end
    list.sgbPalettes = function(self, ...)
      local live = rawget(self, "__vascOrasBagConfig") or config
      if wideEnabledFor(self, live) then
        return { { colors=false, x=0, y=0,
          w=M.WIDE_WIDTH, h=M.WIDE_HEIGHT } }
      end
      if type(nativeSgbPalettes) == "function" then
        return nativeSgbPalettes(self, ...)
      end
      return nil
    end
  end

  list.draw = function(self, ...)
    local args = packed(...)
    local liveConfig = rawget(self, "__vascOrasBagConfig") or config
    if liveConfig.wide then
      if not wideEnabledFor(self, liveConfig) then
        return nativeDraw(self, unpackValues(args, 1, args.n))
      end
      local loveRef = loveRuntime()
      local graphics = loveRef and loveRef.graphics
      local state = type(graphics) == "table" and graphicsState(graphics) or nil
      local ok, returned = drawWideAtomically(liveConfig, graphics, function()
        return drawWidePresentation(self, liveConfig)
      end)
      if state then restoreGraphics(graphics, state) end
      if ok then return unpackValues(returned, 1, returned.n) end
      self.__vascOrasBagLastError = tostring(returned)
      liveConfig.wideFailed = true
      self.__vascOrasBagWidePresentation = false
      self.__vascOrasBagLayoutWidth = M.WIDTH
      self.__vascOrasBagLayoutHeight = M.HEIGHT
      local fallbackOk, fallbackReturned = drawNativeWideFallback(
        liveConfig, graphics, function()
          return nativeDraw(self, unpackValues(args, 1, args.n))
        end)
      if fallbackOk then
        return unpackValues(fallbackReturned, 1, fallbackReturned.n)
      end
      self.__vascOrasBagLastError = tostring(returned) .. "\n"
        .. tostring(fallbackReturned)
      return nil
    end
    if not enabledFor(self, liveConfig) then
      return nativeDraw(self, unpackValues(args, 1, args.n))
    end
    if not rawget(self, "__vascOrasBagForced") then
      local external = externalOwnerOf(self)
      if external then
        return nativeDraw(self, unpackValues(args, 1, args.n))
      end
    end

    -- Never invent a replacement silhouette when the private test asset is
    -- missing or corrupt. Yield before VASC paints any furniture so the
    -- provider's exact KASC/Useful/native renderer stays usable.
    if not resolveBagImage(liveConfig) then
      self.__vascOrasBagLastError = liveConfig.imageError
        or "D/P ORAS Bag atlas is unavailable"
      return nativeDraw(self, unpackValues(args, 1, args.n))
    end

    local loveRef = loveRuntime()
    local graphics = loveRef and loveRef.graphics
    local state = type(graphics) == "table" and graphicsState(graphics) or nil
    local returned
    local ok, err = xpcall(function()
      returned = packed(drawPresentation(self, liveConfig))
    end, traceback)
    if state then restoreGraphics(graphics, state) end
    if ok then return unpackValues(returned, 1, returned.n) end

    self.__vascOrasBagLastError = tostring(err)
    return nativeDraw(self, unpackValues(args, 1, args.n))
  end

  if config.wide then list.drawWidescreen = list.draw end

  return list, true, M.owner
end

return M
