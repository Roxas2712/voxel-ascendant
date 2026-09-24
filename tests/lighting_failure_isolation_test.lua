-- GPU resource rejection must not escape into the engine's one-way pipeline guard.
for _,platform in ipairs({'Windows','Android','iOS'}) do
  local attempts,events,sent=0,{},{}
  love={image={newImageData=function()return {release=function()end}end},
    graphics={newImage=function()return {}end}}
  local modules={
    CanvasPresentation={OS=platform},
    ModSetting={new=function()return {get=function()return true end,setGate=function()end}end},
    LocalLightGrid={prepare=function()attempts=attempts+1;error('GPU texture allocation rejected')end},
    Diagnostics={write=function(event,fields)events[#events+1]={event,fields}end},
  }
  local L=assert(loadfile('lib/LocalLights.lua'))({require=function(name)return assert(modules[name],name)end})
  L.current().allLights={{}}
  local shader={hasUniform=function(_,name)return name=='localLightCount' or name=='localGridOn'end,
    send=function(_,name,value)sent[name]=value end}
  local ok,err=pcall(L.send,shader,true)
  assert(ok,'lighting killed '..platform..' pipeline: '..tostring(err))
  assert(sent.localGridOn==0 and sent.localLightCount==0,'stale light uniforms survived failure')
  assert(L.failure:find('GPU texture allocation rejected',1,true))
  for i=1,120 do L.clear();L.current().allLights={{}};L.send(shader,true)end
  assert(attempts==1,'failed GPU allocation retried every frame')
  assert(#events==1 and events[1][2].actual=='unlit-3d','missing bounded failure receipt')
end
print('PASS lighting allocation failure isolated on Windows/Android/iOS; uniforms reset and no retry storm')
