-- Shared field-action appearance adapter. The ordinary character binder owns
-- selection, costumes and HD preference; cinematics only consume its body.
local V = ...
local M = {}
function M.resolve(player, fallback)
  if not player or player._pokepcAsPokemon or player._pokepcControlSpecies
      or player.pokepcControlSpecies then return nil end
  local exports = V and V.mod and V.mod.exports
  local api = exports and exports.overworldPokemon
  local walking = api and api.walkingSprites
  local voxel = api and api.voxelCharacters
  if not (walking and walking.fieldSprite and voxel and voxel.fieldActorRenderer) then return nil end
  if walking.enabled and not walking.enabled() then return nil end
  local sprite = walking.fieldSprite(player) or fallback
  return sprite and voxel.fieldActorRenderer(sprite) or nil
end
function M.nativeDef(world)
  local exports = V and V.mod and V.mod.exports
  local api = exports and exports.overworldPokemon
  local walking = api and api.walkingSprites
  return walking and walking.fieldNativeDef
    and walking.fieldNativeDef(world.player, world) or nil
end
function M.scale(sprite)
  return sprite and sprite.fieldHD and 16 / sprite.def.frameWidth or 1
end
return M
