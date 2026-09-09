-- Johto entrance markers: a rounded ball on a low, inset plaque pedestal.
-- Only the exact native sixteen placements/artworks are eligible.
-- Local production hook; release remains separate from visual acceptance.
local P={}
local specs={
 VIOLET_GYM={5,8,'TILESET_ELITE_FOUR_ROOM',3,6,12},
 AZALEA_GYM={5,8,'TILESET_ELITE_FOUR_ROOM',3,6,12},
 GOLDENROD_GYM={10,9,'TILESET_ELITE_FOUR_ROOM',1,4,14},
 ECRUTEAK_GYM={5,9,'TILESET_TOWER',3,6,14},
 CIANWOOD_GYM={5,9,'TILESET_TOWER',3,6,14},
 OLIVINE_GYM={5,8,'TILESET_CHAMPIONS_ROOM',3,6,12},
 MAHOGANY_GYM={5,9,'TILESET_ELITE_FOUR_ROOM',3,6,14},
 BLACKTHORN_GYM_1F={5,9,'TILESET_ELITE_FOUR_ROOM',3,6,14},
}
local tiles={
 TILESET_ELITE_FOUR_ROOM={32,33,48,49,34,35,50,51},
 TILESET_TOWER={40,41,56,57,42,43,58,59},
 TILESET_CHAMPIONS_ROOM={46,47,62,63,78,79,94,95},
}
local rows={
 '3000000000000003','0033001111003300','0330111221110330','0301112332111030',
 '0301112332111030','0011111221111100','0011111111111100','0001111111111000',
 '0030011001100300','0033000330003300','0003330330333000','0300333003330030',
 '0300003333000030','0300000000000030','0330000000000330','0333333333333330',
 '0333333333333310','0332222222222110','0332222222222110','0332222222222110',
 '0332111111132110','0332122222232110','0132121111232100','0310122222230010',
 '0132121211232100','0310122222230010','0332121121232110','0332122222232110',
 '0332333333332110','0332222222222110','1032222222222101','1100000000000011',
}
function P.find(map)
 local d=map and map.def;local s=d and specs[map.id];local out={}
 if not(s and d.generation==2 and d.width==s[1] and d.height==s[2] and d.tileset==s[3]
  and d.environment=='INDOOR' and d.outdoor~=true and next(d.connections or{})==nil
  and (map.tileset.tilesPerRow or 16)==16)then return out end
 for i=4,5 do
  local x,y=s[i],s[6];local ok=map:cellCollision(x,y)==7 and map:cellCollision(x,y+1)==7
   and not map:isWarpTileCell(x,y) and not map:isWarpTileCell(x,y+1)
  for dy=0,3 do for dx=0,1 do
   ok=ok and map:tileAt(x*2+dx,y*2+dy)==tiles[d.tileset][dy*2+dx+1]
  end end
  if ok then out[#out+1]={x=x,y=y}end
 end
 return out
end

-- Merge only coplanar equal-colour faces with identical outward winding.
-- Source-front pixels keep distinct UV centres, so no lettering is blurred.
local function merge(input,budget)
 local groups,order={},{}
 for _,q in ipairs(input)do
  if budget and budget.tick then budget.tick()end
  local a,b,f
  for axis=1,3 do if q[1][axis]~=q[2][axis]then a=axis elseif q[2][axis]~=q[3][axis]then b=axis else f=axis end end
  local sa=q[2][a]>q[1][a]and 1 or-1;local sb=q[3][b]>q[2][b]and 1 or-1
  local k=table.concat({a,b,sa,sb,q[1][f],q.u,q.v,q.shade,q.surface},':')
  local g=groups[k]
  if not g then
   g={a=a,b=b,f=f,sa=sa,sb=sb,plane=q[1][f],u=q.u,v=q.v,shade=q.shade,surface=q.surface,
    cells={},a0=999,a1=-999,b0=999,b1=-999};groups[k]=g;order[#order+1]=g
  end
  local x,y=math.min(q[1][a],q[2][a]),math.min(q[2][b],q[3][b])
  g.cells[y]=g.cells[y]or{};assert(not g.cells[y][x]);g.cells[y][x]=true
  g.a0,g.a1,g.b0,g.b1=math.min(g.a0,x),math.max(g.a1,x),math.min(g.b0,y),math.max(g.b1,y)
 end
 local out={}
 for _,g in ipairs(order)do for b=g.b0,g.b1 do for a=g.a0,g.a1 do
  if budget and budget.tick then budget.tick()end
  if g.cells[b]and g.cells[b][a]then
   local right=a;while g.cells[b][right+1]do right=right+1 end
   local bottom=b
   while g.cells[bottom+1]do
    local full=true;for x=a,right do if not g.cells[bottom+1][x]then full=false;break end end
    if not full then break end;bottom=bottom+1
   end
   for y=b,bottom do for x=a,right do g.cells[y][x]=nil end end
   local a0,a1=g.sa>0 and a or right+1,g.sa>0 and right+1 or a
   local b0,b1=g.sb>0 and b or bottom+1,g.sb>0 and bottom+1 or b
   local q={u=g.u,v=g.v,shade=g.shade,surface=g.surface}
   for i,p in ipairs({{a0,b0},{a1,b0},{a1,b1},{a0,b1}})do
    local v={};v[g.a],v[g.b],v[g.f]=p[1],p[2],g.plane;q[i]=v
   end
   out[#out+1]=q
  end
 end end end
 return out
end
function P.model(data,tileset,budget,raw)
 local ts=tiles[tileset]
 if not(ts and data and data.getDimensions and data.getPixel)then return nil end
 local w,h=data:getDimensions();if w~=128 or h~=128 then return nil end
 local uvs={}
 for y=0,31 do for x=0,15 do
  if budget and budget.tick then budget.tick()end
  local t=ts[math.floor(y/8)*2+math.floor(x/8)+1]
  local sx,sy=t%16*8+x%8,math.floor(t/16)*8+y%8
  local row=(tileset=='TILESET_CHAMPIONS_ROOM'and y==13)and'0300110000110030'or rows[y+1]
  local want=tonumber(row:sub(x+1,x+1))/3
  local r,g,b,a=data:getPixel(sx,sy)
  if math.abs(r-want)>.001 or math.abs(g-want)>.001 or math.abs(b-want)>.001 or(a and a<.99)then return nil end
  uvs[y*16+x]={(sx+.5)/w,(sy+.5)/h}
 end end
 local function uv(x,y)return uvs[y*16+x]end
 local stone,dark,red,white=uv(7,19),uv(7,8),uv(6,2),uv(7,10)
 local function occupied(x,y,z)
  if x<0 or x>=16 or y<0 or y>=30 or z<0 or z>=32 then return false end
  if y<2 then return true end -- only the low foot spans both blocked cells
  if y<14 then return x>=1 and x<15 and z>=10 and z<22 end
  if y<16 then return z>=8 and z<24 end
  return (x+.5-8)^2+(y+.5-23)^2+(z+.5-16)^2<=7.2^2
 end
 local q={};local stats={voxels=0,height=30,ballPixels=0,plaquePixels=0}
 local function face(a,b,c,d,shade,color,surface)
  for _,v in ipairs({a,b,c,d})do v[1]=v[1]-8;v[3]=v[3]-16 end
  q[#q+1]={a,b,c,d,u=color[1],v=color[2],shade=shade,surface=surface}
 end
 for y=0,29 do for z=0,31 do for x=0,15 do
  if budget and budget.tick then budget.tick()end
  if occupied(x,y,z)then
   stats.voxels=stats.voxels+1
   -- The native ball is painted in top-down perspective: projecting those
   -- pixels onto a sphere duplicates its outline as black/white stripes.
   -- Wrap native palette samples around the actual volume instead. Apply
   -- the front button to every exposed voxel face, including stair risers,
   -- so an oblique camera cannot reveal a differently painted side face.
   local color=y>=24 and red or(y>=22 and dark or white)
   if y<16 then color=stone
   elseif z>=16 then
    local radius2=(x+.5-8)^2+(y+.5-23)^2
    if radius2<=2.2^2 then color=white
    elseif radius2<=3.2^2 then color=dark end
   end
   if not occupied(x,y,z+1)then
    local front,surface=color,'plain'
    if y>=16 then surface='ball-front';stats.ballPixels=stats.ballPixels+1
    elseif y>=2 and y<14 and z==21 and x>=3 and x<13 then
     front=uv(x,31-y);surface='plaque-front';stats.plaquePixels=stats.plaquePixels+1
    end
    face({x,y,z+1},{x+1,y,z+1},{x+1,y+1,z+1},{x,y+1,z+1},1,front,surface)
   end
   if not occupied(x,y,z-1)then face({x+1,y,z},{x,y,z},{x,y+1,z},{x+1,y+1,z},.68,color,'plain')end
   if not occupied(x-1,y,z)then face({x,y,z},{x,y,z+1},{x,y+1,z+1},{x,y+1,z},.78,color,'plain')end
   if not occupied(x+1,y,z)then face({x+1,y,z+1},{x+1,y,z},{x+1,y+1,z},{x+1,y+1,z+1},.78,color,'plain')end
   if not occupied(x,y+1,z)then face({x,y+1,z},{x,y+1,z+1},{x+1,y+1,z+1},{x+1,y+1,z},1.12,color,'plain')end
   if not occupied(x,y-1,z)then face({x+1,y,z},{x+1,y,z+1},{x,y,z+1},{x,y,z},.55,color,'plain')end
  end
 end end end
 stats.rawQuads=#q
 return raw and q or merge(q,budget),stats
end
local cache=setmetatable({},{__mode='k'})
local function key(x,y)return(y+64)*4096+x+64 end
function P.build(S,map,data,budget)
 local targets=P.find(map);if #targets==0 or not data then return 0 end
 local ts=map.def.tileset;local entries=cache[data];local model=entries and entries[ts]
 if not model then
  model=P.model(data,ts,budget);if not model then return 0 end
  entries=entries or{};entries[ts]=model;cache[data]=entries
 end
 local count=0
 for _,p in ipairs(targets)do
  local free=true
  for dy=0,3 do for dx=0,1 do free=free and not S.skip[key(p.x*2+dx,p.y*2+dy)]end end
  if free then
   if budget and budget.check then budget.check()end
   S.roundStamps[#S.roundStamps+1]={quads=model,mx=p.x*16+8,my=0,mz=p.y*16+16,r=16}
   for dy=0,3 do for dx=0,1 do
    local k=key(p.x*2+dx,p.y*2+dy)
    S.skip[k]=true;S.ground[k]=false;S.shapeAt[k]={class='building',art='building',h=0,flat=false,authored=true}
   end end
   count=count+1
  end
 end
 return count
end
return P
