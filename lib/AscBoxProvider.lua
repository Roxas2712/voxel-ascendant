-- VASC-owned ASC BOX presentation provider for PokemonUi Host Contract v1.
--
-- This module never receives a Game, save table, box backend or live Pokemon
-- object.  It renders the manager's immutable descriptor and sends only
-- bounded, revision-bound actions back to the authoritative host.

local V = ...
local AscBox = {}

local Font = require("src.render.Font")
local Assets = require("src.render.Assets")
local Sprites = require("src.pokemon.Sprites")
local Data = require("src.core.Data")
local ModSetting = V.require("ModSetting")
local MobileMenuPresentation = V.require("MobileMenuPresentation")

local storagePresentation, storagePresentationTried
local unregisterPointer
local function reviewedStoragePresentation()
  if not storagePresentationTried then
    storagePresentationTried = true
    local ok, presentation = pcall(V.require, "OrasPartyPresentation")
    if ok and type(presentation) == "table"
        and type(presentation.drawHostStorage) == "function" then
      storagePresentation = presentation
    end
  end
  return storagePresentation
end

AscBox.densitySetting = ModSetting.new("ascBoxDensity", "ASC BOX GRID",
  { "detail_20", "oras_30" }, { "5 X 4 DETAIL", "6 X 5 ORAS" },
  "detail_20")

local W, H = 512, 288
local imageCache = {}

local C = {
  navy={12/255,37/255,84/255}, navy2={5/255,24/255,61/255},
  blue={23/255,75/255,142/255}, orange={244/255,91/255,12/255},
  gold={1,194/255,44/255}, cream={1,247/255,218/255},
  paper={1,252/255,236/255}, glass={158/255,215/255,244/255},
  glass2={202/255,238/255,251/255}, sea={5/255,113/255,183/255},
  sky={31/255,158/255,219/255}, green={45/255,184/255,69/255},
  red={234/255,68/255,37/255}, gray={117/255,135/255,148/255},
  white={1,1,1}, black={20/255,23/255,25/255},
}

local EDITION = {
  red={218/255,49/255,44/255}, blue={45/255,99/255,205/255},
  yellow={235/255,192/255,37/255}, gold={212/255,164/255,34/255},
  silver={147/255,160/255,178/255}, crystal={45/255,184/255,206/255},
}

local function copy(items)
  local out = {}
  for index, item in ipairs(items or {}) do out[index] = item end
  return out
end

local function color(value, alpha)
  love.graphics.setColor(value[1], value[2], value[3], alpha or 1)
end

local function rect(value, x, y, w, h, alpha)
  color(value, alpha)
  love.graphics.rectangle("fill", x, y, w, h)
end

local function rounded(value, x, y, w, h, radius, alpha)
  color(value, alpha)
  love.graphics.rectangle("fill", x, y, w, h, radius or 4, radius or 4)
end

local function outline(value, x, y, w, h, radius, width, alpha)
  color(value, alpha)
  love.graphics.setLineWidth(width or 1)
  love.graphics.rectangle("line", x + .5, y + .5, w - 1, h - 1,
    radius or 3, radius or 3)
  love.graphics.setLineWidth(1)
end

local solidTextShader
local function textShader(valueColor)
  if solidTextShader == nil then
    local graphics = love and love.graphics
    if not (graphics and type(graphics.newShader) == "function") then
      solidTextShader = false
    else
      local ok, shader = pcall(graphics.newShader, [[
        extern vec4 tone;
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
          vec4 px = Texel(tex, tc);
          return vec4(tone.rgb, px.a * tone.a);
        }
      ]])
      solidTextShader = ok and shader or false
    end
  end
  if solidTextShader then
    solidTextShader:send("tone", {
      valueColor[1], valueColor[2], valueColor[3], valueColor[4] or 1,
    })
    return solidTextShader
  end
end

local function text(value, x, y, valueColor, scale)
  valueColor = valueColor or C.black
  local shader = textShader(valueColor)
  if shader and type(love.graphics.setShader) == "function" then
    love.graphics.setShader(shader)
    color(C.white)
  else
    color(valueColor)
  end
  love.graphics.push()
  love.graphics.translate(math.floor(x), math.floor(y))
  love.graphics.scale(scale or 1, scale or 1)
  Font.draw(tostring(value or ""), 0, 0)
  love.graphics.pop()
  if shader and type(love.graphics.setShader) == "function" then
    love.graphics.setShader()
  end
end

local function width(value, scale)
  return Font.width(tostring(value or "")) * (scale or 1)
end

local function fit(value, maxWidth, scale)
  value, scale = tostring(value or ""), scale or 1
  if width(value, scale) <= maxWidth then return value end
  local spans = Font.split(value)
  local budget = math.max(0,
    math.floor(maxWidth / scale) - Font.width("."))
  local count = Font.spansFitting(spans, budget)
  local out = {}
  for index = 1, count do
    out[#out + 1] = value:sub(spans[index].from, spans[index].to)
  end
  return table.concat(out) .. "."
end

local function centered(value, x, y, w, valueColor, scale)
  text(value, x + math.floor((w - width(value, scale)) / 2), y,
    valueColor, scale)
end

local function shell(x, y, w, h, accent)
  rounded(C.navy2, x + 3, y + 3, w, h, 7, .55)
  rounded(accent or C.orange, x, y, w, h, 7)
  rounded(C.cream, x + 3, y + 3, w - 6, h - 6, 5)
  rounded(C.paper, x + 6, y + 6, w - 12, h - 12, 3)
  outline(C.navy, x, y, w, h, 7, 2)
end

local function editionAccent(model)
  return EDITION[tostring(model and model.edition or ""):lower()] or C.orange
end

local function pokemonName(pokemon)
  if not pokemon then return "---" end
  return pokemon.nickname or tostring(pokemon.species or "---"):gsub("_", " ")
end

local function sanitizedMon(pokemon)
  return {
    species=pokemon.species, form=pokemon.form, gender=pokemon.gender,
    shiny=pokemon.shiny == true, egg=pokemon.egg == true,
    palette=pokemon.palette,
  }
end

local function artImage(pokemon)
  if not (pokemon and pokemon.species) or pokemon.egg == true then return nil end
  -- The species catalog and public Sprites resolver are presentation data.
  -- The provider still never sees the host's Game/save/live-mon identity.
  local data = Data
  if not data then return nil end
  local mon = sanitizedMon(pokemon)
  local okPath, path, trueColor = pcall(Sprites.path, data,
    pokemon.species, "front", { mon=mon, kind="pokemon_ui" })
  if not okPath or type(path) ~= "string" or path == "" then return nil end
  local key = path .. (trueColor and "#true" or "#pal")
  if imageCache[key] == nil then
    local ok, image = pcall(Assets.image, path)
    if ok and image and type(image.setFilter) == "function" then
      pcall(image.setFilter, image, "nearest", "nearest")
    end
    imageCache[key] = ok and image or false
  end
  return imageCache[key] or nil
end

if type(Assets.register) == "function" then
  Assets.register(function() imageCache = {} end)
end

local function drawPokemon(pokemon, x, y, w, h)
  if not pokemon then return end
  if pokemon.egg == true then
    local cx, cy = x + w / 2, y + h / 2
    color(C.cream)
    love.graphics.ellipse("fill", cx, cy, math.max(5, w * .25),
      math.max(7, h * .38))
    outline(C.navy, cx - math.max(5, w * .25),
      cy - math.max(7, h * .38), math.max(10, w * .5),
      math.max(14, h * .76), 6, 1)
    color(C.gold)
    love.graphics.rectangle("fill", cx - 5, cy - 2, 4, 3)
    love.graphics.rectangle("fill", cx + 2, cy + 3, 5, 3)
    return
  end
  local image = artImage(pokemon)
  if image then
    local iw, ih = image:getDimensions()
    local scale = math.min(w / math.max(1, iw), h / math.max(1, ih))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image,
      math.floor(x + (w - iw * scale) / 2),
      math.floor(y + (h - ih * scale) / 2), 0, scale, scale)
  else
    rounded(C.glass, x + 3, y + 3, w - 6, h - 6, 4)
    centered("?", x, y + math.floor(h / 2) - 4, w, C.navy, 1)
  end
  if pokemon.shiny then
    local mask = {
      "....N....", "...NHN...", "...NGN...", "NNNGGGNNN",
      ".NGHGGGN.", "..NGGGN..", "..NGNGN..", ".NGN.NGN.",
      ".NN...NN.",
    }
    local ox, oy = math.floor(x + w - 13), math.floor(y + 2)
    for _, symbol in ipairs({ "N", "G", "H" }) do
      color(symbol == "N" and C.navy or symbol == "G" and C.gold or C.cream)
      for row, value in ipairs(mask) do
        local col = 1
        while col <= #value do
          if value:sub(col, col) == symbol then
            local first = col
            repeat col = col + 1
            until col > #value or value:sub(col, col) ~= symbol
            love.graphics.rectangle("fill", ox + first - 1, oy + row - 1,
              col - first, 1)
          else
            col = col + 1
          end
        end
      end
    end
  end
