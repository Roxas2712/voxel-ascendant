-- Original voxel-character renderer for Ascendant Pokemon Overworld.
--
-- Standalone uses a silhouette-preserving relief in the native 2D pipeline.
-- When VASC is present, its public VoxelScene/Voxel3D facade is used to swap
-- the flat character card for a real depth-bearing mesh made from the active
-- sprite frame.  Game/KASC/JASC remain authoritative for identity and pose.

local VoxelCharacters = {}
VoxelCharacters.__index = VoxelCharacters

local PATCH_KEY = "__ascendantPokemonVoxelCharacters"

local function invoke(method, owner, ...)
  if type(method) ~= "function" then return nil end
  local ok, value = pcall(method, owner, ...)
  if not ok or value == nil then ok, value = pcall(method, ...) end
  return ok and value or nil
end

local function findMod(mod, id)
  return invoke(mod and mod.find, mod, id)
end

local function walker(def)
  return type(def) == "table" and def.walker == true
end

local function option(mod, key, fallback)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  return value == true
end

local function choice(mod, key, fallback)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  return value
end

local function cubeProfile(mod)
  local value = choice(mod, "actor_voxel_cubes", "off")
  -- RC19 stored this key as a toggle. Preserve an existing enabled setting.
  if value == true then value = "balanced" end
  local profiles = {
    subtle={ depth=.42, layers=2 },
    balanced={ depth=.68, layers=3 },
    strong={ depth=.92, layers=4 },
    extreme={ depth=1.20, layers=5 },
  }
  return profiles[tostring(value)]
end

local function heroRoleFromIdentity(generation, identity)
  local raw = tostring(identity or "")
  local value = raw:upper():gsub("[^A-Z0-9]", "")
  local exact = {}
  for token in (raw .. "|"):gmatch("(.-)|") do
    exact[token:upper():gsub("[^A-Z0-9]", "")] = true
  end
  if tonumber(generation) == 1 then
    -- "CRYSTAL" is KASC's name for this Kanto artwork family. It is not
    -- Kris/Crystal, whose ids are accepted only by the Gen 2 branch below.
    if value:find("KACRYSTALBLUEWALK", 1, true)
        or exact.SPRITEBLUE then
      return "blue"
    end
    if value:find("KACRYSTALGREENWALK", 1, true)
        or exact.SPRITEKAGREEN or exact.SPRITEGREEN then
      return "green"
    end
    if value:find("KACRYSTALREDWALK", 1, true)
        or exact.SPRITERED then
      return "red"
    end
    return nil
  end
  if exact.SPRITEKRIS or value:find("JASCKRIS", 1, true) then
    return "kris"
  end
  if exact.SPRITERIVAL or exact.SPRITESILVER
      or value:find("JASCSILVER", 1, true) then return "silver" end
  if exact.SPRITECHRIS or exact.SPRITEGOLD
      or exact.SPRITEETHAN or value:find("JASCGOLD", 1, true) then
    return "gold"
  end
  return nil
end

local function identityFromDef(def)
  if type(def) ~= "table" then return "" end
  return table.concat({ tostring(def.id or ""), tostring(def.name or ""),
    tostring(def.image or ""), tostring(def.ascendantCharacter or "") }, "|")
end

local function visualRoleForDef(generation, def, previous)
  if type(def) ~= "table" then return previous end
  local explicit = tostring(def.ascendantRole or ""):lower()
  if explicit ~= "" then return explicit end
  local identity = identityFromDef(def)
  local hero = heroRoleFromIdentity(generation, identity)
  if hero then return hero end
  local value = identity:upper()
  if value:find("OAK", 1, true) or value:find("EICH", 1, true) then
    return "oak"
  end
  return previous
end

local function playerRoleForGeneration(generation, role, identity)
  role = tostring(role or ""):lower()
  if role == "ethan" then role = "gold" end
  if role == "crystal" then role = "kris" end
  if tonumber(generation) == 1 then
    return (role == "red" or role == "green" or role == "blue")
      and role or heroRoleFromIdentity(generation, identity) or "red"
  end
  return (role == "gold" or role == "kris" or role == "silver")
    and role or heroRoleFromIdentity(generation, identity) or "gold"
end

local function standalonePatch(self)
  -- A flat screen-space renderer has no camera/depth buffer. Keep its native
  -- sprites intact instead of faking volume with a black offset silhouette.
  -- The follower and provider remain standalone; true character geometry is
  -- activated only inside an actual 3D renderer.
  return false, "native_renderer_has_no_3d_scene"
end

local function frameSize(def, iw, ih)
  local count = math.max(1, math.floor(tonumber(def.frames) or 1))
  local fw = math.max(1, math.floor(tonumber(def.frameWidth) or iw))
  local fh = tonumber(def.frameHeight)
  if not fh or fh < 1 then fh = math.floor(ih / count) end
  return math.min(fw, iw), math.max(1, math.min(math.floor(fh), ih))
end

local function framePixels(imageData, frame, fw, fh)
  local _, ih = imageData:getDimensions()
  local fy = math.max(0, math.floor(tonumber(frame) or 0)) * fh
  if fy + fh > ih then fy = 0 end
  local meaningfulAlpha = false
  for y = 0, fh - 1 do
    for x = 0, fw - 1 do
      local _, _, _, a = imageData:getPixel(x, fy + y)
      if a < 0.98 then meaningfulAlpha = true break end
    end
    if meaningfulAlpha then break end
  end
  local solid = {}
  for y = 0, fh - 1 do
    solid[y] = {}
    for x = 0, fw - 1 do
      local r, g, b, a = imageData:getPixel(x, fy + y)
      solid[y][x] = meaningfulAlpha and a > 0.05
        or (a > 0.05 and not (r > 0.83 and g > 0.83 and b > 0.83))
    end
  end
  return solid, fy
end

local function poseFrames(def, requested)
  local count = math.max(1, math.floor(tonumber(def.frames) or 1))
  requested = math.max(0, math.floor(tonumber(requested) or 0))
  if count >= 6 then
    local base = requested >= 3 and 3 or 0
    return base, base + 1, base + 2
  end
  if count >= 3 then return 0, 1, 2 end
  return 0, 0, 0
end

local function unionMask(front, back, x, y, width)
  local frontOn = front[y] and front[y][x] == true
  local bx = width - x - 1
  local backOn = back[y] and back[y][bx] == true
  return frontOn or backOn
end

