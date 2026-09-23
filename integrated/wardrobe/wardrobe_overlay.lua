-- Deterministic authored-patch compositor. No animation or gameplay state.
-- Inputs are saved RGBA layers + binary replacement coverage, never prompts.
local M={format='kasc.wardrobe.layers/v1',version='authored-overlay-1'}
local order={'lower','upper','footwear','hair','head','eyewear','accessory'}
local hairColors={black={.13,.14,.16},brown={.53,.29,.14},blond={.95,.75,.38},silver={.89,.91,.94},red={.75,.20,.15},blue={.22,.43,.78},purple={.56,.28,.68}}
local allowed={};for _,slot in ipairs(order)do allowed[slot]=true end
local function need(ok,message)if not ok then error('wardrobe overlay: '..message,0)end end
local function relative(path)
  return type(path)=='string'and path~=''and not path:find('..',1,true)
    and not path:find('\\',1,true)and not path:find(':',1,true)and path:sub(1,1)~='/'
end
local function same(a,b,x,y)
  local r,g,blue,alpha=a:getPixel(x,y);local R,G,B,A=b:getPixel(x,y)
  return r==R and g==G and blue==B and alpha==A
end
function M.validate(pack,allowDraft)
  need(type(pack)=='table'and pack.format==M.format,'unsupported manifest format')
  need(pack.character=='RED'or pack.character=='BLUE'or pack.character=='GREEN','unknown character')
  need(type(pack.id)=='string'and pack.id~='','missing package id')
  need(type(pack.revision)=='number'and pack.revision>=1 and pack.revision%1==0,'invalid revision')
  need(pack.status=='reviewed'or allowDraft and pack.status=='draft','art is not reviewed')
  need(type(pack.atlases)=='table'and type(pack.parts)=='table'and type(pack.defaults)=='table','incomplete manifest')
  if not allowDraft then
    for _,action in ipairs({'walk','fishing','bicycle'})do need(pack.atlases[action],'missing action '..action)end
  end
  for slot in pairs(pack.parts)do need(allowed[slot],'unknown part slot '..tostring(slot))end
  for slot in pairs(pack.defaults)do need(pack.parts[slot],'default for missing slot '..tostring(slot))end
  if not allowDraft then
    for slot,parts in pairs(pack.parts)do for id,part in pairs(parts)do
      for _,action in ipairs({'walk','fishing','bicycle'})do
        need(part.atlases and part.atlases[action],'missing '..action..' frames for '..slot..'/'..id)
      end
    end end
  end
  return true
