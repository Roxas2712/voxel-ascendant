-- Exercise the actual bounded pump with suspended jobs, no geometry/GPU mocks.
local function up(fn,name)
 for i=1,100 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
 error('missing '..name)
end
for _,mobile in ipairs{true,false}do
 local t=0;local picked={};local budget
 love={timer={getTime=function()return t end,getDelta=function()return 1/60 end}}
 package.loaded['src.render.Assets']={register=function()end}
 local modules={Voxel3D={mobileRuntime=function()return mobile end},ModSetting={new=function()return{}end},
 BuildBudget={begin=function(_,slice)budget=slice end,finish=function()end}}
 local M=assert(loadfile('lib/ChunkMesher.lua'))({require=function(n)return modules[n] or{}end})
 local jobs=up(M.pump,'jobs')
 local function job(id,rank,published,aux)
  return{id=id,live=true,priority=rank,terrainPublished=published,auxOnly=aux,
   co=coroutine.create(function()while true do picked[#picked+1]=id;t=t+1;coroutine.yield()end end)}
 end
 jobs[1]=job('current-decoration',2,true,false)
 jobs[2]=job('route9-body',1,false,false)
 jobs[3]=job('route4-body',1,false,false)
 M.pump(false,false,false)
 assert(picked[1]==(mobile and 'route9-body' or 'current-decoration'),'terrain queue priority')
 assert(budget>0 and budget<=.0041,'visible frame budget increased')
 if mobile then
  jobs[2].terrainPublished=true;M.pump(false,false,false)
  assert(picked[2]=='route4-body','second direct body starved')
  jobs[3].terrainPublished=true;M.pump(false,false,false)
  assert(picked[3]=='current-decoration','current decoration failed to resume')
  jobs[1].urgent=true;jobs[2].terrainPublished=false;M.pump(false,false,false)
  assert(picked[4]=='current-decoration','explicit urgent ownership changed')
 end
end
print('PASS mobile body-before-aux, direct queue drains, unchanged budget and desktop/urgent priority')
