local records={}
love={timer={getTime=function()return 0 end}}
local D=assert(loadfile('lib/MobileVoxelDiagnostic.lua'))({})
D.setLogger({enabled=function()return true end,write=function(event,fields)if event=='mobile-voxel-option'then records[#records+1]=fields end;return true end})
for _,level in ipairs({0,2,3,7,0,2})do
  for i=1,60 do D.observeOption(level>0,'gen1-pipeline-update',{level=level})end
end
assert(#records==6,'rung transitions disappeared or generated per-frame spam: '..#records)
for i,level in ipairs({0,2,3,7,0,2})do assert(records[i].level==level)end
assert(D.status().optionLevel==2)
local P=assert(loadfile('lib/PerformanceDiagnostics.lua'))({})
local writes={};P.diagnostics={write=function(event,fields)writes[#writes+1]={event,fields}end}
P.noteEvent('vasc.battle.battle-camera-static-fallback',{provider='MAP',reason='camera-safe-static'})
assert(#P.recentSignals==0 and #P.findings==0,'working static camera marked as rendering failure')
P.noteEvent('mobile-checkpoint',{status='failed',caller='mobile-scenery',mapId='ROUTE_1',neighbor='PALLET_TOWN',reason='GPU mesh rejected'})
assert(#P.recentSignals==1,'real failure was hidden')
local found
for _,r in ipairs(writes)do if r[1]=='vasc.performance.scenery-ring' and r[2].action=='ring-failed'then found=r[2].reason end end
assert(found=='GPU mesh rejected','scenery error discarded original reason')
-- Use the production closed-schema serializer, not a fake diagnostic writer.
local Logger=assert(loadfile('lib/Diagnostics.lua'))({require=function()return nil end})
local function up(fn,name)
  for i=1,100 do local n,v=debug.getupvalue(fn,i);if not n then break end;if n==name then return v end end
  error('missing upvalue '..name)
end
local normalize=up(Logger.write,'normalizedFields')
local normalized,dropped=normalize({settingId='voxel',settingValue='3RD',settingDirection=1})
assert(#normalized==3 and dropped==0,'menu choices still redacted')
local _,privateDropped=normalize({password='private',settingValue={private='data'}})
assert(privateDropped==2,'closed schema lost private-field protection')
print('PASS repeated camera changes, quiet static camera, original scenery error and closed-schema menu values')
