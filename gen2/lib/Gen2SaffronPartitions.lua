-- Native Crystal Saffron partition union; guarded late post-analysis owner.
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
  assert(a and b and fixed,'nonaxis wall face')
  local sa=q[2][a]>q[1][a]and 1 or-1;local sb=q[3][b]>q[2][b]and 1 or-1
  local key=table.concat({a,b,sa,sb,q[1][fixed],q.u,q.v,q.shade},':')
  local g=groups[key]
  if not g then
   g={a=a,b=b,fixed=fixed,sa=sa,sb=sb,plane=q[1][fixed],u=q.u,v=q.v,shade=q.shade,cells={},loA=999,hiA=-999,loB=999,hiB=-999}
   groups[key]=g;order[#order+1]=g
  end
  local aa=math.min(q[1][a],q[2][a]);local bb=math.min(q[2][b],q[3][b])
  local right=math.max(q[1][a],q[2][a])-1;local bottom=math.max(q[2][b],q[3][b])-1
  for y=bb,bottom do g.cells[y]=g.cells[y]or{};for x=aa,right do
   if budget and budget.tick then budget.tick()end
   assert(not g.cells[y][x],'duplicate wall surface');g.cells[y][x]=true
  end end
  g.loA,g.hiA=math.min(g.loA,aa),math.max(g.hiA,right)
  g.loB,g.hiB=math.min(g.loB,bb),math.max(g.hiB,bottom)
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

local specs,occupiedCells={},{}
local function add(art,coords)
 for x,y in coords:gmatch("(%d+),(%d+)")do x,y=tonumber(x),tonumber(y);specs[#specs+1]={x=x,y=y,art=art};occupiedCells[y*32+x]=true end
end
add({3,4,19,20},"7,0;7,6;7,12")
add({3,5,12,13},"6,0;13,0;6,6;13,6;6,12;13,12")
add({4,4,20,20},"0,0;1,0;2,0;3,0;4,0;5,0;8,0;9,0;10,0;11,0;14,0;15,0;16,0;17,0;18,0;19,0;0,6;1,6;2,6;3,6;4,6;5,6;8,6;9,6;10,6;11,6;14,6;15,6;16,6;17,6;18,6;19,6;0,12;1,12;2,12;3,12;4,12;5,12;8,12;9,12;10,12;11,12;14,12;15,12;16,12;17,12;18,12;19,12")
add({4,5,20,21},"12,0;12,6;12,12")
add({12,13,12,13},"6,1;13,1;6,2;13,2;6,3;13,3;6,4;13,4;6,5;13,5;6,7;13,7;6,8;13,8;6,9;13,9;6,10;13,10;6,11;13,11;6,13;13,13;6,14;13,14;6,15;13,15;6,16;13,16;6,17;13,17")
table.sort(specs,function(a,b)return a.y==b.y and a.x<b.x or a.y<b.y end)
local signatures={
 [3]="0000000003333333020000000200000002000000020000000200000002222222",
 [4]="0000000033333333000000000000000000000000000000000000000022222222",
 [5]="0000000033333330000000200000002000000020000000200000002022222220",
 [12]="0300000003000000030000000300000003000000030000000300000003000000",
 [13]="0000002000000020000000200000002000000020000000200000002000000020",
 [19]="0000000001111111011111110111111101111111022222220111111100000000",
 [20]="0000000011111111111111111111111111111111222222221111111100000000",
 [21]="0000000011111110111111101111111011111110222222201111111000000000",
 [16]="2222222332222233332223333332333333332333333222333322222332222222",
}
local collisionSignature="070707070707070707070707070707070707070700000000000007000000000000070000000000000000000000000700000000000007000000000000007c0000007c0700007c007c0007007c0000007c0000000000000700000000000007000000000000007c0000007c0700007c007c0007007c0000007c070707070707070707070707070707070707070700000000000007000000000000070000000000000000000000000700000000000007000000000000007c0000007c07000000007c0007007c0000007c0000000000000700000000000007000000000000007c0000007c0700000000000007007c0000007c070707070707070707070707070707070707070700000000000007000000000000070000000000000000000000000700070000000007000000000000007c0000007c07000700007c0007007c0000007c0000000000000700000000000007000000000000007c0000007c0700707000000007007c0000007c"
local warps={
 {8,17,2,"SAFFRON_CITY",25,2},
 {9,17,2,"SAFFRON_CITY",25,2},
 {11,15,18,"SAFFRON_GYM",25,4},
 {19,15,19,"SAFFRON_GYM",25,4},
 {19,11,20,"SAFFRON_GYM",25,4},
 {1,11,21,"SAFFRON_GYM",25,4},
 {5,3,22,"SAFFRON_GYM",25,4},
 {11,5,23,"SAFFRON_GYM",25,4},
 {1,15,24,"SAFFRON_GYM",25,4},
 {19,3,25,"SAFFRON_GYM",25,4},
 {15,17,26,"SAFFRON_GYM",25,4},
 {5,17,27,"SAFFRON_GYM",25,4},
 {5,9,28,"SAFFRON_GYM",25,4},
 {9,3,29,"SAFFRON_GYM",25,4},
 {15,9,30,"SAFFRON_GYM",25,4},
 {15,5,31,"SAFFRON_GYM",25,4},
 {1,5,32,"SAFFRON_GYM",25,4},
 {19,17,3,"SAFFRON_GYM",25,4},
 {19,9,4,"SAFFRON_GYM",25,4},
 {1,9,5,"SAFFRON_GYM",25,4},
 {5,5,6,"SAFFRON_GYM",25,4},
 {11,3,7,"SAFFRON_GYM",25,4},
 {1,17,8,"SAFFRON_GYM",25,4},
 {19,5,9,"SAFFRON_GYM",25,4},
 {15,15,10,"SAFFRON_GYM",25,4},
 {5,15,11,"SAFFRON_GYM",25,4},
 {5,11,12,"SAFFRON_GYM",25,4},
 {9,5,13,"SAFFRON_GYM",25,4},
 {15,11,14,"SAFFRON_GYM",25,4},
 {15,3,15,"SAFFRON_GYM",25,4},
 {1,3,16,"SAFFRON_GYM",25,4},
 {11,9,17,"SAFFRON_GYM",25,4},
}
local function key(x,y)return(y+64)*4096+x+64 end
function P.find(map)
 local d=map and map.def;local ts=map and map.tileset
 if not(d and ts and map.id=='SAFFRON_GYM'and d.id==map.id and d.generation==2
  and d.tileset=='TILESET_UNDERGROUND'and d.width==10 and d.height==9
  and d.environment=='INDOOR'and d.outdoor~=true and next(d.connections or{})==nil
  and ts.tilesPerRow==16 and ts.tilePalettes and#(d.warps or{})==32)then return{}end
 for t in pairs(signatures)do if ts.tilePalettes[t+1]~=(t==16 and 1 or 4)then return{}end end
 for _,f in ipairs((ts.anim or{}).frames or{})do
  if f.func~='WaitTileAnimation'and f.func~='DoneTileAnimation'then return{}end
 end
 for i,w in ipairs(warps)do local actual=d.warps[i]
  if type(actual)~='table'or actual.x~=w[1]or actual.y~=w[2]or actual.destWarp~=w[3]or actual.destMap~=w[4]
   or actual.destGroup~=w[5]or actual.destMapNum~=w[6]then return{}end
 end
 for y=0,17 do for x=0,19 do
  local at=(y*20+x)*2+1
  if map:cellCollision(x,y)~=tonumber(collisionSignature:sub(at,at+1),16)then return{}end
 end end
 local found={}
 for _,p in ipairs(specs)do
  if map:isWarpTileCell(p.x,p.y)then return{}end
  for dy=0,1 do for dx=0,1 do if map:tileAt(p.x*2+dx,p.y*2+dy)~=p.art[dy*2+dx+1]then return{}end end end
  found[#found+1]=p
 end
 return found
end
local function validAtlas(atlas)
 if not(atlas and atlas.getDimensions and atlas.getPixel)then return false end
 local w,h=atlas:getDimensions();if w~=128 or h~=128 then return false end
 for t,s in pairs(signatures)do for y=0,7 do for x=0,7 do
  local r,g,b,a=atlas:getPixel(t%16*8+x,math.floor(t/16)*8+y);local expected=tonumber(s:sub(y*8+x+1,y*8+x+1))/3
  if math.abs(r-expected)>.001 or math.abs(g-expected)>.001 or math.abs(b-expected)>.001 or math.abs(a-1)>.001 then return false end
 end end end
 return true
end
function P.model(atlas,raw,budget)
 if not validAtlas(atlas)then return nil end
 local function tick()if budget and budget.tick then budget.tick()end end
 local function texel(t,x,y)return(t%16*8+x+.5)/128,(math.floor(t/16)*8+y+.5)/128 end
 local aliases={}
 local function pigment(u,v)
  local x,y=math.floor(u*128),math.floor(v*128);local t=math.floor(y/8)*16+math.floor(x/8)
  local color=math.floor(atlas:getPixel(x,y)*3+.5);local k=t*4+color
  if not aliases[k]then aliases[k]={u,v}end;return aliases[k][1],aliases[k][2]
 end
 local faces={}
 local function face(a,b,c,d,shade,u,v)
  tick();u,v=pigment(u,v);faces[#faces+1]={a,b,c,d,shade=shade,u=u,v=v}
 end
 local function neighbour(x,y)return x>=0 and x<20 and y>=0 and y<18 and occupiedCells[y*32+x]end
 local capU,capV=texel(4,3,3)
 for _,p in ipairs(specs)do
  local X,Z=p.x*16,p.y*16
  face({X,16,Z},{X,16,Z+16},{X+16,16,Z+16},{X+16,16,Z},1,capU,capV)
  face({X,0,Z+16},{X,0,Z},{X+16,0,Z},{X+16,0,Z+16},.55,capU,capV)
  for y=0,15 do
   -- Original east-west wall section, kept upright on every visible side.
   -- Native vertical 0c/0d map strips are plan-view edges, not side panels.
   local u,v=texel(y<8 and 20 or 4,3,7-y%8)
   if not neighbour(p.x,p.y+1)then face({X,y,Z+16},{X+16,y,Z+16},{X+16,y+1,Z+16},{X,y+1,Z+16},1,u,v)end
   if not neighbour(p.x,p.y-1)then face({X+16,y,Z},{X,y,Z},{X,y+1,Z},{X+16,y+1,Z},.76,u,v)end
   if not neighbour(p.x-1,p.y)then face({X,y,Z},{X,y,Z+16},{X,y+1,Z+16},{X,y+1,Z},.90,u,v)end
   if not neighbour(p.x+1,p.y)then face({X+16,y,Z+16},{X+16,y,Z},{X+16,y+1,Z},{X+16,y+1,Z+16},.82,u,v)end
  end
 end
 return raw and faces or mergeFaces(faces,budget),{height=16,cells=90,voxels=90*16*16*16,rawQuads=#faces}
end
-- Atomic whole-grid replacement: shared faces are absent, so a partial
-- placement would leave holes. Foreign or already claimed cells reject all.
function P.build(S,map,atlas,budget)
 if not(S and S.skip and S.ground and S.shapeAt and S.tileAt and S.runs and S.objectQuads)then return 0 end
 local found=P.find(map);if#found~=90 or not validAtlas(atlas)then return 0 end
 for _,p in ipairs(found)do for dy=0,1 do for dx=0,1 do
  local k=key(p.x*2+dx,p.y*2+dy);local sh,run=S.shapeAt[k],S.runs[k]
  if S.skip[k]or S.ground[k]~=nil or S.tileAt[k]~=p.art[dy*2+dx+1]
   or not(sh and sh.class=='wall'and sh.art=='upright'and not sh.authored)
   or not(run and(run.h==16 or run.h==32))then return 0 end
 end end end
 local model=P.model(atlas,false,budget);if not model then return 0 end
 -- No yield inside the commit. Keep original object quads and all run data.
 for _,q in ipairs(model)do S.objectQuads[#S.objectQuads+1]=q end
 for _,p in ipairs(found)do for dy=0,1 do for dx=0,1 do local k=key(p.x*2+dx,p.y*2+dy);S.skip[k]=true;S.ground[k]=16 end end end
 return 90
end
return P
