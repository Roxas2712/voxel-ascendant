-- Optional quality-of-life helpers for Gold/Silver/Crystal.
--
-- The native Gen-2 World remains authoritative. This module reads map/save
-- state for a responsive location banner and, when enabled, lets an otherwise
-- unused A press in front of water use the best owned fishing rod. It never
-- grants an item/move/badge, bypasses SURF, changes a warp, or mutates battle
-- state beyond what World:useRod already owns.

local C = ... or {}
local mod = C.mod

local M = {
  installed = false,
  bannerDraws = 0,
  easyFishingUses = 0,
  lastError = nil,
}

local banners = setmetatable({}, { __mode = "k" })
local lastNames = setmetatable({}, { __mode = "k" })
local RODS = { "SUPER_ROD", "GOOD_ROD", "OLD_ROD" }
local unpackValues = table.unpack or unpack

local function pack(...)
  return { n = select("#", ...), ... }
end

local function option(key, fallback)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  return value
end

local function enabled(key)
  local value = option(key, false)
  local text = tostring(value):lower()
  return value == true or value == 1 or value == "1"
    or text == "true" or text == "on"
end

local function now()
  local timer = love and love.timer
  if timer and type(timer.getTime) == "function" then
    local ok, value = pcall(timer.getTime)
    if ok and tonumber(value) then return tonumber(value) end
  end
  return os.clock()
end

local function currentWorld(payload)
  local game = type(payload) == "table" and payload.game or nil
  game = game or (mod and mod.world and mod.world.game)
  local api = mod and mod.world
  if api and type(api.overworld) == "function" then
    local ok, world = pcall(api.overworld, api)
    if ok and type(world) == "table" then return world, game or world.game end
  end
  return nil, game
end

local function cleanName(value)
  value = tostring(value or ""):gsub("_", " ")
  value = value:gsub("(%l)(%u)", "%1 %2")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return value ~= "" and value:upper() or "UNKNOWN AREA"
end

local function locationName(game, mapId, map)
  local data = game and game.data
  local field = data and data.field
  local townMap = field and field.townMap
  local locations = townMap and (townMap.locations or townMap.landmarks or townMap)
  local entry = type(locations) == "table" and locations[mapId] or nil
  local name = type(entry) == "table" and (entry.name or entry.label) or nil
  local def = map and map.def
    or (data and data.maps and data.maps[mapId])
  name = name or (type(def) == "table" and (def.label or def.name))
  return cleanName(name or mapId)
end

local function duration()
  local value = tonumber(option("qolLocationBanners", false))
  if not value or value <= 0 then return nil end
  return math.max(1, math.min(3, value))
end

local function bannerAllowed(world)
  if not world then return false end
  if type(world.busy) == "function" then
    local ok, busy = pcall(world.busy, world)
    if ok and busy then return false end
  end
  return world.battleActive ~= true and world.flyAnim == nil
end

local function drawBanner(world)
  local state = banners[world]
  if not state or not duration() or now() >= state.expiresAt then
    banners[world] = nil
    return
  end
  if not bannerAllowed(world) then return end
  local G = love and love.graphics
  if not (G and type(G.getDimensions) == "function"
      and type(G.rectangle) == "function" and type(G.printf) == "function") then
    return
  end
  local w, h = G.getDimensions()
  local panelW = math.min(w * 0.62, 760)
  local panelH = math.max(54, math.min(86, h * 0.085))
  local x, y = (w - panelW) * 0.5, math.max(18, h * 0.035)
  local pushed = false
  if type(G.push) == "function" then
    local okPush = pcall(G.push, "all")
    pushed = okPush == true
  end
  local ok, err = pcall(function()
    if type(G.origin) == "function" then G.origin() end
    G.setColor(0.005, 0.018, 0.035, 0.88)
    G.rectangle("fill", x, y, panelW, panelH, 14, 14)
    G.setColor(0.10, 0.75, 0.95, 0.96)
    if type(G.setLineWidth) == "function" then G.setLineWidth(2) end
    G.rectangle("line", x, y, panelW, panelH, 14, 14)
    G.setColor(1, 1, 1, 0.98)
    local font = type(G.getFont) == "function" and G.getFont() or nil
    local fontH = font and font:getHeight() or 16
    G.printf(state.name, x + 20, y + (panelH - fontH) * 0.5,
      panelW - 40, "center")
  end)
  if pushed then pcall(G.pop) end
  if ok then
    M.bannerDraws = M.bannerDraws + 1
  else
    M.lastError = tostring(err)
  end
