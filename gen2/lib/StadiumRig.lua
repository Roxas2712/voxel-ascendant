-- STADIUM battles: posing a skeleton and skinning it, on the CPU.
--
-- One instance of this is one Pokemon standing on the map -- the meshes it
-- draws through and the scratch space its pose is computed in. The MODEL
-- (geometry, bones, animations, textures) is shared and read-only; this is
-- everything about it that is per-Pokemon and changes every frame.
--
-- ------- why the CPU
--
-- Because these models are tiny and the mod's shader already exists. A
-- battle model is 674 vertices on average and 1311 at the worst, of which
-- exactly two are on screen at a time -- so skinning them by hand costs
-- about two thousand vertex transforms a frame, which is less than the
-- grass pass does on an empty route. What it buys is that the finished
-- vertices go into Voxel3D's OWN vertex format, through Voxel3D's OWN
-- shader, and therefore get every single thing the rest of the diorama
-- gets for free: the depth buffer decides what is in front of what, the
-- sun pass throws a real shadow of the actual pose, the hour's tint lands
-- on it, the hit flash flattens it, and the tilt-shift and the
-- depth-of-field see it as part of the picture. A GPU skinning path would
-- have needed a second shader that then had to re-implement all of that,
-- and a second shadow shader beside it.
--
-- It is also what makes the FORMAT work. Every vertex in the Stadium set is
-- rigidly bound to ONE bone with weight 1 (model_extract/README.md), so
-- skinning is a single matrix multiply per vertex with no blend -- and the
-- per-vertex `shade` Voxel3D wants, which no glTF has, is computed here
-- from the bone-local normal.
--
-- ------- the two matrix chains
--
-- Stadium has TWO joint scale modes (func_800143C0), selected by the raw
-- command-0x1D flags preserved in DSM5/6. Mode 0 keeps scale OUT of the matrix
-- chain: a separate stack pre-scales child translations and the accumulated
-- scale is applied only to the finished draw matrix. Mode 1 builds a normal
-- local TRS matrix, so scale propagates through descendants. Modes 2/3 are
-- camera-facing variants.
--
-- The runtime therefore keeps two matrices per bone:
--
--   pivot   the unscaled combined transform a mode-0 child inherits when its
--           immediate parent is also mode 0.
--   draw    the actual matrix used to skin vertices, and the matrix inherited
--           by mode-1 children.
--
-- DSM4 threw away the flag byte and forced every joint down the first path.
-- That happened to look acceptable on most models but is the root cause of
-- Stadium 2 Lugia's detached rigid pieces.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Voxel3D = V.require("Voxel3D")
local StadiumPack = V.require("StadiumPack")

local StadiumRig = {}
StadiumRig.__index = StadiumRig

local sin, cos, floor = math.sin, math.cos, math.floor

-- binary angle (32768 = pi) to radians
local ANG = math.pi / 32768

-- ------- how a surface is lit
--
-- Voxel3D shades a face by its DIRECTION rather than by a light uniform:
-- every terrain and character mesh in this mode carries a per-vertex
-- `shade` baked from which way its face points, and the shadow map
-- multiplies on top of that (see Voxel3D.FACE_SHADE). A skinned model has
-- no fixed faces to bake, so the same answer is computed per vertex from
-- the posed normal -- and these four numbers are FACE_SHADE's own six
-- values, fitted:
--
--     +Y up 1.00   -Y down 0.55   +X east 0.84   -X west 0.72
--     +Z south 0.90   -Z north 0.68
--
-- so a Pokemon's flank catches the same southeastern sun the roof of the
-- house behind it does, and the two read as being in one picture.
local SHADE_BASE = 0.7725
local SHADE_X = 0.06
local SHADE_Y = 0.225
local SHADE_Z = 0.11

-- N64 tile address modes -> LOVE sampler modes. CLAMP wins when its bit is
-- present; MIRROR without CLAMP is mirrored repeat; zero is ordinary wrap.
local function wrapName(mode)
  mode = tonumber(mode) or 2
  if mode == 0 then return "repeat" end
  if mode == 1 then return "mirroredrepeat" end
  return "clamp"
end
StadiumRig.wrapName = wrapName

local function preparePart(part, tint)
  local texture = part and part.texture
  if not texture then return end
  local prim = part.prim or {}
  if texture.setWrap then
    pcall(texture.setWrap, texture, wrapName(prim.wrapS), wrapName(prim.wrapT))
  end
  if tint and love.graphics and love.graphics.setColor then
    local c = prim.tint or { 255, 255, 255, 255 }
    love.graphics.setColor((c[1] or 255) / 255, (c[2] or 255) / 255,
      (c[3] or 255) / 255, (c[4] or 255) / 255)
  end
end

-- ------- an instance

-- `model` is a StadiumPack model. Returns nil where meshes cannot be made,
-- which is the same "no 3D" answer every other GPU object in this mod gives.
function StadiumRig.new(model)
  if not (model and model.prims) then return nil end
  if not (love.graphics and love.graphics.newMesh) then return nil end

  local self = setmetatable({
    model = model,
    -- The two chains, flat: twelve numbers a bone, row-major 3x4.
    --
    -- Named with the M rather than `pivot` and `draw` because an instance
    -- field called `draw` shadows the DRAW METHOD through __index, and the
    -- failure that causes is a nasty one: the shadow pass calls caster()
    -- and keeps working, so a Pokemon casts a perfect animated shadow onto
    -- ground it is not standing on.
    pivotM = {},
    drawM = {},
    -- the accumulated scale, which is the third thing the game's own walk
    -- carries and neither matrix can hold
    accX = {}, accY = {}, accZ = {},
    parts = {},
    -- what the pose walk last answered, so a frame that neither moved the
    -- animation nor turned the model can skip the whole thing
    poseKey = nil,
    -- scratch for the body-centre estimate (see anchor), kept on the rig so
    -- a per-frame measurement allocates nothing
    cx = {}, cy = {}, cz = {},
  }, StadiumRig)

  -- One mesh per primitive: a primitive is already "the triangles sharing
  -- one texture", which is exactly one draw call's worth.
  --
  -- "dynamic" rather than "static": every vertex is rewritten every frame
  -- the pose changes, which is what the usage hint exists to say.
  for i, prim in ipairs(model.prims) do
    local rows = {}
    local uv = prim.uv
    for k = 1, prim.vertCount do
      -- position and shade are filled by skin(); the texture coordinates
      -- never change, so they are written once here
      rows[k] = { 0, 0, 0, uv[k * 2 - 1], uv[k * 2], 1 }
    end
    local ok, mesh = pcall(love.graphics.newMesh, Voxel3D.FORMAT, rows,
                           "triangles", "dynamic")
    if not ok then return nil end
    pcall(mesh.setVertexMap, mesh, prim.index)
    self.parts[i] = { mesh = mesh, rows = rows, prim = prim }
  end
  -- Lugia is the one Stadium-2 model that exposed a hierarchy interpretation
  -- mismatch severe enough to scatter rigid body parts across the map.  Probe
  -- repair modes before the ordinary bind measurement so measureBind sees the
  -- repaired assembly, not the broken default hierarchy.
  if tonumber(model.species) == 249 and not model.useExactNodeFlags then
    -- Legacy/compatibility safety path. DSM5 stores the raw flags, but only
    -- Lugia is allowed to opt into the experimental exact-flag transform.
    -- A DSM4 cache still gets the older Lugia hierarchy recovery instead.
    pcall(self.selectLugiaHierarchy, self)
  end

  -- the spot the animations are measured against, taken while there is no
  -- pose to overwrite (see measureBind)
  local okMeasure = pcall(self.measureBind, self)
  if not okMeasure or model.bindBroken then
    self:release()
    return nil
  end
  return self
end

function StadiumRig:release()
  for _, part in ipairs(self.parts or {}) do
    if part.mesh and part.mesh.release then
      pcall(part.mesh.release, part.mesh)
    end
  end
  self.parts = {}
end

-- ------- sampling one track
--
-- `c` is the pack's own fold: a bare number when the component holds still
-- for the whole animation, or one value a frame when it does not. Two frame
-- indices and a blend come in because the caller has already resolved what
-- "between frame 12 and 13, three tenths of the way" means for THIS
-- animation's looping.

-- One component at one frame.
local function sampleAt(c, i)
  if type(c) == "number" then return c end
  return c[i]
