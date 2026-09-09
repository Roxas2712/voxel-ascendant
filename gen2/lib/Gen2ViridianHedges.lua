-- Native Crystal Viridian hedges; guarded late post-analysis owner.
-- Own map/art contract and clipped hedge volume; shared axis-face merging utility.
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
  assert(a and b and fixed,'nonaxis hedge face')
  local sa=q[2][a]>q[1][a]and 1 or-1;local sb=q[3][b]>q[2][b]and 1 or-1
  local key=table.concat({a,b,sa,sb,q[1][fixed],q.u,q.v,q.shade},':')
  local g=groups[key]
  if not g then
   g={a=a,b=b,fixed=fixed,sa=sa,sb=sb,plane=q[1][fixed],u=q.u,v=q.v,shade=q.shade,cells={},loA=999,hiA=-999,loB=999,hiB=-999}
   groups[key]=g;order[#order+1]=g
  end
  local aa=math.min(q[1][a],q[2][a]);local bb=math.min(q[2][b],q[3][b])
  g.cells[bb]=g.cells[bb]or{};assert(not g.cells[bb][aa],'duplicate hedge surface');g.cells[bb][aa]=true
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
local function add(art,coords)
 for x,y in coords:gmatch("(%d+),(%d+)")do specs[#specs+1]={x=tonumber(x),y=tonumber(y),art=art,half=art[1]==61}end
end
add({2,3,2,3},"2,0;3,0;4,0;5,0;6,0;7,0;0,1;1,1;8,1;9,1;1,4;8,4;2,5;3,5;6,5;7,5;2,8;7,8;0,13;1,13;8,13;9,13;0,14;9,14;0,15;9,15;0,16;3,16;6,16;9,16")
add({2,3,2,33},"0,8;8,8")
add({2,3,18,19},"0,0;1,0;8,0;9,0;0,2;1,2;8,2;9,2;2,4;3,4;6,4;7,4;0,5;9,5;2,6;3,6;6,6;7,6;0,9;1,9;3,9;6,9;8,9;9,9;0,10;1,10;8,10;9,10;0,12;1,12;8,12;9,12;1,14;8,14;0,17;1,17;2,17;7,17;8,17;9,17")
add({2,3,33,3},"1,8;9,8")
add({18,19,18,19},"2,1;3,1;4,1;5,1;6,1;7,1;1,5;8,5;2,9;7,9;3,17;6,17")
add({61,61,2,3},"0,4;9,4;3,8;6,8;2,16;7,16")
table.sort(specs,function(a,b)return a.y==b.y and a.x<b.x or a.y<b.y end)
local signatures={
 [2]="0000000003300032030322020302210203000002030111010321001103221111",
 [3]="0000000032000220203220202022102020000020201110102210011022211110",
 [18]="0000000001111111011111110111111101111111011111110111111100000000",
 [19]="0000000011111110111111101111111011111110111111101111111000000000",
 [33]="0000000001111110011111100111111001111110011111100111111000000000",
 [61]="1111111111111111112222221123332211232212112322121122111211222222",
}
local function key(x,y)return(y+64)*4096+x+64 end
local function layout(map)
 local d=map and map.def;local ts=map and map.tileset
 if not(d and ts and map.id=='VIRIDIAN_GYM'and d.id==map.id and d.generation==2
  and d.tileset=='TILESET_TRAIN_STATION'and d.width==5 and d.height==9
  and d.environment=='INDOOR'and d.outdoor~=true and next(d.connections or{})==nil
  and ts.tilesPerRow==16 and ts.tilePalettes)then return false end
 for t in pairs(signatures)do if ts.tilePalettes[t+1]~=(t==61 and 7 or 3)then return false end end
 for _,f in ipairs((ts.anim or{}).frames or{})do
  if f.func~='WaitTileAnimation'and f.func~='DoneTileAnimation'then return false end
 end
 return true
end
function P.find(map)
 local found={};if not layout(map)then return found end
 for _,p in ipairs(specs)do
  local ok=map:cellCollision(p.x,p.y)==7 and not map:isWarpTileCell(p.x,p.y)
  for _,w in ipairs(map.def.warps or{})do if w.x==p.x and w.y==p.y then ok=false end end
  for dy=0,1 do for dx=0,1 do
   if map:tileAt(p.x*2+dx,p.y*2+dy)~=p.art[dy*2+dx+1]then ok=false end
  end end
  if ok then found[#found+1]=p end
 end
 return found
end
local function validAtlas(atlas)
 if not(atlas and atlas.getDimensions and atlas.getPixel)then return false end
 local w,h=atlas:getDimensions();if w~=128 or h~=128 then return false end
 for t,s in pairs(signatures)do for y=0,7 do for x=0,7 do
  local r,g,b,a=atlas:getPixel(t%16*8+x,math.floor(t/16)*8+y)
  local shade=tonumber(s:sub(y*8+x+1,y*8+x+1))/3
  if math.abs(r-shade)>.001 or math.abs(g-shade)>.001 or math.abs(b-shade)>.001 or math.abs(a-1)>.001 then return false end
 end end end
 return true
end
function P.model(atlas,half,raw,budget)
 if not validAtlas(atlas)then return nil end
 local depth=half and 8 or 16
 local function tick()if budget and budget.tick then budget.tick()end end
 local function texel(t,x,y)return(t%16*8+x+.5)/128,(math.floor(t/16)*8+y+.5)/128 end
 local aliases={}
 local function pigment(u,v)
  local x,y=math.floor(u*128),math.floor(v*128);local t=math.floor(y/8)*16+math.floor(x/8)
  local r=atlas:getPixel(x,y);local k=t*4+math.floor(r*3+.5)
  if not aliases[k]then aliases[k]={u,v}end;return aliases[k][1],aliases[k][2]
 end
 local function occupied(x,y,z)
  if x<0 or x>=16 or z<0 or z>=depth or y<0 or y>=12 then return false end
  local inset=y<9 and 0 or y-8
  return x>=inset and x<16-inset and z>=inset and z<depth-inset
 end
 local function leaf(x,y,z)
  local n=(math.floor(x/2)*7+math.floor(y/2)*3+math.floor(z/2)*11)%19
  if n<2 then return texel(2,2,2)elseif n<10 then return texel(2,3,3)
  elseif n<17 then return texel(2,3,5)else return texel(2,3,2)end
 end
 local faces={};local voxels=0
 local function face(a,b,c,d,shade,u,v)
  u,v=pigment(u,v);faces[#faces+1]={a,b,c,d,shade=shade,u=u,v=v}
 end
 for y=0,11 do for z=0,depth-1 do for x=0,15 do
  tick();if occupied(x,y,z)then
   voxels=voxels+1;local X,Z=x-8,z-depth/2
   local u,v=leaf(x,y,z);local su,sv
   if y<4 then su,sv=texel(18,3,4)else su,sv=texel(x<8 and 2 or 3,x%8,11-y)end
   if not occupied(x,y,z+1)then face({X,y,Z+1},{X+1,y,Z+1},{X+1,y+1,Z+1},{X,y+1,Z+1},1,su,sv)end
   if not occupied(x,y,z-1)then face({X+1,y,Z},{X,y,Z},{X,y+1,Z},{X+1,y+1,Z},.76,su,sv)end
   if not occupied(x-1,y,z)then face({X,y,Z},{X,y,Z+1},{X,y+1,Z+1},{X,y+1,Z},.90,y<4 and su or u,y<4 and sv or v)end
   if not occupied(x+1,y,z)then face({X+1,y,Z+1},{X+1,y,Z},{X+1,y+1,Z},{X+1,y+1,Z+1},.82,y<4 and su or u,y<4 and sv or v)end
   if not occupied(x,y+1,z)then face({X,y+1,Z},{X,y+1,Z+1},{X+1,y+1,Z+1},{X+1,y+1,Z},1,u,v)end
   if not occupied(x,y-1,z)then face({X,y,Z+1},{X,y,Z},{X+1,y,Z},{X+1,y,Z+1},.55,su,sv)end
  end
 end end end
 return raw and faces or mergeFaces(faces,budget),{height=12,width=16,depth=depth,voxels=voxels,rawQuads=#faces}
end
-- Call only after normal Structures.forMap analysis and ground votes. Claim
-- the unused native wall tiles now, so neighbouring runs/statues do not change.
function P.build(S,map,atlas,budget)
 if not(S and S.skip and S.ground and S.shapeAt and S.tileAt and S.runs and S.roundStamps and S.objectQuads)then return 0 end
 local found=P.find(map);if #found==0 or not validAtlas(atlas)then return 0 end
 local accepted={};local models={}
 for _,p in ipairs(found)do
  local free=true
  for dy=0,1 do for dx=0,1 do
   local k=key(p.x*2+dx,p.y*2+dy);local sh=S.shapeAt[k];local run=S.runs[k]
   if S.skip[k]or S.ground[k]~=nil or S.tileAt[k]~=p.art[dy*2+dx+1]
    or not(sh and sh.class=='wall'and sh.art=='upright'and not sh.authored)
    or not(run and(run.h==16 or run.h==32 or run.h==48))then free=false end
  end end
  if free then
   local kind=p.half and 'half'or'full'
   if not models[kind]then models[kind]=P.model(atlas,p.half,false,budget)end
   if models[kind]then accepted[#accepted+1]={p=p,q=models[kind]}end
  end
 end
 -- Everything above may yield; commit only complete, validated closed models.
 for _,item in ipairs(accepted)do local p=item.p
  S.roundStamps[#S.roundStamps+1]={quads=item.q,mx=p.x*16+8,my=0,mz=p.y*16+(p.half and 12 or 8),r=8}
  for dy=0,1 do for dx=0,1 do local k=key(p.x*2+dx,p.y*2+dy)
   S.skip[k]=true;S.ground[k]=61
  end end
 end
 return #accepted
end
return P
