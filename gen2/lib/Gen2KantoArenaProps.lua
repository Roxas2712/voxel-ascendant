-- Exact Crystal arena statues. Keep the native 16x32 front drawing once,
-- with a shallow voxel relief and plain material on the rear/side surfaces.
-- The two blocked source cells remain inside the model's pedestal footprint.
local P={}
local specs={
 PEWTER_GYM={ts='TILESET_TOWER',w=5,h=7,tiles={0x22,0x23,0x32,0x33,0x26,0x27,0x36,0x37},at={{2,10},{7,10}}},
 CERULEAN_GYM={ts='TILESET_PORT',w=5,h=8,tiles={6,7,0x16,0x17,8,9,0x18,0x19},at={{2,12},{6,12}}},
 VERMILION_GYM={ts='TILESET_GAME_CORNER',w=5,h=9,tiles={0x42,0x43,0x52,0x53,0x44,0x45,0x54,0x55},at={{3,14},{6,14}}},
 CELADON_GYM={ts='TILESET_TRAIN_STATION',w=5,h=9,tiles={0x48,0x49,0x58,0x59,0x4a,0x4b,0x5a,0x5b},at={{3,14},{6,14}}},
 FUCHSIA_GYM={ts='TILESET_LAB',w=5,h=9,tiles={0x4c,0x4d,0x5c,0x5d,0x4e,0x4f,0x5e,0x5f},at={{3,14},{6,14}}},
 SAFFRON_GYM={ts='TILESET_UNDERGROUND',w=10,h=9,tiles={7,8,0x17,0x18,9,0x19,0x30,0x31},at={{8,14}}},
 VIRIDIAN_GYM={ts='TILESET_TRAIN_STATION',w=5,h=9,tiles={0x48,0x49,0x58,0x59,0x4a,0x4b,0x5a,0x5b},at={{3,12},{6,12}}},
 FIGHTING_DOJO={ts='TILESET_TRAIN_STATION',w=5,h=6,tiles={0x48,0x49,0x58,0x59,0x10,1,0x5a,0x5b},at={{2,0},{7,0},{3,2},{6,2},{2,4},{7,4},{2,8},{7,8}}},
}
function P.find(map)
 local d=map and map.def;local s=d and specs[map.id or d.id];local out={}
 if not(s and d.generation==2 and d.tileset==s.ts and d.width==s.w and d.height==s.h
  and d.environment=='INDOOR' and d.outdoor~=true and next(d.connections or{})==nil)then return out end
 for _,p in ipairs(s.at)do
  local ok=map:cellCollision(p[1],p[2])==7 and map:cellCollision(p[1],p[2]+1)==7
  for dy=0,3 do for dx=0,1 do
   ok=ok and map:tileAt(p[1]*2+dx,p[2]*2+dy)==s.tiles[dy*2+dx+1]
  end end
  if ok then out[#out+1]={x=p[1],y=p[2],tiles=s.tiles}end
 end
 return out
end

function P.model(map,p,data,budget)
 if not(data and data.getPixel and data.getDimensions)then return nil end
 local aw,ah=data:getDimensions();local perRow=map.tileset.tilesPerRow or 16
 if perRow~=16 or aw~=128 or ah~=128 then return nil end
 local q={}
 local function source(x,y)
  local tile=p.tiles[math.floor(y/8)*2+math.floor(x/8)+1]
  return tile%perRow*8+x%8,math.floor(tile/perRow)*8+y%8
 end
 local function uv(x,y)local sx,sy=source(x,y);return {(sx+.5)/aw,(sy+.5)/ah}end
 local gold,stone=uv(2,2),uv(7,26)
 local function face(a,b,c,d,shade,color,coords)
  q[#q+1]={a,b,c,d,shade=shade,uv=coords or {color,color,color,color}}
 end
 -- Three shallow pedestal courses cover both native blocked cells. The
 -- figure stands centrally on its cap, rather than at the end of a long
 -- box. Each front row still samples its exact original pixels.
 local bands={{0,2,0,32},{2,14,3,29},{14,16,1,31}}
 for _,b in ipairs(bands)do
  local y0,y1,z0,z1=b[1],b[2],b[3],b[4]
  for y=y0,y1-1 do for col=0,1 do
   local sy=31-y;local tile=p.tiles[math.floor(sy/8)*2+col+1]
   local sx,ty=tile%perRow*8,math.floor(tile/perRow)*8+sy%8
   local x=col*8
   face({x,y,z1},{x+8,y,z1},{x+8,y+1,z1},{x,y+1,z1},1,nil,
    {{sx/aw,(ty+1)/ah},{(sx+8)/aw,(ty+1)/ah},{(sx+8)/aw,ty/ah},{sx/aw,ty/ah}})
  end end
  face({16,y0,z0},{0,y0,z0},{0,y1,z0},{16,y1,z0},.68,stone)
  face({0,y0,z0},{0,y0,z1},{0,y1,z1},{0,y1,z0},.78,stone)
  face({16,y0,z1},{16,y0,z0},{16,y1,z0},{16,y1,z1},.78,stone)
 end
 local function ledge(y,z0,z1,shade)
  face({0,y,z0},{0,y,z1},{16,y,z1},{16,y,z0},shade,stone)
 end
 ledge(2,0,3,1.12);ledge(2,29,32,1.12)
 ledge(14,3,1,.55);ledge(14,31,29,.55)
 ledge(16,1,31,1.12)
 -- Rounded cheeks and the native central muzzle make a compact carving.
 -- A one-voxel incision keeps dark details readable without projecting each
 -- shade into a separate long spike. The front drawing is retained once.
 local depths={}
 for y=0,15 do for x=0,15 do
  local sx,sy=source(x,y);local r,g,b=data:getPixel(sx,sy)
  local nx,ny=(x-7.5)/8,(y-7.5)/8
  local round=math.floor(6*math.sqrt(math.max(0,1-nx*nx-ny*ny))+.5)
  local muzzle=(x>=5 and x<=10 and y>=9 and y<=13)and 2 or 0
  depths[y*16+x]=22+round+muzzle-((r+g+b)<.5 and 1 or 0)
 end end
 local function depth(x,y)
  if x<0 or x>15 or y<0 or y>15 then return 20 end
  return depths[y*16+x]
 end
 for y=0,15 do for x=0,15 do
  if budget and budget.tick then budget.tick()end
  local z=depth(x,y);local low=31-y;local color=uv(x,y)
  face({x,low,z},{x+1,low,z},{x+1,low+1,z},{x,low+1,z},1,color)
  local v=depth(x-1,y)
  if v<z then face({x,low,v},{x,low,z},{x,low+1,z},{x,low+1,v},.78,gold)end
  v=depth(x+1,y)
  if v<z then face({x+1,low,z},{x+1,low,v},{x+1,low+1,v},{x+1,low+1,z},.78,gold)end
  v=depth(x,y-1)
  if v<z then face({x,low+1,v},{x,low+1,z},{x+1,low+1,z},{x+1,low+1,v},1.12,gold)end
  v=depth(x,y+1)
  if y<15 and v<z then face({x+1,low,v},{x+1,low,z},{x,low,z},{x,low,v},.55,gold)end
 end end
 -- The carving has a stepped, tapered rear hull. Its outer rim is shallow;
 -- only the central mass extends backward, so there is no full-size cube lid.
 for inset=0,3 do
  local x0,x1,y0,y1,z0,z1=inset,16-inset,16+inset,32-inset,18-inset*2,20-inset*2
  face({x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0},.78,gold)
  face({x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1},.78,gold)
  face({x0,y1,z0},{x0,y1,z1},{x1,y1,z1},{x1,y1,z0},1.12,gold)
  if inset>0 then face({x1,y0,z0},{x1,y0,z1},{x0,y0,z1},{x0,y0,z0},.55,gold)end
  -- Rear-facing ring between this course and the narrower following one.
  face({x1,y1-1,z0},{x0,y1-1,z0},{x0,y1,z0},{x1,y1,z0},.68,gold)
  face({x1,y0,z0},{x0,y0,z0},{x0,y0+1,z0},{x1,y0+1,z0},.68,gold)
  face({x0+1,y0+1,z0},{x0,y0+1,z0},{x0,y1-1,z0},{x0+1,y1-1,z0},.68,gold)
  face({x1,y0+1,z0},{x1-1,y0+1,z0},{x1-1,y1-1,z0},{x1,y1-1,z0},.68,gold)
 end
 face({12,20,12},{4,20,12},{4,28,12},{12,28,12},.68,gold)
 return q
end

local function key(x,y)return(y+64)*4096+x+64 end
function P.build(S,map,data,budget)
 local count=0
 for _,p in ipairs(P.find(map))do
  local quads=P.model(map,p,data,budget)
  if quads then
   local conflict=false
   for dy=0,3 do for dx=0,1 do conflict=conflict or S.skip[key(p.x*2+dx,p.y*2+dy)]end end
   if not conflict then
    for _,q in ipairs(quads)do
     if budget and budget.check then budget.check()end
     for i=1,4 do q[i][1]=q[i][1]+p.x*16;q[i][3]=q[i][3]+p.y*16 end
     q.own=true
     S.objectQuads[#S.objectQuads+1]=q
    end
    for dy=0,3 do for dx=0,1 do
     local k=key(p.x*2+dx,p.y*2+dy)
     S.skip[k]=true;S.ground[k]=false
     S.shapeAt[k]={class='building',art='building',h=0,flat=false,authored=true}
    end end
    count=count+1
   end
  end
 end
 return count
end
P.specs=specs
return P
