-- Observe committed levels without changing experience rewards or stat math.
local M={}
local previous=setmetatable({},{__mode='k'})
local pending=setmetatable({},{__mode='k'})
local installed=setmetatable({},{__mode='k'})
local keys={'hp','attack','defense','speed','special','spAttack','spDefense'}
local function snapshot(mon)
 local result={level=mon.level}
 for _,key in ipairs(keys)do result[key]=tonumber((mon.stats or {})[key])end
 return result
end
function M.install(mod)
 if installed[mod]then return true end
 if not(mod.events and type(mod.events.on)=='function')then return false end
 mod.events:on('battle.exp_gained',function(event)
  local mon=event and event.mon
  if mon then previous[mon]=snapshot(mon);pending[mon]=nil end
 end)
 mod.events:on('pokemon.level_up',function(event)
  local mon=event and event.mon
  if not mon then return end
  local before=previous[mon]
  pending[mon]=nil
  if before and tonumber(mon.level) and mon.level>(tonumber(before.level)or mon.level)then
   local gains={level=mon.level,stats=mon.stats}
   for _,key in ipairs(keys)do
    local value=tonumber((mon.stats or {})[key])
    if value and before[key]then gains[key]=value-before[key]end
   end
   pending[mon]=gains
  end
  previous[mon]=snapshot(mon)
 end)
 installed[mod]=true
 return true
end
-- Consume once when a StatBox is decorated, not once per draw. An unrelated
-- later stats/item window must never repeat an old battle's gains.
function M.take(mon)
 if not mon then return nil end
 local gains=pending[mon];pending[mon]=nil
 if gains and gains.level==mon.level and gains.stats==mon.stats then return gains end
end
return M
