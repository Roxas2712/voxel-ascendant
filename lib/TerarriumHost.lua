-- Narrow opt-in seam. Portable battle lifecycle remains owned by VASC.
local V = ...
local H = {service=nil}
function H.available() return H.service ~= nil end
function H.stage(map,cameraMode)
 if not H.service then return nil end
 local arena=V.require('VoxelBattleStage').arena(map,nil,nil)
 if not arena then return nil end
 arena.terarrium=H.service.setup(map,cameraMode)
 for _,side in ipairs({'player','enemy'})do
  local p=arena.terarrium.actors[side]
  arena[side]={arena.mid[1]+p[1],arena.mid[2]+p[3]}
  arena[side..'Cell']={(arena[side][1]-8)/16,(arena[side][2]-8)/16}
 end
 arena.presentationMode='DISCS' -- shared renderer lifecycle, separate stage identity
 arena.portableStage='terarrium'
 arena.terarriumService=H.service -- latch exact service for this encounter
 return arena
end
local function register(factory,builtin)
  if H.service and not H.builtIn then return false,'Terarrium already registered' end
  local service=factory({Voxel3D=V.require('Voxel3D'),Mat4=V.require('Mat4'),
   resolveStyle=V.require('BattleArenaStyle').resolve,
   playFanfare=function(battle)return require('src.core.Sound').play(battle.data,'Caught_Mon')end})
  for _,name in ipairs({'setup','draw','cast','camera','trainerFoot','release'})do
   if type(service)~='table' or type(service[name])~='function' then return false,'missing '..name end
  end
  if H.builtIn then
   -- Older standalone 0.2.2 calls register unconditionally and keeps its own
   -- endBattle closure. Let its lazy factory finish, but never replace the
   -- built-in renderer or activate that unused service's battle lifecycle.
   service.release()
   return true,'Built-in VASC Terrarium owns the presentation'
  end
  H.service,H.builtIn=service,builtin==true
  return true
end
function H.builtin()
 return {schema='vasc.terarrium-host/v1',revision=3,generation=1,
  register=function(factory)return register(factory,true)end,available=H.available}
end
function H.public()
 return {schema='vasc.terarrium-host/v1',revision=3,generation=1,builtIn=H.builtIn,
  register=function(factory)return register(factory,false)end,available=H.available}
end
return H
