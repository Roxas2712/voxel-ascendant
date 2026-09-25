local M=dofile(os.getenv('DIAGNOSTICS_MODULE')or'lib/SpriteDownloadDiagnostics.lua')
local function report()return{id='operation-1',startedAt=10,finishedAt=20,outcome='error',events={},counts={}}end
local function fixture(state)
 local raw='saved';local time,encodes,posts=100,0,0;local broken,large=false,false
 local d={cache={read=function()return raw end,write=function(_,_,v)raw=v;return true end},
  decode=function(s)if s=='ack'then return{accepted=true,reportId='operation-1'}end;return state end,
  encode=function()encodes=encodes+1;if broken then error('encoder failed')end;return large and string.rep('x',262145)or'encoded'end,
  now=function()return time end,newId=function()return'new-operation'end,endpoint='https://example.invalid/report',
  transport={post=function()posts=posts+1;return'job'end,poll=function()return{status='ok',body='ack'}end,release=function()end}}
 return d,function(b,l)broken,large=b,l end,function()return encodes,posts end,function(t)time=t end
end
local malformed=report();malformed.attempts='bad';malformed.counts.error='bad';malformed.events={false,{name='error',at=12,code='unknown',rawUrl='private'}}
local d=fixture({history={42},outbox={false,'bad',42,malformed}})
local s=M.new(d);s:update();assert(#s.state.outbox==0,'malformed rows blocked valid report acknowledgement')
local active=report();active.finishedAt=nil;active.outcome=nil;active.counts.error='bad'
d=fixture({history={},outbox={},active=active});s=M.new(d)
assert(s.state.active==nil and s.state.outbox[1].outcome=='error'and s.state.outbox[1].counts.error==1,'interrupted recovery failed')
local many={};for i=1,40 do many[i]=report()end
d=fixture({history=many,outbox=many});s=M.new(d);assert(#s.state.history==10 and #s.state.outbox==32)
local toggle,counts,advance
d,toggle,counts,advance=fixture({history={},outbox={report()}});s=M.new(d)
toggle(true,false);s:update();local n=counts();for i=1,600 do s:update()end;assert(counts()==n,'encoding failure retried each frame')
assert(s:begin());assert(s:finish('success')==false,'optional encoder failure should return failure, not throw')
toggle(false,false);advance(5000);s:update();assert(#s.state.outbox==1,'ack did not drain old report')
d,toggle,counts=fixture({history={},outbox={report()}});s=M.new(d);toggle(false,true);s:update();n=counts()
for i=1,600 do s:update()end;assert(counts()==n and s.warning=='report_too_large','oversized report encoded every frame')
print('PASS diagnostics: malformed queues, interrupted counts, bounds, encoder isolation, backoff and matching ACK')
