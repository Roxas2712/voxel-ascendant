-- Mobile terrain visibility is independent of optional scenery promotion.
local P = {}

local function direct(state, id)
  for _, c in pairs(state.map.def.connections or {}) do
    if c.map == id then return true end
  end
  return false
end

function P.handoff(state, ...)
  for n = 1, select('#', ...) do
    local old = select(n, ...)
    if old and old.worldMaps == state.worldMaps and direct(old, state.map.id) then
      local origin
      for _, nb in ipairs(old.neighbors or {}) do
        if nb.map == state.map then origin = nb; break end
      end
      if origin then
        local entries = { [old.map.id] = { map=old.map, ox=0, oy=0 } }
        for _, nb in ipairs(old.neighbors or {}) do entries[nb.map.id] = nb end
        local admitted = {}
        for _, nb in ipairs(state.neighbors or {}) do
          local prev = entries[nb.map.id]
          if direct(state, nb.map.id) and prev and prev.map == nb.map
              and prev.ox - origin.ox == nb.ox
              and prev.oy - origin.oy == nb.oy then
            admitted[nb.map.id] = true
          end
        end
        return admitted
      end
    end
  end
  return {}
end

function P.bodies(state, meshes, waters, prepared)
  local out = { state={map=state.map, neighbors={}, worldMaps=state.worldMaps},
    maps={[state.map.id]=true}, meshes={}, waters={},
    horizonFallback=true, mobileCoreBootstrap=true, mobileTerrainOnly=true }
  for i, nb in ipairs(state.neighbors or {}) do
    if direct(state, nb.map.id) and meshes[i] and prepared(nb.map) then
      local j = #out.meshes + 1
      out.state.neighbors[j] = nb
      out.meshes[j], out.waters[j] = meshes[i], waters[i]
      out.maps[nb.map.id] = true
    end
  end
  return out
end

function P.covers(rich, terrain)
  if rich.state.map ~= terrain.state.map then return false end
  for id in pairs(terrain.maps) do if not rich.maps[id] then return false end end
  return true
end

return P
