-- KASC-owned wardrobe. Optional HD presentation consumes the same selection.
return function(mod,opts)
  local function load(name)return opts.load(mod,'wardrobe_'..name..'.lua')end
  local catalog=load('catalog')
  -- Only complete, hash-checked authored packages can activate appearances.
  local wardrobe=opts.load(mod,'wardrobe.lua')(mod,{catalog=catalog,appearanceReady=false})
  wardrobe.assets=load('authored_assets')(mod,{catalog=catalog,wardrobe=wardrobe,compositor=load('overlay')})
  for _,directory in ipairs(load('packages'))do
    local ok,err=pcall(function()
      local package=opts.load(mod,directory..'/manifest.lua')
      wardrobe.assets.register({directory=directory,package=package})
    end)
    if not ok then wardrobe.assets.errors[directory]=tostring(err)end
  end
  wardrobe.appearanceReady=not next(wardrobe.assets.errors)
    and wardrobe.assets.available('RED','champion')
    and wardrobe.assets.available('BLUE','champion')
    and wardrobe.assets.available('GREEN','champion')
  wardrobe.presentation=load('presentation')(mod,{wardrobe=wardrobe})
  wardrobe.menu=load('menu')(mod,{wardrobe=wardrobe,i18n=opts.i18n})
  wardrobe.walker2d=load('walker2d')(mod,{wardrobe=wardrobe})
  wardrobe.world=load('world')(mod,{menu=wardrobe.menu})
  wardrobe.cardId='kasc.characters.wardrobe'
  wardrobe.card={schema='kanto-ascendant/consumer-card/v1',id=wardrobe.cardId,
    version='1.2.1',owner=mod.id,requires={},saveWrites={'wardrobe_v1'}}
  mod.exports.wardrobe=wardrobe
  opts.characters.wardrobe=wardrobe
  local function enabled()return not mod.options or mod.options:get('wardrobe_enabled')~=false end
  -- Legacy optional HD bridges used setActive as their own toggle. KASC 1.2
  -- owns activation; an old renderer setting must not turn off its wardrobe.
  local activate=wardrobe.setActive
  wardrobe.setActive=function(_,game)activate(enabled(),game)end
  wardrobe.setActive(enabled())
  mod.events:on('mod.options_changed',function(ev)
    if ev and ev.mod==mod.id then wardrobe.setActive(enabled(),ev.game)end
  end)
  wardrobe.presentation.install()
  return wardrobe
end