end

-- ------- interpolation, and the one place it must not happen
--
-- These streams are not keyframes: they carry ONE VALUE PER FRAME at 30 Hz,
-- and the game steps them a frame at a time. So at 60 Hz the honest replay
-- is each pose held for two frames -- which is exactly what it looks like,
-- a set of models moving at half the frame rate of everything around them.
-- Blending between consecutive entries is therefore not reconstructing
-- something the source had; it is INVENTING the halfway pose. It is worth
-- inventing, because a 30 Hz step against a 60 Hz camera reads as a stutter
-- and the halfway pose is right far more often than it is wrong.
--
-- Where it IS wrong is the reason a naive version of this shipped once and
-- had to be taken out: bones snapping to an upside-down pose for a frame,
-- arms turning inside out for a few. Rotations here are EULER TRIPLES, and
-- a Euler triple is not a direction you can walk along. Two triples can
-- describe nearly the same orientation and be nowhere near each other
-- component by component -- (0, 20976, 32736) and (0, -19936, -5904) are a
-- real pair out of the set -- so walking from one to the other passes
-- through orientations that are nothing like either end. That is precisely
-- a bone flipping over and back inside one frame.
--
-- Shortest-arc wrapping (below) fixes the easy half of that, where a
-- component crosses the +-pi seam. It cannot fix the hard half, where the
-- source simply RE-EXPRESSES a rotation. So the hard half is not fixed, it
-- is DETECTED: a bone whose rotation moves more than BREAK_ANGLE in a
-- single frame is not being animated, it is being re-expressed or snapped,
-- and that bone holds its frame instead of blending. Per bone and all three
-- components together, because the three are one rotation and blending two
-- of them while holding the third is its own wrong answer.
--
-- The same guard, in the same spirit, for TRANSLATION: BREAK_MOVE of the
-- model's own height inside one frame is a teleport rather than a stride.
-- Scale needs none -- a linear blend of two scales lies between them, and
-- there is no way for that to be a pose neither end had.

-- 32768 binary-angle units is pi, so this is a quarter turn in one 30 Hz
-- frame -- 2700 degrees a second. Nothing in the set genuinely moves that
-- fast; everything that reads as moving that fast is a re-expression.
local BREAK_ANGLE = 16384

-- and half the Pokemon's own height in one frame, which is fifteen body
-- heights a second
local BREAK_MOVE = 0.5

-- The signed distance from `c[i0]` to `c[i1]` the SHORT way round, for a
-- binary angle. Interpolating 32700 toward -32700 the long way spins the
-- bone most of a full turn inside one frame; the short way is 136 units,
-- which is what actually happened.
local function angleDelta(c, i0, i1)
  if type(c) == "number" then return 0 end
  local d = c[i1] - c[i0]
  if d > 32768 then d = d - 65536 elseif d < -32768 then d = d + 65536 end
  return d
end

local function linearDelta(c, i0, i1)
  if type(c) == "number" then return 0 end
  return c[i1] - c[i0]
end

