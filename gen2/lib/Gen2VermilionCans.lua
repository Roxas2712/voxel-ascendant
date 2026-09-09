-- Exact Crystal Vermilion cans with native material texels and fixed placement guards.
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
  assert(a and b and fixed,'nonaxis can face')
  local sa=q[2][a]>q[1][a]and 1 or-1;local sb=q[3][b]>q[2][b]and 1 or-1
  local key=table.concat({a,b,sa,sb,q[1][fixed],q.u,q.v,q.shade},':')
  local g=groups[key]
  if not g then
   g={a=a,b=b,fixed=fixed,sa=sa,sb=sb,plane=q[1][fixed],u=q.u,v=q.v,shade=q.shade,cells={},loA=999,hiA=-999,loB=999,hiB=-999}
   groups[key]=g;order[#order+1]=g
  end
  local aa=math.min(q[1][a],q[2][a]);local bb=math.min(q[2][b],q[3][b])
  g.cells[bb]=g.cells[bb]or{};assert(not g.cells[bb][aa],'duplicate can surface');g.cells[bb][aa]=true
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
local art={70,71,86,87}
local floorArt={1,16,17,18}
local signature='3333333333333333311111000111111331330011100333133130111111103313310111111111031331011100011103133101101110110313310001111100031331030011100303133103330003330313310133333331031331301133311033133130331113303313313300333003331331111100011111133333333333333333'
function R.matches(map,x,y)
 if type(x)~='number' or type(y)~='number' or x~=math.floor(x) or y~=math.floor(y)
  or x<1 or x>9 or x%2~=1 or (y~=7 and y~=9 and y~=11)then return false end
 local d=map and map.def
 if not(d and map.id=='VERMILION_GYM' and d.generation==2 and d.tileset=='TILESET_GAME_CORNER'
  and d.width==5 and d.height==9 and d.environment=='INDOOR' and d.outdoor~=true
  and next(d.connections or{})==nil and map.tileset and map.tileset.tilesPerRow==16)then return false end
 for _,frame in ipairs((map.tileset.anim or{}).frames or{})do
  if frame.func~='WaitTileAnimation' and frame.func~='DoneTileAnimation'then return false end
 end
 if map:cellCollision(x,y)~=7 then return false end
 for _,warp in ipairs(d.warps or{})do if warp.x==x and warp.y==y then return false end end
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
 local lid={texel(6,4)};local body={texel(7,10)};local seam={texel(6,5)}
 -- The source draws a pale short body, dark closed lid and central grip.
 -- Its square floor frame is not can geometry. Hidden depth and 10px total
 -- height are authored; this is not a promise to preserve 256 front pixels.
 local function occupied(x,y,z)
  if x<0 or x>=16 or z<0 or z>=16 or y<0 or y>=10 then return false end
  if y>=8 then return z>=7 and z<=8 and x>=6 and x<=9 and (y==9 or x==6 or x==9)end
  local radius=y>=6 and 7 or 6
  return (x+.5-8)^2+(z+.5-8)^2<=radius^2
 end
 local q,voxels={},0
 local function face(a,b,c,d,shade,uv)q[#q+1]={a,b,c,d,u=uv[1],v=uv[2],shade=shade}end
 for y=0,9 do for z=0,15 do for x=0,15 do
  if budget and budget.tick then budget.tick()end
  if occupied(x,y,z)then
   voxels=voxels+1;local X,Z=x-8,z-8
   local color=y==0 and lid or y<6 and body or y==6 and seam or y>=8 and seam or lid
   if not occupied(x,y,z+1)then face({X,y,Z+1},{X+1,y,Z+1},{X+1,y+1,Z+1},{X,y+1,Z+1},1,color)end
   if not occupied(x,y,z-1)then face({X+1,y,Z},{X,y,Z},{X,y+1,Z},{X+1,y+1,Z},.78,color)end
   if not occupied(x-1,y,z)then face({X,y,Z},{X,y,Z+1},{X,y+1,Z+1},{X,y+1,Z},.90,color)end
   if not occupied(x+1,y,z)then face({X+1,y,Z+1},{X+1,y,Z},{X+1,y+1,Z},{X+1,y+1,Z+1},.84,color)end
   if not occupied(x,y+1,z)then face({X,y+1,Z},{X,y+1,Z+1},{X+1,y+1,Z+1},{X+1,y+1,Z},1,y>=6 and lid or body)end
   if not occupied(x,y-1,z)then face({X,y,Z+1},{X,y,Z},{X+1,y,Z},{X+1,y,Z+1},.55,lid)end
  end
 end end end
 return unmerged and q or mergeFaces(q,budget),{height=10,voxels=voxels,rawQuads=#q}
end
local function key(x,y)return(y+64)*4096+x+64 end
-- Run after normal room analysis. Early claims alter the synthetic east
-- wall's region flood; replace only the identified native glyph plates.
function R.build(S,map,atlas,budget)
 if not(S.objectQuads and S.roundStamps and S.skip)then return 0 end
 local targets={}
 for y=7,11,2 do for x=1,9,2 do if R.matches(map,x,y)then
  local owned=true
  for dy=0,1 do for dx=0,1 do owned=owned and S.skip[key(x*2+dx,y*2+dy)]end end
  for _,stamp in ipairs(S.roundStamps)do
   if stamp.mx==x*16+8 and stamp.mz==y*16+8 then owned=false end
  end
  if owned then targets[#targets+1]={x=x,y=y,faces={}}end
 end end end
 if #targets==0 then return 0 end
 -- All old plate faces must use only this 16x16 atlas rectangle. In FULL
 -- analysis the adjacent wall contributes faces on x=160 too; bounding
 -- boxes alone would accidentally remove six wall faces at each edge can.
 for index,q in ipairs(S.objectQuads)do
  if budget and budget.tick then budget.tick()end
  local native=true
  for i=1,4 do
   local u,v=q.uv and q.uv[i][1]or q.u,q.uv and q.uv[i][2]or q.v
   if not(u and v and u>=48/128 and u<=64/128 and v>=32/128 and v<=48/128)then native=false;break end
  end
  if native then
   for _,p in ipairs(targets)do
    local inside=true
    for i=1,4 do local v=q[i]
     inside=inside and v[1]>=p.x*16 and v[1]<=(p.x+1)*16
      and v[3]>=p.y*16 and v[3]<=(p.y+1)*16 and v[2]>=0 and v[2]<=16
    end
    if inside then p.faces[#p.faces+1]=index;break end
   end
  end
 end
 local accepted={}
 for _,p in ipairs(targets)do if #p.faces==434 then accepted[#accepted+1]=p end end
 if #accepted==0 then return 0 end
 local model=R.model(atlas,false,budget);if not model then return 0 end
 local removed={}
 for _,p in ipairs(accepted)do for _,index in ipairs(p.faces)do removed[index]=true end end
 local preserved={}
 for index,q in ipairs(S.objectQuads)do if not removed[index]then preserved[#preserved+1]=q end end
 S.objectQuads=preserved
 for _,p in ipairs(accepted)do
  S.roundStamps[#S.roundStamps+1]={quads=model,mx=p.x*16+8,my=0,mz=p.y*16+8,r=7}
  for dy=0,1 do for dx=0,1 do
   S.ground[key(p.x*2+dx,p.y*2+dy)]=floorArt[dy*2+dx+1]
  end end
 end
 return #accepted
end
return R
