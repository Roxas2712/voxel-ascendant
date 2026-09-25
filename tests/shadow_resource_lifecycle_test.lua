-- Exercise the actual allocation closures, including fitted-size availability.
local function upvalue(fn,name)
 for i=1,100 do local k,v=debug.getupvalue(fn,i);if k==name then return v end end
 error('missing upvalue '..name)
end
for _,prefix in ipairs({'','gen2/'})do
 local created,released,dataReleased,attempts=0,0,0,0
 local failCanvas,failImage,off,mobile=false,false,false,false
 local function resource()
  created=created+1
  return {setFilter=function()end,setWrap=function()end,release=function(self)assert(not self.freed);self.freed=true;released=released+1 end}
 end
 love={system={getOS=function()return mobile and 'Android' or 'OS X'end},
  graphics={newCanvas=function()end,setDepthMode=function()end,newShader=function()return {}end,
   newImage=function()if failImage then error('injected image upload failure')end;return resource()end},
  image={newImageData=function()return {setPixel=function()end,release=function()dataReleased=dataReleased+1 end}end}}
 local modules={Mat4={identity=function()return {}end},VoxelState={},Gen1CaveWalls={},
  CanvasPresentation=setmetatable({},{__index=function()return mobile and 'Android' or 'OS X'end}),
  Quality={shadowsOff=function()return off end,shadowSizes=function()return {1024,1536,2048}end},
  PixelCanvas={new=function()attempts=attempts+1;if failCanvas then return false,'injected allocation failure'end;return true,resource()end}}
 local shadow=assert(loadfile(prefix..'lib/ShadowMap.lua'))({require=function(n)return assert(modules[n],n)end})
 local allocate=upvalue(shadow.available,'getCanvas')
 assert(allocate(2048));local n=attempts
 for i=1,600 do assert(shadow.available());assert(allocate(2048))end
 assert(attempts==n,prefix..'availability reallocates a fitted shadow canvas: '..attempts)
 if prefix~=''then
  off=true;assert(not shadow.available());off=false;mobile=true;assert(not shadow.available());mobile=false
  assert(attempts==n,'disabled/mobile shadows allocated GPU resources')
 end
 assert(shadow.texture());assert(dataReleased==1,'temporary image data retained')
 shadow.invalidate();assert(created==released,'invalidate retained GPU objects')
 assert(allocate(1024));failCanvas=true;assert(not allocate(2048))
 assert(created==released,'failed replacement retained old canvas')
 n=attempts;for i=1,60 do assert(not shadow.available())end
 assert(attempts==n,'failed canvas retried every frame')
 shadow.invalidate();failCanvas=false;assert(shadow.available(),'explicit invalidation must allow recovery')
 failImage=true;assert(not shadow.texture());assert(dataReleased==2,'upload failure retained image data')
 shadow.invalidate();assert(created==released)
 print('PASS '..prefix..'shadow: 600 stable frames, failure latch, explicit GPU cleanup, recovery')
end