-- ------- the pose
--
-- `anim` is an index into model.anims (or nil for the bind pose), `frame` a
-- FLOAT frame in that animation's own 30 Hz timeline, and `wrap` whether
-- the far end joins back to loopStart (a standby loop) or holds on the last
-- frame (a faint).
function StadiumRig:pose(anim, frame, wrap)
  local model = self.model
  local n = model.boneCount
  local tracks = anim and StadiumPack.tracks(model, anim) or nil
  local frames = anim and model.anims[anim] and model.anims[anim].frames or 1

  -- The two frames this instant falls between, and how far. `k` is 0 on
  -- every whole frame, so a caller that steps in whole frames -- the test
  -- suite, the blink probe -- sees exactly the frame it asked for.
  local i0, i1, k = 1, 1, 0
  if tracks and frames > 1 then
    local f = frame
    if f < 0 then f = 0 end
    local base = floor(f)
    k = f - base
    local loop = model.anims[anim].loopStart or 0
    if not (loop > 0 and loop < frames) then loop = 0 end
    if base >= frames then
      if wrap then
        -- the far end joins back to loopStart, which is where the game's own
        -- player sends the counter (func_80016FBC)
        base = loop + (base - loop) % (frames - loop)
      else
        base = frames - 1                   -- a faint holds where it fell
        k = 0
      end
    end
    i0 = base + 1
    if i0 > frames then i0 = frames end
    if i0 < 1 then i0 = 1 end
    -- and the frame after it, which past the end of a loop is loopStart --
    -- the same seam the counter itself crosses. An animation that HOLDS
    -- (a faint) has nothing after its last frame, so it blends with itself.
    if i0 < frames then
      i1 = i0 + 1
    elseif wrap then
      i1 = loop + 1
    else
      i1, k = i0, 0
    end
  end

  -- The frame this animation is actually SHOWING, after the wrap or the
  -- hold, 0-based -- the WHOLE frame, never the blend. A texture swap has no
  -- halfway: an eye is open or it is shut, and a pupil interpolated toward a
  -- swirl is not a thing the hardware could draw. So the skeleton runs at 60
  -- and the textures step at 30, which is what the game does with both.
  -- Stashed rather than recomputed because the texture
  -- animation is sampled at the very same frame (see textures) -- in the
  -- game one counter drives both, and 73% of the paired animations in the
  -- set are the same length as each other, which is what that looks like
  -- from the outside. Two copies of this arithmetic would be two things to
  -- keep in step; one number cannot drift from itself.
  self.frameAt = i0 - 1

  local parent = model.parent
  local restT, restR, restS = model.restT, model.restR, model.restS
  local pivot, drw = self.pivotM, self.drawM
  local accX, accY, accZ = self.accX, self.accY, self.accZ

  -- how far a bone may travel in one frame before it is read as a teleport
  -- rather than a stride. In the vertices' own RAW units, which is what the
  -- tracks are in: model.height is measured after the model_root scale.
  local moveBreak = nil
  if k > 0 then
    local root = model.rootScale
    if not (root and root > 0) then root = 1 end
    local h = (model.height or 0) / root
    if h > 0 then moveBreak = h * BREAK_MOVE end
  end

  for b = 1, n do
    local o3 = (b - 1) * 3
    local tx, ty, tz, rx, ry, rz, kx, ky, kz
    local comps = tracks and tracks[b]
    if comps then
      tx = sampleAt(comps[1], i0)
      ty = sampleAt(comps[2], i0)
      tz = sampleAt(comps[3], i0)
      rx = sampleAt(comps[4], i0)
      ry = sampleAt(comps[5], i0)
      rz = sampleAt(comps[6], i0)
      kx = sampleAt(comps[7], i0)
      ky = sampleAt(comps[8], i0)
      kz = sampleAt(comps[9], i0)
      if k > 0 then
        -- ROTATION, all three at once: a bone that snaps holds its frame,
        -- and a bone that moves holds none of it (see BREAK_ANGLE)
        local dx = angleDelta(comps[4], i0, i1)
        local dy = angleDelta(comps[5], i0, i1)
        local dz = angleDelta(comps[6], i0, i1)
        if dx < 0 then dx = -dx end
        if dy < 0 then dy = -dy end
        if dz < 0 then dz = -dz end
        if dx <= BREAK_ANGLE and dy <= BREAK_ANGLE and dz <= BREAK_ANGLE then
          rx = rx + angleDelta(comps[4], i0, i1) * k
          ry = ry + angleDelta(comps[5], i0, i1) * k
          rz = rz + angleDelta(comps[6], i0, i1) * k
        end
        -- TRANSLATION, likewise together: the three are one offset
        local mx = linearDelta(comps[1], i0, i1)
        local my = linearDelta(comps[2], i0, i1)
        local mz = linearDelta(comps[3], i0, i1)
        local far = false
        if moveBreak then
          far = (mx > moveBreak or mx < -moveBreak)
                or (my > moveBreak or my < -moveBreak)
                or (mz > moveBreak or mz < -moveBreak)
        end
        if not far then
          tx, ty, tz = tx + mx * k, ty + my * k, tz + mz * k
        end
        -- SCALE, which cannot land anywhere the two ends did not bracket
        kx = kx + linearDelta(comps[7], i0, i1) * k
        ky = ky + linearDelta(comps[8], i0, i1) * k
        kz = kz + linearDelta(comps[9], i0, i1) * k
      end
    else
      -- a bone this animation never touches keeps its rest transform
      tx, ty, tz = restT[o3 + 1], restT[o3 + 2], restT[o3 + 3]
      rx, ry, rz = restR[o3 + 1], restR[o3 + 2], restR[o3 + 3]
      kx, ky, kz = restS[o3 + 1], restS[o3 + 2], restS[o3 + 3]
    end

    local p = parent[b]
    local nodeFlags = model.nodeFlags

    if nodeFlags and model.useExactNodeFlags then
      -- Exact Stadium geo-node transform mode, preserved by DSM5.
      -- v0.2.17 deliberately restricts this path to Lugia until Stadium 2's
      -- per-node semantics are verified across the complete 251-model set.  The source
      -- game converts cmd 0x1D's flags like this before func_800143C0:
      -- default=1, bit0 clears bit0, bit1 sets bit1.
      local raw = tonumber(nodeFlags[b]) or 1
      local mode = 1
      if raw % 2 == 1 then mode = 0 end
      if math.floor(raw / 2) % 2 == 1 then mode = mode + 2 end

      local sepPX, sepPY, sepPZ = 1, 1, 1
      if p > 0 then sepPX, sepPY, sepPZ = accX[p], accY[p], accZ[p] end

      -- Rx*Ry*Rz transposed into the column-vector 3x4 form used by this rig.
      local ax, ay, az = rx * ANG, ry * ANG, rz * ANG
      local sx, cx = sin(ax), cos(ax)
      local sy, cy = sin(ay), cos(ay)
      local sz, cz = sin(az), cos(az)
      local m11, m12, m13 = cy * cz, sx * sy * cz - cx * sz, cx * sy * cz + sx * sz
      local m21, m22, m23 = cy * sz, sx * sy * sz + cx * cz, cx * sy * sz - sx * cz
      local m31, m32, m33 = -sy, sx * cy, cx * cy
      local o = (b - 1) * 12

      if mode == 0 then
        -- func_800143C0's separate-scale path. Only another mode-0 parent
        -- supplies its unscaled pivot; every other parent supplies the current
        -- draw matrix. Translation is pre-scaled by D_800AB970's current
        -- scale-stack value, then this joint pushes its own scale onto it.
        tx, ty, tz = tx * sepPX, ty * sepPY, tz * sepPZ
        if p > 0 then
          local pr = tonumber(nodeFlags[p]) or 1
          local pm = 1
          if pr % 2 == 1 then pm = 0 end
          if math.floor(pr / 2) % 2 == 1 then pm = pm + 2 end
          local base = (pm == 0) and pivot or drw
          local q = (p - 1) * 12
          local a1,a2,a3,a4 = base[q+1],base[q+2],base[q+3],base[q+4]
          local b1,b2,b3,b4 = base[q+5],base[q+6],base[q+7],base[q+8]
          local c1,c2,c3,c4 = base[q+9],base[q+10],base[q+11],base[q+12]
          pivot[o+1] = a1*m11 + a2*m21 + a3*m31
          pivot[o+2] = a1*m12 + a2*m22 + a3*m32
          pivot[o+3] = a1*m13 + a2*m23 + a3*m33
          pivot[o+4] = a1*tx + a2*ty + a3*tz + a4
          pivot[o+5] = b1*m11 + b2*m21 + b3*m31
          pivot[o+6] = b1*m12 + b2*m22 + b3*m32
          pivot[o+7] = b1*m13 + b2*m23 + b3*m33
          pivot[o+8] = b1*tx + b2*ty + b3*tz + b4
          pivot[o+9] = c1*m11 + c2*m21 + c3*m31
          pivot[o+10] = c1*m12 + c2*m22 + c3*m32
          pivot[o+11] = c1*m13 + c2*m23 + c3*m33
          pivot[o+12] = c1*tx + c2*ty + c3*tz + c4
        else
          pivot[o+1],pivot[o+2],pivot[o+3],pivot[o+4] = m11,m12,m13,tx
          pivot[o+5],pivot[o+6],pivot[o+7],pivot[o+8] = m21,m22,m23,ty
          pivot[o+9],pivot[o+10],pivot[o+11],pivot[o+12] = m31,m32,m33,tz
        end

        local ex, ey, ez = sepPX*kx, sepPY*ky, sepPZ*kz
        accX[b],accY[b],accZ[b] = ex,ey,ez
        drw[o+1],drw[o+2],drw[o+3],drw[o+4] = pivot[o+1]*ex,pivot[o+2]*ey,pivot[o+3]*ez,pivot[o+4]
        drw[o+5],drw[o+6],drw[o+7],drw[o+8] = pivot[o+5]*ex,pivot[o+6]*ey,pivot[o+7]*ez,pivot[o+8]
        drw[o+9],drw[o+10],drw[o+11],drw[o+12] = pivot[o+9]*ex,pivot[o+10]*ey,pivot[o+11]*ez,pivot[o+12]
      else
        -- func_8000F5A8 + func_800122B4 path. Scale is part of the local
        -- matrix, so it propagates through the draw chain. Camera-facing modes
        -- 2/3 use a view-oriented basis in Stadium; for world rendering we keep
        -- their position/scale attached with this finite parent-space basis.
        local l11,l12,l13,l14 = m11*kx,m12*ky,m13*kz,tx
        local l21,l22,l23,l24 = m21*kx,m22*ky,m23*kz,ty
        local l31,l32,l33,l34 = m31*kx,m32*ky,m33*kz,tz
        if p > 0 then
          local q=(p-1)*12
          local a1,a2,a3,a4=drw[q+1],drw[q+2],drw[q+3],drw[q+4]
          local b1,b2,b3,b4=drw[q+5],drw[q+6],drw[q+7],drw[q+8]
          local c1,c2,c3,c4=drw[q+9],drw[q+10],drw[q+11],drw[q+12]
          drw[o+1]=a1*l11+a2*l21+a3*l31; drw[o+2]=a1*l12+a2*l22+a3*l32; drw[o+3]=a1*l13+a2*l23+a3*l33; drw[o+4]=a1*l14+a2*l24+a3*l34+a4
          drw[o+5]=b1*l11+b2*l21+b3*l31; drw[o+6]=b1*l12+b2*l22+b3*l32; drw[o+7]=b1*l13+b2*l23+b3*l33; drw[o+8]=b1*l14+b2*l24+b3*l34+b4
          drw[o+9]=c1*l11+c2*l21+c3*l31; drw[o+10]=c1*l12+c2*l22+c3*l32; drw[o+11]=c1*l13+c2*l23+c3*l33; drw[o+12]=c1*l14+c2*l24+c3*l34+c4
        else
          drw[o+1],drw[o+2],drw[o+3],drw[o+4]=l11,l12,l13,l14
          drw[o+5],drw[o+6],drw[o+7],drw[o+8]=l21,l22,l23,l24
          drw[o+9],drw[o+10],drw[o+11],drw[o+12]=l31,l32,l33,l34
        end
        for j=1,12 do pivot[o+j]=drw[o+j] end
        -- Mode 1/2/3 does not push Stadium's separate scale stack.
        accX[b],accY[b],accZ[b]=sepPX,sepPY,sepPZ
      end
    else
      -- Legacy DSM4 fallback, retained only for developer/shipped packs that
      -- predate v0.2.16. DSM5 non-Lugia compatibility intentionally reaches this branch in v0.2.17.
      local hierarchyMode = model.hierarchyMode or "normal"
      local inheritParent = p > 0 and hierarchyMode == "normal"
      local inheritRotation = p > 0 and hierarchyMode ~= "flat"
      local pax, pay, paz = 1, 1, 1
      if inheritParent then pax, pay, paz = accX[p], accY[p], accZ[p] end
      tx, ty, tz = tx * pax, ty * pay, tz * paz

      local ax, ay, az = rx * ANG, ry * ANG, rz * ANG
      local sx, cx = sin(ax), cos(ax)
      local sy, cy = sin(ay), cos(ay)
      local sz, cz = sin(az), cos(az)
      local m11, m12, m13 = cy * cz, sx * sy * cz - cx * sz, cx * sy * cz + sx * sz
      local m21, m22, m23 = cy * sz, sx * sy * sz + cx * cz, cx * sy * sz - sx * cz
      local m31, m32, m33 = -sy, sx * cy, cx * cy

      local o = (b - 1) * 12
      if inheritRotation then
        local q = (p - 1) * 12
        local a1, a2, a3, a4 = pivot[q + 1], pivot[q + 2], pivot[q + 3], pivot[q + 4]
        local b1, b2, b3, b4 = pivot[q + 5], pivot[q + 6], pivot[q + 7], pivot[q + 8]
        local c1, c2, c3, c4 = pivot[q + 9], pivot[q + 10], pivot[q + 11], pivot[q + 12]
        pivot[o + 1] = a1 * m11 + a2 * m21 + a3 * m31
        pivot[o + 2] = a1 * m12 + a2 * m22 + a3 * m32
        pivot[o + 3] = a1 * m13 + a2 * m23 + a3 * m33
        if hierarchyMode == "absolute_translation" then
          pivot[o + 4], pivot[o + 8], pivot[o + 12] = tx, ty, tz
        else
          pivot[o + 4] = a1 * tx + a2 * ty + a3 * tz + a4
          pivot[o + 8] = b1 * tx + b2 * ty + b3 * tz + b4
          pivot[o + 12] = c1 * tx + c2 * ty + c3 * tz + c4
        end
        pivot[o + 5] = b1 * m11 + b2 * m21 + b3 * m31
        pivot[o + 6] = b1 * m12 + b2 * m22 + b3 * m32
        pivot[o + 7] = b1 * m13 + b2 * m23 + b3 * m33
        pivot[o + 9] = c1 * m11 + c2 * m21 + c3 * m31
        pivot[o + 10] = c1 * m12 + c2 * m22 + c3 * m32
        pivot[o + 11] = c1 * m13 + c2 * m23 + c3 * m33
      else
        pivot[o + 1], pivot[o + 2], pivot[o + 3], pivot[o + 4] = m11, m12, m13, tx
        pivot[o + 5], pivot[o + 6], pivot[o + 7], pivot[o + 8] = m21, m22, m23, ty
        pivot[o + 9], pivot[o + 10], pivot[o + 11], pivot[o + 12] = m31, m32, m33, tz
      end

      local ex, ey, ez = pax * kx, pay * ky, paz * kz
      accX[b], accY[b], accZ[b] = ex, ey, ez
      drw[o + 1], drw[o + 2] = pivot[o + 1] * ex, pivot[o + 2] * ey
      drw[o + 3], drw[o + 4] = pivot[o + 3] * ez, pivot[o + 4]
      drw[o + 5], drw[o + 6] = pivot[o + 5] * ex, pivot[o + 6] * ey
      drw[o + 7], drw[o + 8] = pivot[o + 7] * ez, pivot[o + 8]
      drw[o + 9], drw[o + 10] = pivot[o + 9] * ex, pivot[o + 10] * ey
      drw[o + 11], drw[o + 12] = pivot[o + 11] * ez, pivot[o + 12]
    end
  end