end

local function findEntry(model, location)
  if type(location) ~= "table" then return nil end
  local zone = model.zones and model.zones[location.zone]
  for _, entry in ipairs(zone and zone.entries or {}) do
    if (location.id ~= nil and entry.id == location.id)
        or (location.id == nil and entry.slot == location.slot
          and entry.box == location.box) then
      return entry
    end
  end
end

local function focusedEntry(model)
  return findEntry(model, model.focus)
end

local function targetFor(entry)
  if not entry then return nil end
  return { id=entry.id, zone=entry.zone, slot=entry.slot, box=entry.box }
end

local function gridSpec()
  local mode = AscBox.densitySetting:get()
  if mode == "oras_30" then
    return { columns=6, rows=5, slots=30, stepX=51, stepY=33 }
  end
  return { columns=5, rows=4, slots=20, stepX=61, stepY=41 }
end

AscBox.gridSpec = gridSpec

local function primaryZone(model)
  local wanted = model.surface == "legacy_bank" and "legacy" or "box"
  if model.zones and model.zones[wanted] then return wanted, model.zones[wanted] end
  for name, zone in pairs(model.zones or {}) do
    if name ~= "party" then return name, zone end
  end
  return "party", model.zones and model.zones.party or { entries={} }
end

local SEARCH_X, SEARCH_Y, SEARCH_W, SEARCH_H = 326, 14, 178, 40
local SEARCH_DONE_X, SEARCH_DONE_Y, SEARCH_DONE_W, SEARCH_DONE_H =
  442, 16, 58, 14

local function drawHeader(model, accent)
  shell(16, 12, 480, 42, accent)
  local title = model.title or (model.surface == "legacy_bank" and "LEGACY BANK"
    or model.surface == "battle_party" and "BATTLE TEAM" or "ASC BOX")
  -- `shell` has an opaque cream/paper interior. White text was effectively
  -- invisible there in every Legacy selection frame; the reviewed PC/Team
  -- presenter uses a separate navy title plate and never enters this branch.
  centered(fit(title, 390, 2), 61, 25, 390, C.navy, 2)
  rect(accent, 23, 19, 31, 28)
  outline(C.gold, 20, 16, 37, 34, 4, 1)
end

local function drawSearchPanel(self)
  if self.model.surface ~= "pc_box" or not self.searchOpen then return end
  local search = type(self.model.search) == "table" and self.model.search or {}
  rounded(C.navy2, SEARCH_X, SEARCH_Y, SEARCH_W, SEARCH_H, 6, .94)
  outline(C.glass2, SEARCH_X, SEARCH_Y, SEARCH_W, SEARCH_H, 6, 1)
  local de = self.model.locale == "de"
  text((de and "SUCHE " or "SEARCH ")
    .. tostring(self.searchMode or search.mode or "name"):upper(),
    SEARCH_X + 8, SEARCH_Y + 5, C.white, 1)
  local visible = tostring(self.searchQuery or search.query or "")
    .. tostring(self.searchEditing and self.searchComposition or "")
  text(fit(visible == "" and (de and "TIPPE..." or "TYPE...") or visible,
    112, 1), SEARCH_X + 8, SEARCH_Y + 19,
    visible ~= "" and C.gold or C.glass2, 1)
  local results = type(search.results) == "table" and search.results or {}
  local count = #results
  local index = count > 0 and math.max(1, math.min(count,
    tonumber(self.searchIndex) or 1)) or 0
  text(("%d/%d"):format(index, count),
    SEARCH_X + SEARCH_W - 43, SEARCH_Y + 19, C.gold, 1)
  if self.searchEditing then
    rounded(C.orange, SEARCH_DONE_X, SEARCH_DONE_Y,
      SEARCH_DONE_W, SEARCH_DONE_H, 4)
    outline(C.gold, SEARCH_DONE_X, SEARCH_DONE_Y,
      SEARCH_DONE_W, SEARCH_DONE_H, 4, 1)
    text(de and "X FERTIG" or "X DONE", de and 447 or 453, 19, C.white, 1)
  end
end

local function drawHp(pokemon, x, y, w)
  if not pokemon or pokemon.maxHp == nil then return end
  local ratio = math.max(0, math.min(1,
    (tonumber(pokemon.hp) or 0) / math.max(1, tonumber(pokemon.maxHp) or 1)))
  rounded(C.navy2, x, y, w, 5, 2)
  rounded(ratio <= .2 and C.red or ratio <= .5 and C.gold or C.green,
    x + 1, y + 1, math.floor((w - 2) * ratio), 3, 1)
end

local function sameLocation(a, entry)
  return a and entry and a.id == entry.id and a.zone == entry.zone
    and a.slot == (entry.sourceSlot or entry.slot)
    and a.box == (entry.sourceBox or entry.box)
end