end

local function bestRod(world)
  local save = world and world.game and world.game.save
  local inventory = save and save.inventory
  if type(inventory) ~= "table" then return nil end
  for _, id in ipairs(RODS) do
    local value = inventory[id]
    local count = type(value) == "table" and tonumber(value.count or value.quantity)
      or tonumber(value)
    if count and count > 0 then return id end
  end
  return nil
end

local function facingWater(world)
  if not (world and type(world.fieldContext) == "function") then return false end
  local okCtx, ctx = pcall(world.fieldContext, world)
  if not (okCtx and type(ctx) == "table") then return false end
  local okPermissions, Permissions = pcall(require, "src.world.gen2.Permissions")
  if not (okPermissions and Permissions and type(Permissions.isWater) == "function") then
    return false
  end
  local okWater, water = pcall(Permissions.isWater, ctx.facingColl)
  return okWater and water == true
end

local function installWorldHooks(World)
  local bridge = rawget(World, "__vascGen2Comfort")
  if type(bridge) ~= "table" then
    bridge = { originalDraw=World.draw, originalInteract=World.interact }
    if type(bridge.originalDraw) == "function" then
      World.draw = function(world, ...)
        local results = pack(bridge.originalDraw(world, ...))
        local provider = bridge.provider
        if provider and type(provider.drawBanner) == "function" then
          pcall(provider.drawBanner, world)
        end
        return unpackValues(results, 1, results.n)
      end
    end
    if type(bridge.originalInteract) == "function" then
      World.interact = function(world, ...)
        local results = pack(bridge.originalInteract(world, ...))
        if results[1] then return unpackValues(results, 1, results.n) end
        local provider = bridge.provider
        if provider and type(provider.easyInteract) == "function" then
          local ok, handled = pcall(provider.easyInteract, world)
          if ok and handled then return true end
        end
        return unpackValues(results, 1, results.n)
      end
    end
    World.__vascGen2Comfort = bridge
  end
  bridge.provider = {
    owner=M,
    drawBanner=drawBanner,
    easyInteract=function(world)
      if not enabled("qolEasyInteractions") or not facingWater(world) then
        return false
      end
      local rod = bestRod(world)
      if not rod or type(world.useRod) ~= "function" then return false end
      local outcome = world:useRod(rod)
      if outcome == nil or outcome == false or outcome == "nowhere" then
        return false
      end
      M.easyFishingUses = M.easyFishingUses + 1
      return true
    end,
  }
  return true
end

function M.install()
  if M.installed then return true end
  local okWorld, World = pcall(require, "src.world.gen2.World")
  if not (okWorld and type(World) == "table") then
    M.lastError = "Gen-2 World unavailable"
    return false, M.lastError
  end
  installWorldHooks(World)
  if mod and mod.events and type(mod.events.on) == "function" then
    mod.events:on("map.entered", function(event)
      local world, game = currentWorld(event)
      local seconds = duration()
      if not (world and seconds and event and event.mapId) then
        if world then banners[world] = nil end
        return
      end
      local name = locationName(game or world.game, event.mapId, event.map)
      if lastNames[world] == name then return end
      lastNames[world] = name
      banners[world] = { name=name, expiresAt=now() + seconds }
    end)
    mod.events:on("mod.options_changed", function(event)
      if type(event) ~= "table" or event.key ~= "qolLocationBanners" then return end
      if event.mod ~= nil and event.mod ~= mod.id then return end
      if duration() == nil then
        for world in pairs(banners) do banners[world] = nil end
      end
    end)
  end
  M.installed = true
  M.lastError = nil
  return true
end

function M.status()
  return {
    installed=M.installed,
    locationBanner=duration() ~= nil,
    easyInteractions=enabled("qolEasyInteractions"),
    bannerDraws=M.bannerDraws,
    easyFishingUses=M.easyFishingUses,
    nativeRules=true,
    lastError=M.lastError,
  }
end

return M
