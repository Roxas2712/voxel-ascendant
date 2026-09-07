-- Shared Gen-1/Gen-2 desktop/mobile presentation. The existing FIELD KIT
-- controller still owns rows, availability, A/B, SELECT favourites and saves.
local V = ...
local M = {}
local function isFieldKit(menu)
  if type(menu)~="table" or (menu.title~="FIELD KIT" and menu.title~="FELD-KIT")
      or type(menu.items)~="table" or #menu.items==0
      or type(menu.update)~="function" or type(menu.draw)~="function" then return false end
  for _,item in ipairs(menu.items) do
    if type(item)~="table" or type(item.toolId)~="string"
        or not (item.toolId:match("^FIELD:[A-Z_]+$") or item.toolId:match("^ITEM:[A-Z_]+$")) then return false end
  end
  return true
end
function M.decorate(menu,Style,mod)
  if not isFieldKit(menu) or menu.__vascFieldKitFullscreen then return false end
  if type(Style)~="table" or type(Style.new)~="function" then return false end
  local de=menu.title=="FELD-KIT"
  local original={}
  for k,v in pairs(menu) do original[k]=v end
  local ok,err=pcall(function()
    local ui=Style.new(mod,{skin=function()return "oras_fullscreen"end,
      language=function()return de and "de" or "en"end})
    ui.decorateFocusHelp(menu,function(item)
      local text=item and item.help
      if type(text)=="string" and text~="" then return text end
      return de and "A: Gewähltes Werkzeug nutzen.\nSELECT: Favorit festlegen.\nB: Zurück."
        or "A: Use the selected tool.\nSELECT: Set favourite.\nB: Back."
    end,8)
    menu.__vascFieldKitFullscreen=true
  end)
  if not ok then
    for k in pairs(menu) do if original[k]==nil then menu[k]=nil end end
    for k,v in pairs(original) do menu[k]=v end
    M.lastError=tostring(err)
    return false
  end
  return true
end
function M.install()
  if M.installed then return true end
  local mod=V and V.mod
  if not (mod and mod.events and type(mod.events.on)=="function") then return false end
  local Style=V.require("VascMenuStyle")
  mod.events:on("screen.pushed",function(event)
    M.decorate(type(event)=="table" and event.state,Style,mod)
  end,13000)
  M.installed=true
  return true
end
return M
