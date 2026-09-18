-- Exact runtime seating for source-reviewed stationary actors. Source atlases
-- remain unchanged. Gen1 seats also apply in Classic; HD-off and the grid
-- keep their original rendering.
local M={}
local function smooth(a,b,x)
 local t=math.max(0,math.min(1,(x-a)/(b-a)))
 return t*t*(3-2*t)
end
local function value(mod,key,default)
 local ok,v=pcall(mod.options.get,mod.options,key)
 if ok and v~=nil then return v end
 return default
end
function M.new(options)
 local mod,voxel=assert(options.mod),assert(options.voxel)
 local profileData=assert(options.profiles,'human seat profiles')
 local profilesByMap=assert(profileData.byGeneration)[options.generation]or{}
 local graphics=love.graphics
 local poses,meshes={},{}
 local serial,count=0,0
 local api={updates=0,meshes=0,textures=0}
 local compositeShader
 local function atlasFamily(path)
  local name=tostring(path or ''):gsub('\\','/'):match('([^/]+)%.png$')or''
  return name:gsub('%-variant%-.+$',''):gsub('(%-sheet%-v%d+)%-.+$','%1')
 end
 local function admittedSource(def,profile)
  local path=tostring(def and def.ascendantAtlasImage or ''):gsub('\\','/')
  return (path:find('/assets/characters/npcs/',1,true)or path:sub(1,24)=='assets/characters/npcs/')
   and atlasFamily(path)==atlasFamily(profile.path)
 end
 local function enabled()
  return (options.generation==1 or options.generation==2)
   and value(mod,'hd_walking_sprites',true)==true
   and value(mod,'actor_voxel_grid','off')=='off'
 end
 local function release(record)
  local s=meshes[record];if not s then return end
  for _,r in ipairs({s.mesh,s.canvas,s.frontCanvas,s.turnedCanvas,s.quad,s.frontQuad})do
   if r and r.release then r:release()end
  end
  meshes[record]=nil;count=count-1;api.meshes=count;api.textures=count*3
 end
 local function actorFor(game,record,profile)
  local world=game and (options.generation==2 and game.world or game.overworld or game.world)
  if not world or not world.map or world.map.id~=profile.mapId then return end
  local found
  for _,actor in pairs(world.npcs or {})do
   if actor.sprite==record.sprite then if found then return end;found=actor end
  end
  local def=found and found.sprite and found.sprite.def
  if not def or found.def==nil or found.def.index~=profile.index
   or def.ascendantRole~=profile.role
   or not admittedSource(def,profile)
   or def.ascendantCharacterAction~=nil
   or found.cellX~=profile.cellX or found.cellY~=profile.cellY
   or found.px~=profile.px or found.py~=profile.py
   or found.moving or found.scriptedMoving then return end
  return found,world
 end
 function api:pose(game,record,dialogueBox,now)
  local world=game and (options.generation==2 and game.world or game.overworld or game.world)
  local mapId=world and world.map and world.map.id
  if not enabled() or not mapId then if record then poses[record]=nil end;return end
  local profile,actor
  for _,candidate in ipairs(profilesByMap[mapId]or{})do
   local found=actorFor(game,record,candidate)
   if found then profile,actor=candidate,found;break end
  end
  local acting=value(mod,'human_acting_pilot',false)==true and value(mod,'card_animation_mode','classic')=='natural'
  if not actor or (not acting and not profile.alwaysSeated) then poses[record]=nil;return end
  local target=acting and dialogueBox and (profile.directDialogue or world.talkNpc==actor) and 1 or 0
  local state=poses[record]
  if not state or state.actor~=actor or state.sprite~=actor.sprite then
   state={actor=actor,sprite=actor.sprite,look=0,last=now};poses[record]=state
  end
  local dt=math.min(.1,math.max(0,now-(state.last or now)));state.last=now
  state.look=state.look+(target-state.look)*(1-math.exp(-dt*9))
  if math.abs(target-state.look)<.002 then state.look=target end
  state.target=target
  return profile,state.look,state.look==target
 end
 local function appendCuts(out,a,b,candidates)
  out[1]=a
  for _,v in ipairs(candidates)do if v>a and v<b then out[#out+1]=v end end
  out[#out+1]=b
 end
 local function build(record,original,source,profile,visibleHeight)
  local n=original:getVertexCount();assert(n==4 or n==16,'unsupported seated card mesh')
  local imageWidth,imageHeight=source.texture:getDimensions()
  assert(imageWidth%3==0 and imageHeight%4==0,'seated atlas layout')
  local cellWidth,cellHeight=imageWidth/3,imageHeight/4
  local vertices,indices,base={},{},{}
  if not profile.bodyMin or not profile.bodyMax or not profile.headCenter then
   local bounds=source.bounds and source.bounds[profile.row]
    and source.bounds[profile.row][0]
   local left,right=cellWidth*.18,cellWidth*.82
   if bounds then
    left=math.max(0,(tonumber(bounds.left)or left))
    right=math.min(cellWidth,(tonumber(bounds.right)or right))
   end
   local width=math.max(24,right-left)
   profile.bodyMin=left+width*.08;profile.bodyMax=right-width*.08
   profile.headCenter=(left+right)/2
  end
  local u0,u1=0,cellWidth/imageWidth
  local v0,v1=profile.row*cellHeight/imageHeight,(profile.row+1)*cellHeight/imageHeight
  local xCandidates={
   (profile.bodyMin-10)/imageWidth,profile.bodyMin/imageWidth,
   profile.bodyMax/imageWidth,(profile.bodyMax+10)/imageWidth,
   profile.headCenter/imageWidth,
  }
  local yCandidates={}
  for _,y in ipairs({profile.headFade[1],profile.headFade[2],120,138,160,165,178})do
   yCandidates[#yCandidates+1]=(profile.row*cellHeight+y)/imageHeight
  end
  table.sort(xCandidates);table.sort(yCandidates)
  local unit=visibleHeight/cellHeight
  local function transform(v)
   local sourceX=v[4]*imageWidth
   local sourceY=v[5]*imageHeight-profile.row*cellHeight
   local leg=smooth(profile.bodyMin-10,profile.bodyMin,sourceX)
    *(1-smooth(profile.bodyMax,profile.bodyMax+10,sourceX))
   local shift=sourceY<=138 and 0 or sourceY<165 and (sourceY-138)/27*26 or 26
   local outY=sourceY
   if sourceY>138 and sourceY<165 then outY=138+(sourceY-138)*.62
   elseif sourceY>=165 then outY=154.74+(sourceY-165)*(cellHeight-154.74)/(cellHeight-165)end
   local head=1-smooth(profile.headFade[1],profile.headFade[2],sourceY)
   local b={}
   for k=1,6 do b[k]=v[k]end
   b[1]=b[1]+(profile.bendSign or profile.sign)*shift*leg*unit
   -- Side-facing occupants of deep voxel chairs also need their shins
   -- in front of the seat edge, while the hips stay on its cushion.
   local depth=profile.legDepth or ((profile.bendSign or profile.sign)==0 and .72 or 0)
   b[3]=b[3]+shift*leg*unit*depth
   b[2]=b[2]+(sourceY-outY)*unit
   b[4]=(v[4]*imageWidth)/cellWidth
   b[5]=(v[5]*imageHeight-profile.row*cellHeight)/cellHeight
   base[#base+1]={x=b[1],y=b[2],z=b[3],sourceX=sourceX,head=head,unit=unit}
   vertices[#vertices+1]=b
   return #vertices
  end
  for quad=0,n/4-1 do
   local a,b,c,d={original:getVertex(quad*4+1)},{original:getVertex(quad*4+2)},
    {original:getVertex(quad*4+3)},{original:getVertex(quad*4+4)}
   local left,right=math.max(u0,math.min(a[4],d[4])),math.min(u1,math.max(b[4],c[4]))
   local top,bottom=math.max(v0,math.min(c[5],d[5])),math.min(v1,math.max(a[5],b[5]))
   if right>left and bottom>top then
    local xs,ys={},{};appendCuts(xs,left,right,xCandidates);appendCuts(ys,top,bottom,yCandidates)
    local function sample(u,v)
     local tx=(u-a[4])/(b[4]-a[4]);local ty=(v-d[5])/(a[5]-d[5])
     local out={}
     for k=1,6 do
      local upper=d[k]+(c[k]-d[k])*tx;local lower=a[k]+(b[k]-a[k])*tx
      out[k]=upper+(lower-upper)*ty
     end
     out[4],out[5]=u,v;return transform(out)
    end
    for yi=1,#ys-1 do for xi=1,#xs-1 do
     local tl=sample(xs[xi],ys[yi]);local tr=sample(xs[xi+1],ys[yi])
     local br=sample(xs[xi+1],ys[yi+1]);local bl=sample(xs[xi],ys[yi+1])
     indices[#indices+1]=bl;indices[#indices+1]=br;indices[#indices+1]=tr
     indices[#indices+1]=bl;indices[#indices+1]=tr;indices[#indices+1]=tl
    end end
   end
  end
  assert(#vertices>0,'empty seated mesh')
  local mesh=assert(voxel.newMesh(vertices,indices))
  local function cell(row)
   local canvas=graphics.newCanvas(cellWidth,cellHeight);canvas:setFilter('linear','linear')
   local quad=graphics.newQuad(0,row*cellHeight,cellWidth,cellHeight,imageWidth,imageHeight)
   graphics.push('all')
   local ok,err=pcall(function()
    graphics.setCanvas(canvas);graphics.origin();graphics.setScissor();graphics.setDepthMode()
    graphics.clear(0,0,0,0);graphics.setColor(1,1,1,1)
    graphics.setBlendMode('replace','premultiplied');graphics.setShader();graphics.draw(source.texture,quad)
   end)
   graphics.pop();if not ok then canvas:release();quad:release();error(err,0)end
   return canvas,quad
  end
  local ok,canvas,quad,frontCanvas,frontQuad=pcall(function()
   local a,b=cell(profile.row);local c,d=cell(0);return a,b,c,d
  end)
  if not ok then mesh:release();error(canvas,0)end
  local turnedCanvas=graphics.newCanvas(cellWidth,cellHeight);turnedCanvas:setFilter('linear','linear')
  return {mesh=mesh,canvas=canvas,quad=quad,frontCanvas=frontCanvas,frontQuad=frontQuad,
   turnedCanvas=turnedCanvas,vertices=vertices,base=base,source=source.texture,
   original=original,profile=profile,look=-1,used=serial}
 end
 function api:prepare(record,original,source,profile,visibleHeight,look)
  if not record or not original or not source or not profile then return nil end
  serial=serial+1;local state=meshes[record]
  if state and (state.original~=original or state.source~=source.texture or state.profile~=profile)then release(record);state=nil end
  if not state then
   -- A Game Corner can show ten seated actors at once. Retaining their small
   -- per-actor blink canvases avoids rebuilding and releasing them every draw.
   if count>=16 then
    local oldest,used
    for key,s in pairs(meshes)do if not used or s.used<used then oldest,used=key,s.used end end
    release(oldest)
   end
   state=build(record,original,source,profile,visibleHeight);meshes[record]=state
   count=count+1;api.meshes=count;api.textures=count*3
  end
  state.used=serial;look=math.max(0,math.min(1,tonumber(look)or 0))
  if state.look~=look then
   local angle=(profile.headSign or profile.sign)*math.sin(math.pi*look)*.46
   local cosine,sine=math.cos(angle),math.sin(angle)
   for i,item in ipairs(state.base)do
    local dx=(item.sourceX-profile.headCenter)*item.unit
    state.vertices[i][1]=item.x+dx*(cosine-1)*item.head
    state.vertices[i][2]=item.y-1.2*item.unit*look*item.head
    state.vertices[i][3]=item.z+dx*sine*item.head
   end
   state.mesh:setVertices(state.vertices);state.look=look;api.updates=api.updates+1
  end
  return state.mesh,state.canvas
 end
 function api:front(record)
  local state=meshes[record];return state and state.frontCanvas or nil
 end
 function api:compose(record,front,profile,amount)
  local state=meshes[record];if not state or not front then return nil end
  amount=tonumber(amount)or 0
  if state.compositeFront==front and state.compositeAmount==amount then return state.turnedCanvas end
  if not compositeShader then compositeShader=graphics.newShader([[
   extern Image front;extern vec2 cutBand;extern float frontOffset;
   vec4 effect(vec4 color,Image side,vec2 uv,vec2 screen){
    vec2 p=uv*vec2(165.0,225.0);vec2 fuv=uv+vec2(frontOffset/165.0,0.0);
    vec4 f=(fuv.x>=0.0&&fuv.x<=1.0)?Texel(front,fuv):vec4(0.0);
    float useFront=1.0-smoothstep(cutBand.x,cutBand.y,p.y);
    return mix(Texel(side,uv),f,useFront)*color;
   }
  ]])end
  graphics.push('all')
  local ok,err=pcall(function()
   graphics.setCanvas(state.turnedCanvas);graphics.origin();graphics.setScissor();graphics.setDepthMode()
   graphics.clear(0,0,0,0);graphics.setColor(1,1,1,1);graphics.setBlendMode('replace','premultiplied')
   graphics.setShader(compositeShader);compositeShader:send('front',front)
   compositeShader:send('cutBand',profile.headCut);compositeShader:send('frontOffset',profile.frontOffset)
   graphics.draw(state.canvas)
  end)
  graphics.pop();if not ok then self.error=err;return nil end
  state.compositeFront,state.compositeAmount=front,amount;return state.turnedCanvas
 end
 function api:reset()for record in pairs(poses)do poses[record]=nil end end
 function api:clear()
  self:reset();local keys={};for record in pairs(meshes)do keys[#keys+1]=record end
  for _,record in ipairs(keys)do release(record)end
  if compositeShader then compositeShader:release();compositeShader=nil end
 end
 return api
end
return M
