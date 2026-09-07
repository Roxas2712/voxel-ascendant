local root=assert(arg[1])
local texts, boot, fullscreen = {}, false, false
local function capture(s) texts[#texts+1]=tostring(s) end
local font={getWidth=function(_,s)return #s*4 end}
local g={}
for _,k in ipairs({'setColor','rectangle','setLineWidth','push','pop','origin',
  'setBlendMode','setFont','circle','line','setScissor'})do g[k]=function()end end
g.print=capture;g.printf=capture;g.newFont=function()return font end
g.getFont=function()return font end;g.getDimensions=function()return 1280,720 end
love={graphics=g}
local mod={options={get=function(_,key)
  if key=='hud_language' then return 'de' end
  if key=='qol_ui_skin' then return 'oras_glass' end
end},find=function(id)
  if id=='translation-german-universal' and boot then return {exports={bootLanguage=boot}} end
end}
local style=assert(loadfile(root..'/gen2/lib/PauseMenuBattleStyle.lua'))({mod=mod,
  SharedMenuPresentation={draw=function(_,spec)
    capture(spec.title);capture(spec.footer)
    for _,row in ipairs(spec.items)do capture(row.label);capture(row.help)end
    return true
  end}})
local items={}
for _,id in ipairs({'pokedex','pokemon','pack','pokegear','status','save','option','mods','quit'})do
  items[#items+1]={value=id,label='NATIVE',desc='NATIVE'}
end
local native=function()error('unexpected native fallback: '..tostring(style.lastError))end
local menu={screenId='Gen2StartMenu',items=items,list={index=1},game={},draw=native}
assert(style.decorateResolvedStart(menu))
for _,language in ipairs({false,'en','de'})do
  boot=language
  for _,full in ipairs({false,true})do
    menu._vascGen2StartFullscreen=full
    for _,phase in ipairs({'menu','confirm'})do
      menu.phase=phase;texts={};menu:draw()
      local out=table.concat(texts,'|')
      assert(not style.lastError,style.lastError)
      if boot=='de' then
        assert(out:find('ZURÜCK',1,true),out)
        if phase=='menu' then assert(out:find('TASCHE',1,true),out)end
      else
        assert(out:find('B: BACK',1,true),out)
        for _,word in ipairs({'TASCHE','SPEICHERN','ZURÜCK','ÖFFNEN','STEUERKREUZ','NEIN','BEENDEN'})do
          assert(not out:find(word,1,true),out)
        end
        if phase=='menu' then assert(out:find('BAG',1,true),out)end
      end
    end
  end
end
print('PASS Gen2 actual START draw: compact/fullscreen, normal/quit, absent/English/German Universal; saved German battle HUD ignored')
