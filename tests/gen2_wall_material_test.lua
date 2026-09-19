-- Native source fixtures independently captured from Crystal's Johto sheet.
local signatures={
 [7]='3333333322222223222222233333333322232222222322223333333332222223',
 [27]='2323232333323333333333333332333323232323333333323333333333333332',
}
local function image()
 local p={}
 function p:getDimensions()return 128,128 end
 function p:getPixel(x,y)return unpack(self[y*128+x] or {.1,.2,.3,1})end
 function p:setPixel(x,y,...)self[y*128+x]={...}end
 return p
end
local src,out=image(),image()
for tile,s in pairs(signatures)do for y=0,7 do for x=0,7 do
 local v=tonumber(s:sub(y*8+x+1,y*8+x+1))/3
 src:setPixel(tile%16*8+x,math.floor(tile/16)*8+y,v,v,v,1)
 out:setPixel(tile%16*8+x,math.floor(tile/16)*8+y,v,.7*v,.5*v,1)
end end end
local dependencies={['src.render.Assets']={},['src.render.GbcPalette']={},['src.world.gen2.Palettes']={}}
local chunk=assert(loadfile('gen2/lib/GoldColorAtlas.lua'))
setfenv(chunk,setmetatable({require=function(n)return assert(dependencies[n])end},{__index=_G}))
local M=chunk()
local map={def={tileset='TILESET_JOHTO',environment='TOWN'},tileset={}}
local function snapshot(p)local copy={};for y=0,127 do for x=0,127 do copy[y*128+x]={p:getPixel(x,y)}end end;return copy end
local before=snapshot(out);local source=snapshot(src)
assert(M.styleWalls(src,out,map,'gbc')==2)
local changes=0
for y=0,127 do for x=0,127 do
 local k=y*128+x;local tile=math.floor(y/8)*16+math.floor(x/8)
 local rgba={out:getPixel(x,y)};local orig={src:getPixel(x,y)}
 for i=1,4 do
  assert(orig[i]==source[k][i],'borrowed source mutated')
  if not signatures[tile]then assert(rgba[i]==before[k][i],'non-wall art changed')end
 end
 if signatures[tile]then
  changes=changes+1
  assert(rgba[1]>=.90 and rgba[1]<=.95,'stipple contrast not reduced')
  assert(rgba[4]==1,'opaque wall became transparent')
 end
end end
assert(changes==128)
-- Every single-pixel source replacement must disable the entire affected tile.
for tile in pairs(signatures)do for y=0,7 do for x=0,7 do
 local px,py=tile%16*8+x,math.floor(tile/16)*8+y
 local original={src:getPixel(px,py)};src:setPixel(px,py,.5,.5,.5,1)
 assert(M.styleWalls(src,image(),map,'gbc')==1,'custom wall was overwritten')
 src:setPixel(px,py,unpack(original))
end end end
for _,mode in ipairs({'dmg','classic'})do assert(M.styleWalls(src,image(),map,mode)==0)end
map.def.environment='INDOOR';assert(M.styleWalls(src,image(),map,'gbc')==0)
map.def.environment='TOWN';map.def.tileset='TILESET_KANTO';assert(M.styleWalls(src,image(),map,'gbc')==0)
map.def.tileset='TILESET_JOHTO';map.tileset.trueColor=true;assert(M.styleWalls(src,image(),map,'gbc')==0)
print('PASS_NATIVE_WALL_MATERIAL_PIXEL_GUARDS_OPACITY_AND_SCOPE')
