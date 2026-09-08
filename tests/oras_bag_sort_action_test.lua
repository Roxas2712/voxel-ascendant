-- Manual ORAS Bag sort contract: never automatic, pocket-local and reversible.

local root = arg and arg[1] or "."

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected)
      .. ", got " .. tostring(actual), 2)
  end
end

local function check(value, message)
  if not value then error(message or "check failed", 2) end
end

local oldPreload = package.preload["src.inventory.Bag"]
local oldLoaded = package.loaded["src.inventory.Bag"]
package.loaded["src.inventory.Bag"] = nil
package.preload["src.inventory.Bag"] = function()
  return { order = function(save) return save.bagOrder end }
end

local oldLove = rawget(_G, "love")
local labels = {}
_G.love = { graphics = {
  setColor = function() end,
  rectangle = function() end,
  getLineWidth = function() return 1 end,
  setLineWidth = function() end,
} }
local Font = {
  width = function(text) return #text * 4 end,
  draw = function(text) labels[#labels + 1] = text end,
}

local Sort = assert(loadfile(root .. "/lib/ManualBagSort.lua"))({})
eq(Sort.LABEL, "SORT", "untranslated sessions default to English")
local boot
local localized=assert(loadfile(root .. "/lib/ManualBagSort.lua"))({mod={find=function()
  return boot and {exports={bootLanguage=boot}} or nil
end}})
eq(localized.labels().LABEL,'SORT','absent Universal mod')
boot='de';eq(localized.labels().LABEL,'SORTIEREN','Universal German')
boot='en';eq(localized.labels().LABEL,'SORT','Universal English boot')
eq(Sort.schema, "voxel-ascendant/manual-oras-bag-sort/v2", "schema")

local globalOrder = { "potion", "poke_ball", "antidote", "great_ball", "ether" }
local pocket = { potion=true, antidote=true, ether=true }
local nativeUpdates, nativeChoices, nativeCancels, nativeSelects = 0, 0, 0, 0
local nativePocketMoves, projects, nativeDraws = 0, 0, 0
local pressedKey
local list = {
  __vascOrasBagPresentation = true,
  __pocketIds = { "potion", "antidote", "ether" },
  __pocketIndex = 1,
  index = 1,
  scroll = 0,
  rows = 2,
  game = {
    save = { inventory = {}, bagOrder = globalOrder },
    data = { items = {
      potion = { name="Potion" },
      antidote = { name="Antidote" },
      ether = { name="Ether" },
    } },
    input = { wasPressed = function(_, key) return key == pressedKey end },
  },
}
local function project()
  projects = projects + 1
  list.items = {}
  for _, id in ipairs(globalOrder) do
    if pocket[id] then list.items[#list.items + 1] = { value=id, label=id } end
  end
end
project()
projects = 0
list.__project = project
list.update = function(self)
  nativeUpdates = nativeUpdates + 1
  if self.game.input:wasPressed("down") and self.index < #self.items then
    self.index = self.index + 1
  elseif self.game.input:wasPressed("up") and self.index > 1 then
    self.index = self.index - 1
  elseif self.game.input:wasPressed("right") then
    self.__pocketIndex = self.__pocketIndex + 1
    nativePocketMoves = nativePocketMoves + 1
  elseif self.game.input:wasPressed("b") then
    nativeCancels = nativeCancels + 1
  elseif self.game.input:wasPressed("select") then
    self.swapIndex = self.index
    nativeSelects = nativeSelects + 1
  elseif self.game.input:wasPressed("a") then
    nativeChoices = nativeChoices + 1
  end
  return "native-update"
end
list.draw = function(_, marker) nativeDraws = nativeDraws + 1; return "native", marker end
list.drawWidescreen = function(_, marker)
  nativeDraws = nativeDraws + 1
  return "wide", marker
end

local decorated, changed = Sort.decorate(list, { Font=Font })
eq(decorated, list, "decorated list identity")
eq(changed, true, "ORAS list decorated")
eq(table.concat(globalOrder, ","),
  "potion,poke_ball,antidote,great_ball,ether", "decorate sorted automatically")
eq(projects, 0, "decorate projected automatically")

local drawA, drawB = list:draw("draw-token")
eq(drawA, "native", "native draw return one")
eq(drawB, "draw-token", "native draw return two")
eq(nativeDraws, 1, "native draw call count")
eq(labels[#labels], "START:SORT", "manual START action was not drawn")
eq(table.concat(globalOrder, ","),
  "potion,poke_ball,antidote,great_ball,ether", "draw sorted automatically")

list.__vascOrasBagWidePresentation = true
local wideA, wideB = list:drawWidescreen("mobile-wide-token")
eq(wideA, "wide", "mobile wide draw return one")
eq(wideB, "mobile-wide-token", "mobile wide draw return two")
eq(labels[#labels], "START: SORT",
  "mobile wide path bypassed the visible sort button")
list.__vascOrasBagWidePresentation = nil

eq(list:update(), "native-update", "unfocused update ownership")
eq(nativeUpdates, 1, "native update count")
eq(table.concat(globalOrder, ","),
  "potion,poke_ball,antidote,great_ball,ether", "update sorted automatically")

-- D-pad/keyboard/controller all arrive as the same engine action edges.  The
-- item list is cyclic and never uses its lower boundary to focus the action.
pressedKey = "down"
eq(list:update(), "native-update", "ordinary row DOWN ownership")
eq(list.index, 2, "ordinary row DOWN did not navigate")
eq(list.__vascManualBagSortFocused, false, "button focused before final row")
list.index = #list.items
eq(list:update(), nil, "final row DOWN wrap should be consumed")
eq(list.index, 1, "final row did not wrap to first item")
eq(list.scroll, 0, "DOWN wrap did not reset scroll")
eq(nativeUpdates, 2, "DOWN boundary leaked into provider")
pressedKey = "up"
eq(list:update(), nil, "first row UP wrap should be consumed")
eq(list.index, #list.items, "first row did not wrap to final item")
eq(list.scroll, 1, "UP wrap did not expose final row")
eq(nativeUpdates, 2, "UP boundary leaked into provider")

-- LEFT/RIGHT always remain the provider's pocket navigation. START alone
-- invokes the header action and preserves the selected item.
local selectedBeforeSort = list.items[list.index].value
pressedKey = "right"
eq(list:update(), "native-update", "RIGHT pocket navigation ownership")
eq(nativeUpdates, 3, "RIGHT did not reach pocket navigation")
eq(nativePocketMoves, 1, "RIGHT did not change pocket")
eq(list.__vascManualBagSortFocused, false, "RIGHT focused sort action")
eq(table.concat(globalOrder, ","),
  "potion,poke_ball,antidote,great_ball,ether", "RIGHT sorted automatically")

pressedKey = "start"
local sorted, reason = list:update()
eq(sorted, true, "START did not sort")
eq(reason, "sorted", "START sort reason")
eq(nativeUpdates, 3, "sort leaked START into native row action")
eq(nativeChoices, 0, "START chose the underlying item")
eq(table.concat(globalOrder, ","),
  "antidote,poke_ball,ether,great_ball,potion", "current pocket order")
eq(globalOrder[2], "poke_ball", "other pocket position two changed")
eq(globalOrder[4], "great_ball", "other pocket position four changed")
eq(list.items[list.index].value, selectedBeforeSort,
  "selected item was not preserved")
eq(projects, 1, "sorted pocket was not projected exactly once")
eq(list.__vascManualBagSortCount, 1, "manual sort count")
eq(list.__vascManualBagSortMode, "alphabetical", "first mode")
list.__vascOrasBagWidePresentation = true
list:draw()
eq(labels[#labels], "START: A-Z", "active sort mode was not shown")
list.__vascOrasBagWidePresentation = nil

-- Repeated START presses cycle independently for this pocket. Relevance puts
-- restorative items first; strength uses the data-owned price/rank fallback.
pressedKey = "start"
eq(select(1, list:update()), true, "second START did not sort")
eq(list.__vascManualBagSortMode, "relevance", "second mode")
pressedKey = "start"
eq(select(1, list:update()), true, "third START did not sort")
eq(list.__vascManualBagSortMode, "strength", "third mode")
pressedKey = "start"
eq(select(1, list:update()), true, "fourth START did not sort")
eq(list.__vascManualBagSortMode, "alphabetical", "mode did not wrap")
eq(list.__vascManualBagSortCount, 4, "cyclic sort count")

local rankedBalls = Sort.sortIds({
  "MASTER_BALL", "ULTRA_BALL", "GREAT_BALL", "LOVE_BALL", "POKE_BALL",
}, list.game, "strength")
eq(table.concat(rankedBalls, ","),
  "POKE_BALL,GREAT_BALL,LOVE_BALL,ULTRA_BALL,MASTER_BALL",
  "ball strength order")

-- A remains the native item action.
local retainedIndex = list.index
pressedKey = "a"
eq(list:update(), "native-update", "unfocused A ownership")
eq(nativeChoices, 1, "unfocused A did not choose the native item")
eq(list.__vascManualBagSortCount, 4, "native item A sorted the pocket")
eq(list.index, retainedIndex, "native A moved the retained item selection")

-- SELECT starts the provider-owned move; that pending move then keeps DOWN
-- even at the final row, and START cannot sort across that transaction.
list.index = #list.items
pressedKey = "select"
eq(list:update(), "native-update", "SELECT ownership")
eq(nativeSelects, 1, "SELECT did not reach provider")
eq(list.swapIndex, list.index, "provider SELECT move did not start")
eq(list.__vascManualBagSortCount, 4, "SELECT sorted the pocket")
pressedKey = "start"
eq(list:update(), "native-update", "START interrupted SELECT move")
eq(list.__vascManualBagSortCount, 4, "START sorted during SELECT move")
pressedKey = "down"
eq(list:update(), "native-update", "SELECT-swap DOWN ownership")
eq(list.__vascManualBagSortFocused, false, "SELECT swap leaked to button focus")
list.swapIndex = nil

-- A further RIGHT delegates once and never sorts.
pressedKey = "right"
local beforePocketNavigation = list.__vascManualBagSortCount
eq(list:update(), "native-update", "pocket navigation ownership")
eq(list.__vascManualBagSortFocused, false,
  "pocket navigation retained button focus")
eq(nativePocketMoves, 2, "pocket navigation did not reach provider")
eq(list.__pocketIndex, 3, "provider pocket navigation did not run")
eq(list.__vascManualBagSortCount, beforePocketNavigation,
  "pocket navigation sorted automatically")

-- Pocket changes remain provider-owned and do not trigger another sort.
pressedKey = nil
eq(list:update(), "native-update", "pocket update ownership")
eq(list.__vascManualBagSortCount, 4, "pocket change triggered sorting")

-- Cancel remains delegated to the native/provider seam.
pressedKey = "b"
eq(list:update(), "native-update", "cancel ownership")
eq(nativeCancels, 1, "cancel did not reach provider")
eq(list.__vascManualBagSortFocused, false, "cancel retained button focus")
eq(list.__vascManualBagSortCount, 4, "cancel sorted the pocket")
pressedKey = nil

local wrappedPointer
local pointerRemoved = false
local mod = { hooks = { wrap = function(_, name, callback, priority)
  eq(name, "input.pointer", "pointer hook name")
  eq(priority, 850, "pointer hook priority")
  wrappedPointer = callback
  return function() pointerRemoved = true end
end } }
local installed = Sort.installPointer(mod, {
  pointerToLogical = function(_, x, y) return x, y end,
})
eq(installed, true, "pointer hook installation")
list.game.stack = { top = function() return list end }
local beforePointer = list.__vascManualBagSortCount
local consumed = wrappedPointer(function() return false end, list.game, {
  insideGame=true, source="mouse", button=1, phase="pressed", gameX=112, gameY=7,
})
eq(consumed, true, "button pointer press not consumed")
eq(list.__vascManualBagSortCount, beforePointer + 1, "pointer did not sort once")
wrappedPointer(function() return false end, list.game, {
  insideGame=true, source="mouse", button=1, phase="pressed", gameX=4, gameY=4,
})
eq(list.__vascManualBagSortCount, beforePointer + 1, "outside pointer sorted")
eq(Sort.health().state, "active", "sort segment health")

local wide = { __vascOrasBagWidePresentation=true }
local x, y, width, height = Sort.buttonRect(wide)
eq(x, 276, "wide button x")
eq(y, 17, "wide button y")
eq(width, 156, "wide button width")
eq(height, 18, "wide button height")
check(Font.width(Sort.INPUT_LABEL) <= width - 12,
  "wide START sort label has no horizontal gutter")

local compactX, compactY, compactWidth, compactHeight = Sort.buttonRect({})
eq(compactX, 76, "compact button x")
eq(compactY, 3, "compact button y")
eq(compactWidth, 68, "compact button width")
eq(compactHeight, 12, "compact button height")
check(Font.width("START:SORT") <= compactWidth - 8,
  "compact START sort label has no horizontal gutter")

local rejected = { draw=function() end }
local _, rejectedChange, rejectedReason = Sort.decorate(rejected, { Font=Font })
eq(rejectedChange, false, "non-VASC Bag decorated")
eq(rejectedReason, "not-vasc-oras-bag", "non-VASC reason")

local rollbackOrder = { "potion", "antidote" }
local rollback = {
  __vascOrasBagPresentation=true,
  __pocketIds={ "potion", "antidote" },
  items={ { value="potion" }, { value="antidote" } },
  index=1, rows=2, draw=function() end,
  game={ save={ inventory={}, bagOrder=rollbackOrder }, data=list.game.data },
  __project=function() error("projection failed") end,
}
Sort.decorate(rollback, { Font=Font })
local rollbackOK, rollbackReason = Sort.sortCurrentPocket(rollback)
eq(rollbackOK, false, "failed projection reported success")
eq(rollbackReason, "project-failed", "failed projection reason")
eq(table.concat(rollbackOrder, ","), "potion,antidote", "order rollback")

-- Native BagMenu ends with CANCEL rather than a provider __project callback.
-- Sort all three modes repeatedly without treating that row as an item id.
for _,wideFlag in ipairs({'__vascOrasBagWidePresentation','__vascOrasFrlgBagWidePresentation'}) do
 for _,count in ipairs({0,1,3}) do
  local order={};local items={};local ids={'potion','antidote','ether'}
  local inventory={}
  for n=1,count do order[n]=ids[n];items[n]={value=ids[n],count=n};inventory[ids[n]]=n end
  local cancel={cancel=true,label='CANCEL'};items[#items+1]=cancel
  local raw={__vascOrasBagPresentation=true,items=items,index=#items,rows=8,
    game={save={inventory=inventory,bagOrder=order},data=list.game.data,
      input={wasPressed=function(_,key)return key=='start' end}},
    draw=function()end,update=function()error('START leaked to native bag')end}
  raw[wideFlag]=true;Sort.decorate(raw,{Font=Font})
  for n=1,6 do
   check(raw:update(),'native START failed')
   eq(#raw.items,count+1,'CANCEL was dropped')
   eq(raw.items[#raw.items],cancel,'CANCEL identity/callback lost')
   eq(raw.items[raw.index],cancel,'selected CANCEL moved')
   for id,qty in pairs(inventory)do eq(qty,({potion=1,antidote=2,ether=3})[id],'quantity changed')end
  end
  if count>1 then
   raw.index=1;local chosen=raw.items[1];raw:update()
   eq(raw.items[raw.index],chosen,'selected native item moved to another item')
  end
 end
end

eq(Sort.deactivate(), true, "sort segment deactivation")
eq(pointerRemoved, true, "sort pointer hook was not removed")
eq(Sort.health().state, "inactive", "sort segment remained active")

_G.love = oldLove
package.preload["src.inventory.Bag"] = oldPreload
package.loaded["src.inventory.Bag"] = oldLoaded

print("oras_bag_sort_action_test: ok")
