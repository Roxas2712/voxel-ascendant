local boot, hud = nil, 'de'
local mod={options={get=function() return hud end},find=function()
  return boot and {exports={bootLanguage=boot}} or nil
end}
local drawn
local Bridge=assert(loadfile('gen2/lib/SharedVascMenuPresentation.lua'))({mod=mod,
  Style={new=function(_,opts) return {decorateFocusHelp=function(menu)
    menu.draw=function(self) drawn={language=self.__vascLanguage,footer=self.footer} end
    return menu
  end} end}})
local owner={game={save={}}}
for _,value in ipairs({false,'en','de'}) do
  boot=value or nil
  for _,stored in ipairs({'de','en'}) do
    hud=stored
    assert(Bridge.draw(owner,{title='START',items={{label='TEST'}}},600,1200))
    local expected=boot=='de' and 'de' or 'en'
    assert(drawn.language==expected,'shared menu language followed HUD instead of translation')
    assert(drawn.footer==(expected=='de' and 'A: AUSWAHL   B: ZURÜCK' or 'A: SELECT   B: BACK'))
  end
end
print('PASS Gen2 shared menu headings/footer follow Universal boot language')
