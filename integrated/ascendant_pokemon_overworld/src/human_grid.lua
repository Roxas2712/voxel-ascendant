-- Human grid animation; dependencies are loaded by the mod entry point.
return function(Cache,Stencil,Builder,Preparation)
local Module={}
function Module.new(voxel,helpers)
 local cache=Cache.new(voxel.newMesh,24,32)
 local prep=Preparation.new(helpers.queue(love.timer.getTime,.002),24,function()end,
  {budget=128000,weight=function(value)return #value.shape.vertices end})
 local token,seen=nil,{}
 local sourceIds=setmetatable({},{__mode='k'});local sourceSerial=0
 local recent={}
 local actors=setmetatable({},{__mode='k'})
 local api={metrics={draws=0,pending=0,clears=0,poseReads=0},cache=cache,preparation=prep}
 function api:clear()
  prep:clear();cache:clear();actors=setmetatable({},{__mode='k'});seen={};recent={};token=nil
  sourceIds=setmetatable({},{__mode='k'});sourceSerial=0
  self.metrics.clears=self.metrics.clears+1
 end
 function api:context(nextToken)
  if token~=nextToken then self:clear();token=nextToken end
 end
 function api:frame(nextToken,allowed)
  if not allowed then self:clear();return end
  self:context(nextToken)
  local now=love.timer.getTime();local retained={}
  for key,d in pairs(recent)do
   if now-d.lastUsed<=1.5 then retained[#retained+1]=d else recent[key]=nil end
  end
  table.sort(retained,function(a,b)return a.lastUsed>b.lastUsed end)
  for i=#retained,25,-1 do recent[retained[i].key]=nil;retained[i]=nil end
  prep:frame(token,true,retained);seen={}
 end
 function api:prepare(nextToken,record,flat,texture,source,row,col,height,cubes,neutral)
  self:context(nextToken)
  local id=sourceIds[source.texture]
  if not id then sourceSerial=sourceSerial+1;id=sourceSerial;sourceIds[source.texture]=id end
  local key=table.concat({id,tostring(record.role),row,col,height,
    cubes and cubes.depth or 0,cubes and cubes.layers or 0,tostring(neutral)},':')
  local shape=cache:get(key)
  if not shape and not seen[key]then
   seen[key]=true
   recent[key]={key=key,lastUsed=love.timer.getTime(),factory=Builder.factory({texture=texture,flat=flat,
    neutral=source.bounds[row][0],row=row,bounds=helpers.bounds,cardMesh=helpers.cardMesh,
    voxel=voxel,stencil=Stencil,cubes=cubes,visibleHeight=height,
    flatUnit=height/(source.bounds[row][0].bottom-source.bounds[row][0].top),shadingNeutral=neutral,continuousSurface=true})}
  end
  if not shape then
   local ready=prep:get(token,key)
   if not ready then self.metrics.pending=self.metrics.pending+1;return nil end
   shape=cache:put(key,ready.shape)
   if not shape then return nil end
  end
  recent[key]=nil
  local state=actors[record]
  if not state or state.key~=key or state.shape~=shape then state={key=key,shape=shape,pose=Stencil.newPose(shape)};actors[record]=state end
  local motion=record.humanMotion
  local poseKey=tostring(motion.armStride)..':'..tostring(motion.idleShift)
  local ok,mesh,err=pcall(function()
   if state.lastPose~=poseKey then
    state.deform=state.pose:update(flat);state.lastPose=poseKey
    self.metrics.poseReads=self.metrics.poseReads+1
   end
   return cache:draw(key,record,poseKey,state.deform)
  end)
  if not ok or not mesh then self.error=err or mesh;return nil end
  self.metrics.draws=self.metrics.draws+1
  return mesh,texture
 end
 return api
end
return Module
end