local function appendFace(Voxel3D, verts, indices, face, x, y, z,
    sx, sy, sz, u0, v0, u1, v1)
  local corners = Voxel3D.FACE_CORNERS and Voxel3D.FACE_CORNERS[face]
  if not corners then return end
  local shade = Voxel3D.FACE_SHADE and Voxel3D.FACE_SHADE[face] or 1
  local centerU, centerV = (u0 + u1) / 2, (v0 + v1) / 2
  local quad = math.floor(#verts / 4)
  for i = 1, 4 do
    local c = corners[i]
    verts[#verts + 1] = {
      x + c[1] * sx, y + c[2] * sy, z + c[3] * sz,
      centerU, centerV, shade,
    }
  end
  Voxel3D.pushQuad(indices, quad)
end

local function framePalette(imageData, frame, fw, fh)
  local iw, ih = imageData:getDimensions()
  local fy = math.max(0, math.floor(tonumber(frame) or 0)) * fh
  if fy + fh > ih then fy = 0 end
  local samples, red = {}, nil
  for y = 0, fh - 1 do
    for x = 0, fw - 1 do
      local r, g, b, a = imageData:getPixel(x, fy + y)
      if a > 0.1 then
        local sample = {
          r=r, g=g, b=b, l=r*0.299+g*0.587+b*0.114,
          u=(x+0.5)/iw, v=(fy+y+0.5)/ih,
        }
        samples[#samples + 1] = sample
        if r > 0.58 and g < 0.42 and b < 0.42
            and (not red or r-g-b*0.5 > red.r-red.g-red.b*0.5) then
          red = sample
        end
      end
    end
  end
  table.sort(samples, function(a, b) return a.l < b.l end)
  if #samples == 0 then
    return {dark={u=0,v=0}, body={u=0,v=0}, light={u=0,v=0}}
  end
  local dark, light = samples[1], samples[#samples]
  local body, best = samples[math.ceil(#samples/2)], -1
  for _, sample in ipairs(samples) do
    local separation = math.min(math.abs(sample.l-dark.l),
      math.abs(sample.l-light.l))
    if separation > best then body, best = sample, separation end
  end
  return { dark=dark, body=body, light=light, red=red }
end

local function primitiveBuilder(Voxel3D)
  local verts, indices = {}, {}
  local lx, ly, lz = 0.35, 0.78, 0.52
  local function triangle(a, b, c, sample, center)
    local abx, aby, abz = b[1]-a[1], b[2]-a[2], b[3]-a[3]
    local acx, acy, acz = c[1]-a[1], c[2]-a[2], c[3]-a[3]
    local nx, ny, nz = aby*acz-abz*acy,
      abz*acx-abx*acz, abx*acy-aby*acx
    local outward = nx*(a[1]-center[1]) + ny*(a[2]-center[2])
      + nz*(a[3]-center[3])
    if outward < 0 then b, c, nx, ny, nz = c, b, -nx, -ny, -nz end
    local length = math.sqrt(nx*nx + ny*ny + nz*nz)
    if length < 0.0001 then return end
    nx, ny, nz = nx/length, ny/length, nz/length
    local shade = math.max(0.58, math.min(1,
      0.72 + math.max(-0.35, nx*lx+ny*ly+nz*lz)*0.34))
    if type(sample) == "function" then
      sample = sample({
        (a[1]+b[1]+c[1])/3,
        (a[2]+b[2]+c[2])/3,
        (a[3]+b[3]+c[3])/3,
      })
    end
    if type(sample) ~= "table" then return end
    for _, p in ipairs({a,b,c}) do
      verts[#verts+1] = {p[1],p[2],p[3],sample.u,sample.v,shade}
      indices[#indices+1] = #verts
    end
  end
  local function ellipsoid(cx, cy, cz, rx, ry, rz, sample, rotZ)
    local segments, rings = 12, 6
    local center = {cx,cy,cz}
    local cosine, sine = math.cos(rotZ or 0), math.sin(rotZ or 0)
    local function point(longitude, latitude)
      local px = rx*math.cos(latitude)*math.cos(longitude)
      local py = ry*math.sin(latitude)
      local pz = rz*math.cos(latitude)*math.sin(longitude)
      return {cx+px*cosine-py*sine, cy+px*sine+py*cosine, cz+pz}
    end
    for ring = 0, rings-1 do
      local lat0 = -math.pi/2 + math.pi*ring/rings
      local lat1 = -math.pi/2 + math.pi*(ring+1)/rings
      for segment = 0, segments-1 do
        local lon0 = 2*math.pi*segment/segments
        local lon1 = 2*math.pi*(segment+1)/segments
        local a, b = point(lon0,lat0), point(lon1,lat0)
        local c, d = point(lon1,lat1), point(lon0,lat1)
        triangle(a,b,c,sample,center)
        triangle(a,c,d,sample,center)
      end
    end
  end
  local function cone(cx, cy, cz, rx, height, rz, sample, rotZ)
    local segments = 10
    local center = {cx,cy,cz}
    local cosine, sine = math.cos(rotZ or 0), math.sin(rotZ or 0)
    local function rotate(px, py, pz)
      return {cx+px*cosine-py*sine, cy+px*sine+py*cosine, cz+pz}
    end
    local apex = rotate(0,height/2,0)
    local baseCenter = rotate(0,-height/2,0)
    for segment = 0, segments-1 do
      local a0 = 2*math.pi*segment/segments
      local a1 = 2*math.pi*(segment+1)/segments
      local a = rotate(rx*math.cos(a0),-height/2,rz*math.sin(a0))
      local b = rotate(rx*math.cos(a1),-height/2,rz*math.sin(a1))
      triangle(a,b,apex,sample,center)
      triangle(baseCenter,b,a,sample,center)
    end
  end
  return {
    ellipsoid=ellipsoid,
    cone=cone,
    finish=function() return Voxel3D.newMesh(verts,indices) end,
  }
end

local function authoredPaletteTexture()
  if not (love and love.image and love.image.newImageData
      and love.graphics and love.graphics.newImage) then return nil, nil end
  local colors = {
    red={0.878,0.216,0.098}, skin={0.886,0.580,0.357},
    dark={0.114,0.094,0.098}, white={0.925,0.922,0.871},
    blue={0.176,0.361,0.710}, yellow={0.937,0.718,0.153},
  }
  local order = {"red","skin","dark","white","blue","yellow"}
  local ok, data = pcall(love.image.newImageData, #order, 1)
  if not ok or not data then return nil, nil end
  local samples = {}
  for index, name in ipairs(order) do
    local color = colors[name]
    data:setPixel(index-1, 0, color[1], color[2], color[3], 1)
    samples[name] = {u=(index-.5)/#order, v=.5}
  end
  local imageOk, texture = pcall(love.graphics.newImage, data)
  if not imageOk or not texture then return nil, nil end
  pcall(texture.setFilter, texture, "nearest", "nearest")
  return texture, samples
end

local function buildEeveeMesh(Voxel3D, imageData, frame, fw, fh)
  local palette = framePalette(imageData, frame, fw, fh)
  local shape = primitiveBuilder(Voxel3D)
  local e, cone = shape.ellipsoid, shape.cone

  -- Eevee's toy-like proportions: very short legs, a compact body and a
  -- head almost as wide as the torso.  A generic fox has the opposite ratio.
  e(5.55,1.25, 1.55, 1.15,1.35,1.1,palette.body, 0)
  e(10.45,1.25,1.55, 1.15,1.35,1.1,palette.body, 0)
  e(5.7,1.3,-1.35, 1.05,1.4,1.0,palette.body, 0)
  e(10.3,1.3,-1.35,1.05,1.4,1.0,palette.body, 0)
  e(8,4.45,-0.35,3.65,2.55,3.0,palette.body, 0)

  -- The cream neck ruff is made from overlapping faceted balloons rather
  -- than painted pixels, so it stays recognisable from every camera angle.
  for _, tuft in ipairs({
    {4.65,6.35,0.75,1.8,1.65,1.3,-0.52},
    {5.75,7.0,1.35,1.9,1.8,1.35,-0.32},
    {7.15,7.45,1.75,1.85,1.95,1.4,-0.12},
    {8.85,7.45,1.75,1.85,1.95,1.4,0.12},
    {10.25,7.0,1.35,1.9,1.8,1.35,0.32},
    {11.35,6.35,0.75,1.8,1.65,1.3,0.52},
  }) do
    e(tuft[1],tuft[2],tuft[3],tuft[4],tuft[5],tuft[6],palette.light,tuft[7])
  end

  -- Head, cream muzzle, black nose and eyes.
  e(8,10.35,0.8,4.15,3.7,3.55,palette.body,0)
  e(8,9.15,3.65,2.05,1.35,0.95,palette.light,0)
  e(8,9.2,4.5,0.58,0.42,0.3,palette.dark,0)
  e(6.35,10.75,3.9,0.58,0.82,0.3,palette.dark,0)
  e(9.65,10.75,3.9,0.58,0.82,0.3,palette.dark,0)
  e(6.18,11.0,4.16,0.18,0.24,0.12,palette.light,0)
  e(9.48,11.0,4.16,0.18,0.24,0.12,palette.light,0)

  -- Broad triangular ears, dark inner ears and dark tips.  These replace the
  -- narrow ellipsoids that made the first pass read as an ordinary fox.
  cone(5.1,14.1,-0.05,2.2,5.9,1.45,palette.dark,-0.22)
  cone(10.9,14.1,-0.05,2.2,5.9,1.45,palette.dark,0.22)
  cone(5.1,13.95,0.35,1.78,5.25,1.12,palette.body,-0.22)
  cone(10.9,13.95,0.35,1.78,5.25,1.12,palette.body,0.22)
  cone(5.15,14.25,1.2,0.92,3.9,0.38,palette.dark,-0.22)
  cone(10.85,14.25,1.2,0.92,3.9,0.38,palette.dark,0.22)

  -- Three short forehead tufts complete Eevee's recognisable head shape.
  cone(6.9,13.45,2.05,0.65,2.15,0.6,palette.body,-0.34)
  cone(8.0,13.8,2.15,0.72,2.45,0.65,palette.body,0)
  cone(9.1,13.45,2.05,0.65,2.15,0.6,palette.body,0.34)

  -- A raised, bushy tail with a pale tip remains visible behind the body.
  e(11.7,5.7,-2.0,1.9,2.35,1.5,palette.body,-0.60)
  e(13.3,7.6,-2.0,2.2,2.85,1.65,palette.body,-0.50)
  e(14.45,9.75,-1.9,1.8,2.25,1.45,palette.light,-0.40)
  return shape.finish()
end

local function buildHumanoidMesh(Voxel3D, imageData, frame, fw, fh)
  local palette = framePalette(imageData, frame, fw, fh)
  local shape = primitiveBuilder(Voxel3D)
  local e = shape.ellipsoid
  local accent = palette.red or palette.body
  local skin = palette.light
  local dark = palette.dark
  local cap = palette.red ~= nil

  -- Feet and separate legs make walking read as a figure rather than a card.
  e(5.95,1.15,0.15,1.7,1.25,1.75,dark,0)
  e(10.05,1.15,0.15,1.7,1.25,1.75,dark,0)
  e(6.1,3.0,0,1.55,2.25,1.55,accent,-0.05)
  e(9.9,3.0,0,1.55,2.25,1.55,accent,0.05)

  -- Rounded torso, backpack and free-standing arms.
  e(8,6.05,-1.9,3.3,3.25,1.55,dark,0)
  e(8,6.2,0,3.65,3.5,2.75,accent,0)
  e(8,4.75,2.55,3.35,0.55,0.5,dark,0)
  e(8,7.5,2.55,1.25,1.75,0.5,dark,0)
  e(3.9,6.1,0.25,1.35,3.0,1.35,skin,-0.15)
  e(12.1,6.1,0.25,1.35,3.0,1.35,skin,0.15)
  e(3.75,4.3,0.65,1.15,1.25,1.15,dark,0)
  e(12.25,4.3,0.65,1.15,1.25,1.15,dark,0)

  -- Oversized head and small ears produce the same balloon/chibi ratio as
  -- the reference while retaining the active character palette.
  e(8,11.15,0.2,4.05,3.7,3.55,skin,0)
  e(3.95,11.15,0.2,0.9,1.25,0.8,skin,0)
  e(12.05,11.15,0.2,0.9,1.25,0.8,skin,0)
  e(8,13.35,0.15,4.18,1.72,3.72,dark,0)

  -- Eyes and a tiny nose are real raised pieces and therefore rotate with
  -- the whole actor for down/up/left/right poses.
  e(6.45,11.25,3.68,0.48,0.68,0.25,dark,0)
  e(9.55,11.25,3.68,0.48,0.68,0.25,dark,0)
  e(8,10.1,3.85,0.42,0.34,0.22,dark,0)

  if cap then
    -- Red-style cap: crown, contrasting band and forward brim.
    e(8,14.15,0.1,4.5,1.85,3.82,accent,0)
    e(8,13.15,3.25,3.65,0.52,1.35,dark,0)
    e(8,13.35,3.85,3.25,0.4,1.05,accent,0)
  end
  return shape.finish()
end

local function buildRedMesh(Voxel3D, imageData, frame, fw, fh,
    authored, motionPhase)
  local palette = authored or framePalette(imageData, frame, fw, fh)
  local shape = primitiveBuilder(Voxel3D)
  local e, cone = shape.ellipsoid, shape.cone
  local red, skin, dark = palette.red or palette.body,
    palette.skin or palette.light, palette.dark
  local white, blue, yellow = palette.white or palette.light,
    palette.blue or palette.dark, palette.yellow or palette.light
  motionPhase = math.max(0, math.min(2,
    math.floor(tonumber(motionPhase) or 0)))
  local stride = motionPhase == 1 and .82
    or motionPhase == 2 and -.82 or 0
  local bob = motionPhase == 0 and 0 or .14

  -- Shoes and baggy blue trousers. The two cached stride variants make an
  -- actual walk cycle; right-facing uses the same geometry, correctly yawed.
  e(6.2,.6, .2+stride,1.58,.68,1.62,dark,-.03)
  e(9.8,.6,.2-stride,1.58,.68,1.62,dark,.03)
  e(6.2,.62,1.55+stride,1.17,.48,.4,white,0)
  e(9.8,.62,1.55-stride,1.17,.48,.4,white,0)
  e(6.25,1.85, .30*stride,1.6,1.48,1.48,blue,-.05)
  e(9.75,1.85,-.30*stride,1.6,1.48,1.48,blue,.05)

  -- One continuous torso carries the vest as colored surface facets. This
  -- avoids the detached red ovals of the rejected prototype.
  local function shirtAndVest(point)
    local x, z = point[1]-8, point[3]
    return z > .65 and math.abs(x) > 1.0 and red or dark
  end
  e(8,4.45+bob,0,2.95,2.38,2.28,shirtAndVest,0)
  e(6.82,4.5+bob,2.27,.16,2.0,.16,white,0)
  e(9.18,4.5+bob,2.27,.16,2.0,.16,white,0)
  e(6.88,6.35+bob,2.08,.9,.5,.3,white,-.38)
  e(9.12,6.35+bob,2.08,.9,.5,.3,white,.38)
  e(5.85,3.65+bob,2.32,.62,.24,.16,yellow,0)
  e(10.15,3.65+bob,2.32,.62,.24,.16,yellow,0)

  -- Black short sleeves, skin forearms, hands and dark wristbands.
  e(4.75,5.15+bob,-stride*.35,1.02,1.25,1.0,dark,-.2)
  e(11.25,5.15+bob,stride*.35,1.02,1.25,1.0,dark,.2)
  e(4.38,3.98+bob,.1-stride*.68,.72,1.2,.72,skin,-.18)
  e(11.62,3.98+bob,.1+stride*.68,.72,1.2,.72,skin,.18)
  e(4.25,3.05+bob,.45-stride*.86,.72,.72,.72,skin,0)
  e(11.75,3.05+bob,.45+stride*.86,.72,.72,.72,skin,0)
  e(4.32,3.62+bob,.38-stride*.72,.79,.28,.78,dark,0)
  e(11.68,3.62+bob,.38+stride*.72,.79,.28,.78,dark,0)

  -- Rounded backpack with a raised rear pocket and top handle.
  e(8,4.55+bob,-2.45,2.72,2.48,1.05,dark,0)
  e(8,4.55+bob,-3.18,2.42,2.15,.48,red,0)
  e(8,4.0+bob,-3.62,1.58,1.08,.22,dark,0)
  e(8,4.0+bob,-3.79,1.38,.9,.18,red,0)
  e(8,6.72+bob,-2.95,1.0,.42,.4,dark,0)
  e(8,6.74+bob,-3.25,.72,.25,.25,red,0)

  -- Head, ears, layered hair and face.
  e(8,9.15+bob,.12,3.72,3.05,3.28,skin,0)
  e(4.28,9.15+bob,0,.68,.9,.62,skin,0)
  e(11.72,9.15+bob,0,.68,.9,.62,skin,0)
  e(8,9.9+bob,-2.5,3.62,2.42,1.02,dark,0)
  cone(5,10.6+bob,-1.15,.8,2.15,.72,dark,-.24)
  cone(11,10.6+bob,-1.15,.8,2.15,.72,dark,.24)
  cone(6.15,10.85+bob,2.72,.62,1.65,.35,dark,-.28)
  cone(8,11.0+bob,2.88,.68,1.8,.35,dark,0)
  cone(9.85,10.85+bob,2.72,.62,1.65,.35,dark,.28)
  e(6.55,9.35+bob,3.27,.38,.62,.2,dark,0)
  e(9.45,9.35+bob,3.27,.38,.62,.2,dark,0)
  e(8,8.75+bob,3.34,.28,.2,.18,skin,0)
  -- Two short angled strokes read as the approved friendly smile.
  e(7.55,8.13+bob,3.28,.52,.12,.13,dark,-.22)
  e(8.45,8.13+bob,3.28,.52,.12,.13,dark,.22)

  -- The white front is now painted onto the cap dome itself, so the side
  -- profile is a curved panel instead of the rejected feather-like plate.
  local function capPanel(point)
    local x, z = point[1]-8, point[3]
    return z > 1.0 and math.abs(x) < 2.95 and white or red
  end
  e(8,12.05+bob,0,4.05,1.72,3.48,capPanel,0)
  e(8,11.25+bob,3.38,3.35,.32,.92,red,0)
  e(8,13.62+bob,0,.4,.24,.4,red,0)
  return shape.finish()
end

local function buildVoxelMesh(Voxel3D, Assets, def, frame, role,
    authored, motionPhase)
  local imageData = Assets.imageData(def.image)
  if not imageData then return nil end
  local iw, ih = imageData:getDimensions()
  local fw, fh = frameSize(def, iw, ih)
  if tostring(def.image):lower():match("follower_0*133") then
    return buildEeveeMesh(Voxel3D, imageData, frame, fw, fh)
  end
  if role == "red" then
    -- Red uses the approved 4x3 rendered Card atlas. Never fall back to the
    -- rejected procedural approximation when that atlas is unavailable.
    return nil
  end
  if not tostring(def.image):lower():match("follower_%d+") then
    return buildHumanoidMesh(Voxel3D, imageData, frame, fw, fh)
  end
  local frontFrame, backFrame, sideFrame = poseFrames(def, frame)
  local front, frontY = framePixels(imageData, frontFrame, fw, fh)
  local back, backY = framePixels(imageData, backFrame, fw, fh)
  local side, sideY = framePixels(imageData, sideFrame, fw, fh)
  -- Native overworld art is square for readability, but a square depth would
  -- turn every actor into a cube.  A shallower hull gives the compact,
  -- polygonal toy-like proportions used by the reference style.
  local sx, sy, sz = 16 / fw, 16 / fh, 10 / fw
  local function occupied(x, y, z)
    if x < 0 or x >= fw or y < 0 or y >= fh or z < 0 or z >= fw then
      return false
    end
    -- The front and mirrored back jointly describe the body outline. The
    -- orthogonal side view carves that outline into a true visual hull.
    return unionMask(front, back, x, y, fw)
      and side[y] and side[y][z] == true
  end
  local function uvFor(face, x, y, z)
    local u, v
    if face == 5 then
      u, v = x, frontY + y
    elseif face == 6 then
      u, v = fw - x - 1, backY + y
    elseif face == 1 then
      u, v = z, sideY + y
    elseif face == 2 then
      u, v = fw - z - 1, sideY + y
    else
      u, v = x, frontY + y
    end
    local inset = 0.18
    return (u + inset) / iw, (v + inset) / ih,
      (u + 1 - inset) / iw, (v + 1 - inset) / ih
  end

  local faces, points, neighbours = {}, {}, {}
  local function pointKey(ix, iy, iz)
    return ix .. ":" .. iy .. ":" .. iz
  end
  local function addPoint(ix, iy, iz)
    local pointId = pointKey(ix, iy, iz)
    if not points[pointId] then
      points[pointId] = {
        x=ix * sx, y=iy * sy, z=(iz - fw / 2) * sz,
        ix=ix, iy=iy, iz=iz, floor=iy == 0,
      }
      neighbours[pointId] = {}
    end
    return pointId
  end
  local function connect(a, b)
    neighbours[a][b], neighbours[b][a] = true, true
  end

  for py = 0, fh - 1 do
    for px = 0, fw - 1 do
      for pz = 0, fw - 1 do
        if occupied(px, py, pz) then
          local iy = fh - py - 1
          for face, delta in ipairs({
            { 1, 0, 0 }, { -1, 0, 0 }, { 0, -1, 0 },
            { 0, 1, 0 }, { 0, 0, 1 }, { 0, 0, -1 },
          }) do
            if not occupied(px + delta[1], py + delta[2], pz + delta[3]) then
              local u0, v0, u1, v1 = uvFor(face, px, py, pz)
              local cornerIds = {}
              for index, corner in ipairs(Voxel3D.FACE_CORNERS[face]) do
                cornerIds[index] = addPoint(px + corner[1], iy + corner[2],
                  pz + corner[3])
              end
              for index = 1, 4 do
                connect(cornerIds[index], cornerIds[index % 4 + 1])
              end
              faces[#faces + 1] = {
                direction=face, corners=cornerIds,
                uv={u0, v0, u1, v1},
              }
            end
          end
        end
      end
    end
  end

  -- Inflate every vertical slice like a soft toy.  A silhouette boundary is
  -- kept shallow while pixels farther inside the outline push the front and
  -- back surfaces outward.  This is deliberately not a uniform extrusion:
  -- the rounded depth gradient is what makes heads, torsos and limbs read as
  -- balloon-like volume from a moving VASC camera.
  local function outlineDistance(ix, iy)
    local vx, vy = ix, fh - iy
    local best = math.min(vx, fw - vx, vy, fh - vy)
    for py = 0, fh - 1 do
      for px = 0, fw - 1 do
        if not unionMask(front, back, px, py, fw) then
          local dx, dy = vx - (px + 0.5), vy - (py + 0.5)
          best = math.min(best, math.sqrt(dx * dx + dy * dy))
        end
      end
    end
    return math.max(0, best)
  end
  local sliceMax = {}
  for _, point in pairs(points) do
    local slice = point.ix .. ":" .. point.iy
    sliceMax[slice] = math.max(sliceMax[slice] or 0, math.abs(point.z))
  end
  for _, point in pairs(points) do
    local slice = point.ix .. ":" .. point.iy
    local oldHalf = sliceMax[slice] or 0
    if oldHalf > 0.001 then
      local distance = outlineDistance(point.ix, point.iy)
      local balloonHalf = math.min(5.7, 1.0 + 1.9 * math.sqrt(distance))
      point.z = point.z / oldHalf * balloonHalf
    end
  end

  -- Four restrained Laplacian passes remove the staircase from the tiny
  -- source silhouette. Feet remain fixed to the ground so locomotion and
  -- shadows stay anchored while the upper body rounds into the balloon hull.
  for _ = 1, 4 do
    local nextPoints = {}
    for pointId, point in pairs(points) do
      local nx, ny, nz, count = 0, 0, 0, 0
      for neighbourId in pairs(neighbours[pointId]) do
        local other = points[neighbourId]
        nx, ny, nz, count = nx + other.x, ny + other.y, nz + other.z, count + 1
      end
      if count > 0 then
        local amount = 0.24
        nextPoints[pointId] = {
          x=point.x + (nx / count - point.x) * amount,
          y=point.floor and 0 or point.y + (ny / count - point.y) * amount,
          z=point.z + (nz / count - point.z) * amount,
          floor=point.floor,
        }
      else
        nextPoints[pointId] = point
      end
    end
    points = nextPoints
  end

  local verts, indices = {}, {}
  local lightX, lightY, lightZ = 0.32, 0.72, 0.48
  local function triangleShade(a, b, c, fallback)
    local abx, aby, abz = b.x-a.x, b.y-a.y, b.z-a.z
    local acx, acy, acz = c.x-a.x, c.y-a.y, c.z-a.z
    local nx = aby*acz-abz*acy
    local ny = abz*acx-abx*acz
    local nz = abx*acy-aby*acx
    local length = math.sqrt(nx*nx + ny*ny + nz*nz)
    if length < 0.001 then return fallback end
    nx, ny, nz = nx/length, ny/length, nz/length
    local light = math.max(-0.4, nx*lightX + ny*lightY + nz*lightZ)
    return math.max(0.5, math.min(1.0, 0.7 + light*0.38))
  end
  for _, surface in ipairs(faces) do
    local u0, v0, u1, v1 = unpack(surface.uv)
    local uv = {
      {u0,v1}, {u1,v1}, {u1,v0}, {u0,v0},
    }
    local polygon = {}
    for index, pointId in ipairs(surface.corners) do
      polygon[index] = points[pointId]
    end
    -- Split every softly warped quad into two genuinely flat-shaded facets.
    -- Duplicated triangle vertices keep the shade discontinuity crisp, which
    -- is the characteristic low-poly balloon surface of the reference.
    for _, order in ipairs({ {1,2,3}, {1,3,4} }) do
      local facetShade = triangleShade(polygon[order[1]], polygon[order[2]],
        polygon[order[3]], Voxel3D.FACE_SHADE[surface.direction] or 1)
      for _, index in ipairs(order) do
        local point = polygon[index]
        verts[#verts + 1] = {
          point.x, point.y, point.z,
          uv[index][1], uv[index][2], facetShade,
        }
        indices[#indices + 1] = #verts
      end
    end
  end
  return Voxel3D.newMesh(verts, indices)
end

local function locateBillboards(scene)
  if not (debug and debug.getupvalue) then return nil end
  local queue, seenFunctions, seenTables = {}, {}, {}
  for _, value in pairs(scene or {}) do
    if type(value) == "function" then queue[#queue + 1] = value end
  end
  local cursor = 1
  while cursor <= #queue do
    local fn = queue[cursor]
    cursor = cursor + 1
    if not seenFunctions[fn] then
      seenFunctions[fn] = true
      local index = 1
      while true do
        local _, value = debug.getupvalue(fn, index)
        if value == nil then break end
        if type(value) == "table" and not seenTables[value] then
          seenTables[value] = true
          if type(value.mesh) == "function"
              and type(value.shadowQuad) == "function"
              and type(value.invalidate) == "function" then
            return value
          end
          for _, nested in pairs(value) do
            if type(nested) == "function" and not seenFunctions[nested] then
              queue[#queue + 1] = nested
            end
          end
        elseif type(value) == "function" and not seenFunctions[value] then
          queue[#queue + 1] = value
        end
        index = index + 1
      end
    end
  end
  return nil
end

local function matMul(a, b)
  local out = {}
  for row = 0, 3 do
    local a0, a1 = a[row * 4 + 1], a[row * 4 + 2]
    local a2, a3 = a[row * 4 + 3], a[row * 4 + 4]
    for col = 1, 4 do
      out[row * 4 + col] = a0 * b[col] + a1 * b[4 + col]
        + a2 * b[8 + col] + a3 * b[12 + col]
    end
  end
  return out
end

local function translate(x, y, z)
  return { 1,0,0,x, 0,1,0,y, 0,0,1,z, 0,0,0,1 }
end

local function scale(x, y, z)
  return { x,0,0,0, 0,y,0,0, 0,0,z,0, 0,0,0,1 }
end

local function rotateX(angle)
  local c, s = math.cos(angle), math.sin(angle)
  return { 1,0,0,0, 0,c,-s,0, 0,s,c,0, 0,0,0,1 }
end

local function rotateY(angle)
  local c, s = math.cos(angle), math.sin(angle)
  return { c,0,s,0, 0,1,0,0, -s,0,c,0, 0,0,0,1 }
end

local function mirroredMatrix(m)
  if type(m) ~= "table" or #m < 16 then return false end
  local determinant = m[1] * (m[6] * m[11] - m[7] * m[10])
    - m[2] * (m[5] * m[11] - m[7] * m[9])
    + m[3] * (m[5] * m[10] - m[6] * m[9])
  return determinant < 0
end

local function frameFromCard(mesh, def, texture)
  if not (mesh and type(mesh.getVertexCount) == "function"
      and mesh:getVertexCount() == 4 and type(mesh.getVertex) == "function") then
    return nil
  end
  local ok, _, _, _, _, v = pcall(mesh.getVertex, mesh, 1)
  if not ok or type(v) ~= "number" then return nil end
  local _, ih = texture:getDimensions()
  local _, fh = frameSize(def, texture:getDimensions())
  return math.max(0, math.min((tonumber(def.frames) or 1) - 1,
    math.floor(v * ih / fh)))
end

local function standingMatrix(cardModel, frame, lean, uniformScale, baseLift)
  if type(cardModel) ~= "table" or #cardModel < 16 then return cardModel end
  local mirrored = mirroredMatrix(cardModel)
  local direction = frame % 3
  local yaw = direction == 1 and math.pi
    or direction == 2 and (mirrored and math.pi / 2 or -math.pi / 2)
    or 0
  local corrected = matMul(cardModel, translate(8, 0, 0))
  -- VASC already expresses a right-facing side card as a mirrored model.
  -- The opposite yaw above is sufficient for a volume; applying a second
  -- negative scale flipped triangle winding and could cull right-walk frames.
  corrected = matMul(corrected, rotateX(math.pi / 2 - lean))
  corrected = matMul(corrected, rotateY(yaw))
  if uniformScale then
    corrected = matMul(corrected,
      scale(uniformScale, uniformScale, uniformScale))
  else
    corrected = matMul(corrected, scale(1, 1.35, 1))
  end
  return matMul(corrected, translate(-8, baseLift or 0, 0))
end

-- One live job at a time. Queued factories own no decoded data. A caller must
-- prune before pumping whenever its visible/admitted demand changes.
local function newAnimationQueue(clock, seconds)
  local jobs, active, deadline = {}, nil, 0
  local queue = {}
  local function checkpoint(nativeStep)
    if nativeStep then coroutine.yield("frame")
    elseif clock() >= deadline then coroutine.yield("budget") end
  end
  function queue.push(key, factory, complete)
    if not jobs[key] then jobs[key] = {factory=factory, complete=complete} end
  end
  local function discard(key)
    local job = jobs[key]
    jobs[key] = nil
    if active == key then active = nil end
    if job and job.cleanup then pcall(job.cleanup) end
  end
  function queue.prune(wanted)
    for key in pairs(jobs) do if not wanted[key] then discard(key) end end
  end
  function queue.pump(order)
    deadline = clock() + seconds
    -- A frozen/missing clock must still never cause an unbounded pump.
    for _ = 1, 128 do
      if not active then
        for _, key in ipairs(order) do if jobs[key] then active = key; break end end
      end
      if not active then break end
      local key, job = active, jobs[active]
      if not job.thread then
        local ok, run, cleanup = pcall(job.factory)
        if not ok or type(run) ~= "function" then
          discard(key); job.complete(false)
        else
          job.cleanup = cleanup
          job.thread = coroutine.create(function() return run(checkpoint) end)
        end
      end
      if job.thread then
        local ok, result = coroutine.resume(job.thread)
        if not ok or coroutine.status(job.thread) == "dead" then
          jobs[key], active = nil, nil
          -- A successful pair transfers ownership to the resident cache.
          if (not ok or not result) and job.cleanup then pcall(job.cleanup) end
          job.complete(ok and result or false)
        elseif result == "frame" or result == "budget" then break end
      end
      if clock() >= deadline then break end
    end
  end
  function queue.pending()
    local count = 0; for _ in pairs(jobs) do count = count + 1 end
    return count
  end
  return queue
end

local function alphaBounds(imageData, row, column, atlasColumns, layout, checkpoint, noGrid)
  if not imageData or type(imageData.getPixel) ~= "function" then return nil end
  local iw, ih = imageData:getDimensions()
  local cellW, cellH = math.floor(iw / (atlasColumns or 3)), math.floor(ih / 4)
  local left, top = (column + 1) * cellW, (row + 1) * cellH
  local right, bottom = column * cellW, row * cellH
  local found = false
  if layout then
    -- For authored bounds only non-emptiness is needed. Try the centre first:
    -- an opaque sample proves the same result as the exhaustive scan. Hollow
    -- or empty cells still take that scan; no pixel/alpha threshold changes.
    local probeX = column * cellW + math.max(0, math.min(cellW-1,
      math.floor((layout.left+layout.right)/2)))
    local probeY = row * cellH + math.max(0, math.min(cellH-1,
      math.floor((layout.top+layout.bottom)/2)))
    local _, _, _, alpha = imageData:getPixel(probeX, probeY)
    found = alpha and alpha > .02 or false
  end
  for y = row * cellH, (row + 1) * cellH - 1 do
    if checkpoint then checkpoint() end
    if layout and found then break end
    for x = column * cellW, (column + 1) * cellW - 1 do
      local _, _, _, alpha = imageData:getPixel(x, y)
      if alpha and alpha > .02 then
        found = true
        left, right = math.min(left, x), math.max(right, x + 1)
        top, bottom = math.min(top, y), math.max(bottom, y + 1)
        -- A verified layout replaces these bounds below. Only non-emptiness
        -- matters here; continue full discovery for ordinary unsized cards.
        if layout then break end
      end
    end
    if layout and found then break end
  end
  if not found then return nil end
  if layout then
    left, top = column * cellW + layout.left, row * cellH + layout.top
    right, bottom = column * cellW + layout.right, row * cellH + layout.bottom
  end
  local function sampleGrid(columns, rows)
    local cells = {}
  for gy = 0, rows - 1 do
    if checkpoint then checkpoint() end
    cells[gy] = {}
    local y0 = math.floor(top + (bottom-top) * gy / rows)
    local y1 = math.max(y0 + 1,
      math.floor(top + (bottom-top) * (gy+1) / rows))
    for gx = 0, columns - 1 do
      local x0 = math.floor(left + (right-left) * gx / columns)
      local x1 = math.max(x0 + 1,
        math.floor(left + (right-left) * (gx+1) / columns))
      local occupied = false
      for sy = y0, math.min(y1 - 1, bottom - 1) do
        for sx = x0, math.min(x1 - 1, right - 1) do
          local _, _, _, alpha = imageData:getPixel(sx, sy)
          if alpha and alpha > .08 then occupied = true break end
        end
        if occupied then break end
      end
      cells[gy][gx] = occupied
    end
  end
    return cells
  end
  local columns, rows = 10, 14
  local cells = not noGrid and sampleGrid(columns, rows) or nil
  -- Cube bodies use a finer lattice than the legacy separation grid.  This
  -- keeps faces recognisable while avoiding the huge slab-like terraces of a
  -- 10x14 body.
  local cubeColumns, cubeRows = 16, 22
  local cubeCells = not noGrid and sampleGrid(cubeColumns, cubeRows) or nil
  return { left=left, top=top, right=right, bottom=bottom,
    imageWidth=iw, imageHeight=ih, gridColumns=columns, gridRows=rows,
    occupied=cells, cubeColumns=cubeColumns, cubeRows=cubeRows,
    cubeOccupied=cubeCells, layout=layout, cellX=column*cellW, cellY=row*cellH }
end

local function atlasCardMesh(Voxel3D, bounds, visibleHeight, voxelFinish,
    voxelGrid, voxelCubes, neutral)
  if not bounds then return nil end
  visibleHeight = tonumber(visibleHeight) or 16
  local pixelHeight = math.max(1, bounds.bottom - bounds.top)
  local pixelWidth = math.max(1, bounds.right - bounds.left)
  local visibleWidth = visibleHeight * pixelWidth / pixelHeight
  local x0, x1 = (16-visibleWidth)/2, (16+visibleWidth)/2
  local y0 = 0
  if bounds.layout then
    local layout = bounds.layout
    local unit = visibleHeight / layout.referenceHeight
    visibleWidth, visibleHeight = pixelWidth * unit, pixelHeight * unit
    x0 = 8 + (bounds.left - bounds.cellX - layout.anchorX) * unit
    x1 = x0 + visibleWidth
    y0 = (layout.anchorY - (bounds.bottom - bounds.cellY)) * unit
  end
  local u0 = bounds.left / bounds.imageWidth
  local u1 = bounds.right / bounds.imageWidth
  local v0 = bounds.top / bounds.imageHeight
  local v1 = bounds.bottom / bounds.imageHeight
  local indices = {}
  local verts = {}
  if voxelGrid then
    -- Build real separated voxel cells from the authored alpha silhouette.
    -- A slanted camera therefore sees depth and black inner faces instead of
    -- merely seeing grid lines painted over a flat card.
    local columns = voxelCubes and (bounds.cubeColumns or 16)
      or (bounds.gridColumns or 10)
    local rows = voxelCubes and (bounds.cubeRows or 22)
      or (bounds.gridRows or 14)
    local occupied = voxelCubes and (bounds.cubeOccupied or bounds.occupied or {})
      or (bounds.occupied or {})
    local gap = voxelCubes and .006 or .07
    -- The original grid keeps its shallow separated slices.  Cube mode is a
    -- separate opt-in: width, height and depth become approximately equal,
    -- turning every occupied silhouette cell into a real Minecraft-like
    -- cuboid while retaining the black separation gaps.
    local cellWidth = visibleWidth / columns
    local cellHeight = visibleHeight / rows
    local cubeDepth = math.min(cellWidth, cellHeight)
      * (voxelCubes and voxelCubes.depth or .92)
    local function columnLayers(gx, gy)
      if not voxelCubes then return 1 end
      -- Give the authored silhouette actual volume.  Boundary cells form one
      -- cube, while successively enclosed cells grow into glued stacks.  The
      -- stepped front/back faces read as a Minecraft-like body instead of a
      -- uniformly thick, gridded billboard.
      local layers = 1
      for radius = 1, (voxelCubes and voxelCubes.layers or 1) do
        local enclosed = true
        for oy = -radius, radius do
          for ox = -radius, radius do
            if math.abs(ox) + math.abs(oy) == radius
                and not (occupied[gy + oy] and occupied[gy + oy][gx + ox]) then
              enclosed = false
              break
            end
          end
          if not enclosed then break end
        end
        if not enclosed then break end
        layers = layers + 1
      end
      return layers
    end
    local layerMap = {}
    for gy = 0, rows - 1 do
      layerMap[gy] = {}
      for gx = 0, columns - 1 do
        layerMap[gy][gx] = occupied[gy] and occupied[gy][gx]
          and columnLayers(gx, gy) or 0
      end
    end
    local function neighbourLayers(gx, gy)
      return layerMap[gy] and layerMap[gy][gx] or 0
    end
    for gy = 0, rows - 1 do
      for gx = 0, columns - 1 do
        if occupied[gy] and occupied[gy][gx] then
          local ax, bx = (gx+gap)/columns, (gx+1-gap)/columns
          local at, ab = (gy+gap)/rows, (gy+1-gap)/rows
          local xa, xb = x0 + (x1-x0)*ax, x0 + (x1-x0)*bx
          local yt = y0 + visibleHeight*(1-at)
          local yb = y0 + visibleHeight*(1-ab)
          local ua, ub = u0 + (u1-u0)*ax, u0 + (u1-u0)*bx
          local vt, vb = v0 + (v1-v0)*at, v0 + (v1-v0)*ab
          local layers = layerMap[gy][gx]
          local depth = voxelCubes and layers * cubeDepth or .42
          local zBack = voxelCubes and -cubeDepth * .5 or 0
          local zFront = voxelCubes and zBack + depth or depth
          local function quad(a,b,c,d)
            local base = #verts / 4
            verts[#verts+1], verts[#verts+2] = a, b
            verts[#verts+1], verts[#verts+2] = c, d
            Voxel3D.pushQuad(indices, base)
          end
          quad({xa,yb,zFront,ua,vb,1}, {xb,yb,zFront,ub,vb,1},
               {xb,yt,zFront,ub,vt,1}, {xa,yt,zFront,ua,vt,1})
          local black = .035
          if not voxelCubes then
            quad({xb,yb,zBack,ub,vb,black}, {xa,yb,zBack,ua,vb,black},
                 {xa,yt,zBack,ua,vt,black}, {xb,yt,zBack,ub,vt,black})
          end
          local function exposedStart(nx, ny)
            local neighbour = voxelCubes and neighbourLayers(nx, ny) or 0
            return neighbour < layers and zBack + neighbour * cubeDepth or nil
          end
          local zs = exposedStart(gx - 1, gy)
          if zs then quad({xa,yb,zs,ua,vb,black}, {xa,yb,zFront,ua,vb,black},
            {xa,yt,zFront,ua,vt,black}, {xa,yt,zs,ua,vt,black}) end
          zs = exposedStart(gx + 1, gy)
          if zs then quad({xb,yb,zFront,ub,vb,black}, {xb,yb,zs,ub,vb,black},
            {xb,yt,zs,ub,vt,black}, {xb,yt,zFront,ub,vt,black}) end
          zs = exposedStart(gx, gy - 1)
          if zs then quad({xa,yt,zFront,ua,vt,black}, {xb,yt,zFront,ub,vt,black},
            {xb,yt,zs,ub,vt,black}, {xa,yt,zs,ua,vt,black}) end
          zs = exposedStart(gx, gy + 1)
          if zs then quad({xa,yb,zs,ua,vb,black}, {xb,yb,zs,ub,vb,black},
            {xb,yb,zFront,ub,vb,black}, {xa,yb,zFront,ua,vb,black}) end
        end
      end
    end
  elseif not voxelFinish then
    verts = {
      {x0,y0,0,u0,v1,1}, {x1,y0,0,u1,v1,1},
      {x1,y0+visibleHeight,0,u1,v0,1},
      {x0,y0+visibleHeight,0,u0,v0,1},
    }
    Voxel3D.pushQuad(indices, 0)
  else
    -- A shallow four-facet relief keeps the approved painting intact while
    -- making VASC's light respond in broad low-poly planes. It is deliberately
    -- not a silhouette offset: transparent pixels remain transparent and no
    -- black halo can appear around the authored outline.
    local shades = { .91, 1.0, .97, .89 }
    local depths = { 0, .18, .24, .15, 0 }
    for segment = 0, 3 do
      local a, b = segment / 4, (segment + 1) / 4
      local xa, xb = x0 + (x1-x0)*a, x0 + (x1-x0)*b
      local ua, ub = u0 + (u1-u0)*a, u0 + (u1-u0)*b
      local base = #verts / 4
      local shade = neutral and 1 or shades[segment + 1]
      verts[#verts+1] = {xa,y0,depths[segment+1],ua,v1,shade}
      verts[#verts+1] = {xb,y0,depths[segment+2],ub,v1,shade}
      verts[#verts+1] = {xb,y0+visibleHeight,depths[segment+2],ub,v0,shade}
      verts[#verts+1] = {xa,y0+visibleHeight,depths[segment+1],ua,v0,shade}
      Voxel3D.pushQuad(indices, base)
    end
  end
  return Voxel3D.newMesh(verts, indices)
end

local function spriteMetrics(Assets, def, frame, dex)
  -- Eevee uses the authored balloon mesh rather than the sprite hull.
  if tonumber(dex) == 133 then return 17.15, .10 end
  -- Procedural humanoids have a known authored range independent of the
  -- source sprite's transparent padding.
  if not tostring(def.image or ""):lower():match("follower_%d+") then
    return 16.1, .10
  end
  local ok, imageData = pcall(Assets.imageData, def.image)
  if not ok or not imageData then return 16, 0 end
  local iw, ih = imageData:getDimensions()
  local fw, fh = frameSize(def, iw, ih)
  local firstY = math.max(0, math.floor(tonumber(frame) or 0)) * fh
  if firstY + fh > ih then firstY = 0 end
  local top, bottom = fh, 0
  for y = 0, fh - 1 do
    for x = 0, fw - 1 do
      local _, _, _, alpha = imageData:getPixel(x, firstY + y)
      if alpha and alpha > .02 then
        top, bottom = math.min(top, y), math.max(bottom, y + 1)
      end
    end
  end
  if bottom <= top then return 16, 0 end
  local unit = 16 / fh
  return (bottom - top) * unit, -(fh - bottom) * unit
end

local function unmirrorCardMatrix(model)
  if not mirroredMatrix(model) then return model end
  local corrected = matMul(model, translate(8, 0, 0))
  corrected = matMul(corrected, scale(-1, 1, 1))
  return matMul(corrected, translate(-8, 0, 0))
end

local function translatedModel(model, dx, dz, dy)
  if type(model) ~= "table" or #model < 16
      or (dx == 0 and dz == 0 and (dy == nil or dy == 0)) then return model end
  local shifted = {}
  for index = 1, 16 do shifted[index] = model[index] end
  shifted[4] = (tonumber(shifted[4]) or 0) + dx
  shifted[8] = (tonumber(shifted[8]) or 0) + (dy or 0)
  shifted[12] = (tonumber(shifted[12]) or 0) + dz
  return shifted
end

-- Existing A/B walk renders are also the only authored wing positions in the
-- 4x3 source contract. Use them slowly while an obvious winged follower is
-- idle, rather than leaving every wing permanently frozen.
local WINGED_FOLLOWER = {
  [12]=true, [15]=true, [41]=true, [42]=true, [49]=true, [83]=true,
  [123]=true, [142]=true, [144]=true, [145]=true, [146]=true, [149]=true,
  [163]=true, [164]=true, [165]=true, [166]=true, [169]=true, [176]=true,
  [177]=true, [178]=true, [193]=true, [207]=true, [225]=true, [226]=true,
  [227]=true, [249]=true, [250]=true, [251]=true,
}

-- Movement always returns through the authored neutral pose.  Apart from
-- looking less mechanical this is important for atlases whose A/B frames
-- contain a large wing, tail or flame excursion: jumping directly A -> B
-- reads as a two-frame flicker rather than a step cycle.
local function followerMotionColumn(moving, living, dex, now, profile)
  if moving then
    local phase = math.floor(now * 8) % 4
    return phase == 1 and 1 or phase == 3 and 2 or 0
  end
  local articulatedIdle = WINGED_FOLLOWER[dex]
    or tostring(profile or ""):find("wing%-flap")
    or tostring(profile or ""):find("fin%-swim")
    or tostring(profile or ""):find("paddle%-bob")
  if living and articulatedIdle then
    local phase = math.floor(now * 3.2) % 4
    return phase == 1 and 1 or phase == 3 and 2 or 0
  end
  return 0
end

local function verifiedCardLayout(layout, groundAnchorHeightFactor)
  if type(layout) ~= "table" then return nil end
  for _, key in ipairs({ "cellWidth", "cellHeight", "left", "top",
      "right", "bottom", "anchorX", "anchorY", "referenceHeight" }) do
    local n = layout[key]
    if type(n) ~= "number" or n ~= n or math.abs(n) == math.huge then return nil end
  end
  if layout.cellWidth < 1 or layout.cellHeight < 1
      or layout.left < 0 or layout.top < 0
      or layout.right > layout.cellWidth or layout.bottom > layout.cellHeight
      or layout.right <= layout.left or layout.bottom <= layout.top
      or layout.anchorX < 0 or layout.anchorX > layout.cellWidth
      or layout.anchorY < 0 or layout.anchorY > layout.cellHeight * (groundAnchorHeightFactor or 1)
      or layout.referenceHeight <= 0 then return nil end
  return layout
end

local function verifiedFlameLayout(cards)
  if type(cards) ~= "table" or cards.verified ~= true
      or type(cards.id) ~= "string" or cards.id == ""
      or type(cards.onSheet) ~= "string" or cards.onSheet == ""
      or type(cards.offSheet) ~= "string" or cards.offSheet == "" then return nil end
  return verifiedCardLayout(cards.layout)
end

local function verifiedAnimationLayout(cards, dex)
  if type(cards) ~= "table" or cards.verified ~= true
      or type(cards.id) ~= "string" or cards.id == "" then return nil end
  local columns = 8
  local denseTag = dex == 41 and "original-zubat-flight-16-v1"
    or dex == 42 and "original-golbat-flight-16-default-v1"
  if denseTag and cards.sourceSampleDensity == denseTag
      and type(cards.idle) == "table" and type(cards.walk) == "table"
      and cards.idle.columns == 16 and cards.walk.columns == 16 then columns = 16 end
  for _, state in ipairs({ "idle", "walk" }) do
    local clip = cards[state]
    if type(clip) ~= "table" or type(clip.sheet) ~= "string" or clip.sheet == ""
        or clip.columns ~= columns or type(clip.duration) ~= "number"
        or clip.duration ~= clip.duration or clip.duration <= 0
        or clip.duration == math.huge then return nil end
  end
  -- Reviewed flying clips may place the original ground root below their
  -- visible cell. The importer proves its shared camera projection; this
  -- finite bounded range permits that without inventing a flight translation.
  return verifiedCardLayout(cards.layout, 2)
end

-- Presentation-only locomotion detection; never changes game coordinates or
-- collision. Native six-frame walkers briefly return to their neutral frame
-- between steps, so retain motion through that interval.
local function cardIsMoving(record, model, now, moving)
  if record.flameObservedAt and now < record.flameObservedAt then
    record.flameMovingUntil = nil
  end
  if type(model) == "table" and #model >= 16 then
    local groundX = model[1] * 8 + model[4]
    local groundZ = model[9] * 8 + model[12]
    if record.flameGroundX and (math.abs(groundX-record.flameGroundX) > .001
        or math.abs(groundZ-record.flameGroundZ) > .001) then moving = true end
    record.flameGroundX, record.flameGroundZ = groundX, groundZ
  end
  if moving then record.flameMovingUntil = now + .25 end
  record.flameObservedAt = now
  return moving or (record.flameMovingUntil ~= nil and now < record.flameMovingUntil)
end

-- APO owns this small presentation shader. VASC's shadowReception API is
-- write-only, so changing sunReceive and guessing its previous value would
-- corrupt a surrounding pass. A separate shader leaves every scene-light
-- uniform intact. Projection, curvature and camera pull match VASC's public
-- scene fields; LOVE retains the caller's canvas, depth and blending state.
local NEUTRAL_CARD_SHADER = [[
varying float cardShade;
#ifdef VERTEX
uniform mat4 vp;
uniform mat4 model;
uniform vec3 eye;
uniform vec3 curve;
uniform float pull;
attribute float VertexShade;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
  cardShade = VertexShade;
  vec4 w = model * vertex_position;
  if (curve.z > 0.0) {
    vec2 cd = w.xz - curve.xy;
    w.y -= dot(cd, cd) * curve.z;
  }
  if (pull > 0.0) w.xyz += normalize(eye - w.xyz) * pull;
  return vp * w;
}
#endif
#ifdef PIXEL
uniform float cardAlphaPass;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  vec4 p = Texel(tex, tc);
  if (cardAlphaPass > 1.5) {
    if (p.a <= 0.001 || p.a >= 0.999) discard;
    return vec4(p.rgb * cardShade, p.a) * color;
  }
  if (cardAlphaPass > 0.5) {
    if (p.a < 0.999) discard;
    return vec4(p.rgb * cardShade, 1.0) * color;
  }
  if (p.a < 0.5) discard;
  return vec4(p.rgb * cardShade, 1.0) * color;
}
#endif
]]

local function vascPatch(self)
  local handle = findMod(self.mod, "VOXEL_ASCENDANT")
  local exports = type(handle) == "table" and handle.exports or nil
  local facade = type(exports) == "table" and exports.lib or nil
  local resolve = type(facade) == "table" and facade.require or nil
  if type(resolve) ~= "function" then return false, "vasc_facade_unavailable" end
  local scene = resolve("VoxelScene")
  local Voxel3D = resolve("Voxel3D")
  local VoxelState = resolve("VoxelState")
  if type(scene) ~= "table" or type(Voxel3D) ~= "table"
      or type(Voxel3D.draw) ~= "function" then
    return false, "vasc_voxel_modules_unavailable"
  end

  local SpriteRenderer = require("src.render.SpriteRenderer")
  local Assets = require("src.render.Assets")
  if type(SpriteRenderer) ~= "table"
      or type(SpriteRenderer.resolveImage) ~= "function" then
    return false, "sprite_identity_seam_unavailable"
  end
  local old = rawget(Voxel3D, PATCH_KEY)
  if old and old.owner == self and type(old.owns) == "function"
      and old.owns() then
    self.vascInstalled = true
    self.vascOwnerCheck = old.owns
    return true
  end
  if old and type(old.restore) == "function" then pcall(old.restore) end

  local originalResolve = SpriteRenderer.resolveImage
  local originalDraw = Voxel3D.draw
  local originalBeginScene = Voxel3D.beginScene
  local originalPreparePokemonFrame = Voxel3D.preparePokemonFrame
  local plannerOk, residencyPlanner = pcall(resolve, "HdResidencyPlan")
  if not plannerOk or type(residencyPlanner) ~= "table"
      or type(residencyPlanner.plan) ~= "function" then residencyPlanner = nil end
  local framePlan, wrappedPreparePokemonFrame
  local originalFlatten = Voxel3D.flatten
  local originalPlayerWalker = scene.requireExternalKascWalker
  local wrappedPlayerWalker
  if self.pikachuRide and type(originalPlayerWalker) == "function" then
    wrappedPlayerWalker = function(...)
      local sprite, route = originalPlayerWalker(...)
      self.renderPlayerSprite = sprite
      return sprite, route
    end
    scene.requireExternalKascWalker = wrappedPlayerWalker
  end
  local sceneShader, flattened, neutralShader
  local styleModule = self.cardStyleModule
  local stylePass = styleModule and styleModule.new()
  local wrappedBeginScene, wrappedFlatten
  local pruneAnimationCache
  -- Only an observed normal scene is eligible. Shadow/effect/ghost passes
  -- keep their native shader; an already active scene waits until next frame.
  if type(originalBeginScene) == "function" then
    wrappedBeginScene = function(...)
      if pruneAnimationCache then pruneAnimationCache() end
      local results = { originalBeginScene(...) }
      local graphics = love and love.graphics
      sceneShader = results[1] and graphics
        and type(graphics.getShader) == "function" and graphics.getShader()
        or nil
      flattened = false
      return unpack(results)
    end
    Voxel3D.beginScene = wrappedBeginScene
  end
  if type(originalFlatten) == "function" then
    wrappedFlatten = function(color, amount, ...)
      local results = { originalFlatten(color, amount, ...) }
      flattened = color ~= nil and (tonumber(amount) or 1) > 0
      return unpack(results)
    end
    Voxel3D.flatten = wrappedFlatten
  end

  local function cardShader(graphics, model, pull)
    if neutralShader == nil then
      local ok, value = pcall(graphics.newShader, NEUTRAL_CARD_SHADER)
      neutralShader = ok and value or false
      if not ok then self.neutralCardError = tostring(value) end
    end
    if not neutralShader then return nil end
    local ok, err = pcall(function()
      neutralShader:send("vp", "row", Voxel3D.vp)
      neutralShader:send("model", "row", model or scale(1, 1, 1))
      neutralShader:send("eye", Voxel3D.eye)
      neutralShader:send("curve", { Voxel3D.curveX or 0,
        Voxel3D.curveZ or 0, Voxel3D.curveK or 0 })
      neutralShader:send("pull", pull or 0)
      neutralShader:send("cardAlphaPass", 0)
    end)
    if not ok then self.neutralCardError = tostring(err) return nil end
    return neutralShader
  end
  local authoredTexture, authoredPalette = authoredPaletteTexture()
  local cardTextures = {}
  for _, role in ipairs({ "red", "green", "blue", "gold", "kris", "silver", "oak" }) do
    local path = self.mod.path .. "/assets/characters/" .. role
      .. "_cards_4x3.png"
    local ok, texture = pcall(Assets.image, path)
    local dataOk, imageData = pcall(Assets.imageData, path)
    if ok and texture and dataOk and imageData then
      local bounds = {}
      for row = 0, 3 do
        bounds[row] = {}
        for column = 0, 2 do
          bounds[row][column] = alphaBounds(imageData, row, column)
        end
      end
      cardTextures[role] = { texture=texture, bounds=bounds }
    end
  end
  local cardMeshes = {}
  local atlasTextures = {}
  local blinkTextures = {}
  local flameTextures = {}
  local animationTextures = {}
  local imageDefs = setmetatable({}, { __mode = "k" })
  local spriteRecords = setmetatable({}, { __mode = "k" })
  local phaseSerial = 0
  local cache = {}

  local function animationClock()
    return love and love.timer and love.timer.getTime and love.timer.getTime() or 0
  end
  local animationQueue = newAnimationQueue(animationClock, .002)
  self.animationPendingGpuBytes, self.animationPendingCpuBytes = 0, 0
  local fallbackQueue = newAnimationQueue(animationClock, .002)
  local fallbackTextures, fallbackWanted = {}, {}
  local FALLBACK_BUDGET = 64*1024*1024
  self.fallbackCacheBytes, self.fallbackPendingGpuBytes, self.fallbackPendingCpuBytes = 0, 0, 0
  local function releaseCardMeshes(key)
    for meshKey, mesh in pairs(cardMeshes) do
      if meshKey:find(key, 1, true) then
        if mesh and type(mesh.release) == "function" then pcall(mesh.release, mesh) end
        cardMeshes[meshKey] = nil
      end
    end
  end
  local function pruneFallbackCache()
    fallbackQueue.prune(fallbackWanted)
    local count, bytes = 0, 0
    for key, source in pairs(fallbackTextures) do
      if not fallbackWanted[key] then
        if source then
          for _, record in pairs(spriteRecords) do
            if record.cardSource == source then record.cardSource = nil end
          end
          releaseCardMeshes(key)
          if source.texture.release then pcall(source.texture.release, source.texture) end
        end
        fallbackTextures[key] = nil
      elseif source then
        count, bytes = count+1, bytes+source.bytes
      end
    end
    self.fallbackCacheBytes, self.fallbackCacheEntries = bytes, count
    self.fallbackPendingPairs = fallbackQueue.pending()
  end
  -- These full-resolution atlases belong to APO, not the engine's permanent
  -- shared image cache. Retire only our unused resources between scene passes.
  -- Visible actors refresh lastUsed whenever their card is resolved.
  pruneAnimationCache = function()
    local now, count, bytes = animationClock(), 0, 0
    animationQueue.prune(framePlan and framePlan.wanted or {})
    for key, sources in pairs(animationTextures) do
      if sources then
        if framePlan and not framePlan.wanted[key]
            or not framePlan and now - sources.lastUsed > 5 then
          for _, record in pairs(spriteRecords) do
            if record.animationSources == sources then record.animationSources = nil end
          end
          releaseCardMeshes(key)
          for _, clip in ipairs({sources.idle, sources.walk}) do
            if clip.owned and type(clip.texture.release) == "function" then
              pcall(clip.texture.release, clip.texture)
            end
          end
          animationTextures[key] = nil
        else
          count = count + 1
          bytes = bytes + (sources.bytes or 0)
        end
      end
    end
    self.animationCacheEntries, self.animationCacheBytes = count, bytes
    self.animationPendingPairs = animationQueue.pending()
    pruneFallbackCache()
  end

  local function flameSources(cards)
    local layout = verifiedFlameLayout(cards)
    if not layout then return nil end
    local keyParts = {cards.id, cards.onSheet, cards.offSheet}
    for _, field in ipairs({ "cellWidth", "cellHeight", "left", "top",
        "right", "bottom", "anchorX", "anchorY", "referenceHeight" }) do
      keyParts[#keyParts+1] = tostring(layout[field])
    end
    local key = table.concat(keyParts, "#")
    if flameTextures[key] == nil then
      local ok, sources = pcall(function()
        local made = {}
        for _, state in ipairs({ "on", "off" }) do
          local path = cards[state .. "Sheet"]
          local texture, data = Assets.image(path), Assets.imageData(path)
          if not (texture and data) then return false end
          local iw, ih = data:getDimensions()
          local tw, th = texture:getDimensions()
          if iw ~= layout.cellWidth*3 or ih ~= layout.cellHeight*4
              or tw ~= iw or th ~= ih then return false end
          local bounds = {}
          for row = 0, 3 do
            bounds[row] = {}
            for column = 0, 2 do
              bounds[row][column] = alphaBounds(data, row, column, 3, layout)
              if not bounds[row][column] then return false end
            end
          end
          made[state] = {texture=texture,bounds=bounds,id=key.."#"..state}
        end
        -- Only confirmed GO render cards enter here; pixel-art sources are
        -- excluded before this loader and retain their nearest filter.
        for _, state in ipairs({ "on", "off" }) do
          local texture = made[state].texture
          if type(texture.setFilter) == "function" then
            pcall(texture.setFilter, texture, "linear", "linear", 8)
          end
        end
        return made
      end)
      flameTextures[key] = ok and sources or false
      if not flameTextures[key] then
        self.flameCardError = "flame_cards_unavailable:" .. cards.id
      end
    end
    return flameTextures[key] or nil
  end

  local function animationDescription(cards, dex)
    local layout = verifiedAnimationLayout(cards, dex)
    if not layout then return nil end
    local keyParts = {cards.id, cards.idle.sheet, cards.walk.sheet,
      tostring(cards.idle.duration), tostring(cards.walk.duration),
      tostring(cards.idle.columns), tostring(cards.walk.columns)}
    for _, field in ipairs({ "cellWidth", "cellHeight", "left", "top",
        "right", "bottom", "anchorX", "anchorY", "referenceHeight" }) do
      keyParts[#keyParts+1] = tostring(layout[field])
    end
    -- Flat and relief HD cards never read occupancy lattices. Compute those
    -- only for the explicit grid/cube presentation; key the distinction so a
    -- live style change cannot reuse incomplete geometry metadata.
    local grid = self.presentationPolicy and self.presentationPolicy:gridEnabled("pokemon") or false
    local key = table.concat(keyParts, "#") .. (grid and "#grid" or "#card")
    return {key=key,layout=layout,grid=grid,bytes=layout.cellWidth*layout.cellHeight*4*4
      *(cards.idle.columns+cards.walk.columns)}
  end

  local function fallbackDescription(def)
    if not (self.mod._vascIntegrated and type(def)=="table"
        and tonumber(def.ascendantPokemonDex or def.pokemonDex)
        and def.ascendantPokemonSpriteSource~="pokemmo"
        and type(def.ascendantAtlasImage)=="string" and def.ascendantAtlasImage~="") then return nil end
    local grid=self.presentationPolicy and self.presentationPolicy:gridEnabled("pokemon") or false
    return {path=def.ascendantAtlasImage,grid=grid,
      key=def.ascendantAtlasImage..(grid and "#fallback-grid" or "#fallback-card")}
  end

  local function queueFallback(description)
    local key=description.key
    if fallbackTextures[key]~=nil then return end
    fallbackQueue.push(key,function()
      local data,texture,cpuBytes,gpuBytes=nil,nil,0,0
      local function cleanup()
        if data and data.release then pcall(data.release,data) end
        if texture and texture.release then pcall(texture.release,texture) end
        self.fallbackPendingCpuBytes=self.fallbackPendingCpuBytes-cpuBytes
        self.fallbackPendingGpuBytes=self.fallbackPendingGpuBytes-gpuBytes
        data,texture,cpuBytes,gpuBytes=nil,nil,0,0
      end
      local function run(checkpoint)
        data=Assets.imageData(description.path)
        if not data then return false end
        local iw,ih=data:getDimensions()
        cpuBytes=iw*ih*4;self.fallbackPendingCpuBytes=self.fallbackPendingCpuBytes+cpuBytes
        -- Existing 3x4 render cards only; reject oversized/malformed sheets
        -- before GPU upload. The tiny engine strip remains available.
        if iw%3~=0 or ih%4~=0 or cpuBytes>16*1024*1024
            or self.fallbackCacheBytes+cpuBytes>FALLBACK_BUDGET then return false end
        checkpoint(true)
        texture=love.graphics.newImage(data)
        if not texture then return false end
        gpuBytes=cpuBytes;self.fallbackPendingGpuBytes=self.fallbackPendingGpuBytes+gpuBytes
        checkpoint(true)
        local bounds={}
        for row=0,3 do
          bounds[row]={}
          for col=0,2 do
            bounds[row][col]=alphaBounds(data,row,col,3,nil,checkpoint,not description.grid)
            if not bounds[row][col] then return false end
          end
        end
        if data.release then data:release() end;data=nil
        self.fallbackPendingCpuBytes=self.fallbackPendingCpuBytes-cpuBytes;cpuBytes=0
        texture:setFilter("linear","linear",8)
        local source={texture=texture,bounds=bounds,id=key,bytes=gpuBytes}
        self.fallbackPendingGpuBytes=self.fallbackPendingGpuBytes-gpuBytes
        texture,gpuBytes=nil,0
        return source
      end
      return run,cleanup
    end,function(source)
      fallbackTextures[key]=source or false
      if source then self.fallbackCacheBytes=self.fallbackCacheBytes+source.bytes end
      if not source then self.fallbackCardError="fallback_card_unavailable" end
    end)
  end

  local function animationSources(cards, dex)
    local description=animationDescription(cards,dex)
    if not description then return nil end
    local key,layout=description.key,description.layout
    -- Frame admission is independent of draw order and covers every direction,
    -- shadow and eye with the original full atlases. No camera-time row decode.
    if framePlan and not framePlan.wanted[key] then return nil end
    -- Integrated loads may only start at the owner-filtered frame boundary,
    -- never once per shadow/eye/draw pass or after a failed admission plan.
    if self.mod._vascIntegrated and not framePlan then return nil end
    if animationTextures[key] == nil then
      -- A scene cannot retain unbounded full-HD pairs. Refuse a new pair
      -- before decoding; the already-bound native strip remains drawable.
      -- Do not evict textures that another actor may still use this frame.
      local resident=0
      for _,pair in pairs(animationTextures)do
        if pair then resident=resident+(pair.bytes or 0)end
      end
      local needed=description.bytes
      local budget=framePlan and framePlan.budgetBytes or 96*1024*1024
      if self.mod._vascIntegrated and resident+needed>budget then
        self.animationCardError="animation_gpu_budget"
        return nil
      end
      local function factory()
        local created, pendingData = {}, {}
        local gpuBytes, cpuBytes = 0, 0
        local function cleanup()
          for _, data in ipairs(pendingData) do
            if type(data.release) == "function" then pcall(data.release, data) end
          end
          for _, texture in ipairs(created) do
            if type(texture.release) == "function" then pcall(texture.release, texture) end
          end
          pendingData, created = {}, {}
          self.animationPendingGpuBytes = self.animationPendingGpuBytes - gpuBytes
          self.animationPendingCpuBytes = self.animationPendingCpuBytes - cpuBytes
          gpuBytes, cpuBytes = 0, 0
        end
        local function run(checkpoint)
        local made = {lastUsed=animationClock(), bytes=0}
        for _, state in ipairs({ "idle", "walk" }) do
          local clip = cards[state]
          local data = Assets.imageData(clip.sheet)
          if data then pendingData[#pendingData+1] = data end
          if not data then return false end
          local iw, ih = data:getDimensions()
          cpuBytes = iw*ih*4
          self.animationPendingCpuBytes = self.animationPendingCpuBytes + cpuBytes
          if iw ~= layout.cellWidth*clip.columns or ih ~= layout.cellHeight*4 then return false end
          if checkpoint then checkpoint(true) end
          local owned = love and love.graphics and type(love.graphics.newImage) == "function"
          local texture = data and (owned and love.graphics.newImage(data) or Assets.image(clip.sheet))
          if owned and texture then
            created[#created+1] = texture
            gpuBytes = gpuBytes + iw*ih*4
            self.animationPendingGpuBytes = self.animationPendingGpuBytes + iw*ih*4
          end
          if checkpoint then checkpoint(true) end
          if not (texture and data) then return false end
          local tw, th = texture:getDimensions()
          if tw ~= iw or th ~= ih then return false end
          local bounds = {}
          for row = 0, 3 do
            bounds[row] = {}
            for column = 0, clip.columns-1 do
              bounds[row][column] = alphaBounds(data, row, column, clip.columns, layout, checkpoint, not description.grid)
              if not bounds[row][column] then return false end
            end
          end
          made[state] = {texture=texture,bounds=bounds,id=key.."#"..state,
            columns=clip.columns,duration=clip.duration,owned=owned}
          made.bytes = made.bytes + iw*ih*4
          if type(data.release) == "function" then data:release() end
          pendingData[#pendingData] = nil
          self.animationPendingCpuBytes = self.animationPendingCpuBytes - cpuBytes
          cpuBytes = 0
        end
        for _, state in ipairs({ "idle", "walk" }) do
          if type(made[state].texture.setFilter) == "function" then
            pcall(made[state].texture.setFilter, made[state].texture, "linear", "linear", 8)
          end
        end
        self.animationPendingGpuBytes = self.animationPendingGpuBytes - gpuBytes
        gpuBytes = 0
        return made
        end
        return run, cleanup
      end
      local function complete(sources)
        animationTextures[key] = sources or false
        if sources then sources.lastUsed=animationClock()
        else self.animationCardError = "animation_cards_unavailable:" .. cards.id end
      end
      if self.mod._vascIntegrated then
        animationQueue.push(key, factory, complete)
      else
        local run, cleanup = factory()
        local ok, sources = pcall(run)
        if not ok or not sources then cleanup() end
        complete(ok and sources)
      end
    end
    if animationTextures[key] then animationTextures[key].lastUsed = animationClock() end
    pruneAnimationCache()
    return animationTextures[key] or nil
  end

  if self.mod._vascIntegrated and residencyPlanner then
    wrappedPreparePokemonFrame=function(world,posed)
      if type(originalPreparePokemonFrame)=="function" then
        pcall(originalPreparePokemonFrame,world,posed)
      end
      local descriptions, fallbackCandidates={},{}
      local ok,value=pcall(function()
        local actors={}
        local player=world and world.player
        local px,py=tonumber(player and player.px) or 0,tonumber(player and player.py) or 0
        for _,pose in ipairs(posed or {})do
          local def=pose.sprite and pose.sprite.def
          if type(def)=="table" and def.ascendantPokemonSpriteSource~="pokemmo"
              and not (pose.stadiumMon and pose.stadiumMatrix)then
            local dx,dy=(tonumber(pose.px) or px)-px,(tonumber(pose.py) or py)-py
            local description=animationDescription(def.ascendantPokemonAnimationCards,
              tonumber(def.ascendantPokemonDex) or tonumber(def.pokemonDex))
            local fallback=fallbackDescription(def)
            if fallback then fallbackCandidates[#fallbackCandidates+1]={description=fallback,
              animationKey=description and description.key,context=def.ascendantPokemonContext,
              distance=dx*dx+dy*dy} end
            if description then
              descriptions[description.key]={cards=def.ascendantPokemonAnimationCards,
                dex=tonumber(def.ascendantPokemonDex) or tonumber(def.pokemonDex)}
              actors[#actors+1]={key=description.key,bytes=description.bytes,
                context=def.ascendantPokemonContext,distance=dx*dx+dy*dy}
            end
          end
        end
        return assert(residencyPlanner.plan(actors,residencyPlanner.BUDGET_BYTES))
      end)
      if ok then
        framePlan=value;self.animationResidencyError=nil
        self.animationResidency={budgetBytes=value.budgetBytes,plannedBytes=value.bytes,
          requestedActors=value.requestedActors,admittedActors=value.admittedActors,
          rejectedActors=value.rejectedActors,admittedPairs=value.admittedPairs}
      else
        -- Contain optional visual planning faults; never suppress the world.
        framePlan=nil;self.animationResidencyError="frame_plan_failed"
        self.animationResidency=nil
      end
      local fallbackOrder, fallbackDefinitions={},{}
      fallbackWanted={}
      if framePlan then
        local actors={}
        for _,entry in ipairs(fallbackCandidates) do
          -- An admitted animation needs no extra static atlas while loading:
          -- use its existing native strip until the complete pair is ready.
          if not entry.animationKey or not framePlan.wanted[entry.animationKey]
              or animationTextures[entry.animationKey]==false then
            local key=entry.description.key
            actors[#actors+1]={key=key,bytes=1,context=entry.context,distance=entry.distance}
            fallbackDefinitions[key]=entry.description
          end
        end
        -- Unit weights order metadata only. Actual byte admission occurs
        -- against FALLBACK_BUDGET before each native GPU allocation.
        local ok,ordered=pcall(residencyPlanner.plan,actors,256)
        if ok and ordered then fallbackWanted,fallbackOrder=ordered.wanted,ordered.orderedKeys end
      end
      pruneAnimationCache()
      if framePlan then
        for _,key in ipairs(framePlan.orderedKeys) do
          local entry=descriptions[key]
          animationSources(entry.cards,entry.dex)
        end
        animationQueue.pump(framePlan.orderedKeys)
        pruneAnimationCache()
        for _,key in ipairs(fallbackOrder) do queueFallback(fallbackDefinitions[key]) end
        fallbackQueue.pump(fallbackOrder)
        pruneFallbackCache()
      end
    end
    Voxel3D.preparePokemonFrame=wrappedPreparePokemonFrame
  end

  local function resolveImage(sprite)
    local image = originalResolve(sprite)
    local def = sprite and sprite.def or nil
    local identity = identityFromDef(def)
    local heroRole = heroRoleFromIdentity(self.generation, identity)
    local hasAtlas = type(def) == "table"
      and type(def.ascendantAtlasImage) == "string"
      and def.ascendantAtlasImage ~= ""
    -- Only artwork explicitly bound by this mod is ours to decorate. Vanilla
    -- walkers must remain VASC's ordinary flat 2D billboards; claiming every
    -- walker here produced the unwanted procedural "3D people" fallback.
    -- Known protagonists are the sole exception: KASC/JASC may recreate the
    -- player's renderer after our binding event, so their published sprite ID
    -- must reconnect to the fixed approved hero atlas without a saved preview.
    if image and walker(def) and (hasAtlas or heroRole ~= nil) then
      local record = spriteRecords[sprite]
      if not record then
        phaseSerial = phaseSerial + 1
        local seed = tostring(sprite.seed or "")
        local phase = phaseSerial * .61803398875
        if seed ~= "" then
          local hash = 0
          for index = 1, #seed do hash = (hash*131+seed:byte(index)) % 104729 end
          phase = hash / 104729
        end
        record = { def=sprite.def, flamePhase=phase % 1 }
        spriteRecords[sprite] = record
      end
      record.def = sprite.def
      record.sprite = sprite
      record.isPlayer = sprite.seed == "player"
      local boundPhase = tonumber(sprite.def.ascendantPokemonFlamePhase)
      if boundPhase and boundPhase == boundPhase and math.abs(boundPhase) < math.huge then
        record.flamePhase = boundPhase % 1
      end
      local animationPhase = tonumber(sprite.def.ascendantPokemonAnimationPhase)
      record.animationPhase = animationPhase and animationPhase == animationPhase
        and math.abs(animationPhase) < math.huge and animationPhase % 1 or record.flamePhase
      record.role = visualRoleForDef(self.generation, sprite.def, record.role)
      record.scaleClass = sprite.def.ascendantScaleClass
      -- Use the delivered source, including a quarantined GO asset's safe
      -- PokeMMO replacement. The user's HD preference does not turn pixel
      -- artwork into a model render; interpolation would blur its detail.
      local pixelArt = sprite.def.ascendantPokemonSpriteSource == "pokemmo"
      local textureFilter = pixelArt and "nearest" or "linear"
      local anisotropy = pixelArt and 1 or 8
      local atlasPath = sprite.def.ascendantAtlasImage
      record.flameSources = not pixelArt
        and flameSources(sprite.def.ascendantPokemonFlameCards) or nil
      record.animationSources = not pixelArt and not record.flameSources
        and animationSources(sprite.def.ascendantPokemonAnimationCards,
          tonumber(sprite.def.ascendantPokemonDex)
            or tonumber(sprite.def.pokemonDex)) or nil
      record.cardSource = nil
      local ownedFallback=fallbackDescription(sprite.def)
      if ownedFallback then
        record.cardSource=fallbackTextures[ownedFallback.key] or nil
      elseif not record.flameSources and not record.animationSources
          and type(atlasPath) == "string" and atlasPath ~= "" then
        if atlasTextures[atlasPath] == nil then
          local textureOk, atlasTexture = pcall(Assets.image, atlasPath)
          local dataOk, atlasData = pcall(Assets.imageData, atlasPath)
          if textureOk and atlasTexture and dataOk and atlasData then
            -- Smooth the GO/HD render cards while retaining nearest-neighbour
            -- sampling for PokeMMO's deliberately pixel-authored atlases.
            if type(atlasTexture.setFilter) == "function" then
              pcall(atlasTexture.setFilter, atlasTexture,
                textureFilter, textureFilter, anisotropy)
            end
            local bounds = {}
            for row = 0, 3 do
              bounds[row] = {}
              for column = 0, 2 do
                bounds[row][column] = alphaBounds(atlasData, row, column)
              end
            end
            atlasTextures[atlasPath] = { texture=atlasTexture, bounds=bounds }
          else
            atlasTextures[atlasPath] = false
          end
        end
        record.cardSource = atlasTextures[atlasPath] or nil
      end
      record.dex = tonumber(sprite.def.ascendantPokemonDex)
        or tonumber(sprite.def.pokemonDex)
        or tonumber(tostring(sprite.def.image or ""):match("follower_0*(%d+)"))
      record.motionProfile = sprite.def.ascendantPokemonMotionProfile
      local blinkPath = sprite.def.ascendantPokemonBlinkSourceExact == true
        and sprite.def.ascendantPokemonBlinkSheet or nil
      record.blinkSource = nil
      if type(blinkPath) == "string" and blinkPath ~= "" then
        if blinkTextures[blinkPath] == nil then
          local textureOk, blinkTexture = pcall(Assets.image, blinkPath)
          local dataOk, blinkData = pcall(Assets.imageData, blinkPath)
          if textureOk and blinkTexture and dataOk and blinkData then
            if type(blinkTexture.setFilter) == "function" then
              pcall(blinkTexture.setFilter, blinkTexture,
                textureFilter, textureFilter, anisotropy)
            end
            local bounds = {}
            for row = 0, 3 do
              bounds[row] = {}
              for column = 0, 3 do
                bounds[row][column] = alphaBounds(blinkData, row, column, 4)
              end
            end
            blinkTextures[blinkPath] = { texture=blinkTexture, bounds=bounds,
              id=blinkPath }
          else
            blinkTextures[blinkPath] = false
          end
        end
        record.blinkSource = blinkTextures[blinkPath] or nil
      end
      if sprite.seed == "player" then
        -- Identity is selected once by WalkingSprites. Rendering must never
        -- consult a second saved preview value: that stale cross-edition seam
        -- was able to turn Gen 1 Red into Kris without JASC being active.
        record.role = playerRoleForGeneration(self.generation, record.role,
          identity)
      end
      imageDefs[image] = record
    elseif image then
      -- A native actor may share an image with an APO actor. Only the exact
      -- renderer resolved immediately before this draw owns its metadata.
      imageDefs[image] = nil
    end
    return image
  end

  local function replacement(def, frame, role, motionPhase, dex)
    local cacheKey = table.concat({ tostring(def.image), tostring(def.frames or ""),
      tostring(def.frameWidth or ""), tostring(def.frameHeight or ""),
      tostring(frame), tostring(role or "actor"), tostring(motionPhase or 0),
      tostring(dex or "") }, "#")
    if cache[cacheKey] == nil then
      local ok, value = pcall(buildVoxelMesh, Voxel3D, Assets, def, frame,
        role, authoredPalette, motionPhase)
      local nominalHeight, baseLift = spriteMetrics(Assets, def, frame, dex)
      cache[cacheKey] = ok and value and {
        mesh=value,
        texture=role == "red" and authoredTexture or nil,
        nominalHeight=nominalHeight,
        baseLift=baseLift,
      } or false
    end
    return cache[cacheKey] or nil
  end

  local function draw(mesh, texture, model, pull, sunModel)
    local record = texture and imageDefs[texture] or nil
    local def = record and record.def or nil
    local function correctedDraw(drawMesh, drawTexture, drawModel, drawPull,
        drawSunModel, ownedCard, styleSpec)
      local graphics = love and love.graphics
      local neutral = (styleSpec ~= nil or not option(self.mod, "atmospheric_sprite_shading", false))
        and ownedCard and sceneShader and not flattened
      local oldR, oldG, oldB, oldA
      local previousShader
      local alphaShader, previousBlend, previousAlphaMode
      -- Reviewed Beedrill/Scyther wings and Gastly/Koffing/Weezing gas are translucent.
      -- Keep this explicit to their source-animation cards: opaque body
      -- pixels write depth; wing pixels blend without becoming invisible or
      -- writing an opaque rectangular occluder. Other species stay unchanged.
      local originalWingAlpha = ownedCard and record
        and (record.dex == 15 or record.dex == 123 or record.dex == 92
          or record.dex == 109 or record.dex == 110)
        and record.animationSources ~= nil
      if neutral and graphics and type(graphics.getColor) == "function"
          and type(graphics.setColor) == "function"
          and type(graphics.getShader) == "function"
          and type(graphics.setShader) == "function"
          and type(graphics.newShader) == "function"
          and type(graphics.getDepthMode) == "function"
          and graphics.getShader() == sceneShader then
        local depth, writes = graphics.getDepthMode()
        -- Ghosts use greater/no-write; additive effects also disable writes.
        if depth == "lequal" and writes == true then
          local shader = styleSpec and stylePass
            and stylePass:prepare(graphics, Voxel3D, drawModel, drawPull, styleSpec)
            or nil
          if styleSpec and not shader then self.cardStyleError = stylePass and stylePass.error end
          shader = shader or cardShader(graphics, drawModel, drawPull)
          if shader then
            previousShader = sceneShader
            oldR, oldG, oldB, oldA = graphics.getColor()
            graphics.setShader(shader)
            graphics.setColor(1, 1, 1, oldA or 1)
            if originalWingAlpha and type(graphics.setDepthMode) == "function"
                and type(graphics.getBlendMode) == "function"
                and type(graphics.setBlendMode) == "function" then
              alphaShader = shader
              previousBlend, previousAlphaMode = graphics.getBlendMode()
              graphics.setBlendMode("alpha", "alphamultiply")
              shader:send("cardAlphaPass", 1)
            end
          end
        end
      end
      local results = { pcall(function()
        local result = { originalDraw(drawMesh, drawTexture, drawModel,
          drawPull, drawSunModel) }
        if alphaShader then
          graphics.setDepthMode("lequal", false)
          alphaShader:send("cardAlphaPass", 2)
          originalDraw(drawMesh, drawTexture, drawModel, drawPull, drawSunModel)
        end
        return unpack(result)
      end) }
      if alphaShader then
        alphaShader:send("cardAlphaPass", 0)
        graphics.setDepthMode("lequal", true)
        graphics.setBlendMode(previousBlend, previousAlphaMode)
      end
      if previousShader then graphics.setShader(previousShader) end
      if oldR and graphics then graphics.setColor(oldR, oldG, oldB, oldA) end
      if not results[1] then error(results[2], 0) end
      return unpack(results, 2)
    end
    if def then
      local frame = frameFromCard(mesh, def, texture)
        local cardSource = record.flameSources and record.flameSources.on
          or record.animationSources and record.animationSources.idle
          or record.cardSource or cardTextures[record.role]
      local cardTexture = cardSource and cardSource.texture
      if frame and cardTexture then
        local direction = frame % 3
        local mirrored = mirroredMatrix(model)
        -- Atlas rows: front, left, back, right. Columns: neutral, A, B.
        local row = direction == 0 and 0
          or direction == 1 and 2
          or (mirrored and 3 or 1)
        local spacingX, spacingZ, spacingMoving = 0, 0, false
        -- A matrix position is not actor identity: passable followers can
        -- occupy the player's cell. Applying their render-only trail offset
        -- to every card there also displaced humans onto walls/ledges.
        -- Only an explicitly bound Pokemon follower may use this bridge.
        if record.dex and def.ascendantPokemonContext == "follower"
            and self.followerSpacing
            and type(self.followerSpacing.vascOffset) == "function" then
          spacingX, spacingZ, spacingMoving =
            self.followerSpacing:vascOffset(model)
        end
        local now = love and love.timer and love.timer.getTime
          and love.timer.getTime() or 0
        -- Every authored Pokemon card may idle, including fixed route/city
        -- actors. Follower ownership only controls spacing, never liveliness.
        local living = record.dex ~= nil
          and option(self.mod, "living_follower_animation", true)
        local column = followerMotionColumn(frame >= 3 or spacingMoving,
          living, record.dex, now, record.motionProfile)
        local flameState
        local animationState
        local cardMoving = frame >= 3 or spacingMoving
        if record.flameSources or record.animationSources then
          cardMoving = cardIsMoving(record, model, now, cardMoving)
        end
        local rideVisual = self:_rideOffset(record, model, spacingX, spacingZ, now)
        if rideVisual then
          cardMoving = false
          row = self.playerRideAnchor.row or row
        end
        if record.flameSources then
          -- Native walking alternates a walk frame with a neutral frame.
          -- Keep that neutral interval lit, including ambient actors without
          -- follower-spacing metadata. Track only presentation state here.
          flameState = "on"
          if living and not cardMoving
              and ((now / 12 + record.flamePhase) % 1) < 5/12 then
            flameState = "off"
          end
          if not living then column = 0 end
          cardSource = record.flameSources[flameState]
        elseif record.animationSources then
          animationState = living and cardMoving and "walk" or "idle"
          cardSource = record.animationSources[animationState]
          -- Authored TRS samples retain their source duration. Different actors
          -- can share the image while keeping independently seeded idle cycles.
          column = living and math.floor(((now / cardSource.duration
            + record.animationPhase) % 1) * cardSource.columns) or 0
        end
        -- Source-exact blink sidecars are one-shot 4x4 sheets.  A stable
        -- per-variant interval avoids lockstep blinking without inventing a
        -- single pixel. Variants without a verified sidecar stay on breathing.
        local blinkColumn
        if living and not record.flameSources and not record.animationSources and not spacingMoving
            and frame < 3 and record.blinkSource then
          local paletteSeed = def.ascendantPokemonPalette == "shiny" and .83 or 0
          local interval = 3.5 + ((record.dex or 0) * .173 + paletteSeed) % 4
          local blinkTime = (now + (record.dex or 0) * .271 + paletteSeed) % interval
          if blinkTime < .0666667 then blinkColumn = 0
          elseif blinkTime < .2 then blinkColumn = 2
          elseif blinkTime < .233334 then blinkColumn = 1 end
        end
        local activeSource = blinkColumn ~= nil and record.blinkSource or cardSource
        local activeColumn = blinkColumn ~= nil and blinkColumn or column
        local visibleHeight = tonumber(def.ascendantWorldHeight)
        if visibleHeight and (visibleHeight ~= visibleHeight or visibleHeight <= 0
            or visibleHeight == math.huge) then visibleHeight = nil end
        if visibleHeight then
          -- Use the same explicit body height as the native renderer and
          -- follower spacing; do not overwrite it with a broad size tier.
        elseif record.scaleClass and self.scaleProfiles
            and self.scaleProfiles.worldHeightForClass then
          visibleHeight = self.scaleProfiles.worldHeightForClass(record.scaleClass)
        else
          visibleHeight = self.scaleProfiles
            and self.scaleProfiles.worldHeight(record.role) or 16
        end
        self:_rememberPlayerAnchor(record, model, visibleHeight, now, row)
        local finishOption = record.dex and "voxel_pokemon_finish"
          or "voxel_character_finish"
        local voxelFinish = option(self.mod, finishOption, true)
        local neutral = not option(self.mod, "atmospheric_sprite_shading", false)
        local actorKind = record.dex and "pokemon" or "characters"
        local voxelGrid = self.presentationPolicy
          and self.presentationPolicy:gridEnabled(actorKind) or false
        local voxelCubes = cubeProfile(self.mod)
        local bounds = activeSource.bounds[row][activeColumn]
        local styleSpec, styleDescriptor
        if styleModule and not voxelGrid and not record.flameSources then
          local source = def.ascendantPokemonSpriteSource
          styleSpec = {
            mode=choice(self.mod, "pokemon_card_style", "off"),
            source=(source == "pokemon_go_549" or source == "pokemon_go_legacy") and "go" or source,
            kind=record.animationSources and "animation-cards" or "hd-cards",
            pixelArt=source == "pokemmo", legacyCyndaquil=record.dex == 155,
            imageWidth=bounds.imageWidth, imageHeight=bounds.imageHeight,
            columns=activeSource.columns or (blinkColumn ~= nil and 4 or 3),
            row=row, column=activeColumn,
          }
          styleDescriptor = styleModule.descriptor(styleSpec)
          if not styleDescriptor then styleSpec = nil end
        end
        local styleHeightFactor = 1
        if styleDescriptor then
          bounds, styleHeightFactor = styleModule.paddedBounds(bounds, styleDescriptor)
          neutral = true
        end
        local key = table.concat({ record.role, row, activeColumn,
          visibleHeight, tostring(voxelFinish), tostring(voxelGrid),
          tostring(neutral),
          styleDescriptor and styleDescriptor.mode or "original",
          tostring(voxelCubes and (voxelCubes.depth .. ":" .. voxelCubes.layers)
            or false),
          tostring(activeSource.id or def.ascendantAtlasImage or "builtin") }, "#")
        if cardMeshes[key] == nil then
          cardMeshes[key] = atlasCardMesh(Voxel3D,
            bounds, visibleHeight * styleHeightFactor, voxelFinish,
            voxelGrid, voxelCubes, neutral)
            or false
        end
        local card = cardMeshes[key] or nil
        if card then
          if record.animationSources then
            local id = def.ascendantPokemonAnimationCards.id
            local seen = self.animationObservations[id]
            if not seen then
              if #self.animationObservationOrder >= 64 then
                self.animationObservations[table.remove(self.animationObservationOrder, 1)] = nil
              end
              seen = {dex=record.dex, palette=def.ascendantPokemonPalette,
                idle={}, walk={}, frames=0}
              self.animationObservations[id] = seen
              self.animationObservationOrder[#self.animationObservationOrder+1] = id
            end
            seen[animationState][activeColumn] = true
            seen.frames, seen.lastState, seen.lastPhase = seen.frames+1, animationState, activeColumn
          end
          -- A tiny foot-anchored vertical stretch reads as breathing.  An
          -- authored airborne profile also receives a stable clearance above
          -- the floor, plus a shallow hover wave while moving or idle.  This
          -- changes only presentation: path, collision and owner coordinates
          -- remain on the canonical walked tile.
          local breathScale, breathLift = 1, 0
          local profile = tostring(record.motionProfile or "")
          local wave = (math.sin(now * 2.15 + (record.dex or 0) * .37) + 1) / 2
          if living and not record.animationSources and profile:find("airborne") then
            breathScale = 1 + wave * .008
            breathLift = 1.35 + wave * .32
          elseif living and not record.animationSources and profile:find("hover%-bob") then
            breathScale = 1 + wave * .008
            breathLift = .22 + wave * .20
          elseif living and not record.animationSources and not spacingMoving and frame < 3 then
            if profile:find("paddle%-bob") then
              breathScale = 1 + wave * .008
              breathLift = wave * .18
            elseif profile:find("serpentine") or profile:find("sway") then
              breathScale = 1 + wave * .009
              breathLift = wave * .04
            else
              breathScale = 1 + wave * .012
              breathLift = wave * .07
            end
          end
          -- The atlas already contains separate left/right and A/B renders;
          -- cancel the engine's sheet mirror so it is not applied twice.
          local cardModel = translatedModel(unmirrorCardMatrix(model),
            spacingX + (rideVisual and rideVisual.dx or 0),
            spacingZ + (rideVisual and rideVisual.dz or 0),
            breathLift + (rideVisual and rideVisual.dy or 0))
          local cardSun = translatedModel(unmirrorCardMatrix(sunModel),
            spacingX + (rideVisual and rideVisual.dx or 0),
            spacingZ + (rideVisual and rideVisual.dz or 0),
            breathLift + (rideVisual and rideVisual.dy or 0))
          if breathScale ~= 1 then
            cardModel = matMul(cardModel, scale(1, breathScale, 1))
            cardSun = matMul(cardSun, scale(1, breathScale, 1))
          end
          if self.debugLog and type(self.debugLog.event) == "function"
              and record.dex then
            local moving = cardMoving
            local clip = animationState and ("source-" .. animationState)
              or flameState and ("fire-" .. flameState)
              or blinkColumn ~= nil and "blink"
              or moving and "walk"
              or activeColumn ~= 0 and "idle-articulated"
              or "idle-breathe"
            pcall(self.debugLog.event, self.debugLog, "ANIMATION", {
              species=def.pokemonSpecies or record.dex,
              palette=def.ascendantPokemonPalette,
              source=def.ascendantPokemonSpriteSource or "ascendant_hd",
              provider=activeSource.id or def.ascendantAtlasImage,
              animation=record.motionProfile or "card-cycle",
              clip=clip, state=moving and "moving" or "idle",
              style=styleDescriptor and styleDescriptor.mode or "original",
              presentation=rideVisual and rideVisual.state or "ground",
              phase=activeColumn, frame=frame,
              context=def.ascendantPokemonContext,
              decision="render-card",
            }, self.activeGame)
          end
          return correctedDraw(card, activeSource.texture, cardModel, pull,
            cardSun, true, styleSpec)
        end
      end
      -- If an authored atlas cannot be loaded, retain the engine's flat card.
      -- Never synthesize a humanoid mesh from a six-frame fallback strip.
    end
    return correctedDraw(mesh, texture, model, pull, sunModel)
  end

  SpriteRenderer.resolveImage = resolveImage
  Voxel3D.draw = draw
  local state = { owner=self, resolve=resolveImage, draw=draw }
  function state.owns()
    return SpriteRenderer.resolveImage == resolveImage and Voxel3D.draw == draw
      and (not wrappedBeginScene or Voxel3D.beginScene == wrappedBeginScene)
      and (not wrappedFlatten or Voxel3D.flatten == wrappedFlatten)
      and (not wrappedPlayerWalker or scene.requireExternalKascWalker == wrappedPlayerWalker)
      and (not wrappedPreparePokemonFrame or Voxel3D.preparePokemonFrame == wrappedPreparePokemonFrame)
  end
  function state.restore()
    if wrappedPreparePokemonFrame and Voxel3D.preparePokemonFrame==wrappedPreparePokemonFrame then
      Voxel3D.preparePokemonFrame=originalPreparePokemonFrame
    end
    framePlan={wanted={}}
    fallbackWanted={}
    pruneAnimationCache()
    if wrappedPlayerWalker and scene.requireExternalKascWalker == wrappedPlayerWalker then
      scene.requireExternalKascWalker = originalPlayerWalker
    end
    if SpriteRenderer.resolveImage == resolveImage then
      SpriteRenderer.resolveImage = originalResolve
    end
    if Voxel3D.draw == draw then Voxel3D.draw = originalDraw end
    if wrappedBeginScene and Voxel3D.beginScene == wrappedBeginScene then
      Voxel3D.beginScene = originalBeginScene
    end
    if wrappedFlatten and Voxel3D.flatten == wrappedFlatten then
      Voxel3D.flatten = originalFlatten
    end
    if rawget(Voxel3D, PATCH_KEY) == state then Voxel3D[PATCH_KEY] = nil end
  end
  Voxel3D[PATCH_KEY] = state
  self.vascInstalled = true
  self.vascRestore = state.restore
  self.vascOwnerCheck = state.owns
  return true
end

local function actorCentre(entity)
  if not entity then return nil end
  local x = tonumber(entity.px) or tonumber(entity.cellX) and entity.cellX * 16
  local z = tonumber(entity.py) or tonumber(entity.cellY) and entity.cellY * 16
  if not x or not z then return nil end
  return x + 8, z + 8
end

local function matrixFoot(model)
  if type(model) ~= "table" or #model < 16 then return nil end
  return model[1] * 8 + model[4], model[5] * 8 + model[8],
    model[9] * 8 + model[12]
end

function VoxelCharacters:_rememberPlayerAnchor(record, model, height, now, row)
  if not self.pikachuRide or record.dex then return end
  local game = self.activeGame
  local world = game and (game.overworld or game.world)
  local player = world and world.player
  if not player or not player.sprite then return end
  if player.sprite.def ~= record.def and record.isPlayer ~= true
      and not (self.renderPlayerSprite and record.sprite == self.renderPlayerSprite) then return end
  local px, pz = actorCentre(player)
  local x, y, z = matrixFoot(model)
  if not x or not px then return end
  if math.abs(x-px) + math.abs(z-pz) > 2.5 then
    self.playerAnchorError = "position-delta:"..tostring(x-px)..":"..tostring(z-pz)
    return
  end
  self.playerAnchorError = nil
  self.playerRideAnchor = {player=player, world=world, map=world.map,
    -- The head lies on the camera-leaned card, not directly above its feet.
    -- Transform that actual local head point, including the Y basis' X/Z.
    x=x+model[2]*height, y=y, z=z+model[10]*height,
    nativeX=px, nativeZ=pz, height=model[6]*height, row=row, at=now}
end

function VoxelCharacters:_cancelRide(now)
  self.playerRideAnchor = nil
  if self.pikachuRide then self.pikachuRide:sample({now=now, enabled=false}) end
end

function VoxelCharacters:_rideOffset(record, model, dx, dz, now)
  if not self.pikachuRide or record.dex ~= 25
      or record.def.ascendantPokemonContext ~= "follower" then return nil end
  local game = self.activeGame
  local world = game and (game.overworld or game.world)
  local player = world and world.player
  local top = game and game.stack and type(game.stack.top) == "function"
    and game.stack:top()
  local anchor = self.playerRideAnchor
  local x, y, z = matrixFoot(model)
  local px, pz = actorCentre(player)
  -- Select an actual marked follower, not a city Pokemon sharing its texture.
  -- Only one actor gets the optional performance; source/identity stays owned.
  local selected, seen = nil, {}
  for _, pool in ipairs({world and world.entities or {}, world and world.npcs or {}}) do
    for _, actor in ipairs(pool) do
      if not seen[actor] then
        seen[actor] = true
        local def = actor.sprite and actor.sprite.def
        if def and def.ascendantPokemonDex == 25 and not actor.overworldWildSpawn
            and def.ascendantPokemonContext == "follower"
            and (actor.followerMon or actor.isPokemonFollower or actor.wildsFollower
              or actor._ascendantPokemonOverworld or actor._ascendantNativeFollower
              or actor.pokepcTrailer or actor.followerSpecies) then
          selected = actor
          break
        end
      end
    end
    if selected then break end
  end
  local ax, az = actorCentre(selected)
  local offset = self.followerSpacing and self.followerSpacing.offsets[selected]
  local matches = x and ax and (math.abs(x-ax)+math.abs(z-az) <= 2.5
    or offset and math.abs(x-ax-offset.dx)+math.abs(z-az-offset.dy) <= 2.5)
  if not matches then self.rideGuard = "no-matching-follower" return nil end
  local eligible = top and top.isOverworld == true and player and anchor
    and anchor.player == player and anchor.world == world and anchor.map == world.map
    and now-anchor.at <= .25 and record.animationSources ~= nil
    and option(self.mod, "hd_walking_sprites", true)
    and option(self.mod, "hd_pokemon_followers", true)
    and option(self.mod, "living_follower_animation", true)
    and not (game.save and game.save.onBike) and not player.onBike and not player.surfing
    and not player.inputLocked and not player.scriptedMoving and not world.inputLocked
    and not world.pikaHop and not world.pikachuBillsScene and not world.pikachuFanClubScene
    and not world.pikachuPewterSleepScene
  self.rideGuard = eligible == true and "ready" or not anchor and "no-player-anchor"
    or (not top or top.isOverworld ~= true) and "not-overworld" or "player-state"
  return self.pikachuRide:sample({
    now=now, enabled=option(self.mod, "pikachu_head_ride", false), eligible=eligible == true,
    worldKey=world and world.map, actorKey=selected,
    playerX=anchor and px and anchor.x+px-anchor.nativeX,
    playerZ=anchor and pz and anchor.z+pz-anchor.nativeZ,
    playerY=anchor and anchor.y, playerHeight=anchor and anchor.height,
    followerX=x+dx, followerZ=z+dz, followerY=y,
  })
end

function VoxelCharacters.new(options)
  return setmetatable({
    mod = assert(options.mod), generation = assert(options.generation),
    scaleProfiles = options.scaleProfiles,
    followerSpacing = options.followerSpacing,
    presentationPolicy = options.presentationPolicy,
    debugLog = options.debugLog,
    cardStyleModule = options.cardStyleModule,
    pikachuRide = options.pikachuRide,
    activeGame = nil,
    standaloneInstalled = false, vascInstalled = false,
    standaloneError = nil, vascError = nil,
    animationObservations = {}, animationObservationOrder = {},
  }, VoxelCharacters)
end

VoxelCharacters.playerRoleForGeneration = playerRoleForGeneration
VoxelCharacters.heroRoleFromIdentity = heroRoleFromIdentity
VoxelCharacters.identityFromDef = identityFromDef
VoxelCharacters.visualRoleForDef = visualRoleForDef

function VoxelCharacters:install()
  local ok, reason = standalonePatch(self)
  if not ok then self.standaloneError = reason end
  local vok, vreason = vascPatch(self)
  if not vok then self.vascError = vreason end
  local renderer = self
  if self.mod.events and type(self.mod.events.on) == "function" then
    for _, event in ipairs({ "mods.loaded", "game.ready", "save.loaded",
        "map.entered", "map.reloaded" }) do
      self.mod.events:on(event, function(ev)
        if ev and ev.game then renderer.activeGame = ev.game end
        renderer:_cancelRide(love and love.timer and love.timer.getTime and love.timer.getTime() or 0)
        if not renderer.vascOwnerCheck or not renderer.vascOwnerCheck() then
          local installed, err = vascPatch(renderer)
          if not installed then renderer.vascError = err end
        end
      end)
    end
    for _, event in ipairs({"screen.pushed", "mod.options_changed"}) do
      self.mod.events:on(event, function()
        renderer:_cancelRide(love and love.timer and love.timer.getTime and love.timer.getTime() or 0)
      end)
    end
  end
  return self.standaloneInstalled or self.vascInstalled
end

function VoxelCharacters:health()
  return {
    schema = "ascendant.voxel-characters/v1",
    ok = self.standaloneInstalled or self.vascInstalled,
    generation = self.generation,
    standalone = self.standaloneInstalled,
    vasc = self.vascInstalled,
    mode = self.vascInstalled and "vasc_visual_hull" or "native_2d_fallback",
    standaloneError = self.standaloneError,
    vascError = self.vascError,
    neutralCardError = self.neutralCardError,
    flameCardError = self.flameCardError,
    animationCardError = self.animationCardError,
    animationCacheEntries = self.animationCacheEntries,
    animationCacheBytes = self.animationCacheBytes,
    animationPendingPairs = self.animationPendingPairs,
    animationPendingGpuBytes = self.animationPendingGpuBytes,
    animationPendingCpuBytes = self.animationPendingCpuBytes,
    fallbackCacheBytes = self.fallbackCacheBytes,
    fallbackCacheEntries = self.fallbackCacheEntries,
    fallbackPendingPairs = self.fallbackPendingPairs,
    fallbackPendingGpuBytes = self.fallbackPendingGpuBytes,
    fallbackPendingCpuBytes = self.fallbackPendingCpuBytes,
    fallbackCardError = self.fallbackCardError,
    animationResidency = self.animationResidency,
    animationResidencyError = self.animationResidencyError,
    pikachuRide = self.pikachuRide and self.pikachuRide:health(),
    pikachuRideGuard = self.rideGuard,
    playerAnchorError = self.playerAnchorError,
  }
end

function VoxelCharacters:public()
  local renderer = self
  return {
    schema = "ascendant.voxel-characters/v1",
    health = function() return renderer:health() end,
    animationObservation = function(id)
      local seen = renderer.animationObservations[id]
      if not seen then return nil end
      local idle, walk = 0, 0
      for _ in pairs(seen.idle) do idle=idle+1 end
      for _ in pairs(seen.walk) do walk=walk+1 end
      return {dex=seen.dex, palette=seen.palette, frames=seen.frames,
        idlePhases=idle, walkPhases=walk, lastState=seen.lastState, lastPhase=seen.lastPhase}
    end,
  }
end

return VoxelCharacters
