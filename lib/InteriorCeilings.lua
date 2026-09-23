-- Small authored ceiling assemblies. One static batch follows the existing
-- whole-roof cutaway; the same layout supplies bounded room-light sources.
local V=...
local M={}
M.palette={{.78,.80,.79},{.32,.38,.41},{.63,.78,.87},{.92,.96,1},
 {.19,.14,.21},{1,.73,.42},{.48,.38,.23},{.94,.93,.86}}
-- Shared geometry, distinct material/fixture families. Even large floors
-- retain a fixed source budget; LocalLights selects nearby lamps per frame.
local styles={
 ship={surface=8,fixture='lantern',warm=true,beams=true},
 home={surface=8,fixture='pendant',warm=true},
 traditional_home={surface=7,fixture='lantern',warm=true,beams=true},
 coastal_home={surface=8,fixture='lantern',warm=true,beams=true},
 daycare={surface=8,fixture='shade',warm=true},
 hotel={surface=8,fixture='shade',warm=true},
 diner={surface=8,fixture='pendant',warm=true},
 casino={surface=5,fixture='pendant',warm=true},
 museum={surface=8,fixture='spot',warm=true},
 lab={surface=1,fixture='panel'},mart={surface=8,fixture='panel'},
 center={surface=8,fixture='panel'},corporate={surface=1,fixture='panel'},
 workshop={surface=1,fixture='strip',beams=true},
 rocket={surface=2,fixture='strip',beams=true},
 power_plant={surface=2,fixture='strip',beams=true},
 ruined_mansion={surface=7,fixture='lantern',warm=true,beams=true},
 gate={surface=8,fixture='strip'},elevator={surface=1,fixture='panel'},
 underground={surface=2,fixture='strip',beams=true},
 ice_hall={surface=3,fixture='panel'},stone_hall={surface=2,fixture='lantern',warm=true,beams=true},
 spirit_hall={surface=5,fixture='lantern',warm=true,beams=true},
 dragon_hall={surface=7,fixture='lantern',warm=true,beams=true},
 champion_hall={surface=8,fixture='pendant',warm=true},
}
M.styles=styles
function M.layout(map,profile)
 if not (profile and profile.ceiling and profile.ceiling.enabled and profile.ceiling.authored)then return nil end
 local w,d,h=map.def.width*32,map.def.height*32,profile.shellHeight
 local style=styles[profile.ceiling.style or profile.theme] or styles.home
 local out={w=w,d=d,h=h,theme=profile.theme,style=style,lamps={}}
 if map.id=='OAKS_LAB' then
  local half=w*22/96;local depth=half/2.2
  out.skylight={w/2-half,w/2+half,d/2-depth,d/2+depth}
 end
 local nx=math.min(4,math.max(1,math.ceil(w/110)))
 local nz=math.min(4,math.max(1,math.ceil(d/110)))
 -- Eight static fixtures maximum, independent of total map area.
 while nx*nz>8 do if nx>=nz then nx=nx-1 else nz=nz-1 end end
 for row=1,nz do for col=1,nx do
  local x,z=w*(col-.5)/nx,d*(row-.5)/nz
  local s=out.skylight
  if s and x>s[1]-12 and x<s[2]+12 and z>s[3]-6 and z<s[4]+6 then
   z=row<=(nz+1)/2 and s[3]-12 or s[4]+12
  end
  local hanging=style.fixture=='pendant' or style.fixture=='lantern' or style.fixture=='shade'
  out.lamps[#out.lamps+1]={position={x,h-(hanging and 7 or 2),z},
   normal={0,-1,0},radius=style.warm and 92 or 110,power=style.warm and .95 or 1.1,
   color=style.warm and {1,.76,.48}or {.78,.88,1},kind='ceiling',constant=true}
 end end
 return out
end
-- A free battle orbit can leave the room. Remove the complete assembly at
-- that point instead of exposing its exterior roof or clipping the playfield.
function M.visibleFrom(map,profile,eye)
 return profile and profile.ceiling and profile.ceiling.enabled and profile.ceiling.authored
  and eye and eye[2]<profile.shellHeight-1 and eye[1]>0 and eye[3]>0
  and eye[1]<map.def.width*32 and eye[3]<map.def.height*32 or false
end
function M.geometry(map,profile,checkpoint)
 local plan=M.layout(map,profile);if not plan then return end
 local G=V.require('Voxel3D');local verts,indices={},{}
 local function box(x,y,z,w,h,d,color)
  if w<=0 or h<=0 or d<=0 then return end
  for face,corners in ipairs(G.FACE_CORNERS)do
   G.pushQuad(indices,#verts/4)
   for _,p in ipairs(corners)do
    verts[#verts+1]={x+p[1]*w,y+p[2]*h,z+p[3]*d,(color-.5)/8,.5,
     face==4 and .95 or (G.FACE_SHADE[face]or 1)}
   end
  end
  if checkpoint then checkpoint()end
 end
 local w,d,h,s=plan.w,plan.d,plan.h,plan.skylight
 local color=plan.style.surface
 if s then
  box(0,h,0,w,2,s[3],color);box(0,h,s[4],w,2,d-s[4],color)
  box(0,h,s[3],s[1],2,s[4]-s[3],color)
  box(s[2],h,s[3],w-s[2],2,s[4]-s[3],color)
  -- Glass meets the ceiling directly. Only internal mullions remain.
  box(s[1],h,s[3],s[2]-s[1],.5,s[4]-s[3],3)
  box(w/2-.4,h-.15,s[3],.8,.3,s[4]-s[3],2)
  box(s[1],h-.15,d/2-.4,s[2]-s[1],.3,.8,2)
 else box(0,h,0,w,2,d,color)end
 -- Narrow structural rails make the large commercial ceiling read at room scale.
 for _,z in ipairs(plan.style.beams and {.16,.50,.88}or {})do
  if not s or z*d<s[3]or z*d>s[4]then box(0,h-.7,z*d,w,.7,1.2,2)end
 end
 for _,l in ipairs(plan.lamps)do
  local x,y,z=unpack(l.position)
  if plan.style.fixture=='pendant' or plan.style.fixture=='lantern' or plan.style.fixture=='shade'then
   box(x-.4,y+1,z-.4,.8,h-y,.8,7)
   local lantern=plan.style.fixture=='lantern'
   box(x-4,y,z-4,8,lantern and 4 or 1.5,8,lantern and 6 or 7)
   box(x-3,y-.3,z-3,6,.3,6,6)
   if lantern then
    for _,dx in ipairs({-4,3})do for _,dz in ipairs({-4,3})do box(x+dx,y,z+dz,1,4,1,7)end end
   end
  elseif plan.style.fixture=='spot'then
   box(x-4,y,z-3,8,2,6,2);box(x-2,y-.3,z-2,4,.3,4,6)
  else
   box(x-9,y,z-3,18,2,6,2);box(x-8,y-.25,z-2,16,.25,4,4)
  end
 end
 return verts,indices,#indices/6
end
return M
