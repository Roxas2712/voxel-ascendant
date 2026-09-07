-- Dedicated procedural Lugia rescue model.
--
-- Stadium 2 Dex 249 has repeatedly exposed a model-graph decode mismatch in
-- the current ROM importer.  Rather than keep changing the shared Stadium
-- decoder (and risk the other 250 species), this module gives Lugia an
-- isolated, always-3D fallback built from simple low-poly solids.  It uses
-- the same Voxel3D shader/depth/shadow path as StadiumRig, so it still lives
-- in the world, receives day/night tint, casts a real shadow, and participates
-- in the battle camera.  No Stadium ROM model data is touched here.
--
-- The public shape intentionally mirrors the tiny subset of StadiumRig that
-- StadiumMon calls: pose -> anchor -> skin -> textures, plus draw/caster and
-- attachment.  That lets StadiumMon keep all battle/overworld positioning,
-- send-out scaling, targeting, and camera logic unchanged.

local V = ...

local Voxel3D = V.require("Voxel3D")

local LugiaRescue = {}

local sin, cos, pi = math.sin, math.cos, math.pi
local max, min = math.max, math.min

local SHADE_BASE = 0.7725
local SHADE_X = 0.06
local SHADE_Y = 0.225
local SHADE_Z = 0.11

local sharedTextures = nil

local function clamp01(v)
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

local function solidTexture(r, g, b, a)
  if not (love and love.image and love.image.newImageData
      and love.graphics and love.graphics.newImage) then
    return nil
  end
  local data = love.image.newImageData(2, 2)
  for y = 0, 1 do
    for x = 0, 1 do data:setPixel(x, y, r, g, b, a or 1) end
  end
  local img = love.graphics.newImage(data)
  if img and img.setFilter then pcall(img.setFilter, img, "nearest", "nearest") end
  if img and img.setWrap then pcall(img.setWrap, img, "clamp", "clamp") end
  return img
end

local function textures()
  if sharedTextures then return sharedTextures end
  local ok, made = pcall(function()
    return {
      body = solidTexture(0.88, 0.93, 0.96, 1),
      belly = solidTexture(0.68, 0.82, 0.90, 1),
      blue = solidTexture(0.18, 0.28, 0.55, 1),
      eye = solidTexture(0.05, 0.07, 0.12, 1),
      iris = solidTexture(0.88, 0.20, 0.16, 1),
    }
  end)
  sharedTextures = ok and made or false
  return sharedTextures or nil
end

