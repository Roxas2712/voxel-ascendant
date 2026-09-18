local load=...
local Runner=load('vendor/AnimRunner.lua')
local Motion=load('Motion.lua')
local C={}
function C.new(data,caught,shakes,ball,sound,modern)
  local param=({MASTER_BALL=1,ULTRA_BALL=2,GREAT_BALL=4})[ball] or 5
  local palette=({MASTER_BALL='PAL_BATTLE_OB_GREEN',GREAT_BALL='PAL_BATTLE_OB_BLUE',
    ULTRA_BALL='PAL_BATTLE_OB_YELLOW'})[ball] or 'PAL_BATTLE_OB_RED'
  if modern then palette='VASC_GEN2_BALL:'..ball end
  local runner=Runner.new{data=data.anims,constants=data.constants,
    animId='ANIM_THROW_POKE_BALL',battleTurn=0,param=param,ballPalette=palette,
    sfxOrder=data.audio.sfxOrder,
    hooks={pokeballWobble=Motion.wobbles(caught,shakes),sound=sound}}
  runner:start(data.anims.ids.ANIM_THROW_POKE_BALL)
  return {runner=runner,caught=caught,shakes=shakes,ball=ball,modern=modern==true,age=0,done=false}
end
function C.step(state)
  if state.done then return end
  state.age=state.age+1
  -- Wind-up precedes release; subsequent frames are the unmodified ROM script.
  if state.age<=18 then return end
  state.runner:step()
  assert(state.age<1200,'Johto catch animation exceeded bounded lifetime')
  state.done=state.runner:done()
end
return C
