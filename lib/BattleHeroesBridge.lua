-- Optional presentation-only extension for both trainer actors.
local V=...
local B={}
function B.attach(textures,battle)
 if not V.mod or not V.mod.find then return end
 local ok,hero=pcall(function()
  local mod=V.mod:find('ascendant_battle_heroes')
  local api=mod and mod.exports or V.mod.exports.battleHeroes
  if api and api.schema=='ascendant.battle-heroes/v1' then
   return {player=api.presentation(battle),enemy=api.enemyPresentation and api.enemyPresentation(battle)}
  end
 end)
 if ok and hero then
  local apo=V.mod.exports and V.mod.exports.overworldPokemon
  if apo and apo.walkingSprites and apo.walkingSprites.enabled()==false then
   local native=V.require('NativeBattlePeople')
   hero.player=native.adapt(battle,'player',hero.player)
   hero.enemy=native.adapt(battle,'enemy',hero.enemy)
  end
  local plan=V.require('OverworldBattle').presentationPlan(battle)
  if plan and plan.terarrium then
   local service=V.require('TerarriumHost').service
   if service and service.activity then service.activity(battle)end
   local behind=plan.terarriumCamera=='behind'
   if hero.player and hero.player.setView then hero.player=hero.player.setView(behind and 'terarrium-back' or 'side','player')end
   if hero.enemy and hero.enemy.setView then hero.enemy=hero.enemy.setView(behind and 'terarrium-front' or 'side','enemy')end
  end
  textures.battleHeroes=hero
  if hero.player and hero.player.intro then textures.player=nil end
  if hero.enemy and hero.enemy.intro then textures.enemy=nil end
 end
end
-- Search around the existing Pokemon foot, keeping the closest readable
-- trainer seat. Only MAP uses collision geometry; portable stages retain
-- their authored positions. This never moves an entity or changes a tile.
function B.chooseFoot(p,desired,scale,accept,cached,preferred,ground)
 -- Sample support before projection, including the introduction and a cached
 -- seat. A trainer may occupy a different shelf from its Pokemon.
 local function supported(q)
  if not ground then return q end
  return {q[1],ground(q[1],q[3]),q[3]}
 end
 desired=supported(desired)
 if cached then cached=supported(cached)end
 if cached and accept(cached) then return cached,true end
 local dx,dz=desired[1]-p[1],desired[3]-p[3]
 local angle=math.atan2(dz,dx)
 local function search(filter)
  if accept(desired) and (not filter or filter(desired)) then return desired end
  for _,radius in ipairs({13,18,24,32})do
   for _,step in ipairs({0,1,-1,2,-2,3,-3,4,-4,5,-5,6,-6,7,-7,8})do
    local a=angle+step*math.pi/8
    local candidate=supported({p[1]+math.cos(a)*radius*scale,p[2],p[3]+math.sin(a)*radius*scale})
    if (not filter or filter(candidate)) and accept(candidate) then return candidate end
   end
  end
 end
 local foot=preferred and search(preferred) or nil
 foot=foot or search()
 return foot or desired,foot~=nil
end
-- Keep the trainer on their own Pokemon's side of the battle line, rather
-- than merely on their half of the room (which allowed standing at midfield).
function B.onTeamSide(p,other,point,scale,sideFlank)
 local dx,dz=other[1]-p[1],other[3]-p[3]
 local distance=math.sqrt(dx*dx+dz*dz)
 local advance=sideFlank and 0 or -4*scale
 return distance>.001 and (point[1]-p[1])*dx+(point[3]-p[3])*dz<=advance*distance
