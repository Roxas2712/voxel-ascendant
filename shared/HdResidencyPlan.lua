-- Pure admission for complete, unchanged animation atlas pairs. The renderer
-- supplies only poses admitted by the world owner, before its first pass.
local M={BUDGET_BYTES=384*1024*1024}
local function integer(n,a,b)return type(n)=="number" and n==math.floor(n) and n>=a and n<=b end
function M.plan(actors,budget)
  if type(actors)~="table" or not integer(budget,1,512*1024*1024)then return nil,"invalid_plan"end
  local count=0
  for k in pairs(actors)do if not integer(k,1,256)then return nil,"invalid_actors"end;count=count+1 end
  local pairsByKey={}
  for n=1,count do
    local actor=actors[n]
    if type(actor)~="table" or type(actor.key)~="string" or #actor.key<1 or #actor.key>4096
      or not integer(actor.bytes,1,128*1024*1024)then return nil,"invalid_actor"end
    local priority=actor.context=="follower" and 0 or 1
    local distance=actor.distance
    if type(distance)~="number" or distance~=distance or distance<0 then distance=math.huge end
    local pair=pairsByKey[actor.key]
    if pair then
      if pair.bytes~=actor.bytes then return nil,"conflicting_pair"end
      if priority<pair.priority or priority==pair.priority and distance<pair.distance then
        pair.priority,pair.distance=priority,distance
      end
      pair.actors=pair.actors+1
    else
      pairsByKey[actor.key]={key=actor.key,bytes=actor.bytes,priority=priority,distance=distance,actors=1}
    end
  end
  local ordered={};for _,pair in pairs(pairsByKey)do ordered[#ordered+1]=pair end
  table.sort(ordered,function(a,b)
    if a.priority~=b.priority then return a.priority<b.priority end
    if a.distance~=b.distance then return a.distance<b.distance end
    return a.key<b.key
  end)
  local result={wanted={},orderedKeys={},bytes=0,requestedActors=count,admittedActors=0,rejectedActors=0,
    admittedPairs=0,budgetBytes=budget}
  for _,pair in ipairs(ordered)do
    if result.bytes+pair.bytes<=budget then
      result.wanted[pair.key]=true;result.bytes=result.bytes+pair.bytes
      result.orderedKeys[#result.orderedKeys+1]=pair.key
      result.admittedActors=result.admittedActors+pair.actors;result.admittedPairs=result.admittedPairs+1
    else result.rejectedActors=result.rejectedActors+pair.actors end
  end
  return result
end
return M
