-- Generation adapter for the shared VASC quick menu. Writes go through the
-- registered Gen2 owner and its normal events; no shadow preference store.
local V=...
local mod=V.mod
local M={Game=require('src.core.Game2'),chords={start='f3',dpdown='f4'}}
local function top(g)return g and g.stack and g.stack:top()end
function M.world(g)return g and g.world end
function M.context(g,panel)
  local t=panel and panel.previous or top(g)
  -- A world panel remembers nil, because Game2 does not push its world.
  if panel then t=panel.previous end
  if t and (t.screenId=='Gen2BattleState' or t.isGen2BattleState)
      and t.battle and t.phase then return 'battle',t end
  if not t and g and g.world and g.world.map then return 'world',g.world end
  return 'other',t
end
function M.ready(g)
  if not(g and g.save and g.world and g.stack)then return false end
  local context,t=M.context(g)
  if context=='battle'then return t.phase~='done' and t.phase~='evolving' end
  return context=='world'and g.world:acceptsMenuInput()
end
local presentationKeys={battle3dWorld=true,battleSmartCamera=true,stadium3dSprites=true,battleHudStyle=true,terarriumBehindRed=true}
local function specFor(key)
  for _,s in ipairs(mod._vascGen2Schema or{})do if s.key==key then return s end end
end
local function value(key,spec)
  local val=mod.options:get(key)
  if val==nil then return spec and spec.default end
  return val
end
function M.write(g,key,val)
  local content=mod.exports and mod.exports.ascendantContent
  if content and content.allowSetting and not content:allowSetting(key,val,g)then return false end
  local context,screen=M.context(g,V.Controls and V.Controls.current(g))
  if presentationKeys[key] and context=="battle" and screen.phase~="menu" and screen.phase~="moves" then return false end
  local previous=mod.options:get(key)
  local opts=g.save and g.save.options
  if not opts then return false end
  local manager=g.mods
  local loader=manager and(manager.loader or manager)
  local function apply(v)
    opts.modOptions=opts.modOptions or{};opts.modOptions[mod.id]=opts.modOptions[mod.id]or{}
    opts.modOptions[mod.id][key]=v
    if type(mod.options.set)=='function' then mod.options:set(key,v)end
    for _,owner in ipairs({manager,loader})do
      owner.modOptions=owner.modOptions or{};owner.modOptions[mod.id]=owner.modOptions[mod.id]or{}
      owner.modOptions[mod.id][key]=v
    end
    if loader and loader.events then loader.events:emit('mod.options_changed',{mod=mod.id,key=key,value=v,game=g})end
  end
  apply(val)
  if presentationKeys[key] and context=='battle' then
    local ok,reason=V.Gen2BattleCardHost.changePresentation(screen,function()apply(previous)end)
    if not ok then
      apply(previous)
      mod.log:warn('Battle presentation change declined: %s',tostring(reason))
      return false
    end
  end
  if g.writeOptions then g:writeOptions()else g:persistOptions()end
  return true
