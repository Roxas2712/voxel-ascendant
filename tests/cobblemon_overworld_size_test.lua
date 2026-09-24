local root=assert((...)or arg[1])..'/'
local policy=assert(loadfile(root..'integrated/ascendant_pokemon_overworld/src/scale_profiles.lua'))()
local M=assert(loadfile(root..'lib/CobblemonOverworldSize.lua')){mod={exports={overworldPokemon={scaleProfiles=policy}}}}
local poses=0
local model={height=4,rootScale=1,actions={idle=1,walk=2},anims={{seconds=1},{seconds=2}}}
local rig={pose=function()poses=poses+1 end,posedBounds=function()return -2,0,-3,2,8,3 end}
local mon={model=model,rig=rig,worldHeight=function()return 100 end}
local scale,info=M.scale(mon,19)
assert(math.abs(info.reference-9.45)<1e-8 and info.height<=9.45+1e-8,'use Wilds small tier')
assert(math.abs(scale*100/4*8-9.45)<1e-8,'fit the animated body, not bind height')
assert(poses==32,'sample idle and walk once')
mon.worldHeight=function()return 2 end
local changed=M.scale(mon,19)
assert(math.abs(changed*2/4*8-9.45)<1e-8,'battle sizing must cancel out entirely')
assert(poses==32,'no per-frame rescan')
assert(info.span<=info.reference*1.2+1e-8,'bound long-body size as well as height')
local _,large=M.scale(mon,143)
assert(large.reference>info.reference,'large Wilds species retain their own tier')
local G=assert(loadfile(root..'lib/ModelGrassClearance.lua'))()
local small={stadiumMon={},entity={ascendantPokemonModelSource='cobblemon'},stadiumBounds={0,3,0,8,11,8},gh=3}
local rows=G.rows{small};assert(#rows==1 and rows[1][2]==3 and rows[1][4]>=6)
small.swimming=true;assert(#G.rows{small}==0,'water must not bend grass')
small.swimming=false;small.entity.ascendantPokemonModelSource='sprite';assert(#G.rows{small}==0,'sprite grass untouched')
assert(#G.rows(nil)==0,'clear after grass draw')
print('PASS Wilds tiers, animated envelope, battle-size independence, cached measurement, local grass clearance and water/sprite exclusions')
