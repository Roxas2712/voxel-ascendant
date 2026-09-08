-- Gen-II ASC BOX search keeps Crystal's native mutation owner and adds only
-- the Gen-I-parity START search/navigation seam.
local root = (arg and arg[1]) or "."

local function eq(actual, expected, label)
  assert(actual == expected, (label or "value") .. ": expected "
    .. tostring(expected) .. ", got " .. tostring(actual))
end

local pressed = {}
local input = {}
function input:wasPressed(key) return pressed[key] == true end

local textInputState
local callbacks,assignments={},0
love = setmetatable({}, {
 __index=function(_,key)
  if key=='keyboard' then return {setTextInput=function(active)textInputState=active end}end
  return callbacks[key]
 end,
 __newindex=function(_,key,value)
  assert(key=='textinput','mods cannot assign love.'..tostring(key))
  assignments=assignments+1;callbacks[key]=value
 end,
})

local mod = {
  find=function(id)
    if id == "translation-german-universal" then
      return { exports={ bootLanguage="de" } }
    end
  end,
}
local Adapter = assert(loadfile(
  root .. "/gen2/lib/GoldSubmenuBattleStyle.lua"))({ mod=mod })

local nativeUpdates = 0
local bulbasaur = { species="BULBASAUR", nickname="BISA", gender="male" }
local pikachu = { species="PIKACHU", nickname="SPARKY", gender="female" }
local screen = {
  game={ input=input, save={ boxes={ [1]={bulbasaur}, [14]={pikachu} } },
    data={ pokemon={
      BULBASAUR={ name="BISASAM", types={"GRASS", "POISON"} },
      PIKACHU={ name="PIKACHU", types={"ELECTRIC"} },
    } } },
  boxIndex=1, index=1, scroll=0,
  update=function() nativeUpdates = nativeUpdates + 1 end,
  clampIndex=function(self) self.clamped = true end,
}

Adapter.decorateBoxSearchForQa(screen)
Adapter.decorateBoxSearchForQa({game=screen.game,update=function()end})
eq(assignments,1,"text bridge must install once without a global marker")
pressed.start = true
screen:update()
pressed.start = nil
eq(screen._vascGen2SearchOpen, true, "START search open")
eq(textInputState, true, "OS text input activation")
eq(nativeUpdates, 0, "native Box update leaked under search overlay")

Adapter.gen2SearchTextForQa(screen, "pika")
eq(#screen._vascGen2SearchResults, 1, "name result count")
eq(screen._vascGen2SearchResults[1].box, 14,
  "sparse late Crystal box was not searched")

pressed.select = true
screen:update()
pressed.select = nil
eq(screen._vascGen2SearchMode, "type", "SELECT type mode")
Adapter.gen2SearchTextForQa(screen, "pflanze")
eq(#screen._vascGen2SearchResults, 1, "German type query count")
eq(screen._vascGen2SearchResults[1].mon, bulbasaur, "German type result")

pressed.a = true
screen:update()
pressed.a = nil
eq(screen._vascGen2SearchOpen, false, "A closes located search")
eq(screen.boxIndex, 1, "located box")
eq(screen.index, 1, "located slot")
eq(screen.clamped, true, "native Box cursor clamp")
eq(textInputState, false, "OS text input release")

screen:update()
eq(nativeUpdates, 1, "native Box update did not resume")

print("Gen-II ASC BOX START search: ok")

love=setmetatable({}, {__newindex=function()error('callbacks protected')end})
local locked=assert(loadfile(root..'/gen2/lib/GoldSubmenuBattleStyle.lua'))({mod=mod})
local protected={game=screen.game,update=function()end}
assert(pcall(locked.decorateBoxSearchForQa,protected),'protected callback crashed PC')
assert(type(protected.textinput)=='function','screen text seam lost')
print('PASS protected PC callback fallback')
