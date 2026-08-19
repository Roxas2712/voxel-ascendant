local cache = {}
local stored = {}

local V = {
  mod = {
    id = "VOXEL_ASCENDANT",
    options = { get = function(_, key) return stored[key] end },
  },
}

function V.require(name)
  if cache[name] then return cache[name] end
  if name == "ModSetting" then
    cache[name] = assert(loadfile("lib/ModSetting.lua"))(V)
  elseif name == "Voxel3D" then
    cache[name] = { available = function() return true end }
  else
    cache[name] = {}
  end
  return cache[name]
end

package.preload["src.world.FieldDefaults"] = function()
  return {
    fieldValue = function(_, section, key)
      if section == "playerPics" and key == "front" then
        return "vanilla_front.png"
      end
    end,
  }
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local Battle = assert(loadfile("lib/OverworldBattle.lua"))(V)

eq(Battle.pokemonBackSetting.key, "battleBack",
   "Pokemon setting retains the upgrade-compatible key")
eq(Battle.trainerBackSetting.key, "trainerBack",
   "trainer setting has an independent key")
eq(Battle.backSetting, Battle.pokemonBackSetting,
   "historical companion alias still names the Pokemon setting")

local ctx = { kind = "battle", side = "back", data = {} }
local seenKind
local function companion(_, routed)
  seenKind = routed.kind
  return routed.kind == "battle_back" and "custom_back.png"
         or "custom_front.png"
end

eq(Battle.routeTrainerSprite(companion, "vanilla_back.png", ctx, true, false),
   "custom_back.png", "TRAINER BACK asks companions for their back art")
eq(seenKind, "battle_back", "back-art compatibility route is explicit")
eq(ctx.kind, "battle", "compatibility routing does not mutate engine context")

eq(Battle.routeTrainerSprite(function(path) return path end,
     "vanilla_back.png", ctx, false, true),
   "vanilla_front.png", "front mode falls back to the engine's front art")

eq(Battle.routeTrainerSprite(companion, "vanilla_back.png", ctx, false, true),
   "custom_front.png", "front mode preserves companion-selected front art")

local cardCtx = { kind = "trainer_card", side = "front" }
eq(Battle.routeTrainerSprite(function() return "card.png" end,
     "base.png", cardCtx, true, false),
   "card.png", "non-battle trainer art remains untouched")

print("battle sprite modes: ok")