end

-- ------- keeping the Pokemon on its own tile
--
-- Stadium's animations MOVE the Pokemon, and they move it a long way. Half
-- the set's send-out entrances walk the body more than its own height off
-- the spot it started on; Dewgong's faint travels nearly ten body-heights,
-- and its entrance seven and a half. Every one of them ends exactly where it
-- began, because that game framed each Pokemon with a camera of its OWN that
-- followed the performance around a stage.
--
-- This mode has one camera, solved to put two named map cells at two fixed
-- points in a 160x144 frame (BattleCam), and a Pokemon that travels seven
-- body-heights out of that frame is simply GONE -- which is what sending out
-- a Farfetch'd looked like: an empty tile for three and a half seconds,
-- while its animation played somewhere off to the left of the shot.
--
-- So the bulk travel is taken back out. The pose is measured, and whatever
-- has carried the body further than `limit` from where the bind pose put it
-- is subtracted from every bone.
--
-- ------- why a LIMIT and not an anchor
--
-- Pinning the body outright would flatten the animations into mime: a lunge,
-- a hop, a recoil and a collapse are all the body moving, and they are the
-- part worth having. What breaks the shot is not motion, it is EXCURSION --
-- and the two are told apart by how far. Inside the limit nothing is touched
-- at all, so the 83 species whose animations stay put are bit-for-bit what
-- they were; past it the excess alone is removed, so a big move still reads
-- as big and still comes back to the tile it left.
--
-- ------- where the body IS, and why it is not the median
--
-- The first version of this took the median bone origin, on the reasoning
-- that a handful of bones flung anywhere cannot move a median. True, and it
-- had a worse problem: a median is a RANK, and a rank flips. On a bird most
-- of the skeleton is wing, so as the wings beat, which bone sits at the
-- middle of the sorted list swaps between the up cluster and the down one --
-- and the estimate jumps with it. Measured on Pidgey's standby loop the
-- median moved a tenth of a body-height between adjacent half-frames, and on
-- Pidgeot three whole body-heights. The anchor turns that straight into a
-- translation of the ENTIRE Pokemon, so the body counter-shook against its
-- own wings and the flapping read as twice its real speed. That is the
-- "Pidgey's wings flap super fast" this comment exists because of.
--
-- The centre is now the bone origins averaged, WEIGHTED BY HOW MANY VERTICES
-- EACH BONE MOVES. That fixes both halves at once:
--
--   * the weights are a property of the MESH, computed once and never
--     changing, so there is no rank to flip and no discontinuity available
--     to it -- the estimate is as smooth as the bones themselves
--   * a bone with little geometry on it barely counts, which is exactly the
--     robustness the median was for. Farfetch'd's trail is thirty vertices
--     on five bones -- 1.6% of the model -- so streaking three thousand
--     units out moves this by nothing worth measuring
--
-- Against the median it is two to five times smoother on every species
-- tested and measures the same travel to within a few percent.

-- How far the body estimate may move in ONE 30 Hz frame of a species' own
-- standby loop before that species is judged unmeasurable and left
-- unanchored (see measureBind). The fastest genuine motion in the set is
-- about a fifth of a body-height a frame; the one species that fails this
-- moves three.
StadiumRig.ANCHOR_STEADY = 0.5

-- Which context slot the standby loop is, without requiring StadiumPack --
-- this module is below it and a require would be circular. Position 1 of
-- StadiumPack.CONTEXT, which is the format's own contract.
local IDLE_SLOT = 1

-- How much of the model each bone actually carries. Cached on the shared
-- model: it is a fact about the mesh, not about this instance.
local function boneWeights(model)
  if model.boneW then return model.boneW, model.boneWTotal end
  local w, total = {}, 0
  for b = 1, model.boneCount do w[b] = 0 end
  for _, prim in ipairs(model.prims) do
    local bone = prim.bone
    for k = 1, prim.vertCount do
      local b = bone[k]
      if w[b] then w[b] = w[b] + 1; total = total + 1 end
    end
  end
  model.boneW, model.boneWTotal = w, total
  return w, total
end

-- The body centre of the pose currently in drawM.
local function centre(self, n)
  local model = self.model
  local w, total = boneWeights(model)
  if not (total > 0) then return nil end
  local x, y, z = 0, 0, 0
  local d = self.drawM
  for b = 1, n do
    local q = w[b]
    if q and q > 0 then
      local o = (b - 1) * 12
      x = x + d[o + 4] * q
      y = y + d[o + 8] * q
      z = z + d[o + 12] * q
    end
  end
  return x / total, y / total, z / total
end

-- Bounds of the POSED mesh in raw model units, without touching GPU meshes.
-- Used only when a model is first constructed to reject an obviously exploded
-- standby animation.  Measuring the actual vertices matters: a bad wing chain
-- can move several body lengths while the weighted body centre barely moves.
local function poseBounds(self)
  local model, d = self.model, self.drawM
  local lo1, lo2, lo3 = math.huge, math.huge, math.huge
  local hi1, hi2, hi3 = -math.huge, -math.huge, -math.huge
  for _, prim in ipairs(model.prims or {}) do
    local px, py, pz, bone = prim.px, prim.py, prim.pz, prim.bone
    for k = 1, prim.vertCount do
      local b = bone[k]
      local o = b and (b - 1) * 12 or -12
      if b and b >= 1 and b <= model.boneCount and d[o + 12] ~= nil then
        local x, y, z = px[k], py[k], pz[k]
        local a = d[o + 1] * x + d[o + 2] * y + d[o + 3] * z + d[o + 4]
        local c = d[o + 5] * x + d[o + 6] * y + d[o + 7] * z + d[o + 8]
        local e = d[o + 9] * x + d[o + 10] * y + d[o + 11] * z + d[o + 12]
        if a < lo1 then lo1 = a end; if a > hi1 then hi1 = a end
        if c < lo2 then lo2 = c end; if c > hi2 then hi2 = c end
        if e < lo3 then lo3 = e end; if e > hi3 then hi3 = e end
      end
    end
  end
  if lo1 == math.huge then return nil end
  return lo1, lo2, lo3, hi1, hi2, hi3