end
-- Use the battle axis for the rear offset. Camera-right can point toward
-- the opponent, so adding that vector could cancel the entire rear offset.
function B.rearFoot(p,other,eye,scale,side)
 local dx,dz=p[1]-other[1],p[3]-other[3]
 local d=math.sqrt(dx*dx+dz*dz)
 if d<.001 then return {p[1],p[2],p[3]} end
 dx,dz=dx/d,dz/d
 local sx,sz=-dz,dx
 local cameraSide=(eye[1]-p[1])*sx+(eye[3]-p[3])*sz
 local sign=math.abs(cameraSide)>.001 and (cameraSide>0 and 1 or -1)
  or (side=='player' and 1 or -1)
 return {p[1]+(dx*12+sx*10*sign)*scale,p[2],p[3]+(dz*12+sz*10*sign)*scale}
end
function B.inForeground(p,eye,point,scale)
 local dx,dz=eye[1]-p[1],eye[3]-p[3]
 local distance=math.sqrt(dx*dx+dz*dz)
 return distance>.001 and ((point[1]-p[1])*dx+(point[3]-p[3])*dz)/distance>=4*scale
end
-- A foreground trainer may overlap the lower part of their own large mon.
-- Its upper silhouette must remain visible; the opponent is never relaxed.
function B.foregroundOverlap(left,right,l,r,trainerTop,upperBody,foreground)
 return foreground and trainerTop and upperBody and trainerTop>upperBody
  and math.max(0,math.min(right,r)-math.max(left,l))<(r-l)*.45
end
-- Both bounds use the same normalized screen coordinates (0..2 in Y).
-- Missing height metrics keep the conservative horizontal-only check.
function B.screenOverlap(left,right,top,bottom,l,r,t,b)
 if right<l or left>r then return false end
 if top and bottom and t and b and (bottom<t or top>b)then return false end
 return true
end
-- Tile collision can understate an authored statue or replacement shelf.
-- Cache a conservative height field from the same geometry the MAP draws.
local fields=setmetatable({},{__mode='k'})
function B.geometryField(structures,furniture,models)
 local heights={}
 local function stamp(x0,z0,x1,z1,h)
  if h<=1 then return end
  for z=math.floor(z0/4),math.floor(z1/4) do
   local row=heights[z] or {};heights[z]=row
   for x=math.floor(x0/4),math.floor(x1/4)do row[x]=math.max(row[x] or 0,h)end
  end
 end
 for key,shape in pairs(structures.shapeAt or {})do
  local x=(key%4096)-64;local z=math.floor(key/4096)-64
  if (shape.h or 0)>1 then stamp(x*8,z*8,x*8+7.99,z*8+7.99,shape.h)end
 end
 for _,q in ipairs(structures.objectQuads or {})do
  local x0,z0,x1,z1,h=math.huge,math.huge,-math.huge,-math.huge,0
  for i=1,4 do local p=q[i]
   x0,z0=math.min(x0,p[1]),math.min(z0,p[3])
   x1,z1,h=math.max(x1,p[1]),math.max(z1,p[3]),math.max(h,p[2])
  end
  stamp(x0,z0,x1,z1,h)
 end
 for _,prop in ipairs(furniture or {})do
  local model=models and models[prop.kind]
  if prop.claimed and model then
   for _,box in ipairs(model.boxes or {})do
    local x,z=prop.tx*8+box[1],prop.ty*8+box[3]
    stamp(x,z,x+box[4],z+box[6],box[2]+box[5])
   end
  end
 end
 return function(x,z)local row=heights[math.floor(z/4)];return row and row[math.floor(x/4)] or 0 end
end
function B.geometryClear(height,eye,point)
 local dx,dy,dz=point[1]-eye[1],point[2]-eye[2],point[3]-eye[3]
 local steps=math.ceil(math.sqrt(dx*dx+dz*dz)/2)
 for i=1,steps-1 do
  local t=i/steps;local x,y,z=eye[1]+dx*t,eye[2]+dy*t,eye[3]+dz*t
  if height(x,z)>y+.5 then return false,'geometry' end
 end
 return true
