-- Present both support senders through VASC's existing menu skin. Keep their
-- code validation, confirmation, polling and transport callbacks unchanged.
local M={}
function M.decorate(menu, ui, de)
  if type(menu)~='table' or type(menu.items)~='table' or menu.__vascSupportMenu then return menu end
  local digits,actions={},{}
  for _,row in ipairs(menu.items)do
    if row.digit then digits[row.digit]=row else actions[#actions+1]=row end
  end
  for i=1,8 do if not digits[i] then return menu end end
  local choose=menu.onChoose or (menu.opts and menu.opts.onChoose)
  if type(choose)~='function' then return menu end
  local position=1
  local help=de and 'A erhöht die gewählte Ziffer. LINKS/RECHTS wählt eine der acht Stellen. Danach SUPPORT-LOG SENDEN wählen und bestätigen.'
    or 'A increases the selected digit. LEFT/RIGHT selects one of the eight positions. Then select SEND SUPPORT LOG and confirm.'
  local codeRow={label=de and 'SUPPORT-CODE' or 'SUPPORT CODE',action='supportCode',right='????????',help=help}
  local positionRow={label=de and 'STELLE' or 'DIGIT POSITION',action='supportPosition',right='1 / 8',help=help}
  local function refresh()
    local value={}
    for i=1,8 do value[i]=tostring(digits[i].right or '?'):sub(1,1) end
    codeRow.right=table.concat(value)
    positionRow.right=tostring(position)..' / 8'
  end
  local function selectPosition(step)
    position=((position-1+step)%8)+1;refresh()
  end
  menu.items={codeRow,positionRow}
  for _,row in ipairs(actions)do menu.items[#menu.items+1]=row end
  menu.index=1;menu.scroll=0;menu.pageJump=false
  menu.footer=de and 'A:WAHL L/R:STELLE B:ZURÜCK' or 'A:SELECT L/R:DIGIT B:BACK'
  menu.onChoose=function(item,active)
    if item==codeRow then choose(digits[position],active or menu);refresh()
    elseif item==positionRow then selectPosition(1)
    else return choose(item,active or menu) end
  end
  if menu.opts then menu.opts.onChoose=menu.onChoose end
  if ui and type(ui.showHelp)=='function' then
    menu.onSelectKey=function(item) return ui.showHelp(menu.game,item.label,item.help or help) end
  end
  local base=menu.update
  function menu:update(...)
    local input=self.game and self.game.input
    local item=self.items[self.index]
    if input and type(input.wasPressed)=='function' and (item==codeRow or item==positionRow) then
      if input:wasPressed('left') then selectPosition(-1)
      elseif input:wasPressed('right') then selectPosition(1) end
    end
    if base then base(self,...) end
    refresh()
  end
  refresh()
  menu.__vascSupportMenu=true
  if ui and type(ui.decorateFocusHelp)=='function' then
    return ui.decorateFocusHelp(menu,function(item)return item and item.help or help end,8)
  end
  return menu
end
return M