end

-- Public read-only bounds for preview cameras.  These are the current posed
-- mesh bounds in raw Stadium model units, after skeletal animation/anchoring
-- and before the caller's model matrix.  Keeping the scan here means preview
-- code never has to reach into rig internals or duplicate skinning math.
function StadiumRig:posedBounds()
  return poseBounds(self)
end

local function finite(v)
  return type(v) == "number" and v == v and v > -1e12 and v < 1e12
end

-- Exact screen-space envelope of the vertices the camera actually draws.
-- `skin()` has already written the current posed model-space position into
-- every `part.rows` entry; projecting those same positions avoids the false
-- top produced by projecting the eight corners of their 3-D AABB. Under a
-- perspective/rotated view an AABB corner may combine three extrema that no
-- real mesh vertex owns, which detached the head-anchored status card by
-- roughly 10--14 pixels in the reviewed 1024x768 Stadium battle.
--
-- The caller supplies VP*model so this read-only helper stays independent of
-- Mat4 and can be used for the final camera as well as SMART preflight views.
-- The six trailing return values are the model-space bounds collected during
-- the same pass. Stadium.visualReceipt keeps its established conservative
-- hull/X/foot contract from those values while taking only the exact top as
-- its head Y. Returning nil is deliberate fail-open behaviour for an
-- unskinned/invalid first frame.
function StadiumRig:projectedBounds(mvp, pw, ph)
  pw, ph = tonumber(pw), tonumber(ph)
  if not (type(mvp) == "table" and pw and pw > 0 and ph and ph > 0) then
    return nil
  end
  for index = 1, 16 do
    if not finite(mvp[index]) then return nil end
  end

  local left, top, right, bottom
  local lo1, lo2, lo3 = math.huge, math.huge, math.huge
  local hi1, hi2, hi3 = -math.huge, -math.huge, -math.huge
  for _, part in ipairs(self.parts or {}) do
    local rows = part.rows or {}
    local count = part.prim and tonumber(part.prim.vertCount) or #rows
    count = math.max(0, math.floor(count or 0))
    for k = 1, count do
      local row = rows[k]
      local x = type(row) == "table" and tonumber(row[1]) or nil
      local y = type(row) == "table" and tonumber(row[2]) or nil
      local z = type(row) == "table" and tonumber(row[3]) or nil
      if finite(x) and finite(y) and finite(z) then
        local cx = mvp[1] * x + mvp[2] * y + mvp[3] * z + mvp[4]
        local cy = mvp[5] * x + mvp[6] * y + mvp[7] * z + mvp[8]
        local cw = mvp[13] * x + mvp[14] * y + mvp[15] * z + mvp[16]
        if not (finite(cx) and finite(cy) and finite(cw) and cw > 1e-9) then
          return nil
        end
        local sx = (cx / cw * .5 + .5) * pw
        local sy = (cy / cw * .5 + .5) * ph
        if not (finite(sx) and finite(sy)) then return nil end
        left = left and math.min(left, sx) or sx
        right = right and math.max(right, sx) or sx
        top = top and math.min(top, sy) or sy
        bottom = bottom and math.max(bottom, sy) or sy
        if x < lo1 then lo1 = x end; if x > hi1 then hi1 = x end
        if y < lo2 then lo2 = y end; if y > hi2 then hi2 = y end
        if z < lo3 then lo3 = z end; if z > hi3 then hi3 = z end
      end
    end
  end
  if not (left and right > left and bottom > top) then return nil end
  return left, top, right-left, bottom-top,
    lo1, lo2, lo3, hi1, hi2, hi3
end

-- Project the lower contact band onto the arena floor. This measures the
-- actual posed feet/base, rather than assuming every species has one point
-- of support or using an upper tail/wing as its footprint.
function StadiumRig:groundBounds(model, vp, groundY)
  local _, low, _, _, high = self:posedBounds()
  if not (low and high) then return nil end
  local cutoff = low + (high-low)*.08
  local left, top, right, bottom
  for _, part in ipairs(self.parts or {}) do
    for _, row in ipairs(part.rows or {}) do
      local x,y,z = row[1],row[2],row[3]
      if finite(x) and finite(y) and finite(z) and y <= cutoff then
        local wx = model[1]*x + model[2]*y + model[3]*z + model[4]
        local wz = model[9]*x + model[10]*y + model[11]*z + model[12]
        local cx = vp[1]*wx + vp[2]*groundY + vp[3]*wz + vp[4]
        local cy = vp[5]*wx + vp[6]*groundY + vp[7]*wz + vp[8]
        local cw = vp[13]*wx + vp[14]*groundY + vp[15]*wz + vp[16]
        if not (finite(cw) and cw > 1e-9) then return nil end
        local sx,sy = cx/cw*.5+.5,cy/cw*.5+.5
        left = left and math.min(left,sx) or sx
        right = right and math.max(right,sx) or sx
        top = top and math.min(top,sy) or sy
        bottom = bottom and math.max(bottom,sy) or sy
      end
    end
  end
  if not left then return nil end
  return {left,top,right-left,bottom-top}
end

-- Conservative full-3D version of StadiumBuild.idleIsBroken.  This one runs
-- from the already-packed DSM data, so users keep protection even when their
-- cache predates the extractor fix and no Stadium 2 ROM is currently mounted.
local function explodedBounds(bind, posed)
  if not (bind and posed) then return true, math.huge, math.huge end
  for i = 1, 6 do
    if not finite(bind[i]) or not finite(posed[i]) then
      return true, math.huge, math.huge
    end
  end
  local sx, sy, sz = bind[4]-bind[1], bind[5]-bind[2], bind[6]-bind[3]
  local base = math.max(sx, sy, sz)
  if not (base > 1e-6) then return true, math.huge, math.huge end
  local ps = math.max(posed[4]-posed[1], posed[5]-posed[2], posed[6]-posed[3]) / base
  local drift = math.max(
    math.abs(posed[1]-bind[1]), math.abs(posed[4]-bind[4]),
    math.abs(posed[2]-bind[2]), math.abs(posed[5]-bind[5]),
    math.abs(posed[3]-bind[3]), math.abs(posed[6]-bind[6])) / base
  local bad = (ps > 2.6 and drift > 0.8) or drift > 1.6 or ps > 3.2
  return bad, ps, drift
end

-- A substantial mesh-bearing bone should not teleport multiple body lengths
-- during a standby loop.  This catches detached pieces even when the overall
-- AABB stays deceptively close to the bind size because another part moved the
-- opposite way.  Tiny effect/eye bones are excluded by vertex weight.
local function worstMajorBoneTravel(self, bindT, base)
  if not (bindT and base and base > 0) then return 0 end
  local model, d = self.model, self.drawM
  local w, total = boneWeights(model)
  if not (total and total > 0) then return 0 end
  local worst = 0
  for b = 1, model.boneCount do
    local q = w[b] or 0
    if q / total >= 0.02 then
      local o, t = (b-1)*12, (b-1)*3
      local dx = (d[o+4] or 0) - (bindT[t+1] or 0)
      local dy = (d[o+8] or 0) - (bindT[t+2] or 0)
      local dz = (d[o+12] or 0) - (bindT[t+3] or 0)
      local dist = math.sqrt(dx*dx + dy*dy + dz*dz) / base
      if dist > worst then worst = dist end
    end
  end
  return worst
end

