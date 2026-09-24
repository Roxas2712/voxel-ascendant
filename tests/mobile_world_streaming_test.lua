-- Exercise production scene planning on both phone paths without a GPU.
local function up(fn,name,value,set)
  for i=1,100 do local k,v=debug.getupvalue(fn,i);if not k then break end
    if k==name then if set then debug.setupvalue(fn,i,value) end;return v end
  end
  error('missing upvalue '..name)
end
for _,osName in ipairs({'Android','iOS'}) do
  local ready,aux,atlas,requests,live={},{},{},{},{}
  local horizonReady=false
  local modules={CanvasPresentation={OS=osName},VoxelState={},Mat4={identity=function()return{}end},
    ChunkMesher={request=function(m)requests[m.id]=true end,
      pair=function(m)return ready[m] and {id=m.id} or nil,ready[m] and {water=m.id} or nil end,
      setLive=function(ids)live=ids end,auxReady=function(m)return aux[m]==true end},
    TerrainAtlas={prepared=function(m)return atlas[m]==true end,
      prepare=function(m)atlas[m]=true end,setLive=function()end},
    HorizonWall={preferBody=function()return true end,enabled=function()return true end,
      meshes=function()return {},horizonReady end,cacheStatus=function()return{ready=horizonReady}end,hasSky=function()return true end},
    PanoramaBackdrop={setEnabled=function()end,ready=function()return false end,
      prepare=function()return false,'gpu-unavailable',false end},
  }
  local V={mod={}}
  function V.require(n)
    if not modules[n] then
      if n=='MobileWorldPlan' or n=='MobileSceneryGate' then
        modules[n]=assert(loadfile('lib/'..n..'.lua'))(V)
      else modules[n]={} end
    end
    return modules[n]
  end
  package.loaded['src.render.PaletteFX']={};package.loaded['src.world.Map']={}
  local scene=assert(loadfile('lib/VoxelScene.lua'))(V)
  local core=up(scene.prefetch,'mobileCorePrefetch')
  local trace=up(core,'mobileCoreTrace')
  local a={id='PALLET_TOWN',def={width=10,height=9,connections={north={map='ROUTE_1'}}}}
  local b={id='ROUTE_1',def={width=10,height=18,connections={south={map='PALLET_TOWN'}}}}
  local aState={map=a,neighbors={{map=b,ox=0,oy=-576}}}
  local bState={map=b,neighbors={{map=a,ox=0,oy=576}}}
  ready[a],atlas[a]=true,true
  local function presented(state)
    trace.presented=true
    modules.MobileSceneryGate.noteSafeCanvas(state.map,{})
    scene.prefetch(state)
  end
  scene.prefetch(aState);presented(aState)
  local ok,name=scene.stageMobileScenery(aState)
  assert(ok and name=='direct-ring-admit' and requests.ROUTE_1,'cold route must queue before horizon')
  assert(not aux[b] and not horizonReady)
  ready[b]=true
  local _,_,_,_,p=scene.prefetch(aState)
  assert(p.maps.ROUTE_1 and #p.meshes==1 and p.waters[1].water=='ROUTE_1','ground/water must not wait for aux or panorama')
  local _,_,_,_,q=scene.prefetch(bState)
  assert(q.maps.PALLET_TOWN and q.maps.ROUTE_1,'crossing dropped previous map')
  assert(q.state.neighbors[1].ox==0 and q.state.neighbors[1].oy==576,'re-root offset')
  assert(live.PALLET_TOWN and live.ROUTE_1,'retained map not resident')
  presented(bState);scene.stageMobileScenery(bState)
  horizonReady=true;scene.stageMobileScenery(bState);scene.stageMobileScenery(bState)
  assert(modules.MobileSceneryGate.status(b).failed,'panorama failure fixture')
  local _,_,_,_,failedPlan=scene.prefetch(bState)
  assert(failedPlan.maps.PALLET_TOWN,'optional failure erased terrain')
  local _,_,_,_,back=scene.prefetch(aState)
  assert(back.maps.ROUTE_1,'immediate return dropped route')
  -- A real door/warp cannot borrow the previous outside ring.
  local room={id='ROOM',def={width=4,height=4,connections={}}}
  ready[room],atlas[room]=true,true
  local _,_,_,_,door=scene.prefetch({map=room,neighbors={}})
  assert(#door.meshes==0 and not door.maps.PALLET_TOWN)
  -- Same ID on a new object/save and altered connection offsets do not inherit.
  local P=modules.MobileWorldPlan
  local replacement={id=b.id,def=b.def}
  assert(next(P.handoff({map=replacement,neighbors=bState.neighbors},aState))==nil)
  assert(next(P.handoff({map=b,neighbors={{map=a,ox=16,oy=576}}},aState))==nil)
  local unready=P.bodies(aState,{[1]={}}, {},function()return false end)
  assert(not unready.maps.ROUTE_1,'cold atlas leaked')
  -- Four-way city: warm direct maps survive a fast route/city round-trip.
  local city={id='CERULEAN_CITY',def={connections={}}}
  local cityState={map=city,neighbors={}}
  for i=1,4 do
    local route={id='ROUTE_'..i,def={connections={city={map=city.id}}}}
    city.def.connections[({'north','south','west','east'})[i]]={map=route.id}
    cityState.neighbors[i]={map=route,ox=i*320,oy=0}
    ready[route],atlas[route]=true,true
  end
  ready[city],atlas[city]=true,true
  local _,_,_,_,cityPlan=scene.prefetch(cityState)
  assert(#cityPlan.meshes==4,'warm city ring was unnecessarily readmitted')
  for _,nb in ipairs(cityState.neighbors)do assert(live[nb.map.id],'warm direct map not reserved')end
  -- A growing scene keeps its completed horizon until the replacement is ready.
  local fifth=cityState.neighbors[4].map
  ready[fifth]=nil
  up(core,'mobileSceneryPlan',nil,true)
  local gate=modules.MobileSceneryGate
  presented(cityState);horizonReady=true
  modules.PanoramaBackdrop.ready=function()return true end
  modules.PanoramaBackdrop.prepare=function()return true end
  for i=1,5 do scene.stageMobileScenery(cityState)end
  assert(gate.beginProbe(city));assert(gate.finishProbe(city,{}))
  ready[fifth],atlas[fifth]=true,true;horizonReady=false
  scene.stageMobileScenery(cityState)
  local _,_,_,_,stable=scene.prefetch(cityState)
  assert(gate.allow(city) and not stable.maps[fifth.id],'incomplete horizon replaced the visible scene')
  horizonReady=true;scene.stageMobileScenery(cityState)
  local _,_,_,_,expanded=scene.prefetch(cityState)
  assert(expanded.maps[fifth.id] and gate.allow(city),'completed horizon did not publish atomically')
  print('PASS '..osName..': cold admission, terrain before decoration, handoff/return, panorama failure, warp/save isolation')
end
