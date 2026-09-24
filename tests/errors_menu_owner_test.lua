-- Gen2's Gen1-compat facade writes instance methods. An Errors wrapper must
-- use the native class so later quick-menu draw/touch wrappers remain visible.
local root=assert(arg[1])
for _,nativeClass in ipairs({false,true}) do
 local draws,panels,quick,facadeReads=0,0,0,0
 local Game={draw=function()draws=draws+1;return 'native-frame'end,
  touchpressed=function()return 'native-touch'end}
 local current
 local game=nativeClass and setmetatable({},{__index=Game}) or Game
 game.stack={top=function()return current end}
 local facade=setmetatable({},{__index=game,__newindex=function(_,key,value)game[key]=value end})
 local env=setmetatable({love={timer={getTime=function()return 0 end}},require=function(name)
  assert(name=='src.core.Game');facadeReads=facadeReads+1;return nativeClass and facade or Game
 end},{__index=_G})
 local load=assert(loadfile(root..'/lib/ErrorsMenu.lua'));setfenv(load,env)
 local module=load();local mod={exports={},hooks={wrap=function()end}}
 local result=module.install(mod,{items={},context={}},nativeClass and {Game=Game} or {})
 assert(facadeReads==(nativeClass and 0 or 1),'wrong native draw owner')
 if nativeClass then assert(rawget(game,'draw')==nil,'instance draw masks later class wrappers')end
 local errorsDraw=Game.draw
 function Game:draw(...)quick=quick+1;return errorsDraw(self,...)end
 assert(game:draw()=='native-frame' and draws==1 and quick==1)
 current=setmetatable({drawPhysical=function()panels=panels+1 end,pointer=function()return 'errors-touch'end},result.Screen)
 assert(game:draw()=='native-frame' and draws==2 and quick==2 and panels==1)
 assert(game:touchpressed('finger',1,1)=='errors-touch')
 current=nil;assert(game:touchpressed('finger',1,1)=='native-touch')
end
print('PASS Errors native Gen2 class and Gen1 draw/touch composition')