-- Stadium 2 Lugia hierarchy recovery.
--
-- The same FRAGMENT parser is correct for the normal Stadium model set, but
-- Lugia's GS resource is a useful edge case: under the ordinary parent-local
-- interpretation its rigidly skinned wings/neck can land multiple body lengths
-- apart even in the bind pose.  Instead of banning Dex 249 outright, test the
-- three transform interpretations that the raw node data can plausibly mean
-- and keep the most compact finite assembly.  This operates on an already
-- legacy DSM4 model. DSM5 never reaches this compatibility path because it
-- carries the original joint flags and rebuilds from the Stadium 2 ROM.
--
-- normal               = verified Stadium hierarchy
-- absolute_translation = inherit parent rotation, translations are model-space
-- flat                  = each bone transform is model-space
--
-- The probe is deliberately species-specific until Stadium 2's node semantics
-- are fully mapped. No other Pokemon changes behavior.
function StadiumRig:selectLugiaHierarchy()
  local model = self.model
  if tonumber(model and model.species) ~= 249 then return false end
  if model.lugiaHierarchyProbed then return model.lugiaHierarchyRepaired == true end
  model.lugiaHierarchyProbed = true

  local modes = { "normal", "absolute_translation", "flat" }
  local scores = {}
  for _, mode in ipairs(modes) do
    model.hierarchyMode = mode
    local ok = pcall(self.pose, self, nil, 0, false)
    local a,b,c,d,e,f
    if ok then a,b,c,d,e,f = poseBounds(self) end
    local finiteBounds = a and finite(a) and finite(b) and finite(c)
      and finite(d) and finite(e) and finite(f)
    if finiteBounds then
      local sx, sy, sz = math.max(0, d-a), math.max(0, e-b), math.max(0, f-c)
      local span = math.max(sx, sy, sz)
      local minSpan = math.min(sx, sy, sz)
      -- Reject a totally collapsed candidate. The epsilon is relative to the
      -- candidate itself, so a naturally thin wing can still pass.
      if span > 1e-4 and minSpan > span * 0.003 then scores[mode] = span end
    end
  end

  -- Prefer the least invasive repair.  Absolute translations retain the full
  -- authored parent rotation chain and are selected as soon as they remove a
  -- clear (>18%) hierarchy blow-up.  Flat transforms are a deeper recovery
  -- mode and only win when they are dramatically better than BOTH normal and
  -- abs-translation.  This prevents a merely compact-but-collapsed skeleton
  -- from beating an already plausible assembled Lugia.
  local normal, absT, flat = scores.normal, scores.absolute_translation, scores.flat
  local bestMode = normal and "normal" or (absT and "absolute_translation") or (flat and "flat")
  if normal and absT and absT < normal * 0.82 then bestMode = "absolute_translation" end
  local baseline = (bestMode == "absolute_translation") and absT or normal
  if flat and baseline and flat < baseline * 0.72 and (not normal or flat < normal * 0.58) then
    bestMode = "flat"
  end

  if not bestMode then
    model.hierarchyMode = "normal"
    model.lugiaHierarchyRepaired = false
    return false
  end

  model.hierarchyMode = bestMode
  self:pose(nil, 0, false)
  local a,b,c,d,e,f = poseBounds(self)
  if a and finite(a) and finite(b) and finite(c) and finite(d) and finite(e) and finite(f) then
    -- Legacy stance values were measured with the old hierarchy. Recompute
    -- them from the repaired bind so OverworldStadium does not scale the fixed
    -- Lugia as though it were still a map-wide exploded model.
    model.height = math.max(1e-4, e - b)
    model.floor = b
    model.radius = math.max(d - a, f - c) * 0.5
  end
  model.bindCX, model.bindCY, model.bindCZ = nil, nil, nil
  model.lugiaHierarchyRepaired = true
  -- Animation slot 0 is still only a provisional Stadium-2 routing fallback.
  -- Keep the repaired REAL 3D model in its bind pose rather than letting an
  -- unrelated clip tear the newly assembled hierarchy apart.
  model.staticPose = true
  model.bindBroken = false
  model.anchorOk = false
  if V.mod and V.mod.log and V.mod.log.info then
    pcall(V.mod.log.info, V.mod.log,
      "stadium2: Lugia 3D hierarchy repair selected %s (normal %.1f, absT %.1f, flat %.1f)",
      tostring(bestMode), tonumber(scores.normal) or -1,
      tonumber(scores.absolute_translation) or -1, tonumber(scores.flat) or -1)
  end
  return true
end

-- Where the BIND pose puts it -- the spot every animation is measured
-- against. Cached on the shared MODEL, because it is a fact about the model
-- and not about this instance of it.
--
-- Called once, from new(), and deliberately not lazily from anchor(): taking
-- this measurement means POSING the bind pose, which would overwrite the
-- animated pose anchor() was called to correct. Doing it while the rig is
-- still being built is the one moment there is no pose to lose.
function StadiumRig:measureBind()
  local model = self.model
  if model.bindCX then return end
  self:pose(nil, 0, false)
  model.bindCX, model.bindCY, model.bindCZ = centre(self, model.boneCount)
  local b1,b2,b3,b4,b5,b6 = poseBounds(self)
  local bindBounds = b1 and {b1,b2,b3,b4,b5,b6} or nil
  if not bindBounds then
    model.bindBroken = true
    model.staticPose = true
  elseif not model.useExactNodeFlags then
    -- 0.2.16 may have packed stance extents using the experimental roster-wide
    -- DSM5 transform path.  Re-measure them from the proven compatibility bind
    -- so an already-built DSM5 cache is repaired immediately without another
    -- ROM import. poseBounds is pre-root-scale; packed extents are post-scale.
    local root = tonumber(model.rootScale) or 1
    if root < 0 then root = -root end
    if root == 0 then root = 1 end
    model.height = math.max(1e-4, (b5 - b2) * root)
    model.floor = b2 * root
    model.radius = math.max(b4 - b1, b6 - b3) * 0.5 * root
  end
  local baseSpan = bindBounds and math.max(b4-b1, b5-b2, b6-b3) or 0
  local bindT = {}
  if bindBounds then
    for b = 1, model.boneCount do
      local o, t = (b-1)*12, (b-1)*3
      bindT[t+1], bindT[t+2], bindT[t+3] =
        self.drawM[o+4], self.drawM[o+8], self.drawM[o+12]
    end
    -- Keep the bind translations on the shared model.  v0.2.26 uses this for
    -- a Dex-249-only world-space attack anchor: Stadium's Lugia performances
    -- contain stage/camera travel, but the torso's bind location is the stable
    -- place the overworld battle camera expects it to occupy.  This is runtime
    -- metadata only; it does not change DSM/cache bytes.
    model.bindBoneT = bindT
  end

  -- A pack already marked static (or a species-specific safety override)
  -- has explicitly rejected its standby animation.  The bind pose has just
  -- been measured successfully, so do not sample the very clip we promised
  -- not to trust merely to diagnose it a second time.
  if model.staticPose then
    model.anchorOk = false
    self:pose(nil, 0, false)
    return
  end

  -- ------- and whether this species can be anchored at all
  --
  -- Decided ONCE, per model, offline, by walking its standby loop and asking
  -- how far the body estimate moves between one frame and the next.
  --
  -- Everything the anchor does rests on that estimate being a description of
  -- where the Pokemon is. For 147 species it is: the fastest real motion in
  -- the set moves the body about a fifth of a body-height per 30 Hz frame.
  -- Pidgeot's standby loop moves it THREE, because a few of its rotation
  -- frames are junk (the worst data in the set, and a known issue in its own
  -- right). There is no filter setting that both tracks a real excursion and
  -- rejects that -- measured, at four time constants, either the excursions
  -- came back or the shake did -- because the two are only a factor of
  -- fifteen apart and a filter is a proportion.
  --
  -- So a species whose own idle says its estimate cannot be trusted is not
  -- anchored, and plays exactly as it did before the anchor existed: it
  -- travels as far as its animation says, and it does not vibrate. One
  -- species trading a framing problem for no problem beats 147 trading a
  -- solved framing problem for a shake.
  --
  -- Cheap: forty-odd poses on a model that is about to be posed sixty times
  -- a second anyway.
  local idle = model.ctx and model.ctx[IDLE_SLOT]
  local anim = (idle and idle ~= 0xFFFF) and (idle + 1) or nil
  local rec = anim and model.anims and model.anims[anim]
  model.anchorOk = true
  if rec and rec.frames and rec.frames > 1 then
    local root = model.rootScale
    if not (root and root > 0) then root = 1 end
    local h = (model.height or 0) / root
    if h > 0 then
      local px, py, pz, worst = nil, nil, nil, 0
      local worstSpan, worstDrift, worstBone = 1, 0, 0
      for f = 0, rec.frames - 1 do
        self:pose(anim, f, true)
        local x, y, z = centre(self, model.boneCount)
        if x and px then
          local d = (((x - px) ^ 2 + (y - py) ^ 2 + (z - pz) ^ 2) ^ 0.5) / h
          if d > worst then worst = d end
        end
        px, py, pz = x, y, z

        -- Full-mesh validation every third authored frame, matching the pack
        -- builder's sampling cadence.  This is what catches Lugia's sideways
        -- shard explosion that the old Y-only detector could not see.
        if bindBounds and f % 3 == 0 then
          local p1,p2,p3,p4,p5,p6 = poseBounds(self)
          local posed = p1 and {p1,p2,p3,p4,p5,p6} or nil
          local bad, spanRatio, drift = explodedBounds(bindBounds, posed)
          if spanRatio > worstSpan then worstSpan = spanRatio end
          if drift > worstDrift then worstDrift = drift end
          local boneTravel = worstMajorBoneTravel(self, bindT, baseSpan)
          if boneTravel > worstBone then worstBone = boneTravel end
          if bad or boneTravel > 1.5 then
            model.staticPose = true
          end
        end
      end
      if model.staticPose then
        model.anchorOk = false
        V.mod.log:warn("stadium: species %s has an unstable 3D standby "
                       .. "(span %.2fx, edge drift %.2fx, major-bone travel %.2fx) "
                       .. "-- holding the intact bind pose instead of drawing "
                       .. "detached model pieces", tostring(model.species),
                       worstSpan, worstDrift, worstBone)
      elseif worst > StadiumRig.ANCHOR_STEADY then
        model.anchorOk = false
        V.mod.log:info("stadium: species %s moves its own body %.1f "
                       .. "body-heights in one frame of its standby loop -- "
                       .. "not anchoring it, the measurement cannot be "
                       .. "trusted", tostring(model.species), worst)
      end
    end
  end
  -- and leave the bind pose behind, not the last frame of the idle
  self:pose(nil, 0, false)
