-- Explicit Pokemon-only option ownership. Native art and authored people/effects
-- never acquire a download requirement merely because their key says "sprite".
local M={}
local toggles={kanto_crystal_art='pokemon-crystal',crystal_animation='pokemon-crystal-animation',
 non_crystal_pixel_2d='pokemon-pixel-2d',non_crystal_voxel_animations='pokemon-hd-2d'}
local surfaces={sprite_style_battle=true,sprite_style_summary=true,sprite_style_dex=true,
 sprite_style_box=true,sprite_style_scenes=true}
local function crystal(value,get)
 return value=='crystal' or ((value==nil or value=='legacy') and get and get('kanto_crystal_art')~=false)
end
function M.required(key,value,get)
 if type(key)~='string' then return nil end
 if key=='mega_sprite_collection' then
  return ({['original-20260830']='pokemon-mega-original-20260830',current='pokemon-mega'})[value]
 end
 if key=='pokemon_sprite_style' or key=='dex_sprite_style' then
  return crystal(value,get) and 'pokemon-crystal' or nil
 elseif key=='party_icon_style' then return value=='animated' and 'pokemon-icons' or nil
 elseif key=='box_grid_icon_style' then return value=='hgss_walker' and 'pokemon-overworld-pixel' or nil
 elseif toggles[key] then return value==true and toggles[key] or nil
 elseif surfaces[key] then
  return value==true and get and crystal(get('pokemon_sprite_style'),get) and 'pokemon-crystal' or nil
 elseif key=='sprite_style' then
  return ({pokemmo='pokemon-overworld-mmo',followers='pokemon-overworld-pixel'})[value]
 elseif key=='modernDexSpriteSource' then
  return value=='hd' and 'pokemon-hd-3d'
    -- Gen2 'crystal' uses its packaged menu fronts, not KASC's pack.
    or value=='kasc_crystal' and 'pokemon-crystal' or nil
 elseif key=='battleHdSprites' then return value==true and 'pokemon-hd-3d' or nil
 elseif key:match('^apo_.*sprite_source$') then
  return ({full_hd='pokemon-hd-3d',pokemmo='pokemon-overworld-mmo'})[value]
 elseif key=='apo_pokemon_model_source' then
  return (value=='go_only' or value=='go_first') and 'pokemon-hd-3d' or nil
 end
 return nil
end
return M