-- Unit low-poly sphere with normals.  The per-part transform turns it into
-- an ellipsoid/capsule; keeping one topology for every organic part makes the
-- rescue path small, deterministic, and driver-friendly.
local function sphereTemplate(rings, segs)
  local px, py, pz, nx, ny, nz, uv = {}, {}, {}, {}, {}, {}, {}
  local index = {}
  local n = 0
  for iy = 0, rings do
    local v = iy / rings
    local lat = -pi * 0.5 + pi * v
    local yy = sin(lat)
    local rr = cos(lat)
    for ix = 0, segs do
      local u = ix / segs
      local lon = u * pi * 2
      local xx = cos(lon) * rr
      local zz = sin(lon) * rr
      n = n + 1
      px[n], py[n], pz[n] = xx, yy, zz
      nx[n], ny[n], nz[n] = xx, yy, zz
      uv[n * 2 - 1], uv[n * 2] = u, 1 - v
    end
  end
  local row = segs + 1
  for iy = 0, rings - 1 do
    for ix = 0, segs - 1 do
      local a = iy * row + ix + 1
      local b = a + 1
      local c = a + row
      local d = c + 1
      index[#index + 1] = a
      index[#index + 1] = c
      index[#index + 1] = b
      index[#index + 1] = b
      index[#index + 1] = c
      index[#index + 1] = d
    end
  end
  return { px = px, py = py, pz = pz, nx = nx, ny = ny, nz = nz,
           uv = uv, index = index, count = n }
end

local TEMPLATE = nil
local function template()
  if not TEMPLATE then TEMPLATE = sphereTemplate(7, 10) end
  return TEMPLATE
end

local function rotateXYZ(x, y, z, rx, ry, rz)
  if rx and rx ~= 0 then
    local c, s = cos(rx), sin(rx)
    y, z = y * c - z * s, y * s + z * c
  end
  if ry and ry ~= 0 then
    local c, s = cos(ry), sin(ry)
    x, z = x * c + z * s, -x * s + z * c
  end
  if rz and rz ~= 0 then
    local c, s = cos(rz), sin(rz)
    x, y = x * c - y * s, x * s + y * c
  end
  return x, y, z
end

local function addPart(parts, name, material, cx, cy, cz, sx, sy, sz,
                       rx, ry, rz, group)
  parts[#parts + 1] = {
    name = name,
    material = material,
    cx = cx, cy = cy, cz = cz,
    sx = sx, sy = sy, sz = sz,
    rx = rx or 0, ry = ry or 0, rz = rz or 0,
    group = group,
  }
end

local function partLayout()
  local p = {}

  -- Torso / long neck / head / muzzle.  Unrotated Lugia faces +Z, the same
  -- convention StadiumMon documents for the ordinary Stadium models.
  addPart(p, "body",   "body",   0, 58,  -2, 43, 58, 31,  0, 0, 0, "body")
  addPart(p, "belly",  "belly",  0, 55,  25, 31, 44, 10, -0.05, 0, 0, "body")
  addPart(p, "neck",   "body",   0, 99,   7, 25, 41, 22, -0.12, 0, 0, "body")
  addPart(p, "head",   "body",   0, 132, 18, 30, 25, 28,  0, 0, 0, "head")
  addPart(p, "snout",  "body",   0, 126, 45, 17, 12, 24,  0.03, 0, 0, "head")

  -- Eyes and red irises sit on the side/front quarter of the head so they
  -- remain readable from both battle and overworld camera angles.
  addPart(p, "eyeL",   "eye",  -22, 136, 38, 4.6, 5.0, 2.3, 0, 0, 0, "head")
  addPart(p, "eyeR",   "eye",   22, 136, 38, 4.6, 5.0, 2.3, 0, 0, 0, "head")
  addPart(p, "irisL",  "iris", -22, 136, 40, 2.0, 2.3, 1.2, 0, 0, 0, "head")
  addPart(p, "irisR",  "iris",  22, 136, 40, 2.0, 2.3, 1.2, 0, 0, 0, "head")

  -- The broad hand-like wings are separate flattened ellipsoids.  Extra
  -- fingers at each tip make the silhouette much closer to Lugia than a
  -- generic bird wing while remaining robust procedural geometry.
  addPart(p, "wingL", "body", -66, 82,  1, 66, 13, 25, 0.00, 0, -0.12, "wingL")
  addPart(p, "wingR", "body",  66, 82,  1, 66, 13, 25, 0.00, 0,  0.12, "wingR")
  addPart(p, "lf1", "body", -122, 72,  10, 33, 7, 8, 0, 0.08, -0.30, "wingL")
  addPart(p, "lf2", "body", -120, 84,   0, 35, 7, 8, 0, 0.00, -0.08, "wingL")
  addPart(p, "lf3", "body", -114, 95, -10, 31, 7, 8, 0,-0.08,  0.16, "wingL")
  addPart(p, "rf1", "body",  122, 72,  10, 33, 7, 8, 0,-0.08,  0.30, "wingR")
  addPart(p, "rf2", "body",  120, 84,   0, 35, 7, 8, 0, 0.00,  0.08, "wingR")
  addPart(p, "rf3", "body",  114, 95, -10, 31, 7, 8, 0, 0.08, -0.16, "wingR")

  -- Tail and dorsal blue plates.
  addPart(p, "tail1", "body", 0, 34, -58, 19, 19, 58, -0.12, 0, 0, "tail")
  addPart(p, "tail2", "body", 0, 24,-104, 13, 13, 42, -0.24, 0, 0, "tail")
  addPart(p, "fin1", "blue", 0, 112, -19, 8, 16, 5, 0.28, 0, 0, "fin")
  addPart(p, "fin2", "blue", 0,  92, -28, 9, 17, 5, 0.34, 0, 0, "fin")
  addPart(p, "fin3", "blue", 0,  70, -34,10, 18, 5, 0.40, 0, 0, "fin")
  addPart(p, "fin4", "blue", 0,  49, -39,10, 17, 5, 0.46, 0, 0, "fin")
  addPart(p, "fin5", "blue", 0,  29, -47, 9, 15, 5, 0.50, 0, 0, "fin")

  -- Small feet/legs keep the grounded overworld pose from reading as a
  -- hovering torso when seen from third person.
  addPart(p, "legL", "blue", -16, 11,  8, 8, 16, 8, 0.05, 0, 0, "body")
  addPart(p, "legR", "blue",  16, 11,  8, 8, 16, 8, 0.05, 0, 0, "body")
  addPart(p, "footL", "blue", -16, -1, 18, 12, 6, 16, 0, 0, 0, "body")
  addPart(p, "footR", "blue",  16, -1, 18, 12, 6, 16, 0, 0, 0, "body")

  return p
end

local Rig = {}
Rig.__index = Rig

local function buildMesh()
  local t = template()
  local rows = {}
  for i = 1, t.count do
    rows[i] = { 0, 0, 0, t.uv[i * 2 - 1], t.uv[i * 2], 1 }
  end
  local ok, mesh = pcall(love.graphics.newMesh, Voxel3D.FORMAT, rows,
                         "triangles", "dynamic")
  if not ok or not mesh then return nil end
  pcall(mesh.setVertexMap, mesh, t.index)
  return mesh, rows
end

function Rig.new(model)
  if not (love and love.graphics and love.graphics.newMesh) then return nil end
  local tex = textures()
  if not tex then return nil end

  local self = setmetatable({
    model = model,
    parts = {},
    frameAt = 0,
    anim = 1,
    frame = 0,
    rootRx = 0, rootRy = 0, rootRz = 0,
    rootX = 0, rootY = 0, rootZ = 0,
    wing = 0,
    head = 0,
    tail = 0,
  }, Rig)

  for _, def in ipairs(partLayout()) do
    local mesh, rows = buildMesh()
    if not mesh then
      self:release()
      return nil
    end
    self.parts[#self.parts + 1] = {
      def = def, mesh = mesh, rows = rows,
      texture = tex[def.material] or tex.body,
    }
  end

  self:pose(1, 0, true)
  self:skin(0)
  return self
end

function Rig:release()
  for _, part in ipairs(self.parts or {}) do
    if part.mesh and part.mesh.release then pcall(part.mesh.release, part.mesh) end
  end
  self.parts = {}
end

-- Five simple procedural motions.  They are intentionally conservative: the
-- goal of this rescue path is a stable 3D Lugia first, while still giving the
-- battle system visible idle/attack/hit/faint motion instead of a frozen prop.
function Rig:pose(anim, frame, wrap)
  anim = tonumber(anim) or 1
  frame = tonumber(frame) or 0
  self.anim, self.frame, self.frameAt = anim, frame, math.floor(frame)

  self.rootRx, self.rootRy, self.rootRz = 0, 0, 0
  self.rootX, self.rootY, self.rootZ = 0, 0, 0
  self.wing, self.head, self.tail = 0, 0, 0

  if anim == 1 then
    self.wing = sin(frame * 0.11) * 0.16
    self.head = sin(frame * 0.055) * 0.045
    self.tail = sin(frame * 0.07) * 0.07
  elseif anim == 2 then
    local p = clamp01(frame / 24)
    self.wing = (1 - p) * 0.48 + sin(p * pi) * 0.18
    self.rootY = sin(p * pi) * 7
    self.head = -0.12 * (1 - p)
  elseif anim == 3 then
    local p = clamp01(frame / 30)
    local hit = sin(p * pi)
    self.wing = hit * 0.58
    self.head = -hit * 0.18
    self.rootZ = hit * 18
    self.rootY = hit * 3
  elseif anim == 4 then
    local p = clamp01(frame / 18)
    local hit = sin(p * pi)
    self.rootZ = -hit * 10
    self.rootRy = hit * 0.16
    self.wing = -hit * 0.18
  elseif anim == 5 then
    local p = clamp01(frame / 45)
    self.rootRx = -1.18 * p
    self.rootY = -34 * p
    self.rootZ = -8 * p
    self.wing = -0.42 * p
    self.head = 0.18 * p
  end
end

function Rig:anchor(limit, dt)
  -- The rescue motions are already authored within a fraction of one body
  -- length, so there is nothing to re-center here.
  return true
end

local function posedRotation(self, def)
  local rx, ry, rz = def.rx, def.ry, def.rz
  if def.group == "wingL" then rz = rz - self.wing
  elseif def.group == "wingR" then rz = rz + self.wing
  elseif def.group == "head" then rx = rx + self.head
  elseif def.group == "tail" then ry = ry + self.tail end
  return rx, ry, rz
end

local function rootPoint(self, x, y, z)
  -- Rotate the whole rescue pose about the torso centre so faint/hit motions
  -- keep the body coherent rather than orbiting around world origin.
  local ox, oy, oz = 0, 62, 0
  x, y, z = x - ox, y - oy, z - oz
  x, y, z = rotateXYZ(x, y, z, self.rootRx, self.rootRy, self.rootRz)
  return x + ox + self.rootX, y + oy + self.rootY, z + oz + self.rootZ
end

function Rig:skin(yaw)
  local t = template()
  local cy, sy = cos(yaw or 0), sin(yaw or 0)

  for _, part in ipairs(self.parts) do
    local def, rows = part.def, part.rows
    local rx, ry, rz = posedRotation(self, def)
    local cx, cy0, cz = rootPoint(self, def.cx, def.cy, def.cz)

    for i = 1, t.count do
      local x = t.px[i] * def.sx
      local y = t.py[i] * def.sy
      local z = t.pz[i] * def.sz
      x, y, z = rotateXYZ(x, y, z, rx, ry, rz)
      x, y, z = rootPoint(self, x + def.cx, y + def.cy, z + def.cz)

      local nx, ny, nz = rotateXYZ(t.nx[i], t.ny[i], t.nz[i], rx, ry, rz)
      nx, ny, nz = rotateXYZ(nx, ny, nz, self.rootRx, self.rootRy, self.rootRz)
      local wx = cy * nx + sy * nz
      local wz = cy * nz - sy * nx

      local row = rows[i]
      row[1], row[2], row[3] = x, y, z
      row[6] = SHADE_BASE + SHADE_X * wx + SHADE_Y * ny + SHADE_Z * wz
    end
    pcall(part.mesh.setVertices, part.mesh, rows)
  end
  return true
end

function Rig:textures(aux)
  return true
end

function Rig:attachment(bone)
  -- Effects prefer 0x0A/0x64 as a mouth/body anchor.  Return the front of
  -- the muzzle in the current root pose.
  return rootPoint(self, 0, 128, 67)
end

function Rig:draw(matrix, pull)
  Voxel3D.seams(false)
  Voxel3D.glass(false)
  Voxel3D.blend(nil)
  for _, part in ipairs(self.parts) do
    if part.mesh and part.texture then
      Voxel3D.draw(part.mesh, part.texture, matrix, pull)
    end
  end
  Voxel3D.blend(nil)
  Voxel3D.glass(true)
  Voxel3D.seams(true)
end

function Rig:caster(shadowMap, matrix)
  if not (shadowMap and shadowMap.draw) then return end
  for _, part in ipairs(self.parts) do
    if part.mesh and part.texture then
      shadowMap.draw(part.mesh, part.texture, matrix)
    end
  end
end

local function rescueModel()
  local StadiumPack = V.require("StadiumPack")
  local ctx = {}
  for i = 1, #(StadiumPack.CONTEXT or {}) do ctx[i] = StadiumPack.NONE end

  local function put(name, zeroBased)
    local slot = StadiumPack.SLOT and StadiumPack.SLOT[name]
    if slot then ctx[slot] = zeroBased end
  end
  put("idle", 0)
  put("entrance", 1)
  put("attack_default", 2)
  put("faint", 4)

  local moveAnim, moveAux = {}, {}
  for i = 1, (StadiumPack.N_MOVES or 165) do
    moveAnim[i] = 2 -- zero-based -> rescue attack animation #3
    moveAux[i] = -1
  end

  return {
    species = 249,
    rescue = true,
    rootScale = 1,
    height = 174,
    radius = 137,
    floor = -7,
    staticPose = false,
    ctx = ctx,
    moveAnim = moveAnim,
    moveAux = moveAux,
    auxAnims = {},
    attachments = {
      { tag = 0x0A, bone = 1 },
      { tag = 0x64, bone = 1 },
    },
    anims = {
      { frames = 120, seconds = 4.0, loopStart = 0 },
      { frames = 24,  seconds = 0.8, loopStart = 0 },
      { frames = 30,  seconds = 1.0, loopStart = 0 },
      { frames = 18,  seconds = 0.6, loopStart = 0 },
      { frames = 45,  seconds = 1.5, loopStart = 0 },
    },
  }
end

-- Returns model, rig or nil.  Kept as one call so StadiumMon can switch Lugia
-- atomically without ever touching StadiumPack.load(249).
function LugiaRescue.create()
  local model = rescueModel()
  local ok, rig = pcall(Rig.new, model)
  if not ok or not rig then return nil end
  return model, rig
end

return LugiaRescue
