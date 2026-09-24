local M={}
function M.new(mod,game,guided,de,content)
 local function tr(en,german)return de and german or en end
 local ready=content.available()
 local explanation=tr('Included with VASC. No installation or download needed. Select models in Your Look.',
 'Mit VASC enthalten. Keine Installation und kein Download. Modelle unter Dein Look auswaehlen.')
 local help=ready and explanation or tr('Bundled models missing. Check the VASC files or update package. No separate Cobblemon download.',
 'Modelle fehlen. VASC-Dateien bzw. Updatepaket pruefen. Kein separater Cobblemon-Download.')
 local menu=guided(mod,game,{key='vasc_cobblemon',title='COBBLEMON',rows={
  {label='COBBLEMON',right=content.version,help=explanation},
  {label=tr('SOURCE','QUELLE'),right='VASC',help=explanation},
  {label='STATUS',right=ready and tr('AVAILABLE','VERFUEGBAR')or tr('CHECK FILES','DATEIEN PRUEFEN'),help=help},
  {label=tr('BACK','ZURUECK'),action='back',help=explanation},
 },help=help,onChoose=function(row)if row.action=='back'then game.stack:pop()end end})
 menu.showFirstGuide=function()return false end
 return menu
end
return M
