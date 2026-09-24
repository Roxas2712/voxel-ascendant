-- Coarse anomaly signals, not a proof that every surface is correct.
-- Stores two small summaries, never screenshots or unbounded frame history.
local M={}
function M.observe(state,image)
 local prev=state.previous
 if prev then
  local delta=image.mean-prev.mean
  if state.previousDelta and math.abs(delta)>.10 and math.abs(state.previousDelta)>.10 and delta*state.previousDelta<0 then state.flickers=state.flickers+1 end
  if prev.groundOpaque-image.groundOpaque>.12 or image.groundBlack-prev.groundBlack>.22 then state.losses=state.losses+1 end
  state.previousDelta=delta
 end
 state.previous=image
end
function M.compare(a,b)
 return a and b and (a.groundOpaque-b.groundOpaque>.12 or b.groundBlack-a.groundBlack>.22)or false
end
return M
