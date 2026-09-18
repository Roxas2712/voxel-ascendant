-- Sequential import of a user-selected .spritepack. No extraction or script loading.
local M={MAGIC="VASC-SPRITES-1\n"}
function M.new(d)
  local self={state="idle"}
  local function close() if self.reader then pcall(self.reader.close,self.reader);self.reader=nil end end
  local function fail(err) close();self.state="error";self.error=err;return false,err end
  local function read(n)
    local ok,s=pcall(self.reader.read,self.reader,n)
    if ok and type(s)=="string" and #s==n then return s end
  end
  function self:start(reader,total,p,consent)
    if self.state=="importing" then return false,"busy" end
    self.reader=reader
    if consent~=true then return fail("confirmation_required") end
    if type(total)~="number" or total%1~=0 or total<1 or total>1073741824 then return fail("invalid_size") end
    local magic=p.adapter=="existing-HdContentStore" and "VASC-HD-PACK-1\n" or M.MAGIC
    local header=read(#magic+65+9)
    if not header or header:sub(1,#magic)~=magic then return fail("invalid_header") end
    local h=header:sub(#M.MAGIC+1,#M.MAGIC+64)
    local n=header:sub(-9,-2)
    if header:sub(#M.MAGIC+65,#M.MAGIC+65)~="\n" or header:sub(-1)~="\n" or not n:match("^[a-f0-9]+$")
      or h~=p.manifestSha256 or tonumber(n,16)~=p.manifestBytes or p.manifestBytes>4194304 then return fail("manifest_mismatch") end
    local raw=read(p.manifestBytes);local m,err=d.store:inspect(raw,p)
    if not m then return fail(err) end
    local chunks,seen={},{};local expected=#header+#raw
    for _,f in ipairs(m.files) do for _,c in ipairs(f.chunks) do
      if not seen[c.sha256] then chunks[#chunks+1]=c;seen[c.sha256]=true;expected=expected+c.bytes end
    end end
    if p.adapter~="existing-HdContentStore" then table.sort(chunks,function(a,b)return a.sha256<b.sha256 end)end
    if total~=expected then return fail("package_size_mismatch") end
    self.current=p;self.raw=raw;self.chunks=chunks;self.index=1;self.state="importing";return true
  end
  function self:update()
    if self.state~="importing" then return end
    local c=self.chunks[self.index]
    if c then
      local raw=read(c.bytes);if not raw then return fail("truncated_chunk") end
      local ok,err=d.store:putChunk(c.sha256,raw);if not ok then return fail(err) end
      self.index=self.index+1;return
    end
    local ok,tail=pcall(self.reader.read,self.reader,1)
    if not ok or (type(tail)=="string" and #tail>0) then return fail("trailing_bytes") end
    local yes,err=d.store:activate(self.raw,self.current,false)
    if not yes then return fail(err) end
    close();self.state="ready"
  end
  function self:busy()return self.state=="importing" end
  function self:cancel()close();self.state="cancelled" end
  return self
end
return M
