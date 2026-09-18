-- Coexistence adapter: generic sprites + unchanged legacy APO HD packages.
-- legacyBoot is the frozen renderer store; legacyWrite is its forkVerified().
local M={}
local function legacy(p)return p and p.adapter=="existing-HdContentStore" end
function M.new(d)
  local self={}
  function self:receipt(id)
    local p=d.catalog.packages[id]
    if legacy(p) then
      local row=d.legacyWrite.packages[id]
      if row and row.digest==p.manifestSha256 and row.manifest.revision==p.revision then
        return {verified=true,revision=p.revision,manifestSha256=row.digest}
      end
      return nil
    end
    return d.generic:receipt(id)
  end
  function self:hasChunk(h,n)
    if self.activeLegacy then return d.legacyWrite:hasChunk(h,n) end
    return d.generic:hasChunk(h,n)
  end
  function self:putChunk(h,raw)
    if self.activeLegacy then return d.legacyWrite:putChunk(h,raw) end
    return d.generic:putChunk(h,raw)
  end
  function self:inspect(raw,p)
    self.activeLegacy=legacy(p)
    if not self.activeLegacy then return d.generic:inspect(raw,p) end
    if type(raw)~="string" or #raw~=p.manifestBytes then return nil,"manifest_size_mismatch" end
    local m=d.legacyWrite:inspect(raw,p.manifestSha256)
    if not m or m.id~=p.id or m.revision~=p.revision then return nil,"legacy_manifest_mismatch" end
    local bytes=0;for _,f in ipairs(m.files) do bytes=bytes+f.bytes end
    if bytes~=p.fileBytes then return nil,"legacy_package_size_mismatch" end
    return m
  end
  function self:activate(raw,p,mount)
    if legacy(p) then
      -- Only the write view changes during downloads. A new launch constructs
      -- and verifies a new boot view; no in-scene renderer is hot-swapped.
      return d.legacyWrite:activate(raw,p.manifestSha256,true,true)
    end
    return d.generic:activate(raw,p,mount)
  end
  function self:styleMounted(id)
    local s=d.catalog.styles[id];if not s then return false end
    if s.kind=="native" then return true end
    if s.kind=="import" then return self:hasImport(id) end
    if s.activationPolicy=="any-package" then
      for _,key in ipairs(s.packages) do if self:packageMounted(key) then return true end end
      return false
    end
    for _,key in ipairs(s.packages) do
      local p=d.catalog.packages[key]
      if legacy(p) then
        local row=d.legacyBoot.packages[key]
        if not row or row.digest~=p.manifestSha256 then return false end
      elseif not d.generic.mounted[key] then return false end
    end
    return true
  end
  function self:packageMounted(key)
    local p=d.catalog.packages[key]
    if legacy(p) then
      local row=d.legacyBoot.packages[key];return row and row.digest==p.manifestSha256 or false
    end
    return d.generic:packageMounted(key)
  end
  function self:hasImport(id)return d.hasImport and d.hasImport(id)==true or false end
  return self
end
return M
