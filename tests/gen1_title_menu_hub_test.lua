local root = assert(arg[1], "repository root required")
local pushed, specs, nativeDraws = nil, {}, 0
local universalBoot = "de"
local callbacks = {new=function() end, options=function() end}
local hudHook, detailCalls = nil, 0
local rect={uiw=512,uih=288,uox=71,uoy=43,Ux=3,Uy=3}
package.loaded["src.render.Renderer"]={frameRects=function() return rect end}
local Hub = {
  width=512, height=288,
  draw=function(spec) specs[#specs + 1] = spec return true end,
  drawPhysical=function(spec, w, h)
    spec.physical={w,h}; specs[#specs + 1] = spec return true
  end,
  drawArtworkPhysical=function(spec, actualRect)
    assert(actualRect==rect and spec.generation==1)
    detailCalls=detailCalls+1
    return true
  end,
}
local Accent = {resolve=function() return {}, "blue" end}
local module = assert(loadfile(root .. "/lib/TitleMenuHub.lua"))({
  mod={
    options={get=function(_, key) if key == "hud_language" then return "en" end end},
    find=function(id)
      if id == "translation-german-universal" and universalBoot then
        return {exports={bootLanguage=universalBoot}}
      end
    end,
    events={on=function(_, name, fn) assert(name == "screen.pushed"); pushed=fn end},
    hooks={wrap=function(_,name,fn)
      assert(name=="render.hud");hudHook=fn
    end},
  },
  require=function(name)
    if name == "TitleHubPresentation" then return Hub end
    if name == "EditionAccent" then return Accent end
    error(name)
  end,
})
assert(module.install() and type(pushed) == "function")
assert(type(hudHook)=="function")
local update = function() end
local rootState = {
  screenId="TitleState", game={}, update=update,
  onNewGame=function() end,
  draw=function() nativeDraws=nativeDraws+1 end,
}
local nativeRootDraw = rootState.draw
pushed({state=rootState})
assert(rootState.__vascGen1TitleMenuPresentation == nil
    and rootState.draw == nativeRootDraw
    and rootState.drawWidescreen == nil
    and rootState.uiSize == nil
    and rootState.sgbPalettes == nil
    and rootState.update == update and rootState.onNewGame ~= nil,
  "VASC replaced the native Gen1 logo / Press Start TitleState")
rootState:draw()
assert(nativeDraws == 1 and #specs == 0,
  "native Gen1 title root did not remain the sole renderer")
local menu = {
  titleUiBox={0,0,12,9}, index=2, update=update,
  draw=function() nativeDraws=nativeDraws+1 end,
  items={
    {label="CONTINUE", onSelect=function() end},
    {label="NEW GAME", onSelect=callbacks.new},
    {label="OPTION", onSelect=callbacks.options},
    {label="EXIT GAME", onSelect=function() end},
  },
}
pushed({state=menu})
assert(menu.__vascGen1TitleMenuPresentation == "title-choice")
assert(menu.__ascendantGlobalUiSkinSkip == true)
assert(menu.update == update and menu.items[2].onSelect == callbacks.new
  and menu.items[3].onSelect == callbacks.options,
  "title hub changed native behavior ownership")
menu:draw()
assert(nativeDraws == 1 and specs[#specs].edition == "blue"
  and specs[#specs].language == "de" and specs[#specs].index == 2
  and specs[#specs].generation == 1 and specs[#specs].game == menu.game,
  "Gen1 title view model is incomplete")
menu:drawWidescreen(1600, 900)
assert(specs[#specs].physical[1] == 1600 and menu:uiSize() == 512
  and menu:drawsWidescreen() and menu:wantsFillScale(),
  "Gen1 title hub is not a full-surface renderer")
local zones = menu:sgbPalettes()
assert(type(zones) == "table" and #zones == 1
  and zones[1].colors == false and zones[1].x == 0 and zones[1].y == 0
  and zones[1].w == 512 and zones[1].h == 288,
  "Gen1 title hub did not suppress the underlying 160x144 SGB zones")
universalBoot = "en"
assert(module.languageForQA() == "en",
  "Universal English boot receipt did not control Gen1 title language")
universalBoot = nil
assert(module.languageForQA() == "en",
  "Gen1 title language did not fall back to English without Universal German")
universalBoot = "de"

package.loaded["src.inventory.Badges"] = {count=function() return 3 end}
local confirm = {titleUiBox={4,7,19,16}, game={data={}},
  save={player={name="BLAU"}, pokedex={owned={a=true,b=true}}, playTime=3720},
  update=update, draw=function() nativeDraws=nativeDraws+1 end}
pushed({state=confirm}); confirm:draw()
assert(confirm.__vascGen1TitleMenuPresentation == "continue-info"
  and specs[#specs].items[1].right == "BLAU"
  and specs[#specs].items[2].right == "3"
  and specs[#specs].items[4].right == "1:02",
  "Gen1 CONTINUE receipt was not routed through the shared hub")
assert(confirm:sgbPalettes()[1].colors == false
  and confirm:sgbPalettes()[1].w == 512,
  "Gen1 CONTINUE card leaked native TitleState palette zones")

local active=menu
for _, boot in ipairs({false, "en", "de"}) do
  universalBoot=boot
  confirm:draw()
  assert(specs[#specs].footer == (boot == "de"
    and "A: WEITER   B: ZURÜCK" or "A: CONTINUE   B: BACK"))
end
local game={stack={top=function() return active end}}
local function nextHud() return "native-hud" end
assert(hudHook(nextHud,game,{gameX=999,width=1900})=="native-hud")
assert(detailCalls==1,"desktop post-title group was not redrawn")
menu.__vascGen1MobileMenuBridge=true
hudHook(nextHud,game,{})
assert(detailCalls==1,"desktop artwork redrew the mobile HD owner")
menu.__vascGen1MobileMenuBridge=nil
for _,other in ipairs({rootState,confirm,{screenId="OptionsMenu"},
    {screenId="ChoiceBox"},{screenId="BattleState"}}) do
  active=other;hudHook(nextHud,game,{})
end
assert(detailCalls==1,"artwork leaked over native title, child menu or battle")
active=menu;rect.uiw=160;hudHook(nextHud,game,{})
assert(detailCalls==1,"stale logical viewport was used for artwork")
rect.uiw=512

Hub.draw=function() return false end
local fallback={titleUiBox={0,0,12,7}, items=menu.items,
  draw=function() nativeDraws=nativeDraws+1 end}
pushed({state=fallback}); fallback:draw()
assert(nativeDraws == 2, "failed title painter did not restore native draw")
print("Gen1 native title preserved; post-title choices/CONTINUE use hub")