end
local function option(key,en,de)
  local s=specFor(key)
  if not s or(s.type~='toggle'and s.type~='choice')then return end
  return {id=key,title=en,titleDe=de,hint='',detail='',
    status=function(german)
      local val=value(key,s)
      if s.type=='toggle'then return val and(german and'AN'or'ON')or(german and'AUS'or'OFF')end
      for _,c in ipairs(s.choices or{})do if c[2]==val then return c[1]end end
      return tostring(val)
    end,
    change=function(g,dir)
      local val=value(key,s)
      if s.type=='toggle'then val=not val else
        local choices=s.choices or{};if #choices==0 then return false end
        local at=1;for i,c in ipairs(choices)do if c[2]==val then at=i;break end end
        val=choices[(at-1+(dir or 1))%#choices+1][2]
      end
      return M.write(g,key,val)
    end}
end
local groups={
  followers={
    {'partyFollower','Party follower','Team-Begleiter'},
    {'follower_count','Follower count','Begleiter-Anzahl'},
    {'follow_control','Control mode','Steuerungsmodus'},
    {'trainer_trail','Trainer follows','Trainer folgt'},
    {'apo_hd_pokemon_followers','HD followers','HD-Begleiter'},
    {'apo_follower_sprite_source','Follower artwork','Begleitergrafik'},
    {'apo_dynamic_follower_spacing','Follower spacing','Begleiter-Abstand'},
  },
  wilds={
    {'enabled','Visible wild Pokémon','Sichtbare wilde Pokémon'},
    {'spawn_density','Wild population','Wild-Pokémon: Menge'},
    {'random_encounters','Random encounters','Zufallskämpfe'},
    {'apo_hd_pokemon_grass','HD wild Pokémon','HD-Wild-Pokémon'},
    {'apo_grass_pokemon_sprite_source','Wild artwork','Wild-Pokémon: Grafik'},
    {'sprite_style','Original sprite style','Original-Sprite-Stil'},
    {'water_spawns','Water Pokémon','Wasser-Pokémon'},
    {'cave_spawns','Cave Pokémon','Höhlen-Pokémon'},
    {'pokemon_grass_render_mode','Grass visibility','Sichtbarkeit im Gras'},
    {'wild_silhouettes','Silhouettes','Silhouetten'},
    {'enable_idle','Idle Pokémon','Ruhende Pokémon'},
    {'enable_wander','Wandering Pokémon','Wandernde Pokémon'},
    {'enable_aggressive','Chasing Pokémon','Verfolgende Pokémon'},
    {'enable_hidden','Hidden Pokémon','Versteckte Pokémon'},
  },
  town={
    {'town_pokemon','Town Pokémon','Stadt-Pokémon'},
    {'apo_hd_pokemon_wilds_towns','HD ambient Pokémon','HD-Ambient-Pokémon'},
    {'apo_wilds_town_pokemon_sprite_source','Ambient artwork','Ambient-Grafik'},
    {'apo_hd_pokemon_city','HD story Pokémon','HD-Story-Pokémon'},
    {'apo_city_pokemon_sprite_source','Story artwork','Story-Grafik'},
  },
  terrarium={
    {'terarriumBehindRed','Behind trainer','Hinter dem Trainer'},
    {'terarriumIdleAnimation','Idle motion','Ruheanimation'},
    {'terarriumIdleSound','Idle sound','Animationsklang'},
    {'terarriumBallStyle','Ball design','Ball-Design'},
    {'terarriumBackground','Background','Hintergrund'},
    {'terarriumDome','Glass dome','Glaskuppel'},
  },
  effects={
    {'voxel3d','Voxel world','Voxel-Welt'},
    {'battle3dWorld','Battle view','Kampfansicht'}, {'grid','Voxel grid','Voxel-Raster'},
    {'curve','World curvature','Weltkrümmung'}, {'water','Water','Wasser'},
    {'scenery','Panoramas','Panoramen'}, {'sky','Sky','Himmel'},
    {'clouds','Clouds','Wolken'}, {'weather','Weather','Wetter'},
    {'localLights','Dynamic lighting','Dynamisches Licht'},
    {'daytime','Time of day','Tageszeit'}, {'shadows','Shadows','Schatten'},
    {'deviceProfile','Performance profile','Leistungsprofil'},
    {'sceneResolution','3D resolution','3D-Auflösung'},
    {'openWorld','Open world','Offene Welt'},
  },
}
local names={followers={'Followers','Begleiter'},wilds={'Wilds','Wilds'},town={'Town Pokémon','Stadt-Pokémon'},effects={'Camera & world','Kamera & Welt'}}
function M.rows(g,group,controls)
  local out={};local function add(r)if r then out[#out+1]=r end end
  local function addOption(d)add(option(d[1],d[2],d[3]))end
  local context=M.context(g,controls.current(g))
  if context=='world'then
    if group then for _,d in ipairs(groups[group]or{})do addOption(d)end
    else
      addOption({'cameraMode','Camera view','Kameraansicht'})
      for _,id in ipairs({'followers','wilds','town','effects'})do
        add({id=id,title=names[id][1],titleDe=names[id][2],submenu=id,hint='',detail='',status=function()return '›'end})
      end
      addOption({'apo_hd_walking_sprites','HD characters','HD-Personen'})
      add({id='content',title='Sprites & downloads',titleDe='Sprites & Downloads',hint='',detail='',status=function()return '›'end,
        change=function(game)require('src.ui.Screens').push(game,'VascPokemonHdDownloads') end})
    end
  elseif context=='battle'then
    if group=='terrarium' then
      for _,d in ipairs(groups.terrarium)do addOption(d)end
      return out
    end
    local _,screen=M.context(g,controls.current(g))
    if screen.phase=='menu' or screen.phase=='moves' then
      addOption({'battle3dWorld','Battle view','Kampfansicht'})
      addOption({'stadium3dSprites','3D Pokémon','3D-Pokémon'})
      local plan=V.require('OverworldBattle').presentationPlan(screen)
      if not(plan and plan.terarrium)then addOption({'battleSmartCamera','Automatic camera','Automatische Kamera'})end
      addOption({'battleHudStyle','Battle HUD','Kampf-HUD'})
    end
    for _,d in ipairs({
      {'battle_controls_shape','Button shape','Buttonform'},
      {'battle_controls_transparency','Button transparency','Button-Transparenz'},
      {'battle_controls_y','Raise buttons','Buttons anheben'},
      {'battle_controls_scale','Button size','Buttongröße'},
    })do addOption(d)end
    local plan=V.require('OverworldBattle').presentationPlan(screen)
    if plan and plan.terarrium then
      add({id='terrarium',title='Terrarium settings',titleDe='Terrarium-Einstellungen',submenu='terrarium',hint='',detail='',status=function()return '›'end})
    end
    local shot=V.require('OverworldBattle').shot()
    if shot then
      if shot.liveWorld then addOption({'localLights','Dynamic lighting','Dynamisches Licht'})end
      addOption({'sceneResolution','3D resolution','3D-Auflösung'})
      addOption({'pokemonModelSkin','Pokémon artwork','Pokémon-Grafik'})
      addOption({'battleGrid','Battle grid','Kampf-Raster'})
      add({id='closer',title='Zoom in',titleDe='Näher heran',hint='Q',detail='',status=function()return '+'end,change=function()V.require('CamControl').zoomBy(-1)end})
      add({id='farther',title='Zoom out',titleDe='Weiter heraus',hint='E',detail='',status=function()return '−'end,change=function()V.require('CamControl').zoomBy(1)end})
      -- Staged battles use BattleCam; live-world battles use the world rig.
      if not shot.liveWorld then
        local camera=V.require('CamControl')
        add({id='camera-reset',title='Centre camera',titleDe='Kamera zentrieren',hint='',detail='',status=function()return '↺'end,change=function()camera.recentre()end})
      end
    end
  end
  if not group then
    local hud=V.require('PerformanceOverlay')
    add({id='fps',title='FPS / Frame time',titleDe='FPS / Framezeit',hint='F4',detail='',status=function(de)return hud.enabled:get()and(de and'AN'or'ON')or(de and'AUS'or'OFF')end,
      change=function(game)hud.enabled:setValue(not hud.enabled:get(),game)end})
  end
  return out
end
function M.drawBackdrop(g)
  if M.context(g,V.Controls.current(g))~='battle' then return end
  local shot=V.require('OverworldBattle').shot()
  if not(shot and shot.canvas)then return end
  local G=love.graphics
  G.push('all');G.origin();G.setShader();G.setColor(1,1,1,1)
  local w,h=G.getDimensions();local cw,ch=shot.canvas:getDimensions()
  G.draw(shot.canvas,0,0,0,w/cw,h/ch);G.pop()
end
function M.install(controls)
  V.PerformanceOverlay=V.require('PerformanceOverlay')
  local function syncOverlay()
    for _,entry in ipairs(V.PerformanceOverlay.entries())do
      local setting=entry[1];local val=mod.options:get(setting.key)
      if val~=nil then setting:sync(val)end
    end
  end
  syncOverlay()
  for _,event in ipairs({'game.ready','save.loaded','save.created'})do mod.events:on(event,syncOverlay)end
  mod.events:on('mod.options_changed',function(p)
    if p and p.mod==mod.id and tostring(p.key):match('^live')then syncOverlay()end
  end)
  V.PerformanceOverlay.install(M.Game)
  controls.install()
end
return M
