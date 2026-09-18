-- Native sign interactions stay with the map. Only their 3D artwork changes.
local V=...
local M={}
M.setting=V.require('ModSetting').new('outdoorSigns','VOXEL SIGNS',{true,false},{'ON','OFF'})
local towns={
 PALLET_TOWN={{'ALABASTIA'},{'PALLET','TOWN'}},
 VIRIDIAN_CITY={{'VERTANIA'},{'VIRIDIAN','CITY'}},
 PEWTER_CITY={{'MARMORIA'},{'PEWTER','CITY'}},
 CERULEAN_CITY={{'AZURIA'},{'CERULEAN','CITY'}},
 VERMILION_CITY={{'ORANIA'},{'VERMILION','CITY'}},
 LAVENDER_TOWN={{'LAVANDIA'},{'LAVENDER','TOWN'}},
 CELADON_CITY={{'PRISMANIA'},{'CELADON','CITY'}},
 FUCHSIA_CITY={{'FUCHSANIA'},{'FUCHSIA','CITY'}},
 SAFFRON_CITY={{'SAFFRONIA'},{'SAFFRON','CITY'}},
 CINNABAR_ISLAND={{'ZINNOBER','INSEL'},{'CINNABAR','ISLAND'}},
 INDIGO_PLATEAU={{'INDIGO','PLATEAU'},{'INDIGO','PLATEAU'}},
 VIRIDIAN_FOREST={{'VERTANIA','WALD'},{'VIRIDIAN','FOREST'}},
}
function M.language()
 local mod=V.mod
 if type(mod)=='table' and type(mod.find)=='function'then
  local ok,handle=pcall(mod.find,'translation-german-universal')
  local lang=ok and handle and handle.exports and handle.exports.bootLanguage
  if lang=='de' or lang=='en'then return lang end
  local got,version=pcall(require,'src.core.GameVersion')
  local id=({red='deutsch',blue='deutsch-blau',yellow='deutsch-gelb'})[got and version.get() or 'red']
  if id then local found,h=pcall(mod.find,id);if found and h then return 'de' end end
 end
 return 'en'
