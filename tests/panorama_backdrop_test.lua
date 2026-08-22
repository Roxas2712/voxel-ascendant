local function eq(a, b, label)
  if a ~= b then error((label or "value") .. ": expected " .. tostring(b)
                       .. ", got " .. tostring(a), 2) end
end

local builtVerts, builtIndices, drawCall
local renderEvents = {}
local drawFails = false
local loadCalls = 0
local released = { data = 0, image = 0, mesh = 0 }
local dimensions = { 1024, 192 }
local data = {
  getDimensions = function() return dimensions[1], dimensions[2] end,
  release = function() released.data = released.data + 1 end,
}
local image = {
  setFilter = function(_, min, mag) eq(min, "nearest"); eq(mag, "nearest") end,
  setWrap = function(_, x, y) eq(x, "clamp"); eq(y, "clamp") end,
  release = function() released.image = released.image + 1 end,
}
local mesh = { release = function() released.mesh = released.mesh + 1 end }

love = { graphics = {
  newImage = function(value) eq(value, data); return image end,
  setDepthMode = function(mode, writes)
    renderEvents[#renderEvents + 1] = { "depth", mode, writes }
  end,
} }
package.loaded["src.render.Assets"] = { imageData = function()
  loadCalls = loadCalls + 1
  return data
end }

local voxel3d = {
  pushQuad = function(indices, n)
    local b = n * 4
    for _, value in ipairs({ b + 1, b + 2, b + 3,
                             b + 1, b + 3, b + 4 }) do
      indices[#indices + 1] = value
    end
  end,
  newMesh = function(verts, indices)
    builtVerts, builtIndices = verts, indices
    return mesh
  end,
  draw = function(gotMesh, gotTexture, model)
    renderEvents[#renderEvents + 1] = { "draw" }
    if drawFails then error("synthetic draw failure") end
    drawCall = { gotMesh, gotTexture, model }
  end,
}
local mat4 = { translate = function(x, y, z) return { x, y, z } end }
local V = {
  path = "/virtual/VOXEL_ASCENDANT",
  require = function(name)
    if name == "Voxel3D" then return voxel3d end
    if name == "Mat4" then return mat4 end
    error("unexpected module " .. tostring(name))
  end,
}

local Panorama = assert(loadfile("lib/PanoramaBackdrop.lua"))(V)
eq(loadCalls, 0, "module load decoded the panorama eagerly")
eq(Panorama.RADIUS, 900, "radius")
eq(Panorama.SEGMENTS, 64, "segments")
eq(Panorama.BOTTOM, -120, "bottom")
eq(Panorama.TOP, 300, "top")
eq(Panorama.prepare(), true, "prepare")
eq(loadCalls, 1, "first outdoor prepare load count")
eq(#builtVerts, 256, "vertex budget")
eq(#builtIndices, 384, "index budget")
eq(released.data, 1, "ImageData release")
eq(builtVerts[1][5], 0, "top v")
eq(builtVerts[3][5], 1, "bottom v")
eq(builtVerts[2][4], 0, "first u")
eq(builtVerts[#builtVerts][4], 1, "last u")
eq(Panorama.prepare(), true, "cached prepare")
eq(loadCalls, 1, "cached prepare reloaded the asset")
eq(Panorama.drawAt(12, 3, 34), true, "draw")
eq(#renderEvents, 3, "background depth event count")
eq(renderEvents[1][1], "depth", "background depth first event")
eq(renderEvents[1][2], "lequal", "background depth test")
eq(renderEvents[1][3], false, "background depth writes")
eq(renderEvents[2][1], "draw", "background draw order")
eq(renderEvents[3][1], "depth", "background restore event")
eq(renderEvents[3][2], "lequal", "background restore test")
eq(renderEvents[3][3], true, "background restore writes")
eq(drawCall[1], mesh, "draw mesh")
eq(drawCall[2], image, "draw texture")
eq(drawCall[3][1], 12, "draw x")
eq(drawCall[3][2], 3, "draw y")
eq(drawCall[3][3], 34, "draw z")

renderEvents = {}
drawFails = true
eq(Panorama.drawAt(0, 0, 0), false, "failed draw result")
eq(#renderEvents, 3, "failed draw restored depth")
eq(renderEvents[3][1], "depth", "failed draw restore event")
eq(renderEvents[3][3], true, "failed draw restore writes")
drawFails = false

renderEvents = {}
local savedDepthMode = love.graphics.setDepthMode
love.graphics.setDepthMode = nil
eq(Panorama.drawAt(0, 0, 0), false, "missing depth API fails closed")
eq(#renderEvents, 0, "missing depth API did not draw")
love.graphics.setDepthMode = savedDepthMode

eq(Panorama.setEnabled(false), false, "disable state")
eq(released.image, 1, "disabled image release")
eq(released.mesh, 1, "disabled mesh release")
eq(Panorama.prepare(), false, "disabled prepare")
eq(loadCalls, 1, "disabled prepare decoded asset")
eq(Panorama.setEnabled(true), true, "reenable state")
eq(Panorama.prepare(), true, "lazy reload after reenable")
eq(loadCalls, 2, "reenable did not wait for prepare")

Panorama.invalidate()
eq(released.image, 2, "image invalidate")
eq(released.mesh, 2, "mesh invalidate")
eq(Panorama.ready(), false, "invalidated ready")

dimensions = { 2048, 192 }
eq(Panorama.prepare(), false, "malformed size")
eq(Panorama.prepare(), false, "malformed cached failure")
eq(Panorama.drawAt(0, 0, 0), false, "no malformed draw")
eq(released.data, 3, "bad ImageData release")
eq(released.image, 2, "no bad image")

local sceneFile = assert(io.open("lib/VoxelScene.lua", "rb"))
local scene = sceneFile:read("*a"); sceneFile:close()
local battleFile = assert(io.open("lib/BattleScene.lua", "rb"))
local battle = battleFile:read("*a"); battleFile:close()
assert(scene:find('V.require%("PanoramaBackdrop"%)'))
assert(scene:find('PanoramaBackdrop.setEnabled%(sceneryEnabled%)'))
assert(scene:find('PanoramaBackdrop.drawAt%('),
       "overworld must use the shared depth-safe panorama draw")
assert(battle:find('V.require%("PanoramaBackdrop"%)'))
assert(battle:find('not discs and outdoor'))
assert(battle:find('PanoramaBackdrop.setEnabled%(sceneryEnabled%)'))
assert(battle:find('PanoramaBackdrop.drawAt%('),
       "MAP battles must use the shared depth-safe panorama draw")

print("panorama backdrop: ok")