local function drawGrid(self, accent)
  local model = self.model
  local name, zone = primaryZone(model)
  local spec = gridSpec()
  local virtualFocus
  local search = type(model.search) == "table" and model.search or nil
  if self.searchOpen and search and tostring(search.query or "") ~= "" then
    local results = type(search.results) == "table" and search.results or {}
    local count = #results
    local selected = count > 0 and math.max(1, math.min(count,
      math.floor(tonumber(self.searchIndex) or 1))) or 0
    local pageStart = selected > 0
      and math.floor((selected - 1) / spec.slots) * spec.slots + 1 or 1
    zone, name = { entries={}, capacity=spec.slots }, "box"
    for resultIndex = pageStart, math.min(count, pageStart + spec.slots - 1) do
      local result = results[resultIndex]
      zone.entries[#zone.entries + 1] = {
        id=result.id, zone="box", box=result.sourceBox or result.box,
        slot=resultIndex - pageStart + 1,
        sourceBox=result.sourceBox or result.box,
        sourceSlot=result.sourceSlot or result.slot,
        pokemon=result.pokemon,
      }
    end
    virtualFocus = selected > 0 and selected - pageStart + 1 or 1
  end
  shell(17, 61, 329, 184, accent)
  local bySlot = {}
  for _, entry in ipairs(zone.entries or {}) do bySlot[entry.slot] = entry end
  for slot = 1, spec.slots do
    local col, row = (slot - 1) % spec.columns, math.floor((slot - 1) / spec.columns)
    local x, y = 28 + col * spec.stepX, 72 + row * spec.stepY
    local cw, ch = spec.stepX - 5, spec.stepY - 5
    local entry = bySlot[slot]
    local focus = virtualFocus and virtualFocus == slot
      or not virtualFocus and model.focus.zone == name and model.focus.slot == slot
    rounded(focus and accent or C.glass2, x, y, cw, ch, 5,
      entry and .96 or .52)
    outline(entry and C.blue or C.gray, x, y, cw, ch, 5, focus and 3 or 1)
    local heldSource = sameLocation(self.carry, entry)
    if entry and entry.pokemon and not heldSource then
      drawPokemon(entry.pokemon, x + 2, y + 1, cw - 4, ch - 8)
      text(tostring(entry.pokemon.level or ""), x + 4, y + ch - 9, C.navy, 1)
      if entry.selected then
        color(C.gold)
        love.graphics.circle("fill", x + cw - 6, y + 6, 4)
      end
    elseif heldSource then
      rounded(C.gold, x + 2, y + 2, cw - 4, ch - 4, 4, .24)
      outline(C.gold, x, y, cw, ch, 5, 2)
    elseif slot > (zone.capacity or spec.slots) then
      color(C.gray, .45)
      love.graphics.line(x + 5, y + 5, x + cw - 5, y + ch - 5)
      love.graphics.line(x + cw - 5, y + 5, x + 5, y + ch - 5)
    end
    if focus and self.carry then
      color(C.navy2, .28)
      love.graphics.ellipse("fill", x + cw / 2, y + ch - 3, 12, 3)
      drawPokemon(self.carryPokemon, x + 2, y - 6, cw - 4, ch - 7)
    end
  end
  local box = model.surfaceData and model.surfaceData.currentBox
  if box then
    centered(("BOX %02d"):format(box), 114, 248, 150, C.navy, 1)
  end
end

local function drawPartyStrip(self, accent)
  local model = self.model
  local zone = model.zones and model.zones.party or { entries={} }
  shell(354, 61, 141, 184, accent)
  local bySlot = {}
  for _, entry in ipairs(zone.entries or {}) do bySlot[entry.slot] = entry end

  local focused = focusedEntry(model)
  local detail = self.carryPokemon or (focused and focused.pokemon)
  local detailName = detail and pokemonName(detail)
    or (model.locale == "de" and "LEER" or "EMPTY")
  text(fit(detailName, 116, 1), 365, 71, C.navy, 1)
  if detail then
    drawPokemon(detail, 362, 83, 52, 50)
    if not detail.egg then
      text(("Lv.%s"):format(detail.level or "-"), 418, 85, C.navy, 1)
      drawHp(detail, 418, 97, 66)
      local types = detail.types or {}
      text(fit(table.concat(types, "/"), 66, 1), 418, 107, C.blue, 1)
      text((model.locale == "de" and "FÄH:" or "ABL:")
        .. fit(detail.ability or "---", 42, 1), 362, 140, C.navy, 1)
      text((model.locale == "de" and "ITEM:" or "ITEM:")
        .. fit(detail.item or "---", 36, 1), 362, 152, C.navy, 1)
    else
      text(model.locale == "de" and "POKéMON-EI" or "POKéMON EGG",
        362, 140, C.navy, 1)
      text(model.locale == "de" and "INHALT PRIVAT" or "CONTENTS HIDDEN",
        362, 152, C.gray, 1)
    end
  end

  local stripFocused = model.focus and model.focus.zone == "party"
  if stripFocused then
    rounded(accent, 359, 180, 131, 59, 7, .16)
    outline(accent, 358, 179, 133, 61, 7, 3)
  end
  centered(model.locale == "de" and "TEAM" or "PARTY", 362, 174, 124,
    stripFocused and accent or C.navy, 1)
  for slot = 1, 6 do
    local x, y = 362 + (slot - 1) * 21, 190
    local entry = bySlot[slot]
    local focus = stripFocused and model.focus.slot == slot
    local heldSource = sameLocation(self.carry, entry)
    rounded(focus and accent or C.glass2, x, y, 19, 42, 4,
      entry and .96 or .48)
    outline(C.blue, x, y, 19, 42, 4, focus and 2 or 1)
    if entry and entry.pokemon and not heldSource then
      drawPokemon(entry.pokemon, x, y + 2, 19, 31)
    elseif heldSource then
      rounded(C.gold, x + 2, y + 2, 15, 34, 3, .25)
    end
    if focus and self.carry then
      color(C.navy2, .28)
      love.graphics.ellipse("fill", x + 10, y + 36, 7, 2)
      drawPokemon(self.carryPokemon, x, y - 4, 19, 31)
    end
  end
end

local function drawBattleParty(model, accent)
  shell(18, 61, 476, 184, accent)
  local zone = model.zones and model.zones.party or { entries={} }
  local bySlot = {}
  for _, entry in ipairs(zone.entries or {}) do bySlot[entry.slot] = entry end
  for slot = 1, 6 do
    local col, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
    local x, y = 30 + col * 236, 71 + row * 56
    local entry = bySlot[slot]
    local focus = model.focus.zone == "party" and model.focus.slot == slot
    rounded(focus and accent or C.glass2, x, y, 216, 49, 7,
      entry and .96 or .42)
    outline(C.blue, x, y, 216, 49, 7, focus and 3 or 1)
    if entry and entry.pokemon then
      drawPokemon(entry.pokemon, x + 4, y + 2, 48, 43)
      text(fit(pokemonName(entry.pokemon), 132, 1), x + 57, y + 7,
        C.navy, 1)
      text(("Lv.%s"):format(entry.pokemon.level or "-"), x + 164, y + 7,
        C.navy, 1)
      drawHp(entry.pokemon, x + 58, y + 28, 145)
      if entry.reason then text(fit(entry.reason, 145), x + 58, y + 36, C.red) end
    end
  end
