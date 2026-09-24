-- Run from the mod root with ENGINE_DIR pointing to the host checkout.
local engine = assert(os.getenv("ENGINE_DIR"), "ENGINE_DIR required")
package.path = engine .. "/?.lua;" .. package.path
local drawn = {}
package.loaded["src.render.Font"] = {
  draw=function(s) drawn[#drawn+1] = s end,
  width=function(s) return #s*8 end,
  split=function(s) local t={} for i=1,#s do t[i]={from=i,to=i} end return t end,
  spansFitting=function(spans,budget) return math.min(#spans,math.floor(budget/8)) end,
}
package.loaded["src.render.Assets"] = {}
package.loaded["src.pokemon.Sprites"] = {}
package.loaded["src.core.Data"] = {}
love = { graphics=setmetatable({}, {__index=function() return function() end end}) }
-- Avoid shader/asset creation in this input and text-contract test.
love.graphics.newShader = false
local Input = require("src.core.Input")
Input:init()
local checks = 0
local function eq(a,b,label)
  checks=checks+1
  assert(a==b, label .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
local function newController(path, surface)
  local provider = assert(loadfile(path))({ require=function(name)
    if name=="ModSetting" then return {new=function(_,_,_,_,default)
      return {get=function() return default end} end} end
    return {}
  end })
  local zone = surface=="legacy_bank" and "legacy" or "box"
  local model = {
    surface=surface, locale="en", edition="yellow", revision=1,
    focus={zone=zone,box=1,slot=3}, zones={[zone]={capacity=20,entries={}},
      party={capacity=6,entries={}}}, selection={ids={"kept"},revision=1},
    surfaceData={currentBox=1,boxCount=500,selectedCount=1},
    availability={navigate={enabled=true},cross_box_select={enabled=true},
      change_box={enabled=true},cancel={enabled=true}},
  }
  local calls={}
  local c=setmetatable({model=model,ctx={dispatch=function(action,payload)
    calls[#calls+1]={action=action,payload=payload}
    if action=="cross_box_select" or action=="change_box" then
      eq(payload.modelRevision,model.revision,"paging carries current revision")
      model.surfaceData.currentBox=payload.boxIndex
      model.focus.box=payload.boxIndex
      model.revision=model.revision+1
    end
    return {status="applied",model=model}
  end}},provider.Controller)
  return c,calls
end
local function press(c,source,key)
  Input:reset()
  if source=="touch" then Input:overlayPressed(key)
  else Input:gamepadpressed(nil, "dp"..key) end
  Input:step()
  local pressed={}
  for _,k in ipairs({"up","down","left","right"}) do
    if Input:wasPressed(k) then pressed[k]=true end
  end
  c:handleInput({pressed=pressed})
  if source=="touch" then Input:overlayReleased(key)
  else Input:gamepadreleased(nil,"dp"..key) end
end
for _,path in ipairs({"lib/AscBoxProvider.lua","lib/gen2_a21_shared/AscBoxProvider.lua"}) do
  for _,source in ipairs({"touch","controller"}) do
    local c,calls=newController(path,"legacy_bank")
    press(c,source,"up")
    eq(c.boxHeaderFocus,true,path.." "..source.." UP reaches header")
    eq(#calls,0,"header focus never moves Pokemon cursor")
    press(c,source,"right")
    eq(c.model.surfaceData.currentBox,2,"RIGHT pages forward")
    eq(calls[#calls].action,"cross_box_select","Legacy uses its own host action")
    eq(c.model.focus.slot,3,"column is preserved")
    eq(c.model.selection.ids[1],"kept","selection is preserved")
    c:onEvent(nil,{model=c.model})
    eq(c.boxHeaderFocus,true,"model refresh retains valid header focus")
    press(c,source,"left"); press(c,source,"left")
    eq(c.model.surfaceData.currentBox,500,"first box wraps to last")
    press(c,source,"right")
    eq(c.model.surfaceData.currentBox,1,"last box wraps to first")
    drawn={}; c:draw()
    eq(table.concat(drawn,"|"):find("LEGACY BOX 1",1,true)~=nil,true,"numbered header is drawn")
    eq(table.concat(drawn,"|"):find("LEFT/RIGHT:BOX",1,true)~=nil,true,"header help is drawn")
    press(c,source,"down")
    eq(c.boxHeaderFocus,false,"DOWN returns to grid")
    eq(c.model.focus.slot,3,"grid returns to remembered column")
    c.model.focus.slot=8
    press(c,source,"up")
    eq(calls[#calls].action,"navigate","lower row uses normal navigation")
    c.model.focus.slot=1
    press(c,source,"up")
    local n=#calls
    c:handleInput({pressed={select=true}})
    c:handleInput({pressed={start=true}})
    eq(#calls,n,"header does not mark or transfer a hidden slot")
    c:handleInput({pressed={b=true}})
    eq(c.boxHeaderFocus,false,"B returns to grid without closing")
    eq(#calls,n,"B on header does not close bank")
    c.carry={id="held",zone="legacy",box=1,slot=1}
    press(c,source,"up"); press(c,source,"right"); press(c,source,"down")
    eq(c.carry.id,"held","cross-box carry survives header navigation")
    c.carry=nil; press(c,source,"up")
    c.model.focus.zone="party"; c:onEvent(nil,{model=c.model})
    eq(c.boxHeaderFocus,false,"party focus clears header")
  end
  local c,calls=newController(path,"pc_box")
  press(c,"controller","up"); press(c,"controller","right")
  eq(calls[#calls].action,"change_box","normal PC keeps existing action")
  local c,calls=newController(path,"legacy_bank")
  c.model.availability.cross_box_select.enabled=false
  press(c,"touch","up"); press(c,"touch","right")
  eq(c.model.surfaceData.currentBox,1,"disabled paging cannot change box")
end
print("Legacy Bank header: "..checks.." assertions passed (controller + touch, Gen 1 + Gen 2)")
