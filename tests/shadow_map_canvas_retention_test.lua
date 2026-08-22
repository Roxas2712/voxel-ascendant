-- Repeated availability checks must never resize an already-fitted shadow
-- canvas. The old path re-probed SIZES[1] every frame, so a 2048 view released
-- to 1024 here and begin() allocated back to 2048 immediately afterwards.

local runnerLove = rawget(_G, "love")
local allocations, releases = 0, 0

love = {
  graphics = {},
  image = {},
  event = runnerLove and runnerLove.event or nil,
}

local shader = { send = function() end }
function love.graphics.newShader() return shader end
function love.graphics.newCanvas() end -- capability marker only
function love.graphics.setDepthMode() end
function love.graphics.setMeshCullMode() end
function love.graphics.setCanvas() end
function love.graphics.getBlendMode() return "alpha", "alphamultiply" end
function love.graphics.setBlendMode() end
function love.graphics.clear() end
function love.graphics.setShader() end
function love.graphics.setColor() end

local PixelCanvas = {}
function PixelCanvas.new(w, h)
  allocations = allocations + 1
  local canvas = { w = w, h = h, released = false }
  function canvas:setFilter() end
  function canvas:setWrap() end
  function canvas:release()
    if self.released then error("shadow canvas released twice") end
    self.released = true
    releases = releases + 1
  end
  return true, canvas
end

local cache = {}
local V = {}
function V.require(name)
  if cache[name] then return cache[name] end
  if name == "Mat4" then
    cache[name] = assert(loadfile("lib/Mat4.lua"))(V)
  elseif name == "VoxelState" then
    cache[name] = { angle = 0, FOCAL = 1 }
  elseif name == "PixelCanvas" then
    cache[name] = PixelCanvas
  else
    error("unexpected dependency " .. tostring(name))
  end
  return cache[name]
end

local ShadowMap = assert(loadfile("lib/ShadowMap.lua"))(V)
ShadowMap.SIZES = { 16, 32, 64 }
ShadowMap.TARGET = 0.0001 -- force the fitted view onto the largest rung

local function expect(ok, message)
  if not ok then error(message, 2) end
end

expect(ShadowMap.available(), "initial capability probe failed")
expect(allocations == 1 and releases == 0,
       "initial availability did not allocate exactly the probe rung")
expect(ShadowMap.begin(0, 0, 320, 240), "fitted shadow pass did not begin")
expect(ShadowMap.res == 64 and allocations == 2 and releases == 1,
       "begin did not replace the one-time probe with the fitted rung")
ShadowMap.finish("stable")
local fitted = ShadowMap.texture()
expect(fitted and fitted.w == 64 and not fitted.released,
       "fitted shadow canvas was not retained")
expect(not ShadowMap.stale("stable"), "fresh signature started stale")

for _ = 1, 120 do
  expect(ShadowMap.available(), "availability changed after fitted begin")
end
expect(allocations == 2 and releases == 1,
       "repeated availability resized the live shadow canvas")
expect(ShadowMap.texture() == fitted and not fitted.released,
       "availability discarded the fitted canvas")
expect(not ShadowMap.stale("stable"),
       "availability invalidated an unchanged shadow signature")

love = runnerLove
print("shadow map canvas retention: fitted rung survived 120 availability checks")
