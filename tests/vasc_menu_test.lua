assert(loadfile("main.lua"))

local pushes, registered, popped = {}, {}, 0
local mod = {
  content={screens={register=function(_, name, def) registered[name] = def end}},
  ui={push=function(game, screen, opts)
    pushes[#pushes + 1] = {game=game, screen=screen, opts=opts}
  end},
}

local reset = {music=0, sprites=0}
local V = {require=function(name)
  if name == "LocalMusic" then
    return {backToDefault=function() reset.music = reset.music + 1; return true end}
  end
  if name == "LocalSprites" then
    return {backToDefault=function() reset.sprites = reset.sprites + 1; return true end}
  end
  error("unexpected module " .. tostring(name))
end}
local VascMenu = assert(loadfile("lib/VascMenu.lua"))(V)
assert(VascMenu.install(mod) == true)
assert(type(registered.VascMenu) == "table")
assert(type(registered.VascHelp) == "table")
assert(#VascMenu.pages >= 6)

local pressed = {}
local game = {
  input={wasPressed=function(_, key) return pressed[key] == true end},
  stack={pop=function() popped = popped + 1 end},
}
local function update(state, key)
  pressed = {[key]=true}
  state:update()
  pressed = {}
end

local hub = registered.VascMenu.new(game)
assert(hub.index == 1)
update(hub, "start")
assert(pushes[#pushes].screen == "VascHelp", "START opens contextual help")
update(hub, "a")
assert(pushes[#pushes].screen == "OptionsMenu", "SETTINGS opens engine Options")
update(hub, "down")
update(hub, "a")
assert(pushes[#pushes].screen == "VascUserMusic")
update(hub, "down")
update(hub, "a")
assert(pushes[#pushes].screen == "VascUserSprites")
update(hub, "down")
update(hub, "a")
assert(reset.music == 1 and reset.sprites == 1,
  "global reset restores both custom providers")
assert(hub.restoreStatus == "GAME/KASC RESTORED")
update(hub, "down")
update(hub, "a")
assert(pushes[#pushes].screen == "VascHelp", "HELP remains selectable")
update(hub, "b")
assert(popped == 1)

local help = registered.VascHelp.new(game)
assert(help.page == 1)
update(help, "right")
assert(help.page == 2)
update(help, "left")
assert(help.page == 1)
update(help, "start")
assert(popped == 2)

for _, page in ipairs(VascMenu.pages) do
  assert(type(page.title) == "string" and page.title ~= "")
  assert(#page >= 4, "every help page has actionable guidance")
end

print("ok standalone VASC hub and START help")
