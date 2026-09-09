-- People baked into tiles are authored figure masks, not NPC entities. Keep
-- their original furniture/collision and replace only the extracted figure.
local V = ...
local M = {}
local mesh,texture,failed
local PATH="assets/characters/pokecenter-seated-man-hd-v1.png"
function M.enabled()
  local api=V.mod and V.mod.exports and V.mod.exports.overworldPokemon
  local walkers=api and api.walkingSprites
  if not (walkers and type(walkers.enabled)=="function") then return false end
  local ok,on=pcall(walkers.enabled)
  return ok and on==true
end
local function prepare()
  if mesh and texture then return true end
  if failed then return false end
  local ok,result=pcall(function()
    local Assets=require("src.render.Assets")
    texture=Assets.image(V.mod.path.."/"..PATH)
    if not texture then return false end
    texture:setFilter("linear", "linear")
    local renderer=V.require("Voxel3D")
    -- UV bounds are set to the transparent sprite's authored body rectangle.
    local u0,v0,u1,v1=376/1254,92/1254,990/1254,1164/1254
    local w,h=11.46,20
    local rows={{0,0,0,u0,v1,1},{w,0,0,u1,v1,1},
      {w,h,0,u1,v0,1},{0,h,0,u0,v0,1}}
    local indices={};renderer.pushQuad(indices,0)
    mesh=renderer.newMesh(rows,indices)
    return mesh~=nil
  end)
  if not ok or not result then failed=true;return false end
  return true
end
function M.resolve(figure)
  if figure.hdActor~="pokecenter_seated_man" or not M.enabled()
      or not prepare() then return figure,nil end
  return {mesh=mesh,wx=figure.wx+(figure.w or 0)/2-5.73,
    wz=figure.wz,y=figure.y-4.5,w=11.46,hdActor=figure.hdActor},texture
end
function M.invalidate()
  if mesh and mesh.release then pcall(mesh.release,mesh) end
  mesh,texture,failed=nil,nil,nil
end
return M
