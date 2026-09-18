-- Data-only package planning. No filesystem, network or rendering side effects.
local M = {SCHEMA="vasc.sprite-catalog/v1"}
local function id(v) return type(v)=="string" and #v<=160 and v:match("^[a-z0-9][a-z0-9_.-]*$") end
local function integer(v) return type(v)=="number" and v>=0 and v%1==0 and v<9007199254740991 end
local function digest(v) return type(v)=="string" and #v==64 and not v:find("[^a-f0-9]") end
function M.new(data)
  assert(type(data)=="table" and data.schema==M.SCHEMA,"invalid catalog schema")
  local self={data=data,packages={},styles={}}
  assert(type(data.packages)=="table" and #data.packages<=4096,"invalid packages")
  for _,p in ipairs(data.packages) do
    assert(id(p.id) and not self.packages[p.id],"invalid/duplicate package id")
    assert(integer(p.revision) and p.revision>0 and integer(p.fileBytes) and p.fileBytes>0 and p.fileBytes<=(p.adapter=="existing-HdContentStore" and 134217728 or 67108864),"invalid package size/revision")
    assert(integer(p.manifestBytes) and p.manifestBytes>0 and p.manifestBytes<=4194304,"invalid manifest size")
    assert(digest(p.manifestSha256),"invalid manifest digest")
    assert(type(p.dependencies)=="table" and #p.dependencies<=32,"missing/excessive dependencies")
    self.packages[p.id]=p
  end
  local visited,visiting={},{}
  local function visit(key)
    assert(self.packages[key],"missing dependency: "..tostring(key))
    assert(not visiting[key],"dependency cycle")
    if visited[key] then return end
    visiting[key]=true
    for _,dep in ipairs(self.packages[key].dependencies) do visit(dep) end
    visiting[key]=nil;visited[key]=true
  end
  for key in pairs(self.packages) do visit(key) end
  assert(type(data.styles)=="table" and #data.styles<=1024,"missing/excessive styles")
  for _,s in ipairs(data.styles) do
    assert(id(s.id) and not self.styles[s.id],"invalid/duplicate style")
    assert(s.kind=="native" or s.kind=="download" or s.kind=="import","invalid style kind")
    assert(type(s.packages)=="table","missing style packages")
    for _,key in ipairs(s.packages) do assert(self.packages[key],"unknown style package") end
    assert(s.kind~="download" or #s.packages>0,"empty download style")
    assert(s.kind=="download" or #s.packages==0,"native/import styles cannot contain downloads")
    assert(s.activationPolicy==nil or s.activationPolicy=="any-package","invalid activation policy")
    if s.recommendedPackages then
      assert(type(s.recommendedPackages)=="table" and #s.recommendedPackages>0,"invalid recommended packages")
      local member={};for _,key in ipairs(s.packages) do member[key]=true end
      for _,key in ipairs(s.recommendedPackages) do assert(member[key],"recommendation outside style") end
    end
    self.styles[s.id]=s
  end
  -- A receipt is trusted only after the adapter has verified/restored its files.
  function self:installed(key,store)
    local p=self.packages[key]
    if not p or not store or type(store.receipt)~="function" then return false end
    local ok,r=pcall(store.receipt,store,key)
    return ok and type(r)=="table" and r.verified==true
      and r.manifestSha256==p.manifestSha256 and r.revision==p.revision
  end
  function self:plan(keys,store)
    local result={packages={},missing={},unavailable={},fileBytes=0,downloadBytes=0,seen={}}
    local function add(key)
      local p=assert(self.packages[key],"unknown package")
      if result.seen[key] then return end
      result.seen[key]=true
      for _,dep in ipairs(p.dependencies) do add(dep) end
      result.packages[#result.packages+1]=key
      if not self:installed(key,store) then
        result.missing[#result.missing+1]=key
        result.fileBytes=result.fileBytes+p.fileBytes
        if p.published~=true then result.unavailable[#result.unavailable+1]=key end
      end
    end
    for _,key in ipairs(keys) do add(key) end
    -- Accurate transfer estimate with content-addressed cross-package dedup.
    local chunks={};local exact=true
    for _,key in ipairs(result.missing) do
      local p=self.packages[key]
      if p.transferBytes then exact=false;result.downloadBytes=result.downloadBytes+p.transferBytes
      elseif not p.chunks then exact=false;result.downloadBytes=result.downloadBytes+p.fileBytes
      else
        for _,c in ipairs(p.chunks) do
          assert(digest(c.sha256) and integer(c.bytes) and c.bytes>0 and c.bytes<=4194304,"invalid chunk")
          assert(not chunks[c.sha256] or chunks[c.sha256]==c.bytes,"conflicting chunk length")
          if not chunks[c.sha256] then
            chunks[c.sha256]=c.bytes
            local ok,held=false,false
            if store and type(store.hasChunk)=="function" then ok,held=pcall(store.hasChunk,store,c.sha256,c.bytes) end
            if not ok or held~=true then result.downloadBytes=result.downloadBytes+c.bytes end
          end
        end
      end
    end
    result.estimateExact=exact;result.ready=#result.missing==0
    result.canDownload=#result.missing>0 and #result.unavailable==0
    return result
  end
  function self:stylePlan(key,store)
    local s=assert(self.styles[key],"unknown style")
    local p=self:plan(s.packages,store);p.style=key;p.kind=s.kind
    if s.activationPolicy=="any-package" then
      local installed={}
      for _,id in ipairs(s.packages) do if self:installed(id,store) then installed[#installed+1]=id end end
      if #installed>0 then
        local optional=p.missing;p=self:plan(installed,store);p.optionalPackages=optional
        p.style=key;p.kind=s.kind;p.partial=#optional>0
      else
        p=self:plan(s.recommendedPackages or {s.packages[1]},store)
        p.style=key;p.kind=s.kind;p.partial=true
      end
    end
    if s.kind=="import" then
      local ok,yes=false,false
      if store and type(store.hasImport)=="function" then ok,yes=pcall(store.hasImport,store,key) end
      p.ready=ok and yes==true;p.canDownload=false
    end
    return p
  end
  return self
end
return M
