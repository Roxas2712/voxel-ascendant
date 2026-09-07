-- Voxel world mode: characters as flat forward-facing sprite billboards.
--
-- Every character -- the player, NPCs, the ghosts standing on a neighbour
-- map -- is its CURRENT 2D sprite frame on a single flat quad. The sheets
-- carry real alpha and the shader discards it, so the quad cuts the
-- sprite's exact silhouette out of itself; no geometry is built from the
-- pixels and nothing about a sprite is voxelized.
--
-- That is deliberate. A sprite is a DRAWING, not an object seen from one
-- side: Gen 1's overworld figures are 16x16 icons with a fixed front-on
-- reading, and turning one into a solid -- whether a contoured slab or a
-- carved visual hull -- reconstructs a body the artist never drew and the
-- game never implied. It also had the mod ship a description of the ROM
-- art. One quad wearing the real frame is both more faithful and cheaper:
-- it needs no pixel access at all, only the sheet's dimensions.
--
-- The card always faces SOUTH -- the direction the 2D game implies -- and
-- only LEANS BACK, pivoting at its feet, by exactly the camera's pitch
-- (VoxelScene's billboardMatrix), so at every tilt level it reads face-on
-- like the flat game. Right-facing and the alternating walk step are
-- matrix mirrors, not extra meshes. UVs point into the live sheet image,
-- so RED++ OBP bakes, SGB palette bakes and sprite-replacing mods all
-- texture it with no rebuild.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Assets = require("src.render.Assets")
local Voxel3D = V.require("Voxel3D")

local SpriteBillboards = {}

local meshes = {}

-- One flat 16x16 quad UV-mapped to a whole frame. A hair of inset keeps
-- the sampler inside this frame rather than picking up the neighbouring
-- one along the shared edge.
local function sourceFrameSize(def, iw, ih)
  -- Native sheets stack square frames vertically. Custom/HGSS packs keep
  -- the logical 16x16 world card but may use 32px+ source frames.
  local frames = tonumber(def.frames)
  if frames and frames > 0 then frames = math.max(1, math.floor(frames)) end
  local fw = tonumber(def.frameWidth)
  local fh = tonumber(def.frameHeight)

  if not fw or fw <= 0 then fw = iw end
  if not fh or fh <= 0 then
    local divided = frames and ih / frames or nil
    if divided and divided >= 1
        and math.abs(divided - math.floor(divided + 0.5)) < 0.001 then
      fh = math.floor(divided + 0.5)
    else
      -- Metadata-free legacy sheets retain the historical square inference
      -- (for example 16x64 remains four 16px frames).
      fh = math.min(ih, fw)
    end
  end

  fw = math.max(1, math.min(iw, math.floor(fw + 0.5)))
  fh = math.max(1, math.min(ih, math.floor(fh + 0.5)))
  return fw, fh
end

local function buildCard(def, frame)
  local ok, img = pcall(Assets.image, def.image)
  if not (ok and img) then return nil end
  local iw, ih = img:getDimensions()
  local fw, fh = sourceFrameSize(def, iw, ih)
  frame = math.max(0, math.floor(tonumber(frame) or 0))
  local fy = frame * fh
  if fy + fh > ih then fy = 0 end

  -- Preserve the proven native 16px sampling exactly. Larger/custom frames
  -- use a bounded proportional inset, avoiding bleed without cropping.
  local insetX = fw == 16 and 0.02 or math.min(0.05, fw * 0.003)
  local insetY = fh == 16 and 0.05 or math.min(0.05, fh * 0.003)
  local u0, u1 = insetX / iw, (fw - insetX) / iw
  local v0, v1 = (fy + insetY) / ih, (fy + fh - insetY) / ih
  local verts = {
    { 0, 0, 0, u0, v1, 1 }, { 16, 0, 0, u1, v1, 1 },
    { 16, 16, 0, u1, v0, 1 }, { 0, 16, 0, u0, v0, 1 },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  return Voxel3D.newMesh(verts, indices)
end

-- The card for one (sprite def, frame index), or nil (headless / no
-- image), cached like every other derived GPU object.
--
-- The solid draw, the sun pass and the player's occlusion silhouette all
-- take THIS mesh. That the three agree is load-bearing, not tidiness: the
-- silhouette is drawn with the depth test INVERTED, so any self-overlap in
-- the mesh would read as "behind something" and repaint the figure on open
-- ground whether or not anything hides it; and the sun must see the same
-- outline the camera does, or a shadow stops matching what casts it.
function SpriteBillboards.mesh(def, frame)
  local key = table.concat({
    def.image,
    tostring(def.frames or ""),
    tostring(def.frameWidth or ""),
    tostring(def.frameHeight or ""),
    tostring(math.max(0, math.floor(tonumber(frame) or 0))),
  }, "#")
  if meshes[key] == nil then
    local ok, m = pcall(buildCard, def, frame)
    meshes[key] = (ok and m) or false
  end
  return meshes[key] or nil
end

-- Kept as its own name because the shadow and ghost passes read as their
-- own thing at the call sites; it once carried a different mesh from the
-- solid draw, and now deliberately does not.
SpriteBillboards.shadowQuad = SpriteBillboards.mesh

function SpriteBillboards.invalidate()
  meshes = {}
end

Assets.register(SpriteBillboards.invalidate)

return SpriteBillboards
