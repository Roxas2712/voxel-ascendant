local root=assert(arg[1])
local function read(path) local f=assert(io.open(root.."/"..path,"rb")); local s=f:read("*a"); f:close(); return s end
local Card=assert(loadfile(root.."/lib/OverworldPokemonCard.lua"))()
local Options=assert(loadfile(root.."/lib/OverworldPokemonOptions.lua"))()
package.loaded["src.core.GameVersion"]={generation=function() return 1 end}
local function fixture(fail)
  local values,events,hooks,saved,content={},{},{},{},{}
  local restored=0
  local mod={id="VOXEL_ASCENDANT",path=root,exports={},version="test",log={info=function() end,warn=function() end}}
  mod.options={get=function(_,k) return values[k] end}
  mod.save={get=function(_,k,d) if saved[k]==nil then return d end return saved[k] end,set=function(_,k,v) saved[k]=v end}
  local function subscribe(bucket,name,fn)
    bucket[name]=bucket[name] or {}; local row={fn=fn,active=true};table.insert(bucket[name],row)
    return function() row.active=false end
  end
  mod.events={on=function(_,n,fn) return subscribe(events,n,fn) end}
  mod.hooks={wrap=function(_,n,fn) return subscribe(hooks,n,fn) end}
  mod.content={sprites={get=function(_,id) return content[id] end,
    register=function(_,id,v) content[id]=v end,patch=function(_,id,v) content[id]=v end,
    override=function(_,id,v) content[id]=v end,remove=function(_,id) content[id]=nil end}}
  mod.find=function(_,id) if id=="external" then return {} end end
  function mod:read(path)
    if path=="integrated/ascendant_pokemon_overworld/main.lua" then
      return [[return function(child)
        assert(child:read("manifest.json"))
        assert(child.find("VOXEL_ASCENDANT").exports)
        assert(child.options:get("follower_sprite_source")=="hd")
        child.save:set("selected_slot",3)
        child._apoOwn({restore=function() child.log:info("restore") end})
        child.content.sprites:register("TEMP",{})
        child.hooks:wrap("example",function(nextFn,v) return nextFn(v)+1 end)
        child.events:on("mod.options_changed",function(p) child.exports.last=p end)
        child.exports.runtime={health=function() return {ok=true} end}
        ]]..(fail and "error('injected entry failure')" or "")..[[
      end]]
    end
    return read(path)
  end
  mod.log.info=function() restored=restored+1 end
  return mod,values,events,hooks,saved,content,function() return restored end
end
local mod,values,events,hooks,saved,content,restored=fixture(false)
local card=Card.new(mod)
assert(card:start())
assert(card:health().ok and card:health().state=="active")
assert(saved.apo_selected_slot==3 and saved.selected_slot==nil)
assert(hooks.example[1].fn(function(v) return v end,5)==6)
events["mod.options_changed"][1].fn({mod=mod.id,key="apo_follower_sprite_source",value="pokemmo"})
assert(card.child.exports.last.key=="follower_sprite_source" and card.child.exports.last.mod=="ascendant_pokemon_overworld")
assert(card:stop())
assert(not events["mod.options_changed"][1].active and not hooks.example[1].active)
assert(hooks.example[1].fn(function(v) return v end,5)==5,"revoked callback still active")
assert(content.TEMP==nil and restored()==1)
local broken,_,be,bh,_,bc,br=fixture(true)
local failed=Card.new(broken)
assert(not failed:start())
assert(failed:health().state=="failed" and not failed.active and bc.TEMP==nil and br()==1)
assert(not bh.example[1].active and not be["mod.options_changed"][1].active)
local disabled,dv=fixture(false);dv.apo_enabled=false
local disabledCard=Card.new(disabled)
assert(disabledCard:start() and disabledCard.state=="disabled" and not disabledCard.active)
assert(not disabled.exports.overworldPokemon)
dv.apo_hd_walking_sprites=true
assert(not disabledCard:health().restartRequired and not disabledCard.active,
  "HD toggle must not silently activate a disabled master")
dv.apo_enabled=true
assert(disabledCard:health().restartRequired and not disabledCard.active,
  "enabling the master must report the required reload")
local restarted=Card.new(disabled)
assert(restarted:start() and restarted.active and not restarted:health().restartRequired,
  "master ON plus reload must recover HD service")
assert(restarted:stop())
local duplicate=fixture(false)
duplicate.find=function(_,id) if id=="ascendant_pokemon_overworld" then return {exports={}} end end
local dupe=Card.new(duplicate);assert(not dupe:start() and dupe.state=="external_owner")
local schema=Options.schema(mod)
local sections={pokemon={keys={}},wilds={keys={}},weather={keys={}}};Options.addKeys(sections)
local keys={}
for _,spec in ipairs(schema) do
  assert(spec.key:sub(1,4)=="apo_" and not keys[spec.key]);keys[spec.key]=true
  assert(sections[Options.section(spec.key)].keys[spec.key])
  assert(not spec.label:find("BEGLEITER") and not spec.label:find("MENSCHEN"))
end
local upstream=assert(loadfile(root.."/integrated/ascendant_pokemon_overworld/options.lua"))()
for _,spec in ipairs(upstream) do assert(keys["apo_"..spec.key],"missing option "..spec.key) end
print("PASS APO Card: lifecycle, failure rollback, revocation, duplicate guard, namespaced options/save, complete menu mapping")
