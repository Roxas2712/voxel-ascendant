-- Settled snow bridges small native outdoor ledges. The map and its collision
-- tables stay immutable. Only the resident map is retained; no travel history.
local V=...
local R={BUILD=.80,THAW=.65}
local current, coat, retained = nil, false, nil
local dirs={up={0,-1},down={0,1},left={-1,0},right={1,0}}
local function key(x,y,w)return y*w+x end
local function release(s)
 if not s then return end
 if s.mesh and s.mesh.release then s.mesh:release()end
 if s.retainedMesh and s.retainedMesh.release then s.retainedMesh:release()end
end
local function eligible(map)
 return map and map.def and map.def.tileset=='OVERWORLD' and map.def.outdoor~=false
   and map.def.generation~=2 and map.widthCells and map.heightCells
   and map.widthCells*map.heightCells<=65536
end
function R.build(map,data,elevation)
 local s={map=map,elevation=elevation,list={},cells={}}
 if not eligible(map) then return s end
 local w,h=map.widthCells,map.heightCells
 local blocked={}
 for _,group in ipairs{map.def.warps or {},map.def.signs or {},map.def.objects or {}}do
  for _,o in ipairs(group)do if o.x and o.y then blocked[key(o.x,o.y,w)]=true end end
 end
 local function safe(x,y)
  return x>0 and y>0 and x<w-1 and y<h-1 and not blocked[key(x,y,w)]
    and not map:isWaterCell(x,y) and not (map.isDoorCell and map:isDoorCell(x,y))
 end
 local function walk(x,y)return safe(x,y)and map:isWalkableCell(x,y)end
 local tilePairs=data.field and data.field.tilePairs and data.field.tilePairs.land or {}
 local function pairOK(x,y,tx,ty)
  local a,b=map:cellTile(x,y),map:cellTile(tx,ty)
  for _,p in ipairs(tilePairs)do
   if p.tileset==map.def.tileset and ((p.a==a and p.b==b)or(p.a==b and p.b==a))then return false end
  end
  return true
 end
 -- A reverse crossing must not unlock an otherwise separated part of the map.
 -- Label the ordinary walkable components once, including native tile pairs.
 local components,queue={},{}
 local component=0
 for y=1,h-2 do for x=1,w-2 do
  local k=key(x,y,w)
  if not components[k] and walk(x,y)then
   component=component+1;components[k]=component;queue[1]=k;local head,tail=1,1
   while head<=tail do
    local q=queue[head];queue[head]=nil;head=head+1
    local qx,qy=q%w,math.floor(q/w)
    for _,d in pairs(dirs)do
     local nx,ny=qx+d[1],qy+d[2];local nk=key(nx,ny,w)
     if not components[nk]and walk(nx,ny)and pairOK(qx,qy,nx,ny)then
      components[nk]=component;tail=tail+1;queue[tail]=nk
     end
    end
   end
  end
 end end
 for y=1,h-2 do for x=1,w-2 do
  if walk(x,y)then
   for _,ledge in ipairs(data.field and data.field.ledges or {})do
    local d=dirs[ledge.facing]
    if d and ledge.input==ledge.facing and (ledge.tileset or 'OVERWORLD')==map.def.tileset
       and map:cellTile(x,y)==ledge.standingTile then
     local lx,ly=x+d[1],y+d[2];local tx,ty=x+2*d[1],y+2*d[2]
     local k=key(lx,ly,w)
     if safe(lx,ly)and walk(tx,ty)and not map:isWalkableCell(lx,ly)
        and map:cellTile(lx,ly)==ledge.ledgeTile and not s.cells[k]
        and components[key(x,y,w)]==components[key(tx,ty,w)]then
      local high,low=elevation:at(x,y),elevation:at(tx,ty)
      if high>=low and high-low<=6.01 then
       local r={sx=x,sy=y,lx=lx,ly=ly,tx=tx,ty=ty,dx=d[1],dy=d[2],high=high,low=low}
       s.list[#s.list+1]=r;s.cells[k]=r
      end
     end
    end
   end
  end
 end end
 return s
end
local function within(r,x,z)
 local dx,dz=x-(r.lx*16+8),z-(r.ly*16+8)
 return math.abs(dx*r.dy-dz*r.dx)<=8.01 and math.abs(dx*r.dx+dz*r.dy)<=24.01
end
local function active(r)return coat or r==retained end
local function slope(r,t)
 local peak=math.max(r.high,r.low+1)+.35
 if t< -8 then return r.high+.1+(peak-r.high-.1)*(t+24)/16 end
 if t<8 then return peak end
 return peak+(r.low+.1-peak)*(t-8)/16
end
function R.height(map,x,z)
 if not current or current.map~=map or (not coat and not retained)then return end
 local w=map.widthCells;local cx,cy=math.floor(x/16),math.floor(z/16)
 local k=key(cx,cy,w);local answer
 -- Only the cell and its four neighbours can support this foot; this stays
 -- constant-time even on a long route with hundreds of authored ledges.
 for i=1,5 do
  local at=i==1 and k or i==2 and k-1 or i==3 and k+1 or i==4 and k-w or k+w
  local r=current.cells[at]
  if r and active(r)and within(r,x,z)then
   local y=slope(r,(x-(r.lx*16+8))*r.dx+(z-(r.ly*16+8))*r.dy)
   answer=answer and math.max(answer,y)or y
  end
 end
 return answer
end
function R.observe(state,amount)
 local map=state.map
 if current and current.map~=map then release(current);current=nil;coat=false;retained=nil end
 if not eligible(map)then return end
 if not current and amount>=R.BUILD then
  current=R.build(map,require('src.core.Game').data,V.require('LedgeElevation').map(map))
 end
 if not current then return end
 local elevation=V.require('LedgeElevation').map(map)
 if current.elevation~=elevation then release(current);current=R.build(map,require('src.core.Game').data,elevation);retained=nil end
 if amount>=R.BUILD then coat=true elseif amount<R.THAW then coat=false end
 -- Hold the whole bank until the player's body clears it, even if the
 -- weather changes or the coat melts in the middle of a crossing.
 local p=state.player
 if coat then retained=nil
 elseif p then
  local x,z=p.px+8,p.py+8
  if retained and not within(retained,x,z)then retained=nil end
  if not retained then
   local r=current.cells[key(p.cellX,p.cellY,map.widthCells)]
   if r then retained=r end
  end
 end
end
-- nil leaves native collision untouched. Explicit false closes the sides of
-- a snow crossing; true permits only the two safe ends and the lip between.
function R.permission(state,p,x,y)
 if not current or current.map~=state.map or p~=state.player or p.surfing then return end
 local map=state.map;local w=map.widthCells
 local from=current.cells[key(p.cellX,p.cellY,w)]
 local to=current.cells[key(x,y,w)]
 local r=from or to
 if not r or not active(r)then return end
 if (V.require('VoxelState').level or 0)<=0 and not from then return end
 local function endCell(cx,cy)return (cx==r.sx and cy==r.sy)or(cx==r.tx and cy==r.ty)end
 if (from and not endCell(x,y))or(to and not endCell(p.cellX,p.cellY))then return false end
 local Collision=require('src.world.Collision')
 if Collision.occupied(state.entities or {},x,y,p)then return false end
 return true
end
local function meshFor(list)
 local verts={}
 local function vertex(r,t,u)
  return {r.lx*16+8+r.dx*t+r.dy*u,slope(r,t),r.ly*16+8+r.dy*t-r.dx*u,0,0,3}
 end
 for _,r in ipairs(list)do
  local stops={-24,-8,8,24}
  for i=1,3 do
   local a,b,c,d=vertex(r,stops[i],-8),vertex(r,stops[i],8),vertex(r,stops[i+1],8),vertex(r,stops[i+1],-8)
   -- two-sided banks survive either camera bearing, including free look.
   for _,v in ipairs{a,b,c,a,c,d,c,b,a,d,c,a}do verts[#verts+1]=v end
  end
 end
 if #verts>0 then return V.require('Voxel3D').newMesh(verts)end
end
local texture
function R.draw(state)
 if not current or current.map~=state.map or(not coat and not retained)then return end
 local G=V.require('Voxel3D');local mesh
 if coat then current.mesh=current.mesh or meshFor(current.list);mesh=current.mesh
 elseif retained then
  if current.drawRetained~=retained then
   if current.retainedMesh then current.retainedMesh:release()end
   current.retainedMesh=meshFor{retained};current.drawRetained=retained
  end
  mesh=current.retainedMesh
 end
 if not mesh then return end
 if not texture then
  local img=love.image.newImageData(1,1);img:setPixel(0,0,.88,.94,1,1)
  texture=love.graphics.newImage(img);img:release()
 end
 G.draw(mesh,texture)
end
function R.install()
 local C=require('src.world.Collision');local O=require('src.world.OverworldController')
 if O.vascSnowRamps then return end
 local collision,hop=C.canMove,O.checkLedgeHop
 function C.canMove(map,entities,mover,dir)
  local allowed,why=collision(map,entities,mover,dir)
  local state=require('src.core.Game').overworld
  if state and state.map==map and (allowed or why=='tile')then
   local x,y=C.target(mover.cellX,mover.cellY,dir)
   local snow=R.permission(state,mover,x,y)
   if snow==true then return true elseif snow==false then return false,'tile' end
  end
  return allowed,why
 end
 function O:checkLedgeHop(dir)
  local x,y=C.target(self.player.cellX,self.player.cellY,dir)
  if R.permission(self,self.player,x,y)==true then return false end
  return hop(self,dir)
 end
 O.vascSnowRamps=true
end
function R.status()return {count=current and #current.list or 0,active=coat,retained=retained~=nil}end
return R
