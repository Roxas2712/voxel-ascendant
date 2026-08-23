local function eq(a, b, message)
  if a ~= b then error((message or "mismatch") .. ": "
    .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local files = {
  ["user/music/README.txt"] = true,
  ["user/music/wild"] = { "Johto Wild.mp3", "Kanto.ogg" },
  ["user/music/trainer"] = { "Trainer.wav" },
  ["user/music/rival"] = { "Rival.flac" },
  ["user/music/gym"] = { "Gym.mp3" },
  ["user/music/elite4"] = { "Elite.mp3" },
  ["user/music/champion"] = { "Champion.mp3" },
  ["user/music/field"] = { "Route.mp3", "README.exe" },
  ["user/music/bike"] = { "Bike.mp3" },
  ["user/music/surf"] = { "Surf.mp3" },
  ["user/music/victory"] = { "Victory.mp3" },
  ["user/music/evolution"] = { "Evolution.mp3" },
  ["user/music/title"] = { "Title.mp3" },
  ["user/music/halloffame"] = { "Hall.mp3" },
  ["user/music/credits"] = { "Credits.mp3" },
  ["user/music/jingle"] = { "Heal.mp3" },
  ["user/music/scene"] = { "Oak.mp3" },
  ["user/music/replace"] = { "Music_SpecialKasc.mp3", "bad name.mp3" },
}

local function fileInfo(path)
  if files[path] == true then return {type="file", size=10} end
  if type(files[path]) == "table" then return {type="directory"} end
  for dir, names in pairs(files) do
    if type(names) == "table" then
      for _, name in ipairs(names) do
        if path == dir .. "/" .. name then return {type="file", size=100} end
      end
    end
  end
end

local registered, registerCount, screens, hook = {}, 0, {}, nil
local saveBucket, loaderBucket = {}, {}
local game = {
  save={options={modOptions={VOXEL_ASCENDANT=saveBucket}}},
  mods={modOptions={VOXEL_ASCENDANT=loaderBucket}},
  writeOptions=function(self) self.writes = (self.writes or 0) + 1 end,
}
local mod = {
  id="VOXEL_ASCENDANT",
  assets={
    info=function(_, path) return fileInfo(path) end,
    list=function(_, path) return files[path] or {} end,
    path=function(_, path) return "mods/VOXEL_ASCENDANT/" .. path end,
  },
  content={
    music={register=function(_, id, def)
      if registered[id] then error("duplicate") end
      registered[id], registerCount = def, registerCount + 1
    end},
    screens={register=function(_, id, def) screens[id] = def end},
  },
  hooks={wrap=function(_, name, fn, priority)
    eq(name, "music.select", "hook")
    eq(priority, 2000000, "priority")
    hook = fn
  end},
  ui={
    push=function() end,
    ListMenu={new=function(_, title, items, opts)
      return {title=title, items=items, opts=opts, close=function() end}
    end},
  },
}
local baseV = {mod=mod}
local UserFiles = assert(loadfile("lib/UserFiles.lua"))(baseV)
local oneShotArg
local EngineMusic = {playOnce=function(_, song)
  oneShotArg = song
  return song
end}
package.loaded["src.core.Music"] = EngineMusic
local V = { mod=mod, require=function(name)
  if name == "UserFiles" then return UserFiles end
  if name == "BattleMusic" then
    return {setting={setValue=function(_, value)
      game.battleMusic = value
    end}}
  end
  error("unexpected module " .. tostring(name))
end }
local Music = assert(loadfile("lib/LocalMusic.lua"))(V)
eq(Music.install(mod), true, "install")
eq(#Music.list("wild"), 2, "wild scan")
eq(#Music.list("field"), 1, "extension filter")
eq(type(screens.VascUserMusic), "table", "music screen")
eq(type(screens.VascUserMusicGroup), "table", "music group screen")
eq(type(screens.VascUserMusicExact), "table", "exact music screen")
eq(registerCount, 18, "registered initial tracks")
local any = Music.list("wild")[1]
eq(registered[any.id].file:find("mods/VOXEL_ASCENDANT/", 1, true), 1,
   "asset path")

files["user/music/wild"][3] = "Sinnoh.mp3"
Music.scan(mod)
eq(#Music.list("wild"), 3, "live rescan")
eq(registerCount, 19, "only new track registered")
Music.scan(mod)
eq(registerCount, 19, "repeat rescan idempotent")

eq(Music.categoryFor({reason="map", mapId="ROUTE_1"}), "field", "field")
eq(Music.categoryFor({reason="map", onBike=true}), "bike", "bike")
eq(Music.categoryFor({reason="bike"}), "bike", "Gen 2 bike")
eq(Music.categoryFor({reason="map", surfing=true}), "surf", "surf")
eq(Music.categoryFor({reason="battle", kind="wild"}), "wild", "wild")
eq(Music.categoryFor({reason="battle", kind="gym"}), "gym", "gym")
eq(Music.categoryFor({reason="battle", kind="trainer", trainerId="OPP_RIVAL2"}),
   "rival", "rival")
eq(Music.categoryFor({reason="battle", kind="final", trainerId="OPP_LORELEI"}),
   "elite4", "elite")
eq(Music.categoryFor({reason="battle", kind="final", trainerId="OPP_RIVAL3"}),
   "champion", "champion")
eq(Music.categoryFor({reason="victory", kind="trainer"}),
   "victory", "victory")
eq(Music.categoryFor({reason="evolution"}), "evolution", "evolution")
eq(Music.categoryFor({reason="title"}), "title", "title")
eq(Music.categoryFor({reason="halloffame"}), "halloffame", "hall")
eq(Music.categoryFor({reason="credits"}), "credits", "credits")
eq(Music.categoryFor({reason="once"}), "jingle", "jingle")
eq(Music.categoryFor({reason="oak_speech"}), "scene", "scene")

local exact = Music.list("replace")
eq(#exact, 1, "exact replacement filter")
eq(exact[1].originalId, "Music_SpecialKasc", "exact replacement id")
eq(Music.resolve("Music_SpecialKasc", {reason="unknown"}),
   "Music_SpecialKasc", "custom music default protection")
Music.setEnabled(game, true)
eq(Music.resolve("Music_SpecialKasc", {reason="unknown"}), exact[1].id,
   "exact KASC song replacement")
eq(EngineMusic.playOnce({}, "Music_SpecialKasc"), exact[1].id,
   "one-shot relay result")
eq(oneShotArg, exact[1].id, "one-shot restore alias")

local wild = Music.list("wild")
Music.persist(game, "wild", wild[1].id)
eq(game.writes, 2, "enable plus persist writes")
local chosen = hook(function(value) return value end, "BASE",
  {reason="battle", kind="wild"})
eq(chosen, wild[1].id, "exact local track")
eq(hook(function(value) return value end, "OTHER",
  {reason="battle", kind="wild"}), wild[1].id, "battle choice lock")
Music.finish()

Music.persist(game, "wild", "shuffle")
local first = Music.resolve("BASE", {reason="battle", kind="wild"})
Music.finish()
local second = Music.resolve("BASE", {reason="battle", kind="wild"})
if first == second then error("shuffle repeated with alternatives", 0) end
Music.finish()

local field = Music.list("field")[1]
Music.persist(game, "field", field.id)
eq(Music.resolve("MAP", {reason="map", mapId="PALLET_TOWN"}),
   field.id, "field override")
Music.persist(game, "field", "missing")
eq(Music.resolve("MAP", {reason="map", mapId="PALLET_TOWN"}),
   "MAP", "missing choice fallback")

Music.backToDefault(game)
eq(Music.enabled(), false, "back to default did not disable local music")
eq(game.battleMusic, "original", "back to default kept companion music")
eq(saveBucket[Music.KEY_PREFIX .. "wild"], "original",
   "back to default kept wild selection")
eq(saveBucket[Music.KEY_PREFIX .. "field"], "original",
   "back to default kept field selection")
eq(Music.resolve("Music_SpecialKasc", {reason="unknown"}),
   "Music_SpecialKasc", "default still applied exact replacement")
Music.setEnabled(game, true)

saveBucket[Music.KEY_PREFIX .. "trainer"] = Music.list("trainer")[1].id
Music.restore(game)
eq(Music.resolve("BASE", {reason="battle", kind="trainer"}),
   Music.list("trainer")[1].id, "restore")

print("local user music: ok")
