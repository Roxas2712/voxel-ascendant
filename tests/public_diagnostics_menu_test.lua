-- Complete standalone and public-KASC VASC control-centre contract.
assert(loadfile("main.lua"))

-- VascMenuStyle is a LÖVE renderer. The contract runs under plain LuaJIT, so
-- provide only the inert drawing surface needed to exercise layout, labels
-- and focus-help ownership without turning this into a screenshot test.
love = love or {}
love.graphics = love.graphics or {}
love.graphics.setColor = love.graphics.setColor or function() end
love.graphics.rectangle = love.graphics.rectangle or function() end
love.graphics.setScissor = love.graphics.setScissor or function() end

local function eq(actual, expected, message)
  assert(actual == expected, (message or "values differ")
    .. (" (expected %s, got %s)"):format(tostring(expected), tostring(actual)))
end

local function graphFingerprint(value, seen)
  local kind = type(value)
  if kind ~= "table" then return kind .. ":" .. tostring(value) end
  seen = seen or {}
  if seen[value] then return "ref:" .. tostring(seen[value]) end
  local id = (seen.__count or 0) + 1
  seen.__count = id
  seen[value] = id
  local parts = {}
  for key, item in pairs(value) do
    parts[#parts + 1] = graphFingerprint(key, seen)
      .. "=" .. graphFingerprint(item, seen)
  end
  table.sort(parts)
  return "table{" .. table.concat(parts, ",") .. "}"
end

local function setting(key, label, values, onValue)
  local current = 1
  local object = { key=key, label=label }
  function object:get() return values[current] end
  function object:setValue(value)
    for index, candidate in ipairs(values) do
      if candidate == value then
        current = index
        if onValue then onValue(values[current]) end
        return true
      end
    end
    return false
  end
  function object:row()
    return {
      id="VOXEL_ASCENDANT:" .. key,
      label=label,
      value=function() return values[current] end,
      step=function(_, direction)
        current = ((current + (direction or 1) - 1) % #values) + 1
        if onValue then onValue(values[current]) end
        return true
      end,
    }
  end
  return object
end

local function fixture(ascendantUi)
  local pushes, registered = {}, {}
  local mod = {
    id="VOXEL_ASCENDANT",
    content={screens={register=function(_, name, def) registered[name] = def end}},
    find=function(id)
      if ascendantUi and id == "kanto_ascendant" then
        return { exports={ ascendantUi=ascendantUi } }
      end
    end,
    ui={
      push=function(game, screen, opts)
        pushes[#pushes + 1] = {game=game, screen=screen, opts=opts}
      end,
      ListMenu={new=function(game, title, items, opts)
        opts = opts or {}
        local menu = {
          game=game, title=title, items=items, index=1, opts=opts,
          isOpaque=true, onSelectKey=opts.onSelectKey,
        }
        function menu:update() self.baseUpdates = (self.baseUpdates or 0) + 1 end
        function menu:choose(index)
          self.index = index or self.index
          return self.opts.onChoose(self.items[self.index], self)
        end
        function menu:close() self.closed = true end
        return menu
      end},
    },
  }
  return mod, registered, pushes
end


for _,path in ipairs({'lib/VascMenu.lua','lib/gen2_a21_shared/VascMenu.lua'}) do
  local style=assert(loadfile('lib/VascMenuStyle.lua'))()
  local menuModule=assert(loadfile(path))({require=function(name) if name=='VascMenuStyle' then return style end;error(name)end})
  local mod,screens,pushes=fixture()
  local sent=false
  local diagnostics={CODE='2712',FILE='log',enabled=function()return false end,
    setEnabled=function()error('diagnosis must not enable QA bypasses')end,write=function()end,
    openSupportSend=function()sent=true;return true end}
  assert(menuModule.install(mod,{settings={},diagnostics=diagnostics,performanceDiagnostics={rows=function()return {{label='FPS',right='60'}}end}}))
  local game={stack={top=function()end,push=function()end},input={wasPressed=function()return false end}}
  local root=screens.VascMenu.new(game)
  assert(root.items[1].section=='world',path..' world must stay first')
  local diagnosticIndex,lastSection
  for i,row in ipairs(root.items)do
    if row.section then lastSection=i end
    if row.screen=='VascDiagnostics' then diagnosticIndex=i end
  end
  assert(diagnosticIndex==lastSection+1,'diagnosis must follow the settings sections')
  root:choose(diagnosticIndex);assert(pushes[#pushes].screen=='VascDiagnostics')
  local page=screens.VascDiagnostics.new(game)
  for _,row in ipairs(page.items)do assert(not row.digit and row.action~='diagnosticsApply')end
  page:choose(1);assert(sent,'send must open without KASC and without 2712')
  for i,row in ipairs(page.items)do if row.action=='performanceDiagnostics' then page:choose(i)end end
  assert(pushes[#pushes].screen=='VascPerformanceDiagnostics')
  local kascSent=false
  mod.find=function(_,id)
    if id=='kanto_ascendant' then return {exports={supportSessionLog={openSupportSend=function()kascSent=true;return true end}}} end
  end
  local withKasc=screens.VascDiagnostics.new(game)
  local kascIndex
  for i,row in ipairs(withKasc.items)do if row.action=='sendKascSupport' then kascIndex=i end end
  assert(kascIndex,'KASC log missing from relocated diagnostics')
  withKasc:choose(kascIndex);assert(kascSent,'KASC sender was not called')
  local performance=screens.VascPerformanceDiagnostics.new(game)
  assert(performance.items[1].label=='FPS','monitor still locked')
end
print('Gen1 + Gen2: diagnosis after settings, no unlock, support without KASC, no QA mutation: OK')
