local V = ...
local Ground = {}
local ok, catalog = pcall(V.data, "arena_ground")
if not ok or type(catalog) ~= "table" then catalog = {} end

local function inside(polygon, x, y)
  local hit = false
  local j = #polygon
  for i = 1, #polygon do
    local a, b = polygon[i], polygon[j]
    if (a[2] > y) ~= (b[2] > y)
        and x < (b[1] - a[1]) * (y - a[2]) / (b[2] - a[2]) + a[1] then
      hit = not hit
    end
    j = i
  end
  return hit
end

-- Check the whole contact patch, including its edges. A centre pixel alone
-- can sit on the bank while the rest of a large actor stands in the river.
local function edgeCrossesPatch(a, b, x0, y0, x1, y1)
  local lo, hi = 0, 1
  for _, axis in ipairs({{a[1], b[1]-a[1], x0, x1},
                         {a[2], b[2]-a[2], y0, y1}}) do
    local origin, delta, low, high = unpack(axis)
    if math.abs(delta) < 1e-12 then
      if origin <= low or origin >= high then return false end
    else
      local p, q = (low-origin)/delta, (high-origin)/delta
      if p > q then p,q=q,p end
      lo,hi=math.max(lo,p),math.min(hi,q)
      if lo >= hi then return false end
    end
  end
  return lo < hi
end

function Ground.supports(regions, x, y, rx, ry)
  if not (x and y and rx and ry and rx >= 0 and ry >= 0) then return false end
  local x0,y0,x1,y1=x-rx,y-ry,x+rx,y+ry
  for _, polygon in ipairs(regions or {}) do
    local fits = inside(polygon,x0,y0) and inside(polygon,x1,y0)
      and inside(polygon,x0,y1) and inside(polygon,x1,y1)
    if fits then
      -- Corners alone can miss a thin inlet in a concave ground polygon.
      for i,a in ipairs(polygon) do
        if edgeCrossesPatch(a,polygon[i % #polygon+1],x0,y0,x1,y1) then
          fits=false;break
        end
      end
    end
    if fits then return true end
  end
  return false
end

-- Move an asymmetric footprint as a whole: a curled Onix can have its
-- contact centre well to one side of its model origin. Keep the measured
-- offset and prefer the smallest move inside the side's half of the stage.
function Ground.fit(regions, anchor, footprint, minX, maxX, maxY)
  local cx,cy=footprint[1]+footprint[3]*.5,footprint[2]+footprint[4]*.5
  local rx,ry=footprint[3]*.5+.004,footprint[4]*.5+.004
  if anchor.x >= minX and anchor.x <= maxX
      and (not maxY or anchor.y <= maxY)
      and Ground.supports(regions,cx,cy,rx,ry) then return anchor end
  local offsetX,offsetY=cx-anchor.x,cy-anchor.y
  local best,score
  for xi=math.ceil(minX*100),math.floor(maxX*100) do
    for yi=50,math.floor((maxY or .84)*100) do
      local x,y=xi/100,yi/100
      local cost=(x-anchor.x)^2+(y-anchor.y)^2
      if (not score or cost<score)
          and Ground.supports(regions,x+offsetX,y+offsetY,rx,ry) then
        best,score={x=x,y=y},cost
      end
    end
  end
  return best
end

function Ground.resolve(path, data, width, height)
  local spec = catalog[path]
  if not (spec and data and data.getString and love and love.data) then return nil end
  local hashOK, digest = pcall(function()
    return love.data.encode("string", "hex", love.data.hash("sha256", data:getString()))
  end)
  -- A replaced bitmap must never inherit an unrelated wall/water mask.
  if not hashOK or digest ~= spec.digest then return nil end
  local rx, ry = .055, .025
  local function ranked(left, right, targetX, targetY)
    local choices = {}
    for xi = left, right do
      for yi = 50, 84 do
        local x, y = xi / 100, yi / 100
        if Ground.supports(spec.regions, x, y, rx, ry) then
          local _, _, _, alpha = data:getPixel(
            math.min(width - 1, math.floor(x * width)),
            math.min(height - 1, math.floor(y * height)))
          if alpha and alpha >= .90 then
            choices[#choices + 1] = {x=x, y=y,
              score=math.abs(x-targetX)*1.7 + math.abs(y-targetY)*2}
          end
        end
      end
    end
    table.sort(choices, function(a,b)
      if a.score ~= b.score then return a.score < b.score end
      if a.x ~= b.x then return a.x < b.x end
      return a.y < b.y
    end)
    return choices
  end
  local players, enemies = ranked(30,49,.34,.62), ranked(54,80,.65,.58)
  local best, score, raised, raisedScore
  local function composition(p,e)
    return {player={x=p.x,y=p.y},enemy={x=e.x,y=e.y},
      trainerPlayer={x=p.x,y=p.y},trainerEnemy={x=e.x,y=e.y},
      source="reviewed-ground/v1",regions=spec.regions,
      contactRadiusX=rx,contactRadiusY=ry,digest=digest}
  end
  for _, p in ipairs(players) do
    for _, e in ipairs(enemies) do
      if e.x-p.x >= .27 then
        local candidate = p.score+e.score+math.abs((p.y-e.y)-.04)*.4
        if p.x <= .46 and e.x <= .74 and (not score or candidate < score) then
          score, best = candidate, composition(p,e)
        end
        -- Deep foreground marks can intersect the command dock even with an
        -- arbitrarily small actor. If the ordinary pair sits low, prefer a
        -- slightly more central pair higher on the SAME verified floor.
        -- Neither the contact radius nor the wall/water mask is relaxed.
        local dockScore = candidate
          + 100 * (math.max(0,p.y-.72) + math.max(0,e.y-.72))
        if not raisedScore or dockScore < raisedScore then
          raisedScore, raised = dockScore, composition(p,e)
        end
      end
    end
  end
  if best and best.player.y <= .72 and best.enemy.y <= .72 then return best end
  return raised or best
end
return Ground
