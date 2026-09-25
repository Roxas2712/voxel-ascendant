local f=assert(io.open('battle_hud_oras.lua'));local source=f:read('*a');f:close()
local a=assert(source:find('-- Battle YES / NO presentation',1,true))
local b=assert(source:find('-- Native bottom-UI suppression',a,true))
local Choice={};Choice.__index=Choice
function Choice.new(game, callback) return setmetatable({game=game,onChoose=callback,update=function()end},Choice)end
local battle={phase='messages'};local game={stack={states={battle}}};local hooks={}
local env=setmetatable({require=function(name)assert(name=='src.ui.ChoiceBox');return Choice end,
 floatingCommandsEnabled=function(b)return b==battle end,
 HudRuntime={battleStateInStack=function()return battle end,moveLearnTextBoxInStack=function()end,nicknameTextBoxInStack=function()end,
 stateInStack=function(_,state)for _,s in ipairs(game.stack.states)do if s==state then return true end end end},
 mod={hooks={wrap=function(_,name,fn)hooks[name]=fn end}}},{__index=_G})
local code=assert(loadstring(source:sub(a,b-1),'@battle-choice-owner'));setfenv(code,env);code()
local direct=Choice.new(game,function()end);assert(direct.__floatingBattleChoice==battle,'trainer choice lost HUD')
game.stack.states={battle,direct};assert(hooks['screen.render_visible'](function()return true end,direct)==false,'direct choice drew twice')
for _,base in ipairs({{kind='bag'},{kind='party'},{isTextBox=true}})do
 game.stack.states={battle,base};local calls=0;local choose=Choice.new(game,function()calls=calls+1 end)
 assert(not choose.__floatingBattleChoice,'unrelated menu choice claimed')
 game.stack.states={battle,base,choose}
 assert(hooks['screen.render_visible'](function()return true end,choose)==true,'unrelated menu choice hidden')
 choose.onChoose(true);assert(calls==1,'choice callback changed')
end
print('battle choice ownership: ok')
