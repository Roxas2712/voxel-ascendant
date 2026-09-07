-- Native Gen1Recomp host adapters for PokemonUi Host Contract v1.
--
-- Only this host layer touches Game/save/Party/Boxes and native callbacks.
-- The selected provider receives immutable descriptors and dispatches bounded
-- actions.  In a combined install an already registered external owner wins
-- pc_box; VASC does not create a second session or consume a second input.

local V = ...
local Hosts = {}

local Boxes = require("src.pokemon.Boxes")
local Party = require("src.pokemon.Party")
local Stats = require("src.pokemon.Stats")
local Screens = require("src.ui.Screens")
local GameVersion = require("src.core.GameVersion")
local AscBoxProvider = V.require("AscBoxProvider")
local PartyMenuSkins = V.require("PartyMenuSkins")
local EquipmentView
do
  local ok,value=pcall(V.require,"PokemonEquipmentView")
  if ok and type(value)=="table" then EquipmentView=value end
end
local MobileMenuPresentation
do
  local ok, value = pcall(V.require, "MobileMenuPresentation")
  if ok and type(value) == "table" then MobileMenuPresentation = value end
end

local battleHudExtras, battleHudExtrasTried
local function presentationGender(game, mon)
  if not battleHudExtrasTried then
    battleHudExtrasTried = true
    local ok, service = pcall(V.require, "BattleHudExtras")
    if ok and type(service) == "table"
        and type(service.presentationGender) == "function" then
      battleHudExtras = service
    end
  end
  if battleHudExtras then
    local ok, value = pcall(battleHudExtras.presentationGender, mon, game)
    if ok and type(value) == "string" and value ~= "" then return value end
  end
  local explicit = tostring(mon and (mon.gender or mon.sex) or ""):upper()
  if explicit == "MALE" or explicit == "M" or explicit == "♂" then
    return "MALE"
  elseif explicit == "FEMALE" or explicit == "F" or explicit == "♀" then
    return "FEMALE"
  end
  return "GENDERLESS"
end

local serial = 0
local VASC_OWNER = "VOXEL_ASCENDANT"
local BOX_META_KEY = "__vascOrasBox"
local SLOT_META_KEY = "__vascOrasSlot"
local HOST_VIEWPORTS = {
  { width=160, height=144 },
  { width=480, height=360 },
  { width=512, height=288 },
}

local function clearBoxSeat(mon)
  if type(mon) ~= "table" then return end
  mon[BOX_META_KEY], mon[SLOT_META_KEY] = nil, nil
end

local function validBoxSeat(value)
  value = tonumber(value)
  if not value or value ~= math.floor(value)
      or value < 1 or value > Boxes.CAPACITY then return nil end
  return value
end

