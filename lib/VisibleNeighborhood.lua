-- Desktop residency ring: whole current map plus all direct connections.
-- Keep the engine's complete state and two-hop discovery data untouched.
local V=...
local N={}
N.setting=V.require('ModSetting').new('desktopNeighborRing','PC MAP RING',{true,false},{'ON','OFF'})
function N.apply(state)
 if not N.setting:get()or not(state and state.map and state.map.def)then return state end
 local keep={[state.map.id]=true};local con=state.map.def.connections
 if type(con)~='table'then return state end -- unknown custom-map topology
 for _,c in pairs(con)do if type(c)=='table'and c.map then keep[c.map]=true end end
 local neighbors,seen={},{}
 for _,nb in ipairs(state.neighbors or{})do
  local id=nb.map and nb.map.id
  if keep[id]and id~=state.map.id and not seen[id]then neighbors[#neighbors+1]=nb;seen[id]=true end
 end
 if #neighbors==#(state.neighbors or{})then return state end
 local out={};for k,v in pairs(state)do out[k]=v end;out.neighbors=neighbors
 return out
end
return N
