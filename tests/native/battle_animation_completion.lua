-- Run in LÖVE with VASC_ROOT, GEN1_ANIM_DATA and the engine on package.path.
local root=assert(os.getenv('VASC_ROOT'))
local data=assert(loadfile(assert(os.getenv('GEN1_ANIM_DATA'))))()
local Native=require('src.battle.AnimPlayer')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function run(p,move,side,opts)
 p:start(move,side,opts)
 local events={}
 local ticks=0
 local function poll()
  for _,e in ipairs(p:pollEffects()) do
   events[#events+1]=table.concat({ticks,e.effect or '',e.sound or ''},':')
  end
 end
 poll()
 while not p:isDone() and ticks<10000 do
  ticks=ticks+1;p:update();poll()
 end
 check(p:isDone(),'animation must terminate: '..move)
 return table.concat(events,'|'),ticks
end
for _,prefix in ipairs({'','gen2/'}) do
 local Player=assert(loadfile(root..'/'..prefix..'lib/VascBattleAnimPlayer.lua'))({}).Player
 local cat=assert(loadfile(root..'/'..prefix..'data/vasc_battle_animations.lua'))()
 local count=0
 for move in pairs(data.moveAnims) do
  local entry=cat.programs[move:gsub('_','')]
  if entry then
   for _,side in ipairs({true,false}) do
    local native=Native.new(data)
    local p=Player.new(native,{catalog=cat,registry={programs={[move]=entry},nativeSources={[move]=move}}})
    local valid,expected,nt=pcall(run,Native.new(data),move,side)
    if valid then
    local actual,t=run(p,move,side)
    check(actual==expected,prefix..move..': all native effects and sounds must be delivered at the original ticks')
    check(native:isDone(),move..': native restoration must finish')
    local customEnd=#p.steps+1
    check(p.stepIndex==customEnd,move..': completed custom cursor must remain stable')
    check(t>=nt,move..': completion cannot cut off native timeline')
    -- The next move must start with fresh state after either timeline wins.
    if move=='LOW_KICK' then
     check(actual:find('SE_SHOW_MON_PIC',1,true)~=nil,'Low Kick restores the battler')
     check(t==58,'Low Kick completes after restoration, not at custom frame 18')
     local prior=p.stepIndex;p:update();check(p.stepIndex==prior,'idle updates do not drift')
     local nextEvents=run(p,move,not side)
     local nextExpected=run(Native.new(data),move,not side)
     check(nextEvents==nextExpected,'next attack resets both timelines')
    end
    count=count+1
    else
      print("BASELINE_NATIVE_ERROR",move,side,expected)
      run(p,move,side)
      check(not p.nativeStarted,"failed native source does not block custom completion")
    end
   end
  end
 end
 -- Native-only two-turn charge programs keep their exact effects and timing.
 for _,move in ipairs({'SLIDE_DOWN','TELEPORT','DIG','FLY'}) do
  if data.moveAnims[move] then
   for _,side in ipairs({true,false}) do
    local p=Player.new(Native.new(data),{registry={}})
    local a,t=run(p,move,side,{})
    local e,nt=run(Native.new(data),move,side,{})
    check(a==e and t==nt,move..': native-only charge/release remains unchanged')
   end
  end
 end
 -- Optional native provider failure must not strand a valid custom animation.
 local broken={start=function() error('fixture native unavailable') end,isDone=function() error('must not consult failed native') end}
 local p=Player.new(broken,{catalog=cat,registry={programs={LOW_KICK=cat.programs.LOWKICK}}})
 local _,ticks=run(p,'LOW_KICK',true)
 check(ticks==18,'custom animation completes when native start fails')
 print('ANIMATION_COMPLETION_PASS',prefix=='' and 'gen1' or 'gen2-copy','move-side cases',count)
end
print('ALL_ANIMATION_COMPLETION_PASS checks='..checks)
