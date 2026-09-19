-- Native Goldenrod's route gate is cut off at tile row zero. Reproduce the
-- missing-roof match, and reject modified maps rather than guessing a roof.
local profile=assert(loadfile('gen2/data/voxel_heights.lua'))()
local source=assert(io.open('gen2/lib/Buildings.lua')):read('*a')
local a=assert(source:find('local function matches(',1,true))
local b=assert(source:find('-- Two native maps',a,true))
local chunk=assert(loadstring(source:sub(a,b-1)..'return matches'))
local function keyOf(x,y)return(y+64)*4096+x+64 end
setfenv(chunk,setmetatable({keyOf=keyOf},{__index=_G}))
local matches=chunk()
local selected
for _,p in ipairs(profile.buildings.TilesetJohtoModern)do
 if p.id=='goldenrod_north_gate'then selected=p end
end
assert(selected,'native clipped route gate has no complete building profile')
-- Independently recorded from native Crystal. The native driver also checks
-- Gold's live map, matched model, visible result and normal entry warp.
local rows={
 {0x1A,0x1B,0x1B,0x1B,0x1B,0x1B,0x1B,0x1C},
 {0x1A,0x1B,0x1B,0x1B,0x1B,0x26,0x26,0x1C},
 {0x1A,0x1B,0x37,0x38,0x1B,0x1B,0x1B,0x1C},
 {0x01,0x02,0x39,0x3A,0x02,0x02,0x02,0x16},
}
local map={id='GOLDENROD_CITY',def={width=20,height=18}}
local S={tileAt={}}
for y,row in ipairs(rows)do for x,t in ipairs(row)do S.tileAt[keyOf(x+35,y-1)]=t end end
assert(matches(S,selected,36,0,map),'native gate rejected')
-- Every source tile matters, not merely the first tile or footprint.
for y=0,3 do for x=36,43 do
 local k=keyOf(x,y);local old=S.tileAt[k];S.tileAt[k]=old+1
 assert(not matches(S,selected,36,0,map),'edited gate accepted')
 S.tileAt[k]=old
end end
for _,change in ipairs({'map','width','height','x','y'})do
 local x,y=36,0
 if change=='map'then map.id='VIOLET_CITY'
 elseif change=='width'then map.def.width=21
 elseif change=='height'then map.def.height=19
 elseif change=='x'then x=37 else y=1 end
 assert(not matches(S,selected,x,y,map),'modified placement accepted: '..change)
 map.id='GOLDENROD_CITY';map.def.width=20;map.def.height=18
end
assert(#selected.tiles==4 and #selected.topRows==4)
assert(selected.depth==nil and selected.depthPx==nil,
 'synthetic roof must not enlarge the native walking footprint')
print('PASS_GOLDENROD_NORTH_GATE_NATIVE_MATCH_AND_EDITED_EXCLUSIONS')
