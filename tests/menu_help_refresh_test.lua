for _,path in ipairs({'lib/VascMenu.lua','lib/gen2_a21_shared/VascMenu.lua'})do
 local f=assert(io.open(path));local source=f:read('*a');f:close()
 local code=assert(source:match('(local function refreshConditionalRows.-\nend)')):gsub('local function','function',1)
 local env=setmetatable({sectionRows=function()return{{label='Setting',settingKey='x'}}end,clampNavigation=function()end},{__index=_G})
 setfenv(assert(loadstring(code)),env)()
 for _,value in ipairs({'__vasc_help','__kasc_help','__kasc_help:vasc_settings_world'})do
  local help={label='HELP',value=value};local menu={index=2,items={{label='Setting'},help}}
  assert(env.refreshConditionalRows({},menu,{},{}));assert(menu.items[2]==help,'refresh removed contextual HELP: '..path..' '..value)
 end
end
print('PASS both menu controllers preserve native and namespaced HELP rows on conditional refresh')
