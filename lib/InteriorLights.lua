-- Light sources follow the same room panels and artwork placement as the
-- renderer. No room geometry, tile IDs, collision, warps or saves are edited.
local V=...
local M={}
local cache=setmetatable({},{__mode='k'})
-- Apertures measured in the original panorama's UV space. West artwork is
-- reversed by Gen1InteriorFinish; derive its world position with that rule.
M.apertures={
 home={{.195,.307,.17,.55},{.689,.809,.17,.55}},
 coastal_home={{.247,.357,.17,.53},{.675,.784,.17,.53}},
 traditional_home={{.003,.103,.16,.63},{.264,.483,.16,.63},{.892,.997,.16,.63}},
 center={{.131,.350,.09,.22},{.408,.598,.09,.22},{.650,.861,.09,.22}},
}
local cool={lab=true,center=true,corporate=true,museum=true,workshop=true,power_plant=true,elevator=true}
local underground={rocket=true,underground=true}
-- Public interiors must remain readable without exterior sunlight. Keep
-- their palette, but do not multiply already dark artwork by home-night tint.
local roomAmbient={lab={.72,.76,.80},mart={.78,.76,.72},
 casino={.64,.59,.66},rocket={.64,.67,.71}}
local function horizontal(p)return p.edge=='north' or p.edge=='south'end
local function point(p,along,y,inset)
 local sign=(p.edge=='north' or p.edge=='west')and 1 or -1
 return horizontal(p)and {along,y,p.at+sign*inset}or {p.at+sign*inset,y,along}
end
local function normal(p)
 return p.edge=='north'and {0,0,1}or p.edge=='south'and {0,0,-1}
   or p.edge=='west'and {1,0,0}or {-1,0,0}
end
local function block(out,p,from,upto,bottom,top)
 if upto<=from or top<=bottom then return end
 local a,b=point(p,from,bottom,-.15),point(p,upto,top,.15)
 out[#out+1]={lo={math.min(a[1],b[1]),bottom,math.min(a[3],b[3])},
  hi={math.max(a[1],b[1]),top,math.max(a[3],b[3])}}
