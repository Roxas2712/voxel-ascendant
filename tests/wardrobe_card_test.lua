local root=assert(arg[1],'VASC source root required')
local calls,enabled=0,true
local api={schema='kasc.wardrobe/v1',setActive=function(v)enabled=v;calls=calls+1 end,
  resolve=function(p)return p..'.dressed'end,get=function()return{outfit='league'}end}
local V={mod={exports={},events={on=function()end},log={warn=function(_,...)error(table.concat({...},' '))end}}}
function V.mod:find(id)if id=='kanto_ascendant'then return{exports={wardrobe=api}}end end
local cache={}
function V.require(path)
  if cache[path]then return cache[path]end
  if path=='ModSetting'then return{new=function(_,_,_,_,default)
    return{value=default,get=function(self)return self.value end,
      onChange=function(self,fn)self.change=fn;return self end,
      setValue=function(self,value)self.value=value;self.change(nil,value)end}
  end}end
  local value=assert(loadfile(root..'/lib/'..path..'.lua'))(V);cache[path]=value;return value
end
local card=V.require('cards/wardrobe/Gen1WardrobeCard')
assert(card.boot())
local public=V.mod.exports.wardrobeCard
assert(public.id=='vasc.gen1.wardrobe')
assert(public.enabled()and enabled)
local h=public.health();assert(h.ok)
public.setting:setValue(false);assert(not enabled and not public.enabled())
public.setting:setValue(true);assert(enabled and public.enabled())
assert(public.health().ok)
assert(calls>=3)
print('WARDROBE CARD PASS: lifecycle, service boundary, disable/enable, health')
