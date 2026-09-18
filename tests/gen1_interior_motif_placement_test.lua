local root=arg[1]or'.'
local F=assert(loadfile(root..'/lib/Gen1InteriorFinish.lua'))()
local P=assert(loadfile(root..'/lib/Gen1InteriorPanoramas.lua'))()
for _,profile in pairs(P.profiles)do
 local seams=assert(F.seams[profile.theme],profile.theme)
 assert(seams[1]>0 and seams[1]<seams[2] and seams[2]<1)
end
local function check(panel,theme,height)
 local a=F.placement(panel,theme,height)
 if not a then return nil end
 assert(a.left>=panel.from+4 and a.right<=panel.upto-4)
 assert(a.width>=24 and math.abs(a.right-a.left-a.width)<1e-6)
 for _,door in ipairs(panel.openings or{})do
  assert(a.right<=door.from-2 or a.left>=door.upto+2,'motif intersects door/frame')
 end
 return a
end
local panel={edge='north',from=0,upto=160,openings={{from=72,upto=88,height=24}}}
local a=assert(check(panel,'home',40))
assert(a.right<=70 or a.left>=90,'centred motif cut by door')
panel.openings={{from=140,upto=160},{from=30,upto=55},{from=45,upto=80}}
assert(check(panel,'mart',40),'overlapping/unsorted openings broke placement')
assert(panel.openings[1].from==140,'source openings mutated')
panel.openings={{from=20,upto=140}};assert(not check(panel,'home',40),'narrow remnants squeeze artwork')
panel.openings={};panel.edge='south';assert(not F.placement(panel,'home',40))
panel.edge='north'
local dragon=assert(check(panel,'dragon_hall',40))
assert(dragon.sourceFrom<.230 and dragon.sourceTo>.770,'dragon relief split across walls')
local ranges={}
for _,edge in ipairs({'west','north','east'})do
 panel.edge=edge;local p=assert(check(panel,'lab',40));ranges[#ranges+1]=p
end
assert(ranges[1].sourceFrom==0 and ranges[3].sourceTo==1)
assert(ranges[1].sourceTo==ranges[2].sourceFrom and ranges[2].sourceTo==ranges[3].sourceFrom)
print('PASS complete theme motifs, intact dragon/starter sections, door-safe placement, narrow fragments omitted, source immutable')
-- Hall-of-Fame artwork begins/ends halfway through ornamental columns.
-- The central crest and both side compositions must survive intact, while
-- those already-cropped outer column fragments never reach a wall.
local hall={edge='west',from=0,upto=128,openings={}}
local west=assert(check(hall,'champion_hall',50));hall.edge='north'
local north=assert(check(hall,'champion_hall',50));hall.edge='east'
local east=assert(check(hall,'champion_hall',50))
assert(west.sourceFrom>.02 and east.sourceTo<.98,'partial outer column exposed')
assert(north.sourceFrom<=.38 and north.sourceTo>=.62,'central crest clipped')
assert(west.sourceTo==north.sourceFrom and north.sourceTo==east.sourceFrom,'interior motif lost')
local sampled={}
local graphics={setColor=function()end,draw=function()end,newQuad=function(x,y,w,h,sw,sh)
 sampled[#sampled+1]={x=x,y=y,w=w,h=h,sw=sw,sh=sh};return {release=function()end}
end}
F.paint(graphics,384,128,'champion_hall',{getDimensions=function()return 2172,724 end})
assert(#sampled==5,'champion backing must use separate plain materials and horizontal rails')
for _,q in ipairs(sampled)do
 assert(q.w/q.sw<=.081 and q.h/q.sh<.12,'whole decorated pillar/banner sampled into backing')
end
print('PASS champion walls: full crest/side motifs, trimmed half-columns, plain fabric/marble and continuous rails')

-- The lower wall must be sampled from its actual cap rail, not halfway down
-- the wood/tile joints. Coordinates measured on the existing 2172x724 art.
for theme,rail in pairs({coastal_home=.66,mart=.69,center=.685,diner=.65,
 daycare=.68,traditional_home=.70,casino=.69,hotel=.72,workshop=.78,
 museum=.75,corporate=.69,rocket=.71,power_plant=.77,gate=.68,
 ruined_mansion=.75,ice_hall=.76,stone_hall=.65,spirit_hall=.73,
 dragon_hall=.73,underground=.90})do
 sampled={}
 F.paint(graphics,512,128,theme,{getDimensions=function()return 2172,724 end})
 local dado=sampled[#sampled]
 assert(dado.x==0 and dado.w==2172 and dado.y+dado.h==724,'material band incomplete '..theme)
 assert(dado.y/724<=rail,'material joints restart below cap rail: '..theme)
 assert(dado.y/724>=rail-.035,'decorative motifs enter lower material: '..theme)
end
print('PASS lower wall material begins at cap rails; uninterrupted wood/tile joints')
