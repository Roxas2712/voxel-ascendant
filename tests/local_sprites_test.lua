local function eq(a, b, message)
  if a ~= b then error((message or "mismatch") .. ": "
    .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local present = {}
local function add(path) present[path] = {type="file", size=100} end
add("user/sprites/README.txt")
add("user/sprites/pokemon/front/PIKACHU.png")
add("user/sprites/pokemon/front/CHARIZARD_MEGA_X.png")
add("user/sprites/pokemon/front/CHARIZARD_MEGA_Y.png")
add("user/sprites/pokemon/front/MEWTWO_MEGA_Y.png")
add("user/sprites/pokemon/front/PIKACHU_SHINY.png")
add("user/sprites/pokemon/dex/PIKACHU.png")
add("user/sprites/pokemon/icons/PIKACHU.png")
add("user/sprites/player/battle_front.png")
add("user/sprites/player/back.png")
add("user/sprites/trainers/OPP_RIVAL2.png")
add("user/sprites/overworld/SPRITE_KA_CRYSTAL_GREEN_BIKE.png")

love = {
  image={newImageData=function(path)
    if path:find("BROKEN", 1, true) then error("bad png") end
    return {getDimensions=function() return 64, 64 end, release=function() end}
  end},
}

local screens = {}
local mod = {
  id="VOXEL_ASCENDANT",
  assets={
    info=function(_, path) return present[path] end,
    list=function() return {} end,
    path=function(_, path) return "mods/VOXEL_ASCENDANT/" .. path end,
  },
  content={screens={register=function(_, id, def) screens[id] = def end}},
  ui={
    push=function() end,
    ListMenu={new=function(_, title, items, opts)
      return {title=title, items=items, opts=opts, close=function() end}
    end},
  },
}
local game = {
  save={options={}}, mods={modOptions={}},
  writeOptions=function(self) self.writes=(self.writes or 0)+1 end,
}
local baseV = {mod=mod}
local UserFiles = assert(loadfile("lib/UserFiles.lua"))(baseV)
local V = {mod=mod, require=function(name)
  if name == "UserFiles" then return UserFiles end
  if name == "SpritePacks" then
    return {select=function(value) game.pack = value end}
  end
  error("unexpected module " .. tostring(name))
end}
local Sprites = assert(loadfile("lib/LocalSprites.lua"))(V)
eq(Sprites.ensureTree(), true, "tree")
eq(UserFiles.info("user/sprites/pokemon/front/PIKACHU.png", "file").type,
   "file", "asset info")
eq(UserFiles.path("user/sprites/pokemon/front/PIKACHU.png"),
   "mods/VOXEL_ASCENDANT/user/sprites/pokemon/front/PIKACHU.png",
   "asset path")

local prefix = "mods/VOXEL_ASCENDANT/"
eq(Sprites.resolve("pokemon", "base-front", {
  species="PIKACHU", side="front", kind="battle"}),
  "base-front", "custom sprites changed protected default")
Sprites.setEnabled(game, true)
eq(Sprites.resolve("pokemon", "base-front", {
  species="PIKACHU", side="front", kind="battle"}),
  prefix .. "user/sprites/pokemon/front/PIKACHU.png", "front")
eq(Sprites.resolve("pokemon", "base-dex", {
  species="PIKACHU", side="front", kind="dex"}),
  prefix .. "user/sprites/pokemon/dex/PIKACHU.png", "dex")
eq(Sprites.resolve("pokemon", "base-back", {
  species="PIKACHU", side="back", kind="battle"}),
  "base-back", "missing back fallback")
eq(Sprites.resolve("pokemon", "base-mega", {
  species="CHARIZARD", side="front", kind="battle",
  mon={species="CHARIZARD", _ascMegaForm="CHARIZARD_X"}}),
  prefix .. "user/sprites/pokemon/front/CHARIZARD_MEGA_X.png",
  "KASC Mega runtime alias")
eq(Sprites.resolve("pokemon", "base-mega-y", {
  species="CHARIZARD", side="front", kind="battle",
  mon={species="CHARIZARD", _ascMegaForm="CHARIZARD_Y"}}),
  prefix .. "user/sprites/pokemon/front/CHARIZARD_MEGA_Y.png",
  "KASC Charizard Mega Y runtime alias")
eq(Sprites.resolve("pokemon", "base-mewtwo-y", {
  species="MEWTWO", side="front", kind="battle",
  mon={species="MEWTWO", _ascMegaForm="MEWTWO_Y"}}),
  prefix .. "user/sprites/pokemon/front/MEWTWO_MEGA_Y.png",
  "KASC Mewtwo Mega Y runtime alias")
eq(Sprites.resolve("pokemon", "base-shiny", {
  species="PIKACHU", side="front", kind="battle", mon={shiny=true}}),
  prefix .. "user/sprites/pokemon/front/PIKACHU_SHINY.png",
  "shiny alias")
eq(Sprites.pokemonIds({species="VENUSAUR",
                       mon={_ascMegaForm="VENUSAUR"}})[1],
   "VENUSAUR_MEGA", "single-form Mega alias")
eq(Sprites.resolve("icon", "base-icon", {species="PIKACHU"}),
  prefix .. "user/sprites/pokemon/icons/PIKACHU.png", "icon")
eq(Sprites.resolve("player", "base-player", {kind="battle", side="front"}),
  prefix .. "user/sprites/player/battle_front.png", "player specific")
eq(Sprites.resolve("player", "base-player", {kind="hof", side="back"}),
  prefix .. "user/sprites/player/back.png", "player fallback")
eq(Sprites.resolve("trainer", "base-rival", {trainerId="OPP_RIVAL2"}),
  prefix .. "user/sprites/trainers/OPP_RIVAL2.png", "enemy trainer")

local original = {image="gfx/sprites/red.png", frames=4, frameWidth=16}
local key = Sprites.sourceKey(original.image)
add(Sprites.ROOT .. "/overworld/" .. key .. ".png")
local changed = Sprites.resolve("overworld", original, {})
eq(changed.image, prefix .. Sprites.ROOT .. "/overworld/" .. key .. ".png",
   "overworld")
eq(changed.frames, 4, "overworld shape")
eq(original.image, "gfx/sprites/red.png", "original mutated")

local greenBike = {
  id="SPRITE_KA_CRYSTAL_GREEN_BIKE",
  image="mods/kanto_ascendant/assets/characters/crystal_chars/green_bike.png",
  frames=6, walker=true, trueColor=true,
}
local changedBike = Sprites.resolve("overworld", greenBike, {
  spriteId=greenBike.id, player=true, playerState="bike",
  playerCharacter="GREEN",
})
eq(changedBike.image,
   prefix .. Sprites.ROOT
     .. "/overworld/SPRITE_KA_CRYSTAL_GREEN_BIKE.png",
   "readable KASC bike id")
eq(changedBike.frames, 6, "KASC bike shape")
eq(greenBike.image,
   "mods/kanto_ascendant/assets/characters/crystal_chars/green_bike.png",
   "KASC bike original mutated")

add(Sprites.ROOT .. "/pokemon/front/BROKEN.png")
eq(Sprites.resolve("pokemon", "base-broken", {
  species="BROKEN", side="front", kind="battle"}),
  "base-broken", "broken png did not fail normal")

eq(Sprites.writeInventory({
  pokemon={PIKACHU={}, CHARIZARD_MEGA_X={}}, trainers={OPP_RIVAL2={}},
  sprites={
    RED={id="SPRITE_RED", image="gfx/sprites/red.png"},
    GREEN_BIKE=greenBike,
    NPC={image="gfx/sprites/npc.png"},
  },
}), true, "inventory build")
local inventory = Sprites.inventory()
if not inventory:find("CHARIZARD_MEGA_X", 1, true)
   or not inventory:find("pokemon/overworld/PIKACHU.png", 1, true)
   or not inventory:find(Sprites.sourceKey("gfx/sprites/npc.png"), 1, true)
   or not inventory:find("overworld/SPRITE_KA_CRYSTAL_GREEN_BIKE.png", 1, true)
   or not inventory:find("trainers/OPP_RIVAL2.png", 1, true) then
  error("inventory omitted live forms/sheets", 0)
end

Sprites.backToDefault(game)
eq(Sprites.enabled(), false, "back to default did not disable sprites")
eq(game.pack, "base", "back to default kept sprite pack")
eq(Sprites.resolve("pokemon", "base-front", {
  species="PIKACHU", side="front", kind="battle"}),
  "base-front", "disabled sprites still replaced Game/KASC")

eq(Sprites.install(mod), true, "install")
eq(type(screens.VascUserSprites), "table", "sprite screen")
eq(type(screens.VascUserSpritesHelp), "table", "sprite help screen")

print("local user sprites: ok")