end

-- ORAS GLASS remains a separate PokemonUi provider for the battle-party
-- surface. It consumes the same immutable host model as ASC BOX and is not
-- coupled to the independently selected floating Battle HUD.
local function drawOrasGlassBattleParty(model, accent)
  rect(C.navy2, 0, 0, W, H)
  for y = 0, H - 1, 8 do
    rect(y % 16 == 0 and C.blue or C.navy, 0, y, W, 4, .12)
  end
  rounded(C.black, 18, 13, 476, 37, 5, .91)
  rect(C.sky, 24, 45, 464, 2, .9)
  centered(fit(model.title or "BATTLE TEAM", 390, 2),
    61, 24, 390, C.white, 2)

  local zone = model.zones and model.zones.party or { entries={} }
  local bySlot = {}
  for _, entry in ipairs(zone.entries or {}) do bySlot[entry.slot] = entry end
  for slot = 1, 6 do
    local col, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
    local x, y = 19 + col * 241, 60 + row * 57
    local entry = bySlot[slot]
    local focus = model.focus.zone == "party" and model.focus.slot == slot
    rounded(C.black, x + 3, y + 4, 228, 49, 5, .56)
    rounded(C.navy2, x, y, 228, 49, 5, entry and .88 or .48)
    rect(focus and accent or C.sky, x + 4, y + 43, 220, focus and 3 or 2,
      focus and 1 or .75)
    outline(focus and accent or C.glass, x, y, 228, 49, 5,
      focus and 2 or 1, focus and 1 or .55)
    if entry and entry.pokemon then
      drawPokemon(entry.pokemon, x + 4, y + 2, 47, 42)
      text(fit(pokemonName(entry.pokemon), 125, 1), x + 55, y + 7,
        C.white, 1)
      text(("Lv.%s"):format(entry.pokemon.level or "-"), x + 178, y + 7,
        C.white, 1)
      drawHp(entry.pokemon, x + 55, y + 28, 158)
      if entry.reason then
        text(fit(entry.reason, 158), x + 55, y + 36, C.red, 1)
      end
    end
  end
  rounded(C.black, 18, 239, 476, 35, 5, .88)
  rect(C.sky, 24, 242, 464, 2, .8)
  local de = model.locale == "de"
  local forced = model.surfaceData and model.surfaceData.forcedSwitch == true
  text(de and "A:WÄHLEN" or "A:CHOOSE", 31, 254, C.white, 1)
  text(forced and (de and "B:GESPERRT" or "B:LOCKED")
    or (de and "B:ZURÜCK" or "B:BACK"), 189, 254, C.white, 1)
  text(de and "START:STATUS" or "START:SUMMARY", 326, 254, accent, 1)
end

local ACTION_LABELS = {
  withdraw={en="WITHDRAW",de="ENTNEHMEN"}, deposit={en="DEPOSIT",de="ABLEGEN"},
  release={en="RELEASE",de="FREILASSEN"}, inspect={en="SUMMARY",de="STATUS"},
  dex_entry={en="DEX ENTRY",de="DEX-EINTRAG"},
  move={en="MOVE",de="VERSCHIEBEN"}, multi_select={en="MARK",de="MARKIEREN"},
  menu_cancel={en="CANCEL",de="ABBRUCH"},
  transfer_selected_to_pc={en="SEND SELECTED",de="AUSWAHL AN PC"},
  clear_selection={en="CLEAR SELECTION",de="AUSWAHL LEEREN"},
  transfer_all_to_pc={en="SEND ALL",de="ALLE AN PC"},
}

local TOAST_DURATION = 2
local TOAST_MAX_BYTES = 96
local REJECTION_LABELS = {
  stale_target={ de="QUELLE HAT SICH GEÄNDERT", en="SOURCE CHANGED" },
  egg_hidden={ de="EI-DATEN SIND VERBORGEN", en="EGG DATA IS HIDDEN" },
  dex_unavailable={ de="KEIN DEX-EINTRAG VERFÜGBAR", en="NO DEX ENTRY AVAILABLE" },
  destination_invalid={ de="DIESER PLATZ IST RESERVIERT", en="THAT SLOT IS RESERVED" },
  same_slot={ de="BEREITS AUF DIESEM PLATZ", en="ALREADY IN THIS SLOT" },
  party_full={ de="TEAM IST VOLL", en="PARTY IS FULL" },
  box_full={ de="BOX IST VOLL", en="BOX IS FULL" },
  last_party_mon={ de="LETZTES TEAM-POKéMON BLEIBT", en="LAST PARTY POKéMON STAYS" },
  stale_confirmation={ de="BESTÄTIGUNG IST ABGELAUFEN", en="CONFIRMATION EXPIRED" },
  box_invalid={ de="BOX IST NICHT VERFÜGBAR", en="BOX IS UNAVAILABLE" },
  not_yellow={ de="NUR IN POKéMON GELB", en="YELLOW VERSION ONLY" },
  cannot_switch={ de="WECHSEL NICHT MÖGLICH", en="CANNOT SWITCH" },
  forced_switch={ de="DU MUSST EIN POKéMON WÄHLEN", en="CHOOSE A POKéMON FIRST" },
}

local function boundedToastText(value)
  if type(value) ~= "string" then return nil end
  local out = value:gsub("%c+", " "):gsub("%s+", " ")
    :match("^%s*(.-)%s*$")
  if out == "" then return nil end
  if #out <= TOAST_MAX_BYTES then return out end
  local cut = TOAST_MAX_BYTES - 3
  while cut > 0 do
    local nextByte = out:byte(cut + 1)
    if not nextByte or nextByte < 0x80 or nextByte >= 0xC0 then break end
    cut = cut - 1
  end
  return out:sub(1, cut) .. "..."
end

local function toastForResult(result, locale)
  if type(result) ~= "table" then return nil end
  local message = type(result.message) == "table" and result.message or nil
  local value = boundedToastText(message and message.text
    or type(result.message) == "string" and result.message or nil)
  if not value and result.status == "rejected" then
    local labels = REJECTION_LABELS[result.code]
    value = labels and (locale == "de" and labels.de or labels.en) or nil
    if not value then
      local code = tostring(result.code or "rejected"):upper():gsub("_", " ")
      value = (locale == "de" and "AKTION ABGELEHNT: "
        or "ACTION REJECTED: ") .. code
    end
    value = boundedToastText(value)
  end
  if not value then return nil end
  return {
    text=value,
    timer=TOAST_DURATION,
    severity=message and message.severity or "warning",
  }
end

local function actionLabel(id, locale)
  local row = ACTION_LABELS[id]
  return row and (row[locale] or row.en) or tostring(id):upper():gsub("_", " ")
end

