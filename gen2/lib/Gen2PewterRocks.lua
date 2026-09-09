-- Exact Crystal Pewter arena rocks, built as one shared stamp template.
-- Front pixels come from native Tower art; unseen depth is authored.
-- Bounds, collision, placement and glyph guards intentionally fail closed.
-- Crystal Pewter's own Tower art; do not apply to Gen1, Cianwood or Burned Tower.
local R={}
local function mergeFaces(input,budget)
 local groups,order={},{}
 for _,q in ipairs(input)do
  if budget and budget.tick then budget.tick()end
  local a,b,fixed
  for axis=1,3 do
   if q[1][axis]~=q[2][axis]then a=axis
   elseif q[2][axis]~=q[3][axis]then b=axis else fixed=axis end
  end
  assert(a and b and fixed,'nonaxis quarry face')
  local sa=q[2][a]>q[1][a]and 1 or-1;local sb=q[3][b]>q[2][b]and 1 or-1
  local key=table.concat({a,b,sa,sb,q[1][fixed],q.u,q.v,q.shade},':')
  local g=groups[key]
  if not g then
   g={a=a,b=b,fixed=fixed,sa=sa,sb=sb,plane=q[1][fixed],u=q.u,v=q.v,shade=q.shade,cells={},loA=999,hiA=-999,loB=999,hiB=-999}
   groups[key]=g;order[#order+1]=g
  end
  local aa=math.min(q[1][a],q[2][a]);local bb=math.min(q[2][b],q[3][b])
  g.cells[bb]=g.cells[bb]or{};assert(not g.cells[bb][aa],'duplicate quarry surface');g.cells[bb][aa]=true
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
local nativeRows={
 [0]={0,1,2,3,4,5,6,7,8,9},[1]={0,9},[2]={0,9},[3]={0,9},
 [4]={0,1,2,3,6,7,8,9},[5]={0,9},[6]={0,2,3,6,7,9},[7]={0,9},
 [8]={0,2,3,6,7,9},[9]={0,9},[10]={0,1,8,9}}
local positions={};for y,xs in pairs(nativeRows)do for _,x in ipairs(xs)do positions[y*16+x]=true end end
local art={4,5,20,21}
local signature='2222221111122222111110232210111133302333222103332202333322111022212333332221010220333332211110022133322111010101022331101010101002331101110101000132101021101010011111022201010110111022201010010101012201000210101000102210011021010102211010012210101000011222'
function R.matches(map,x,y)
 if type(x)~='number' or type(y)~='number' or x~=math.floor(x) or y~=math.floor(y) or x<0 or x>=10 or y<0 or y>=14 then return false end
 local d=map and map.def
 if not(d and map.id=='PEWTER_GYM' and d.generation==2 and d.tileset=='TILESET_TOWER'
  and d.width==5 and d.height==7 and d.environment=='INDOOR' and d.outdoor~=true
  and next(d.connections or{})==nil and positions[y*16+x])then return false end
 if map:cellCollision(x,y)~=7 then return false end
 for dy=0,1 do for dx=0,1 do if map:tileAt(x*2+dx,y*2+dy)~=art[dy*2+dx+1]then return false end end end
 return true
end
function R.model(atlas,unmerged,budget)
 if not(atlas and atlas.getDimensions and atlas.getPixel)then return nil end
 local w,h=atlas:getDimensions();if w~=128 or h~=128 then return nil end
 local function texel(x,y)
  local t=art[math.floor(y/8)*2+math.floor(x/8)+1]
  local sx,sy=t%16*8+x%8,math.floor(t/16)*8+y%8
  return (sx+.5)/w,(sy+.5)/h,atlas:getPixel(sx,sy)
 end
 local glyph={}
 for y=0,15 do for x=0,15 do
  local _,_,red,green,blue,alpha=texel(x,y)
  if math.abs(red-green)>.001 or math.abs(green-blue)>.001 or alpha<.99 then return nil end
  glyph[#glyph+1]=tostring(math.floor(red*3+.5))
 end end
 if table.concat(glyph)~=signature then return nil end
 local stoneU,stoneV=texel(10,4);local darkU,darkV=texel(9,6)
 -- Crystal's rock keeps its native front. A low offset ellipsoid and two
 -- unequal chipped planes round the shoulders instead of forming a cone.
 -- The 12px height and hidden depth remain an authored 3D inference.
 local function occupied(x,y,z)
  if x<0 or x>=16 or y<0 or y>=12 or z<0 or z>=16 then return false end
  local X=x+.5-7.0-y*.08
  local Z=z+.5-8.0+y*.035
  local Y=y+.5-3.6
  return (X/8.2)^2+(Z/7.8)^2+(Y/8.0)^2<=1
   and .8*X+.3*Z+y+.5<=12.5
   and -.5*X-.7*Z+y+.5<=13.0
 end
 local q={};local voxels=0
 local function face(a,b,c,d,shade,u,v)q[#q+1]={a,b,c,d,u=u,v=v,shade=shade}end
 for y=0,11 do for z=0,15 do for x=0,15 do
  if budget and budget.tick then budget.tick()end
  if occupied(x,y,z)then
   voxels=voxels+1;local X,Z=x-8,z-8
   -- Native front rows3..14: the bright upper pixels belong to the crown;
   -- outer floor rows do not become rock faces.
   local u,v=texel(x,14-y)
   if not occupied(x,y,z+1)then face({X,y,Z+1},{X+1,y,Z+1},{X+1,y+1,Z+1},{X,y+1,Z+1},1,u,v)end
   if not occupied(x,y,z-1)then face({X+1,y,Z},{X,y,Z},{X,y+1,Z},{X+1,y+1,Z},.78,stoneU,stoneV)end
   if not occupied(x-1,y,z)then face({X,y,Z},{X,y,Z+1},{X,y+1,Z+1},{X,y+1,Z},.90,stoneU,stoneV)end
   if not occupied(x+1,y,z)then face({X+1,y,Z+1},{X+1,y,Z},{X+1,y+1,Z},{X+1,y+1,Z+1},.84,stoneU,stoneV)end
   if not occupied(x,y+1,z)then face({X,y+1,Z},{X,y+1,Z+1},{X+1,y+1,Z+1},{X+1,y+1,Z},1.0,stoneU,stoneV)end
   if y>0 and not occupied(x,y-1,z)then face({X,y,Z+1},{X,y,Z},{X+1,y,Z},{X+1,y,Z+1},.55,darkU,darkV)end
  end
 end end end
 return unmerged and q or mergeFaces(q,budget),{height=12,voxels=voxels,rawQuads=#q}
end
local function key(x,y)return(y+64)*4096+x+64 end
function R.build(S,map,atlas,budget)
 local targets={}
 for y=0,13 do for x=0,9 do if R.matches(map,x,y)then
  local free=true;for dy=0,1 do for dx=0,1 do free=free and not S.skip[key(x*2+dx,y*2+dy)]end end
  if free then targets[#targets+1]={x,y}end
 end end end
 if #targets==0 then return 0 end
 local model=R.model(atlas,false,budget);if not model then return 0 end
 for _,p in ipairs(targets)do
  S.roundStamps[#S.roundStamps+1]={quads=model,mx=p[1]*16+8,my=0,mz=p[2]*16+8}
  for dy=0,1 do for dx=0,1 do local k=key(p[1]*2+dx,p[2]*2+dy)
   S.skip[k]=true;S.ground[k]=false;S.shapeAt[k]={class='building',art='building',h=0,flat=false,authored=true}
  end end
 end
 return #targets
end
return R