end
function M.lines(map,x,y,language)
 local de=(language or M.language())=='de';local text=''
 for _,sign in ipairs(map.def.signs or{})do
  if sign.x==math.floor(x/2) and sign.y==math.floor(y/2)then text=sign.text or '';break end
 end
 local token='TEXT_'..map.id:gsub('_','')..'_SIGN'
 local suffix=text:sub(#token+1)
 local town=towns[map.id] and text:sub(1,#token)==token and (suffix=='' or suffix:match('^%d+$'))
 -- Only actual location nameplates are large. All service/help signs stay
 -- compact and reveal their original content through the native text window.
 if town then return towns[map.id][de and 1 or 2]end
 return {}

end
local glyphs={
 A={'010','101','111','101','101'},B={'110','101','110','101','110'},C={'011','100','100','100','011'},
 D={'110','101','101','101','110'},E={'111','100','110','100','111'},F={'111','100','110','100','100'},
 G={'011','100','101','101','011'},H={'101','101','111','101','101'},I={'111','010','010','010','111'},
 J={'001','001','001','101','010'},K={'101','101','110','101','101'},Q={'010','101','101','111','011'},
 W={'101','101','111','111','101'},X={'101','101','010','101','101'},Y={'101','101','010','010','010'},
 L={'100','100','100','100','111'},M={'101','111','111','101','101'},N={'101','111','111','111','101'},
 O={'010','101','101','101','010'},P={'110','101','110','100','100'},R={'110','101','110','101','101'},
 S={'011','100','010','001','110'},T={'111','010','010','010','010'},U={'101','101','101','101','111'},
 V={'101','101','101','101','010'},Z={'111','001','010','100','111'},
 ['0']={'111','101','101','101','111'},['1']={'010','110','010','010','111'},
 ['2']={'110','001','010','100','111'},['3']={'110','001','010','001','110'},
 ['4']={'101','101','111','001','001'},['5']={'111','100','110','001','110'},
 ['6']={'011','100','111','101','111'},['7']={'111','001','010','010','010'},
 ['8']={'111','101','111','101','111'},['9']={'111','101','111','001','110'},
}
M.glyphs=glyphs
function M.register(P,F)
 local C=P.decorColors
 local function create(map,x,y)
  local route=map.id:match('^ROUTE_(%d+)$')
  local lines=M.lines(map,x,y)
  local kind='kanto_sign_'..map.id..'_'..(#lines>0 and table.concat(lines,'_')or'notice')
  if P.models[kind]then return kind end
  local stone=map.id=='PEWTER_CITY' or map.id=='INDIGO_PLATEAU'
  local longest=0;for _,line in ipairs(lines)do longest=math.max(longest,#line)end
  local width=#lines>0 and math.max(22,longest*4+5)or 16;local left=math.floor((16-width)/2)
  local bottom=#lines>0 and 16 or 10;local height=#lines>0 and #lines*7+6 or 10;local top=bottom+height
  -- Only the raised board overhangs. The base and supports keep the original
  -- sign cell; no walkability, native map tile or interaction point is edited.
  local a={terrain=true,step=1,boxes={},frameW=16,frameH=top+18,depth=16,offsetY=-top-2,
    boardBounds={left,left+width},boardBottom=bottom,labelLines=lines}
  P.models[kind]=a
  a.glassKind=kind..'_glass';a.windowLight=V.require('Gen1PalletVillage').windowLight
  P.models[a.glassKind]={terrain=true,step=1,frameW=16,frameH=top+18,depth=16,offsetY=-top-2,
    boxes={{5,top+1,8,6,1,2,11}}}
  local function b(x,y,z,w,h,d,c)a.boxes[#a.boxes+1]={x,y,z,w,h,d,c}end
  local accents={VIRIDIAN_CITY=C.roofGreen,CERULEAN_CITY=8,LAVENDER_TOWN=C.fadedPlum or C.purple,
    CELADON_CITY=C.roofGreen,FUCHSIA_CITY=C.sage,CINNABAR_ISLAND=C.clay}
  local accent=(stone and C.slate or route and C.roofGreen or accents[map.id] or C.navy)or 10
  b(1,0,3,14,2,10,stone and 14 or C.walnut)
  for _,xx in ipairs({3,11})do
   b(xx,2,6,2,bottom+1,3,stone and 14 or C.oak)
   b(xx-1,bottom-2,5,4,2,5,C.walnut)
  end
  b(left,bottom,4,width,height,4,stone and 14 or C.oak)
  b(left+1,bottom+1,8,width-2,height-2,1,accent)
  b(left-1,top,3,width+2,1,6,C.walnut);b(left,top+1,4,width,1,4,C.oak)
  b(left-1,bottom-1,3,width+2,1,6,C.walnut)
  -- A hooded night lamp illuminates the top of the nameplate.
  b(4,top+2,7,8,1,4,C.walnut)
  for row,line in ipairs(lines)do
   local offset=math.floor((16-(#line*4-1))/2)
   local baseline=top-3-(row-1)*7
   for i=1,#line do local glyph=glyphs[line:sub(i,i)]
    if glyph then for gy,scan in ipairs(glyph)do for gx=1,3 do
     if scan:sub(gx,gx)=='1'then b(offset+(i-1)*4+gx-1,baseline-gy,9,1,1,1,4)end
    end end end
   end
  end
  if #lines==0 then
   b(4,top-3,9,8,1,1,4);b(4,top-5,9,6,1,1,4);b(4,top-7,9,7,1,1,4)
  end
  b(left+2,bottom+1,9,1,1,1,11);b(left+width-3,bottom+1,9,1,1,1,11)
  b(5,bottom+1,9,6,1,1,C.oak)
  return kind
 end
 for _,spec in ipairs({{set='OVERWORLD',tiles={{70,71},{86,87}}},
   {set='FOREST',tiles={{33,34},{49,50}}}})do
  F.patterns[#F.patterns+1]={kind='kanto_sign',sets={[spec.set]=true},tiles=spec.tiles,
   groundTile=spec.set=='FOREST'and 0 or 44,voxelOnly=true,
   enabled=function()return M.setting:get()end,
   guard=function(map)return map.def.generation~=2 end,
   variant=create}
 end
end
function M.bind(invalidate)
 for _,method in ipairs({'setIndex','sync'})do
  local old=M.setting[method]
  M.setting[method]=function(self,...)
   local before=self:get();local result=old(self,...)
   if before~=self:get()then invalidate()end
   return result
  end
 end
end
return M
