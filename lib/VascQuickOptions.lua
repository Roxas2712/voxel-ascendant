-- Live option descriptors, with explicit owners. No parallel preference store.
local V=...
local M={}
local function owner(id)
 local ok,m=pcall(V.mod.find,id)
 return ok and m or nil
end
local function option(g,id,key,en,de,group)
 if not owner(id) then return end
 local loader=g.mods
 local schema=loader and loader.optionSchemas and loader.optionSchemas[id]
 local spec
 for _,s in ipairs(schema or {})do if s.key==key then spec=s;break end end
 if not spec or(spec.type~='toggle'and spec.type~='choice')then return end
 local function value()
  local opts=loader.modOptions and loader.modOptions[id]
  local val=opts and opts[key];if val==nil then val=spec.default end
  return val
 end
 return {id=id..':'..key,title=en,titleDe=de,group=group,hint='',detail='',
  status=function(deutsch)
   local val=value()
   if spec.type=='toggle'then return val and(deutsch and 'AN'or'ON')or(deutsch and'AUS'or'OFF')end
   for _,c in ipairs(spec.choices or{})do if c[2]==val then return c[1]end end
   return tostring(val)
  end,
  change=function(game,delta)
   local val=value()
   if spec.type=='toggle'then val=not val else
    local choices=spec.choices or{};if #choices==0 then return false end
    local at=0;for i,c in ipairs(choices)do if c[2]==val then at=i;break end end
    val=choices[(at-1+(delta or 1))%#choices+1][2]
   end
   local options=game.save and game.save.options
   if not options or not loader.events then return false end
   options.modOptions=options.modOptions or{};options.modOptions[id]=options.modOptions[id]or{}
   loader.modOptions=loader.modOptions or{};loader.modOptions[id]=loader.modOptions[id]or{}
   options.modOptions[id][key]=val;loader.modOptions[id][key]=val
   loader.events:emit('mod.options_changed',{mod=id,key=key,value=val})
   -- Save after the owner has normalized its save-local follower settings.
   if game.writeOptions then game:writeOptions()end
   return true
  end}
end
local wilds={
 {'living_world_enabled','enabled','Visible wild Pokémon','Sichtbare wilde Pokémon'},
 {'living_world_density','spawn_density','Wild population','Wild-Pokémon: Menge'},
 {'living_world_random_encounters','random_encounters','Random encounters','Zufallskämpfe'},
 {'living_world_water','water_spawns','Water Pokémon','Wasser-Pokémon'},
 {'living_world_caves','cave_spawns','Cave spawns','Höhlen-Pokémon'},
 {'living_world_grass','pokemon_grass_render_mode','Grass visibility','Sichtbarkeit im Gras'},
 {'living_world_silhouettes','wild_silhouettes','Silhouettes','Silhouetten'},
 {'living_world_idle','enable_idle','Idle Pokémon','Ruhende Pokémon'},
 {'living_world_wander','enable_wander','Wandering Pokémon','Wandernde Pokémon'},
 {'living_world_chase','enable_aggressive','Chasing Pokémon','Verfolgende Pokémon'},
 {'living_world_hidden','enable_hidden','Hidden Pokémon','Versteckte Pokémon'},
}
function M.rows(g,settings)
 local rows={};local function add(r)if r then rows[#rows+1]=r end end
 local kasc=owner('kanto_ascendant')
 local external=owner('overworld_wild_spawns')
 -- External Wilds takes over the embedded provider when present.
 local wildId=external and'overworld_wild_spawns'or(kasc and'kanto_ascendant')
 if wildId then
  for _,d in ipairs(wilds)do add(option(g,wildId,external and d[2]or d[1],d[3],d[4],'wilds'))end
  add(option(g,wildId,external and'town_pokemon'or'living_world_towns','Town Pokémon','Stadt-Pokémon','town'))
  if external then add(option(g,wildId,'sprite_style','Original sprite style','Original-Sprite-Stil','wilds'))end
 end
 if kasc then
  local followers=kasc.exports and kasc.exports.singleFollower
  if not(followers and followers.external)then
   for _,d in ipairs({{'follower_enabled','Followers','Begleiter'}, {'follower_count','Follower count','Begleiter-Anzahl'}, {'follower_order','Follower order','Begleiter-Reihenfolge'}})do
    add(option(g,'kanto_ascendant',d[1],d[2],d[3],'followers'))
   end
  end
  add(option(g,'kanto_ascendant','wilds_town_pokemon_amount','Town population','Stadt-Pokémon: Menge','town'))
  add(option(g,'kanto_ascendant','wilds_town_pokemon_species','Town species pool','Stadt-Pokémon: Region','town'))
 end
 -- Only advertise native options actually registered by an external owner.
 for _,id in ipairs({'FOLLOWERS_EX','PokePCFollowers_VoxelMerge'})do
  if owner(id)then
   for _,d in ipairs({{'enabled','Followers','Begleiter'},{'follower_count','Follower count','Begleiter-Anzahl'}, {'follow_control','Control mode','Steuerungsmodus'},{'trainer_trail','Trainer follows','Trainer folgt'}})do
    add(option(g,id,d[1],d[2],d[3],'followers'))
   end
   break
  end
 end
 for _,d in ipairs({
  {'apo_hd_pokemon_grass','HD wild Pokémon','HD-Wild-Pokémon','wilds'},
  {'apo_grass_pokemon_sprite_source','Wild sprite source','Wild-Pokémon: Grafikquelle','wilds'},
  {'apo_hd_pokemon_wilds_towns','HD ambient Pokémon','HD-Ambient-Pokémon','town'},
  {'apo_wilds_town_pokemon_sprite_source','Ambient sprite source','Ambient: Grafikquelle','town'},
  {'apo_hd_pokemon_city','HD story Pokémon','HD-Story-Pokémon','town'},
  {'apo_city_pokemon_sprite_source','Story sprite source','Story: Grafikquelle','town'},
  {'apo_hd_pokemon_followers','HD follower artwork','HD-Begleitergrafik','followers'},
  {'apo_follower_sprite_source','Follower sprite source','Begleiter: Grafikquelle','followers'},
  {'apo_dynamic_follower_spacing','Follower spacing','Begleiter-Abstand','followers'},
 })do
  local s=settings[d[1]]
  if s then
   add({id=d[1],title=d[2],titleDe=d[3],group=d[4],hint='',detail='',
    status=function()return s:row().value()end,
    change=function(game,dir)local row=s:row();if not row.muted then return row.step(game,dir or 1)end;return false end})
  end
 end
 local priority={['apo_hd_pokemon_grass']=2,['apo_grass_pokemon_sprite_source']=3}
 for i,row in ipairs(rows)do row.order=priority[row.id]or(4+i)end
 for _,row in ipairs(rows)do if row.id:match(':living_world_enabled$')or row.id:match(':enabled$')then row.order=1 end end
 table.sort(rows,function(a,b)return a.order<b.order end)
 return rows
end
return M
