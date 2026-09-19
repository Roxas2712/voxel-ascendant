-- Gen 1 battle lighting has its own switch and never owns combat state.
local V=...
local L=V.require('LocalLights')
local M={}
M.setting=V.require('ModSetting').new('battleLights','BATTLE LIGHTING',
  {true,false},{'ON','OFF'},L.supported)
M.setting:setGate(function(value)return not value or L.supported end)
function M.neutralStage(arena)
  return arena and (arena.terarrium~=nil or arena.portableStage=="terarrium"
    or (arena.discs and not arena.arenaStyle)) or false
end
function M.enabled(mode,map,arena)
  if M.neutralStage(arena) then return false end
  return L.available() and M.setting:get() and map and map.def
    and map.def.generation~=2 and (mode=='MAP' or mode=='ARENA') or false
end
function M.prepare(state,host,arena,outdoor,ground,props,enabled,weather)
  if not enabled then L.clear(true);return end
  local G=V.require('Voxel3D');local D=V.require('DayNight')
  if not arena.discs then
    -- Use exactly the furniture retained by the battle clearance pass. A
    -- removed building must not leave a lamp hovering over the combatants.
    local f=L.prepare({map=host,player=state.player},outdoor,
      {arena.mid[1],ground,arena.mid[2]},state.dark,weather,true,props)
    if f.portalSky then D.applyRig(true,true) end
    return f
  end
  -- Portable paintings have no world-space wall geometry. Their environment
  -- rig lights the actual 3D actors/platforms, without projecting map walls or
  -- window apertures onto unrelated positions in the painting.
  local sky=L.sky(host,outdoor,weather,true)
  local tint=G.tint
  local lamps={}
  if not sky then
    local cave=host.def.tileset=='CAVERN'
    local tower=V.require('TowerAtmosphere').active(host)
    local window=V.require('VoxelBattleStage').presentationWindowScene(arena)
    local night=D.windowLight()
    if window then
      sky=L.sky(host,true,weather,true)
      tint={.56-night*.19,.54-night*.12,.49+night*.10}
      D.applyRig(true,true)
    else
      -- Broad off-stage practical light: warm/flickering in caves, quiet
      -- neutral fixtures in built rooms. Positions are in stage coordinates.
      local flame=cave or tower
      local clock=V.require('Sky').clock or 0
      local flicker=flame and (.94+.04*math.sin(clock*7)+.02*math.sin(clock*13)) or 1
      local cx,cz=arena.mid[1],arena.mid[2]
      local span=math.sqrt((arena.player[1]-arena.enemy[1])^2+(arena.player[2]-arena.enemy[2])^2)
      local radius=math.max(110,span*1.8)
      tint=tower and {.34,.36,.49} or (flame and {.46,.43,.44} or {.66,.66,.68})
      if cave and state.dark then tint={.18,.18,.22};flicker=flicker*.25 end
      for i,side in ipairs({-1,1})do
        lamps[i]={x=cx+side*span*.55,y=ground+44,z=cz-span*.2,
          radius=radius,power=(flame and 1.1 or .65)*flicker,weight=1,
          normal={0,0,0},owner={},color=flame and {1,.60,.25} or {.90,.94,1}}
      end
    end
  end
  G.tint=tint
  return L.stage(sky,tint,lamps)
end
return M
