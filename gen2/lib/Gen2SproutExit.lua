-- One visible south doorway for the native paired exit. Decorative shell
-- only: no changes to tile, collision, event or warp ownership.
local P={}
function P.spec(map)
 local d=map and map.def
 if not(d and map.id=='SPROUT_TOWER_1F' and d.id==map.id and d.generation==2
  and d.width==10 and d.height==8 and d.tileset=='TILESET_TOWER'
  and d.environment=='DUNGEON' and d.outdoor~=true and not next(d.connections or{})
  and type(map.cellCollision)=='function' and type(map.tileAt)=='function')then return nil end
 local found={}
 for _,w in ipairs(d.warps or{})do
  if w.y==15 then
   if (w.x~=9 and w.x~=10)or w.destMap~='VIOLET_CITY' or w.destWarp~=7
    or found[w.x]then return nil end
   found[w.x]=true
  end
 end
 if not(found[9]and found[10])then return nil end
 for x=9,10 do
  if map:cellCollision(x,15)~=112 then return nil end
  local tiles=x==9 and{7,8,23,24}or{8,9,24,25}
  for i,p in ipairs({{0,0},{1,0},{0,1},{1,1}})do
   if map:tileAt(x*2+p[1],30+p[2])~=tiles[i]then return nil end
  end
 end
 return {left=144,right=176,head=64,z=288,depth=4,city='VIOLET_CITY'}
end
local function quad(out,points,uv,shade)
 local n=#out.vertices
 for i,p in ipairs(points)do out.vertices[n+i]={p[1],p[2],p[3],uv[i][1],uv[i][2],shade}end
 for _,i in ipairs({1,2,3,1,3,4})do out.indices[#out.indices+1]=n+i end
end
function P.panel(s,corners,uv,edge,shade)
 if not(s and edge==1 and corners[1][3]==s.z and corners[2][3]==s.z
  and corners[1][2]==0 and corners[3][2]>s.head)then return nil end
 local x0,x1=corners[1][1],corners[2][1]
 local a,b=math.max(x0,s.left),math.min(x1,s.right)
 if b<=a then return nil end
 local out={vertices={},indices={}}
 local function point(x,y)
  local u,t=(x-x0)/(x1-x0),y/corners[3][2]
  local tex={}
  for k=1,2 do
   local bot=uv[1][k]+u*(uv[2][k]-uv[1][k])
   local top=uv[4][k]+u*(uv[3][k]-uv[4][k])
   tex[k]=bot+t*(top-bot)
  end
  return {x,y,s.z},tex
 end
 local function rect(l,r,bot,top)
  if r<=l or top<=bot then return end
  local pts,tex={},{}
  for _,xy in ipairs({{l,bot},{r,bot},{r,top},{l,top}})do
   local p,u=point(xy[1],xy[2]);pts[#pts+1]=p;tex[#tex+1]=u
  end
  quad(out,pts,tex,shade)
 end
 rect(x0,a,0,corners[3][2]);rect(b,x1,0,corners[3][2]);rect(a,b,s.head,corners[3][2])
 local function reveal(x,y,xx,yy)
  quad(out,{{x,y,s.z},{xx,yy,s.z},{xx,yy,s.z+s.depth},{x,y,s.z+s.depth}},
   {{0,.05},{.125,.05},{.125,.075},{0,.075}},shade*.85)
 end
 -- The panel seam at x160 is NOT a jamb. Exactly two vertical reveals,
 -- with a continuous two-part lintel and no raised threshold.
 if a==s.left then reveal(a,0,a,s.head)end
 if b==s.right then reveal(b,s.head,b,0)end
 reveal(a,s.head,b,s.head)
 return out
end
function P.exterior(s)
 if not s then return nil end
 local out={vertices={},indices={},family='johto_view_town'}
 -- Shared regional town art, not a claim to reconstruct Violet's streets.
 -- Its transparent skyline exposes the real sky; no second wall in the door.
 local z=s.z+96
 quad(out,{{32,-28,z},{288,-28,z},{288,100,z},{32,100,z}},
  {{0,1},{1,1},{1,0},{0,0}},1)
 quad(out,{{32,0,s.z},{32,0,z},{288,0,z},{288,0,s.z}},
  {{.5,.99},{.5,.99},{.5,.99},{.5,.99}},1)
 return out
end
return P
