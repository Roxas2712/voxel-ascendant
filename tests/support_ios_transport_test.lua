local path=arg and arg[1] or 'lib/SupportSend.lua'
local originalOS,now,requests,posts,released,cancelled='iOS',100,0,0,0,0
local result={status='pending'}
love={timer={getTime=function()return now end},system={getOS=function()return originalOS end,httpRequest=function()end}}
package.loaded['src.net.Fetch']={
 request=function(url,opts)
  requests=requests+1
  assert(url=='https://example.invalid/log' and opts.method=='POST')
  assert(opts.headers['Content-Type']=='text/plain' and opts.maxSeconds==30)
  assert(opts.body:find('support-code=12345678',1,true) and #opts.body<=48*1024)
  assert(not opts.body:find('privateuser',1,true))
  return requests
 end,
 poll=function()return result end,
 release=function()released=released+1 end,
 cancel=function()cancelled=cancelled+1 end,
}
local mod={id='VOXEL_ASCENDANT',version='test',manifest={log_url='https://example.invalid/log'},
 postLog=function()posts=posts+1;return {}end,
 fetch={poll=function()return {status='ok'}end,release=function()end}}
local function sender()
 local S=assert(loadfile(path))().new(mod,function()return 'hello /Users/privateuser/test'end)
 S.code='12345678';return S
end
for _,code in ipairs{200,201,204,302,400,403,413,429,500}do
 result={status='pending'}
 local S=sender();local before=requests;assert(S.send());assert(not S.send());assert(requests==before+1)
 assert(S.poll()=='pending')
 result={status='ok',code=code,body='untrusted response'}
 assert(S.poll()==(code<300 and 'saved' or 'failed'))
 assert(requests==before+1 and posts==0,'no retry on rejection')
 assert(not S.send() and S.state=='cooldown')
 now=now+31
end
for _,st in ipairs{{status='error'},{status='ok'},{status='cancelled'}}do
 local S=sender();assert(S.send());result=st;assert(S.poll()=='failed');now=now+31
end
local S=sender();result={status='pending'};assert(S.send());now=now+41;assert(S.poll()=='timeout' and cancelled==1)
S=sender();assert(S.send());S.cancel();assert(S.state=='cancelled' and cancelled==2)
local before=requests
originalOS='OS X';S=sender();assert(S.send() and S.poll()=='saved');assert(posts==1 and requests==before)
originalOS='iOS';love.system.httpPost=function()end;S=sender();assert(S.send());assert(posts==2 and requests==before)
print('PASS iOS support: 2xx-only, rejection/timeout/cancel, no duplicate POST, bounded/redacted body, desktop/dedicated transport preserved')
