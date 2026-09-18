-- The native Mod Manager is another writer of Ascendant's sprite options.
-- Intercept before persistence/events; rejected choices retain the old value.
local M={}
function M.install(modId)
 local ok,Manager=pcall(require,'src.mods.ManagerState')
 if not ok or type(Manager)~='table' or type(Manager.setOption)~='function'then return false end
 local state=Manager._ascendantSpriteSettingGuard
 if not state then
  state={owners={}};Manager._ascendantSpriteSettingGuard=state
  local original=Manager.setOption
  function Manager:setOption(id,key,value,...)
   local game=self.game;local mods=game and game.mods
   local exports=mods and (mods.exports or mods.loader and mods.loader.exports)
   local owner=exports and exports[id]
   local content=state.owners[id] and owner and owner.ascendantContent
   if content and type(content.allowSetting)=='function'then
    local function get(name)
     local saved=game.save and game.save.options and game.save.options.modOptions
     local bucket=saved and saved[id]
     if bucket and bucket[name]~=nil then return bucket[name]end
     local loader=mods.loader or mods
     bucket=loader.modOptions and loader.modOptions[id]
     if bucket and bucket[name]~=nil then return bucket[name]end
     for _,row in ipairs(loader.optionSchemas and loader.optionSchemas[id] or {})do
      if row.key==name then return row.default end
     end
    end
    if not content:allowSetting(key,value,game,get)then return false end
   end
   return original(self,id,key,value,...)
  end
 end
 state.owners[modId]=true
 return true
end
return M
