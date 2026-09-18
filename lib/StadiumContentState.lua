-- Validate the generated DSM7 layout without textures, meshes or ROM access.
-- One model at a time: no roster-sized allocation and no GPU work.
local M={}
function M.validate(raw,species)
  local ok=pcall(function()
    assert(type(raw)=='string' and #raw>=735 and #raw<=16777216,'model size')
    local p=1
    local function skip(n)assert(n>=0 and p+n<=#raw+1,'truncated model');p=p+n end
    local function u8()local n=raw:byte(p);skip(1);return n end
    local function u16()local a,b=u8(),u8();return a+b*256 end
    local function u32()local a,b=u16(),u16();return a+b*65536 end
    assert(raw:sub(1,4)=='DSM7','model format');skip(4)
    assert(u16()==species,'model species')
    local bones,prims,textures,anims,aux,attachments=u16(),u16(),u16(),u16(),u16(),u16()
    assert(bones>0 and bones<=256 and prims>0,'empty geometry')
    skip(17) -- root scale, static flag and three stance floats
    skip(700) -- 165 move animations, 165 auxiliaries, 20 contexts
    skip(bones*27+attachments*4)
    for _=1,prims do
      skip(13) -- texture, render flags, tint and animation channel
      skip(u8()*3) -- texture map
      skip(u16()*2) -- effect textures
      local vertices,indices=u16(),u16()
      assert(vertices>0 and indices%3==0,'geometry counts')
      skip(vertices*14+indices*2)
    end
    for _=1,textures do
      local w,h,n=u16(),u16(),u32()
      assert(w>0 and h>0 and w<=4096 and h<=4096 and n==w*h*4,'texture size')
      skip(n)
    end
    for _=1,anims do
      skip(u8());local frames=u16();skip(4)
      assert(frames>0,'animation frames')
      for _=1,bones do
        local present=u8();assert(present<=1,'animation presence')
        if present==1 then
          for c=1,9 do
            local kind=u8();assert(kind<=1,'animation track')
            skip((c<=6 and 2 or 4)*(kind==0 and 1 or frames))
          end
        end
      end
    end
    for _=1,aux do
      skip(4);local channels=u16()
      for _=1,channels do skip(u16()*2)end
    end
    assert(p==#raw+1,'trailing model bytes')
  end)
  return ok
end
function M.inspect(fs,dir,format,revision,wanted)
  local ok,result=pcall(function()
    local raw=fs.read(dir..'/pack.info')
    if type(raw)~='string' or #raw>256 then return false end
    local f,count,md5,rev=raw:match('^(%S+)%s+(%d+)%s+(%x+)%s+(%d+)%s*$')
    count=tonumber(count)
    if f~=format or tonumber(rev)~=revision or not md5 or #md5~=32
      or not count or count<wanted or count>251 then return false end
    for species=1,count do
      local path=('%s/%03d.dsm'):format(dir,species)
      local info=fs.getInfo(path,'file')
      if not info or not info.size or info.size<735 or info.size>16777216 then return false end
      local bytes=fs.read(path)
      if type(bytes)~='string' or #bytes~=info.size or not M.validate(bytes,species)then return false end
    end
    return true
  end)
  return ok and result==true
end
-- Explicit generated-file allowlist. No source ROMs or unrelated saved files.
function M.path(key)
  if type(key)~='string' then return nil end
  local dir,name=key:match('^stadium%-generated/([^/]+)/(.+)$')
  if dir~='stadium' and dir~='stadium2-gen1' then return nil end
  if name=='pack.info' or name:match('^%d%d%d%.dsm$')
    or name=='lugia_debug/249.dsm' or name=='lugia_debug/249_geo_dump.txt'
    or name=='lugia_debug/UPLOAD_THESE_TWO_FILES.txt' then return 'cache/'..dir..'/'..name end
end
function M.inventory(fs)
  local ok,row=pcall(function()
    local r={id='stadium2-local',activationKeys={},payloadKeys={}}
    for _,dir in ipairs({'stadium','stadium2-gen1'})do
      local prefix='stadium-generated/'..dir..'/'
      local any=false
      for _,sub in ipairs({'','lugia_debug/'})do
        local path='cache/'..dir..'/'..sub
        local info=fs.getInfo(path:gsub('/$',''),'directory')
        if info then
          local items=assert(fs.getDirectoryItems(path),'directory unavailable')
          for _,name in ipairs(items)do
            local key=prefix..sub..name
            if M.path(key)then r.payloadKeys[#r.payloadKeys+1]=key;any=true end
          end
        end
      end
      if any then r.activationKeys[#r.activationKeys+1]=prefix..'pack.info'end
    end
    return r
  end)
  return ok and row or nil
end
return M
