-- Player-centred indoor visibility. It never edits a map or its collision.
local V=...
local M={}
M.setting=V.require('ModSetting').new('currentRoom','ROOM VIEW',{true,false},{'ON','OFF'},true)
local function key(x,y)return(y+64)*4096+x+64 end
local dirs={{1,0},{-1,0},{0,1},{0,-1}}
local cache
local function wholeFootprint(map,profile)
 return (profile and profile.cutawayPlan) or tostring(map.id):match('^CELADON_MANSION_[123]F$')~=nil
end
function M.release()
 if cache then
  if cache.image then cache.image:release()end
  if cache.data then cache.data:release()end
  if cache.mesh then cache.mesh:release()end
 end
 cache=nil
end
function M.enabled(map)
 if M.setting:get()~=true or not map then return false end
 local H=V.require('HorizonWall');if H.isOutdoorMap(map)then return false end
 -- Gym walls already close their authored floor plan. Treating their puzzle
 -- rooms as cave chambers erased every disconnected room down to the sky.
 if type(H.arenaViewFor)=='function' and H.arenaViewFor(map)then return false end
 local c=H.classFor(map)
 return c=='cave'or c=='interior'or c=='room'or c=='tower'
end
function M.plan(map,S,ox,oy,panels)
 local w,h=map.def.width*4,map.def.height*4
 local H=V.require('HorizonWall')
 local profile=type(H.interiorProfileFor)=='function' and H.interiorProfileFor(map)
 -- Authored dungeon partitions already occlude through depth. A second,
 -- player-centred flood mask invents walls in native passages and clips
 -- real wall faces to black from oblique eye-level cameras. Preserve the
 -- native footprint at every camera level; only orbit cutaway lowers walls.
 if wholeFootprint(map,profile) then
  local visible={}
  for y=0,h-1 do for x=0,w-1 do
   local block=map.def.blocks[math.floor(y/4)*map.def.width+math.floor(x/4)+1]
   if block~=nil and block~=map.def.borderBlock then visible[key(x,y)]=true end
  end end
  return {w=w,h=h,ox=ox,oy=oy,visible=visible,blocked={},gates={},map=map,distance={}}
 end
 local blocked,sections={},{}
 for y=0,h-1 do for x=0,w-1 do
  local s=S.shapeAt[key(x,y)]
  if not s or s.class=='void' or (not panels and not (S.skip and S.skip[key(x,y)]) and (s.class=='wall'or s.class=='cliff'))then blocked[key(x,y)]=true end
 end end
 -- Authored room partitions remain barriers even where old wall art was
 -- claimed by a panorama. A doorway opens visually only on approach, so
 -- distant open doors do not reveal another room's puzzle layout.
 for _,p in ipairs(panels or{})do
  local horizontal=p.edge=='north'or p.edge=='south'
  local at=math.floor(p.at/8)
  local inner=(p.edge=='north'or p.edge=='west')and 0 or -1
  for n=math.floor(p.from/8),math.ceil(p.upto/8)-1 do
   local x,y=horizontal and n or at+inner,horizontal and at+inner or n
   local opening=false
   for _,door in ipairs(p.openings or{})do
    if n*8>=door.from and n*8<door.upto and door.open then
     local px,py=(ox+.5)*8,(oy+.5)*8
     local across=horizontal and py or px;local along=horizontal and px or py
     if math.abs(across-p.at)<=20 and along>=door.from-8 and along<=door.upto+8 then opening=true end
    end
   end
   if opening then blocked[key(x,y)]=nil else blocked[key(x,y)]=true end
  end
 end
 -- A paired partition is solid across its thickness. Retain that solid
 -- cross-section for rendering when either room-facing surface is visible.
 -- Door spans are excluded; their approach/lock state stays with the faces.
 for _,p in ipairs(panels or{})do if p.wallThickness then
  local horizontal=p.edge=='north'or p.edge=='south'
  for along=math.floor(p.from/8),math.ceil(p.upto/8)-1 do
   local door=false
   for _,o in ipairs(p.openings or{})do if along*8>=o.from and along*8<o.upto then door=true end end
   if not door then
    local section={}
    for across=math.floor(p.at/8)-1,math.floor((p.at+p.wallThickness)/8)do
     local x,y=horizontal and along or across,horizontal and across or along
     if x>=0 and y>=0 and x<w and y<h then
      local k=key(x,y);blocked[k]=true;section[#section+1]=k
     end
    end
    sections[#sections+1]=section
   end
  end
 end end
 -- Keep the player's own 16px collision cell intact during interpolated
 -- walking and sprite sway; half of a cell can carry decorative wall art.
 local cx,cy=math.floor(ox/2)*2,math.floor(oy/2)*2
 for y=cy,cy+1 do for x=cx,cx+1 do blocked[key(x,y)]=nil end end
 -- Narrow passages delimit chambers. Keep a one-cell approach around
 -- the player open, then reveal the adjoining room when crossing it.
 -- Flood the entire chamber, rather than a jagged line-of-sight cone that
 -- would cut the middle out of a room or flicker behind its own furniture.
 local gates,necks={},{}
 local function solid(x,y)return x<0 or y<0 or x>=w or y>=h or blocked[key(x,y)]end
 local function rim(x,y,dx,dy)
  for i=1,5 do if solid(x+dx*i,y+dy*i)then return i end end
 end
 if panels then
 for y=0,h-1 do for x=0,w-1 do
  if not solid(x,y)then
   local l,r=rim(x,y,-1,0),rim(x,y,1,0)
   local n,b=rim(x,y,0,-1),rim(x,y,0,1)
   local vertical=l and r and l+r<=6 and not solid(x,y-1)and not solid(x,y+1)
   local horizontal=n and b and n+b<=6 and not solid(x-1,y)and not solid(x+1,y)
   if vertical or horizontal then necks[key(x,y)]=(vertical and 1 or 0)+(horizontal and 2 or 0)end
  end
 end end
 -- Gate only the ends/turns of a passage, never every cell along it.
 -- A player in a long corridor sees that whole corridor section.
 for y=0,h-1 do for x=0,w-1 do
  local n=necks[key(x,y)]
  if panels and n and math.abs(x-ox)+math.abs(y-oy)>2 then
   for _,d in ipairs(dirs)do
    local along=n==3 or(n==1 and d[2]~=0)or(n==2 and d[1]~=0)
    local nx,ny=x+d[1],y+d[2]
    if along and not solid(nx,ny)and necks[key(nx,ny)]~=n then gates[key(x,y)]=true end
   end
  end
 end end
 end -- authored interiors only; caves have no synthetic passage gates
 for k in pairs(gates)do blocked[k]=true end
 -- Cave visibility follows reachable ground, bounded by distance. Passage
 -- mouths are not walls: no artificial gates or raised curtains in caves.
 local maxReach=not panels and 24 or nil -- 12 collision cells / 192px
 local distance={[key(ox,oy)]=0}
 local visible,queue={},{{ox,oy}};visible[key(ox,oy)]=true
 local i=1
 while i<=#queue do
  local p=queue[i];i=i+1
  for _,d in ipairs(dirs)do
   local x,y=p[1]+d[1],p[2]+d[2];local k=key(x,y)
   local nextDistance=distance[key(p[1],p[2])]+1
   if x>=0 and y>=0 and x<w and y<h and not visible[k]
     and (not maxReach or nextDistance<=maxReach)then
    visible[k]=true;distance[k]=nextDistance
    if not blocked[k]then queue[#queue+1]={x,y}end
   end
  end
 end
 -- Cardinal flooding reaches both wall faces but not their shared corner.
 -- Complete only solid corners touching this chamber; never queue these
 -- cells or reveal a diagonal floor cell (which may belong to another room).
 for _,p in ipairs(queue)do
  for _,dx in ipairs({-1,1})do for _,dy in ipairs({-1,1})do
   local x,y=p[1]+dx,p[2]+dy;local k=key(x,y)
   if x>=0 and y>=0 and x<w and y<h and blocked[k]and not gates[k]
     and blocked[key(x,p[2])]and blocked[key(p[1],y)]then visible[k]=true end
  end end
 end
 local solidVisible={}
 for _,section in ipairs(sections)do
  local seen=false;for _,k in ipairs(section)do if visible[k]then seen=true;break end end
  if seen then for _,k in ipairs(section)do if blocked[k]and not gates[k]then solidVisible[k]=true end end end
 end
 -- Apply once after collecting; one exposed end must not reveal an entire
 -- connected wall network or flood into a neighbouring room.
 for k in pairs(solidVisible)do visible[k]=true end
 return {w=w,h=h,ox=ox,oy=oy,visible=visible,blocked=blocked,gates=gates,map=map,reach=maxReach,distance=distance}
end
function M.visible(view,x,z)
 return not view or view.visible[key(math.floor(x/8),math.floor(z/8))]==true
end
function M.prepare(state)
 local map=state and state.map;local player=state and state.player
 if not player or not M.enabled(map)then M.release();return nil end
 local ox,oy=math.floor(((player.px or player.cellX*16)+8)/8),math.floor(((player.py or player.cellY*16)+8)/8)
 local S=V.require('Structures').forMap(map)
 local H=V.require('HorizonWall');local profile=H.interiorProfileFor(map)
 local cutaway=profile and profile.cutawayPlan and V.require('InteriorCutaway').active(map) or false
 local complete=wholeFootprint(map,profile)
 -- A complete native dungeon footprint is independent of the player's cell.
 -- Preserve its mask and boundary mesh while walking; native geometry changes
 -- still invalidate S, and ordinary room/cave masks still follow the player.
 if cache and cache.map==map and cache.S==S and cache.complete==complete
   and (complete or (cache.ox==ox and cache.oy==oy))
   and cache.cutaway==cutaway then return cache end
 -- Reuse the mask texture while walking: uploading into the same tiny
 -- image avoids GPU allocation/deletion on every half-cell crossing.
 local reuse=cache and cache.map==map and cache.w==map.def.width*4
   and cache.h==map.def.height*4 and cache.image
   and type(cache.image.replacePixels)=='function' and cache or nil
 if reuse then
  if reuse.mesh then reuse.mesh:release();reuse.mesh=nil end
  cache=nil
 else M.release()end
 local panels=profile and V.require('Gen1InteriorLayout').panelsFor(map,profile)or nil
 local view=M.plan(map,S,ox,oy,panels);view.S=S;view.cutaway=cutaway;view.complete=complete
 local g=love.graphics
 if view.w>g.getSystemLimits().texturesize or view.h>g.getSystemLimits().texturesize then return nil,'room-mask-too-large' end
 local data=reuse and reuse.data or love.image.newImageData(view.w,view.h)
 data:mapPixel(function(x,y)
  local k=key(x,y);local n=view.visible[k]and 1 or 0
  -- Red stays binary; green stores path distance for smooth battle fog.
  -- Solid corner/hidden neighbours inherit a nearby distance only for
  -- filtering: they never gain visibility or become flood-fill seeds.
  local dist=view.distance[k]
  if view.reach and not dist then
   dist=view.reach
   for dy=-1,1 do for dx=-1,1 do
    local nearby=view.distance[key(x+dx,y+dy)]
    if nearby then dist=math.min(dist,nearby+math.abs(dx)+math.abs(dy))end
   end end
  end
  return n,view.reach and math.min(1,dist/view.reach)or 0,0,1
 end)
 local ok,img
 if reuse then
  ok,img=pcall(reuse.image.replacePixels,reuse.image,data)
  if ok then img=reuse.image else reuse.image:release()end
 else ok,img=pcall(g.newImage,data,{mipmaps=false,linear=false})end
 if not ok then data:release();return nil,tostring(img)end
 img:setFilter('linear','linear');img:setWrap('clamp','clamp');view.image=img;view.data=data
 local verts,indices={},{};local v3=V.require('Voxel3D')
 local function quad(c,u0,u1)
  local uv={{u0,1},{u1,1},{u1,0},{u0,0}}
  local n=#verts/4
  for i,p in ipairs(c)do verts[#verts+1]={p[1],p[2],p[3],uv[i][1],uv[i][2],.88}end
  v3.pushQuad(indices,n)
 end
 -- Raised room-facing curtains follow the actual rock/partition contour.
 -- They sit slightly on the visible side, so the same visibility mask never
 -- clips them at a cell boundary. Material is borrowed from the room shell.
 for y=0,view.h-1 do for x=0,view.w-1 do
  if profile and view.visible[key(x,y)]then
   for _,d in ipairs(dirs)do
    local nx,ny=x+d[1],y+d[2]
    local nk=key(nx,ny)
    -- The mask includes a solid boundary cell. Close its far edge toward
    -- concealed cells, including the short returns where a gate meets a
    -- partition. Closing only the free-cell side leaves vertical slits.
    local close=profile and nx>=0 and ny>=0 and nx<view.w and ny<view.h
      and not view.visible[nk]
      or not profile and view.blocked[nk]
    if close then
     local x0,z0,x1,z1
     -- Authored finish/art sit .02/.04px into the room. Keep the closure
     -- behind both, so a coincident curtain never covers the wall motif.
     local inset=profile and .01 or .08
     if d[1]~=0 then x0=(x+(d[1]>0 and 1 or 0))*8-d[1]*inset;x1=x0;z0=y*8;z1=z0+8
     else z0=(y+(d[2]>0 and 1 or 0))*8-d[2]*inset;z1=z0;x0=x*8;x1=x0+8 end
     local base=V.require('ChunkMesher').elevation(map):atTile(x,y)
     local top=base+(profile and profile.shellHeight or 64)
     local period=profile and 128 or 384
     local u0=((x0+z0)%period)/period;local u1=u0+8/period
     quad({{x0,base,z0},{x1,base,z1},{x1,top,z1},{x0,top,z0}},u0,u1)
    end
   end
  end
 end end
 if #verts>0 then view.mesh=v3.newMesh(verts,indices)end
 cache=view;return view
end
function M.texture(view,horizon)
 if not view then return nil end
 for _,rim in ipairs(horizon or{})do
  if rim.kind=='wall'and rim.texture and rim.class~='room_door'and rim.class~='room_security_door'then return rim.texture end
 end
 return nil
end
return M
