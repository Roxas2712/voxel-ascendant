-- Garment definitions are shared by every animation, not copied per pose.
local function rgb(hex)
  return {tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255}
end
local rows={
  {'city','Stadtbummel','City walk','B73735','393644','76927C','EFE6CF','283F59','B88945','zip'},
  {'trail','Pfadfinder','Trail scout','A84432','715291','396D51','D9C9A3','535343','A57A35','pockets'},
  {'league','Liga','League','B72732','503575','193E36','EEE4CC','272C35','C5A54F','piping'},
  {'coast','Kuestentour','Coastal trip','DA574B','47689B','3A8580','F3E7C9','273F56','C49B65','sailor'},
  {'rain','Regentag','Rainy day','D99D30','415684','638155','F2D999','2B3749','6D5140','rain'},
  {'winter','Winterreise','Winter journey','913B42','56436F','365848','E1DCCF','363A43','866650','fleece'},
  {'training','Training','Training','C73735','76509A','39775B','DADDDD','272B34','B5B1A5','sport'},
  {'safari','Safari','Safari','BB714A','817257','637952','EBDBC1','746C52','84603C','pockets'},
  {'night','Abendrunde','Evening walk','632E3A','392D59','243D3B','B6ADA3','20252D','866644','zip'},
  {'festival','Festtag','Festival','A92834','68438C','216955','F4E6C5','343242','C3A051','formal'},
}
local C={version=2,order={'RED','BLUE','GREEN'},characters={},
  uppers={'preset','original','hoodie','field','league','sailor','raincoat','fleece','sport','vest','shirt','cardigan','tee'},
  lowers={'preset','original','jeans','cargo','track','shorts','skirt','dress'},
  footwear={'preset','original','sneakers','ankleboots','tallboots','loafers'}}
local upperByPreset={'hoodie','field','league','sailor','raincoat','fleece','sport','vest','hoodie','shirt'}
local lowerByPreset={'jeans','cargo','track','shorts','cargo','jeans','track','shorts','jeans','track'}
for index,id in ipairs(C.order)do
  local entries={}
  for _,r in ipairs(rows)do
    entries[#entries+1]={id=r[1],de=r[2],en=r[3],pattern=r[10],
      top=rgb(r[3+index]),lining=rgb(r[7]),bottom=rgb(r[8]),bag=rgb(r[9]),trim=rgb('D8CAB0')}
  end
  C.characters[id]=entries
end
-- Columns 7..10 are lining, trousers, bag, garment pattern respectively.
for _,id in ipairs(C.order)do for i,outfit in ipairs(C.characters[id])do
  local r=rows[i]
  outfit.lining=rgb(r[7]);outfit.bottom=rgb(r[8]);outfit.bag=rgb(r[9])
  outfit.trim=rgb((i==3 or i==10) and 'C5A54F' or 'E3D9C5')
  outfit.pattern=r[10]
  outfit.upper=upperByPreset[i]
  outfit.footwear=({'sneakers','ankleboots','loafers','sneakers','ankleboots','ankleboots','sneakers','ankleboots','sneakers','loafers'})[i]
  outfit.lower=id=='GREEN'and(({[1]='skirt',[3]='dress',[6]='dress',[9]='skirt',[10]='dress'})[i]or lowerByPreset[i])or lowerByPreset[i]
end end
-- Green's signature belongs to an accessory, not a mandatory green outfit.
-- Her real green bag/strap remains protected by the authored overlay masks.
local greenPalette={
  city={'D5BE96','23334A'},trail={'AD6543','BDA783'},league={'7D2B47','39303D'},
  coast={'E7DCC2','29456A'},rain={'D6A13F','353C45'},winter={'765273','313340'},
  training={'C56D62','303847'},safari={'B5A580','424E3D'},night={'29466B','252F42'},
  festival={'A999C5','57374E'},
}
for _,outfit in ipairs(C.characters.GREEN)do
  local palette=greenPalette[outfit.id]
  outfit.top=rgb(palette[1]);outfit.bottom=rgb(palette[2])
  outfit.bag=rgb('3F7352');outfit.trim=rgb('4E885F')
  if outfit.id=='city'then outfit.upper='cardigan'end
  if outfit.id=='trail'then outfit.upper='tee';outfit.lower='cargo'end
  if outfit.id=='coast'then outfit.upper='tee';outfit.lower='jeans'end
  if outfit.id=='night'then outfit.upper='tee';outfit.lower='jeans'end
end
function C.find(character,id)
  for _,outfit in ipairs(C.characters[character]or{})do if outfit.id==id then return outfit end end
end
return C
