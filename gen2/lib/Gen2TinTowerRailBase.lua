-- Tin6's north rail reuses the column's bottom-fringe tile. It is not a
-- second 32px cliff beneath the already-standing native fence posts.
local P={}
local signature={
 [2]='2222222211111111333333332221222221222112222222222112222222222221',
 [94]='1101111110111010010101011000100001010101101000100000000000000000',
}
local function key(x,y)return(y+64)*4096+x+64 end
function P.matches(map)
 local d=map and map.def;local ts=map and map.tileset
 if not(d and map.id=='TIN_TOWER_6F' and d.id==map.id and d.generation==2
  and d.tileset=='TILESET_TOWER' and d.width==10 and d.height==9
  and d.environment=='DUNGEON' and d.outdoor~=true and next(d.connections or{})==nil
  and ts and ts.tilesPerRow==16 and ts.tilePalettes
  and ts.tilePalettes[3]==6 and ts.tilePalettes[95]==6)then return false end
 for _,f in ipairs((ts.anim or{}).frames or{})do
  if f.tile==2 or f.tile==94 then return false end
 end
 for x=4,15 do
  if map:cellCollision(x,3)~=7 or map:isWarpTileCell(x,3)then return false end
  for _,w in ipairs(d.warps or{})do if w.x==x and (w.y==2 or w.y==3)then return false end end
  if map:cellCollision(x,2)~=7 then return false end
  for dx=0,1 do
   if map:tileAt(x*2+dx,4)~=17 or map:tileAt(x*2+dx,5)~=33
    or map:tileAt(x*2+dx,6)~=94 or map:tileAt(x*2+dx,7)~=1 then return false end
  end
 end
 return true
end
local function valid(atlas,budget)
 if not(atlas and atlas.getDimensions and atlas.getPixel)then return false end
 local w,h=atlas:getDimensions();if w~=128 or h~=128 then return false end
 for tile,s in pairs(signature)do for y=0,7 do
  if budget and budget.tick then budget.tick()end
  for x=0,7 do
   local r,g,b,a=atlas:getPixel(tile%16*8+x,math.floor(tile/16)*8+y)
   local v=tonumber(s:sub(y*8+x+1,y*8+x+1))/3
   if math.abs(r-v)>.001 or math.abs(g-v)>.001 or math.abs(b-v)>.001 or math.abs(a-1)>.001 then return false end
  end
 end end
 return true
end
function P.geometry(budget)
 local q={}
 local function face(points,shade,tone)
  if budget and budget.tick then budget.tick()end
  points.u=(16.5)/128;points.v=(tone==2 and .5 or 1.5)/128
  points.shade=shade;q[#q+1]=points
 end
 -- One connected plinth, no internal end faces at cell boundaries. All
 -- coordinates are local to center(160,52), wholly within the24 tile claim.
 for x=-96,80,16 do
  local tone=(x/16)%3==0 and 2 or 1
  face({{x,0,4},{x+16,0,4},{x+16,6,4},{x,6,4}},1,tone)
  face({{x+16,0,-4},{x,0,-4},{x,6,-4},{x+16,6,-4}},.76,tone)
  face({{x,6,-4},{x,6,4},{x+16,6,4},{x+16,6,-4}},1,tone)
  face({{x,0,4},{x,0,-4},{x+16,0,-4},{x+16,0,4}},.55,1)
 end
 face({{-96,0,-4},{-96,0,4},{-96,6,4},{-96,6,-4}},.90,1)
 face({{96,0,4},{96,0,-4},{96,6,-4},{96,6,4}},.82,1)
 return q
end
function P.build(S,map,atlas,budget)
 if not(P.matches(map)and valid(atlas,budget)and S and S.skip and S.ground
  and S.shapeAt and S.tileAt and S.roundStamps)then return 0 end
 for x=8,31 do
  local k=key(x,6);local sh=S.shapeAt[k]
  if S.skip[k]or S.ground[k]~=nil or S.tileAt[k]~=94 or not sh
   or sh.class~='cliff' or sh.h~=32 or not sh.authored then return 0 end
 end
 local quads=P.geometry(budget)
 -- Publish only when validation and cooperative geometry construction finish.
 S.roundStamps[#S.roundStamps+1]={quads=quads,mx=160,my=0,mz=52,r=96}
 for x=8,31 do local k=key(x,6);S.skip[k]=true;S.ground[k]=1 end
 return 12
end
return P
