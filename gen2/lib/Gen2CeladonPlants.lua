-- Native Crystal Celadon greenery: exact map, collision and source-art contracts.
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

local specs={}
local function add(kind,x,y,length)specs[y*16+x]={kind=kind,x=x,y=y,length=length}end
for x=0,9 do add('bush',x,1,16)end
for y=6,9 do for _,x in ipairs({0,1,8,9})do add('bush',x,y,16)end end
for y=12,13 do for _,x in ipairs({0,1,2,3,6,7,8,9})do add('bush',x,y,16)end end
for _,p in ipairs({{0,2},{1,2},{8,2},{9,2},{0,4},{1,4},{8,4},{9,4},{0,10},{9,10}})do add('long',p[1],p[2],32)end
for _,p in ipairs({{2,2},{3,2},{4,2},{5,2},{6,2},{7,2},{2,6},{3,6},{6,6},{7,6}})do add('short',p[1],p[2],16)end
local arts={bush={76,77,92,93},short={80,81,84,85},long={80,81,82,83,82,83,84,85}}
local signatures={
 bush='2323230003232323323000323000323221020223230103233202223232120232202010232120102330120210101110322001212121010013021212101010100200111101010101030100111110101102100101010101002330101000100010322300010000000123321000011000123223211012210113133232110000113232',
 short='0000000000000000033200122200023003001100103210300301221001211030001211210211003000121121110220300201221002211230030011001110203003000000000000300333333333333330022222222222222000000000000000000322222222222220033333333333332003333333333333200000000000000000',
 long='00000000000000000332001222000230030011001032103003012210012110300012112102110030001211211102203002012210022112300300110011102030030002200001103003101112001221000122021101211210002110010121121003010110111221000310210212111130031021020122103003001000201100300300022000011030031011120012210001220211012112100021100101211210030101101112210003102102121111300310210201221030030010002011003003000000000000300333333333333330022222222222222000000000000000000322222222222220033333333333332003333333333333200000000000000000',
}
local function key(x,y)return(y+64)*4096+x+64 end
local function staticArt(tileset)
 for _,frame in ipairs((tileset.anim and tileset.anim.frames)or{})do
  if frame.func~='WaitTileAnimation' and frame.func~='DoneTileAnimation'then return false end
 end
 return true
