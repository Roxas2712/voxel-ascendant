-- Native Johto planters. Merge routine follows Gen2CeladonPlants;
-- glyphs, placement guards and geometry below are EliteFourRoom-specific.
local P={}
local function mergeFaces(input,budget)
 local groups,order={},{}
 for _,q in ipairs(input)do
  if budget and budget.tick then budget.tick()end
  local a,b,fixed
  for axis=1,3 do
   if q[1][axis]~=q[2][axis]then a=axis
   elseif q[2][axis]~=q[3][axis]then b=axis else fixed=axis end
  end
  assert(a and b and fixed,'nonaxis plant face')
  local sa=q[2][a]>q[1][a]and 1 or-1;local sb=q[3][b]>q[2][b]and 1 or-1
  local key=table.concat({a,b,sa,sb,q[1][fixed],q.u,q.v,q.shade},':')
  local g=groups[key]
  if not g then
   g={a=a,b=b,fixed=fixed,sa=sa,sb=sb,plane=q[1][fixed],u=q.u,v=q.v,shade=q.shade,cells={},loA=999,hiA=-999,loB=999,hiB=-999}
   groups[key]=g;order[#order+1]=g
  end
  local aa=math.min(q[1][a],q[2][a]);local bb=math.min(q[2][b],q[3][b])
  g.cells[bb]=g.cells[bb]or{};assert(not g.cells[bb][aa],'duplicate plant surface');g.cells[bb][aa]=true
  g.loA,g.hiA=math.min(g.loA,aa),math.max(g.hiA,aa)
  g.loB,g.hiB=math.min(g.loB,bb),math.max(g.hiB,bb)
 end
 local out={}
 for _,g in ipairs(order)do
  for b=g.loB,g.hiB do for a=g.loA,g.hiA do
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
    local q={u=g.u,v=g.v,shade=g.shade}
    for i,p in ipairs({{a0,b0},{a1,b0},{a1,b1},{a0,b1}})do
     local v={};v[g.a],v[g.b],v[g.fixed]=p[1],p[2],g.plane;q[i]=v
    end
    out[#out+1]=q
   end
  end end
 end
 return out
end

local specs={AZALEA_GYM={width=5,height=8},GOLDENROD_GYM={width=10,height=9}}
specs.AZALEA_GYM.flower="0:1 1:1 2:1 3:1 4:1 5:1 6:1 7:1 8:1 9:1 2:4 7:4 1:6 8:6 1:7 8:7 2:9 7:9 0:13 1:13 8:13 9:13 2:14 0:15 1:15 2:15 8:15 9:15"
specs.AZALEA_GYM.bush="0:0 1:0 2:0 3:0 4:0 5:0 6:0 7:0 8:0 9:0 3:4 6:4 2:5 7:5 2:8 7:8 3:9 6:9 0:12 1:12 8:12 9:12 0:14 1:14 8:14 9:14"
specs.GOLDENROD_GYM.flower="3:0 5:0 7:0 9:0 11:0 13:0 15:0 17:0 0:1 1:1 18:1 19:1 9:2 11:2 2:3 4:3 7:3 12:3 14:3 16:3 4:4 10:4 15:4 4:6 14:6 4:7 14:7 16:7 2:8 18:8 14:9 18:9 4:10 9:10 16:10 18:10 4:11 16:11 18:11 5:12 16:13 8:14 11:14 14:14 6:15 10:17 18:17"
specs.GOLDENROD_GYM.bush="0:0 1:0 2:0 4:0 6:0 8:0 10:0 12:0 14:0 16:0 18:0 19:0 7:2 8:2 10:2 3:3 5:3 6:3 13:3 15:3 17:3 3:4 5:4 7:4 11:4 12:4 14:4 16:4 19:4 1:5 4:5 9:5 10:5 15:5 1:6 7:7 10:7 17:7 1:8 3:8 4:8 7:8 10:8 14:8 17:8 2:9 15:9 3:10 6:10 8:10 12:10 1:11 15:11 2:12 4:12 14:12 18:12 0:13 5:13 17:13 6:14 9:14 10:14 15:14 16:14 18:14 7:15 8:15 11:15 12:15 14:15 0:16 7:16 8:16 13:16 14:16 16:16 11:17 19:17"
local signatures={
flower="3200000000000023203333333333330203100000011001300300110013310030030133101321103003013210011331300300110020132130030100000001103003100000000001300232222022222310021111102111111000111110211111000200000000000010022202222210111010110211111011012100000000000012",
bush="3200000001110023201221002323210202123211123231300201212122222020021111111212112002010101110110200210001010100120020000000000002003100000000001300232222022222310021111102111111000111110211111000200000000000010022202222210111010110211111011012100000000000012",
}
local arts={bush={7,8,23,24},flower={62,63,23,24}}
local function key(x,y)return(y+64)*4096+x+64 end
function P.find(map)
 local d=map and map.def;local spec=map and specs[map.id];local out={}
 if not(d and spec and d.generation==2 and d.tileset=='TILESET_ELITE_FOUR_ROOM'
  and d.width==spec.width and d.height==spec.height and d.environment=='INDOOR'
  and d.outdoor~=true and next(d.connections or{})==nil
  and map.tileset and (map.tileset.tilesPerRow or 16)==16)then return out end
 for _,frame in ipairs((map.tileset.anim and map.tileset.anim.frames)or{})do
  -- This tileset also owns lava animations. Only their exact native targets
  -- 56/91 are unrelated; unknown animation hooks must fail closed.
  local safe=frame.func=='WaitTileAnimation' or frame.func=='DoneTileAnimation'
   or frame.func=='StandingTileFrame8' and frame.tile==nil
   or frame.func=='AnimateLavaBubbleTile2' and frame.tile==56
   or frame.func=='AnimateLavaBubbleTile1' and frame.tile==91
  if not safe then return out end
 end
 for _,kind in ipairs({'bush','flower'})do
  for xs,ys in spec[kind]:gmatch('(%d+):(%d+)')do
   local x,y=tonumber(xs),tonumber(ys)
   local valid=map:cellCollision(x,y)==7 and not map:isWarpTileCell(x,y)
   for dy=0,1 do for dx=0,1 do
    valid=valid and map:tileAt(x*2+dx,y*2+dy)==arts[kind][dy*2+dx+1]
   end end
   if valid then out[#out+1]={x=x,y=y,kind=kind}end
  end
 end
 return out
end
local function source(atlas,kind)
 if not(atlas and atlas.getDimensions and atlas.getPixel and arts[kind])then return end
 local w,h=atlas:getDimensions();if w~=128 or h~=128 then return end
 local function texel(x,y)
  local tile=arts[kind][math.floor(y/8)*2+math.floor(x/8)+1]
  local sx,sy=tile%16*8+x%8,math.floor(tile/16)*8+y%8
  local r,g,b,a=atlas:getPixel(sx,sy)
  return(sx+.5)/128,(sy+.5)/128,r,g,b,a
 end
 local glyph={}
 for y=0,15 do for x=0,15 do
  local _,_,r,g,b,a=texel(x,y)
  if math.abs(r-g)>.001 or math.abs(g-b)>.001 or a<.99 then return end
  glyph[#glyph+1]=tostring(math.floor(r*3+.5))
 end end
 if table.concat(glyph)~=signatures[kind]then return end
 return texel
end
function P.model(atlas,kind,unmerged,budget)
 local texel=source(atlas,kind);if not texel then return end
 local foliage=kind=='flower' and source(atlas,'bush')or texel
 if not foliage then return end
 -- Both native variants are planters, not freestanding Celadon shrubs:
 -- a shallow masonry base supports foliage or a recognizable flower bed.
 local height=kind=='bush' and 12 or 9
 local function occupied(x,y,z)
  if x<0 or x>=16 or z<0 or z>=16 or y<0 or y>=height then return false end
  if y<4 then return true end
  if kind=='flower'then
   if y==4 then return true end
   if x<2 or x>13 or z<2 or z>13 then return false end
   local _,_,r=texel(x,math.floor(z/2))
   local color=math.floor(r*3+.5)
   return color~=0 and y<(color==3 and 7 or 9)
  end
  local X,Z,Y=x+.5-8,z+.5-8,y+.5-5
  return(X/7.8)^2+(Z/7.8)^2+(Y/7.8)^2<=1
 end
 local out={};local voxels=0
 local function face(a,b,c,d,shade,u,v)out[#out+1]={a,b,c,d,shade=shade,u=u,v=v}end
 for y=0,height-1 do for z=0,15 do for x=0,15 do
  if budget and budget.tick then budget.tick()end
  if occupied(x,y,z)then
   voxels=voxels+1;local X,Z=x-8,z-8
   local u,v=texel(x,math.floor(z/2))
   -- White pixels around the native flowers are a flat background, not
   -- a continuous white slab. Keep the red/grey petal glyphs raised above
   -- a green bed sampled from the independently guarded native bush art.
   if kind=='flower' and y<=4 then
    u,v=foliage(2+(x+z)%5,1+(math.floor(x/2)+math.floor(z/2))%3)
   end
   local fu,fv,bu,bv,lu,lv,ru,rv=u,v,u,v,u,v,u,v
   if y<4 then
    -- Preserve native bottom masonry on all sides, no mirrored front door/art.
    fu,fv=texel(x,15-y);bu,bv=texel(15-x,15-y)
    lu,lv=texel(z,15-y);ru,rv=texel(15-z,15-y)
   end
   if not occupied(x,y,z+1)then face({X,y,Z+1},{X+1,y,Z+1},{X+1,y+1,Z+1},{X,y+1,Z+1},1,fu,fv)end
   if not occupied(x,y,z-1)then face({X+1,y,Z},{X,y,Z},{X,y+1,Z},{X+1,y+1,Z},.76,bu,bv)end
   if not occupied(x-1,y,z)then face({X,y,Z},{X,y,Z+1},{X,y+1,Z+1},{X,y+1,Z},.90,lu,lv)end
   if not occupied(x+1,y,z)then face({X+1,y,Z+1},{X+1,y,Z},{X+1,y+1,Z},{X+1,y+1,Z+1},.82,ru,rv)end
   if not occupied(x,y+1,z)then face({X,y+1,Z},{X,y+1,Z+1},{X+1,y+1,Z+1},{X+1,y+1,Z},1,u,v)end
  end
 end end end
 return unmerged and out or mergeFaces(out,budget),{height=height,voxels=voxels,rawQuads=#out}
end
function P.build(S,map,atlas,budget)
 local targets=P.find(map);if #targets==0 then return 0 end
 local models={};local ready={}
 for _,p in ipairs(targets)do
  local free=true
  for dy=0,1 do for dx=0,1 do
   local k=key(p.x*2+dx,p.y*2+dy);local shape=S.shapeAt and S.shapeAt[k]
   free=free and not S.skip[k] and S.ground[k]==nil
    and shape and shape.class=='wall' and not shape.authored
  end end
  if free then
   if models[p.kind]==nil then models[p.kind]=P.model(atlas,p.kind,false,budget)or false end
   if models[p.kind]then ready[#ready+1]=p end
  end
 end
 -- Budgeted construction finishes before any shared Structures mutation.
 for _,p in ipairs(ready)do
  S.roundStamps[#S.roundStamps+1]={quads=models[p.kind],mx=p.x*16+8,my=0,mz=p.y*16+8,r=8}
  -- Late claims only: keep the original shape/run/ground analysis intact.
  -- The closed 16x16 base covers the original footprint without new floor.
  for dy=0,1 do for dx=0,1 do S.skip[key(p.x*2+dx,p.y*2+dy)]=true end end
 end
 return #ready
end
return P
