-- Runtime adapter for the same saved-layer compositor used by the offline
-- builder. No procedural fallback, rig changes or native sprite transforms.
return function(mod,opts)
  local W,C,O=assert(opts.wardrobe),assert(opts.catalog),assert(opts.compositor)
  local A={schema='kasc.wardrobe.assets/v2',built=0,cache={},receipts={},packages={},errors={}}
  local ROOT='wardrobe/authored-v1/'
  local logical='mod_cache/'..mod.id..'/'
  local maxEntries,maxBytes=opts.maxEntries or 96,opts.maxBytes or 32*1024*1024
  local order,sizes,requestOrder={},{},{}
  local required=opts.requiredActions or{'walk','fishing','bicycle'}
  assert(not opts.requiredActions or opts.allowDraft,'partial actions are draft-test-only')
  local function sha(bytes)return love.data.encode('string','hex',love.data.hash('sha256',bytes))end
  local function relative(path)
    return type(path)=='string'and path~=''and path:sub(1,1)~='/'and not path:find('..',1,true)
      and not path:find('\\',1,true)and not path:find(':',1,true)
  end
  local function filename(key)return ROOT..key..'.png'end
  local function index()
    local lines={};for _,key in ipairs(order)do lines[#lines+1]=key..' '..sizes[key]end
    local ok,err=mod.cache:write(ROOT..'index.txt',table.concat(lines,'\n'))
    assert(ok,err or'cannot save wardrobe cache index')
  end
  if mod.cache then
    local body=mod.cache:read(ROOT..'index.txt')
    if type(body)=='string'and #body<20000 then
      for key,size in body:gmatch('([0-9a-f]+) (%d+)')do
        if #key==64 and not sizes[key]then
          local info=mod.cache:info(filename(key))
          if info and info.type=='file'then order[#order+1]=key;sizes[key]=info.size or tonumber(size)end
        end
      end
    end
  end
  local function prune(keep)
    local total=0;for _,size in pairs(sizes)do total=total+size end
    while #order>maxEntries or total>maxBytes do
      local key=order[1]
      assert(key~=keep,'one wardrobe atlas exceeds cache limit')
      local ok,err=mod.cache:delete(filename(key));assert(ok,err or'cannot prune wardrobe cache')
      table.remove(order,1);total=total-sizes[key];sizes[key]=nil
      local path=logical..filename(key);A.receipts[path]=nil
      for request,value in pairs(A.cache)do if value==path then A.cache[request]=nil end end
    end
  end
  if mod.cache then prune();index()end
  function A.sources(id)
    local base=mod.path..'/assets/wardrobe/collection/'..id:lower()..'/source-'
    return{base..'walk.png',base..'fishing.png',base..'bicycle.png'}
  end
  local function actionFor(path,id)
    local paths=A.sources(id)
    for i,source in ipairs(paths)do if path==source then return({'walk','fishing','bicycle'})[i]end end
    -- Existing optional HD renderer atlases share the authored source hashes.
    -- KASC owns its copies, so composing clothes never requires that renderer.
    local renderer=mod.find and mod:find('VOXEL_ASCENDANT')
    local base=renderer and renderer.exports and renderer.exports.wardrobeSourceRoot
    if base then
      local role=id:lower()
      if path==base..role..'_cards_4x3.png'then return'walk'end
      for _,action in ipairs({'fishing','bicycle'})do
        if path==base..'actions/'..role..'/'..action..'_4x3.png'then return action end
      end
    end
  end
  function A.register(definition)
    assert(type(definition)=='table'and relative(definition.directory),'invalid wardrobe package directory')
    local pack=assert(definition.package)
    O.validate(pack,opts.allowDraft)
    local recipes=definition.recipes or pack.recipes
    assert(type(recipes)=='table','wardrobe package has no recipes')
    -- Validate the entire registration before publishing any catalog rows.
    local entries={}
    for id,recipe in pairs(recipes)do
      assert(type(id)=='string'and id:match('^[a-z][a-z0-9_-]*$'),'invalid outfit id')
      assert(type(recipe)=='table'and type(recipe.parts)=='table','invalid outfit recipe')
      for slot,part in pairs(recipe.parts)do assert(pack.parts[slot]and pack.parts[slot][part],'unknown recipe part '..slot..'/'..tostring(part))end
      for slot,variants in pairs(pack.parts)do
        local chosen=recipe.parts[slot]or pack.defaults[slot]
        local part=assert(variants[chosen],'missing default recipe part '..slot)
        for dependency,compatible in pairs(part.requires or{})do
          local target=recipe.parts[dependency]or pack.defaults[dependency];local matched=false
          for _,candidate in ipairs(compatible)do if candidate==target then matched=true end end
          assert(matched,'incompatible default recipe '..id..': '..slot..'/'..chosen)
        end
      end
      entries[#entries+1]={id=id,recipe=recipe}
    end
    table.sort(entries,function(a,b)return a.id<b.id end)
    for _,entry in ipairs(entries)do
      local key=pack.character..':'..entry.id
      assert(not A.packages[key],'duplicate wardrobe recipe '..key)
    end
    for _,entry in ipairs(entries)do
      A.packages[pack.character..':'..entry.id]={pack=pack,directory=definition.directory,recipe=entry.recipe}
      local existing=C.find(pack.character,entry.id)
      if not existing then
        C.characters[pack.character][#C.characters[pack.character]+1]={id=entry.id,
          en=entry.recipe.en or entry.id,de=entry.recipe.de or entry.id}
      else existing.en=entry.recipe.en or existing.en;existing.de=entry.recipe.de or existing.de end
    end
    A.cache={};requestOrder={}
    return true
  end
  function A.available(id,outfit)return A.packages[id..':'..outfit]~=nil end
  local function partsFor(record,selection)
    local parts={};for slot,id in pairs(record.recipe.parts)do parts[slot]=id end
    local defaults={upper='preset',lower='preset',footwear='preset',head='classic',hairstyle='standard',
      hair='natural',streak='none',eyewear='none',bag='preset'}
    for _,field in ipairs({'upper','lower','footwear','head','hairstyle','hair','streak','eyewear','bag'})do
      local default=defaults[field]
      local value=selection[field]or default
      if value~=default then
        local binding=record.recipe.bindings and record.recipe.bindings[field]
        local choice=binding and binding[value]
        assert(choice,'unavailable authored part: '..field..'/'..tostring(value))
        if type(choice)=='string'then parts[field]=choice
        else for slot,id in pairs(choice)do parts[slot]=id end end
      end
    end
    return parts
  end
  function A.parts(id,selection)
    local record=assert(A.packages[id..':'..selection.outfit],'unknown outfit')
    local result=partsFor(record,selection)
    for slot,value in pairs(record.pack.defaults)do if not result[slot]then result[slot]=value end end
    return result
  end
  -- Availability is metadata-only: browsing choices must not build every atlas.
  function A.compatible(id,selection)
    if selection.style=='native'or W.plain(selection)then return true end
    local record=A.packages[id..':'..tostring(selection.outfit)]
    if not record then return false end
    return pcall(function()
      local parts=partsFor(record,selection)
      for slot,variants in pairs(record.pack.parts)do
        local part=assert(variants[parts[slot]or record.pack.defaults[slot]])
        for dependency,values in pairs(part.requires or{})do
          local selected=parts[dependency]or record.pack.defaults[dependency];local found=false
          for _,value in ipairs(values)do if selected==value then found=true end end
          assert(found,'incompatible '..slot)
        end
      end
    end)
  end
  function A.options(id,selection,field)
    local result={};local candidate={};for k,v in pairs(selection)do candidate[k]=v end
    for _,value in ipairs(W.options[field]or{})do
      candidate[field]=value
      if A.compatible(id,candidate)then result[#result+1]=value end
    end
    return result
  end
  function A.forOutfit(id,selection)
    local result={};for k,v in pairs(selection)do result[k]=v end
    -- Outfit selection resets the garments, then carries only supported
    -- accessories. A backwards Lotta cap cannot break another outfit preview.
    for _,field in ipairs({'upper','lower','footwear'})do result[field]='preset'end
    local keep={};for _,field in ipairs({'head','bag','hairstyle','hair','streak','eyewear'})do
      keep[field]=result[field];result[field]=W.options[field][1]
    end
    for _,field in ipairs({'head','bag','hairstyle','hair','streak','eyewear'})do
      local value=keep[field];if value then
        result[field]=value
        if not A.compatible(id,result)then result[field]=W.options[field][1]end
      end
    end
    return result
  end
  local function requestKey(path,id,selection)
    local pieces={path,id}
    for _,field in ipairs({'outfit','upper','lower','footwear','head','hairstyle','hair','streak','eyewear','bag'})do
      pieces[#pieces+1]=tostring(selection[field]or'')
    end
    return table.concat(pieces,'\0')
  end
  function A.resolve(path,id,selection)
    if not W.appearanceReady or selection.style=='native'or W.plain(selection)then return path end
    local action=actionFor(path,id)
    if not action then return path end -- native and unrelated graphics are never inputs
    local record=assert(A.packages[id..':'..selection.outfit],'authored outfit unavailable')
    assert(mod.cache,'scoped wardrobe cache unavailable')
    local request=requestKey(path,id,selection)
    local hit=A.cache[request]
    if hit and mod.cache:exists(hit:sub(#logical+1))then return hit end
    local base=love.image.newImageData(path)
    local actualSource=sha(base:getString());base:release()
    local atlas=assert(record.pack.atlases[action],'missing authored action '..action)
    assert(actualSource==atlas.source.sha256,'HD source differs from authored template')
    local deps={newImage=love.image.newImageData,sha256=sha,read=function(file)
      return love.image.newImageData(mod.path..'/'..record.directory..'/'..file)
    end}
    local output,receipt=O.build(record.pack,action,partsFor(record,selection),deps,{allowDraft=opts.allowDraft,hair=selection.hair,streak=selection.streak})
    local png=output:encode('png');output:release()
    local bytes=png:getString();png:release()
    assert(#bytes<=maxBytes,'one wardrobe atlas exceeds cache limit')
    local key=receipt.cacheKey;local file=filename(key)
    if mod.cache:read(file)~=bytes then
      local ok,err=mod.cache:write(file,bytes);assert(ok,err or'wardrobe cache write failed')
    end
    for i=#order,1,-1 do if order[i]==key then table.remove(order,i)end end
    order[#order+1]=key;sizes[key]=#bytes;prune(key);index()
    local resolved=logical..file
    receipt.source=path;receipt.character=id;receipt.outfit=selection.outfit
    A.receipts[resolved]=receipt;A.cache[request]=resolved;A.built=A.built+1
    requestOrder[#requestOrder+1]=request
    if #requestOrder>256 then A.cache[table.remove(requestOrder,1)]=nil end
    return resolved
  end
  function A.prepare(id,selection)
    if selection.style=='native'or W.plain(selection)then return true end
    if not W.appearanceReady then return false,'art-under-revision'end
    if not A.available(id,selection.outfit)then return false,'authored-outfit-unavailable'end
    if W.walker2d and not W.presentation.hd()then
      return pcall(W.walker2d.build,id,selection)
    end
    local sources=A.sources(id);if #sources==0 then return false,'hd-source-unavailable'end
    local actions={walk=1,fishing=2,bicycle=3}
    return pcall(function()
      for _,action in ipairs(required)do
       local source=sources[assert(actions[action])]
       if W.presentation.mode(selection)=='voxel'then W.presentation.resolve(source,id,selection,action)
       else A.resolve(source,id,selection)end
      end
    end)
  end
  function A.health()
    local count,bytes=0,0;for _,size in pairs(sizes)do count=count+1;bytes=bytes+size end
    return{entries=count,bytes=bytes,maxEntries=maxEntries,maxBytes=maxBytes,built=A.built}
  end
  return A
end
