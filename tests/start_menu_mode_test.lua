local root = arg and arg[1] or "."

local eventListeners, hookWrappers = {}, {}
local persisted
local bootLanguage = "de"
local mod = {
  find=function(id)
    if id == "translation-german-universal" and bootLanguage then
      return {exports={bootLanguage=bootLanguage}}
    end
  end,
  events={ on=function(_, name, callback) eventListeners[name] = callback end },
  hooks={ wrap=function(_, name, callback) hookWrappers[name] = callback end },
  save={
    get=function() return false end,
    set=function(_, key, value)
      assert(key == "startMenuFullscreen")
      persisted = value
      return true
    end,
  },
  options={ get=function(_, key)
    if key == "hud_language" then return "de" end
  end },
}

local StartMenu = { new=function(game)
  return {
    screenId="StartMenu",
    game=game,
    items={ {label="POKéDEX"}, {label="POKéMON"}, {label="ITEM"}, {label="OPTION"} },
    index=2,
    scroll=0,
    draw=function(self) self.nativeDraws = (self.nativeDraws or 0) + 1 end,
    update=function(self) self.nativeUpdates = (self.nativeUpdates or 0) + 1 end,
  }
end }
package.preload["src.ui.StartMenu"] = function() return StartMenu end
package.preload["src.core.GamepadMap"] = function()
  return { mapRawButton=function(button) return button == 9 and "select" end }
end

local wideDraws, lastWideAdapter = 0, nil
local stagedCalls = 0
local mobile = {
  isMobileRuntime=function() return true end,
  runtimePlan=function(owner, width, height, winW, winH)
    assert(owner == "start_menu" and width == 512 and height == 288)
    assert(winW == 1170 and winH == 540)
    return {
      active=true, logicalW=512, logicalH=288,
      x=19, y=7, scale=2,
      safe={x=19,y=7,w=1024,h=576},
      receipt={ owner=owner, safe={x=19,y=7,w=1024,h=576} },
    }
  end,
  presentLogical=function(_, plan, callback, config)
    stagedCalls = stagedCalls + 1
    assert(config and type(config.backdrop) == "table",
      "fullscreen START lost its opaque complete-screen backdrop")
    local G = love.graphics
    G.translate(plan.x, plan.y)
    G.scale(plan.scale, plan.scale)
    return true, callback()
  end,
}
local V = {
  mod=mod,
  OrasUiSkin={
    enabled=function() return true end,
    markCustom=function(menu) menu.__markedCustom = true end,
  },
}
function V.require(name)
  if name == "EditionAccent" then
    return { color=function() return { .9, .2, .18, 1 } end }
  elseif name == "MobileMenuPresentation" then
    return mobile
  elseif name == "Diagnostics" then
    return { write=function() end }
  elseif name == "VascMenuStyle" then
    return { new=function()
      return { decorateFocusHelp=function(adapter)
        adapter.drawWidescreen = function(self, width, height)
          wideDraws = wideDraws + 1
          lastWideAdapter = self
          self.lastWide = { width, height }
        end
        return adapter
      end }
    end }
  end
  error("unexpected module " .. tostring(name))
end

