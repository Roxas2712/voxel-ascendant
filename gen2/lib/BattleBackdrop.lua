-- Location-aware full-frame battle paintings for Gold/Silver/Crystal.
--
-- Map assignments live exclusively in gen2/data/arena_scenery.lua.  This
-- resolver deliberately knows no Johto map names itself, so an Injector pack
-- can extend or replace the catalog without changing battle code.  The
-- native game still owns encounters and rules; this module only returns a
-- portable presentation arena.

local V = ...
local BattleBackdrop = {}

local okCatalog, catalog = pcall(V.data, "arena_scenery")
if not okCatalog or type(catalog) ~= "table" then catalog = {} end

local function mapId(map)
  local id = map and (map.id or (map.def and map.def.id))
  return type(id) == "string" and string.upper(id) or ""
end

local function environment(map)
  local value = map and (map.environment or (map.def and map.def.environment))
  return type(value) == "string" and string.upper(value) or ""
end

local function validSpec(spec)
  if type(spec) ~= "table" or type(spec.path) ~= "string"
      or spec.path == "" then return false end
  if spec.width ~= nil and spec.width ~= 1280 then return false end
  if spec.height ~= nil and spec.height ~= 800 then return false end
  if spec.outdoor ~= nil and type(spec.outdoor) ~= "boolean" then return false end
  if spec.voxelSky ~= nil and type(spec.voxelSky) ~= "boolean" then return false end
  return true
end

function BattleBackdrop.resolve(map)
  local id = mapId(map)
  local maps = type(catalog.maps) == "table" and catalog.maps or {}
  local key = maps[id]
  if not key then
    for _, rule in ipairs(type(catalog.rules) == "table" and catalog.rules or {}) do
      if type(rule) == "table" then
        local prefixOk = not rule.prefix
          or id:sub(1, #tostring(rule.prefix)) == tostring(rule.prefix)
        local containsOk = not rule.contains
          or id:find(tostring(rule.contains), 1, true) ~= nil
        if prefixOk and containsOk then key = rule.key break end
      end
    end
  end
  local fallbacks = type(catalog.fallbacks) == "table"
    and catalog.fallbacks or {}
  key = key or fallbacks[environment(map)] or fallbacks.default
  local assets = type(catalog.assets) == "table" and catalog.assets or {}
  local spec = assets[key]
  if not validSpec(spec) then return nil end
  return spec, key, id
end

function BattleBackdrop.arena(map)
  local spec, key, id = BattleBackdrop.resolve(map)
  if not spec then return nil end
  local okStage, arena = pcall(function()
    return V.require("StadiumStage").arena(map)
  end)
  if not (okStage and type(arena) == "table") then return nil end
  arena.map = arena.map or map
  arena.painting = true
  arena.backdropSpec = spec
  arena.backdropKey = key
  arena.backdropMapId = id
  arena.presentationMode = "ARENA"
  arena.gen2ArenaSource = "johto-location-bitmap"
  arena.arenaStyle = {
    id = tostring(key), mapId = id,
    source = "gen2-location-catalog",
  }
  return arena
end

function BattleBackdrop.prepare(arena, skyExposed)
  local okStage, stage = pcall(V.require, "VoxelBattleStage")
  if not (okStage and type(stage) == "table"
      and type(stage.backdropFor) == "function") then return nil end
  return stage.backdropFor(arena, skyExposed == true)
end

function BattleBackdrop.draw(arena, skyExposed, image)
  local okStage, stage = pcall(V.require, "VoxelBattleStage")
  if not (okStage and type(stage) == "table"
      and type(stage.drawBackdrop) == "function") then return false end
  return stage.drawBackdrop(arena, skyExposed == true, image) == true
end

function BattleBackdrop.pathFor(map)
  local spec = BattleBackdrop.resolve(map)
  return spec and spec.path or nil
end

function BattleBackdrop.skyPolicy(arena)
  local okStage, stage = pcall(V.require, "VoxelBattleStage")
  if okStage and type(stage) == "table"
      and type(stage.skyPolicy) == "function" then
    return stage.skyPolicy(arena)
  end
  return { voxelSky=false, skyAperture=nil, source="stage-unavailable" }
end

return BattleBackdrop