end
function M.layout(map)
 local H=V.require('HorizonWall')
 if H.enabled and not H.enabled() then return nil end
 local profile=H.interiorProfileFor(map)
 if not profile or not profile.nativeRoomPanels then return nil end
 local signature=table.concat(map.def.blocks or {},',')..':'..tostring(profile.shellHeight)..':'..tostring(profile.theme)
   ..':'..tostring(profile.ceiling and profile.ceiling.enabled)..':'..tostring(profile.ceiling and profile.ceiling.authored)
 local old=cache[map];if old and old.signature==signature then return old end
 local panels=V.require('Gen1InteriorLayout').panelsFor(map,profile)
 local out={signature=signature,profile=profile,panels=panels,portals={},lamps={},blockers={}}
 local height=profile.shellHeight
 local F=V.require('Gen1InteriorFinish');local placements,feature={},{}
 for _,p in ipairs(panels)do
  local placement=F.placement(p,profile.theme,height);placements[p]=placement
  if placement and (not feature[p.edge]or placement.width>placements[feature[p.edge]].width)then feature[p.edge]=p end
  -- Preserve native doors. A closed door remains a solid light blocker.
  local doors={};for _,d in ipairs(p.openings or{})do doors[#doors+1]=d end
  table.sort(doors,function(a,b)return a.from<b.from end)
  local cursor=p.from
  for _,d in ipairs(doors)do
   block(out.blockers,p,cursor,d.from,0,height)
   block(out.blockers,p,d.from,d.upto,d.open and (d.height or 24)or 0,height)
   cursor=d.upto
  end
  block(out.blockers,p,cursor,p.upto,0,height)
 end
 for _,edge in ipairs({'north','west','east'})do
  local p=feature[edge]
  if p then
  local placement=placements[p]
  local function along(u)
   local f=(u-placement.sourceFrom)/(placement.sourceTo-placement.sourceFrom)
   if edge=='west'then f=1-f end
   return placement.left+f*placement.width
  end
  if not underground[profile.theme] and not tostring(map.id):match('_B%dF$')then
   for _,a in ipairs(M.apertures[profile.theme]or{})do
    if a[1]>=placement.sourceFrom and a[2]<=placement.sourceTo then
     local x,z=along(a[1]),along(a[2]);local first,last=math.min(x,z),math.max(x,z)
     out.portals[#out.portals+1]={position=point(p,(first+last)/2,height*(1-(a[3]+a[4])/2),.35),
      normal=normal(p),rect={first,last,height*(1-a[4]),height*(1-a[3])},axis=horizontal(p)and 3 or 1}
    end
   end
  end
 end end
 -- Keep new sconces on undecorated strips beside the whole artwork. Unlike
 -- ceiling lights they remain attached to the room at every camera height.
 for _,p in ipairs(panels)do
  local placement=placements[p]
  if not p.endcap and p.upto-p.from>=64 and (horizontal(p) or map.def.width>7 or map.def.height>7) then
   local candidates={p.from+9,p.upto-9}
   for _,a in ipairs(candidates)do
    local free=true
    if feature[p.edge]==p and placement and a>placement.left-5 and a<placement.right+5 then free=false end
    for _,d in ipairs(p.openings or{})do if a>d.from-5 and a<d.upto+5 then free=false end end
    if free then
     local color=cool[profile.theme]and {.66,.84,1}or profile.theme=='casino'and {1,.35,.64}or {1,.68,.32}
     out.lamps[#out.lamps+1]={position=point(p,a,height*.76,2),normal=normal(p),
      radius=92,power=cool[profile.theme]and 1.35 or 1.25,color=color,panel=p,kind='sconce',
      constant=underground[profile.theme]or profile.theme=='casino'or profile.theme=='mart'}
    end
   end
  end
 end
 local ceiling=profile.ceiling and profile.ceiling.authored
   and V.require('InteriorCeilings').layout(map,profile)
 if ceiling then
  for _,l in ipairs(ceiling.lamps)do out.lamps[#out.lamps+1]=l end
  local s=ceiling.skylight
  if s then
   -- Keep the central opening within the two-portal mobile budget too.
   table.insert(out.portals,1,{position={(s[1]+s[2])/2,ceiling.h,(s[3]+s[4])/2},
    normal={0,-1,0},rect={s[1],s[2],s[3],s[4]},axis=2})
  end
 end
 cache[map]=out;return out
end
function M.prepare(map)
 local out=M.layout(map);if not out then return nil end
 local D=V.require('DayNight');local night=D.windowLight()
 local cold=cool[out.profile.theme]
 local tint=roomAmbient[out.profile.theme] or cold and {.56,.60,.65}or {.58-night*.17,.56-night*.14,.53+night*.015}
 return out,tint
end
local mesh,tex,current
function M.draw(layout,lights,eye,focus,map)
 if not layout then return end
 local G=V.require('Voxel3D');local Cut=V.require('InteriorCutaway')
 local visible={}
 for _,l in ipairs(lights)do if l.fixture and l.fixture.kind~='ceiling' then
  local p=l.fixture.panel
  if Cut.rimVisible({kind='wall',interiorPanel=p},Cut.active(map),eye,focus)then visible[#visible+1]=l end
 end end
 -- At most eight tiny boxes, rebuilt only when the selected fixture set
 -- changes. Bright faces use their authored color; the metal mount is dark.
 local key='';for _,l in ipairs(visible)do key=key..tostring(l.fixture)..';'end
 if key~=current then
  if mesh then mesh:release();mesh=nil end
  local vertices,indices={},{}
  local function box(x,y,z,w,h,d,u)
   for face,corners in ipairs(G.FACE_CORNERS)do
    G.pushQuad(indices,#vertices/4)
    for _,p in ipairs(corners)do vertices[#vertices+1]={x+p[1]*w,y+p[2]*h,z+p[3]*d,u,.5,1}end
   end
  end
  for _,l in ipairs(visible)do
   local n=l.normal;local x,y,z=l.x,l.y,l.z
   box(x-2,y-3.4,z-2,4,6.8,4,.125)
   box(x-1.45+n[1]*.8,y-2.5,z-1.45+n[3]*.8,2.9,5,2.9,l.color[3]>.8 and .875 or l.color[2]<.5 and .625 or .375)
  end
  if #vertices>0 then
   mesh=love.graphics.newMesh({{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'VertexShade','float',1}},vertices,'triangles','static');mesh:setVertexMap(indices)
  end
  current=key
 end
 if not mesh then return end
 if not tex then
  local d=love.image.newImageData(4,1)
  for i,c in ipairs({{.16,.13,.10},{1,.78,.42},{1,.38,.65},{.75,.91,1}})do d:setPixel(i-1,0,c[1],c[2],c[3],1)end
  tex=love.graphics.newImage(d);d:release();tex:setFilter('nearest','nearest')
 end
 G.draw(mesh,tex,nil,0)
end
return M