local oldLove = _G.love
local circles, transforms, printed = 0, {}, {}
local activeFont = {
  getWidth=function(_, text) return #tostring(text) * 6 end,
  getHeight=function() return 12 end,
}
_G.love = { graphics={
  newFont=function() return activeFont end,
  getDimensions=function() return 1170, 540 end,
  push=function() end, pop=function() end, origin=function() end,
  setBlendMode=function() end, setColor=function() end,
  setLineWidth=function() end, rectangle=function() end,
  print=function(text) printed[#printed + 1] = tostring(text) end,
  setFont=function() end, getFont=function() return activeFont end,
  circle=function() circles = circles + 1 end,
  line=function() end,
  translate=function(x, y) transforms[#transforms + 1] = {"translate",x,y} end,
  scale=function(x, y) transforms[#transforms + 1] = {"scale",x,y} end,
} }

local module = assert(loadfile(root .. "/lib/StartMenuMode.lua"))(V)
assert(module.install())
assert(module.startLabelForQa({label="ITEM"}) == "TASCHE")
assert(module.startLabelForQa({label="OPTION"}) == "OPTIONEN")
bootLanguage = nil
assert(module.startLabelForQa({label="ITEM"}) == "ITEM",
  "Absent translation mod leaked German from the saved battle-HUD preference")
assert(module.startLabelForQa({label="OPTION"}) == "OPTION")
bootLanguage = "en"
assert(module.startLabelForQa({label="ITEM"}) == "ITEM",
  "Universal English boot lost to the saved battle-HUD preference")
bootLanguage = "de"
assert(type(hookWrappers["render.hud"]) == "function")
assert(type(eventListeners["screen.pushed"]) == "function")

local input = { wasPressed=function() return false end }
local game = {
  save={
    version="red", player={name="RED"}, options={modOptions={}},
    startMenuIndex=1,
  },
  input=input,
  writeOptions=function(self) self.optionWrites = (self.optionWrites or 0) + 1 end,
}
local menu = StartMenu.new(game)
game.stack={ states={menu}, top=function(self) return self.states[#self.states] end }
assert(menu.__vascPersistentStartMode and menu.__markedCustom)

local passthrough = hookWrappers["render.hud"](
  function() return "native-hud" end, game, {width=1170,height=540})
assert(passthrough == "native-hud")
assert(circles >= 4, "A21 compact START did not draw its selected Pokéball")
assert(transforms[1][1] == "translate"
    and transforms[1][2] == 19 and transforms[1][3] == 7,
  "compact START did not use the phone-safe final target")
assert(menu.__vascStartMobileReceipt.owner == "start_menu")
assert(stagedCalls == 0,
  "compact START was blurred through the low-resolution staging Canvas")
assert(table.concat(printed, "|"):find("TASCHE", 1, true),
  "Universal German did not localize the native ITEM row")
assert(table.concat(printed, "|"):find("OPTIONEN", 1, true),
  "Universal German did not localize the native OPTION row")

assert(menu:onKeyPressed("tab") == true)
assert(menu._vascStartFullscreen == true and persisted == true)
assert(game.save.startMenuIndex == 2 and game.optionWrites == 1)
hookWrappers["render.hud"](
  function() return "native-hud" end, game, {width=1170,height=540})
assert(wideDraws == 1, "SELECT did not open the complete Ascendant START menu")
assert(stagedCalls == 1,
  "fullscreen START did not use the atomic complete-screen presenter")

-- The real Gen-I START list has nine entries, while the fullscreen focus/help
-- panel displays eight.  Reproduce the final-row viewport directly: QUIT must
-- remain the selected ninth callback row and the presenter must retain the
-- native one-row scroll rather than clamping it back outside the panel.
menu.items = {
  {label="POKéDEX"}, {label="POKéMON"}, {label="ITEM"}, {label="RED"},
  {label="ASCENDANT"}, {label="SAVE"}, {label="OPTION"}, {label="MODS"},
  {label="QUIT"},
}
menu.index, menu.scroll = 9, 1
hookWrappers["render.hud"](
  function() return "native-hud" end, game, {width=1170,height=540})
assert(lastWideAdapter and lastWideAdapter.rows == 8,
  "fullscreen START advertised more rows than the panel can display")
assert(lastWideAdapter.index == 9 and lastWideAdapter.scroll == 1,
  "fullscreen START lost the visible ninth QUIT row")
assert(lastWideAdapter.items[9].label == "BEENDEN",
  "Universal German did not localize the reachable QUIT row")

menu:onKeyPressed("tab")
assert(menu._vascStartFullscreen == false and persisted == false,
  "SELECT did not return to compact START")
assert(module.install(), "install is not idempotent")
_G.love = oldLove
print("Gen-1 A21 START: Pokeball, SELECT toggle and phone-safe presentation ok")
