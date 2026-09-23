-- Four recent scene descriptions, not an ever-growing per-map cache. A warm
-- lookup compares live values without rebuilding/sorting map lists or strings.
-- Do not key by state/neighbor table identity: draw plans are freshly allocated
-- and the engine can edit an existing neighbor entry in place.
local Cache = {}
function Cache.new(build, describe)
  local entries = {}
  local C = {}
  local function matchesMap(saved, map, ox, oy)
    if not saved or saved.map ~= map or saved.id ~= map.id
        or saved.width ~= map.def.width or saved.height ~= map.def.height
        or saved.ox ~= ox or saved.oy ~= oy then return false end
    local class, material, interior = describe(map)
    return saved.class == class and saved.material == material
      and saved.interior == interior
  end
  local function snapshot(map, ox, oy)
    local class, material, interior = describe(map)
    return {map=map, id=map.id, width=map.def.width, height=map.def.height,
      ox=ox, oy=oy, class=class, material=material, interior=interior}
  end
  local function matches(entry, state, revision, ...)
    if entry.worldMaps ~= state.worldMaps or entry.revision ~= revision
        or entry.optionCount ~= select('#', ...) then return false end
    for i=1,entry.optionCount do
      if entry.options[i] ~= select(i, ...) then return false end
    end
    if not matchesMap(entry.source[1], state.map, 0, 0) then return false end
    local n=1
    for _,nb in ipairs(state.neighbors or {}) do
      if nb.map then
        n=n+1
        if not matchesMap(entry.source[n], nb.map, nb.ox or 0, nb.oy or 0) then
          return false
        end
      end
    end
    return n == #entry.source
  end
  function C.get(state, revision, ...)
    for i,entry in ipairs(entries) do
      if matches(entry, state, revision, ...) then
        if i>1 then table.remove(entries,i);table.insert(entries,1,entry) end
        return unpack(entry.result,1,6)
      end
    end
    local source={snapshot(state.map,0,0)}
    for _,nb in ipairs(state.neighbors or {}) do
      if nb.map then source[#source+1]=snapshot(nb.map,nb.ox or 0,nb.oy or 0) end
    end
    local entry={source=source,worldMaps=state.worldMaps,revision=revision,
      options={...},optionCount=select('#',...),result={build(state)}}
    table.insert(entries,1,entry)
    entries[5]=nil
    return unpack(entry.result,1,6)
  end
  function C.clear() entries={} end
  return C
end
return Cache