end

-- ------- and why the offset is SMOOTHED
--
-- A better centre is not enough on its own. Any estimate that follows the
-- pose carries the pose's own frame-to-frame wobble into it, and the anchor
-- multiplies that up into a translation of the whole Pokemon -- so a species
-- whose source data is erratic (Pidgeot's standby loop has a few frames of
-- junk in it, and no estimator can smooth data that is genuinely wrong)
-- would shake bodily rather than in the one bone that is wrong.
--
-- So the offset is low-passed. What the anchor is FOR is a slow excursion --
-- a Pokemon swimming seven body-heights away over two seconds -- and that
-- survives a filter with this time constant untouched, while anything
-- oscillating frame to frame is flattened. The correction ends up describing
-- where the Pokemon has drifted TO, never how it is shaking on the way.
--
-- HALF_LIFE is in seconds: the time the offset takes to close half of any
-- gap between where it is and where the pose says it should be. Short enough
-- that a real excursion is caught within a few frames of starting, long
-- enough that a 30 Hz wobble does not survive it.
StadiumRig.ANCHOR_HALF_LIFE = 0.05


-- ------- what this does NOT fix, and why it stops here
--
-- The filter is a proportion, so it divides the input wobble down rather than
-- bounding it -- and one species' data is bad enough to get through anyway.
-- Pidgeot's standby loop carries a few frames of junk rotation (the worst in
-- the set, and a known issue since before the anchor existed), which moves
-- the body estimate three body-heights inside a single frame; filtered, that
-- is still about three pixels a frame on a fourteen-pixel model.
--
-- Two further mechanisms were built and MEASURED against the set, and both
-- were taken back out:
--
--   a rate limit on the correction bounded the shake to a third of a pixel,
--   and cost so much tracking that 33 of the 148 entrances went back to
--   leaving the frame -- half the problem the anchor exists to solve
--
--   a rate limit on the MEASUREMENT, to tell a spike from an excursion by
--   speed, could not separate them: the fastest real excursion (Dewgong's
--   entrance, five and a half body-heights a second) is close enough to
--   Pidgeot's sustained junk that any threshold either clipped Dewgong or
--   passed Pidgeot, and freezing on distrust made both worse
--
-- So it stops here, at the setting that is right for the 147 species whose
-- data is not broken. Pidgeot is a data problem and belongs with the other
-- data problems in the CHANGELOG's Known section, not in this control loop:
-- the alternative was distorting every other Pokemon's animation to flatter
-- one whose source frames are wrong.

-- Pull the pose back toward the tile. `limit` is in the Pokemon's own
-- body-heights; nil or a non-positive value leaves the pose exactly as posed.
-- `dt` is the frame's own delta; without one the offset is applied whole,
-- which is what a still (the QA sweep, a probe) wants.
function StadiumRig:anchor(limit, dt)
  if not (limit and limit > 0) then return end
  local model = self.model
  local n = model.boneCount
  -- the vertices are in RAW units, before the model_root scale that
  -- model.height is measured after
  local root = model.rootScale
  if not (root and root > 0) then root = 1 end
  local h = (model.height or 0) / root
  if not (h > 0) then return end

  local bx, by, bz = model.bindCX, model.bindCY, model.bindCZ
  if not bx then return end          -- never measured; leave the pose alone
  if model.anchorOk == false then return end   -- and unmeasurable, at that
  local x, y, z = centre(self, n)
  if not x then return end

  local dx, dy, dz = x - bx, y - by, z - bz
  local dist = (dx * dx + dy * dy + dz * dz) ^ 0.5
  local allow = limit * h

  -- what the pose alone asks for: the EXCESS beyond the limit, so what is
  -- inside it stays and the motion keeps its shape
  local ox, oy, oz = 0, 0, 0
  if dist > allow and dist > 0 then
    local k = (dist - allow) / dist
    ox, oy, oz = dx * k, dy * k, dz * k
  end

  -- and then toward it rather than straight to it (see ANCHOR_HALF_LIFE),
  -- and never faster than ANCHOR_RATE
  if dt and dt > 0 then
    local half = StadiumRig.ANCHOR_HALF_LIFE
    local a = (half > 0) and (1 - 0.5 ^ (dt / half)) or 1
    if a > 1 then a = 1 end
    local px, py, pz = self.anchorX or ox, self.anchorY or oy, self.anchorZ or oz
    ox = px + (ox - px) * a
    oy = py + (oy - py) * a
    oz = pz + (oz - pz) * a
  end
  self.anchorX, self.anchorY, self.anchorZ = ox, oy, oz
  if ox == 0 and oy == 0 and oz == 0 then return end

  local pivot, drw = self.pivotM, self.drawM
  for b = 1, n do
    local o = (b - 1) * 12
    pivot[o + 4] = pivot[o + 4] - ox
    pivot[o + 8] = pivot[o + 8] - oy
    pivot[o + 12] = pivot[o + 12] - oz
    drw[o + 4] = drw[o + 4] - ox
    drw[o + 8] = drw[o + 8] - oy
    drw[o + 12] = drw[o + 12] - oz
  end
end

-- The animated model-space origin of one attachment's bone. Geo command
-- 0x24 records the current matrix translation, and pivotM and drawM share
-- exactly that translation; pivotM is used because it describes the graph
-- node itself rather than its draw-only accumulated scale.
-- Pin one posed bone back to the location that same bone occupied in the bind
-- pose, translating the WHOLE skeleton by the same delta.  This preserves every
-- local rotation/scale/child motion in the animation; it removes only the bulk
-- stage travel inherited by the actor.  It is intentionally a separate helper
-- rather than a change to anchor(): normal Pokemon still use the measured,
-- filtered excursion limiter above.
function StadiumRig:pinBoneToBind(bone)
  local model = self.model
  local bindT = model and model.bindBoneT
  bone = tonumber(bone)
  if not (bindT and bone and bone >= 1 and bone <= (model.boneCount or 0)) then
    return false
  end
  local o, t = (bone - 1) * 12, (bone - 1) * 3
  local px, py, pz = self.pivotM[o + 4], self.pivotM[o + 8], self.pivotM[o + 12]
  local bx, by, bz = bindT[t + 1], bindT[t + 2], bindT[t + 3]
  if not (finite(px) and finite(py) and finite(pz)
      and finite(bx) and finite(by) and finite(bz)) then
    return false
  end
  local dx, dy, dz = px - bx, py - by, pz - bz
  if dx == 0 and dy == 0 and dz == 0 then
    self.anchorX, self.anchorY, self.anchorZ = nil, nil, nil
    return true
  end
  local pivot, drw = self.pivotM, self.drawM
  for b = 1, model.boneCount do
    local q = (b - 1) * 12
    pivot[q + 4] = pivot[q + 4] - dx
    pivot[q + 8] = pivot[q + 8] - dy
    pivot[q + 12] = pivot[q + 12] - dz
    drw[q + 4] = drw[q + 4] - dx
    drw[q + 8] = drw[q + 8] - dy
    drw[q + 12] = drw[q + 12] - dz
  end
  -- Do not carry the ordinary anchor filter's previous correction out of an
  -- attack once this exact torso pin is released.
  self.anchorX, self.anchorY, self.anchorZ = nil, nil, nil
  return true
