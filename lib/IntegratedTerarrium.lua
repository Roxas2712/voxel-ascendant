-- Terrarium is shipped and owned by VASC; no companion mod is required.
local V=...
local C={}
local settings,entries,proxy
local prefix="integrated/terarrium/"
-- Base labels are English; VascMenu localizes them from Universal's boot
-- language. The bundled upstream module's German labels are not a locale.
local settingLabels={behindRed='CAMERA BEHIND RED',idleAnimation='IDLE ANIMATION',
 idleSound='IDLE SOUND',ballStyle='BALL DESIGN',background='BACKGROUND',dome='GLASS DOME'}
local choices={
 background={auto='AUTO: BALL',night='NIGHT',forest='FOREST',stone='STONE',gallery='BRIGHT GALLERY'},
 dome={off='OFF',clear='CLEAR',blue='BLUE',rose='ROSE',gold='GOLD'},
 ballStyle={auto='AUTO: KASC',poke='POKE BALL',great='GREAT BALL',ultra='ULTRA BALL',master='MASTER BALL',safari='SAFARI BALL',
  apri_red='RED APRICORN',apri_blue='BLUE APRICORN',apri_yellow='YELLOW APRICORN',apri_green='GREEN APRICORN',
  apri_pink='PINK APRICORN',apri_black='BLACK APRICORN',apri_white='WHITE APRICORN'},
}
local help={
 behindRed="View both teams from behind the player's trainer, or from the side.",
 idleAnimation="Gently rock the Terrarium after a pause in the command menu.",
 idleSound="Play a quiet impact sound during the idle animation.",
 ballStyle="Choose the Terrarium shell. AUTO follows KASC difficulty when available.",
 background="Choose the setting around the Terrarium.",
 dome="Optional glass dome above the Terrarium.",
}
local function readModule(path)
 return assert((loadstring or load)(assert(V.mod:read(prefix..path)),"@"..prefix..path))()
end
local function facade()
 if proxy then return proxy end
 settings,entries={},{}
 proxy=setmetatable({path=V.mod.path.."/integrated/terarrium",exports={},events=V.mod.events,
  options={}}, {__index=V.mod})
 function proxy:read(path) return V.mod:read(prefix..path) end
 function proxy:find(id)
  if id=="VOXEL_ASCENDANT" then
   return {exports={terarrium=V.require("TerarriumHost").builtin()}}
  end
  return V.mod:find(id)
 end
 function proxy.options:define(definitions)
  local Setting=V.require("ModSetting")
  for _,d in ipairs(definitions) do
   local values,labels={},{}
   if d.type=="toggle" then values,labels={false,true},{"OFF","ON"}
   else for _,choice in ipairs(d.choices) do
    labels[#labels+1]=(choices[d.key]and choices[d.key][choice[2]])or choice[1];values[#values+1]=choice[2]
   end end
   local key="terarrium"..d.key:sub(1,1):upper()..d.key:sub(2)
   settings[d.key]=Setting.new(key,settingLabels[d.key]or d.label,values,labels,d.default)
   entries[#entries+1]={settings[d.key],help[d.key],full=true}
  end
 end
 function proxy.options:get(key) return settings[key] and settings[key]:get() end
 return proxy
end
function C.boot()
 if C.ready then return true end
 -- Upstream constructs only service tables here. Meshes, textures and audio
 -- are created lazily when this presentation is actually used.
 local mod=facade()
 readModule("main.lua")(mod)
 C.ready=true
 V.mod.exports.terarriumCard=mod.exports
 return true
end
function C.entries()
 C.boot()
 return entries
end
return C
