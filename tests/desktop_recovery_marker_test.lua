local reads,writes=0,0
local files={}
love={system={getOS=function()return 'Windows'end},filesystem={read=function(p)reads=reads+1;return files[p]end,write=function(p,v)writes=writes+1;files[p]=v;return true end}}
local D=assert(loadfile('lib/Diagnostics.lua'))({mod={}})
local fields={kind=D.MOBILE_RECOVERY_KIND,schema='test',build='test',mode='LIVE_TEST',phase='before',status='active',generation=1,checkpoint='draw'}
for _,platform in ipairs({'Windows','OS X','Linux'})do
 love.system.getOS=function()return platform end
 for i=1,1000 do assert(D.writeMobileRecoveryMarker(fields))end
 assert(D.readMobileRecoveryMarker()==nil)
end
assert(reads==0 and writes==0,'desktop marker still performs I/O')
for _,platform in ipairs({'iOS','Android'})do
 love.system.getOS=function()return platform end
 assert(D.writeMobileRecoveryMarker(fields))
 local marker=assert(D.readMobileRecoveryMarker())
 assert(marker.checkpoint=='draw' and marker.mode=='LIVE_TEST','mobile recovery changed')
end
assert(writes==2 and reads==2)
print('Desktop marker I/O eliminated; iOS/Android recovery round trip preserved: OK')
