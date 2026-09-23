-- KASC owns the wardrobe; the live people provider only chooses its surface.
return function(mod,opts)
 local W=assert(opts.wardrobe)
 local P={}
 function P.hd()
  local provider=mod.find and mod:find('VOXEL_ASCENDANT')
  local api=provider and provider.exports and provider.exports.overworldPokemon
  local walking=api and api.walkingSprites
  if not api or api.active==false or not walking or type(walking.enabled)~='function'then return false end
  local ok,enabled=pcall(walking.enabled)
  return ok and enabled==true
 end
 function P.mode(selection)
  if selection and selection.style=='native'or not P.hd()then return'2d'end
  local provider=mod:find('VOXEL_ASCENDANT')
  local api=provider and provider.exports and provider.exports.overworldPokemon
  local walking=api and api.walkingSprites
  return walking and walking.voxelDemoEnabled and walking.voxelDemoEnabled()and'voxel'or'hd'
 end
 function P.resolve(path,id,selection,action)
  local provider=mod.find and mod:find('VOXEL_ASCENDANT')
  local api=provider and provider.exports and provider.exports.overworldPokemon
  local walking=api and api.walkingSprites
  if P.mode(selection)=='voxel'and walking and walking.resolveAppearance then
   return walking.resolveAppearance(path,id,action,selection)
  end
  return W.resolve(path,id,selection)
 end
 local previous=P.hd()
 function P.sync(game)
  local hd=P.hd()
  if previous==hd then return end
  previous=hd
  -- Refresh after VASC has restored its original actors on the OFF edge.
  -- The same saved outfit then binds to the native six-frame renderer.
  W.refresh(game)
 end
 function P.install()
  for _,event in ipairs({'game.ready','mod.options_changed'})do
   mod.events:on(event,function(ev)P.sync(ev and ev.game)end,-2000)
  end
  -- VASC menu/F6 settings can refresh people without emitting an option event.
  -- Observe that public boolean after the engine update, before drawing.
  mod.hooks:wrap('core.update',function(nextUpdate,game,...)
   local result=nextUpdate(game,...)
   P.sync(game)
   return result
  end,-2000)
 end
 return P
end
