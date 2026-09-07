-- Optional read-only consumer of KASC's versioned equipment authority.
-- No initialization, command dispatch, migration, inventory access or caching.
local M={SCHEMA="kasc.pokemon-equipment-view/v1",OWNER="kasc.pokemon-equipment/v1"}
local function find(mod,id)
  if not(mod and type(mod.find)=="function")then return nil end
  local ok,h=pcall(mod.find,id)
  if not ok or not h then ok,h=pcall(mod.find,mod,id)end
  return ok and type(h)=="table" and h.exports or nil
end
local function text(v)
  return type(v)=="string" and #v>0 and #v<=256 and not v:find("[%z\1-\31]") and v or nil
end
function M.read(mod,game,mon)
  local exports=find(mod,"kanto_ascendant")
  local api=exports and exports.pokemonEquipment67
  if type(api)~="table" or api.schema~=M.SCHEMA or api.version~=1 or api.owner~=M.OWNER
    or type(api.snapshotForMon)~="function" or type(api.capabilities)~="function"then
    return nil,false,"equipment_provider_unavailable"
  end
  local ok,cap=pcall(api.capabilities)
  if not ok or type(cap)~="table" or cap.schema~=M.SCHEMA or cap.version~=1
    or cap.readOnlySnapshots~=true then return nil,false,"equipment_provider_incompatible"end
  local good,view,reason=pcall(api.snapshotForMon,game,mon)
  -- A recognized authority that cannot supply this mon must not be replaced
  -- by species-derived guesses. Existing native commands remain untouched.
  if not good or type(view)~="table"then
    return nil,true,good and text(reason) or "equipment_snapshot_failed"
  end
  if view.schema~=M.SCHEMA or view.owner~=M.OWNER or not text(view.handle)
    or not text(view.revision) or type(view.isEgg)~="boolean"then
    return nil,true,"equipment_snapshot_invalid"
  end
  if view.isEgg then return {isEgg=true},true end
  local translation=find(mod,"translation-german-universal")
  local language=translation and translation.bootLanguage=="de" and "de" or "en"
  local function value(row)
    if type(row)~="table" or type(row.active)~="boolean"
      or (row.id~=false and not text(row.id))then return nil end
    local names=type(row.names)=="table" and row.names or {}
    return {id=row.id,name=row.id~=false and (text(names[language]) or text(names.en) or row.id) or false,
      active=row.active,reasonCode=text(row.reasonCode)}
  end
  local item,ability=value(view.item),value(view.ability)
  if not item or not ability then return nil,true,"equipment_snapshot_invalid"end
  -- Return fresh scalars only; never expose the owner's handle or commands to
  -- an old PokemonUi provider contract which has not negotiated those actions.
  return {isEgg=false,item=item,ability=ability},true
end
return M