end
local function mapFoot(hero,p,desired,scale,map,arena,eye,layout,vp)
 if not (map and arena and arena.presentationMode=='MAP') then return desired end
 local A=V.require('BattleArena');local Scene=V.require('VoxelScene')
 local Board=V.require('BattleBillboard')
 if arena.discs or arena.portableStage then return desired end
 local structures=V.require('Structures').forMap(map)
 local height=fields[structures]
 if not height then
  height=B.geometryField(structures,V.require('VoxelFurniture').find(map),V.require('VoxelItems').models)
  fields[structures]=height
 end
 vp=vp or V.require('Voxel3D').vp
 local function screenSpan(point,width,height)
  if not vp then return end
  local yaw=Board.yawToward(point[1],point[3],eye)
  local rx,rz=math.cos(yaw),-math.sin(yaw)
  local left,right,top,bottom
  for _,side in ipairs({-1,1})do
   for _,rise in ipairs({0,height or hero.height*scale})do
   local x,y,z=point[1]+rx*width*.5*side,point[2]+rise,point[3]+rz*width*.5*side
   local w=vp[13]*x+vp[14]*y+vp[15]*z+vp[16]
   if w<=0 then return end
   local sx=(vp[1]*x+vp[2]*y+vp[3]*z+vp[4])/w
   local sy=(vp[5]*x+vp[6]*y+vp[7]*z+vp[8])/w+1
   left=left and math.min(left,sx)or sx;right=right and math.max(right,sx)or sx
   top=top and math.min(top,sy)or sy;bottom=bottom and math.max(bottom,sy)or sy
   end
  end
  return left,right,top,bottom
 end
 local function screenY(point,h)
  if not vp then return end
  local x,y,z=point[1],point[2]+h,point[3]
  local w=vp[13]*x+vp[14]*y+vp[15]*z+vp[16]
  if w<=0 then return end
  return (vp[5]*x+vp[6]*y+vp[7]*z+vp[8])/w+1
 end
 local relaxed,sideFlank=false,false
 local other=layout.player==p and layout.enemy or layout.player
 -- These Pokemon spans belong to this immutable camera/layout. A trainer
 -- search may test dozens of feet; project each opponent only once.
 local obstacles={}
 for _,side in ipairs({'player','enemy'})do
  local mark=layout[side]
  local hull=layout.actorScreenHulls and layout.actorScreenHulls[side]
  local h=layout.actorInkHeight and layout.actorInkHeight[side]
  local l,r,t,b=screenSpan(mark,layout.actorInkWidth and layout.actorInkWidth[side] or 16*scale,h)
  if not h then t,b=nil,nil end
  if hull then l,r,t,b=hull[1]-1,hull[1]+hull[3]-1,hull[2],hull[2]+hull[4] end
  obstacles[#obstacles+1]={mark=mark,left=l,right=r,
   top=t,bottom=b,
   upper=hull and (hull[2]+hull[4]*.40) or (h and screenY(mark,h*.60))}
 end
 local function accept(point)
  local x,y,z=point[1],point[2],point[3]
  if not B.onTeamSide(p,other,point,scale,sideFlank) then return false,'team-side' end
  local left,right,top,bottom=screenSpan(point,(hero.width+2)*scale)
  if left then
   if left<-.98 or right>.98 then return false,'frame' end
   for _,obstacle in ipairs(obstacles)do
    local l,r=obstacle.left,obstacle.right
    if l and B.screenOverlap(left,right,top,bottom,l,r,obstacle.top,obstacle.bottom) then
     local foreground=obstacle.mark==p and B.inForeground(p,eye,point,scale)
     if not B.foregroundOverlap(left,right,l,r,screenY(point,hero.height*scale),
       obstacle.upper,foreground) then return false,'actor-overlap' end
    end
   end
  end
  local cx,cy=math.floor(x/16),math.floor(z/16)
  if not A.openCell(map,cx,cy,arena.surfing == true) then return false,'ground' end
  if math.abs(Scene.groundAt(map,cx,cy)-y)>.5 then return false,'height' end
  if relaxed then return true end
  if height(x,z)>y+.5 then return false,'geometry' end
  local yaw=Board.yawToward(x,z,eye)
  local rx,rz=math.cos(yaw),-math.sin(yaw)
  for _,edge in ipairs({0,-.35,.35})do
   local offset=hero.width*scale*edge
   if A.visibility(map,eye,{x+rx*offset,z+rz*offset},y,hero.height*scale)<3 then return false,'visibility' end
   for _,fraction in ipairs({.1,.5,1})do
    if not B.geometryClear(height,eye,{x+rx*offset,y+hero.height*scale*fraction,z+rz*offset}) then return false,'geometry-ray' end
   end
  end
  return true
 end
 local cache=hero.mapFoot
 local same=cache and cache.arena==arena and cache.x==p[1] and cache.z==p[3]
 relaxed=same and cache.needsClearance or false
 sideFlank=same and cache.sideFlank or false
 local preferred=layout.player==p and function(q)return B.inForeground(p,eye,q,scale)end or nil
 local function support(x,z)return Scene.groundAt(map,math.floor(x/16),math.floor(z/16))end
 local foot,clear=B.chooseFoot(p,desired,scale,accept,same and cache.foot,preferred,support)
 if not clear then
  relaxed=true;foot,clear=B.chooseFoot(p,desired,scale,accept,nil,preferred,support)
 end
 if not clear then
  -- A narrow pier may have no rear apron. Allow a close side flank, still
  -- level with its own Pokemon, never advancing toward midfield.
  sideFlank=true;foot,clear=B.chooseFoot(p,desired,scale,accept,nil,preferred,support)
 end
 hero.mapFoot={arena=arena,x=p[1],z=p[3],foot=foot,clear=clear,needsClearance=relaxed,sideFlank=sideFlank}
 return foot