end
function P.find(map)
 local out={};local d=map and map.def
 if not(d and map.id=='CELADON_GYM' and d.generation==2 and d.tileset=='TILESET_TRAIN_STATION'
  and d.width==5 and d.height==9 and d.environment=='INDOOR' and d.outdoor~=true
  and next(d.connections or{})==nil and staticArt(map.tileset)
  and (map.tileset.tilesPerRow or 16)==16)then return out end
 for y=0,17 do for x=0,9 do local p=specs[y*16+x]
  if p then
   local valid=true;local tiles=arts[p.kind]
   for yy=y,y+p.length/16-1 do
    valid=valid and map:cellCollision(x,yy)==7 and not map:isWarpTileCell(x,yy)
   end
   for dy=0,p.length/8-1 do for dx=0,1 do
    valid=valid and map:tileAt(x*2+dx,y*2+dy)==tiles[dy*2+dx+1]
   end end
   if valid then out[#out+1]=p end
  end
 end end
 return out
end
local function source(atlas,kind)
 if not(atlas and atlas.getDimensions and atlas.getPixel)then return nil end
 local w,h=atlas:getDimensions();if w~=128 or h~=128 then return nil end
 local art=arts[kind];if not art then return nil end
 local length=#art*4
 local function texel(x,y)
  local tile=art[math.floor(y/8)*2+math.floor(x/8)+1]
  local sx,sy=tile%16*8+x%8,math.floor(tile/16)*8+y%8
  local r,g,b,a=atlas:getPixel(sx,sy)
  return (sx+.5)/128,(sy+.5)/128,r,g,b,a
 end
 local glyph={}
 for y=0,length-1 do for x=0,15 do
  local _,_,r,g,b,a=texel(x,y)
  if math.abs(r-g)>.001 or math.abs(g-b)>.001 or a<.99 then return nil end
  glyph[#glyph+1]=tostring(math.floor(r*3+.5))
 end end
 if table.concat(glyph)~=signatures[kind]then return nil end
 return texel,length
end
function P.model(atlas,kind,unmerged,budget)
 local texel,length=source(atlas,kind);if not texel then return nil end
 local function tick()if budget and budget.tick then budget.tick()end end
 local function leaf(x,y,z)
  -- Four genuine inner-leaf texels from the same atlas tile. Coherent 2px
  -- patches avoid a new noisy sample and UV at every voxel. Native fronts
  -- retain their original per-pixel coordinates independently below.
  local n=(math.floor(x/2)*7+math.floor(z/2)*11+math.floor(y/2)*3)%17
  if n<2 then return texel(3,4)
  elseif n<12 then return texel(4,4)
  elseif n<16 then return texel(2,4)
  else return texel(7,4)end
 end
 -- GoldColorAtlas recolors each 8x8 tile with one palette. Equal source
 -- shades inside that SAME tile are therefore interchangeable in the static
 -- atlas. Never alias across tiles; the native front band stays exact.
 local aliases={}
 local function pigment(u,v)
  local x,y=math.floor(u*128),math.floor(v*128)
  local r=atlas:getPixel(x,y)
  local tile=math.floor(y/8)*16+math.floor(x/8)
  local k=tile*4+math.floor(r*3+.5)
  local a=aliases[k]
  if not a then a={u,v};aliases[k]=a end
  return a[1],a[2]
 end
 local heights={}
 if kind~='bush'then
  for z=0,length-1 do heights[z]={};for x=0,15 do
   local sy=math.floor(z*(length-4)/length)
   local _,_,r=texel(x,sy);local color=math.floor(r*3+.5)
   local rim=x==0 or x==15 or sy==0 or sy>=length-8
   heights[z][x]=rim and 5 or color==0 and 4 or color==1 and 5 or 6
  end end
 end
 local function occupied(x,y,z)
  if x<0 or x>=16 or z<0 or z>=length or y<0 then return false end
  if kind~='bush'then return y<heights[z][x]end
  if y>=12 then return false end
  local X,Z,Y=x+.5-7.5,z+.5-7.8,y+.5-5.2
  return (X/7.8)^2+(Z/7.6)^2+(Y/7.0)^2<=1
 end
 local q={};local voxels=0;local maxHeight=kind=='bush' and 12 or 6
 local function face(a,b,c,d,shade,u,v)q[#q+1]={a,b,c,d,shade=shade,u=u,v=v}end
 for y=0,maxHeight-1 do for z=0,length-1 do for x=0,15 do
  tick()
  if occupied(x,y,z)then
   voxels=voxels+1
   local X,Z=x-8,z-length/2
   local u,v,fu,fv,sideU,sideV
   if kind=='bush'then
    u,v=leaf(x,y,z);fu,fv=texel(x,14-y)
    sideU,sideV=u,v
   else
    u,v=texel(x,math.floor(z*(length-4)/length))
    u,v=pigment(u,v)
    if z==length-1 then
     if y<4 then fu,fv=texel(x,length-1-y)else fu,fv=texel(x,length-8)end
    else fu,fv=u,v end
    if y<4 then sideU,sideV=texel(5,length-1-y)else sideU,sideV=u,v end
    sideU,sideV=pigment(sideU,sideV)
   end
   if not occupied(x,y,z+1)then face({X,y,Z+1},{X+1,y,Z+1},{X+1,y+1,Z+1},{X,y+1,Z+1},1,fu,fv)end
   if not occupied(x,y,z-1)then face({X+1,y,Z},{X,y,Z},{X,y+1,Z},{X+1,y+1,Z},.76,sideU,sideV)end
   if not occupied(x-1,y,z)then face({X,y,Z},{X,y,Z+1},{X,y+1,Z+1},{X,y+1,Z},.90,sideU,sideV)end
   if not occupied(x+1,y,z)then face({X+1,y,Z+1},{X+1,y,Z},{X+1,y+1,Z},{X+1,y+1,Z+1},.82,sideU,sideV)end
   if not occupied(x,y+1,z)then face({X,y+1,Z},{X,y+1,Z+1},{X+1,y+1,Z+1},{X+1,y+1,Z},1.0,u,v)end
   if y>0 and not occupied(x,y-1,z)then face({X,y,Z+1},{X,y,Z},{X+1,y,Z},{X+1,y,Z+1},.55,sideU,sideV)end
  end
 end end end
 return unmerged and q or mergeFaces(q,budget),{height=maxHeight,voxels=voxels,rawQuads=#q,length=length}
end
function P.build(S,map,atlas,budget)
 local found=P.find(map);if #found==0 then return 0 end
 local models={};local count=0
 for _,p in ipairs(found)do
  local free=true
  for dy=0,p.length/8-1 do for dx=0,1 do free=free and not S.skip[key(p.x*2+dx,p.y*2+dy)]end end
  if free then
   if models[p.kind]==nil then models[p.kind]=P.model(atlas,p.kind,false,budget)or false end
   local q=models[p.kind]
   if q then
    count=count+1
    S.roundStamps[#S.roundStamps+1]={quads=q,mx=p.x*16+8,my=0,mz=p.y*16+p.length/2,r=p.length/2}
    for dy=0,p.length/8-1 do for dx=0,1 do local k=key(p.x*2+dx,p.y*2+dy)
     S.skip[k]=true;S.ground[k]=87;S.shapeAt[k]={class='building',art='building',h=0,flat=false,authored=true}
    end end
   end
  end
 end
 return count
end
return P
