local now,enabled=0,true;local frame
local L={available=function()return true end,clear=function()frame=nil end,
 stage=function(_,tint,lamps)frame={tint=tint,lights=lamps};return frame end}
local S=assert(loadfile('integrated/terarrium/Lighting.lua'))()({lights=L,graphics={},clock=function()return now end,enabled=function()return enabled end})
local a={terarrium={id='CINNABAR_GYM'},mid={100,200}};local ao={}
assert(S.prepare(a,7,ao));local lamps=frame.lights;local lamp=lamps[1];local owner=lamp.owner
for i=1,600 do
 now=i/60;assert(S.prepare(a,7,ao));assert(frame.lights==lamps and frame.lights[1]==lamp and lamp.owner==owner,'light rig rebuilt per frame')
 local pulse=1+.035*math.sin(now*2.1)+.018*math.sin(now*4.7)
 assert(math.abs(lamp.power-.92*pulse)<1e-12 and lamp.x==43 and lamp.y==16 and lamp.z==183)
 assert(#lamps==3 and frame.stageAO==ao and frame.unoccluded)
end
local b={terarrium={id='POKEMON_TOWER_3F'},mid={1,2}}
S.prepare(b,4,ao);assert(frame.lights~=lamps and lamp.x==43,'different arenas share mutable lamps')
assert(frame.lights[1].color[1]==.59)
L.mobile=true;a.terarrium.id='ROUTE_17';a.mid={10,20};S.prepare(a,3,ao)
assert(#frame.lights==2 and lamp.x==-34 and lamp.y==35 and lamp.power==.68 and lamp.color[1]==1 and frame.tint[1]==.80)
L.mobile=false;L.handheld=true;S.prepare(a,3);assert(#frame.lights==2)
L.handheld=false;S.prepare(a,3);assert(#frame.lights==3)
enabled=false;assert(not S.prepare(a,3)and not frame);enabled=true
S.release();S.prepare(a,3);assert(frame.lights~=lamps,'release kept the old rig')
local transient=setmetatable({},{__mode='k'})
for i=1,250 do local arena={terarrium={id='ROUTE_17'},mid={i,i}};transient[arena]=true;S.prepare(arena,0)end
collectgarbage('collect');assert(next(transient)==nil,'light rigs retain finished arenas')
print('PASS light rig reuse: 600 animated frames, exact light values, arena separation, mode/layout changes, OFF and release')