end

function StadiumRig:attachment(bone)
  if type(bone) ~= "number" or bone < 1 or bone > self.model.boneCount then
    return nil
  end
  local o = (bone - 1) * 12
  local p = self.pivotM
  if p[o + 4] == nil or p[o + 8] == nil or p[o + 12] == nil then return nil end
  return p[o + 4], p[o + 8], p[o + 12]
end

-- ------- the skin
--
-- Every vertex through its one bone's draw matrix, and its normal through
-- the same bone's pivot (a pure rotation, so the normal survives a
-- non-uniformly scaled bone -- which several species have).
--
-- `yaw` is the model matrix's own turn, and it is folded in HERE rather
-- than left to the matrix because the shade has to be computed against the
-- WORLD normal: a Pokemon turned to face its opponent has a differently lit
-- flank than one facing the camera, and the sun does not turn with it.
function StadiumRig:skin(yaw)
  local cy, sy = cos(yaw or 0), sin(yaw or 0)
  local drw, piv = self.drawM, self.pivotM
  for _, part in ipairs(self.parts) do
    local prim, rows = part.prim, part.rows
    local px, py, pz = prim.px, prim.py, prim.pz
    local nx, ny, nz = prim.nx, prim.ny, prim.nz
    local bone = prim.bone
    for k = 1, prim.vertCount do
      local o = (bone[k] - 1) * 12
      local x, y, z = px[k], py[k], pz[k]
      local row = rows[k]
      row[1] = drw[o + 1] * x + drw[o + 2] * y + drw[o + 3] * z + drw[o + 4]
      row[2] = drw[o + 5] * x + drw[o + 6] * y + drw[o + 7] * z + drw[o + 8]
      row[3] = drw[o + 9] * x + drw[o + 10] * y + drw[o + 11] * z + drw[o + 12]
      local ax, ay, az = nx[k], ny[k], nz[k]
      local wx = piv[o + 1] * ax + piv[o + 2] * ay + piv[o + 3] * az
      local wy = piv[o + 5] * ax + piv[o + 6] * ay + piv[o + 7] * az
      local wz = piv[o + 9] * ax + piv[o + 10] * ay + piv[o + 11] * az
      -- With G_LIGHTING disabled Vtx bytes 12..14 are colour rather than a
      -- normal. DSM6/7 store that as prim.tint, so do not apply directional
      -- lighting a second time.
      if prim.lit == false then
        row[6] = 1
      else
        -- the model matrix's yaw, by hand: (x, z) turned, y untouched
        row[6] = SHADE_BASE + SHADE_X * (cy * wx + sy * wz) + SHADE_Y * wy
                 + SHADE_Z * (cy * wz - sy * wx)
      end
    end
    pcall(part.mesh.setVertices, part.mesh, rows)
  end
end

-- ------- which texture each part wears this frame
--
-- The eyes. A primitive whose display list carried geo command 0x23 with a
-- channel index has its texture REPLACED every frame from a stream of
-- texture-table indices (src/18140.c func_800176DC) -- which is how every
-- Pokemon in the game blinks, and how a confused one gets swirls. glTF has
-- no channel for that, so the .glb files carry only the first frame; the
-- pack carries the streams.
--
-- `aux` is an index into model.auxAnims (the stream set) and `frame` its
-- own frame counter, which runs independently of the skeletal one.
-- The eyes, and everything else a material swaps per frame.
--
-- Sampled at the SKELETAL animation's own frame -- the one pose() just
-- resolved -- and CLAMPED past the end of the stream rather than wrapped.
-- Both halves of that matter, and getting either wrong is visible.
--
-- The frame is the skeleton's because in the game a single counter drives
-- both; the data says so plainly, since 507 of the 691 paired animations in
-- the set have a texture animation exactly as long as the skeletal one it
-- rides with.
--
-- The clamp is what the game's own sampler does (func_80017540 indexes the
-- stream and holds the last entry past its end), and it is the whole
-- difference between a blink and a twitch. Rattata's standby loop is forty
-- frames and its blink is FIVE -- `6 8 7 8 6`, open through closed and back.
-- Wrapped on the blink's own length that plays six times a second, which is
-- what it looked like. Clamped, the eye blinks once at the top of the loop
-- and stays open for the remaining thirty-five frames, so it blinks about
-- once a second and a half.
function StadiumRig:textures(aux)
  local model = self.model
  local anim = aux and model.auxAnims and model.auxAnims[aux] or nil
  local frame = self.frameAt or 0
  for _, part in ipairs(self.parts) do
    local prim = part.prim
    local index = prim.tex
    if anim and prim.texAnim and prim.texAnim >= 0 and prim.texMap then
      local stream = anim.channels[prim.texAnim + 1]
      local n = stream and #stream or 0
      if n > 0 then
        local at = frame + 1
        if at > n then at = n end
        if at < 1 then at = 1 end
        local mapped = prim.texMap[stream[at]]
        if mapped then index = mapped end
      end
    end
    part.texture = StadiumPack.image(model, index)
  end
end

-- ------- the draw
--
-- `model` here is the MODEL MATRIX -- where this Pokemon stands, how big
-- and which way round -- and `sunModel` the transform the shadow pass drew
-- it with, which for these is the same matrix (unlike a character's leaning
-- card; see Voxel3D.draw).
--
-- Seams off for the whole of it: the voxel wireframe draws the integer
-- planes of a mesh's own model space, and these vertices are in the N64's
-- own units where an integer plane means nothing (see VoxelGrid). Glass off
-- for the same reason the sprite passes turn it off -- the mask's
-- coordinates belong to the tileset atlas, not to a Pokemon's texture.
function StadiumRig:draw(matrix, pull)
  Voxel3D.seams(false)
  Voxel3D.glass(false)
  -- Start every Pokemon body from ordinary opaque/alpha state. Attack FX and
  -- additive material parts use the same shared voxel renderer; explicitly
  -- clearing their blend state here prevents a later body (notably Lugia)
  -- from inheriting a ghost/additive draw mode.
  Voxel3D.blend(nil)
  local additive = nil
  for _, part in ipairs(self.parts) do
    if part.prim.additive then
      -- held back to a second pass so the flames composite over the body
      -- rather than depth-fighting it
      additive = additive or {}
      additive[#additive + 1] = part
    elseif part.texture then
      preparePart(part, true)
      Voxel3D.draw(part.mesh, part.texture, matrix, pull)
    end
  end
  if additive then
    Voxel3D.blend("add")
    for _, part in ipairs(additive) do
      if part.texture then
        preparePart(part, true)
        Voxel3D.draw(part.mesh, part.texture, matrix, pull)
      end
    end
    Voxel3D.blend(nil)
  end
  if love.graphics and love.graphics.setColor then love.graphics.setColor(1, 1, 1, 1) end
  Voxel3D.glass(true)
  Voxel3D.seams(true)
end

-- The same geometry as the SUN sees it: no camera-ward pull (a trick for
-- the view's own depth buffer, which would drag a shadow off its owner) and
-- through the shadow pass's own draw call. The generated flame prims are
-- skipped -- a fire casts light, not a shadow.
function StadiumRig:caster(shadowMap, matrix)
  for _, part in ipairs(self.parts) do
    if part.texture and not part.prim.additive then
      preparePart(part, false)
      shadowMap.draw(part.mesh, part.texture, matrix)
    end
  end
end

return StadiumRig
