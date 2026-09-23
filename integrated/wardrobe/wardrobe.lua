-- Save-local clothing authority. Animation/rendering consumers only resolve
-- appearance; this module never advances a frame or changes gameplay stats.
return function(mod,opts)
  opts=opts or{}
  local C=assert(opts.catalog)
  local M={schema='kasc.wardrobe/v1',catalog=C,revision=0,errors={}}
  M.appearanceReady=opts.appearanceReady~=false
  local KEY='wardrobe_v1'
  local options={head={'classic','none','backward','beanie','ash','ash_back'},bag={'preset','original','pink'},style={'hd','native'},
    hair={'natural','black','brown','blond','silver','red','blue','purple'},
    streak={'none','blond','silver','red','blue','purple'},
    eyewear={'none','glasses','sunglasses'},hairstyle={'standard','spiky'},upper=C.uppers,lower=C.lowers,footwear=C.footwear}
  M.options=options
  local function valid(key,value)
    for _,candidate in ipairs(options[key])do if value==candidate then return true end end
    return false
  end
  local function normalize(row,id)
    row=type(row)=='table'and row or{}
    local result={outfit=(row.outfit=='original'or C.find(id,row.outfit))and row.outfit or'original'}
    for key,values in pairs(options)do result[key]=valid(key,row[key])and row[key]or values[1]end
    if id~='RED'or result.head~='none'then result.hairstyle='standard'end
    return result
  end
  local game
  local active=true
  function M.isActive()return active end
  function M.setActive(value,g)
    local changed=active~=(value==true);active=value==true;game=g or game
    if changed and game then M.refresh(game)end
  end
  local function char(id)
    id=tostring(id or 'RED'):upper()
    return C.characters[id] and id or 'RED'
  end
  local function copy(t)local o={};for k,v in pairs(t or{})do o[k]=type(v)=='table'and copy(v)or v end;return o end
  function M.character()
    local api=mod.exports.extendedCharacters
    return char(api and api.getPlayerCharacter())
  end
  function M.get(id)
    id=char(id)
    local state=mod.save:get(KEY)
    local row=type(state)=='table'and type(state.characters)=='table'and state.characters[id]
    return normalize(row,id)
  end
  function M.native(id)return active and M.get(id).style=='native'end
  function M.token(id)
    local row=M.get(id);local parts={active and'on'or'off',char(id),row.outfit}
    for _,key in ipairs({'head','bag','style','hairstyle','hair','streak','eyewear','upper','lower','footwear'})do parts[#parts+1]=row[key]end
    return table.concat(parts,':')
  end
  function M.plain(selection)
    -- A character-specific recipe (e.g. Green's Lotta) need not exist in Red's
    -- catalog. Never normalize its outfit id through a different character:
    -- that used to turn the recipe into 'original' whenever all parts used
    -- their defaults, silently bypassing both preparation and rendering.
    if type(selection)=='table'and selection.outfit and selection.outfit~='original'then return false end
    local row=normalize(selection,'RED')
    return row.outfit=='original'and row.head=='classic'and row.hair=='natural'
      and row.streak=='none'and row.eyewear=='none'and row.upper=='preset'and row.lower=='preset'and row.footwear=='preset'
      and(row.bag=='preset'or row.bag=='original')
  end
  function M.canChange(g)
    if not active then return false,'card-disabled'end
    g=g or game
    if not g or not g.save then return false,'no-save'end
    local world=g.overworld or g.world
    local p=world and world.player
    if g.battle or (g.stack and g.stack.top and g.stack:top()and g.stack:top().isBattle)
      or (p and (p.fishing or p.surfing or p.moving or p.onBike))then return false,'busy'end
    return true
  end
  function M.refresh(g)
    game=g or game
    M.revision=M.revision+1
    if opts.refresh then return opts.refresh(game)end
    local api=mod.exports.extendedCharacters
    if api and api.refreshVisuals then api.refreshVisuals(game)end
    local Runtime=require('src.mods.Runtime')
    Runtime.emit('wardrobe.changed',{game=game,character=M.character(),revision=M.revision})
  end
  function M.choose(id,selection,g)
    id=char(id);g=g or game
    local allowed,why=M.canChange(g);if not allowed then return false,why end
    if type(selection)~='table'then return false,'invalid-selection'end
    local candidate=M.get(id)
    for key,value in pairs(selection)do candidate[key]=value end
    if id=='RED'and selection.hairstyle=='spiky'and not selection.head then candidate.head='none'end
    if candidate.outfit~='original'and not C.find(id,candidate.outfit)then return false,'unknown-outfit'end
    for key in pairs(options)do if not valid(key,candidate[key])then return false,'unknown-'..key end end
    candidate=normalize(candidate,id)
    if not M.appearanceReady and candidate.style~='native'and not M.plain(candidate)then
      return false,'art-under-revision'
    end
    -- Prepare before committing so a missing garment cannot persist a half
    -- applied selection. Native original deliberately needs no derived art.
    if M.assets and M.assets.prepare then
      local ok,err=M.assets.prepare(id,candidate,g)
      if not ok then return false,err end
    end
    local old=mod.save:get(KEY)
    if type(old)=='table'and old.version and old.version>1 then return false,'future-save'end
    local state=copy(type(old)=='table'and old or{})
    state.version=1;state.characters=type(state.characters)=='table'and state.characters or{}
    state.characters[id]=candidate
    local ok,result,err=pcall(mod.save.set,mod.save,KEY,state)
    if not ok or result==false then return false,tostring(err or result)end
    M.refresh(g)
    return true
  end
  function M.resolve(path,id,selection)
    if type(path)~='string'or not M.assets then return path end
    if not active or not M.appearanceReady then return path end
    -- User explicitly protects the small native/pixel sprites, including
    -- every original KASC back-throw frame. Native walking variants are
    -- separate sheets consumed only by wardrobe_walker2d; never replace sources.
    if path:find('/characters/crystal_chars/',1,true)or path:find('/runtime/',1,true)then return path end
    id=char(id);selection=selection or M.get(id)
    if M.plain(selection)then return path end
    local ok,result=pcall(M.assets.resolve,path,id,selection)
    if ok and type(result)=='string'then return result end
    M.errors[path]=tostring(result)
    return path
  end
  function M.resolveKnown(path)
    return path
  end
  function M.rows(id)
    local rows={{id='original',de='Original',en='Original'}}
    if M.appearanceReady then
      for _,entry in ipairs(C.characters[char(id)])do
        if entry.id~='original'and(not M.assets or not M.assets.available or M.assets.available(char(id),entry.id))then rows[#rows+1]=entry end
      end
    end
    return rows
  end
  function M.bind(g)game=g or game end
  if mod.events then
    for _,event in ipairs({'game.ready','save.loaded','save.created'})do
      mod.events:on(event,function(ev)game=ev and ev.game or game;M.revision=M.revision+1 end)
    end
  end
  return M
end
