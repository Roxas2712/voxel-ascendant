local root=assert(arg[1])
local function module(path)return assert(loadfile(root..'/'..path))()end
local transportPath=root:find('kasc-errors',1,true) and 'support_send.lua' or 'lib/SupportSend.lua'
local Transport=module(transportPath)
local Group=module('lib/SupportLogs.lua')
local now=100
local ticket='1234567890:'..string.rep('a',16)..':'..string.rep('b',64)..':0'
local function bootstrap()
 package.loaded['src.net.Fetch']={request=function()return 999 end,poll=function()return {status='ok',code=200,body=ticket:sub(1,92)}end,release=function()end,cancel=function()end}
end
bootstrap()
love={data={hash=function()return string.rep('\0',32)end},timer={getTime=function()return now end},math={random=math.random},system={getOS=function()return 'Linux'end},graphics={}}
local function fixture(id)
 local received,jobs,released,cancelled={}, {}, {}, {}
 local mod={id=id,version='QA',manifest={log_url='https://example.invalid/logs'},exports={}}
 function mod:postLog(body)
  local handle=#received+1;received[handle]=body;jobs[handle]={status='pending'};return handle
 end
 mod.fetch={poll=function(_,handle)return jobs[handle]end,release=function(_,handle)released[handle]=true end,cancel=function(_,handle)cancelled[handle]=true end}
 local sender=Transport.new(mod,function()return string.rep('long line ä /Users/private/path token=SECRET https://private.test\n',15000)end)
 mod.exports.supportLogsProvider={supportSender=function()return sender end}
 return mod,sender,received,jobs,released,cancelled
end
for _,ids in ipairs{{'kanto_ascendant'},{'VOXEL_ASCENDANT'},{'kanto_ascendant','VOXEL_ASCENDANT'}}do
 local mods,senders,received,jobs={},{},{},{}
 for _,id in ipairs(ids)do mods[id],senders[id],received[id],jobs[id]=fixture(id)end
 local owner=mods[ids[1]];owner.find=function(id)return mods[id]end
 local group=Group.new(owner);assert(#group.targets==#ids)
 for _,id in ipairs(ids)do assert(#received[id]==0,'opening UI must not send')end
 assert(group.send());group.poll();local reportId=group.reportId;assert(#reportId==16)
 assert(not group.send(),'parallel send')
 for _,id in ipairs(ids)do
  local body=received[id][1]
  assert(body:find('report-id='..reportId,1,true),'reports not correlated')
  assert(body:find('ASCENDANT-SUPPORT/2',1,true) and not body:find('support-code',1,true))
  assert(#body<=500*1024 and not body:find('SECRET',1,true) and not body:find('/Users/private',1,true))
  jobs[id][1]={status=id=='VOXEL_ASCENDANT' and 'error' or 'ok'};group.poll()
 end
 group.poll();assert(not group.pending())
 for _,target in ipairs(group.targets)do assert(target.state==(target.label=='VASC' and 'failed' or 'saved'))end
 group.send();for _,id in ipairs(ids)do assert(#received[id]==1,'cooldown bypass')end
 now=now+61;assert(group.send());group.poll();assert(group.reportId~=reportId);group.cancel()
 for _,target in ipairs(group.targets)do assert(target.state=='cancelled')end
end
do
 local mod,sender,received,jobs,released,cancelled=fixture('kanto_ascendant')
 assert(sender.send(nil,ticket));now=now+41;assert(sender.poll()=='timeout' and released[1] and cancelled[1])
 now=now+61;assert(sender.send(nil,ticket));jobs[2]={status='error',code=429};assert(sender.poll()=='cooldown')
 now=now+61
 local snapshot=Transport.new(mod,function()return nil,'no-log'end)
 assert(snapshot.send(nil,ticket));assert(received[3]:find('Session log unavailable',1,true))
end
-- iOS uses its engine request bridge and only confirms HTTP 2xx.
do
 now=now+61;love.system.getOS=function()return 'iOS'end
 local status={status='pending'};local count=0
 package.loaded['src.net.Fetch']={request=function(url,options)count=count+1;assert(options.method=='POST' and options.maxSeconds==30);return 7 end,
 poll=function()return status end,release=function()end,cancel=function()end}
 local mod=fixture('VOXEL_ASCENDANT');local sender=Transport.new(mod,function()return 'QA'end)
 assert(sender.send(nil,ticket) and count==1);status={status='ok',code=429};assert(sender.poll()=='cooldown')
 now=now+61;assert(sender.send(nil,ticket));status={status='ok',code=201};assert(sender.poll()=='saved')
 love.system.getOS=function()return 'Linux'end;bootstrap()
end
-- The Errors entry remains actionable with no incidents. Opening, inspecting
-- diagnostics and backing out never submit data; A confirms explicitly.
do
 local mod,sender,received,jobs=fixture('kanto_ascendant')
 function mod:read(path)local f=assert(io.open(root..'/'..path));local s=f:read('*a');f:close();return s end
 mod.hooks={wrap=function()end}
 local current;local Game={draw=function()end,touchpressed=function()end}
 local game={stack={push=function(_,s)current=s;return s end,pop=function()current=nil end,top=function()return current end}}
 local errors=module('lib/ErrorsMenu.lua').install(mod,{items={},context={},read=function()end},{Game=Game})
 errors.open(game);current:choose('open');assert(current.support and #received==0)
 current:choose('back');assert(not current.support and #received==0)
 current:choose('diagnostics');assert(current.diagnostics);current:choose('back')
 current:choose('sendLogs');current:choose('confirm');assert(#received==0);current.support.poll();assert(#received==1)
 current:choose('back');assert(sender.state=='cancelled')
 assert(errors.title()=='ERRORS / DIAGNOSTICS')
end
print('PASS combined support: solo/both, confirmation without errors, shared ID, bounded redaction, partial failure, cooldown, cancellation, timeout, iOS and device diagnostics')
-- Authorization fails closed; a computation budget keeps the frame responsive.
do
 now=now+61;bootstrap()
 local mod,sender,received=fixture('VOXEL_ASCENDANT')
 local calls=0;love.data.hash=function()calls=calls+1;return string.rep('\255',32)end
 local group=Group.new(mod);assert(group.send());group.poll()
 assert(calls==2048 and #received==0 and group.pending(),'proof budget or admission bypass')
 group.cancel();assert(not group.pending() and #received==0)
 love.data.hash=function()return string.rep('\0',32)end
 for _,reply in ipairs{{status='ok',code=200,body='forged'},{status='ok',code=429},{status='error'}}do
  now=now+61;package.loaded['src.net.Fetch'].poll=function()return reply end
  local attempt=Group.new(mod);assert(attempt.send());attempt.poll()
  assert(not attempt.pending() and #received==0,'invalid ticket still uploaded')
 end
 bootstrap()
end
-- Old engine size rejection is local and safe to retry with a marked excerpt.
do
 now=now+61;local mod=fixture('VOXEL_ASCENDANT');local seen={}
 function mod:postLog(body)
  seen[#seen+1]=body
  if #body>64*1024 then return nil,'log body too large' end
  return 1
 end
 local sender=Transport.new(mod,function()return string.rep('large log entry\n',50000)end)
 assert(sender.send(nil,ticket));assert(#seen==2 and #seen[1]>64*1024 and #seen[2]<=48*1024)
 assert(seen[2]:find('older middle records omitted',1,true))
end
print('PASS ticket rejection, proof frame budget, cancel before upload and old-engine size fallback')