local function drawActionMenu(self, accent)
  local items = self.menu
  if not items then return end
  local h = 19 + #items * 25
  shell(158, 70, 196, h, accent)
  for index, id in ipairs(items) do
    local y = 80 + (index - 1) * 25
    if index == self.menuIndex then rounded(accent, 168, y - 3, 176, 22, 4) end
    text((index == self.menuIndex and "> " or "  ")
      .. actionLabel(id, self.model.locale), 175, y,
      index == self.menuIndex and C.navy2 or C.navy, 1)
  end
end

local function drawFooter(self, accent)
  shell(17, 250, 478, 31, accent)
  if self.toast and tonumber(self.toast.timer) and self.toast.timer > 0 then
    text(fit(self.toast.text, 452, 1), 29, 261, C.navy, 1)
    return
  end
  local entry = focusedEntry(self.model)
  local left = entry and pokemonName(entry.pokemon) or (self.model.help or "")
  local selectedCount = self.model.surface == "legacy_bank"
    and math.max(0, tonumber(self.model.surfaceData
      and self.model.surfaceData.selectedCount)
      or #(self.model.selection and self.model.selection.ids or {})) or 0
  if selectedCount > 0 then
    left = (self.model.locale == "de" and "%s · %d MARKIERT"
      or "%s · %d SELECTED"):format(left, selectedCount)
  end
  -- Keep the focused name/selection counter separate from the right-hand
  -- control help; the old 310px budget visibly overprinted long German rows.
  text(fit(left, 238, 1), 29, 261, C.navy, 1)
  local de = self.model.locale == "de"
  local prompt
  if self.model.surface == "legacy_bank" then
    prompt = de and "SELECT:MARK  START:SENDEN"
      or "SELECT:MARK  START:SEND"
  elseif self.model.surface == "battle_party" then
    prompt = de and "A:WÄHLEN  START:STATUS" or "A:CHOOSE  START:SUMMARY"
  else
    local spec = gridSpec()
    if self.model.focus.zone == "party" and self.model.focus.slot == 1 then
      prompt = de and "LEFT:BOX  A:HEBEN" or "LEFT:BOX  A:LIFT"
    elseif self.model.focus.zone == "box"
        and self.model.focus.slot == spec.slots then
      prompt = de and "RIGHT:TEAM  A:HEBEN" or "RIGHT:TEAM  A:LIFT"
    else
      prompt = de and "A:HEBEN  START:SUCHE" or "A:LIFT  START:SEARCH"
    end
  end
  text(fit(prompt, 203, 1), 278, 261, C.navy, 1)
end

local Controller = {}
Controller.__index = Controller

local SEARCH_MODES = { "name", "type", "gender" }

local function boundedSearchText(value)
  value = tostring(value or "")
  if #value <= 32 then return value end
  local cut = value:sub(1, 32)
  local lead = #cut
  while lead > 0 do
    local byte = cut:byte(lead)
    if byte < 128 or byte >= 192 then break end
    lead = lead - 1
  end
  if lead > 0 then
    local byte = cut:byte(lead)
    local expected = byte >= 240 and byte <= 247 and 4
      or byte >= 224 and byte <= 239 and 3
      or byte >= 194 and byte <= 223 and 2 or 1
    if #cut - lead + 1 < expected then cut = cut:sub(1, lead - 1) end
  end
  return cut
end

local function removeLastSearchCharacter(value)
  value = tostring(value or "")
  local first = #value
  if first == 0 then return value end
  while first > 1 do
    local byte = value:byte(first)
    if byte >= 128 and byte <= 191 then first = first - 1 else break end
  end
  return value:sub(1, first - 1)
end

local function enabled(model, action)
  local row = model.availability and model.availability[action]
  return row and row.enabled == true
end

function Controller:_accept(result, action)
  if type(result) == "table" and type(result.model) == "table" then
    self.model = result.model
    if type(self.model.search) == "table" then
      local count = #(self.model.search.results or {})
      self.searchIndex = count == 0 and 1 or math.max(1,
        math.min(count, tonumber(self.searchIndex) or 1))
    end
  end
  local toast = toastForResult(result, self.model and self.model.locale)
  if toast then
    self.toast = toast
  elseif result and result.status == "applied"
      and (result.action or action) == "move" then
    self.toast = nil
  end
  if result and result.status == "confirmation_required" then
    self.confirmation = result.confirmation
  else
    self.confirmation = nil
  end
  return result ~= nil
end

function Controller:_dispatchResult(action, extra)
  local payload = extra or {}
  payload.modelRevision = self.model.revision
  local result = self.ctx.dispatch(action, payload)
  return result, self:_accept(result, action)
end

function Controller:_dispatch(action, extra)
  local _, accepted = self:_dispatchResult(action, extra)
  return accepted
end

function Controller:_search(mode, query)
  if self.model.surface ~= "pc_box" then return false end
  mode = mode or (self.model.search and self.model.search.mode) or "name"
  query = boundedSearchText(query)
  return self:_dispatch("search", { mode=mode, query=query })
end

function Controller:beginSearch(mode)
  if self.model.surface ~= "pc_box" then return false end
  self.searchOpen = true
  self.searchEditing = true
  self.searchMode = mode or (self.model.search and self.model.search.mode) or "name"
  self.searchQuery = self.model.search and self.model.search.query or ""
  self.searchComposition = ""
  self.searchCompositionStart, self.searchCompositionLength = nil, nil
  self.searchIndex = 1
  return true
end

function Controller:endSearch(clear)
  if clear then self.searchQuery = ""; self:_search(self.searchMode, "") end
  self.searchOpen = false
  self.searchEditing = false
  self.searchComposition = ""
  self.searchCompositionStart, self.searchCompositionLength = nil, nil
  return true
end

function Controller:finishSearchInput()
  if not self.searchOpen then return false end
  self.searchEditing = false
  self.searchComposition = ""
  self.searchCompositionStart, self.searchCompositionLength = nil, nil
  return true
end

function Controller:isTextInputActive()
  return self.searchEditing == true
end

function Controller:textinput(value)
  if not self.searchEditing or type(value) ~= "string" then return false end
  local newline = value:find("[\r\n]")
  local committed = newline and value:sub(1, newline - 1) or value
  -- Strip only ASCII controls. Lua pattern `%c` is locale/runtime dependent
  -- and can classify UTF-8 continuation bytes as controls.
  committed = committed:gsub("[%z\1-\31\127]", "")
  self.searchComposition = ""
  self.searchCompositionStart, self.searchCompositionLength = nil, nil
  local handled = true
  if committed ~= "" then
    self.searchQuery = boundedSearchText((self.searchQuery or "") .. committed)
    handled = self:_search(self.searchMode, self.searchQuery)
  end
  if newline then self:finishSearchInput(); return true end
  return committed ~= "" and handled or false
end

function Controller:textedited(value, start, length)
  if not self.searchEditing or type(value) ~= "string" then return false end
  self.searchComposition = boundedSearchText(value:gsub("[\r\n]", ""))
  self.searchCompositionStart = math.max(0, math.floor(tonumber(start) or 0))
  self.searchCompositionLength = math.max(0, math.floor(tonumber(length) or 0))
  return true
end

function Controller:keypressed(key)
  if not self.searchEditing then return false end
  if key == "backspace" or key == "delete" then
    local hadComposition = tostring(self.searchComposition or "") ~= ""
    self.searchComposition = ""
    self.searchCompositionStart, self.searchCompositionLength = nil, nil
    if hadComposition then return true end
    self.searchQuery = removeLastSearchCharacter(self.searchQuery)
    return self:_search(self.searchMode, self.searchQuery)
  elseif key == "escape" then
    return self:endSearch(false)
  elseif key == "return" or key == "kpenter" then
    return self:finishSearchInput()
  end
  -- Gen1Recomp 0.1.90's protected mod sandbox does not allow VASC to bridge
  -- love.textinput, and that engine revision does not forward the callback
  -- to Runtime either.  Preserve ordinary desktop name/type/gender search
  -- through the screen-owned keypressed seam.  Textinput remains the owner
  -- of UTF-8 and IME composition on engines that expose it.
  if type(key) == "string" and #key == 1
      and key:match("^[%w _%-]$") then
    return self:textinput(key)
  end
  return false
end

function Controller:pointerpressed(x, y)
  if self.model.surface ~= "pc_box" then return false end
  if self.searchEditing and x >= SEARCH_DONE_X
      and x <= SEARCH_DONE_X + SEARCH_DONE_W and y >= SEARCH_DONE_Y
      and y <= SEARCH_DONE_Y + SEARCH_DONE_H then
    return self:finishSearchInput()
  end
  if x < SEARCH_X or x > SEARCH_X + SEARCH_W
      or y < SEARCH_Y or y > SEARCH_Y + SEARCH_H then return false end
  if y <= SEARCH_Y + 22 then return self:beginSearch() end
  local width = SEARCH_W / #SEARCH_MODES
  local index = math.max(1, math.min(#SEARCH_MODES,
    math.floor((x - SEARCH_X) / width) + 1))
  self.searchMode = SEARCH_MODES[index]
  self.searchQuery = ""
  self:beginSearch(self.searchMode)
  return self:_search(self.searchMode, self.searchQuery)
end

function Controller:_changeBox(delta)
  if self.model.surface ~= "pc_box" or not enabled(self.model, "change_box") then
    return false
  end
  local surface = type(self.model.surfaceData) == "table"
    and self.model.surfaceData or {}
  local current = tonumber(surface.currentBox) or 1
  local count = math.max(1, tonumber(surface.boxCount) or 1)
  local nextBox = ((current + delta - 1) % count) + 1
  return self:_dispatch("change_box", { boxIndex=nextBox })
end

function Controller:_entryActions()
  local entry, surface = focusedEntry(self.model), self.model.surface
  if not entry then return {} end
  local out = {}
  local candidates
  if surface == "pc_box" then
    candidates = entry.zone == "party"
      and { "move", "inspect", "deposit" }
      or { "move", "inspect", "withdraw", "release" }
  elseif surface == "legacy_bank" then
    candidates = entry.zone == "party"
      and { "deposit", "inspect", "dex_entry" }
      or { "multi_select", "move", "dex_entry", "withdraw", "inspect" }
  else
    candidates = { "select", "inspect" }
  end
  for _, id in ipairs(candidates) do if enabled(self.model, id) then out[#out + 1] = id end end
  -- This row belongs to the temporary detail-card menu, not to the host
  -- surface.  Keeping it provider-local means choosing ABBRUCH can never
  -- accidentally close the complete PC session.
  if surface == "pc_box" then out[#out + 1] = "menu_cancel" end
  return out
end

function Controller:_run(action)
  local entry = focusedEntry(self.model)
  if action == "menu_cancel" then
    self.menu = nil
    return true
  elseif action == "transfer_selected_to_pc" then
    return self:_dispatch(action, { selectionRevision=self.model.selection.revision
      or self.model.revision })
  elseif action == "clear_selection" then
    return self:_dispatch(action, { selectionRevision=self.model.selection.revision
      or self.model.revision })
  elseif action == "transfer_all_to_pc" then
    return self:_dispatch(action, { scope="withdrawable" })
  elseif action == "change_box" or action == "cross_box_select" then
    return false
  elseif action == "cancel" then
    return self:_dispatch(action, { scope="surface" })
  end
  if action == "dex_entry" and self.carry then
    return self:_dispatch(action, { target=self.carry })
  end
  if not entry then return false end
  if action == "move" then
    self.carry = targetFor(entry)
    self.carryPokemon = entry.pokemon
    return true
  end
  local payload = { target=targetFor(entry) }
  if action == "multi_select" then payload.selected = not entry.selected end
  return self:_dispatch(action, payload)
end

function Controller:handleInput(input)
  local pressed = type(input) == "table" and (input.pressed or input) or {}
  if self.searchOpen then
    if pressed.b then return self:endSearch(false) end
    if pressed.start then
      return self.searchEditing and true or self:beginSearch(self.searchMode)
    end
    if pressed.select then
      local current = self.searchMode or "name"
      local index = 1
      for i, mode in ipairs(SEARCH_MODES) do if mode == current then index = i end end
      index = (index % #SEARCH_MODES) + 1
      self.searchMode = SEARCH_MODES[index]
      return self:_search(self.searchMode, self.searchQuery)
    end
    local results = self.model.search and self.model.search.results or {}
    if pressed.up or pressed.down then
      if #results > 0 then
        local delta = pressed.down and 1 or -1
        self.searchIndex = ((self.searchIndex - 1 + delta) % #results) + 1
      end
      return true
    end
    if pressed.a and #results > 0 then
      local result = results[self.searchIndex or 1]
      self:endSearch(false)
      return self:_dispatch("search_locate", { target={
        id=result.id, zone="box", box=result.sourceBox or result.box,
        slot=result.sourceSlot or result.slot,
      } })
    end
    return false
  end
  if self.confirmAll then
    if pressed.b then self.confirmAll = nil; return true end
    if pressed.a then
      self.confirmAll = nil
      return self:_dispatch("transfer_all_to_pc", { scope="withdrawable" })
    end
    return false
  end
  if self.confirmation then
    if pressed.b then self.confirmation = nil; return true end
    if pressed.a then
      local entry = focusedEntry(self.model)
      local token = self.confirmation.token
      self.confirmation = nil
      return self:_dispatch("release", {
        target=targetFor(entry), confirmationToken=token,
      })
    end
    return false
  end
  if self.menu then
    if pressed.up then
      self.menuIndex = self.menuIndex > 1 and self.menuIndex - 1 or #self.menu
      return true
    elseif pressed.down then
      self.menuIndex = self.menuIndex < #self.menu and self.menuIndex + 1 or 1
      return true
    elseif pressed.b then self.menu = nil; return true
    elseif pressed.a then
      local action = self.menu[self.menuIndex]
      self.menu = nil
      if action == "transfer_all_to_pc" then
        self.confirmAll = true
        return true
      end
      return self:_run(action)
    end
    return false
  end
  if pressed.start and self.model.surface == "pc_box" then
    return self:beginSearch()
  end
  if self.boxHeaderFocus and self.model.surface == "pc_box" then
    if pressed.left or pressed.page_prev then return self:_changeBox(-1) end
    if pressed.right or pressed.page_next then return self:_changeBox(1) end
    if pressed.up or pressed.down or pressed.a or pressed.b then
      self.boxHeaderFocus = false
      return true
    end
    return false
  end
  local focus = type(self.model.focus) == "table" and self.model.focus or {}
  if self.model.surface == "pc_box" and focus.zone == "box"
      and tonumber(focus.slot) and tonumber(focus.slot) <= gridSpec().columns
      and pressed.up and enabled(self.model, "navigate") then
    -- Header focus is presentation-local: Host-v1 focus IDs remain bound to
    -- their exact namespaced slot until LEFT/RIGHT requests change_box.
    self.boxHeaderFocus = true
    return true
  end
  if self.carry then
    if pressed.b then self.carry, self.carryPokemon = nil, nil; return true end
    if pressed.start and enabled(self.model, "dex_entry") then
      return self:_run("dex_entry")
    end
    if pressed.a then
      local destination = {
        zone=self.model.focus.zone, slot=self.model.focus.slot,
        box=self.model.focus.box,
      }
      local source = self.carry
      local result, accepted = self:_dispatchResult("move", {
        target=source, destination=destination,
      })
      if result and result.status == "applied" then
        self.carry, self.carryPokemon = nil, nil
      end
      return accepted
    end
    -- Navigation and cross-box page changes below deliberately remain live
    -- while carrying. The source descriptor stays revision-bound; if the
    -- external host changes underneath it, the Host-v1 stale gate rejects the
    -- drop without a partial mutation.
  end
  if pressed.b and self.model.surface == "pc_box"
      and focus.zone == "party" and enabled(self.model, "navigate") then
    -- Match the reviewed 0.5.3 storage contract: B leaves the live mini-Team
    -- strip first. The host owns the remembered Box cursor, so toggling the
    -- focus zone restores that exact seat without closing the PC.
    return self:_dispatch("navigate", { direction="page_next" })
  end
  for _, direction in ipairs({ "up", "down", "left", "right" }) do
    if pressed[direction] and enabled(self.model, "navigate") then
      return self:_dispatch("navigate", { direction=direction })
    end
  end
  if pressed.page_prev or pressed.page_next then
    local current = self.model.surfaceData.currentBox or 1
    local count = math.max(1, self.model.surfaceData.boxCount or 1)
    local nextBox = ((current + (pressed.page_next and 1 or -1) - 1) % count) + 1
    local action = self.model.surface == "legacy_bank"
      and "cross_box_select" or "change_box"
    if enabled(self.model, action) then
      return self:_dispatch(action, { boxIndex=nextBox })
    end
  end
  if pressed.select and self.model.surface ~= "battle_party" then
    if self.model.surface == "legacy_bank" then
      local entry = focusedEntry(self.model)
      if entry and entry.zone == "legacy" then
        if enabled(self.model, "multi_select") then
          return self:_run("multi_select")
        end
        local availability = self.model.availability
          and self.model.availability.multi_select or nil
        self.toast = {
          text=boundedToastText(availability and availability.reason)
            or (self.model.locale == "de" and "NICHT MARKIERBAR"
              or "CANNOT MARK"),
          timer=TOAST_DURATION, severity="warning",
        }
      end
      -- SELECT belongs exclusively to cross-box marking on this surface.
      -- A locked/empty/Party focus must never fall through to page navigation.
      return true
    end
    return self:_dispatch("navigate", { direction="page_next" })
  end
  if pressed.start then
    if self.model.surface == "legacy_bank" then
      local bulk = {}
      if #(self.model.selection.ids or {}) > 0
          and enabled(self.model, "transfer_selected_to_pc") then
        bulk[#bulk + 1] = "transfer_selected_to_pc"
      end
      if #(self.model.selection.ids or {}) > 0
          and enabled(self.model, "clear_selection") then
        bulk[#bulk + 1] = "clear_selection"
      end
      if enabled(self.model, "transfer_all_to_pc") then
        bulk[#bulk + 1] = "transfer_all_to_pc"
      end
      if #bulk > 0 then self.menu, self.menuIndex = bulk, 1; return true end
    elseif enabled(self.model, "inspect") then
      return self:_run("inspect")
    end
  end
  if pressed.b and enabled(self.model, "cancel") then return self:_run("cancel") end
  if pressed.a then
    if self.model.surface == "battle_party" then
      return enabled(self.model, "select") and self:_run("select") or false
    elseif self.model.surface == "pc_box" then
      -- A selects the occupied card first.  Moving is one explicit choice in
      -- the right-hand action card alongside the native full-screen Summary,
      -- withdraw/deposit and guarded release actions.  Carry mode begins only
      -- after the player confirms MOVE from that card.
      local menu = self:_entryActions()
      if #menu > 0 then self.menu, self.menuIndex = menu, 1; return true end
      return false
    end
    local menu = self:_entryActions()
    if #menu > 0 then self.menu, self.menuIndex = menu, 1; return true end
  end
  return false
end

function Controller:draw()
  if self.style == "oras_glass" and self.model.surface == "battle_party" then
    drawOrasGlassBattleParty(self.model, editionAccent(self.model))
    love.graphics.setColor(1, 1, 1, 1)
    return true
  end

  -- Standard PC storage uses the reviewed 0.5.3 drawing path verbatim.  Only
  -- a private immutable descriptor proxy crosses this seam; Controller input,
  -- revision checks, moves/swaps and save ownership remain in the Host-v1
  -- dispatcher above.  Any presentation error fails open to the older local
  -- painter for this frame instead of breaking the native PC session.
  if self.model.surface == "pc_box" then
    local focus = type(self.model.focus) == "table" and self.model.focus or {}
    if focus.zone == "box" then
      self.storageBoxCursor = tonumber(focus.slot) or self.storageBoxCursor
    elseif focus.zone == "party" then
      self.storagePartyCursor = tonumber(focus.slot) or self.storagePartyCursor
    end
    local menuLabels
    if type(self.menu) == "table" then
      menuLabels = {}
      for _, id in ipairs(self.menu) do
        menuLabels[#menuLabels + 1] = actionLabel(id, self.model.locale)
      end
    end
    local presentation = reviewedStoragePresentation()
    if presentation then
      local ok, rendered = pcall(presentation.drawHostStorage,
        self.model, {
          data=Data,
          boxCursor=self.storageBoxCursor,
          partyCursor=self.storagePartyCursor,
          boxHeaderFocus=self.boxHeaderFocus == true,
          carry=self.carry,
          carryPokemon=self.carryPokemon,
          toast=self.toast,
          menuLabels=menuLabels,
          menuIndex=self.menuIndex,
          searchOpen=self.searchOpen == true,
          searchEditing=self.searchEditing == true,
          searchComposition=self.searchComposition,
          searchIndex=self.searchIndex,
        })
      if ok and rendered then
        love.graphics.setColor(1, 1, 1, 1)
        return true
      end
    end
  end

  rect(C.sky, 0, 0, W, 150)
  for y = 0, 148, 6 do rect(C.glass2, 0, y, W, 3, .08 + y / 1800) end
  rect(C.sea, 0, 150, W, H - 150)
  local accent = editionAccent(self.model)
  drawHeader(self.model, accent)
  drawSearchPanel(self)
  if self.model.surface == "battle_party" then drawBattleParty(self.model, accent)
  else drawGrid(self, accent); drawPartyStrip(self, accent) end
  drawFooter(self, accent)
  if self.carry then
    rounded(C.gold, 18, 222, 328, 23, 4, .96)
    text(self.model.locale == "de" and "TRAGE POKéMON - A:ABLEGEN B:ABBRUCH"
      or "CARRYING POKéMON - A:DROP B:CANCEL", 28, 229, C.navy, 1)
  end
  drawActionMenu(self, accent)
  if self.confirmation then
    shell(108, 103, 296, 80, accent)
    centered(fit(self.confirmation.prompt, 264, 1), 124, 122, 264, C.navy, 1)
    centered(self.model.locale == "de" and "A: JA     B: NEIN"
      or "A: YES     B: NO", 124, 151, 264, C.navy, 1)
  end
  if self.confirmAll then
    shell(108, 103, 296, 80, accent)
    centered(self.model.locale == "de" and "ALLE MÖGLICHEN ÜBERTRAGEN?"
      or "TRANSFER EVERY POSSIBLE POKéMON?", 124, 122, 264, C.navy, 1)
    centered(self.model.locale == "de" and "A: JA     B: NEIN"
      or "A: YES     B: NO", 124, 151, 264, C.navy, 1)
  end
  love.graphics.setColor(1, 1, 1, 1)
  return true
end

function Controller:onEvent(_, envelope)
  if envelope and envelope.model then
    self.model = envelope.model
    if not (self.model.surface == "pc_box" and self.model.focus
        and self.model.focus.zone == "box") then
      self.boxHeaderFocus = false
    end
  end
  return true
end

function Controller:update(dt)
  if self.toast then
    local elapsed = tonumber(dt) or 0
    if elapsed > 0 then
      self.toast.timer = math.max(0,
        math.min(TOAST_DURATION, tonumber(self.toast.timer) or 0) - elapsed)
      if self.toast.timer <= 0 then self.toast = nil end
    end
  end
  return true
end
function Controller:close() self.closed = true; return true end

local function surfaceDef(PokemonUi, surface, style)
  local req = PokemonUi.REQUIREMENTS[surface]
  local actions = copy(req.actions)
  if surface == "legacy_bank" then actions[#actions + 1] = "clear_selection" end
  return {
    controllerGeneration=PokemonUi.CONTROLLER_GENERATION,
    viewport={ width=W, height=H },
    schemas={
      model=PokemonUi.MODEL_SCHEMA, action=PokemonUi.ACTION_SCHEMA,
      actionResult=PokemonUi.ACTION_RESULT_SCHEMA, event=PokemonUi.EVENT_SCHEMA,
    },
    modes=copy(req.modes), actions=actions, events=copy(req.events),
    claims={ draw="complete", input="complete", commit="atomic",
      selection=req.selection },
    create=function(ctx)
      local self = setmetatable({ ctx=ctx, model=ctx.model, style=style }, Controller)
      self.receipt = {
        schema=PokemonUi.SESSION_SCHEMA, apiVersion=PokemonUi.API_VERSION,
        owner=ctx.owner, provider=ctx.provider,
        host=ctx.host, hostOwner=ctx.hostOwner,
        hostGeneration=ctx.hostGeneration,
        capabilityDigest=ctx.capabilityDigest,
        viewport={ width=ctx.viewport.width, height=ctx.viewport.height },
        surface=ctx.surface, session=ctx.session,
        controllerGeneration=ctx.controllerGeneration,
        schemas={
          model=ctx.schemas.model, action=ctx.schemas.action,
          actionResult=ctx.schemas.actionResult, event=ctx.schemas.event,
        },
        complete=true,
        claims={ draw="complete", input="complete", commit="atomic",
          selection=ctx.selection, modes=copy(ctx.modes),
          actions=copy(ctx.actions), events=copy(ctx.events) },
      }
      return self
    end,
  }
end

function AscBox.install(PokemonUi)
  if AscBox.unregister then return true end
  local hooks = V.mod and V.mod.hooks
  if type(hooks) == "table" and type(hooks.wrap) == "function" then
    unregisterPointer = hooks:wrap("input.pointer", function(nextInput, game, pointer)
      local downstream = nextInput(game, pointer)
      if downstream == true or type(pointer) ~= "table"
          or pointer.phase ~= "pressed" or pointer.insideGame == false then
        return downstream == true
      end
      local stack = game and game.stack
      local top = stack and type(stack.top) == "function" and stack:top()
      local marker = top and top.__pokemonUiHostV1
      if not (type(marker) == "table"
          and marker.owner == "VOXEL_ASCENDANT"
          and marker.surface == "pc_box"
          and type(top.pointerpressed) == "function") then
        return false
      end
      local pointerX, pointerY = pointer.gameX, pointer.gameY
      if type(MobileMenuPresentation) == "table"
          and type(MobileMenuPresentation.pointerToLogical) == "function" then
        pointerX, pointerY = MobileMenuPresentation.pointerToLogical(
          top, pointerX, pointerY)
      end
      local ok, handled = pcall(top.pointerpressed, top, pointerX, pointerY)
      return ok and handled == true
    end, 15155)
  end
  local unregisterAsc, why = PokemonUi.register({
    schema=PokemonUi.PROVIDER_SCHEMA, apiVersion=PokemonUi.API_VERSION,
    id="asc_box", owner="VOXEL_ASCENDANT", label="ASC BOX",
    surfaces={
      pc_box=surfaceDef(PokemonUi, "pc_box"),
      legacy_bank=surfaceDef(PokemonUi, "legacy_bank"),
      battle_party=surfaceDef(PokemonUi, "battle_party"),
    },
  })
  if not unregisterAsc then
    if unregisterPointer then unregisterPointer(); unregisterPointer = nil end
    return nil, why
  end
  local unregisterGlass, glassWhy = PokemonUi.register({
    schema=PokemonUi.PROVIDER_SCHEMA, apiVersion=PokemonUi.API_VERSION,
    id="oras_glass", owner="VOXEL_ASCENDANT", label="ORAS GLASS",
    surfaces={
      battle_party=surfaceDef(PokemonUi, "battle_party", "oras_glass"),
    },
  })
  if not unregisterGlass then
    unregisterAsc()
    if unregisterPointer then unregisterPointer(); unregisterPointer = nil end
    return nil, glassWhy
  end
  AscBox.unregister = function()
    unregisterGlass()
    unregisterAsc()
    if unregisterPointer then unregisterPointer(); unregisterPointer = nil end
    AscBox.unregister = nil
  end
  return true
end

AscBox.WIDTH, AscBox.HEIGHT = W, H
AscBox.Controller = Controller

return AscBox
