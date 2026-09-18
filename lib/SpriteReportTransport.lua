-- Preserve the actual receiver acknowledgement. Legacy POST has no response
-- body, so those engines must fetch the receiver's persisted receipt separately.
local M={}
function M.new(Fetch,decode)
  if type(Fetch)~='table' or type(Fetch.poll)~='function' or type(Fetch.release)~='function' then return nil end
  if type(Fetch.request)~='function' and not(type(Fetch.post)=='function' and type(Fetch.get)=='function')then return nil end
  local function clear(h,cancel)
    if not h.native then return end
    if cancel and Fetch.cancel then pcall(Fetch.cancel,h.native)end
    pcall(Fetch.release,h.native);h.native=nil
  end
  local self={}
  function self:post(url,body)
    local report=decode(body);local id=report and report.reportId
    if type(id)~='string' or #id>80 or not id:match('^[a-zA-Z0-9_.-]+$')then return nil end
    if Fetch.request then
      local native=Fetch.request(url,{method='POST',body=body,headers={['Content-Type']='application/json'},maxSeconds=12})
      return native and {native=native,phase='request',url=url,body=body,receipt=url..'/receipts/'..id}
    end
    local native=Fetch.post(url,body,{contentType='application/json',maxSeconds=10})
    return native and {native=native,phase='legacy-post',receipt=url..'/receipts/'..id}
  end
  function self:poll(h)
    if not h.native then return {status='error'}end
    local response=Fetch.poll(h.native)
    if type(response)=='table' and response.status=='error' and h.phase=='request'
      and type(Fetch.post)=='function' and type(Fetch.get)=='function' then
      -- Some mobile builds expose request(), but only have the older POST bridge.
      clear(h)
      h.native=Fetch.post(h.url,h.body,{contentType='application/json',maxSeconds=10})
      h.body=nil;h.phase='legacy-post'
      return {status=h.native and 'pending' or 'error'}
    end
    if type(response)~='table' or response.status~='ok' then return response end
    if h.phase=='legacy-post' then
      clear(h)
      h.native=Fetch.get(h.receipt,{accept='application/json',maxSeconds=5});h.phase='receipt'
      return {status=h.native and 'pending' or 'error'}
    end
    local code=tonumber(response.code)
    if h.phase=='request' and (not code or code<200 or code>=300)then return {status='error'}end
    if type(response.body)~='string' or #response.body>4096 then return {status='error'}end
    return {status='ok',body=response.body}
  end
  function self:release(h)clear(h)end
  function self:cancel(h)clear(h,true)end
  return self
end
return M
