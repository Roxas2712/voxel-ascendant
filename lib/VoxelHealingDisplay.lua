-- The nurse's own lit-ball counter selects the portrait. No extra timer or
-- party mutation: loading, flashing and completion remain engine-owned.
local V=...
local Assets=require('src.render.Assets')
local G=V.require('Voxel3D')
local M=V.require('Mat4')
local D={}
local animation,portraits,mesh
function D.current(ha,party)
  local index=math.min(6,math.max(0,tonumber(ha and ha.lit) or 0))
  return party and party[index],index
end
function D.portrait(ha)
  local Game=require('src.core.Game')
  local mon,index=D.current(ha,Game.save and Game.save.party)
  if not mon then return end
  if animation~=ha then animation,portraits=ha,{} end
  if portraits[index]==nil then
    local exports=Game.mods and Game.mods.exports and Game.mods.exports.VOXEL_ASCENDANT
    local provider=exports and exports.overworldPokemon and exports.overworldPokemon.pokemonWalksheets
    local result
    if provider then
      local ok,record=pcall(provider.resolvePokeMMO,Game,mon)
      if not ok or not record then ok,record=pcall(provider.resolve,Game,mon)end
      if ok and record and record.runtime then
        local loaded,img=pcall(Assets.image,V.path..'/integrated/ascendant_pokemon_overworld/'..record.runtime)
        if loaded then result=img end
      end
    end
    portraits[index]=result or false
  end
  return portraits[index] or nil,index
end
function D.draw(placement,ha)
  local img=D.portrait(ha)
  if not img then return end
  if not mesh then
    -- Native runtime walksheets contain six vertically stacked square poses.
    -- Pose zero faces south, directly out of the machine's display.
    local ok,value=pcall(G.newMesh,{
      {11,19,9.04,0,1/6,1},{21,19,9.04,1,1/6,1},
      {21,29,9.04,1,0,1},{11,29,9.04,0,0,1},
    },{1,2,3,1,3,4})
    if not ok or not value then return end
    mesh=value
  end
  love.graphics.setColor(1,1,1,1)
  G.draw(mesh,img,M.translate(placement.tx*8,0,placement.ty*8),0)
end
Assets.register(function()
  if mesh and mesh.release then mesh:release()end
  animation,portraits,mesh=nil,nil,nil
end)
return D
