-- Only record changes in the actual world-canvas outcome. The older mobile
-- checkpoint deduplication omitted repeated desktop map warmups entirely.
-- This trace neither changes readiness nor substitutes an old map's image.
local Trace={}
local mapId,mode,pendingAt,pendingFrames
function Trace.observe(diagnostics,id,canvas,reason,clock,cover)
 local nextMode=cover and 'HOLD' or canvas and '3D' or '2D'
 if id==mapId and nextMode==mode then
  if nextMode~='3D' then pendingFrames=(pendingFrames or 0)+1 end
  return false
 end
 local stamp=clock and clock() or 0
 local recovery=id==mapId and mode~='3D' and nextMode=='3D'
 local fields={mapId=id,mode=nextMode,phase='world-canvas-result',
  reason=cover or (canvas and 'canvas-produced') or reason or 'canvas-missing',
  frames=recovery and pendingFrames or nil,
  elapsed=recovery and pendingAt and math.max(0,(stamp-pendingAt)*1000)or nil}
 mapId,mode=id,nextMode
 pendingAt,pendingFrames=nextMode~='3D' and stamp or nil,nextMode~='3D' and 1 or nil
 if diagnostics and type(diagnostics.write)=='function'then
  pcall(diagnostics.write,'vasc.performance.world-canvas',fields)
 end
 return true
end
return Trace
