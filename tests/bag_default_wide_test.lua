local configured
local V={mod={id='VOXEL_ASCENDANT',options={get=function(_,key)if key=='qol_bag_skin' then return configured end end}}}
V.require=function(name)
 if name=='ModSetting' then return assert(loadfile('lib/ModSetting.lua'))(V) end
 return {}
end
local settings=assert(loadfile('lib/OrasBattleHudSettings.lua'))(V)
assert(settings.bagSkinSetting.values[settings.bagSkinSetting.defaultIndex]=='oras_wide','fresh Bag setting must default to widescreen')
local skin=assert(loadfile('lib/OrasUiSkin.lua'))(V)
assert(skin.install({mod=V.mod,bagSkin={}}))
local c=skin.controller
assert(c.bagStyle({})=='oras_wide','missing setting must resolve to widescreen')
for value,expected in pairs({external='external',oras_wide='oras_wide',frlg_wide='frlg_wide',oras='oras_wide',frlg='frlg_wide',unknown='external'})do
 configured=value
 assert(c.bagStyle({})==expected,'configured Bag choice changed: '..value)
end
configured='oras_wide'
assert(c.bagStyle({save={options={modOptions={VOXEL_ASCENDANT={qol_bag_skin='external'}}}}})=='external','explicit saved GAME/KASC choice must win')
print('bag widescreen default and explicit choices: ok')
