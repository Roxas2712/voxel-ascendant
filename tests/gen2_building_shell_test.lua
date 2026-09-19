-- Compare analytical occupancy with the independent dense fallback, including
-- exact quad order, UVs, shading, voxel/shell counts and cooperative yields.
local root = assert(arg[1])
local ticks = 0
local B = assert(loadfile(root .. '/gen2/lib/Buildings.lua'))({require=function(name)
  assert(name=='BuildBudget')
  local function tick() ticks=ticks+1;if ticks%31==0 then coroutine.yield() end end
  return {tick=tick,check=tick}
end})
local function up(fn,key)
  for i=1,100 do local n,v=debug.getupvalue(fn,i);if n==key then return v end end
  error('missing '..key)
end
local model,emit=up(B.build,'model'),up(B.build,'emit')
local function same(a,b)
  assert(type(a)==type(b))
  if type(a)~='table' then assert(a==b);return end
  for k,v in pairs(a)do same(v,b[k])end
  for k in pairs(b)do assert(a[k]~=nil)end
end
local function run(fn)
  local co=coroutine.create(fn);local value
  repeat local ok,v=coroutine.resume(co);assert(ok,v);value=v until coroutine.status(co)=='dead'
  return value
end
for variant=1,24 do
 local W,H=16,14
 local sp={W=W,H=H,inside={},ax={},ay={}}
 local pr={D=variant%7+1,ytop=13,ground=14,top={},recess={},interior={},shadeTexel={[2]=0,[3]=1}}
 if variant%2==0 then pr.rear={} end
 for x=0,W-1 do pr.top[x]=(x+variant)%5 end
 for y=0,H-1 do for x=0,W-1 do
  local i=y*W+x
  sp.inside[i]=(x+y+variant)%11~=0
  sp.ax[i],sp.ay[i]=x,y
  pr.interior[i]=i
  pr.recess[i]=(x+y)%4==0
  if pr.rear then pr.rear[i]=i end
 end end
 local t={slab=variant%3+1,roofRows=4,roofBack=1,roofFront=1,roofCycle={1,2},frontEave=variant%3}
 if variant%3==0 then t.ledge={7,9} end
 if variant%4==0 then t.roofFlankPeriod=2 end
 local m=model(sp,pr,t)
 local fast=run(function()return emit(m,sp,128,128)end)
 -- Dense fallback obtains occupancy only from the original material lookup.
 m.ranges=nil
 local dense=run(function()return emit(m,sp,128,128)end)
 same(dense,fast)
end
assert(ticks>31)
print('PASS Gen2 building shell: 24 dense/analytical cases with exact geometry and yielding')
