-- A cold spawn immediately beside a connection can reach its neighbour
-- before the ordinary background queue finishes. Include that one imminent
-- destination in initial preparation, using the existing asynchronous jobs.
-- Once a map has opened, this module never closes it or delays movement.
local V=...
local M={}
local opened=setmetatable({},{__mode='k'})
local Chunk=V.require('ChunkMesher')
local Horizon=V.require('HorizonWall')

function M.pending(state,index,distance,plan)
 local map=state and state.map
 if not map or opened[map] or not index or not distance
    or distance<0 or distance>4 then return false end
 local nb=state.neighbors and state.neighbors[index]
 if not(nb and nb.map) or (plan and plan.maps and plan.maps[nb.map.id])then return false end
 -- Unknown/failing resource owners keep their existing fallback. Never
 -- wait on an absent job or a failed horizon just because its mesh is nil.
 if type(Chunk.building)~='function' then return false end
 if Chunk.building(nb.map,true) then return true end
 if not Chunk.ready(nb.map,true) or not Chunk.auxReady(nb.map) then return false end
 local _,ready,failed=Horizon.meshes({map=map,neighbors={nb},worldMaps=state.worldMaps})
 return not ready and not failed
end

function M.open(map)
 if map then opened[map]=true end
end
return M
