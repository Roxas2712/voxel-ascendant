-- Resolver for the validated transparent Pokemon #001-251 3x4 atlas handoff.

local PokemonWalksheets = {}
PokemonWalksheets.__index = PokemonWalksheets
PokemonWalksheets.SCHEMA = "ascendant.pokemon-walksheets/v1"

local CONTEXT_SOURCE_OPTION = {
  follower="follower_sprite_source",
  grass="grass_pokemon_sprite_source",
  city="city_pokemon_sprite_source",
  wilds_town="wilds_town_pokemon_sprite_source",
}

-- These delivered GO cards are kept in the source/archive for diagnosis, but
-- must never become a live renderer.  Cyndaquil's supplied card has no flame
-- layer: one delivery shows a flat white patch, the other a flat yellow patch.
-- The animated PokeMMO sheet is the safe visual fallback until a verified GO
-- export with real flames is available.
local INVALID_GO_ASSET_REASON = {
  [155]="cyndaquil_flame_layer_missing",
}

local function invalidGoAssetReason(record)
  if type(record) == "table" and type(record.flameCards) == "table"
      and record.flameCards.verified == true then return nil end
  return type(record) == "table" and INVALID_GO_ASSET_REASON[record.dex]
    or nil
end

local function split(line, separator)
  local result = {}
  for value in (line .. separator):gmatch("(.-)" .. separator) do
    result[#result + 1] = value
  end
  return result
end

local function animationMotionColumns(record)
  if not record.animationCards then return { "idle", "step-a", "step-b" } end
  local cards = record.animationCards
  local count = type(cards) == "table" and type(cards.idle) == "table"
    and cards.idle.columns == 16 and 16 or 8
  local result = {}
  for column = 0, count - 1 do result[#result+1] = tostring(column) end
  return result
end

local function gender(mon)
  if type(mon) ~= "table" then return "none" end
  if mon.isFemale == true then return "female" end
  if mon.isMale == true then return "male" end
  local value = tostring(mon.gender or mon.sex or ""):lower()
  if value == "f" or value == "female" or value == "weiblich" then
    return "female"
  end
  if value == "m" or value == "male" or value == "maennlich"
      or value == "männlich" then return "male" end
  return "none"
end

local function optionValue(mod, key, fallback)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  return tostring(value)
end

local function normalizedForm(value)
  local form = value ~= nil and tostring(value) or "base"
  if form == "" or form == "0" or form:match("^0+$") then return "base" end
  return form
end

local function formKeys(mon)
  if type(mon) ~= "table" then return { "base" } end
  local value = mon.form or mon.formId or mon.variant or mon.unownForm
  if value == nil or value == "" or value == 0 then return { "base" } end
  local raw = tostring(value):lower():gsub("[^%w]+", "-")
  return { raw, raw:gsub("^0+", ""), "base" }
end

function PokemonWalksheets.new(options)
  local self = setmetatable({
    mod=assert(options.mod), catalog=assert(options.catalog),
    scaleProfiles=options.scaleProfiles, byDex={},
    legacyByDex={}, legacyCount=0, legacySpeciesCount=0,
    byRuntime={}, pokemmoByDex={}, pokemmoCount=0,
    idleEvents={}, flameCards={}, flameCardErrors={}, flameCardRecords={},
    animationCards={}, animationCardErrors={}, animationCardRecords={},
    count=0, speciesCount=0, extendedSpeciesCount=0, lastError=nil,
  }, PokemonWalksheets)
  local body, err = self.mod:read("production/pokemon-walksheet-runtime.tsv")
  if type(body) ~= "string" then
    self.lastError = err or "pokemon_walksheet_manifest_missing"
    return self
  end
  local seenDex, first = {}, true
  for line in body:gmatch("[^\r\n]+") do
    if first then first = false else
      local field = split(line, "\t")
      local dex = tonumber(field[1])
      if dex and field[4] and field[5] and field[6] and field[7] then
        self.byDex[dex] = self.byDex[dex] or {}
        local form = normalizedForm(field[3])
        self.byDex[dex][form] = self.byDex[dex][form] or {}
        self.byDex[dex][form][field[4]] = self.byDex[dex][form][field[4]] or {}
        local speciesClass = self.scaleProfiles and self.scaleProfiles.species
          and self.scaleProfiles.species[dex] or nil
        local record = {
          dex=dex, species=field[2], form=form, gender=field[4],
          palette=field[5], atlas=field[6], runtime=field[7],
          scaleClass=speciesClass or field[8], heightDm=tonumber(field[9]),
          runtimeContentWidth=tonumber(field[12]) or 16,
          runtimeContentHeight=tonumber(field[13]) or 16,
          motionProfile=field[16] ~= "" and field[16] or nil,
          source="pokemon_go_549", sourceTier="extended_549",
        }
        self.byDex[dex][form][field[4]][field[5]] = record
        self.byRuntime[record.runtime] = record
        self.byRuntime[self.mod.path .. "/" .. record.runtime] = record
        self.count = self.count + 1
        seenDex[dex] = true
      end
    end
  end
  for _ in pairs(seenDex) do self.speciesCount = self.speciesCount + 1 end
  self.extendedSpeciesCount = self.speciesCount
  if self.speciesCount < 251 then self.lastError = "incomplete_dex_coverage" end

  -- The original #001-251 delivery has the intended, colour-accurate GO
  -- lighting and ships at a larger runtime cell size than the expansion
  -- delivery. Keep both immutable source sets: prefer this legacy atlas when
  -- it has the requested form/palette, then use the 549 expansion for missing
  -- variants and later generations. Motion metadata is materialized in the
  -- legacy index (with expansion inheritance as a compatibility fallback),
  -- so release filtering cannot remove flying/crawling locomotion profiles.
  local legacy = self.mod:read("production/pokemon-walksheet-legacy-runtime.tsv")
  if type(legacy) == "string" then
    local seenLegacyDex, header = {}, true
    for line in legacy:gmatch("[^\r\n]+") do
      if header then header = false else
        local field = split(line, "\t")
        local dex, form = tonumber(field[1]), normalizedForm(field[3])
        if dex and field[4] and field[5] and field[6] and field[7] then
          local extendedForms = self.byDex[dex] or {}
          local extendedVariants = extendedForms[form]
            or extendedForms.base or {}
          local extended = (extendedVariants[field[4]]
              and extendedVariants[field[4]][field[5]])
            or (extendedVariants.none
              and extendedVariants.none[field[5]])
            or (extendedVariants.none
              and extendedVariants.none.normal)
          local speciesClass = self.scaleProfiles and self.scaleProfiles.species
            and self.scaleProfiles.species[dex] or nil
          local record = {
            dex=dex, species=field[2], form=form, gender=field[4],
            palette=field[5], atlas=field[6], runtime=field[7],
            scaleClass=speciesClass or field[8], heightDm=tonumber(field[9]),
            runtimeContentWidth=tonumber(field[12]) or 16,
            runtimeContentHeight=tonumber(field[13]) or 16,
            motionProfile=(field[14] ~= "" and field[14])
              or (extended and extended.motionProfile) or nil,
            source="pokemon_go_legacy", sourceTier="legacy_251",
          }
          self.legacyByDex[dex] = self.legacyByDex[dex] or {}
          self.legacyByDex[dex][form] = self.legacyByDex[dex][form] or {}
          self.legacyByDex[dex][form][field[4]] =
            self.legacyByDex[dex][form][field[4]] or {}
          self.legacyByDex[dex][form][field[4]][field[5]] = record
          self.byRuntime[record.runtime] = record
          self.byRuntime[self.mod.path .. "/" .. record.runtime] = record
          self.legacyCount = self.legacyCount + 1
          seenLegacyDex[dex] = true
        end
      end
    end
    for _ in pairs(seenLegacyDex) do
      self.legacySpeciesCount = self.legacySpeciesCount + 1
    end
    if self.legacySpeciesCount < 251 then
      self.legacyLastError = "incomplete_legacy_dex_coverage"
    end
  else
    self.legacyLastError = "pokemon_walksheet_legacy_manifest_missing"
  end
  local coveredDex = {}
  for dex in pairs(self.byDex) do coveredDex[dex] = true end
  for dex in pairs(self.legacyByDex) do coveredDex[dex] = true end
  self.speciesCount = 0
  for _ in pairs(coveredDex) do self.speciesCount = self.speciesCount + 1 end
  local pokemmo = self.mod:read("production/pokemmo-follower-runtime.tsv")
  if type(pokemmo) == "string" then
    local header = true
    for line in pokemmo:gmatch("[^\r\n]+") do
      if header then header = false else
        local field = split(line, "\t")
        local dex = tonumber(field[1])
        if dex and field[2] and field[3] and field[4]
            and field[5] and field[6] then
          local form = field[4] ~= "" and field[4] or "base"
          self.pokemmoByDex[dex] = self.pokemmoByDex[dex] or {}
          self.pokemmoByDex[dex][form] = self.pokemmoByDex[dex][form] or {}
          self.pokemmoByDex[dex][form][field[2]] =
            self.pokemmoByDex[dex][form][field[2]] or {}
          local record = {
            dex=dex, form=form, gender=field[2], palette=field[3],
            atlas=field[5], runtime=field[6],
            runtimeContentWidth=tonumber(field[7]) or 16,
            runtimeContentHeight=tonumber(field[8]) or 16,
            source="pokemmo",
          }
          self.pokemmoByDex[dex][form][field[2]][field[3]] = record
          self.byRuntime[record.runtime] = record
          self.byRuntime[self.mod.path .. "/" .. record.runtime] = record
          self.pokemmoCount = self.pokemmoCount + 1
        end
      end
    end
  end
  if type(self.mod:read("assets/pokemon-idle-events-549/manifest.json"))
      == "string" then
    self.idleEventManifest = self.mod.path
      .. "/assets/pokemon-idle-events-549/manifest.json"
    self.idleEventRoot = self.mod.path .. "/assets/pokemon-idle-events-549"
  end
  local idleRuntime = self.mod:read("production/pokemon-idle-event-runtime.tsv")
  if type(idleRuntime) == "string" then
    local header = true
    for line in idleRuntime:gmatch("[^\r\n]+") do
      if header then header = false else
        local field = split(line, "\t")
        local dex = tonumber(field[1])
        if dex and field[2] and field[3] then
          self.idleEvents[dex] = self.idleEvents[dex] or {}
          self.idleEvents[dex][field[2]] = {
            sheet=self.mod.path .. "/" .. field[3], sha256=field[4],
            sourceAuthority=field[5], sourceExact=true,
          }
        end
      end
    end
  end
  self:_loadFlameCards()
  self:_loadAnimationCards()
  return self
end

-- Repairs are additive, variant-specific assets. The original handoff and
-- its quarantine stay intact if either state or the native strip is absent.
-- A release-time receipt binds the images; this startup check also prevents
-- truncated/mis-sized or missing paired atlases from enabling a repair.
local function pngDimensions(body)
  if type(body) ~= "string" or body:sub(1, 8) ~= "\137PNG\r\n\26\n"
      or body:sub(13, 16) ~= "IHDR" or #body < 33 then return nil end
  local function uint32(offset)
    local a,b,c,d = body:byte(offset, offset+3)
    return ((a*256+b)*256+c)*256+d
  end
  return uint32(17), uint32(21)
end

local function assetPath(value)
  return type(value) == "string" and value:match("^assets/[%w_./%-]+$")
    and not value:find("..", 1, true) and value:match("%.png$")
end

function PokemonWalksheets:_loadFlameCards()
  local body = self.mod:read("production/pokemon-flame-cards-runtime.tsv")
  if type(body) ~= "string" then return end
  local first = true
  for line in body:gmatch("[^\r\n]+") do
    if first then first = false else
      local f = split(line, "\t")
      local dex = tonumber(f[1])
      local layout = { cellWidth=tonumber(f[10]), cellHeight=tonumber(f[11]),
        left=tonumber(f[12]), top=tonumber(f[13]), right=tonumber(f[14]),
        bottom=tonumber(f[15]), anchorX=tonumber(f[16]),
        anchorY=tonumber(f[17]), referenceHeight=tonumber(f[18]) }
      local valid = dex and f[25] == "verified-render"
        and (f[5] == "normal" or f[5] == "shiny")
        and assetPath(f[6]) and assetPath(f[7]) and assetPath(f[8])
        and f[6] ~= f[7] and f[9] ~= ""
      for _, key in ipairs({ "cellWidth", "cellHeight", "left", "top",
          "right", "bottom", "anchorX", "anchorY", "referenceHeight" }) do
        local value = layout[key]
        if not value or value ~= value or math.abs(value) == math.huge then
          valid = false
        end
      end
      if valid then
        valid = layout.cellWidth > 0 and layout.cellHeight > 0
          and layout.left >= 0 and layout.top >= 0
          and layout.right > layout.left and layout.bottom > layout.top
          and layout.right <= layout.cellWidth
          and layout.bottom <= layout.cellHeight
          and layout.anchorX >= 0 and layout.anchorX <= layout.cellWidth
          and layout.anchorY >= 0 and layout.anchorY <= layout.cellHeight
          and layout.referenceHeight > 0
        for _, index in ipairs({ 6, 7, 8 }) do
          local w,h = pngDimensions(self.mod:read(f[index]))
          local expectedW = index == 8 and 16 or layout.cellWidth*3
          local expectedH = index == 8 and 96 or layout.cellHeight*4
          if w ~= expectedW or h ~= expectedH then valid = false end
        end
      end
      if valid then
        local key = table.concat({dex,normalizedForm(f[3]),f[4],f[5]}, ":")
        self.flameCards[key] = {
          id=f[9], onSheet=self.mod.path .. "/" .. f[6],
          offSheet=self.mod.path .. "/" .. f[7], verified=true, layout=layout,
          onRelative=f[6], offRelative=f[7], runtimeRelative=f[8],
          runtimeContentWidth=tonumber(f[19]) or 16,
          runtimeContentHeight=tonumber(f[20]) or 16,
          onSha256=f[21], offSha256=f[22], runtimeSha256=f[23],
          sourceReceipt=f[24],
        }
      else
        self.flameCardErrors[#self.flameCardErrors+1] =
          "flame_card_pair_unverified:" .. tostring(dex or f[1])
      end
    end
  end
end

function PokemonWalksheets:_withFlameCards(record)
  local key = table.concat({record.dex,record.form,record.gender,record.palette}, ":")
  local cards = self.flameCards[key]
  if not cards then return record end
  if not self.flameCardRecords[record] then
    local repaired = {}
    for name,value in pairs(record) do repaired[name] = value end
    repaired.atlas, repaired.runtime = cards.onRelative, cards.runtimeRelative
    repaired.runtimeContentWidth = cards.runtimeContentWidth
    repaired.runtimeContentHeight = cards.runtimeContentHeight
    repaired.flameCards = cards
    self.flameCardRecords[record] = repaired
    self.byRuntime[repaired.runtime] = repaired
    self.byRuntime[self.mod.path .. "/" .. repaired.runtime] = repaired
  end
  return self.flameCardRecords[record]
end

-- Multi-frame repairs are optional and variant-specific. Neither a requested
-- source preference nor a neighbouring form/palette authorises a different
-- model's repair. The original atlas remains a safe load-time fallback.
function PokemonWalksheets:_loadAnimationCards()
  local body = self.mod:read("production/pokemon-animation-cards-runtime.tsv")
  if type(body) ~= "string" then return end
  local first = true
  for line in body:gmatch("[^\r\n]+") do
    if first then first = false else
      local f = split(line, "\t")
      local dex, idleDuration, walkDuration = tonumber(f[1]), tonumber(f[11]), tonumber(f[13])
      local idleColumns, walkColumns = tonumber(f[10]), tonumber(f[12])
      -- Only the two explicitly reviewed original bat-flight source pairs
      -- use the denser sampling; unrelated species remain eight-column.
      local denseTag = dex == 41 and "original-zubat-flight-16-v1"
        or dex == 42 and "original-golbat-flight-16-default-v1"
      local sourceDensity = denseTag and idleColumns == 16 and walkColumns == 16
        and normalizedForm(f[3]) == "base" and f[4] == "none"
        and denseTag or nil
      local layout = {cellWidth=tonumber(f[14]),cellHeight=tonumber(f[15]),
        left=tonumber(f[16]),top=tonumber(f[17]),right=tonumber(f[18]),
        bottom=tonumber(f[19]),anchorX=tonumber(f[20]),anchorY=tonumber(f[21]),
        referenceHeight=tonumber(f[22])}
      local function finite(n)
        return type(n) == "number" and n == n and math.abs(n) < math.huge
      end
      local valid = #f == 29 and finite(dex) and dex >= 1 and dex == math.floor(dex)
        and f[29] == "verified-render" and type(f[9]) == "string" and f[9] ~= ""
        and (f[5] == "normal" or f[5] == "shiny")
        and (f[4] == "none" or f[4] == "male" or f[4] == "female")
        and assetPath(f[6]) and assetPath(f[7]) and assetPath(f[8]) and f[6] ~= f[7]
        and ((idleColumns == 8 and walkColumns == 8) or sourceDensity ~= nil)
        and finite(idleDuration) and idleDuration > 0
        and finite(walkDuration) and walkDuration > 0
      for name, value in pairs(layout) do
        if not finite(value) then valid = false end
        if name ~= "anchorX" and name ~= "anchorY" and name ~= "referenceHeight"
            and finite(value) and value ~= math.floor(value) then valid = false end
      end
      -- Missing fields are absent from pairs(), and therefore checked explicitly.
      for _, name in ipairs({ "cellWidth", "cellHeight", "left", "top", "right",
          "bottom", "anchorX", "anchorY", "referenceHeight" }) do
        if not finite(layout[name]) then valid = false end
      end
      local contentW, contentH = tonumber(f[23]), tonumber(f[24])
      if not finite(contentW) or not finite(contentH) or contentW <= 0 or contentW > 16
          or contentH <= 0 or contentH > 16 then valid = false end
      if valid then
        valid = layout.cellWidth > 0 and layout.cellHeight > 0
          and layout.left >= 0 and layout.top >= 0
          and layout.right > layout.left and layout.bottom > layout.top
          and layout.right <= layout.cellWidth and layout.bottom <= layout.cellHeight
          and layout.anchorX >= 0 and layout.anchorX <= layout.cellWidth
          and layout.anchorY >= 0 and layout.anchorY <= layout.cellHeight * 2
          and layout.referenceHeight > 0
      end
      if valid then
        local key = table.concat({dex,normalizedForm(f[3]),f[4],f[5]}, ":")
        if self.animationCards[key] ~= nil then
          self.animationCards[key] = false
          self.animationCardErrors[#self.animationCardErrors+1] = "animation_card_duplicate:" .. key
        else
          self.animationCards[key] = {id=f[9],verified=false,layout=layout,
            sourceSampleDensity=sourceDensity,
            idle={sheet=self.mod.path.."/"..f[6],columns=idleColumns,duration=idleDuration},
            walk={sheet=self.mod.path.."/"..f[7],columns=walkColumns,duration=walkDuration},
            idleRelative=f[6],walkRelative=f[7],runtimeRelative=f[8],
            runtimeContentWidth=contentW,runtimeContentHeight=contentH,
            idleSha256=f[25],walkSha256=f[26],runtimeSha256=f[27],sourceReceipt=f[28]}
        end
      else
        self.animationCardErrors[#self.animationCardErrors+1] =
          "animation_card_pair_unverified:" .. tostring(dex or f[1])
      end
    end
  end
end

function PokemonWalksheets:_validateAnimationCards(cards)
  if cards.validationComplete then return cards.verified end
  -- Do not read hundreds of PNG pairs at mod startup. Verify dimensions once
  -- when a variant is requested; decoded texture/alpha checks remain lazy in
  -- the renderer. Full SHA/PNG integrity is checked by the release importer.
  local valid = true
  for _, relative in ipairs({cards.idleRelative,cards.walkRelative,cards.runtimeRelative}) do
    local w,h = pngDimensions(self.mod:read(relative))
    local native = relative == cards.runtimeRelative
    local columns = relative == cards.idleRelative and cards.idle.columns or cards.walk.columns
    if w ~= (native and 16 or cards.layout.cellWidth*columns)
        or h ~= (native and 96 or cards.layout.cellHeight*4) then valid = false end
  end
  cards.verified, cards.validationComplete = valid, true
  if not valid then
    self.animationCardErrors[#self.animationCardErrors+1] = "animation_cards_unavailable:" .. cards.id
  end
  return valid
end

function PokemonWalksheets:_withAnimationCards(record)
  if record.source == "pokemmo" or record.flameCards then return record end
  local cards = self.animationCards[table.concat({record.dex,record.form,
    record.gender,record.palette}, ":")]
  if not cards or not self:_validateAnimationCards(cards) then return record end
  if not self.animationCardRecords[record] then
    local repaired = {}
    for name,value in pairs(record) do repaired[name] = value end
    repaired.runtime = cards.runtimeRelative
    repaired.runtimeContentWidth, repaired.runtimeContentHeight =
      cards.runtimeContentWidth, cards.runtimeContentHeight
    repaired.animationCards = cards
    self.animationCardRecords[record] = repaired
    self.byRuntime[repaired.runtime] = repaired
    self.byRuntime[self.mod.path .. "/" .. repaired.runtime] = repaired
  end
  return self.animationCardRecords[record]
end

function PokemonWalksheets:fromPath(path)
  return type(path) == "string" and self.byRuntime[path] or nil
end

function PokemonWalksheets:resolve(game, mon)
  local dexForPresentation = self.catalog.presentationDexFor
    or self.catalog.dexFor
  local dex = dexForPresentation(game, mon)
  local extendedForms = dex and self.byDex[dex] or nil
  local legacyForms = dex and dex <= 251 and self.legacyByDex[dex] or nil
  if not extendedForms and not legacyForms then
    return nil, "pokemon_walksheet_unavailable"
  end
  local wantedGender = gender(mon)
  local wantedPalette = self.catalog.isShiny(mon) and "shiny" or "normal"
  local genders = { wantedGender, "none", "male", "female" }
  local palettes = wantedPalette == "shiny"
    and { "shiny", "normal" } or { "normal" }
  local checked = {}
  for _, form in ipairs(formKeys(mon)) do
    if not checked[form] then
      checked[form] = true
      for _, palette in ipairs(palettes) do
        -- A reviewed animated export outranks the older three-pose delivery.
        -- Preserve explicit gender variants when a neutral-tagged base export
        -- cannot prove it represents the requested dimorphic model.
        for _, forms in ipairs({extendedForms or {}, legacyForms or {}}) do
          local variants = forms[form]
          for _, candidateGender in ipairs(genders) do
            local candidate = variants and variants[candidateGender]
              and variants[candidateGender][palette]
            local originalGender = legacyForms and legacyForms[form]
              and legacyForms[form][wantedGender]
            local ambiguousGender = wantedGender ~= "none" and candidateGender ~= wantedGender
              and originalGender and originalGender[palette] ~= nil
            if candidate and not ambiguousGender then
              local repaired = self:_withAnimationCards(candidate)
              if repaired.animationCards then
                return repaired, nil, {requestedGender=wantedGender,
                  requestedPalette=wantedPalette,requestedForm=form,exactForm=repaired.form == form,
                  exactGender=repaired.gender == wantedGender or repaired.gender == "none",
                  exactPalette=repaired.palette == wantedPalette,
                  source=repaired.source,sourceTier=repaired.sourceTier}
              end
            end
          end
        end
        -- Source priority is evaluated inside each palette. A missing legacy
        -- shiny therefore selects the exact 549 shiny before ever falling
        -- back to legacy normal artwork.
        for _, source in ipairs({
          { id="legacy_251", forms=legacyForms },
          { id="extended_549", forms=extendedForms },
        }) do
          local variants = source.forms and source.forms[form] or nil
          for _, candidateGender in ipairs(genders) do
            local key = source.id .. ":" .. form .. ":"
              .. candidateGender .. ":" .. palette
            if variants and not checked[key] then
              checked[key] = true
              local record = variants[candidateGender]
                and variants[candidateGender][palette] or nil
              if record then
                record = self:_withAnimationCards(self:_withFlameCards(record))
                return record, nil, {
                  requestedGender=wantedGender,
                  requestedPalette=wantedPalette,
                  requestedForm=form, exactForm=record.form == form,
                  exactGender=record.gender == wantedGender
                    or record.gender == "none",
                  exactPalette=record.palette == wantedPalette,
                  source=record.source, sourceTier=record.sourceTier,
                }
              end
            end
          end
        end
      end
    end
  end
  return nil, "pokemon_walksheet_variant_unavailable"
end

function PokemonWalksheets:resolvePokeMMO(game, mon)
  local dex = self.catalog.dexFor(game, mon)
  local forms = dex and self.pokemmoByDex[dex] or nil
  if not forms then return nil, "pokemmo_follower_unavailable" end
  local wantedGender = gender(mon)
  local wantedPalette = self.catalog.isShiny(mon) and "shiny" or "normal"
  local genders = { wantedGender, "none", "male", "female" }
  local palettes = wantedPalette == "shiny"
    and { "shiny", "normal" } or { "normal" }
  local checked = {}
  for _, form in ipairs(formKeys(mon)) do
    local variants = forms[form]
    if variants and not checked[form] then
      checked[form] = true
      for _, palette in ipairs(palettes) do
        for _, candidateGender in ipairs(genders) do
          local record = variants[candidateGender]
            and variants[candidateGender][palette] or nil
          if record then
            local hd = self:resolve(game, mon)
            record.species = hd and hd.species or tostring(mon.species or "")
            record.scaleClass = hd and hd.scaleClass or "pokemon_medium"
            record.heightDm = hd and hd.heightDm or nil
            record.motionProfile = hd and hd.motionProfile or nil
            return record, nil, {
              requestedGender=wantedGender, requestedPalette=wantedPalette,
              exactGender=record.gender == wantedGender or record.gender == "none",
              exactPalette=record.palette == wantedPalette,
              source="pokemmo",
            }
          end
        end
      end
    end
  end
  return nil, "pokemmo_follower_variant_unavailable"
end

function PokemonWalksheets:resolveFollower(game, mon)
  return self:resolveContext(game, mon, "follower")
end

function PokemonWalksheets:sourceForContext(context)
  local key = CONTEXT_SOURCE_OPTION[context]
  local source = key and optionValue(self.mod, key, "hd") or "hd"
  if self.mod._vascIntegrated and (source=="stadium2" or source=="full_hd") then return source end
  return source == "pokemmo" and "pokemmo" or "hd"
end

-- VASC integration: catalogue membership alone never grants ownership of a
-- visible actor. Both the native strip and the HD atlas must exist. Cache
-- immutable packaged-file checks, not per-entity decisions or live providers.
function PokemonWalksheets:_usableRecord(record)
  if type(record)~="table" then return false end
  if not (self.mod and self.mod._vascIntegrated) then return true end
  if record.animationCards then
    return self:_validateAnimationCards(record.animationCards)
      and self.mod:info(record.runtime)~=nil
  end
  self.assetPresence=self.assetPresence or {}
  for _,path in ipairs({record.runtime or false,record.atlas or false}) do
    if type(path)~="string" then return false end
    if self.assetPresence[path]==nil then
      local ok,info=pcall(self.mod.info,self.mod,path)
      self.assetPresence[path]=ok and type(info)=="table" and info.type=="file"
        and (info.size==nil or info.size>0) or false
    end
    if not self.assetPresence[path] then return false end
  end
  return true
end

function PokemonWalksheets:resolveContext(game, mon, context)
  local source = self:sourceForContext(context)
  if source == "pokemmo" then
    local record, reason, variant = self:resolvePokeMMO(game, mon)
    if self:_usableRecord(record) then return record, reason, variant end
  end
  local record, reason, variant = self:resolve(game, mon)
  local invalidReason = invalidGoAssetReason(record)
  if record and invalidReason then
    local fallback, _, fallbackVariant =
      self:resolvePokeMMO(game, mon)
    if self:_usableRecord(fallback) then
      fallbackVariant = fallbackVariant or {}
      fallbackVariant.fallbackFrom = record.source
      fallbackVariant.fallbackReason = "invalid_go_asset_fallback_pokemmo"
      fallbackVariant.invalidGoAssetReason = invalidReason
      return fallback, "invalid_go_asset_fallback_pokemmo", fallbackVariant
    end
    return nil, "invalid_go_asset_no_safe_fallback:" .. invalidReason
  end
  if not self:_usableRecord(record) then
    local fallback, _, fallbackVariant=self:resolvePokeMMO(game,mon)
    if self:_usableRecord(fallback) then
      fallbackVariant=fallbackVariant or {}
      fallbackVariant.fallbackFrom=source
      fallbackVariant.fallbackReason="full_hd_unavailable_fallback_mmo"
      return fallback,fallbackVariant.fallbackReason,fallbackVariant
    end
    return nil,"no_usable_card_owner_retained"
  end
  if source=="pokemmo" then
    variant=variant or {};variant.fallbackFrom="pokemmo"
    variant.fallbackReason="mmo_unavailable_fallback_full_hd"
    return record,variant.fallbackReason,variant
  end
  return record, reason, variant
end


-- Built-in provider advertised to PresentationPolicy. These are transparent
-- render cards authored from the supplied Pokemon-GO model source, not a live
-- rig provider. Keeping the distinction explicit prevents VASC's Stadium-2
-- body from being drawn over the selected GO card.
function PokemonWalksheets:goRenderCardProvider()
  local resolver = self
  return {
    version="go-hd-render-cards-v1",
    kind="go_hd_render_cards",
    animated=true,
    available=function(dex, context)
      context = type(context) == "table" and context or {}
      local source = type(context.entity) == "table" and context.entity
        or type(context.mon) == "table" and context.mon or {}
      local mon = {}
      for key, value in pairs(source) do mon[key] = value end
      if tonumber(dex) then mon.nationalDex = tonumber(dex) end
      if mon.species == nil then mon.species = context.species end
      local record = resolver:resolve(context.game, mon)
      return resolver:_usableRecord(record) and invalidGoAssetReason(record) == nil
    end,
  }
end

function PokemonWalksheets:def(game, mon, id, context)
  local record, reason, variant = self:resolveContext(game, mon, context)
  if not record then return nil, reason end
  local absoluteRuntime = self.mod.path .. "/" .. record.runtime
  local worldHeight = self.scaleProfiles
    and (self.scaleProfiles.worldHeightForRecord
      and self.scaleProfiles.worldHeightForRecord(record)
      or self.scaleProfiles.worldHeightForClass(record.scaleClass)) or nil
  local def = {
    id=id or ("SPRITE_ASCENDANT_POKEMON_%03d"):format(record.dex),
    image=absoluteRuntime, frames=6, walker=true, trueColor=true,
    pokemonDex=record.dex, ascendantPokemonDex=record.dex,
    pokemonSpecies=record.species,
    ascendantAtlasImage=self.mod.path .. "/" .. record.atlas,
    ascendantAtlasRelative=record.atlas,
    ascendantRole=("pokemon_%03d"):format(record.dex),
    ascendantScaleClass=record.scaleClass,
    ascendantWorldHeight=worldHeight,
    ascendantRuntimeContentWidth=record.runtimeContentWidth,
    ascendantRuntimeContentHeight=record.runtimeContentHeight,
    ascendantNativeScale=worldHeight
      and worldHeight / math.max(1, record.runtimeContentHeight) or nil,
    ascendantPokemonGender=record.gender,
    ascendantPokemonPalette=record.palette,
    ascendantPokemonExactPalette=variant and variant.exactPalette,
    ascendantPokemonContext=context,
    ascendantPokemonWalksheet=true,
    ascendantPokemonMotionProfile=record.motionProfile,
    ascendantPokemonSpriteSource=record.source or "ascendant_hd",
    ascendantPokemonMotionColumns=animationMotionColumns(record),
    ascendantPokemonAnimationClips=record.animationCards and {"idle","walk"} or nil,
    ascendantPokemonDirectionRows={ "front", "left", "back", "right" },
    ascendantPokemonSourceFallbackReason=reason,
    ascendantPokemonInvalidGoAssetReason=variant
      and variant.invalidGoAssetReason or nil,
    ascendantPokemonIdleEventManifest=self.idleEventManifest,
    ascendantPokemonIdleEventRoot=self.idleEventRoot,
    ascendantPokemonFlameCards=record.flameCards,
    ascendantPokemonAnimationCards=record.animationCards,
  }
  local idle = self.idleEvents[record.dex]
    and self.idleEvents[record.dex][record.palette] or nil
  if idle then
    def.ascendantPokemonBlinkSheet = idle.sheet
    def.ascendantPokemonBlinkSourceExact = idle.sourceExact
    def.ascendantPokemonBlinkSha256 = idle.sha256
  end
  return def, nil, record, variant
end

function PokemonWalksheets:public()
  local resolver = self
  local quarantined, repairedVariants = {}, 0
  local animatedVariants = 0
  for _, cards in pairs(self.animationCards) do
    if cards and (not cards.validationComplete or cards.verified) then
      animatedVariants = animatedVariants + 1
    end
  end
  for _ in pairs(self.flameCards) do repairedVariants = repairedVariants + 1 end
  for dex in pairs(INVALID_GO_ASSET_REASON) do
    if not (self.flameCards[dex .. ":base:none:normal"]
        and self.flameCards[dex .. ":base:none:shiny"]) then
      quarantined[#quarantined+1] = dex
    end
  end
  return {
    schema=PokemonWalksheets.SCHEMA,
    atlasCount=self.count, pokemmoAtlasCount=self.pokemmoCount,
    extendedSpeciesCount=self.extendedSpeciesCount,
    legacyAtlasCount=self.legacyCount,
    legacySpeciesCount=self.legacySpeciesCount,
    legacyLastError=self.legacyLastError,
    speciesCount=self.speciesCount,
    lastError=self.lastError,
    idleEventManifest=self.idleEventManifest,
    quarantinedGoDex=quarantined,
    quarantinedOriginalGoDex={ 155 },
    repairedFlameVariants=repairedVariants,
    flameCardErrors=self.flameCardErrors,
    animatedVariants=animatedVariants,
    animationCardErrors=self.animationCardErrors,
    gender=gender,
    resolve=function(game, mon) return resolver:resolve(game, mon) end,
    resolveFollower=function(game, mon)
      return resolver:resolveFollower(game, mon)
    end,
    resolveContext=function(game, mon, context)
      return resolver:resolveContext(game, mon, context)
    end,
    sourceForContext=function(context)
      return resolver:sourceForContext(context)
    end,
    resolvePokeMMO=function(game, mon)
      return resolver:resolvePokeMMO(game, mon)
    end,
    def=function(game, mon, id, context)
      return resolver:def(game, mon, id, context)
    end,
    goRenderCardProvider=function()
      return resolver:goRenderCardProvider()
    end,
    fromPath=function(path) return resolver:fromPath(path) end,
  }
end

PokemonWalksheets.gender = gender
return PokemonWalksheets
