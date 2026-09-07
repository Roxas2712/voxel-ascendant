-- Private VASC working-set primitive, not an APO layout or gameplay owner.
-- A caller supplies its complete frame demands BEFORE shadow/eye/reflection
-- passes. Each bank is one exact direction row; no frame/pixel resampling.
-- Not wired to the renderer until its frame/UV adapter has been verified.
local M={}
local function integer(n,a,b)
  return type(n)=="number" and n==math.floor(n) and n>=a and n<=b
end
local function denseArray(value,minimum,maximum)
  if type(value)~="table"then return false end
  local count=0
  for key in pairs(value)do
    if not integer(key,1,maximum)then return false end
    count=count+1
  end
  if count<minimum or count>maximum then return false end
  for n=1,count do if value[n]==nil then return false end end
  return true
end
local function release(object)
  if object and type(object.release)=="function"then pcall(object.release,object)end
end
function M.new(deps)
  local budget=assert(deps.budgetBytes)
  assert(integer(budget,1,512*1024*1024),"invalid bank budget")
  local entries,failed={},{}
  local self={active=false,serial=0,bytes=0,peakBytes=0,decodes=0,uploads=0,releases=0}
  local function evict(key)
    local entry=entries[key]
    if not entry then return end
    release(entry.texture);entries[key]=nil
    self.bytes=self.bytes-entry.bytes;self.releases=self.releases+1
  end
  local function describe(bank)
    if type(bank)~="table" or type(bank.path)~="string" or #bank.path<1
      or #bank.path>1024 or not integer(bank.row,0,3)then
      return nil,"invalid_bank"
    end
    local ok,info=pcall(deps.info,bank.path)
    if not ok or type(info)~="table" or type(info.sha256)~="string"
      or #info.sha256~=64 or info.sha256:find("[^0-9a-f]")
      or not integer(info.width,1,16384) or not integer(info.height,4,16384)
      or info.height%4~=0 or info.width*info.height*4>64*1024*1024 then
      return nil,"unverified_source"
    end
    local h=info.height/4
    return {key=info.sha256..":"..bank.row,path=bank.path,row=bank.row,
      width=info.width,height=h,sourceHeight=info.height,bytes=info.width*h*4}
  end
  function self:beginFrame(scene,actors)
    if self.active then return nil,"frame_still_active"end
    if self.closed then return nil,"closed"end
    if scene==nil or not denseArray(actors,0,256)then return nil,"invalid_frame"end
    local sorted,ids={},{}
    for _,actor in ipairs(actors)do
      if type(actor)~="table" or type(actor.id)~="string" or #actor.id<1
        or #actor.id>256 or ids[actor.id] or not denseArray(actor.banks,1,16)then
        return nil,"invalid_actor"
      end
      ids[actor.id]=true;sorted[#sorted+1]=actor
    end
    self.serial=self.serial+1
    if self.scene~=scene then
      for key in pairs(entries)do evict(key)end
      failed={};self.scene=scene
    end
    -- Follower priority affects only resource admission, never spawn/counts.
    table.sort(sorted,function(a,b)
      local pa,pb=a.context=="follower" and 0 or 1,b.context=="follower" and 0 or 1
      if pa~=pb then return pa<pb end
      local da,db=tonumber(a.distance) or math.huge,tonumber(b.distance) or math.huge
      if da~=da then da=math.huge end;if db~=db then db=math.huge end
      if da~=db then return da<db end
      return a.id<b.id
    end)
    local wanted,planned,result={},0,{}
    for _,actor in ipairs(sorted)do
      local specs,own,extra,reason={},{},0,nil
      for _,bank in ipairs(actor.banks)do
        local spec,why=describe(bank)
        if not spec then reason=why;break end
        if failed[spec.key]then reason="source_failed";break end
        specs[#specs+1]=spec
        if not own[spec.key] and not wanted[spec.key]then extra=extra+spec.bytes end
        own[spec.key]=spec
      end
      if not reason and planned+extra>budget then reason="gpu_budget"end
      if reason then result[actor.id]={reason=reason}
      else
        planned=planned+extra
        for key,spec in pairs(own)do wanted[key]=spec end
        result[actor.id]={specs=specs}
      end
    end
    -- No handle from the previous frame is pinned now. Retain warm rows only
    -- when every bank promised to this frame fits; evict oldest unused first.
    local need,unused=0,{}
    for key,spec in pairs(wanted)do if not entries[key]then need=need+spec.bytes end end
    for key,entry in pairs(entries)do
      if not wanted[key]then unused[#unused+1]={key=key,last=entry.last}end
    end
    table.sort(unused,function(a,b)return a.last==b.last and a.key<b.key or a.last<b.last end)
    for _,entry in ipairs(unused)do
      if self.bytes+need<=budget then break end
      evict(entry.key)
    end
    local groups={}
    for key,spec in pairs(wanted)do
      if not entries[key]then
        local group=groups[spec.path] or {};groups[spec.path]=group;group[#group+1]=spec
      end
    end
    -- One decoded source at a time, even when several actors share rows.
    -- Bounds/UV construction belongs to the caller via prepare(rowPixels).
    for path,specs in pairs(groups)do
      local pixels
      local ok=pcall(function()
        pixels=assert(deps.load(path));self.decodes=self.decodes+1
        local w,h=pixels:getDimensions()
        assert(w==specs[1].width and h==specs[1].sourceHeight,"source_dimensions")
        for _,spec in ipairs(specs)do
          local row,texture
          local made,value=pcall(function()
            row=assert(deps.newImageData(w,spec.height))
            row:paste(pixels,0,0,0,spec.row*spec.height,w,spec.height)
            local metadata=deps.prepare and deps.prepare(row,spec) or nil
            texture=assert(deps.newImage(row))
            return {texture=texture,metadata=metadata,bytes=spec.bytes,
              width=w,height=spec.height,sourceRow=spec.row,last=self.serial}
          end)
          release(row)
          if made then
            entries[spec.key]=value;self.bytes=self.bytes+spec.bytes
            self.peakBytes=math.max(self.peakBytes,self.bytes);self.uploads=self.uploads+1
          else release(texture);failed[spec.key]=true end
        end
      end)
      release(pixels)
      if not ok then for _,spec in ipairs(specs)do failed[spec.key]=true end end
    end
    local accepted,rejected=0,0
    for _,row in pairs(result)do
      if row.specs then
        row.banks={}
        for _,spec in ipairs(row.specs)do
          local entry=entries[spec.key]
          if not entry or failed[spec.key]then row.reason="source_failed";break end
          entry.last=self.serial;row.banks[#row.banks+1]=entry
        end
        row.specs=nil
      end
      if row.reason then row.banks=nil;rejected=rejected+1 else accepted=accepted+1 end
    end
    self.active=true;self.accepted,self.rejected=accepted,rejected
    return result
  end
  function self:endFrame()self.active=false end
  function self:close()
    for key in pairs(entries)do evict(key)end
    failed={};self.active=false;self.closed=true
  end
  function self:health()
    local count=0;for _ in pairs(entries)do count=count+1 end
    return {banks=count,textureBytes=self.bytes,peakTextureBytes=self.peakBytes,
      decodes=self.decodes,uploads=self.uploads,releases=self.releases,
      accepted=self.accepted or 0,rejected=self.rejected or 0,active=self.active}
  end
  return self
end
return M
