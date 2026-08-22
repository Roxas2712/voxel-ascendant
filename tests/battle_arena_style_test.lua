local function eq(a, b, message)
  if a ~= b then error((message or "mismatch") .. ": "
    .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local V = {}
function V.data(name) return assert(loadfile("data/" .. name .. ".lua"))() end
local Style = assert(loadfile("lib/BattleArenaStyle.lua"))(V)
local audit = Style.audit()
eq(audit.maps, 95, "authored map count")
eq(audit.anchors, 111, "authored anchor count")
eq(audit.profiles, 32, "base arena profile count")

local function map(id, tileset)
  return { id=id, def={ tileset=tileset or "OVERWORLD" } }
end
eq(Style.resolve(map("LORELEIS_ROOM", "GYM"), {}).id,
   "league_ice", "Lorelei room style")
eq(Style.resolve(map("CHAMPIONS_ROOM", "GYM"), {}).id,
   "league_champion", "Champion room style")
eq(Style.resolve(map("KA_JOHTO_GOLD_PASSAGE"), {}).id,
   "johto_gold", "Gold passage style")
eq(Style.resolve(map("KA_HEVO_RED_ABYSS"), {}).id,
   "red_basalt", "Red room style")
eq(Style.resolve(map("ROUTE_20"), {}).id, "coast", "surf route style")
local nugget = Style.resolve(map("ROUTE_24"), {})
eq(nugget.id, "nugget_bridge", "Nugget Bridge style")
eq(nugget.profile.motif, "nugget_bridge", "Nugget Bridge graphic motif")
local cerulean = Style.resolve(map("CERULEAN_CITY"), {})
eq(cerulean.id, "cerulean_canal", "Cerulean landmark style")
eq(cerulean.profile.motif, "cerulean_canal", "Cerulean graphic motif")
eq(Style.resolve(map("VIRIDIAN_FOREST", "FOREST"), {}).id,
   "forest", "forest style")

local low = Style.resolve(map("ROUTE_3"), { anchorIndex=1, anchorHeight=0 })
local high = Style.resolve(map("ROUTE_3"), { anchorIndex=2, anchorHeight=6 })
if low.variant == high.variant or low.seed == high.seed then
  error("anchor/height did not produce a distinct stable arena variant")
end

local source = assert(io.open("lib/OverworldBattle.lua", "rb")):read("*a")
if not source:find('{ "MAP", "ARENA", "DISCS", "OFF" }', 1, true) then
  error("3D-BTL ladder does not expose MAP/ARENA/DISCS/OFF")
end
if not source:find('OverworldBattle.ARENA = "arena"', 1, true) then
  error("ARENA stored value is missing")
end

print("battle arena styles: 95 maps, 111 anchors, 32 profiles")
