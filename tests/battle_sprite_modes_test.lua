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
local seenKind, seenSide, seenPath
local function companion(_, routed)
  seenKind = routed.kind
  seenSide = routed.side
  seenPath = _
  if routed.kind == "battle_back" then return "custom_back.png" end
  if routed.side == "front" then return "custom_front.png" end
  return "custom_back.png"
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
eq(seenSide, "front", "front mode is routed as a real front-art request")
eq(seenPath, "vanilla_front.png", "front providers receive the front base path")
eq(ctx.side, "back", "front routing does not mutate engine context")

-- Kanto Ascendant 6.7's outer selector preserves any path changed by its
-- inner selector. This reproduces that shape: a fake path replacement cannot
-- beat it, while the real side=front request above selects the correct family.
local function kanto67Inner(base, routed)
  return routed.side == "back" and "kanto_battle_back.png"
         or "kanto_standing_front.png"
end
local function kanto67Outer(base, routed)
  local selected = Battle.routeTrainerSprite(kanto67Inner, base, routed,
                                               false, true)
  return selected ~= base and selected or "kanto_default_front.png"
end
eq(kanto67Outer("vanilla_back.png", ctx), "kanto_standing_front.png",
   "Kanto Ascendant 6.7 receives a front request when TRAINER BACK is OFF")

local cardCtx = { kind = "trainer_card", side = "front" }
eq(Battle.routeTrainerSprite(function() return "card.png" end,
     "base.png", cardCtx, true, false),
   "card.png", "non-battle trainer art remains untouched")

print("battle sprite modes: ok")