end
-- Compare the body's direction toward its opponent with the actual camera
-- bearing at its collision-safe foot. A dead band prevents boundary flicker.
function B.bodyView(foot,target,eye,previous)
 if not (foot and target and eye) then return previous end
 local dx,dz=target[1]-foot[1],target[3]-foot[3]
 local ex,ez=eye[1]-foot[1],eye[3]-foot[3]
 local length=math.sqrt((dx*dx+dz*dz)*(ex*ex+ez*ez))
 if length<.001 then return previous end
 local dot=(dx*ex+dz*ez)/length
 if dot>=.72 or previous=='front' and dot>=.60 then return 'front' end
 if dot<=-.72 or previous=='back' and dot<=-.60 then return 'back' end
 return 'side'
end
function B.append(cards,textures,layout,eye,map,arena,presentationVP,probe)
 local heroes=textures and textures.battleHeroes
 if not heroes then return end
 for _,side in ipairs({'player','enemy'}) do
 local hero=heroes[side]
 if hero and probe then
  local copy={};for k,value in pairs(hero)do copy[k]=value end;hero=copy
 end
 if hero then
 local other=side=='player' and 'enemy' or 'player'
 local p,e=layout[side],layout[other]
 if not (hero.canvas and p and e) then return end
 local sign=side=='player' and 1 or -1
 local Board=V.require('BattleBillboard')
 local dx,dz=p[1]-e[1],p[3]-e[3]
 local d=math.sqrt(dx*dx+dz*dz)
 if d<.001 then return end
 dx,dz=dx/d,dz/d
 local yaw=Board.yawToward(p[1],p[3],eye)
 local rx,rz=math.cos(yaw),-math.sin(yaw)
 local toward=(e[1]-p[1])*rx+(e[3]-p[3])*rz
 if math.abs(toward)>.001 then sign=toward>0 and 1 or -1 end
 hero.facing=sign==1 and 'player' or 'enemy'
 local scale=layout.actorScale and layout.actorScale[side] or 1
 local desired=B.rearFoot(p,e,eye,scale,side)
 local x,y,z=desired[1],desired[2],desired[3]
 local foot=arena and arena.terarrium and arena.terarriumService.trainerFoot(arena,side,p[2])
  or mapFoot(hero,p,desired,scale,map,arena,eye,layout,presentationVP)
 x,y,z=foot[1],foot[2],foot[3]
 local view=arena.terarrium and hero.view or B.bodyView(foot,{foot[1]+e[1]-p[1],foot[2],foot[3]+e[3]-p[3]},eye,hero.view)
 if not probe and hero.setView then hero.setView(view,hero.facing) end
 local matrix=Board.matrix(x,y,z,hero.width*scale,hero.height*scale,
  Board.yawToward(x,z,eye))
 local vp=V.require('Voxel3D').vp
 if vp then
  local hand=hero.releaseHand or {.5,.5}
  local offset=(hand[1]-.5)*hero.width*scale
  local hx,hy,hz=x+rx*offset,y+hero.height*(1-hand[2])*scale,z+rz*offset
  local w=vp[13]*hx+vp[14]*hy+vp[15]*hz+vp[16]
  if w>0 then hero.handNdc={
   (vp[1]*hx+vp[2]*hy+vp[3]*hz+vp[4])/w,
   (vp[5]*hx+vp[6]*hy+vp[7]*hz+vp[8])/w} end
 end
 cards[#cards+1]={side=side..'Hero',source=hero,tex=hero.canvas,
  placementSafe=not (map and arena and arena.presentationMode=='MAP'
    and ((layout.actorScreenHulls and layout.actorScreenHulls.player and layout.actorScreenHulls.enemy)
      or (layout.actorInkWidth and layout.actorInkWidth.player and layout.actorInkWidth.enemy))) or
    (hero.mapFoot and hero.mapFoot.arena==arena and hero.mapFoot.clear)~=false,
  metrics={canvasWidth=192,canvasHeight=256,inkX0=0,inkY0=0,inkX1=191,inkY1=255},
  model=matrix,shadowModel=matrix,shadowGroundY=y,
  shadowFoot={x,y,z},shadowRadius={2.8*scale,1.8*scale}}
