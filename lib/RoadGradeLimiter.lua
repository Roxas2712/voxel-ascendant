-- Spread unauthored terrain cliffs along connected walking ground. Native
-- jumps, doors and connection edges are fixed datums, not smoothing inputs.
local V = ...
local Budget = V.require("BuildBudget")
local M = {}
local directions = {{1,0},{-1,0},{0,1},{0,-1}}

function M.apply(map, values, width, height, step, walkable, water, protected)
  -- Most maps need no repair. Avoid graph/envelope allocation for them;
  -- this work runs only while building a cached elevation snapshot.
  local steep = false
  for y = 0, height - 1 do
    Budget.check()
    for x = 0, width - 1 do
      local k = y * width + x
      for i = 1,3,2 do
        local d = directions[i]
        local nx,ny = x+d[1],y+d[2]
        if nx < width and ny < height
           and math.abs((values[k] or 0)-(values[ny*width+nx] or 0)) > step*2
           and walkable(x,y) and walkable(nx,ny)
           and not water(x,y) and not water(nx,ny) then
          steep = true; break
        end
      end
      if steep then break end
    end
    if steep then break end
  end
  if not steep then return false end
  local nodes, original, anchors, edges = {}, {}, {}, {}
  for y = 0, height - 1 do
    Budget.check()
    for x = 0, width - 1 do
      if walkable(x,y) and not water(x,y) then
        local k = y * width + x
        nodes[#nodes+1], original[k] = k, values[k] or 0
        anchors[k] = protected[k] or x == 0 or y == 0
          or x == width-1 or y == height-1
          or (type(map.isWarpTileCell) == "function" and map:isWarpTileCell(x,y))
      end
    end
  end
  for _, k in ipairs(nodes) do
    Budget.tick()
    local x,y = k % width, math.floor(k / width)
    local neighbours = {}
    for _, d in ipairs(directions) do
      local nx,ny = x+d[1],y+d[2]
      local nk = ny * width + nx
      if nx >= 0 and nx < width and ny >= 0 and ny < height
         and original[nk] ~= nil then
        local delta = math.abs(original[k]-original[nk])
        -- Existing short, two-course slopes beside nested native jumps may
        -- be required by their fixed endpoints. Keep their existing grade.
        -- Larger contour discontinuities instead get one course per cell.
        local cap = delta > step*2 and step or math.max(step,delta)
        neighbours[#neighbours+1] = {nk,cap}
      end
    end
    edges[k] = neighbours
  end

  local function envelope(lower)
    local result, queue, queued = {}, {}, {}
    for _, k in ipairs(nodes) do
      if not lower or anchors[k] then
        result[k] = original[k]
        queue[#queue+1], queued[k] = k, true
      end
    end
    local head = 1
    while head <= #queue do
      Budget.tick()
      local k = queue[head]
      head, queued[k] = head+1, nil
      for _, edge in ipairs(edges[k]) do
        local nk,cap = edge[1],edge[2]
        local candidate = result[k] + (lower and -cap or cap)
        if result[nk] == nil or (lower and candidate > result[nk])
           or (not lower and candidate < result[nk]) then
          result[nk] = candidate
          if not queued[nk] then queue[#queue+1],queued[nk] = nk,true end
        end
      end
    end
    return result
  end
  local lower,upper = envelope(true),envelope(false)
  -- Never move a native datum to satisfy an impossible custom-map constraint.
  -- Both envelopes obey the edge bounds; their maximum does too, provided
  -- the fixed datums are mutually consistent.
  for _, k in ipairs(nodes) do
    if anchors[k] and math.max(lower[k] or -math.huge,upper[k]) ~= original[k] then
      return false
    end
  end
  local changed = false
  for _, k in ipairs(nodes) do
    local v = math.max(lower[k] or -math.huge,upper[k])
    if v ~= original[k] then values[k],changed = v,true end
  end
  return changed
end

return M
