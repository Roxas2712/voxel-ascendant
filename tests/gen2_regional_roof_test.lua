local function pixels(w,h,value)
 local p={w=w,h=h,values={},released=0}
 function p:getDimensions()return self.w,self.h end
 function p:getPixel(x,y)
  assert(not self.dead and x>=0 and x<self.w and y>=0 and y<self.h)
  return self.values[y*self.w+x] or value,0,0,1
 end
 function p:setPixel(x,y,r)self.values[y*self.w+x]=r end
 function p:paste(src,dx,dy,sx,sy,sw,sh)
  for y=0,sh-1 do for x=0,sw-1 do self:setPixel(dx+x,dy+y,src:getPixel(sx+x,sy+y))end end
 end
 function p:release()self.released=self.released+1;assert(self.released==1);self.dead=true end
 return p
end
local base=pixels(128,32,1);local roofA=pixels(72,8,0);local roofB=pixels(72,8,2/3)
for t=0,8 do for y=0,7 do for x=0,7 do roofA:setPixel(t*8+x,y,(t*64+y*8+x)/600)end end end
local assets={base=base,roofA=roofA,roofB=roofB};local created={}
local function newImageData(w,h)local p=pixels(w,h,0);created[#created+1]=p;return p end
local colors={{255,255,255},{170,170,170},{85,85,85},{0,0,0}}
local set={};for i=1,8 do set[i]=colors end
local libs={
 ['src.render.Assets']={imageData=function(path)return assert(assets[path],'missing test roof')end},
 ['src.render.GbcPalette']={mode='gbc',resolve=function(c)return c end},
 ['src.world.gen2.Palettes']={DAYTIME_ID={DAY=1},daytimeFor=function()return 'DAY'end,bgSet=function()return set end},
}
local chunk=assert(loadfile('gen2/lib/GoldColorAtlas.lua'))
local env=setmetatable({require=function(n)return assert(libs[n])end,love={image={newImageData=newImageData},graphics={newImage=function()
 return {setFilter=function()end,release=function(self)assert(not self.dead);self.dead=true end}
end}}},{__index=_G})
setfenv(chunk,env);local M=chunk()
local composed=M.withRoof(base,roofA,16,newImageData)
for y=0,31 do for x=0,127 do
 local tile=math.floor(y/8)*16+math.floor(x/8)
 local expected=1
 if tile>=10 and tile<=18 then expected=roofA:getPixel((tile-10)*8+x%8,y%8)end
 assert(composed:getPixel(x,y)==expected,'roof copied outside its native tile slots')
 assert(base:getPixel(x,y)==1,'borrowed Assets data was changed')
end end
composed:release()
local ts={id='TilesetJohto',image='base',tilesPerRow=16,tilePalettes={}}
local map={id='TEST_TOWN',def={group=1,tileset='TILESET_JOHTO',palette='PALETTE_AUTO'},tileset=ts}
local world={map=map,daytime='DAY',game={data={gen2Palettes={}}},roofs={mapGroupRoofs={[1]='A',[2]='B',[3]='missing'},roofs={A={image='roofA'},B={image='roofB'},missing={image='absent'}}}}
local image,color,ok,err,key,geometry=M.forMap(world,map,{})
assert(ok and geometry and geometry:getPixel(80,0)==roofA:getPixel(0,0))
local image2,_,_,_,_,geometry2=M.forMap(world,map,{})
assert(image==image2 and geometry==geometry2,'same regional source was not reused')
-- An existing map id with a different native roof must not inherit its atlas.
map.def.group=2
local different,_,good,_,key2,geo2=M.forMap(world,map,{})
assert(good and different~=image and key~=key2 and geo2:getPixel(80,0)==2/3)
map.def.group=3
local _,fallback,fallbackOk,_,_,missing=M.forMap(world,map,{})
assert(fallbackOk and fallback and not missing,'missing roof lost coloured base fallback')
M.setLive({TEST_TOWN=true});assert(not geometry.dead and not geo2.dead)
M.setLive({});assert(geometry.dead and geo2.dead and image.dead and different.dead)
M.invalidate();assert(not base.dead and not roofA.dead and not roofB.dead)
print('PASS_REGIONAL_ROOF_COPY_CACHE_FALLBACK_AND_OWNERSHIP')