end
end
end
function B.cameraSafe(visuals,reserved,frame,padding)
 for _,side in ipairs({'playerHero','enemyHero'})do
  local actor=visuals and visuals[side]
  if actor then
   if actor.placementSafe==false then return false,side..'-placement-unavailable' end
   local h=actor.hull
   if not h or h[1]<frame[1] or h[2]<frame[2] or h[1]+h[3]>frame[3] or h[2]+h[4]>frame[4] then
    return false,side..'-outside-safe-frame'
   end
   for _,r in ipairs(reserved or {})do
    if h[1]<r.x+r.w+padding and h[1]+h[3]+padding>r.x
     and h[2]<r.y+r.h+padding and h[2]+h[4]+padding>r.y then
     return false,side..'-under-'..tostring(r.id or 'hud')
    end
   end
  end
 end
 return true
end
function B.reserveHUD(geometry,visuals)
 for _,side in ipairs({'player','enemy'}) do
 local actor=visuals and visuals[side..'Hero']
 local h=actor and actor.hull
 local p=geometry and geometry.actorHulls and geometry.actorHulls[side]
 if h and p then
 local x,y=math.min(h[1],p[1]),math.min(h[2],p[2])
 local right,bottom=math.max(h[1]+h[3],p[1]+p[3]),math.max(h[2]+h[4],p[2]+p[4])
 geometry.actorHulls[side]={x,y,right-x,bottom-y}
end
end
end
-- A complete trainer placement casts overlapping visibility rays. Reuse
-- cell samples inside this synchronous placement only, including the colour
-- and shadow callers that run outside the camera solver's existing scope.
local appendActors=B.append
function B.append(...)
 local arena=V.require('BattleArena')
 if arena and arena.withVisibilitySamples then
  return arena.withVisibilitySamples(appendActors,...)
 end
 return appendActors(...)
end
return B
