-- Fault-injection tests: replacement is atomic, old GPU objects are freed,
-- corrupt/foreign captures retain the semantic horizon and decoding is bounded.
local root=arg[1] or '.'
local resources,decodes,uploads={},0,0
local bad,tooLarge,foreign=false,false,false
local function resource(kind)
 local r={kind=kind,live=true}
 function r:release()assert(self.live,'double release '..self.kind);self.live=false end
 function r:setFilter()end;function r:setWrap()end
 resources[#resources+1]=r;return r
end
local pixels={getString=function()return 'source' end}
local Assets={imageData=function()return pixels end}
local Palette={mode='gbc'}
package.loaded['src.render.Assets']=Assets
package.loaded['src.render.GbcPalette']=Palette
local S=assert(loadfile(root..'/gen2/lib/JohtoWorldSignature.lua'))()
local maps={A={width=20,height=10,tileset='TILESET_JOHTO',environment='TOWN',connections={{map='B'}}},B={width=20,height=10,tileset='TILESET_JOHTO',environment='ROUTE',connections={{map='C'}}},C={width=2,height=2,tileset='TILESET_JOHTO',environment='ROUTE'}}
local sets={TILESET_JOHTO={image='source',blocks={1}}};local data={maps=maps,tilesets=sets,gen2Palettes={1},gen2Roofs={}}
local signature=S.digest(maps,sets,{},data.gen2Palettes,{'A','B','C'},function()return 'source'end,function(s)return s end)
assert(S.near(maps,'A',1).B and not S.near(maps,'A',1).C)
assert(S.near(maps,'A',2).C)
local changed=S.digest(maps,sets,{}, {2},{'A','B','C'},function()return 'source'end,function(s)return s end)
assert(changed~=signature,'palette changes must invalidate captures')
local view={size=640,eye={1,2,3},path='art',files={['north-land']={x=0,y=0,w=16,h=8},['east-land']={x=0,y=0,w=16,h=8},['east-lights']={x=0,y=0,w=16,h=8}}}
local catalog={crystal={signature=signature,maps={'A','B','C'},views={['A:1']=view,['A:2']=view,['B:1']=view}}}
local planeSeen=false
local G={newMesh=function(v)
 if v[1][2]==-8 then
  assert(v[1][1]==-64 and v[1][3]==-128 and v[3][1]==960 and v[3][3]==1920,'ground map scale/orientation')
  planeSeen=true
 end
 return resource('mesh')end}
love={data={hash=function(_,s)return s end,encode=function(_,_,s)return s end},filesystem={newFileData=function(s)return s end},image={newImageData=function()
 decodes=decodes+1;if bad then error('bad PNG')end
 local r=resource('pixels');r.getDimensions=function()return tooLarge and 1024 or 16,8 end;return r
end},graphics={newImage=function()uploads=uploads+1;return resource('texture')end}}
local V={require=function(name)return ({Voxel3D=G,Mat4={},JohtoWorldSignature=S})[name]end,data=function()return foreign and {} or catalog end,mod={read=function()return 'PNG'end}}
local M=assert(loadfile(root..'/gen2/lib/JohtoWorldBackdrop.lua'))(V)
M.RELEASE_READY=true
local function state(id,d)return {map={id=id,def=maps[id],renderer={data=data}},worldMaps=maps,_stadiumOpenWorldDepth=d or 1}end
local a=state('A');local b=state('B')
local function live(kind)local n=0;for _,r in ipairs(resources)do if r.live and (not kind or r.kind==kind)then n=n+1 end end;return n end
local function load(s)
 for i=1,3 do local before=uploads;local done=M.prepare(s);assert(uploads==before+1,'more than one upload per step');assert(done==(i==3));assert(M.ready(s)==(i==3),'partial view exposed')end
 assert(live('pixels')==0 and live('texture')==3 and live('mesh')==3)
end
load(a);local n=decodes;assert(M.prepare(a) and decodes==n,'stable view redecoded')
assert(not M.ready(b) and live()==0,'map replacement retained old objects');load(b)
M.setEnabled(false);assert(live()==0 and M.prepare(b) and not M.ready(b));M.setEnabled(true);load(a)
a._stadiumOpenWorldDepth=2;assert(not M.ready(a) and live()==0);load(a)
M.invalidate();assert(live()==0);bad=true;assert(M.prepare(a));assert(not M.ready(a) and M.status().error);bad=false
M.invalidate();tooLarge=true;assert(M.prepare(a));assert(live()==0 and not M.ready(a));tooLarge=false
M.invalidate();foreign=true;assert(M.prepare(a) and not M.ready(a) and live()==0);foreign=false
M.invalidate();Palette.mode='dmg';assert(M.prepare(a) and not M.ready(a));Palette.mode='gbc'
M.invalidate();load(a);local interior=state('A');interior.map.def={tileset='TILESET_JOHTO',environment='INDOOR'};assert(M.prepare(interior) and not M.ready(interior) and live()==0)
M.invalidate();view.ground={path='ground',w=16,h=8,x=-64,z=-128,spanX=1024,spanZ=2048}
assert(not M.prepare(a) and planeSeen,'ground not staged first');M.invalidate();assert(live()==0,'plane leaked')
print('PASS_JOHTO_WORLD_BACKDROP_LIFECYCLE',decodes,uploads)
