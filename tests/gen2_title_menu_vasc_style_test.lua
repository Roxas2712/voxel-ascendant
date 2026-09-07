local root = assert(arg[1], "repository root required")
local pushed, specs, nativeDraws = nil, {}, 0
local universalBoot = "de"
local originalVersion = package.loaded["src.core.GameVersion"]
local originalBadges = package.loaded["src.inventory.Badges"]
package.loaded["src.core.GameVersion"] = {get=function() return "silver" end}
package.loaded["src.inventory.Badges"] = {count=function() return 8 end}
local Hub = {drawPhysical=function(spec, w, h)
  spec.physical={w,h}; specs[#specs + 1]=spec; return true
end}
local Style = assert(loadfile(root .. "/gen2/lib/TitleMenuVascStyle.lua"))({
  mod={options={get=function(_, key) if key == "hud_language" then return "en" end end},
    find=function(id)
      if id == "translation-german-universal" and universalBoot then
        return {exports={bootLanguage=universalBoot}}
      end
    end,
    events={on=function(_, name, fn) assert(name == "screen.pushed"); pushed=fn end}},
  TitleHubPresentation=Hub,
  CanvasPresentation={OS="OS X"},
})
assert(Style.install() and type(pushed) == "function")
local choose = function() end
local list={index=2, update=function() end, items={
  {label="CONTINUE", value="continue"}, {label="NEW GAME", value="new"},
  {label="OPTION", value="option"}, {label="EXIT GAME", value="exit"},
}}
local update=function() end
local state={phase="menu", list=list, hasSave=true, update=update, choose=choose,
  game={data={}}, draw=function() nativeDraws=nativeDraws+1 end,
  drawWidescreen=function() nativeDraws=nativeDraws+1 end}
pushed({state=state})
assert(state.__vascGen2TitleMenuPresentation == "title-choice"
  and state.__ascendantGlobalUiSkinSkip == true)
assert(state.list == list and state.update == update and state.choose == choose,
  "Gen2 title hub changed engine navigation ownership")
state:drawWidescreen(1920,1080)
assert(nativeDraws == 0 and specs[#specs].edition == "silver"
  and specs[#specs].index == 2 and specs[#specs].physical[1] == 1920
  and specs[#specs].generation == 2 and specs[#specs].game == state.game,
  "current Gen2 MainMenu list was not presented")
universalBoot = "en"
assert(Style.languageForQA(state) == "en",
  "Universal English boot receipt did not control Gen2 title language")
universalBoot = nil
assert(Style.languageForQA(state) == "en",
  "Gen2 title language did not fall back to English without Universal German")
universalBoot = "de"

state.phase="confirm"
state.save={player={name="SILBER"}, pokedex={owned={one=true}},playTime=65}
state:drawWidescreen(1920,1080)
assert(specs[#specs].items[1].right == "SILBER"
  and specs[#specs].items[2].right == "8"
  and specs[#specs].items[4].right == "0:01",
  "same-state Gen2 confirm phase did not switch presentation")

for _, boot in ipairs({false, "en", "de"}) do
  universalBoot=boot
  state:drawWidescreen(1920,1080)
  assert(specs[#specs].footer == (boot == "de"
    and "A: WEITER   B: ZURÜCK" or "A: CONTINUE   B: BACK"))
  state.phase="menu"; state:drawWidescreen(600,1200)
  assert(specs[#specs].footer:find(boot == "de" and "ZURÜCK" or "B: BACK",1,true))
  state.phase="confirm"
end
Hub.drawPhysical=function() return false end
local fallback={phase="menu", list=list,
  draw=function() nativeDraws=nativeDraws+1 end}
pushed({state=fallback}); fallback:drawWidescreen(800,600)
assert(nativeDraws == 1, "failed Gen2 title painter did not fail open")

package.loaded["src.core.GameVersion"] = originalVersion
package.loaded["src.inventory.Badges"] = originalBadges
print("Current Gen2 MainMenu and confirm phase use the six-edition hub")
