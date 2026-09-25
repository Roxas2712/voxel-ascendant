-- Explicit, bounded authorization and upload. A ticket correlates one report
-- pair; it is not proof of a player account or a persistent tracking ID.
local M={}
local function find(mod,id)
  if mod.id==id then return mod end
  if type(mod.find)~='function' then return end
  local ok,other=pcall(mod.find,id)
  if not ok or not other then ok,other=pcall(mod.find,mod,id) end
  if ok and type(other)=='table' then return other end
end
local function clock()return love.timer.getTime()end
function M.new(mod)
  local S={targets={},reportId=nil,started=false}
  local authorization,lastAttempt,delivery
  function S.refresh()
    if S.started then return end
    S.targets={}
    for _,id in ipairs{'kanto_ascendant','VOXEL_ASCENDANT'}do
      local other=find(mod,id)
      if other then
        local exports=other.exports or {}
        local provider=exports.supportLogsProvider or exports.supportSessionLog or exports.diagnostics
        local ok,sender=false,nil
        if provider and type(provider.supportSender)=='function' then ok,sender=pcall(provider.supportSender) end
        S.targets[#S.targets+1]={label=id=='kanto_ascendant' and 'KASC' or 'VASC',sender=ok and sender or nil,state=ok and sender and 'idle' or 'unavailable'}
      end
    end
  end
  local function mark(state)
    for _,target in ipairs(S.targets)do if target.sender then target.state=state end end
  end
  local function releaseAuthorization(cancel)
    if authorization and authorization.handle then
      if cancel and authorization.api.cancel then pcall(authorization.api.cancel,authorization.handle) end
      pcall(authorization.api.release,authorization.handle)
    end
    authorization=nil
  end
  function S.pending()
    if authorization then return true end
    for _,target in ipairs(S.targets)do if target.state=='pending' or target.state=='queued' then return true end end
    return false
  end
  function S.send()
    if S.pending() then return false end
    for _,target in ipairs(S.targets)do
      if target.sender and target.sender.state=='pending' then return false end
    end
    if lastAttempt and clock()-lastAttempt<60 then mark('cooldown');return false end
    local random=love and love.math and love.math.random or math.random
    local parts={};for i=1,4 do parts[i]=string.format('%04x',random(0,65535))end
    S.reportId=table.concat(parts);S.started=true
    local url
    for _,target in ipairs(S.targets)do
      if target.sender and target.sender.available() then url=target.sender.ticketEndpoint();break end
    end
    local ok,api=pcall(require,'src.net.Fetch')
    if not url or not ok or type(api)~='table' or type(api.request)~='function' or type(api.poll)~='function' or type(api.release)~='function'
        or not (love.data and type(love.data.hash)=='function') then mark('unavailable');return false end
    lastAttempt=clock()
    local requested,handle=pcall(api.request,url,{method='POST',body='ASCENDANT-TICKET/1\nreport-id='..S.reportId..'\n',
      headers={['Content-Type']='text/plain'},userAgent='ascendant-support',maxSeconds=20})
    if not requested or not handle then mark('failed');return false end
    authorization={api=api,handle=handle,at=clock(),counter=0};mark('authorizing')
    return true
  end
  local function nextUpload()
    if not delivery then return end
    for _,target in ipairs(S.targets)do if target.state=='pending' then return end end
    for _,target in ipairs(S.targets)do
      if target.sender and target.state=='queued' then
        local ok,sent,state=pcall(target.sender.send,S.reportId,delivery)
        target.state=ok and state or 'failed'
        target.reportId=ok and sent and target.sender.reportId or nil
        if target.state=='pending' then return end
      end
    end
    delivery=nil
  end
  local function upload(ticket)
    delivery=ticket;mark('queued');nextUpload()
  end
  function S.poll()
    if authorization then
      local a=authorization
      if clock()-a.at>40 then releaseAuthorization(true);mark('timeout');return end
      if a.handle then
        local ok,status=pcall(a.api.poll,a.handle)
        if not ok or type(status)~='table' then releaseAuthorization(true);mark('failed');return end
        if status.status=='pending' then return end
        pcall(a.api.release,a.handle);a.handle=nil
        if status.status~='ok' or tonumber(status.code)~=200 then
          authorization=nil;mark(tonumber(status.code)==429 and 'cooldown' or 'failed');return
        end
        local body=status.body
        if type(body)~='string' or #body~=92 or not body:match('^%d%d%d%d%d%d%d%d%d%d:[0-9a-f]+:[0-9a-f]+$') then
          authorization=nil;mark('failed');return
        end
        a.challenge=body;mark('authorizing')
      end
      -- At most 2048 small hashes or 2ms per frame; never freeze a phone.
      local started=clock()
      for _=1,2048 do
        local ticket=a.challenge..':'..a.counter
        local ok,digest=pcall(love.data.hash,'sha256',ticket..':'..S.reportId)
        if not ok or type(digest)~='string' or #digest~=32 then authorization=nil;mark('failed');return end
        if digest:byte(1)==0 and digest:byte(2)<4 then
          authorization=nil;upload(ticket);break
        end
        a.counter=a.counter+1
        if clock()-started>=.002 then break end
      end
    end
    for _,target in ipairs(S.targets)do
      if target.sender and target.state=='pending' then
        local ok,state=pcall(target.sender.poll)
        if not ok then pcall(target.sender.cancel) end
        target.state=ok and state or 'failed'
      end
    end
    nextUpload()
  end
  function S.cancel()
    delivery=nil
    if authorization then releaseAuthorization(true);mark('cancelled') end
    for _,target in ipairs(S.targets)do
      if target.sender and (target.state=='pending' or target.state=='queued') then
        pcall(target.sender.cancel);target.state='cancelled'
      end
    end
  end
  S.refresh()
  return S
end
return M
