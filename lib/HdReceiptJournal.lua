-- Bounded, origin-bound transaction receipts. Tokens identify one download,
-- never a device. Two checked slots survive a torn write; expiry is <=24 h.
local M={}
local LIMIT=32768
local function hex(s,n)return type(s)=="string" and #s==n and not s:find("[^0-9a-f]")end
local function integer(n,a,b)return type(n)=="number" and n==math.floor(n)and n>=a and n<=b end
local function packageId(s)return type(s)=="string"and s:match("^apo%.pokemon%-hd%.g%d%d%.dex%d%d%d%d%-%d%d%d%d$")~=nil end
function M.new(d)
  assert(type(d.origin)=="string" and d.origin:match("^https://[^/%?#@%s|]+$"),'invalid receipt origin')
  local cache,hash,now=assert(d.cache),assert(d.sha256),assert(d.now)
  local self={origin=d.origin};local sequence,slot,entries=0,1,{}
  local function read(which)
    local path="hd-content/receipts."..which
    local ok,info=pcall(cache.info,cache,path)
    if not ok or type(info)~="table" or info.type~="file" or not integer(info.size,1,LIMIT)then return nil end
    local good,raw=pcall(cache.read,cache,path)
    return good and type(raw)=="string" and #raw==info.size and raw or nil
  end
  local function parse(raw)
    if not raw then return nil end
    local prefix,digest=raw:match("^(.*\n)([0-9a-f]+)$")
    if not prefix or not hex(digest,64)or hash(prefix)~=digest then return nil end
    local lines={};for line in prefix:gmatch("([^\n]*)\n")do lines[#lines+1]=line end
    local seq=tonumber(lines[2])
    if lines[1]~="VASC-HD-RECEIPTS-1" or not integer(seq,1,2147483647)
        or lines[3]~=d.origin or #lines>67 then return nil end
    local rows={}
    for n=4,#lines do
      local id,manifest,ticket,expiry=lines[n]:match("^([^|]+)|([^|]+)|([^|]+)|(%d+)$")
      expiry=tonumber(expiry)
      if not packageId(id)or rows[id]or not hex(manifest,64)or not hex(ticket,48)
          or not integer(expiry,1,4102444800)then return nil end
      rows[id]={id=id,digest=manifest,ticket=ticket,expires=expiry}
    end
    return {sequence=seq,entries=rows}
  end
  for candidate=0,1 do
    local ok,value=pcall(parse,read(candidate))
    if ok and value and value.sequence>sequence then sequence,slot,entries=value.sequence,candidate,value.entries end
  end
  local function save()
    if sequence>=2147483647 then return false end
    local ids={};for id in pairs(entries)do ids[#ids+1]=id end;table.sort(ids)
    if #ids>64 then return false end
    local lines={"VASC-HD-RECEIPTS-1",tostring(sequence+1),d.origin}
    for _,id in ipairs(ids)do
      local row=entries[id]
      lines[#lines+1]=table.concat({row.id,row.digest,row.ticket,tostring(row.expires)},"|")
    end
    local prefix=table.concat(lines,"\n").."\n"
    local raw=prefix..hash(prefix);if #raw>LIMIT then return false end
    local nextSlot=1-slot
    local ok,result=pcall(cache.write,cache,"hd-content/receipts."..nextSlot,raw)
    if not ok or result~=true or read(nextSlot)~=raw then return false end
    sequence,slot=sequence+1,nextSlot;return true
  end
  function self:list()
    local time=now();local result={};local expired=false
    if not integer(time,1,4102444800)then return result end
    for id,row in pairs(entries)do
      if row.expires<=time then entries[id]=nil;expired=true
      else result[#result+1]={id=row.id,digest=row.digest,ticket=row.ticket,expires=row.expires}end
    end
    if expired then pcall(save)end
    table.sort(result,function(a,b)return a.id<b.id end)
    return result
  end
  function self:put(id,digest,ticket,ttl)
    local time=now()
    if not packageId(id)or not hex(digest,64)or not hex(ticket,48)
        or not integer(time,1,4102358400)then return false end
    self:list()
    local count=0;for _ in pairs(entries)do count=count+1 end
    if not entries[id]and count>=64 then return false end
    ttl=integer(ttl,1,86400)and ttl or 86400
    entries[id]={id=id,digest=digest,ticket=ticket,expires=time+ttl}
    return save()
  end
  function self:remove(id,ticket)
    if not entries[id]then return true end
    if entries[id].ticket~=ticket then return false end
    entries[id]=nil;return save()
  end
  return self
end
return M
