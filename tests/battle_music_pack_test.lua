local function eq(a, b, message)
  if a ~= b then error((message or "mismatch") .. ": "
    .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local fakeSongs = {}
local fakeMod = {
  id="VOXEL_ASCENDANT", options={get=function() return nil end},
  content={music={get=function(_, id) return fakeSongs[id] end}},
}
local V = { mod=fakeMod }
local ModSetting = assert(loadfile("lib/ModSetting.lua"))(V)
function V.require(name)
  if name == "ModSetting" then return ModSetting end
  error("unexpected module " .. tostring(name))
end

local Music = assert(loadfile("lib/BattleMusic.lua"))(V)
eq(Music.API_VERSION, 1, "api")
eq(Music.setting:get(), "original", "default")
eq(Music.setting:rungs(), 1, "missing pack exposed dead rungs")
eq(Music.resolve("Music_WildBattle", {reason="battle", kind="wild"}),
   "Music_WildBattle", "default changed game music")

local invalid = Music.register({id="BAD"})
eq(invalid, nil, "bad pack accepted")

local function add(id) fakeSongs[id] = {file="/separate-pack/" .. id .. ".ogg"} end
for _, id in ipairs({
  "Pack_G2_Wild_A", "Pack_G2_Wild_B", "Pack_G3_Trainer",
  "Pack_G4_Gym", "Pack_G5_League", "Pack_G6_Wild",
}) do add(id) end

local unregister = assert(Music.register({
  id="LEGAL_LOCAL_PACK", label="LOCAL PACK", version="1.0.0",
  sourceUrl="https://example.invalid/music-pack",
  sha256=string.rep("a", 64), userConfirmed=true, separateInstall=true,
  tracks={
    {id="Pack_G2_Wild_A", generation=2, scopes={wild=true}},
    {id="Pack_G2_Wild_B", generation=2, scopes={wild=true}},
    {id="Pack_G3_Trainer", generation=3, scopes={trainer=true}},
    {id="Pack_G4_Gym", generation=4, scopes={gym=true}},
    {id="Pack_G5_League", generation=5, scopes={league=true}},
    {id="Pack_G6_Wild", generation=6, scopes={wild=true}},
  },
}))
eq(Music.setting:rungs(), 7, "available generations not exposed")

Music.setting:sync("gen3")
eq(Music.resolve("base", {reason="map", kind="trainer"}), "base",
   "map cue replaced")
eq(Music.resolve("base", {reason="battle", kind="trainer"}),
   "Pack_G3_Trainer", "trainer generation")
eq(Music.resolve("other", {reason="battle", kind="trainer"}),
   "Pack_G3_Trainer", "double battle cue was not locked")
Music.finish()

Music.setting:sync("gen4")
eq(Music.resolve("base", {reason="battle", kind="gym",
                          trainerId="OPP_BROCK"}),
   "Pack_G4_Gym", "gym scope")
Music.finish()

Music.setting:sync("gen5")
eq(Music.resolve("base", {reason="battle", kind="gym",
                          trainerId="OPP_LORELEI"}),
   "Pack_G5_League", "league classifier")
Music.finish()

Music.setting:sync("shuffle")
local first = Music.resolve("base", {reason="battle", kind="wild"})
Music.finish()
local second = Music.resolve("base", {reason="battle", kind="wild"})
if first == second then error("shuffle repeated with alternatives", 0) end
Music.finish()

local hook
local mod = { hooks={wrap=function(_, name, fn)
  eq(name, "music.select", "hook name") hook=fn
end} }
eq(Music.install(mod), true, "install")
Music.setting:sync("gen6")
eq(hook(function(value) return value end, "base",
        {reason="battle", kind="wild"}), "Pack_G6_Wild", "hook relay")
Music.finish()

local public = Music.public()
eq(public.requirements.bundledAudio, false, "bundled-audio claim")
eq(public.requirements.networkDownloads, false, "network-download claim")
eq(#Music.list(), 1, "pack list")
eq(unregister(), true, "unregister")
Music.setting:sync("shuffle")
eq(Music.setting:get(), "original", "missing stored pack did not fail original")
eq(Music.resolve("base", {reason="battle", kind="wild"}), "base",
   "removed pack still selected")

print("battle music packs: ok")
