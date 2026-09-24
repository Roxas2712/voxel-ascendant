local now=0
love={timer={getTime=function()return now end}}
local writes,records,last=0,0,nil
local D=assert(loadfile('lib/MobileVoxelDiagnostic.lua'))({})
D.setLogger({write=function()records=records+1;return true end,
  writeMobileRecoveryMarker=function(marker)writes=writes+1;last=marker;return true end})
local base=writes
for frame=1,600 do
  now=frame/60
  for k=1,20 do
    D.checkpoint('repro-'..k..'-start',{})
    D.checkpoint('repro-'..k..'-ready',{})
  end
end
local used=writes-base
assert(used<=62,'global ten-second budget exceeded: '..used)
assert(not last.checkpoint:find('start',1,true),'completed calls left crash marker')
-- A brand new dangerous operation still persists before the operation runs.
D.checkpoint('new-driver-operation-start',{})
assert(last.checkpoint=='new-driver-operation-start')
D.checkpoint('new-driver-operation-ready',{})
assert(last.checkpoint=='new-driver-operation-ready')
-- Retry a failed terminal write, even though its repeated key is throttled.
local fail=true
D.setLogger({write=function()return true end,writeMobileRecoveryMarker=function(m)
  if m.checkpoint=='new-driver-operation-ready' and fail then fail=false;return false end
  last=m;return true
end})
now=now+2
D.checkpoint('new-driver-operation-start',{})
D.checkpoint('new-driver-operation-ready',{})
D.checkpoint('new-driver-operation-ready',{})
assert(last.checkpoint=='new-driver-operation-ready')
print('PASS global diagnostic budget: '..used..' writes / 600 frames / 20 checkpoint pairs; terminal and retry receipts intact')
