-- Native party rows are black-on-white, while their message box uses light ink.
for _,path in ipairs({'lib/OrasUiSkin.lua','lib/gen2_a21_shared/OrasUiSkin.lua'})do
 local color,shader={0,0,0,1},'upstream';local tx,ty=0,0;local failPaint=false
 local calls={};local ink={send=function()end}
 local g={newShader=function()return ink end,getShader=function()return shader end,
  setShader=function(value)shader=value end,getColor=function()return unpack(color)end,
  setColor=function(...)color={...}end,transformPoint=function(x,y)return x+tx,y+ty end,
  rectangle=function()if failPaint then error('paint unavailable')end end}
 love={graphics=g}
 local Font={drawBox=function()return 'native-box'end,
  drawCode=function(code,x,y)calls[#calls+1]={code=code,shader=shader,color=color[1]}end}
 local originalCode,originalBox=Font.drawCode,Font.drawBox
 local mod={exports={},events={on=function()end},options={get=function()return 'oras'end}}
 local module=assert(loadfile(path))({})
 assert(module.install({mod=mod,Font=Font,PaletteFX={}}))
 local state={draw=function()
  Font.drawCode('name',24,0)
  Font.drawBox(0,12,20,6)
  Font.drawCode('hp',104,8) -- Native body remains native even after a box exists.
  Font.drawCode('prompt',8,112)
  tx,ty=30,20;Font.drawBox(0,0,5,3);tx,ty=0,0
  Font.drawCode('translated',38,28)
  Font.drawCode('outside',0,0)
 end}
 assert(select(2,module.decorateInstance(state)))
 state:draw()
 assert(calls[1].shader=='upstream' and calls[2].shader=='upstream',path..': native party ink was recolored')
 assert(calls[3].shader==ink and calls[4].shader==ink,path..': glass text lost light ink')
 assert(calls[5].shader=='upstream',path..': ink escaped painted region')
 assert(Font.drawCode==originalCode and Font.drawBox==originalBox and shader=='upstream' and color[1]==0)
 local broken={draw=function()Font.drawBox(0,0,20,18);Font.drawCode('box',8,8);error('draw failure')end}
 module.decorateInstance(broken);assert(not pcall(broken.draw,broken))
 assert(Font.drawCode==originalCode and Font.drawBox==originalBox and shader=='upstream')
 failPaint=true;calls={}
 local fallback={draw=function()Font.drawBox(0,0,20,18);Font.drawCode('native fallback',8,8)end}
 module.decorateInstance(fallback);fallback:draw()
 assert(calls[1].shader=='upstream','failed glass paint still changes text ink')
 print('PASS ink regions, transformed boxes, native fallback and error restoration: '..path)
end
