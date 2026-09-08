-- Regression: enter() pushes its dialog BEFORE the parent's screen.pushed.
local nativeLove = love
local listeners, texts, language = {}, {}, "en"
local function emit(event) for _, fn in ipairs(listeners[event.name] or {}) do fn(event) end end
local Move = {}; Move.__index=Move
function Move:draw() end
function Move:finish(value) return value end
local Text={}; Text.__index=Text
local Choice={}; Choice.__index=Choice
package.loaded["src.ui.MoveLearnMenu"]=Move
package.loaded["src.render.TextBox"]=Text
package.loaded["src.ui.ChoiceBox"]=Choice
package.loaded["src.mods.Runtime"]={wants=function()return true end,wantsHook=function()return false end,emit=function(name,event)event.name=name;emit(event)end}
local engine=assert(os.getenv("GEN1RECOMP_DIR"))
local Stack=assert(loadfile(engine.."/src/core/StateStack.lua"))()
local graphics={}
for _,name in ipairs({"push","pop","setColor","rectangle","setLineWidth","translate","scale","setShader","setScissor","setBlendMode"}) do graphics[name]=function()end end
love={graphics=graphics, event=nativeLove.event}
package.loaded["src.core.Strings"]=function(s)return s end
package.loaded["src.render.Font"]={draw=function(t)texts[#texts+1]=t end,width=function(t)return #t*8 end}
local context={mod={find=function(id)if id=="translation-german-universal" then return {exports={bootLanguage=language}} end end}}
local overlay=assert(loadfile("lib/OrasPartyOverlayPresentation.lua"))(context)
context.require=function(name)if name=="OrasPartyOverlayPresentation" then return overlay end end
local module=assert(loadfile(os.getenv("MOVE_LEARN_SOURCE") or "lib/MoveLearnPresentation.lua"))(context)
assert(module.install({events={on=function(_,name,fn)listeners[name]=listeners[name] or {};table.insert(listeners[name],fn);return function()end end}}))
local stack=setmetatable({}, {__index=Stack});stack:init()
local game={stack=stack,data={moves={TACKLE={name="TACKLE"},GROWL={name="GROWL"},TAIL_WHIP={name="TAIL WHIP"},CUT={name="CUT"},SURF={name="SURF"}}}}
local battle={isOpaque=true,isWideBattleLayout=function()return true end,uiSize=function()return 304,144 end}
stack:push(battle)
local menu=setmetatable({game=game,mon={species="TAUROS",moves={{id="TACKLE"},{id="GROWL"},{id="TAIL_WHIP"},{id="CUT"}}},newMoveId="SURF",index=1},Move)
local prompt=setmetatable({game=game,draw=function()end},Text)
local original=prompt.draw
menu.enter=function()stack:push(prompt)end
stack:push(menu)
assert(stack:top()==prompt,"fixture missed nested enter prompt")
assert(menu.isWideBattleLayout and menu:isWideBattleLayout(),"move owner lost to lower battle")
assert(prompt.uiSize and select(1,prompt:uiSize())==512,"initial prompt collapsed canvas")
assert(prompt.__vascOrasWideTextBox,"initial native prompt omitted")
assert(prompt:isWideBattleLayout(),"initial prompt centred as classic overlay")
local choice=setmetatable({game=game,draw=function()end,index=1},Choice);stack:push(choice)
assert(choice.__vascOrasWideChoiceBox and select(1,choice:uiSize())==512,"nested yes/no collapsed canvas")
stack:pop();stack:pop()
menu.selecting=true
for _,lang in ipairs({"en","de","en"}) do
 language=lang;texts={};menu:draw();local result=table.concat(texts,"|")
 assert(result:find(lang=="de" and "ATTACKE LERNEN" or "LEARN A MOVE",1,true),"wrong language")
 assert(not result:find("CANCEL",1,true),"unreachable fifth menu row")
 for _,id in ipairs({"TACKLE","GROWL","TAIL WHIP","CUT"})do assert(result:find(id,1,true),"missing selectable move")end
end
local foreign=function()end;prompt.draw=foreign
stack:pop()
assert(menu.isWideBattleLayout==nil and menu.uiSize==nil,"owner geometry not restored")
assert(prompt.draw==foreign,"foreign modal draw overwritten")
assert(prompt.uiSize==nil,"modal geometry leaked on release")
assert(stack:top()==battle and select(1,battle:uiSize())==304,"battle was changed")
love=nativeLove
print("MOVE_LEARN_MODAL_SURFACE_PASS")