local function numericMons(list)
  local rows = {}
  for key, mon in pairs(type(list) == "table" and list or {}) do
    if type(key) == "number" and key >= 1 and key == math.floor(key)
        and type(mon) == "table" then
      rows[#rows + 1] = { key=key, mon=mon }
    end
  end
  table.sort(rows, function(a, b) return a.key < b.key end)
  return rows
end

local function firstFreeSeat(used)
  for slot = 1, Boxes.CAPACITY do
    if not used[slot] then return slot end
  end
end

-- The engine and KASC require dense numeric Box arrays. ASC BOX keeps the
-- independent visible seat on the Pokemon itself, using the same namespaced
-- metadata as the final 0.5.3 prototype. This migration never leaves holes
-- for `#box`, ipairs or ordinary saves.
local function normalizeBox(box, boxIndex, partyMons)
  local rows, used = numericMons(box), {}
  for _, row in ipairs(rows) do
    local mon = row.mon
    local slot = mon[BOX_META_KEY] == boxIndex
      and validBoxSeat(mon[SLOT_META_KEY]) or nil
    if slot and not used[slot] then row.slot, used[slot] = slot, true end
  end
  for _, row in ipairs(rows) do
    if not row.slot then
      local old = validBoxSeat(row.key)
      row.slot = old and not used[old] and old or firstFreeSeat(used)
      if row.slot then used[row.slot] = true end
    end
  end
  table.sort(rows, function(a, b)
    if a.slot ~= b.slot then return (a.slot or math.huge) < (b.slot or math.huge) end
    return a.key < b.key
  end)
  for key in pairs(box) do if type(key) == "number" then box[key] = nil end end
  for dense, row in ipairs(rows) do
    box[dense] = row.mon
    if not partyMons[row.mon] then
      row.mon[BOX_META_KEY], row.mon[SLOT_META_KEY] = boxIndex, row.slot
    end
  end
end

local function ensureSpatialBoxes(save)
  local boxes = Boxes.ensure(save)
  save.party = type(save.party) == "table" and save.party or {}
  local partyMons = {}
  for _, mon in ipairs(save.party) do
    if type(mon) == "table" then partyMons[mon] = true; clearBoxSeat(mon) end
  end
  for index = 1, Boxes.COUNT do
    boxes[index] = type(boxes[index]) == "table" and boxes[index] or {}
    normalizeBox(boxes[index], index, partyMons)
  end
  return boxes
end

local function monAtBox(box, boxIndex, slot)
  slot = validBoxSeat(slot)
  if not slot then return nil end
  for dense, mon in ipairs(box or {}) do
    if mon[BOX_META_KEY] == boxIndex and mon[SLOT_META_KEY] == slot then
      return mon, dense
    end
  end
end

local function copy(items)
  local out = {}
  for index, item in ipairs(items or {}) do out[index] = item end
  return out
end

local function arraysFor(PokemonUi, surface)
  local req = PokemonUi.REQUIREMENTS[surface]
  return copy(req.modes), copy(req.actions), copy(req.events)
end

local function schemas(PokemonUi)
  return {
    model=PokemonUi.MODEL_SCHEMA, action=PokemonUi.ACTION_SCHEMA,
    actionResult=PokemonUi.ACTION_RESULT_SCHEMA, event=PokemonUi.EVENT_SCHEMA,
  }
end

local function hostSurface(PokemonUi, surface)
  local req = PokemonUi.REQUIREMENTS[surface]
  local modes, actions, events = arraysFor(PokemonUi, surface)
  return {
    controllerGeneration=PokemonUi.CONTROLLER_GENERATION,
    viewports=copy(HOST_VIEWPORTS),
    schemas=schemas(PokemonUi), modes=modes, actions=actions, events=events,
    claims={ model="immutable_snapshot", actions="authoritative",
      input="exclusive", commit="atomic",
      fallback="whole_surface_next_frame", selection=req.selection },
  }
end

local function locale()
  -- A loaded universal translation owns the whole game's boot language.  It
  -- must win over VASC's historical HUD-only preference; otherwise the Box
  -- and Team hosts can be the lone English surfaces in a German session.
  if V.mod and type(V.mod.find) == "function" then
    local ok, handle = pcall(V.mod.find, V.mod,
      "translation-german-universal")
    if not ok or handle == nil then ok, handle = pcall(V.mod.find,
      "translation-german-universal") end
    local boot = ok and handle and handle.exports
      and handle.exports.bootLanguage
    if boot == "de" or boot == "en" then return boot end
    for _, id in ipairs({ "universal_german", "deutsch",
        "deutsch-blau", "deutsch-gelb" }) do
      local found, legacy = pcall(V.mod.find, V.mod, id)
      if not found or legacy == nil then
        found, legacy = pcall(V.mod.find, id)
      end
      if found and legacy then return "de" end
    end
  end
  local value = V.mod and V.mod.options and V.mod.options:get("hud_language")
  if value == "de" then return "de" end
  if value == "en" then return "en" end
  return "en"
end

local function edition()
  local ok, value = pcall(GameVersion.get)
  return tostring(ok and value or "red"):lower()
end

local STAT_KEYS = {
  hp={ "hp", "maxHp", "maxHP" },
  attack={ "attack", "atk" },
  defense={ "defense", "def" },
  speed={ "speed", "spe" },
  special={ "special", "specialAttack", "spAttack", "spAtk" },
}

local function nonnegativeInteger(value)
  value = tonumber(value)
  if not value then return nil end
  return math.max(0, math.floor(value))
end

local function firstStat(sources, keys)
  for _, source in ipairs(sources) do
    if type(source) == "table" then
      for _, key in ipairs(keys) do
        local value = nonnegativeInteger(source[key])
        if value ~= nil then return value end
      end
    end
  end
  return nil
end

-- Party structs already carry calculated stats. Gen-I Box structs do not, so
-- calculate a temporary presentation block without attaching it to the live
-- Pokemon/save. The alias reads keep the immutable Host-v1 descriptor usable
-- with Gen-II-style adapters while the canonical attack/defense names remain
-- preferred.
local function presentationStats(game, mon, def)
  local sources = { mon.stats, mon }
  local out = {}
  for key, aliases in pairs(STAT_KEYS) do
    out[key] = firstStat(sources, aliases)
  end
  if (out.hp == nil or out.attack == nil or out.defense == nil)
      and type(def) == "table" and type(def.baseStats) == "table"
      and type(Stats.calc) == "function" then
    local ok, calculated = pcall(Stats.calc, def,
      math.max(1, tonumber(mon.level) or 1), mon.dvs or {}, mon.statExp, mon)
    if ok and type(calculated) == "table" then
      for key, aliases in pairs(STAT_KEYS) do
        if out[key] == nil then out[key] = firstStat({ calculated }, aliases) end
      end
    end
  end
  return out
end

local function typeId(value)
  if type(value) == "table" then
    value = value.id or value.name or value.key or value.type
  end
  if type(value) ~= "string" or value == "" then return nil end
  value = value:upper():gsub("[%s%-]+", "_")
  if value == "PSYCHIC" then value = "PSYCHIC_TYPE" end
  return value
end

local function pokemonTypes(mon, def)
  local out = {}
  local function append(value)
    local kind = typeId(value)
    if kind and kind ~= out[1] and kind ~= out[2] and #out < 2 then
      out[#out + 1] = kind
    end
  end
  local function appendSource(source)
    if type(source) == "table" then
      for _, value in ipairs(source) do append(value) end
      append(source.primary)
      append(source.secondary)
      append(source.type1)
      append(source.type2)
    else
      append(source)
    end
  end
  appendSource(mon.types)
  append(mon.type1)
  append(mon.type2)
  append(mon.type)
  if #out < 2 and type(def) == "table" then
    appendSource(def.types)
    append(def.type1)
    append(def.type2)
    append(def.type)
  end
  return out
end

local function eggDescriptor()
  return {species="EGG",egg=true,nickname="EGG",level=0,
    art={kind="pokemon",species="EGG",egg=true,variant="vasc_neutral"}}
end

local function pokemonDescriptor(game, mon)
  if type(mon) ~= "table" then return nil end
  local egg = mon.egg == true or mon.isEgg == true or mon.is_egg == true
    or tostring(mon.status or ""):upper() == "EGG"
    or ({ EGG=true, POKEMON_EGG=true })[tostring(mon.species or ""):upper()]
  if egg then
    -- A storage snapshot must not reveal the future hatchling's species,
    -- nickname, shiny flag, moves or stats before the Egg opens.
    return eggDescriptor()
  end
  local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
  local types = pokemonTypes(mon, def)
  -- KASC's Gen-II-compatible shiny state is normally encoded in DVs rather
  -- than duplicated onto `mon.shiny`.  Resolve it while the authoritative
  -- host still has the live record, then expose only the resulting boolean.
  local shiny = mon.shiny == true or Stats.isShiny(mon.dvs)
  local stats = presentationStats(game, mon, def)
  local gender = presentationGender(game, mon)
  local item = mon.item or mon.heldItem or mon.held_item
  if type(item) == "table" then item = item.id or item.name end
  local ability = mon.ability or (def and def.ability)
  if ability == nil and def and type(def.abilities) == "table" then
    ability = def.abilities[1]
  end
  if type(ability) == "table" then ability = ability.id or ability.name end
  if EquipmentView then
    local equipment,owned=EquipmentView.read(V.mod,game,mon)
    if owned then
      if equipment and equipment.isEgg then return eggDescriptor() end
      -- Explicit none, unknown identity or a failed authoritative snapshot
      -- never falls back to a guessed species ability or stale item alias.
      item=equipment and not equipment.isEgg and equipment.item.name or nil
      ability=equipment and not equipment.isEgg and equipment.ability.name or nil
    end
  end
  return {
    species=mon.species, form=mon.form, gender=gender,
    shiny=shiny, egg=false,
    nickname=mon.nickname, level=math.max(0, tonumber(mon.level) or 0),
    hp=math.max(0, tonumber(mon.hp) or 0),
    maxHp=stats.hp,
    attack=stats.attack, defense=stats.defense,
    speed=stats.speed, special=stats.special,
    status=type(mon.status) == "string" and mon.status or nil,
    ability=(type(ability) == "string" or type(ability) == "number")
      and ability or nil,
    item=(type(item) == "string" or type(item) == "number") and item or nil,
    palette=(type(mon.palette) == "string" or type(mon.palette) == "number")
      and mon.palette or nil,
    types=types,
    art={ kind="pokemon", species=mon.species, form=mon.form,
      gender=gender, shiny=shiny,
      egg=false,
      palette=(type(mon.palette) == "string" or type(mon.palette) == "number")
        and mon.palette or nil },
  }
end

local SEARCH_CASEFOLD = {
  ["Ä"]="ä", ["Ö"]="ö", ["Ü"]="ü", ["ẞ"]="ß",
  ["À"]="à", ["Á"]="á", ["Â"]="â", ["Ã"]="ã", ["Å"]="å",
  ["Ç"]="ç", ["È"]="è", ["É"]="é", ["Ê"]="ê", ["Ë"]="ë",
  ["Ì"]="ì", ["Í"]="í", ["Î"]="î", ["Ï"]="ï", ["Ñ"]="ñ",
  ["Ò"]="ò", ["Ó"]="ó", ["Ô"]="ô", ["Õ"]="õ", ["Ù"]="ù",
  ["Ú"]="ú", ["Û"]="û", ["Ý"]="ý", ["Ÿ"]="ÿ",
}

local function searchFold(value)
  value = tostring(value or "")
  value = value:gsub("A\204\136", "ä"):gsub("a\204\136", "ä")
    :gsub("O\204\136", "ö"):gsub("o\204\136", "ö")
    :gsub("U\204\136", "ü"):gsub("u\204\136", "ü")
  for upper, lower in pairs(SEARCH_CASEFOLD) do value = value:gsub(upper, lower) end
  return value:lower():gsub("\204[\128-\191]", "")
    :gsub("\205[\128-\175]", ""):gsub("[_%-]+", " ")
    :gsub("%s+", " "):match("^%s*(.-)%s*$")
end

local function searchMatches(game, mon, mode, query)
  local descriptor = pokemonDescriptor(game, mon)
  if not descriptor then return false end
  query = searchFold(query)
  if query == "" then return false end
  if descriptor.egg == true then
    return mode == "name"
      and searchFold(descriptor.nickname):find(query, 1, true) ~= nil
  end
  if mode == "name" then
    local species = searchFold(descriptor.species):gsub("_", " ")
    local def = game and game.data
    local speciesName = type(def) == "table" and def.pokemon
      and def.pokemon[mon.species] and def.pokemon[mon.species].name
    return searchFold(descriptor.nickname):find(query, 1, true) ~= nil
      or species:find(query, 1, true) ~= nil
      or searchFold(speciesName):find(query, 1, true) ~= nil
  elseif mode == "type" then
    for _, kind in ipairs(descriptor.types or {}) do
      if searchFold(kind):find(query, 1, true) ~= nil then return true end
    end
  elseif mode == "gender" then
    local gender = searchFold(descriptor.gender)
    local wanted = query == "m" and "male" or query == "f" and "female"
      or query == "g" and "genderless" or query
    return gender == wanted
  end
  return false
end

local BaseSession = {}
BaseSession.__index = BaseSession

function BaseSession:opaqueId(zone, box, slot, mon)
  local egg = type(mon) == "table"
    and (mon.egg == true or mon.isEgg == true or mon.is_egg == true
      or tostring(mon.status or ""):upper() == "EGG"
      or ({ EGG=true, POKEMON_EGG=true })[tostring(mon.species or ""):upper()])
  return table.concat({ self.id, zone, tostring(box or 0), tostring(slot),
    egg and "EGG" or tostring(mon and mon.species or "empty") }, ":")
end

function BaseSession:bindEntry(zone, box, slot, mon, extra, denseIndex)
  local id = self:opaqueId(zone, box, slot, mon)
  self.bindings[id] = {
    id=id, zone=zone, box=box, slot=slot, mon=mon, denseIndex=denseIndex,
  }
  local out = {
    id=id, zone=zone, box=box, slot=slot,
    pokemon=pokemonDescriptor(self.game, mon), selected=false, enabled=true,
  }
  for key, value in pairs(extra or {}) do out[key] = value end
  return out
end

function BaseSession:availability(enabled, reason, confirmation)
  return { enabled=enabled and true or false, reason=reason,
    confirmationRequired=confirmation and true or nil }
end

function BaseSession:locate(target)
  local binding = type(target) == "table" and self.bindings[target.id] or nil
  if not binding or binding.zone ~= target.zone or binding.slot ~= target.slot
      or binding.box ~= target.box then return nil end
  return binding
end

function BaseSession:result(envelope, status, code, opts)
  opts = opts or {}
  if status == "applied" then self.revision = self.revision + 1 end
  local result = {
    schema=self.PokemonUi.ACTION_RESULT_SCHEMA,
    apiVersion=self.PokemonUi.API_VERSION,
    host=envelope.host, hostGeneration=envelope.hostGeneration,
    surface=envelope.surface, session=envelope.session,
    action=envelope.action, requestRevision=envelope.modelRevision,
    status=status, code=code,
  }
  if status ~= "closed" then result.model = self:buildModel() end
  if opts.message then result.message = opts.message end
  if opts.confirmation then result.confirmation = opts.confirmation end
  return result
end

function BaseSession:reject(envelope, code, text)
  return self:result(envelope, "rejected", code, text and {
    message={ text=text, severity="warning" },
  } or nil)
end

function BaseSession:inspect(envelope)
  local target = self:locate(envelope.target)
  if not target or not target.mon then return self:reject(envelope, "stale_target") end
  if pokemonDescriptor(self.game, target.mon).egg == true then
    return self:reject(envelope, "egg_hidden")
  end
  Screens.push(self.game, "SummaryMenu", target.mon)
  return self:result(envelope, "applied", "summary_opened")
end

function BaseSession:dexEntry(envelope)
  local target = self:locate(envelope.target)
  if not target or not target.mon then return self:reject(envelope, "stale_target") end
  local descriptor = pokemonDescriptor(self.game, target.mon)
  if descriptor.egg == true then return self:reject(envelope, "egg_hidden") end
  local catalog = self.game.data and self.game.data.pokemon
  if not descriptor.species or type(catalog) ~= "table"
      or not catalog[descriptor.species] then
    return self:reject(envelope, "dex_unavailable")
  end
  Screens.push(self.game, "DexEntryMenu", {
    species=descriptor.species, forceOwned=true,
  })
  return self:result(envelope, "applied", "dex_opened")
end

local PcSession = setmetatable({}, { __index=BaseSession })
PcSession.__index = PcSession

function PcSession.new(PokemonUi, handle, game, native, screen)
  serial = serial + 1
  return setmetatable({
    PokemonUi=PokemonUi, handle=handle, game=game, native=native,
    screen=screen, id="vasc-pc-" .. serial, revision=0,
    focusZone="box", boxFocusSlot=1, partyFocusSlot=1,
    bindings={}, pendingRelease=nil,
    searchMode="name", searchQuery="", searchTargets={},
  }, PcSession)
end

function PcSession:buildModel()
  local language = locale()
  local boxes = ensureSpatialBoxes(self.game.save)
  local current = math.max(1, math.min(Boxes.COUNT,
    tonumber(self.game.save.currentBox) or 1))
  self.game.save.currentBox = current
  local box, party = boxes[current], self.game.save.party or {}
  self.bindings = {}
  local boxEntries, partyEntries = {}, {}
  -- Bind all Boxes so a held opaque source remains valid after a promptless
  -- cross-Box page change. Only the current Box is exposed in the snapshot.
  for boxIndex, list in ipairs(boxes) do
    for denseIndex, mon in ipairs(list) do
      local slot = validBoxSeat(mon[SLOT_META_KEY]) or denseIndex
      local entry = self:bindEntry("box", boxIndex, slot, mon, nil, denseIndex)
      if boxIndex == current then boxEntries[#boxEntries + 1] = entry end
    end
  end
  for slot, mon in ipairs(party) do
    partyEntries[#partyEntries + 1] = self:bindEntry(
      "party", nil, slot, mon, nil, slot)
  end
  local searchResults = {}
  for _, target in ipairs(self.searchTargets or {}) do
    local binding = self.bindings[target.id]
    if binding and binding.mon and binding.box == target.box
        and binding.slot == target.slot then
      searchResults[#searchResults + 1] = {
        id=binding.id, box=binding.box, slot=binding.slot,
        sourceBox=binding.box, sourceSlot=binding.slot,
        pokemon=pokemonDescriptor(self.game, binding.mon),
      }
    end
  end
  local focusSlot = self.focusZone == "box"
    and self.boxFocusSlot or self.partyFocusSlot
  local focus = { zone=self.focusZone, slot=focusSlot,
    box=self.focusZone == "box" and current or nil }
  local focusList = self.focusZone == "box" and boxEntries or partyEntries
  for _, entry in ipairs(focusList) do
    if entry.slot == focusSlot then focus.id = entry.id break end
  end
  local target = focus.id and self.bindings[focus.id] or nil
  local targetEgg = target and pokemonDescriptor(self.game, target.mon).egg == true
  local inBox = target and target.zone == "box"
  local inParty = target and target.zone == "party"
  local canPrint = false
  local okYellow, isYellow = pcall(GameVersion.isYellow)
  if okYellow then canPrint = isYellow and true or false end
  local availability = {
    navigate=self:availability(true),
    inspect=self:availability(target ~= nil and not targetEgg,
      targetEgg and "egg_hidden" or nil),
    dex_entry=self:availability(target ~= nil and not targetEgg,
      targetEgg and "egg_hidden" or nil),
    move=self:availability(true),
    withdraw=self:availability(inBox and #party < Party.MAX,
      #party >= Party.MAX and "party_full" or nil),
    deposit=self:availability(inParty and #party > 1 and #box < Boxes.CAPACITY,
      #party <= 1 and "last_party_mon" or #box >= Boxes.CAPACITY and "box_full" or nil),
    release=self:availability(inBox, nil, true),
    change_box=self:availability(true),
    print_box=self:availability(canPrint, canPrint and nil or "not_yellow"),
    search=self:availability(true),
    search_locate=self:availability(true),
    cancel=self:availability(true),
  }
  return {
    schema=self.PokemonUi.MODEL_SCHEMA, apiVersion=self.PokemonUi.API_VERSION,
    host="vasc_gen1_native", hostGeneration=self.PokemonUi.HOST_GENERATION,
    surface="pc_box", session=self.id, revision=self.revision,
    locale=language, edition=edition(), mode="browse_box",
    title="ASC BOX", help=language == "de"
      and "A: AKTION  SELECT: TEAM" or "A: ACTION  SELECT: PARTY",
    focus=focus, selection={ kind="single", ids={} },
    zones={
      box={ label=("BOX %02d"):format(current), index=current,
        count=#box, capacity=Boxes.CAPACITY, entries=boxEntries },
      party={ label="PARTY", count=#party, capacity=Party.MAX,
        entries=partyEntries },
    },
    availability=availability,
    surfaceData={ title="ASC BOX", currentBox=current,
      boxCount=Boxes.COUNT, boxCapacity=Boxes.CAPACITY,
      partyCapacity=Party.MAX, canPrint=canPrint },
    search={ active=searchFold(self.searchQuery) ~= "", mode=self.searchMode,
      query=self.searchQuery, results=searchResults },
  }
end

function PcSession:search(envelope)
  self.searchMode = envelope.mode
  self.searchQuery = envelope.query:sub(1, 32)
  self.searchTargets = {}
  if searchFold(self.searchQuery) == "" then
    self.searchQuery = ""
    return self:result(envelope, "applied", "search_updated")
  end
  local boxes = ensureSpatialBoxes(self.game.save)
  for boxIndex, box in ipairs(boxes) do
    for denseIndex, mon in ipairs(box) do
      local slot = validBoxSeat(mon[SLOT_META_KEY]) or denseIndex
      if searchMatches(self.game, mon, self.searchMode, self.searchQuery) then
        local id = self:opaqueId("box", boxIndex, slot, mon)
        self.searchTargets[#self.searchTargets + 1] = {
          id=id, box=boxIndex, slot=slot,
        }
      end
    end
  end
  return self:result(envelope, "applied", "search_updated")
end

function PcSession:locateSearch(envelope)
  local target = self:locate(envelope.target)
  if not target or target.zone ~= "box" or not target.mon then
    return self:reject(envelope, "stale_target")
  end
  self.game.save.currentBox = target.box
  self.focusZone, self.boxFocusSlot = "box", target.slot
  return self:result(envelope, "applied", "search_located")
end

function PcSession:navigate(envelope)
  local direction = envelope.direction
  if direction == "page_next" or direction == "page_prev" then
    self.focusZone = self.focusZone == "box" and "party" or "box"
    return self:result(envelope, "applied", "focus_changed")
  end
  local spec = AscBoxProvider.gridSpec()
  if self.focusZone == "party" then
    local slot = self.partyFocusSlot
    if direction == "left" and slot == 1 then
      self.focusZone, self.boxFocusSlot = "box", spec.slots
    elseif direction == "left" then
      self.partyFocusSlot = slot - 1
    elseif direction == "right" then
      self.partyFocusSlot = math.min(Party.MAX, slot + 1)
    elseif direction == "up" then
      local column = math.floor((slot - 1) * math.max(0, spec.columns - 1)
        / math.max(1, Party.MAX - 1) + .5)
      local rows = math.ceil(spec.slots / spec.columns)
      self.focusZone = "box"
      self.boxFocusSlot = math.min(spec.slots,
        (rows - 1) * spec.columns + column + 1)
    end
  else
    local slot, columns = self.boxFocusSlot, spec.columns
    local row, column = math.floor((slot - 1) / columns), (slot - 1) % columns
    local rows = math.ceil(spec.slots / columns)
    if direction == "right" and slot == spec.slots then
      self.focusZone, self.partyFocusSlot = "party", 1
    elseif direction == "down" and row == rows - 1 then
      self.focusZone = "party"
      self.partyFocusSlot = math.floor(column * math.max(0, Party.MAX - 1)
        / math.max(1, columns - 1) + .5) + 1
    else
      if direction == "left" then column = (column - 1) % columns
      elseif direction == "right" then column = (column + 1) % columns
      elseif direction == "up" then row = (row - 1) % rows
      elseif direction == "down" then row = (row + 1) % rows end
      self.boxFocusSlot = math.min(spec.slots, row * columns + column + 1)
    end
  end
  return self:result(envelope, "applied", "focus_changed")
end

local function firstFreeBoxSlot(box, boxIndex)
  local used = {}
  for _, mon in ipairs(box or {}) do
    local slot = mon[BOX_META_KEY] == boxIndex
      and validBoxSeat(mon[SLOT_META_KEY]) or nil
    if slot then used[slot] = true end
  end
  return firstFreeSeat(used)
end

function PcSession:sourcePosition(binding, boxes, party)
  if not binding or type(binding.mon) ~= "table" then return nil end
  local list = binding.zone == "party" and party
    or binding.zone == "box" and boxes[binding.box] or nil
  if not list then return nil end
  for dense, mon in ipairs(list) do
    if mon == binding.mon then
      if binding.zone == "party" and dense ~= binding.slot then return nil end
      if binding.zone == "box" and (mon[BOX_META_KEY] ~= binding.box
          or mon[SLOT_META_KEY] ~= binding.slot) then return nil end
      return list, dense
    end
  end
end

function PcSession:move(envelope, forcedDestination)
  local source = self:locate(envelope.target)
  local destination = forcedDestination or envelope.destination
  if not source or not source.mon or type(destination) ~= "table"
      or (destination.zone ~= "box" and destination.zone ~= "party") then
    return self:reject(envelope, "stale_target")
  end

  local boxes = ensureSpatialBoxes(self.game.save)
  local party = self.game.save.party
  local sourceList, sourceDense = self:sourcePosition(source, boxes, party)
  if not sourceList then return self:reject(envelope, "stale_target") end

  local targetBox = destination.zone == "box"
    and (tonumber(destination.box) or tonumber(self.game.save.currentBox)) or nil
  local targetSlot = tonumber(destination.slot)
  local targetLimit = destination.zone == "box" and Boxes.CAPACITY or Party.MAX
  if targetSlot ~= math.floor(targetSlot or -1) or targetSlot < 1
      or targetSlot > targetLimit or (targetBox and (targetBox < 1
        or targetBox > Boxes.COUNT or targetBox ~= math.floor(targetBox))) then
    return self:reject(envelope, "destination_invalid")
  end
  local targetList = destination.zone == "box" and boxes[targetBox] or party
  local targetMon, targetDense
  if destination.zone == "box" then
    targetMon, targetDense = monAtBox(targetList, targetBox, targetSlot)
  else
    targetMon, targetDense = targetList[targetSlot], targetSlot
  end

  local sameContainer = source.zone == destination.zone
    and (source.zone == "party" or source.box == targetBox)
  local sameSeat = sameContainer and source.slot == targetSlot
  if sameSeat then return self:reject(envelope, "same_slot") end

  -- Every guard is evaluated before the first authoritative write. A stale
  -- source, capacity failure or last-party refusal therefore cannot leave a
  -- partial move behind.
  if not targetMon then
    if destination.zone == "party" and #party >= Party.MAX then
      return self:reject(envelope, "party_full")
    end
    if destination.zone == "box" and #targetList >= Boxes.CAPACITY then
      return self:reject(envelope, "box_full")
    end
    if source.zone == "party" and destination.zone ~= "party"
        and #party <= 1 then
      return self:reject(envelope, "last_party_mon")
    end
  end

  if sameContainer then
    if targetMon then
      if source.zone == "box" then
        source.mon[SLOT_META_KEY], targetMon[SLOT_META_KEY] =
          targetSlot, source.slot
        normalizeBox(sourceList, source.box, {})
      else
        sourceList[sourceDense], sourceList[targetDense] =
          targetMon, source.mon
        clearBoxSeat(sourceList[sourceDense])
        clearBoxSeat(sourceList[targetDense])
      end
    elseif source.zone == "box" then
      source.mon[SLOT_META_KEY] = targetSlot
      normalizeBox(sourceList, source.box, {})
    else
      local mon = table.remove(sourceList, sourceDense)
      table.insert(sourceList, math.min(targetSlot, #sourceList + 1), mon)
      clearBoxSeat(mon)
    end
  elseif targetMon then
    if source.zone == "box" then
      targetMon[BOX_META_KEY], targetMon[SLOT_META_KEY] = source.box, source.slot
    else
      clearBoxSeat(targetMon)
    end
    if destination.zone == "box" then
      source.mon[BOX_META_KEY], source.mon[SLOT_META_KEY] = targetBox, targetSlot
    else
      clearBoxSeat(source.mon)
    end
    sourceList[sourceDense], targetList[targetDense] = targetMon, source.mon
    if source.zone == "box" then normalizeBox(sourceList, source.box, {}) end
    if destination.zone == "box" then normalizeBox(targetList, targetBox, {}) end
  else
    table.remove(sourceList, sourceDense)
    if destination.zone == "box" then
      source.mon[BOX_META_KEY], source.mon[SLOT_META_KEY] = targetBox, targetSlot
      targetList[#targetList + 1] = source.mon
      normalizeBox(targetList, targetBox, {})
    else
      clearBoxSeat(source.mon)
      table.insert(targetList, math.min(targetSlot, #targetList + 1), source.mon)
    end
    if source.zone == "box" then normalizeBox(sourceList, source.box, {}) end
  end

  if source.zone == "party" and destination.zone == "box" then
    pcall(function()
      require("src.world.PikachuFollower")
        .modifyHappiness(self.game.save, "DEPOSITED", source.mon)
    end)
  end
  for _, mon in ipairs(party) do
    local def = self.game.data.pokemon and self.game.data.pokemon[mon.species]
    if def then pcall(Stats.ensure, def, mon) end
  end
  self.focusZone = destination.zone
  if destination.zone == "box" then
    self.game.save.currentBox, self.boxFocusSlot = targetBox, targetSlot
  else
    self.partyFocusSlot = math.max(1, math.min(targetSlot, math.max(1, #party)))
  end
  self.pendingRelease = nil
  return self:result(envelope, "applied", targetMon and "swapped" or "moved")
end

function PcSession:withdraw(envelope)
  local target = self:locate(envelope.target)
  local party = self.game.save.party
  if not target or target.zone ~= "box" then
    return self:reject(envelope, "stale_target")
  end
  if #party >= Party.MAX then return self:reject(envelope, "party_full") end
  return self:move(envelope, { zone="party", slot=#party + 1 })
end

function PcSession:deposit(envelope)
  local target = self:locate(envelope.target)
  local party = self.game.save.party
  local boxIndex = self.game.save.currentBox
  local box = ensureSpatialBoxes(self.game.save)[boxIndex]
  if not target or target.zone ~= "party" or party[target.slot] ~= target.mon then
    return self:reject(envelope, "stale_target")
  end
  if #party <= 1 then return self:reject(envelope, "last_party_mon") end
  if #box >= Boxes.CAPACITY then return self:reject(envelope, "box_full") end
  return self:move(envelope, {
    zone="box", box=boxIndex, slot=firstFreeBoxSlot(box, boxIndex),
  })
end

function PcSession:release(envelope)
  local target = self:locate(envelope.target)
  local boxes = ensureSpatialBoxes(self.game.save)
  local box = target and target.box and boxes[target.box] or nil
  local live, dense
  if box then live, dense = monAtBox(box, target.box, target.slot) end
  if not target or target.zone ~= "box" or not dense
      or live ~= target.mon or box[dense] ~= target.mon then
    return self:reject(envelope, "stale_target")
  end
  local pending = self.pendingRelease
  if not envelope.confirmationToken then
    local token = self.id .. ":release:" .. self.revision .. ":" .. target.id
    self.pendingRelease = { token=token, target=target.id,
      revision=self.revision }
    return self:result(envelope, "confirmation_required", "confirm_release", {
      confirmation={ token=token,
        prompt=(locale() == "de" and "%s freilassen?" or "Release %s?")
          :format(target.mon.nickname or tostring(target.mon.species)),
        default="no" },
    })
  end
  if not pending or pending.token ~= envelope.confirmationToken
      or pending.target ~= target.id or pending.revision ~= self.revision then
    return self:reject(envelope, "stale_confirmation")
  end
  self.pendingRelease = nil
  table.remove(box, dense)
  normalizeBox(box, target.box, {})
  self.boxFocusSlot = math.max(1, math.min(target.slot, Boxes.CAPACITY))
  return self:result(envelope, "applied", "released")
end

function PcSession:changeBox(envelope)
  if envelope.boxIndex < 1 or envelope.boxIndex > Boxes.COUNT then
    return self:reject(envelope, "box_invalid")
  end
  ensureSpatialBoxes(self.game.save)
  self.game.save.currentBox = envelope.boxIndex
  -- Paging is a promptless view change, including while a Pokemon is being
  -- carried. Keep both the active zone and the exact remembered Box seat so
  -- the new Box opens under the same cursor instead of jumping to slot one.
  self.pendingRelease = nil
  -- Deliberately promptless and no implicit disk write. This is the same live
  -- save object the ordinary Save command later persists.
  return self:result(envelope, "applied", "box_changed")
end

function PcSession:printBox(envelope)
  local okYellow, isYellow = pcall(GameVersion.isYellow)
  if not okYellow or not isYellow then return self:reject(envelope, "not_yellow") end
  return self:result(envelope, "applied", "print_requested")
end

function PcSession:cancel(envelope)
  self.screen.closeAfterInput = true
  return self:result(envelope, "closed", "closed")
end

function PcSession:actions()
  return {
    navigate=function(e) return self:navigate(e) end,
    inspect=function(e) return self:inspect(e) end,
    dex_entry=function(e) return self:dexEntry(e) end,
    move=function(e) return self:move(e) end,
    withdraw=function(e) return self:withdraw(e) end,
    deposit=function(e) return self:deposit(e) end,
    release=function(e) return self:release(e) end,
    change_box=function(e) return self:changeBox(e) end,
    print_box=function(e) return self:printBox(e) end,
    search=function(e) return self:search(e) end,
    search_locate=function(e) return self:locateSearch(e) end,
    cancel=function(e) return self:cancel(e) end,
  }
end

local BattleSession = setmetatable({}, { __index=BaseSession })
BattleSession.__index = BattleSession

function BattleSession.new(PokemonUi, handle, game, native, opts, screen)
  serial = serial + 1
  return setmetatable({
    PokemonUi=PokemonUi, handle=handle, game=game, native=native,
    opts=opts or {}, screen=screen, id="vasc-battle-party-" .. serial,
    revision=0, focusSlot=math.max(1, native.index or 1), bindings={},
  }, BattleSession)
end

function BattleSession:party()
  return self.opts.party or self.native.party or self.game.save.party or {}
end

function BattleSession:buildModel()
  local language = locale()
  local party = self:party()
  self.bindings = {}
  local entries = {}
  for slot, mon in ipairs(party) do
    local reason
    if tonumber(mon.hp) and mon.hp <= 0 then reason = "fainted" end
    entries[#entries + 1] = self:bindEntry("party", nil, slot, mon, {
      enabled=reason == nil, reason=reason,
    })
  end
  self.focusSlot = math.max(1, math.min(self.focusSlot, math.max(1, #party)))
  local focus = { zone="party", slot=self.focusSlot }
  for _, entry in ipairs(entries) do if entry.slot == self.focusSlot then focus.id=entry.id end end
  local target = focus.id and self.bindings[focus.id] or nil
  local targetEgg = target and pokemonDescriptor(self.game, target.mon).egg == true
  local selectable = target and target.mon
    and not targetEgg and (tonumber(target.mon.hp) == nil or target.mon.hp > 0)
  local forced = self.opts.forceSwitch == true
  return {
    schema=self.PokemonUi.MODEL_SCHEMA, apiVersion=self.PokemonUi.API_VERSION,
    host="vasc_gen1_native", hostGeneration=self.PokemonUi.HOST_GENERATION,
    surface="battle_party", session=self.id, revision=self.revision,
    locale=language, edition=edition(), mode="browse_party",
    title=forced and (language == "de" and "NÄCHSTES POKéMON WÄHLEN"
      or "CHOOSE NEXT POKéMON") or (language == "de" and "KAMPFTEAM"
      or "BATTLE TEAM"),
    help=forced and (language == "de" and "A: WÄHLEN" or "A: CHOOSE")
      or (language == "de" and "A: WÄHLEN  B: ZURÜCK"
        or "A: CHOOSE  B: BACK"),
    focus=focus, selection={ kind="single", ids={} },
    zones={ party={ label="PARTY", count=#entries,
      capacity=Party.MAX, entries=entries } },
    availability={
      navigate=self:availability(#entries > 0),
      inspect=self:availability(target ~= nil and not targetEgg,
        targetEgg and "egg_hidden" or nil),
      select=self:availability(selectable, selectable and nil or "cannot_switch"),
      cancel=self:availability(not forced, forced and "forced_switch" or nil),
    },
    surfaceData={ title="BATTLE TEAM", forcedSwitch=forced,
      canCancel=not forced, reason=forced and "forced_switch" or "battle" },
  }
end

function BattleSession:navigate(envelope)
  local n = math.max(1, #self:party())
  local step = (envelope.direction == "left" or envelope.direction == "up")
    and -1 or 1
  self.focusSlot = ((self.focusSlot + step - 1) % n) + 1
  self.native.index = self.focusSlot
  return self:result(envelope, "applied", "focus_changed")
end

-- Gen1Recomp 0.2.56 deliberately keeps the native battle PartyMenu alive
-- while its callback validates the selected monster.  ASC BOX decorates that
-- same native object, but independent Host-v1 providers render HostScreen
-- instead.  Temporarily translate the native menu's two lifecycle callbacks
-- into an action result so the engine callback remains the sole authority:
-- refuse keeps this provider open, close tears it down after the action.
function BattleSession:keepOpenSwitch(mon)
  local callback, native = self.opts.onSwitch, self.native
  if type(callback) ~= "function" or type(native) ~= "table" then
    return nil, nil
  end
  local ownClose, ownRefuse = rawget(native, "close"), rawget(native, "refuse")
  local closeRequested, refusal
  rawset(native, "close", function(menu)
    if menu == native then closeRequested = true end
  end)
  rawset(native, "refuse", function(menu, text)
    if menu == native then refusal = text end
  end)
  local ok, why = pcall(callback, mon, native)
  rawset(native, "close", ownClose)
  rawset(native, "refuse", ownRefuse)
  if not ok then error(why, 0) end
  return closeRequested, refusal
end

function BattleSession:select(envelope)
  local target = self:locate(envelope.target)
  local party = self:party()
  if not target or party[target.slot] ~= target.mon then
    return self:reject(envelope, "stale_target")
  end
  if tonumber(target.mon.hp) and target.mon.hp <= 0 then
    return self:reject(envelope, "cannot_switch", locale() == "de"
      and "Dieses Pokémon kann nicht kämpfen."
      or "That Pokemon cannot battle.")
  end
  if self.opts.keepOpen == true then
    local closeRequested, refusal = self:keepOpenSwitch(target.mon)
    if refusal ~= nil then
      return self:reject(envelope, "cannot_switch", tostring(refusal))
    end
    if not closeRequested then
      return self:result(envelope, "applied", "selection_pending")
    end
    self.screen.closeAfterInput = true
    return self:result(envelope, "closed", "selected")
  end
  self.screen.closeAfterInput = true
  self.screen.afterClose = function()
    if type(self.opts.onSwitch) == "function" then
      self.opts.onSwitch(target.mon, self.native)
    end
  end
  return self:result(envelope, "closed", "selected")
end

function BattleSession:cancel(envelope)
  if self.opts.forceSwitch then return self:reject(envelope, "forced_switch") end
  self.screen.closeAfterInput = true
  self.screen.afterClose = function()
    if type(self.opts.onCancel) == "function" then self.opts.onCancel() end
  end
  return self:result(envelope, "closed", "cancelled")
end

function BattleSession:actions()
  return {
    navigate=function(e) return self:navigate(e) end,
    inspect=function(e) return self:inspect(e) end,
    select=function(e) return self:select(e) end,
    cancel=function(e) return self:cancel(e) end,
  }
end

local HostScreen = {}
HostScreen.__index = HostScreen
HostScreen.isOpaque = true

-- Gen1Recomp 0.1.90 owns love.textinput directly but does not forward the
-- ordinary game path to Runtime's input.textinput hook. Keep a weak set of
-- concrete VASC hosts and bridge only the one that is both top-of-stack and
-- actively requesting IME input. Editors/importers and every non-VASC screen
-- continue through the exact callback that was installed before us.
local liveTextHosts = setmetatable({}, { __mode="k" })
local LOVE_TEXT_BRIDGE_KEY = "__vascPokemonUiTextInputBridgeV1"

local function globalTextHost()
  for host in pairs(liveTextHosts) do
    local stack = host.game and host.game.stack
    local top = stack and type(stack.top) == "function" and stack:top()
    if host.imeActive == true and top == host and not host.fallback
        and host.controller then return host end
  end
end

local function installLoveTextInputBridge()
  local loveApi = rawget(_G, "love")
  if type(loveApi) ~= "table" then return false, "love_unavailable" end
  local existing = rawget(loveApi, LOVE_TEXT_BRIDGE_KEY)
  if type(existing) == "table" and existing.owner == VASC_OWNER
      and loveApi.textinput == existing.textinput
      and loveApi.textedited == existing.textedited then
    return true, "already_installed"
  end
  -- A foreign bridge is a complete owner; do not layer or replace it.
  if existing ~= nil then return false, "foreign_text_bridge" end

  local previousTextInput = loveApi.textinput
  local previousTextEdited = loveApi.textedited
  local bridge = { owner=VASC_OWNER, schema="vasc.gen1.pc-text-input/v1" }
  bridge.textinput = function(value, ...)
    local host = globalTextHost()
    if host and type(host.textinput) == "function" then
      local ok, handled = pcall(host.textinput, host, value)
      if ok and handled == true then return true end
    end
    if type(previousTextInput) == "function" then
      return previousTextInput(value, ...)
    end
    return false
  end
  bridge.textedited = function(value, start, length, ...)
    local host = globalTextHost()
    if host and type(host.textedited) == "function" then
      local ok, handled = pcall(host.textedited, host, value, start, length)
      if ok and handled == true then return true end
    end
    if type(previousTextEdited) == "function" then
      return previousTextEdited(value, start, length, ...)
    end
    return false
  end
  bridge.previousTextInput = previousTextInput
  bridge.previousTextEdited = previousTextEdited

  -- Gen1Recomp 0.1.90 exposes a protected LÖVE proxy to mods.  Assigning a
  -- callback through that proxy raises "mods cannot assign love.textinput".
  -- The Runtime input hooks and HostScreen:onKeyPressed seam below remain
  -- valid in that environment, so a locked callback must only disable the
  -- optional IME bridge; it must never abort the complete PC/party host
  -- installation.  Keep installation transactional for engines that permit
  -- one callback but reject another.
  local inputAssigned, inputWhy = pcall(function()
    loveApi.textinput = bridge.textinput
  end)
  if not inputAssigned then
    return false, "love_textinput_locked:" .. tostring(inputWhy)
  end
  local editedAssigned, editedWhy = pcall(function()
    loveApi.textedited = bridge.textedited
  end)
  if not editedAssigned then
    pcall(function() loveApi.textinput = previousTextInput end)
    return false, "love_textedited_locked:" .. tostring(editedWhy)
  end
  local markerAssigned, markerWhy = pcall(function()
    loveApi[LOVE_TEXT_BRIDGE_KEY] = bridge
  end)
  if not markerAssigned then
    pcall(function() loveApi.textinput = previousTextInput end)
    pcall(function() loveApi.textedited = previousTextEdited end)
    return false, "love_text_bridge_marker_locked:" .. tostring(markerWhy)
  end
  return true
end

local INPUTS = { "up", "down", "left", "right", "a", "b", "start", "select" }

function HostScreen.new(native)
  return setmetatable({ native=native, game=native.game, imeActive=false }, HostScreen)
end

function HostScreen:activate(sessionState)
  self.hostState = sessionState
  local controller, receipt = sessionState.handle:begin({
    surface=sessionState.surface, session=sessionState.id,
    controllerGeneration=sessionState.PokemonUi.CONTROLLER_GENERATION,
    atomicLayer=true, model=sessionState:buildModel(),
    actions=sessionState:actions(),
    events=copy(sessionState.PokemonUi.REQUIREMENTS[sessionState.surface].events),
  })
  if not controller then self.fallback=true; self.fallbackReceipt=receipt; return false end
  self.controller, self.receipt = controller, receipt
  self.viewport = { width=receipt.viewport.width, height=receipt.viewport.height }
  -- The reviewed standalone 0.5.3 storage screen owns an opaque, paper-
  -- coloured frame.  The Host-v1 wrapper is the actual state on the stack,
  -- so the marker must live here rather than on its private drawing proxy.
  self.letterboxWhite = true
  self.__vascOrasStorage = sessionState.surface == "pc_box" and true or nil
  self.__pokemonUiHostV1={ owner=VASC_OWNER, surface=sessionState.surface }
  liveTextHosts[self] = true
  return true
end

function HostScreen:uiSize()
  if self.fallback and type(self.native.uiSize) == "function" then
    return self.native:uiSize()
  end
  if self.fallback then return 160, 144 end
  local viewport = self.viewport or { width=512, height=288 }
  return viewport.width, viewport.height
end

local function nativeFlag(self, name)
  local callback = self.native and self.native[name]
  if type(callback) ~= "function" then return false end
  local ok, value = pcall(callback, self.native)
  return ok and value == true
end

function HostScreen:drawsWidescreen()
  if self.fallback then return nativeFlag(self, "drawsWidescreen") end
  return true
end

-- Standalone 0.5.3's PC screen requests a 512x288 UI canvas, but does not
-- opt into battle FILL scaling or claim to be a wide battle.  Applying those
-- battle-only flags to PC storage changed its window scale/crop and made
-- unrelated modal states inherit battle layout behavior.
function HostScreen:wantsFillScale()
  if self.fallback then return nativeFlag(self, "wantsFillScale") end
  return self.hostState and self.hostState.surface == "battle_party"
end

function HostScreen:isWideBattleLayout()
  if self.fallback then return nativeFlag(self, "isWideBattleLayout") end
  return self.hostState and self.hostState.surface == "battle_party"
end

function HostScreen:sgbPalettes(...)
  if self.fallback then
    local callback = self.native and self.native.sgbPalettes
    if type(callback) == "function" then return callback(self.native, ...) end
    return nil
  end
  local width, height = self:uiSize()
  -- This is the exact standalone 0.5.3 true-colour contract.  Clearing a
  -- shader during draw is insufficient: Renderer:endFrame applies SGB zones
  -- afterwards and otherwise recolours the finished ORAS layer.
  return { { colors=false, x=0, y=0, w=width, h=height } }
end

function HostScreen:update(dt)
  if self.fallbackNext then
    self:disarmInput()
    self.fallbackNext, self.fallback = nil, true
    self.letterboxWhite = self.native and self.native.letterboxWhite == true
      and true or nil
  end
  if self.fallback then return self.native:update(dt) end
  local ok = self.controller:update(dt)
  if ok == false then self:disarmInput(); self.fallbackNext=true; return end
  self:syncKeyCapture()
  local pressed = {}
  for _, key in ipairs(INPUTS) do
    if self.game.input:wasPressed(key) then pressed[key] = true end
  end
  -- Shoulder/page aliases are optional and remain exclusive when present.
  if self.game.input:wasPressed("l") then pressed.page_prev = true end
  if self.game.input:wasPressed("r") then pressed.page_next = true end
  if next(pressed) then
    local handled = self.controller:handleInput({ pressed=pressed })
    self:syncKeyCapture()
    if handled == false and not self.controller:isActive() then self.fallbackNext=true end
  end
  if self.closeAfterInput then
    self.closeAfterInput = nil
    if self.game.stack:top() == self then self.game.stack:pop() end
    local after = self.afterClose
    self.afterClose = nil
    if after then after() end
  end
end

function HostScreen:textinput(value)
  if self.fallback or not self.controller then return false end
  local handled = self.controller:inputSeam("textinput", value) == true
  self:syncKeyCapture()
  return handled
end

function HostScreen:textedited(value, start, length)
  if self.fallback or not self.controller then return false end
  return self.controller:inputSeam("textedited", value, start, length) == true
end

function HostScreen:setKeyCapture(active)
  if active == true and not self.fallback and self.controller then
    self.onKeyPressed = function(screen, key)
      if screen.fallback or not screen.controller then return false end
      local handled = screen.controller:inputSeam("keypressed", key) == true
      screen:syncKeyCapture()
      return handled
    end
  else
    self.onKeyPressed = nil
  end
end

function HostScreen:syncKeyCapture()
  if self.fallback or not self.controller then
    self:setKeyCapture(false)
    self:setTextInput(false)
    return
  end
  local active = self.controller:isTextInputActive()
  self:setKeyCapture(active)
  self:setTextInput(active)
end

function HostScreen:setTextInput(active)
  active = active == true
  if active then installLoveTextInputBridge() end
  if self.imeActive == active then return end
  self.imeActive = active
  local keyboard = type(love) == "table" and love.keyboard or nil
  if keyboard and type(keyboard.setTextInput) == "function" then
    pcall(keyboard.setTextInput, active)
  end
end

function HostScreen:disarmInput()
  if self.controller then self.controller:inputSeam("endSearch", false) end
  self:setKeyCapture(false)
  self:setTextInput(false)
end

function HostScreen:pointerpressed(x, y)
  if self.fallback or not self.controller then return false end
  local handled = self.controller:inputSeam("pointerpressed", x, y) == true
  self:syncKeyCapture()
  return handled
end

function HostScreen:drawNative(...)
  local draw = self.native.drawWidescreen or self.native.draw
  if type(draw) == "function" then return draw(self.native, ...) end
end

function HostScreen:draw(...)
  if self.fallback then return self:drawNative(...) end
  local g = love.graphics
  if not (g and g.newCanvas and g.setCanvas and g.getCanvas) then
    self.fallbackNext = true
    return
  end
  local width, height = self:uiSize()
  if self.layer and type(self.layer.getDimensions) == "function" then
    local lw, lh = self.layer:getDimensions()
    if lw ~= width or lh ~= height then self.layer = nil end
  end
  if not self.layer then
    -- One logical UI pixel must be one canvas texel on Retina/mobile too.
    -- LÖVE otherwise inherits the window DPI and silently magnifies this
    -- intermediate layer before the engine's own integer presentation pass.
    local ok, layer = pcall(g.newCanvas, width, height, { dpiscale=1 })
    if not ok or not layer then self.fallbackNext=true; return end
    self.layer = layer
    if layer.setFilter then layer:setFilter("nearest", "nearest") end
  end
  local old = g.getCanvas()
  -- BoxMenu is normally entered while the cartridge renderer still owns a
  -- 160x144 palette shader and a scaled transform.  Canvases do not reset
  -- either state in LÖVE: inheriting them recolours the ORAS artwork into the
  -- current four-colour game palette and clips most of the 512x288 layer.
  -- Render providers in a clean, pixel-addressed graphics scope, then restore
  -- the host state before compositing the completed layer.
  g.push("all")
  g.setCanvas(self.layer)
  if type(g.origin) == "function" then g.origin() end
  if type(g.setShader) == "function" then g.setShader() end
  if type(g.setScissor) == "function" then g.setScissor() end
  if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
  g.clear(0, 0, 0, 0)
  local ok, complete = pcall(self.controller.draw, self.controller)
  g.pop()
  g.setCanvas(old)
  if not ok then error(complete, 0) end
  if complete ~= true then self.fallbackNext=true; return end
  -- The provider's true-colour result must also bypass every piece of the
  -- cartridge draw state during the final blit.  Game:draw has already
  -- selected a canvas matching uiSize(); inherited 160x144 transforms or
  -- scissors here only crop/overscale the completed 512x288 layer.
  g.push("all")
  if not self.__vascMobileHudDrawing and type(g.origin) == "function" then
    g.origin()
  end
  if type(g.setShader) == "function" then g.setShader() end
  if type(g.setScissor) == "function" then g.setScissor() end
  if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
  g.setColor(1, 1, 1, 1)
  g.draw(self.layer, 0, 0)
  g.pop()
end
HostScreen.drawWidescreen = HostScreen.draw

function HostScreen:exit()
  self:disarmInput()
  liveTextHosts[self] = nil
  if self.controller then self.controller:close("host-screen-exit") end
  if type(self.native.exit) == "function" then self.native:exit() end
end

local function externalHostPresent(PokemonUi, surface)
  for _, host in ipairs(PokemonUi.listHosts(surface)) do
    if host.owner ~= VASC_OWNER then return true end
  end
  return false
end

local function warn(message, ...)
  local logger = V.mod and V.mod.log
  if logger and type(logger.warn) == "function" then
    pcall(logger.warn, logger, message, ...)
  end
end

local function mobileHostPresentation(screen, surface)
  if type(screen) ~= "table" or screen.fallback
      or type(MobileMenuPresentation) ~= "table"
      or type(MobileMenuPresentation.attach) ~= "function" then
    return screen
  end
  MobileMenuPresentation.attach(screen, {
    owner=surface == "battle_party" and "battle_team" or "box_pc",
    logicalSize=function(self) return self:uiSize() end,
    enabled=function(self) return self.fallback ~= true end,
    backdrop=surface == "battle_party"
      and { 5/255, 24/255, 61/255, 1 }
      or { 1, 252/255, 236/255, 1 },
  })
  return screen
end

local STORAGE_SCREEN_IDS = {
  BoxMenu=true, PcMenu=true, CenterPcMenu=true,
}
local STORAGE_PROVIDER_MARKERS = {
  "__ascendantFireRedWideOrganizer",
  "__ascendantFireRedWideGrid",
  "__ascendantFireRedWideBoxRoot",
  "__ascendantFireRedBoxRoot",
  "__ascendantBoxSwitchLegend",
  "__ascendantModernStorage",
}

local function storagePresentationState(state)
  if type(state) ~= "table" then return false end
  if STORAGE_SCREEN_IDS[tostring(state.screenId or state.id or "")] then
    return true
  end
  for _, marker in ipairs(STORAGE_PROVIDER_MARKERS) do
    if rawget(state, marker) then return true end
  end
  return false
end

local function mobileStoragePresentation(state)
  if not storagePresentationState(state)
      or type(MobileMenuPresentation) ~= "table"
      or type(MobileMenuPresentation.attach) ~= "function" then
    return state, false, "not_storage_state"
  end
  return MobileMenuPresentation.attach(state, {
    owner="box_pc",
    logicalSize=function(screen)
      if type(screen.uiSize) == "function" then
        local ok, width, height = pcall(screen.uiSize, screen)
        if ok and tonumber(width) and tonumber(height)
            and width > 0 and height > 0 then return width, height end
      end
      return 160, 144
    end,
    backdrop={ 1, 252/255, 236/255, 1 },
  })
end

local function activePokemonUiHost(game)
  local stack = game and game.stack
  local top = stack and type(stack.top) == "function" and stack:top()
  if top and top.__pokemonUiHostV1 then return top end
end

local function installRawInputHooks()
  -- Install immediately when the app callback already exists, and retry from
  -- HostScreen:setTextInput when mods loaded before LÖVE assigned callbacks.
  installLoveTextInputBridge()
  local hooks = V.mod and V.mod.hooks
  if type(hooks) ~= "table" or type(hooks.wrap) ~= "function" then return end
  Hosts.rawInputUnregister = {
    hooks:wrap("input.textinput", function(nextInput, game, value)
      local downstream = nextInput(game, value)
      if downstream == true then return true end
      local host = activePokemonUiHost(game)
      if not (host and host.imeActive == true
          and type(host.textinput) == "function") then return false end
      local ok, handled = pcall(host.textinput, host, value)
      return ok and handled == true
    end, 15154),
    hooks:wrap("input.textedited", function(nextInput, game, value, start, length)
      local downstream = nextInput(game, value, start, length)
      if downstream == true then return true end
      local host = activePokemonUiHost(game)
      if not (host and host.imeActive == true
          and type(host.textedited) == "function") then return false end
      local ok, handled = pcall(host.textedited, host, value, start, length)
      return ok and handled == true
    end, 15154),
    hooks:wrap("input.focus", function(nextInput, game, active)
      local downstream = nextInput(game, active)
      if active == false then
        local host = activePokemonUiHost(game)
        if host and type(host.disarmInput) == "function" then
          pcall(host.disarmInput, host)
        end
      end
      return downstream
    end, 15154),
  }
end

function Hosts.install(PokemonUi)
  if Hosts.installed then return true end
  local handle, why = PokemonUi.registerHost({
    schema=PokemonUi.HOST_SCHEMA, apiVersion=PokemonUi.API_VERSION,
    id="vasc_gen1_native", owner=VASC_OWNER,
    hostGeneration=PokemonUi.HOST_GENERATION,
    surfaces={
      pc_box=hostSurface(PokemonUi, "pc_box"),
      battle_party=hostSurface(PokemonUi, "battle_party"),
    },
  })
  if not handle then return nil, why end
  Hosts.handle = handle
  installRawInputHooks()

  local BoxMenu = require("src.ui.BoxMenu")
  if type(BoxMenu.new) == "function" and not BoxMenu.__vascPokemonUiHostV1 then
    BoxMenu.__vascPokemonUiHostV1 = true
    local baseNew = BoxMenu.new
    BoxMenu.new = function(game, ...)
      local native = baseNew(game, ...)
      if externalHostPresent(PokemonUi, "pc_box")
          or PokemonUi.resolve("pc_box", handle).effective == PokemonUi.GAME_DEFAULT then
        mobileStoragePresentation(native)
        return native
      end
      local screen = HostScreen.new(native)
      local state = PcSession.new(PokemonUi, handle, game, native, screen)
      state.surface = "pc_box"
      return screen:activate(state)
        and mobileHostPresentation(screen, state.surface) or native
    end
  end

  -- Registry-provided/native PC states can be finalized outside BoxMenu.new.
  -- This exact pushed-state boundary captures their completed renderer only;
  -- it never admits a generic Menu/ListMenu shape.
  local events = V.mod and V.mod.events
  if events and type(events.on) == "function"
      and not V.mod.__vascMobileStoragePresentationWatcher then
    local ok = pcall(events.on, events, "screen.pushed", function(event)
      mobileStoragePresentation(type(event) == "table" and event.state or nil)
    end, 15150)
    if ok then V.mod.__vascMobileStoragePresentationWatcher = true end
  end

  local PartyMenu = require("src.ui.PartyMenu")
  if type(PartyMenu.new) == "function" and not PartyMenu.__vascPokemonUiHostV1 then
    PartyMenu.__vascPokemonUiHostV1 = true
    local baseNew = PartyMenu.new
    PartyMenu.new = function(game, opts, ...)
      opts = opts or {}
      local native = baseNew(game, opts, ...)
      local battlePicker = type(opts.onSwitch) == "function"
        and (opts.battle ~= nil or opts.forceSwitch == true)
        and not opts.pickOnly and not opts.tmhm
      if not battlePicker or externalHostPresent(PokemonUi, "battle_party") then
        return native
      end
      local resolved = PokemonUi.resolve("battle_party", handle)
      if resolved.effective == PokemonUi.GAME_DEFAULT then return native end

      -- ASC BOX's reviewed 0.5.3 team view is a presentation adapter for the
      -- real PartyMenu, not a second switch implementation. Host-v1 still
      -- resolves the requested surface/provider, while the engine remains the
      -- sole owner of forced/voluntary validation, pop order and callbacks.
      if resolved.effective == "asc_box" then
        local presented, decorated, reason =
          PartyMenuSkins.decorateBattle(native, opts)
        if decorated then return presented end
        warn("ASC BOX battle PartyMenu failed open: %s", tostring(reason))
        return native
      end

      local screen = HostScreen.new(native)
      local state = BattleSession.new(PokemonUi, handle, game, native, opts, screen)
      state.surface = "battle_party"
      return screen:activate(state)
        and mobileHostPresentation(screen, state.surface) or native
    end
  end

  Hosts.installed = true
  return true
end

Hosts.HostScreen = HostScreen
Hosts.PcSession = PcSession
Hosts.BattleSession = BattleSession
Hosts.BOX_META_KEY = BOX_META_KEY
Hosts.SLOT_META_KEY = SLOT_META_KEY
Hosts.ensureSpatialBoxes = ensureSpatialBoxes
Hosts.mobileStoragePresentation = mobileStoragePresentation
Hosts.storagePresentationState = storagePresentationState
-- Narrow QA seam: verifies that protected engine callback proxies fail open
-- without needing to construct a second complete Host-v1 installation.
Hosts.installLoveTextInputBridgeForQa = installLoveTextInputBridge

return Hosts