end
function M.build(pack,action,selection,deps,opts)
  opts=opts or{};M.validate(pack,opts.allowDraft)
  selection=selection or{}
  for slot in pairs(selection)do need(pack.parts[slot],'unknown selection slot '..tostring(slot))end
  local atlas=pack.atlases[action];need(atlas,'missing action '..tostring(action))
  need(type(atlas.width)=='number'and type(atlas.height)=='number'and atlas.width>0 and atlas.height>0,'invalid atlas dimensions')
  need(atlas.columns==3 and atlas.rows==4,'HD atlas must contain the existing 3 x 4 frames')
  need(atlas.width%atlas.columns==0 and atlas.height%atlas.rows==0,'non-integral frame dimensions')
  local owned={}
  local function load(spec,label)
    need(type(spec)=='table'and relative(spec.file),'invalid '..label..' path')
    local data=assert(deps.read(spec.file));owned[#owned+1]=data
    local w,h=data:getDimensions();need(w==atlas.width and h==atlas.height,label..' dimensions differ from source')
    need(type(spec.sha256)=='string'and deps.sha256(data:getString())==spec.sha256,label..' hash mismatch')
    return data
  end
  local ok,result,receipt=pcall(function()
    local base=load(atlas.source,'source');local protect=load(atlas.protect,'protected mask')
    local output=deps.newImage(atlas.width,atlas.height)
    owned[#owned+1]=output;output:paste(base,0,0,0,0,atlas.width,atlas.height)
    local cw,ch=atlas.width/atlas.columns,atlas.height/atlas.rows
    local hashes={M.version,pack.character,action,atlas.source.sha256,atlas.protect.sha256}
    local parts={}
    for _,slot in ipairs(order)do
      if slot=='eyewear'and((opts.hair and opts.hair~='natural')or(opts.streak and opts.streak~='none'))then
        local hair=opts.hair or'natural';local streak=opts.streak or'none'
        need(hair=='natural'or hairColors[hair],'unknown hair color');need(streak=='none'or hairColors[streak],'unknown streak color')
        local head=selection.head or pack.defaults.head
        local spec=pack.materials and pack.materials.hair and pack.materials.hair[head]and pack.materials.hair[head][action]
        need(spec,'missing hair ownership for selected head');local mask=load(spec,'hair ownership')
        for y=0,atlas.height-1 do for x=0,atlas.width-1 do
          local lock,_,_,a=mask:getPixel(x,y)
          need(a==0 or a==1,'hair ownership must be binary')
          if a==1 then
            local _,_,_,protected=protect:getPixel(x,y);need(protected==0,'hair overlaps protected pixels')
            local r,g,b,alpha=output:getPixel(x,y);local shade=.35+.65*math.max(r,g,b)
            if hair~='natural'then local color=hairColors[hair];r,g,b=color[1]*shade,color[2]*shade,color[3]*shade end
            if streak~='none'and lock>0 then local color=hairColors[streak]
              r,g,b=r*(1-lock)+color[1]*shade*lock,g*(1-lock)+color[2]*shade*lock,b*(1-lock)+color[3]*shade*lock
            end
            output:setPixel(x,y,r,g,b,alpha)
          end
        end end
        hashes[#hashes+1]='hair/'..hair..'/'..streak..'/'..spec.sha256
      end
      if pack.parts[slot]then
      local id=selection[slot]or pack.defaults[slot]
      local part=pack.parts[slot][id];need(part,'unknown '..slot..' part '..tostring(id))
      for dependency,compatible in pairs(part.requires or{})do
        need(pack.parts[dependency]and type(compatible)=='table','invalid compatibility requirement for '..slot)
        local chosen=selection[dependency]or pack.defaults[dependency];local matches=false
        for _,candidate in ipairs(compatible)do if candidate==chosen then matches=true end end
        need(matches,'incompatible '..slot..'/'..id..' with '..dependency..'/'..tostring(chosen))
      end
      local patch=part.atlases and part.atlases[action]
      need(patch,'missing '..action..' frames for '..slot..'/'..id)
      need(patch.seam==atlas.seam,'incompatible frame/seam template for '..slot..'/'..id)
      local rgba=load(patch.rgba,slot..' RGBA');local coverage=load(patch.coverage,slot..' coverage')
      local counts={};for frame=1,atlas.columns*atlas.rows do counts[frame]=0 end
      for y=0,atlas.height-1 do for x=0,atlas.width-1 do
        local _,_,_,replace=coverage:getPixel(x,y)
        need(replace==0 or replace==1,slot..' replacement mask must be binary')
        local _,_,_,a=rgba:getPixel(x,y)
        if replace==1 then
          local _,_,_,protected=protect:getPixel(x,y)
          need(protected==0,slot..' overlaps protected source pixels')
          output:setPixel(x,y,rgba:getPixel(x,y))
          local frame=math.floor(y/ch)*atlas.columns+math.floor(x/cw)+1
          counts[frame]=counts[frame]+1
        else need(a==0,slot..' has visible RGBA outside its replacement mask')end
      end end
      need(type(patch.framePixels)=='table'and #patch.framePixels==12,'missing frame inventory for '..slot)
      for frame=1,12 do need(counts[frame]==patch.framePixels[frame],'frame coverage changed: '..slot..' frame '..frame)end
      hashes[#hashes+1]=slot..'/'..id;hashes[#hashes+1]=patch.rgba.sha256;hashes[#hashes+1]=patch.coverage.sha256
      parts[#parts+1]={slot=slot,id=id,framePixels=counts}
    end end
    for y=0,atlas.height-1 do for x=0,atlas.width-1 do
      local _,_,_,p=protect:getPixel(x,y)
      need(p==0 or p==1,'protected mask must be binary')
      if p==1 then need(same(output,base,x,y),'protected source pixel changed')end
    end end
    local record={package=pack.id,revision=pack.revision,action=action,character=pack.character,
      width=atlas.width,height=atlas.height,columns=atlas.columns,rows=atlas.rows,parts=parts,
      sourceSha256=atlas.source.sha256,outputSha256=deps.sha256(output:getString()),
      cacheKey=deps.sha256(table.concat(hashes,'\0')),draft=pack.status~='reviewed'}
    return output,record
  end)
  for _,data in ipairs(owned)do if not ok or data~=result then data:release()end end
  if not ok then error(result,0)end
  return result,receipt
end
return M
