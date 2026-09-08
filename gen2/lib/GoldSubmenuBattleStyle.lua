-- Gold/Silver KASC/VASC-style renderers for the built-in Gold submenus that
-- are opened from the Gen-2 START / pause menu.
--
-- IMPORTANT: this module deliberately patches PRESENTATION ONLY.  Every screen
-- keeps its original update/action/save/item/party/Pokegear/Pokedex logic.
-- Most constructors are tagged only when created from the real Gen-2 START
-- menu.  PartyMenu and SummaryMenu are intentionally universal in v0.2.42 so
-- their 3D presentation works from pause, battle fallbacks and item/party flows
-- regardless of stack-construction timing on Gen1Recomp v0.1.83.
--
-- The hierarchy mirrors the shared Ascendant menus.  Gen-2 used to keep an
-- antique-brown prototype palette here; that made START look like VASC while
-- PACK/CARD/POKEGEAR looked like an unrelated mod.  All ordinary screens now
-- use the same navy/charcoal, Ascendant-red and amber-focus vocabulary.
local V = ...
local mod = V and V.mod
local Gen2CrystalFronts = V and type(V.require) == "function"
  and V.require("Gen2CrystalFronts") or nil
local SharedParty = V and V.OrasPartyPresentation
local SharedSummary = V and V.OrasPartySummaryPresentation
local SharedBag = V and V.OrasBagSkin
local SharedFrlgBag = V and V.OrasFrlgBagSkin
local ManualBagSort = V and V.ManualBagSort
local SharedMenus = V and V.SharedMenuPresentation
local Diagnostics = V and type(V.Diagnostics) == "table" and V.Diagnostics or {}
local CanvasPresentation = V and V.CanvasPresentation

local function presentationLanguage(game)
  if SharedParty and type(SharedParty.activeLanguage) == "function" then
    local ok, value = pcall(SharedParty.activeLanguage, game)
    if ok and (value == "de" or value == "en") then return value end
  end
  local finder = mod and mod.find
  if type(finder) == "function" then
    local ok, universal = pcall(finder, "translation-german-universal")
    if not ok then ok, universal = pcall(finder, mod,
      "translation-german-universal") end
    local boot = ok and universal and universal.exports
      and universal.exports.bootLanguage
    if boot == "de" or boot == "en" then return boot end
    for _, id in ipairs({ "deutsch", "deutsch-blau", "deutsch-gelb" }) do
      local found, handle = pcall(finder, id)
      if not found then found, handle = pcall(finder, mod, id) end
      if found and handle then return "de" end
    end
  end
  return "en"
end

local function localized(game, english, german)
  return presentationLanguage(game) == "de" and german or english
end

local function diagnostic(event, fields)
  if type(Diagnostics.write) == "function" then
    pcall(Diagnostics.write, event, fields)
  end
end

local function diagnosticOnce(owner, key, event, fields)
  if type(owner) ~= "table" then return diagnostic(event, fields) end
  local seen = rawget(owner, "_vascGen2DiagnosticEvents")
  if type(seen) ~= "table" then
    seen = {}
    rawset(owner, "_vascGen2DiagnosticEvents", seen)
  end
  if seen[key] then return end
  seen[key] = true
  diagnostic(event, fields)
end

local M = {
  installed = false,
  draws = 0,
  tagged = 0,
  lastError = nil,
  targets = {},
  mapBitmapFrameDraws = 0,
}

local fonts = {}
local StartMenuClass = nil
local SaveModule = nil
local PartyModelPreview = nil
local Gen2Nests = nil
local Gen2Unown = nil
local WorldPanorama = nil
local TrainerCardImages = {}
local TrainerCardBadgeCase = nil
local MenuAssets = nil
local MenuPaletteFX = nil
local MenuGbcPalette = nil
local MenuGen2Palettes = nil

local WORLD_PANORAMA_ASSET = "assets/ui/gen2/johto_kanto_panorama.png"
-- Independent frames are intentional: the artwork is a panorama, not one
-- affine copy of the cartridge's two 160x144 town maps.  Region ownership is
-- decided first from the Gen-2 landmark table, then the native coordinate is
-- projected into the matching half.  The small overlap is the Indigo/Mt.
-- Silver seam and never changes which region owns a Fly row.
local WORLD_PANORAMA_FRAME = {
  johto = { x = 0.010, y = 0.055, w = 0.620, h = 0.850 },
  kanto = { x = 0.585, y = 0.060, w = 0.405, h = 0.835 },
}

local function engineModule(slot, name)
  if slot == false then return nil end
  if slot then return slot end
  local ok, module = pcall(require, name)
  return ok and module or false
end

local function worldPanorama()
  if WorldPanorama == false then return nil end
  if WorldPanorama then return WorldPanorama end
  local G = love and love.graphics
  if not (G and type(G.newImage) == "function") then
    WorldPanorama = false
    return nil
  end
  local path = V and V.path and (V.path .. "/" .. WORLD_PANORAMA_ASSET)
    or WORLD_PANORAMA_ASSET
  local ok, image = pcall(G.newImage, path)
  -- LÖVE's virtual filesystem does not accept every absolute developer/RC
  -- path even though io.open can read it. The installed mod normally uses a
  -- virtual `mods/...` path; this byte-backed retry keeps frozen/symlinked RC
  -- trees and the release harness on the exact same panorama code path.
  if (not ok or not image) and io and type(io.open) == "function"
      and love.filesystem and type(love.filesystem.newFileData) == "function" then
    local file = io.open(path, "rb")
    if file then
      local bytes = file:read("*a")
      file:close()
      local made, data = pcall(love.filesystem.newFileData,
        bytes, "johto_kanto_panorama.png")
      if made and data then ok, image = pcall(G.newImage, data) end
    end
  end
  if not ok or not image then
    WorldPanorama = false
    M.lastError = "Gen-2 panorama: " .. tostring(image)
    return nil
  end
  if type(image.setFilter) == "function" then
    pcall(image.setFilter, image, "linear", "linear")
  end
  WorldPanorama = image
  return image
end

local function customUIEnabled()
  -- The upgrader persists the removed `customUI` key as false so obsolete
  -- wrappers stay disabled.  New Gen-2 surfaces must follow their explicit
  -- ORAS/GAME DEFAULT selectors and must not inherit that tombstone.
  return true
end

local function optionUsesOras(key)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return true end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return true end
  value = tostring(value):lower()
  return value ~= "standard" and value ~= "native"
    and value ~= "game_default" and value ~= "off"
end

local function modOption(key, fallback)
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  return value
end

local function selectedBagStyle()
  local value = tostring(modOption("qol_bag_skin", "oras_wide")):lower()
  if value == "oras" then return "oras_wide" end
  if value == "frlg" then return "frlg_wide" end
  if value == "oras_wide" or value == "frlg_wide" then return value end
  -- Gold's 160x144 native PACK is not a full-window mobile surface and is the
  -- stale default shown in the reported iPhone build.  Keep the persisted
  -- preference untouched for PC, but give phones the reviewed wide renderer.
  -- The two actual wide styles remain switchable through BAG MENU.
  if CanvasPresentation
      and (CanvasPresentation.OS == "iOS"
        or CanvasPresentation.OS == "Android") then
    return "oras_wide"
  end
  return "external"
end

M.selectedBagStyleForQA = selectedBagStyle

local function modernDexEnabled()
  local value = tostring(modOption("pokedexStyle", "modern")):lower()
  return value ~= "game" and value ~= "native"
    and value ~= "standard" and value ~= "game_default"
end

local function modernDexSpriteSource()
  local value = tostring(modOption("modernDexSpriteSource", "crystal")):lower()
  if value == "active" or value == "game" then return value end
  return "crystal"
end

local function partyPreviewModule()
  if PartyModelPreview == false then return nil end
  if PartyModelPreview then return PartyModelPreview end
  if not (V and type(V.require) == "function") then
    PartyModelPreview = false
    return nil
  end
  local ok, preview = pcall(V.require, "PartyModelPreview")
  if ok and type(preview) == "table" then
    PartyModelPreview = preview
    return preview
  end
  PartyModelPreview = false
  M.lastError = "PartyModelPreview: " .. tostring(preview)
  return nil
end

local function engineAssetModule()
  if MenuAssets == false then return nil end
  if MenuAssets then return MenuAssets end
  local ok, value = pcall(require, "src.render.Assets")
  MenuAssets = ok and value or false
  return MenuAssets or nil
end

local function enginePaletteFx()
  if MenuPaletteFX == false then return nil end
  if MenuPaletteFX then return MenuPaletteFX end
  local ok, value = pcall(require, "src.render.PaletteFX")
  MenuPaletteFX = ok and value or false
  return MenuPaletteFX or nil
end

local function engineGbcPalette()
  if MenuGbcPalette == false then return nil end
  if MenuGbcPalette then return MenuGbcPalette end
  local ok, value = pcall(require, "src.render.GbcPalette")
  MenuGbcPalette = ok and value or false
  return MenuGbcPalette or nil
end

local function engineGen2Palettes()
  if MenuGen2Palettes == false then return nil end
  if MenuGen2Palettes then return MenuGen2Palettes end
  local ok, value = pcall(require, "src.world.gen2.Palettes")
  MenuGen2Palettes = ok and value or false
  return MenuGen2Palettes or nil
end

local function font(size)
  size = math.max(5, math.floor((tonumber(size) or 10) + 0.5))
  if fonts[size] ~= nil then return fonts[size] or nil end
  local G = love and love.graphics
  if not (G and type(G.newFont) == "function") then
    fonts[size] = false
    return nil
  end
  local ok, f = pcall(G.newFont, size)
  fonts[size] = ok and f or false
  return fonts[size] or nil
end

local function roundRect(mode, x, y, w, h, r)
  love.graphics.rectangle(mode, x, y, w, h, r, r)
end

local function uiScaleFor(ww, wh)
  return math.max(0.18, math.min(1, math.min(ww / 800, wh / 600)))
end

local EDITION_ACCENTS = {
  gold = { 0.92, 0.67, 0.13 },
  silver = { 0.68, 0.75, 0.84 },
  crystal = { 0.12, 0.78, 0.95 },
}
local EDITION_HIGHLIGHTS = {
  gold = { 1.00, 0.80, 0.28 },
  silver = { 0.88, 0.93, 0.98 },
  crystal = { 0.42, 0.91, 1.00 },
}
local activeEdition = "crystal"

local function editionForScreen(screen)
  local candidates = {
    screen and screen.save,
    screen and screen.game and screen.game.save,
    screen and screen.world and screen.world.game and screen.world.game.save,
    mod and mod.game and mod.game.save,
    mod and mod.world and mod.world.game and mod.world.game.save,
  }
  for _, save in ipairs(candidates) do
    local edition = tostring(type(save) == "table" and save.version or ""):lower()
    if EDITION_ACCENTS[edition] then return edition end
  end
  return activeEdition
end

-- Shared ORAS Party/Bag renderers are generation-neutral and therefore keep
-- their original orange chrome unless their owner supplies a local palette.
-- Gen 2 supplies the installed edition here; Gen 1 never passes this option,
-- so its reviewed presentation remains byte-for-byte identical at draw time.
local function editionChromeFor(screen)
  local edition = editionForScreen(screen)
  local primary = EDITION_ACCENTS[edition] or EDITION_ACCENTS.crystal
  local bright = EDITION_HIGHLIGHTS[edition] or EDITION_HIGHLIGHTS.crystal
  return {
    id = edition,
    primary = { primary[1], primary[2], primary[3], 1 },
    bright = { bright[1], bright[2], bright[3], 1 },
  }
end

local function panel(x, y, w, h, r, alpha, s)
  local G = love.graphics
  local accent = EDITION_ACCENTS[activeEdition] or EDITION_ACCENTS.crystal
  G.setColor(0.018, 0.030, 0.055, alpha or 0.92)
  roundRect("fill", x, y, w, h, r)
  G.setColor(accent[1], accent[2], accent[3], 0.94)
  G.setLineWidth(math.max(1, 2 * (s or 1)))
  roundRect("line", x, y, w, h, r)
end

-- A map bitmap is artwork inside the ORAS workspace, not the workspace panel
-- itself. Give that actual raster a tight edition-coloured frame so the broad
-- Johto panorama and the native 160x144 fail-open canvases read as one map
-- object on first draw and every later reopening. The frame is painted before
-- the bitmap/markers: it hugs the scaled raster without ever covering a native
-- cursor, Fly point, player dot or Pokédex-area marker.
local function bitmapMapFrameGeometry(screen, x, y, w, h, s)
  x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h)
  if not (x and y and w and h and w > 0 and h > 0) then return nil end
  s = math.max(0.18, tonumber(s) or 1)
  local stroke = math.max(1, math.min(4 * s, math.min(w, h) * 0.008))
  local pad = math.max(2 * s, stroke * 1.35)
  return {
    x=x-pad, y=y-pad, w=w+pad*2, h=h+pad*2,
    pad=pad, stroke=stroke, edition=editionForScreen(screen),
  }
end

local function drawBitmapMapFrame(screen, x, y, w, h, s)
  local G = love and love.graphics
  local frame = bitmapMapFrameGeometry(screen, x, y, w, h, s)
  if not (G and frame) then return nil end
  local chrome = editionChromeFor(screen)
  local accent = chrome.primary
  local bright = chrome.bright
  G.setColor(0.004, 0.009, 0.018, 0.96)
  G.rectangle("fill", frame.x, frame.y, frame.w, frame.h)
  G.setLineWidth(frame.stroke)
  G.setColor(accent[1], accent[2], accent[3], 0.98)
  G.rectangle("line", frame.x, frame.y, frame.w, frame.h)
  G.setLineWidth(math.max(1, frame.stroke * 0.48))
  G.setColor(bright[1], bright[2], bright[3], 0.72)
  G.rectangle("line", x-frame.pad*0.46, y-frame.pad*0.46,
    w+frame.pad*0.92, h+frame.pad*0.92)
  G.setLineWidth(1)
  M.mapBitmapFrameDraws = M.mapBitmapFrameDraws + 1
  return frame
end

local function cleanText(text)
  text = tostring(text or "")
  text = text:gsub("<PO><KE>", "POKé")
  text = text:gsub("<PK><MN>", "POKéMON")
  text = text:gsub("<POKE>", "POKé")
  text = text:gsub("<LV>", "LV ")
  text = text:gsub("<NEXT>", " ")
  text = text:gsub("{PLAYER}", "PLAYER")
  text = text:gsub("[\v\f\r]", " ")
  text = text:gsub("\n", "  ")
  text = text:gsub("%s+", " ")
  return text
end

local function clipped(text, f, maxW)
  text = cleanText(text)
  if not f or type(f.getWidth) ~= "function" or f:getWidth(text) <= maxW then
    return text
  end
  local suffix = "..."
  while #text > 0 and f:getWidth(text .. suffix) > maxW do
    text = text:sub(1, -2)
  end
  return text .. suffix
end

local function targetDimensions(fallbackW, fallbackH)
  local mobile = CanvasPresentation
    and (CanvasPresentation.OS == "iOS"
      or CanvasPresentation.OS == "Android")
  local G = love and love.graphics
  if mobile and G and type(G.getDimensions) == "function" then
    local ok, w, h = pcall(G.getDimensions)
    if ok and w and h and w > 0 and h > 0 then return w, h end
  end
  if fallbackW and fallbackH and fallbackW > 0 and fallbackH > 0 then
    return fallbackW, fallbackH
  end
  if not G then return nil, nil end
  if type(G.getCanvas) == "function" then
    local ok, c = pcall(G.getCanvas)
    if ok and c and type(c.getDimensions) == "function" then
      local w, h = c:getDimensions()
      if w and h and w > 0 and h > 0 then return w, h end
    end
  end
  if type(G.getDimensions) == "function" then return G.getDimensions() end
  return nil, nil
end

M.mobileWindowForQA = targetDimensions

local function beginDraw(ww, wh, screen)
  if not (ww and wh and ww > 0 and wh > 0) then return false end
  local G = love and love.graphics
  if not G then return false end
  G.push("all")
  G.origin()
  activeEdition = editionForScreen(screen)
  if type(G.setBlendMode) == "function" then G.setBlendMode("alpha") end
  return true
end

local function endDraw()
  love.graphics.pop()
  M.draws = M.draws + 1
end

local function header(G, title, subtitle, x, y, w, headerH, wh, s)
  local titleFont = font(math.max(18 * s, wh * 0.023))
  local metaFont = font(math.max(11 * s, wh * 0.013))
  if titleFont then G.setFont(titleFont) end
  G.setColor(1, 1, 1, 0.98)
  G.print(clipped(title, G.getFont(), w * 0.89), x + w * 0.055, y + headerH * 0.22)
  if subtitle and subtitle ~= "" then
    if metaFont then G.setFont(metaFont) end
    G.setColor(1, 1, 1, 0.58)
    G.print(clipped(subtitle, G.getFont(), w * 0.89),
      x + w * 0.055, y + headerH * 0.68)
  end
end

local function footer(G, text, x, y, w, h, gap, wh, s, warning)
  local metaFont = font(math.max(10 * s, wh * 0.013))
  if metaFont then G.setFont(metaFont) end
  if warning and warning ~= "" then
    G.setColor(1, 0.86, 0.56, 0.96)
  else
    G.setColor(1, 1, 1, 0.58)
  end
  G.printf(cleanText(warning and warning ~= "" and warning or text),
    x + gap * 1.5, y + h - math.max(30 * s, wh * 0.037),
    w - gap * 3, "left")
end

-- Dynamic battle-selector geometry.  Ordinary party lists (6 + CANCEL),
-- Pokegear stations and the pause options all grow vertically before scrolling.
local function listGeometry(ww, wh, count, widthFrac, maxW, rowScale, maxRows)
  local s = uiScaleFor(ww, wh)
  local margin = math.max(18 * s, wh * 0.025)
  local w = math.min(ww * (widthFrac or 0.46), (maxW or 620) * s)
  local gap = math.max(7 * s, wh * 0.008)
  local headerH = math.max(48 * s, wh * 0.060)
  local footerH = math.max(42 * s, wh * 0.052)
  local baseRowH = math.max(48 * s,
    math.min(72 * s, wh * (rowScale or 0.070)))
  local minRowH = math.max(30 * s, wh * 0.040)
  local available = wh - margin * 2
  local requested = math.max(1, math.floor(tonumber(count) or 1))
  local rows = requested
  if tonumber(maxRows) and tonumber(maxRows) > 0 then
    rows = math.min(rows, math.max(1, math.floor(tonumber(maxRows))))
  end
  local rowH = baseRowH

  local function heightFor(n, rh)
    return headerH + rh * n + gap * (n + 1) + footerH
  end
  local h = heightFor(rows, rowH)
  if h > available then
    rowH = (available - headerH - footerH - gap * (rows + 1)) / rows
    if rowH < minRowH then
      rowH = minRowH
      rows = math.max(1, math.floor(
        (available - headerH - footerH - gap) / (rowH + gap)))
    end
    h = heightFor(rows, rowH)
  end
  local x = ww - w - margin
  local y = wh - h - margin
  local r = math.max(14 * s, wh * 0.022)
  return {
    x = x, y = y, w = w, h = h, rowH = rowH, gap = gap,
    headerH = headerH, footerH = footerH, r = r, s = s,
    rows = math.max(1, rows), margin = margin,
  }
end

-- Full-screen work area shared by the dedicated Gen-2 applications.  These
-- ratios are the responsive form of the accepted Kanto VASC ModernDex shell
-- (lib/ModernDex.lua: 512x288, 12px outer inset, 354px primary display,
-- 12px hinge and 122px action rail).  Keeping the geometry here means Gold,
-- Silver and Crystal retain their native screen objects while presenting the
-- same broad two-display composition as Kanto instead of two bottom popups.
local KANTO_DEX_PRIMARY = 354
local KANTO_DEX_RAIL = 122
local KANTO_DEX_GAP = 12

local function wideWorkspaceGeometry(ww, wh, opts)
  opts = opts or {}
  local s = uiScaleFor(ww, wh)
  local margin = math.max(14 * s, math.min(ww, wh) * 0.024)
  local x, y = margin, margin
  local w, h = math.max(1, ww - margin * 2), math.max(1, wh - margin * 2)
  local gap = math.max(9 * s, math.min(ww, wh) * 0.014)
  local headerH = math.max(64 * s, h * 0.105)
  local footerH = math.max(38 * s, h * 0.055)
  local contentY = y + headerH + gap
  local contentH = math.max(1, h - headerH - footerH - gap * 2)
  local contentW = math.max(1, w - gap * 2)
  local splitGap = gap
  local ratio = tonumber(opts.primaryRatio)
    or (KANTO_DEX_PRIMARY / (KANTO_DEX_PRIMARY + KANTO_DEX_RAIL))
  ratio = math.max(0.54, math.min(0.79, ratio))
  local primaryW = math.floor((contentW - splitGap) * ratio)
  local railW = math.max(1, contentW - splitGap - primaryW)
  local primaryFirst = opts.railFirst ~= true
  local primaryX = primaryFirst and (x + gap) or (x + gap + railW + splitGap)
  local railX = primaryFirst and (primaryX + primaryW + splitGap) or (x + gap)
  return {
    x=x, y=y, w=w, h=h, s=s, margin=margin, gap=gap,
    headerH=headerH, footerH=footerH,
    content={ x=x + gap, y=contentY, w=contentW, h=contentH },
    primary={ x=primaryX, y=contentY, w=primaryW, h=contentH },
    rail={ x=railX, y=contentY, w=railW, h=contentH },
  }
end
M.wideWorkspaceGeometry = wideWorkspaceGeometry

local function rectGeometry(rect, ww, wh, count, maxRows)
  local s = uiScaleFor(ww, wh)
  local gap = math.max(6 * s, math.min(ww, wh) * 0.009)
  local headerH = math.max(46 * s, rect.h * 0.105)
  local footerH = math.max(34 * s, rect.h * 0.065)
  local requested = math.max(1, math.floor(tonumber(count) or 1))
  local rows = math.min(requested,
    math.max(1, math.floor(tonumber(maxRows) or requested)))
  local available = rect.h - headerH - footerH - gap * (rows + 1)
  local rowH = math.max(28 * s, available / rows)
  return {
    x=rect.x, y=rect.y, w=rect.w, h=rect.h, s=s, gap=gap,
    margin=math.max(14 * s, math.min(ww, wh) * 0.024),
    headerH=headerH, footerH=footerH,
    rowH=rowH, rows=rows,
    r=math.max(13 * s, math.min(ww, wh) * 0.020),
  }
end

local function drawWideWorkspaceShell(ww, wh, title, subtitle, opts)
  local G = love.graphics
  local geo = wideWorkspaceGeometry(ww, wh, opts)
  G.setColor(0.006, 0.011, 0.022, 1)
  G.rectangle("fill", 0, 0, ww, wh)
  panel(geo.x, geo.y, geo.w, geo.h,
    math.max(16 * geo.s, geo.h * 0.024), 0.98, geo.s)
  header(G, title, subtitle, geo.x, geo.y, geo.w, geo.headerH, wh, geo.s)
  local accent = EDITION_ACCENTS[activeEdition] or EDITION_ACCENTS.crystal
  G.setColor(accent[1], accent[2], accent[3], 0.72)
  roundRect("fill", geo.x + geo.gap, geo.y + geo.headerH - geo.gap * 0.55,
    geo.w - geo.gap * 2, math.max(2 * geo.s, geo.gap * 0.22), geo.gap * 0.10)
  footer(G, opts and opts.footer or "", geo.x, geo.y, geo.w, geo.h,
    geo.gap, wh, geo.s)
  return geo
end

local function windowFirst(count, visible, cursor, engineScroll)
  count = math.max(0, tonumber(count) or 0)
  visible = math.max(1, tonumber(visible) or 1)
  cursor = math.max(1, math.min(count > 0 and count or 1,
    tonumber(cursor) or 1))
  if count <= visible then return 1 end
  local first = math.max(1, (tonumber(engineScroll) or 0) + 1)
  if cursor < first then first = cursor end
  if cursor > first + visible - 1 then first = cursor - visible + 1 end
  if first + visible - 1 > count then first = math.max(1, count - visible + 1) end
  return first
end

local function hpColor(ratio)
  if ratio <= 0.20 then return 0.95, 0.23, 0.18 end
  if ratio <= 0.50 then return 0.96, 0.72, 0.15 end
  return 0.24, 0.90, 0.46
end

-- rows: { name, meta, value, tag, disabled, hpRatio, accentText }
local function drawListPanel(ww, wh, title, subtitle, rows, cursor, engineScroll, opts)
  opts = opts or {}
  local G = love.graphics
  -- A nearly empty pocket or early-game Pokegear must still read as a real
  -- widescreen application, not collapse to a tiny lower-right popup.
  local layoutCount = math.max(#rows, tonumber(opts.minRows) or 5)
  local geo = opts.geo or listGeometry(ww, wh, layoutCount, opts.widthFrac,
    opts.maxW, opts.rowScale, opts.maxRows)
  panel(geo.x, geo.y, geo.w, geo.h, geo.r, opts.alpha or 0.82, geo.s)
  header(G, title, subtitle, geo.x, geo.y, geo.w, geo.headerH, wh, geo.s)

  local first = windowFirst(#rows, geo.rows, cursor, engineScroll)
  local nameFont = font(math.max(13 * geo.s, math.min(18 * geo.s, geo.rowH * 0.31)))
  local metaFont = font(math.max(9 * geo.s, math.min(12 * geo.s, geo.rowH * 0.22)))
  for slot = 1, geo.rows do
    local i = first + slot - 1
    local row = rows[i]
    if not row then break end
    local ry = geo.y + geo.headerH + geo.gap + (slot - 1) * (geo.rowH + geo.gap)
    local on = cursor and i == cursor
    if on then
      G.setColor(0.12, 0.29, 0.52, 0.96)
    else
      G.setColor(0.08, 0.17, 0.29, 0.92)
    end
    roundRect("fill", geo.x + geo.gap, ry, geo.w - geo.gap * 2,
      geo.rowH, geo.r * 0.55)
    if on then
      G.setColor(1.00, 0.71, 0.18, 0.98)
      G.setLineWidth(math.max(1, 2 * geo.s))
      roundRect("line", geo.x + geo.gap, ry, geo.w - geo.gap * 2,
        geo.rowH, geo.r * 0.55)
    end

    local lx = geo.x + geo.gap * 2.2
    local right = geo.x + geo.w - geo.gap * 2.2
    local maxTextW = geo.w - geo.gap * 4.4
    if nameFont then G.setFont(nameFont) end
    G.setColor(1, 1, 1, row.disabled and 0.38 or 0.98)
    local hasMeta = row.meta and cleanText(row.meta) ~= ""
    local nameY = hasMeta and (ry + geo.rowH * 0.13) or (ry + geo.rowH * 0.31)
    local nameText = cleanText(row.name or "")
    local valueText = cleanText(row.value)
    local valueW = 0
    if valueText ~= "" then
      -- Reserve enough room for short semantic labels (notably CURSOR on the
      -- Pokégear map) before clipping a potentially long place/value.  The
      -- old value-first layout could reduce the label budget to twenty pixels
      -- and turn CURSOR into CURS... even on a wide panel.
      local nameNaturalW = G.getFont():getWidth(nameText)
      local labelReserve = math.min(maxTextW * 0.48,
        math.max(nameNaturalW, maxTextW * 0.24))
      local valueBudget = math.max(20,
        maxTextW - labelReserve - geo.gap * 1.5)
      valueText = clipped(valueText, G.getFont(), valueBudget)
      valueW = G.getFont():getWidth(valueText)
    end
    G.print(clipped(nameText, G.getFont(),
      math.max(20, maxTextW - valueW - geo.gap * 1.5)), lx, nameY)
    if valueText ~= "" then
      G.setColor(1, 1, 1, row.disabled and 0.30 or 0.78)
      G.print(valueText, right - valueW, nameY)
    end

    if row.tag and cleanText(row.tag) ~= "" then
      if metaFont then G.setFont(metaFont) end
      local tag = cleanText(row.tag)
      local tw = G.getFont():getWidth(tag)
      G.setColor(1, 1, 1, 0.58)
      G.print(tag, right - tw, ry + geo.rowH * 0.60)
    end

    if hasMeta and geo.rowH >= 33 * geo.s then
      if metaFont then G.setFont(metaFont) end
      G.setColor(1, 1, 1, row.disabled and 0.28 or 0.60)
      local metaMax = geo.w - geo.gap * 4.4
      if row.tag then metaMax = metaMax * 0.70 end
      G.print(clipped(row.meta, G.getFont(), metaMax), lx, ry + geo.rowH * 0.60)
    end

    if row.hpRatio ~= nil and geo.rowH >= 43 * geo.s then
      local ratio = math.max(0, math.min(1, tonumber(row.hpRatio) or 0))
      local bx = lx
      local by = ry + geo.rowH * 0.48
      local bw = geo.w * 0.40
      local bh = math.max(5 * geo.s, geo.rowH * 0.075)
      G.setColor(0, 0, 0, 0.46)
      roundRect("fill", bx, by, bw, bh, bh * 0.5)
      local cr, cg, cb = hpColor(ratio)
      G.setColor(cr, cg, cb, 0.96)
      if ratio > 0 then
        roundRect("fill", bx, by, math.max(2 * geo.s, bw * ratio), bh, bh * 0.5)
      end
    end
  end

  -- Long lists (especially the 251-entry Pokédex) get a real viewport marker.
  -- The native Gen2 screen owns cursor/index movement; this bar only mirrors
  -- the custom viewport so every species remains reachable without letting
  -- hundreds of rows run past the bottom of the window.
  if opts.scrollbar and #rows > geo.rows then
    local trackX = geo.x + geo.w - math.max(6 * geo.s, geo.gap * 0.65)
    local trackY = geo.y + geo.headerH + geo.gap
    local trackH = geo.rows * geo.rowH + math.max(0, geo.rows - 1) * geo.gap
    local thumbH = math.max(18 * geo.s, trackH * (geo.rows / #rows))
    local denom = math.max(1, #rows - geo.rows)
    local frac = math.max(0, math.min(1, (first - 1) / denom))
    local thumbY = trackY + (trackH - thumbH) * frac
    G.setColor(1, 1, 1, 0.10)
    roundRect("fill", trackX, trackY, math.max(3 * geo.s, geo.gap * 0.24),
      trackH, math.max(2 * geo.s, geo.gap * 0.12))
    G.setColor(1, 1, 1, 0.52)
    roundRect("fill", trackX, thumbY, math.max(3 * geo.s, geo.gap * 0.24),
      thumbH, math.max(2 * geo.s, geo.gap * 0.12))
  end

  local footerText = opts.footer or
    "D-PAD / ARROWS SELECT    CROSS/A CONFIRM    CIRCLE/B BACK"
  footer(G, footerText, geo.x, geo.y, geo.w, geo.h, geo.gap, wh, geo.s,
    opts.warning)
  return geo, first
end

local function drawMessage(ww, wh, rightX, title, text, opts)
  text = cleanText(text)
  if text == "" then return nil end
  opts = opts or {}
  local s = uiScaleFor(ww, wh)
  local margin = math.max(18 * s, wh * 0.025)
  local available = math.max(0, (rightX or ww) - margin * 2)
  if available < 78 * s then return nil end
  local w = math.min(ww * (opts.widthFrac or 0.52), 720 * s, available)
  local h = math.max(74 * s, math.min(opts.maxH or 126 * s, wh * (opts.heightFrac or 0.15)))
  local x = margin
  local y = opts.y or (wh - h - margin)
  local r = math.max(14 * s, wh * 0.022)
  panel(x, y, w, h, r, opts.alpha or 0.78, s)

  local titleFont = font(math.max(15 * s, wh * 0.020))
  local bodyFont = font(math.max(11 * s, wh * 0.014))
  if title and title ~= "" then
    if titleFont then love.graphics.setFont(titleFont) end
    love.graphics.setColor(1, 1, 1, 0.96)
    love.graphics.print(clipped(title, love.graphics.getFont(), w - h * 0.42),
      x + h * 0.20, y + h * 0.14)
  end
  if bodyFont then love.graphics.setFont(bodyFont) end
  love.graphics.setColor(1, 1, 1, 0.64)
  love.graphics.printf(text, x + h * 0.20,
    y + (title and title ~= "" and h * 0.48 or h * 0.28),
    w - h * 0.40, "left")
  return { x = x, y = y, w = w, h = h, r = r, s = s }
end

local function drawTextPanelAt(rect, ww, wh, title, subtitle, text, footerText)
  local G = love.graphics
  local geo = rectGeometry(rect, ww, wh, 1, 1)
  panel(rect.x, rect.y, rect.w, rect.h, geo.r, 0.92, geo.s)
  header(G, title, subtitle, rect.x, rect.y, rect.w, geo.headerH, wh, geo.s)
  local pad = math.max(14 * geo.s, geo.gap * 1.8)
  local bodyY = rect.y + geo.headerH + pad
  local bodyH = rect.h - geo.headerH - geo.footerH - pad * 1.6
  G.setColor(1, 1, 1, 0.045)
  roundRect("fill", rect.x + pad, bodyY, rect.w - pad * 2,
    math.max(1, bodyH), geo.r * 0.55)
  local bodyFont = font(math.max(13 * geo.s, wh * 0.017))
  if bodyFont then G.setFont(bodyFont) end
  G.setColor(1, 1, 1, 0.72)
  G.printf(cleanText(text), rect.x + pad * 1.45, bodyY + pad * 1.15,
    rect.w - pad * 2.9, "left")
  footer(G, footerText or "", rect.x, rect.y, rect.w, rect.h,
    geo.gap, wh, geo.s)
  return geo
end

local function partyModelPanel(screen, mon, geo, ww, wh)
  local G = love.graphics
  local s = geo.s
  local x = geo.margin
  local y = geo.y
  local w = geo.x - geo.margin * 2
  local h = geo.h
  if w < math.max(170 * s, ww * 0.20) then return false end

  panel(x, y, w, h, geo.r, 0.80, s)
  local game = screen and screen.game
  local def = mon and game and game.data and game.data.pokemon
    and game.data.pokemon[mon.species]
  local speciesName = cleanText((def and def.name) or (mon and mon.species) or "POKéMON")
  local nickname = cleanText(mon and (mon.nickname or mon.name) or speciesName)
  local dex = def and tonumber(def.dex or def.index) or nil
  local subtitle = dex and (speciesName .. "    #" .. string.format("%03d", dex)) or speciesName
  if not mon then
    nickname, subtitle = "PARTY", "SELECT A POKéMON"
  elseif mon.isEgg then
    nickname, subtitle = cleanText(mon.nickname or "EGG"), "EGG"
  end
  header(G, nickname, subtitle, x, y, w, geo.headerH, wh, s)

  local infoH = math.max(112 * s, math.min(154 * s, h * 0.22))
  local modelTop = y + geo.headerH + geo.gap * 0.5
  local modelBottom = y + h - infoH - geo.gap * 1.5
  local modelH = math.max(40, modelBottom - modelTop)
  local modelX = x + geo.gap * 1.2
  local modelW = w - geo.gap * 2.4

  -- Subtle showroom floor.  The actual model canvas is transparent, so this
  -- reads through it and anchors hovering/flying Pokemon without pretending
  -- the party screen is a second overworld scene.
  G.setColor(1, 1, 1, 0.035)
  roundRect("fill", modelX, modelTop, modelW, modelH, geo.r * 0.62)
  G.setColor(1, 1, 1, 0.075)
  G.ellipse("fill", modelX + modelW * 0.50, modelTop + modelH * 0.82,
    modelW * 0.28, math.max(5 * s, modelH * 0.045))

  local preview, info = partyPreviewModule(), nil
  local canvas
  if mon and not mon.isEgg and preview and type(preview.render) == "function" then
    local ok, rendered, details = pcall(preview.render, screen, mon,
      math.min(modelW, 480), math.min(modelH, 480))
    if ok then canvas, info = rendered, details end
    if not ok then M.lastError = "Party model preview: " .. tostring(rendered) end
  end

  if canvas and type(canvas.getDimensions) == "function" then
    local cw, ch = canvas:getDimensions()
    if cw and ch and cw > 0 and ch > 0 then
      local k = math.min(modelW / cw, modelH / ch)
      local dw, dh = cw * k, ch * k
      G.setColor(1, 1, 1, 1)
      G.draw(canvas, modelX + (modelW - dw) * 0.5,
        modelTop + (modelH - dh) * 0.5, 0, k, k)
    end
  else
    local f1 = font(math.max(15 * s, wh * 0.019))
    local f2 = font(math.max(10 * s, wh * 0.013))
    local title
    local body
    if not mon then
      title, body = "SELECT A POKéMON", "THE STADIUM 2 MODEL WILL APPEAR HERE"
    elseif mon.isEgg then
      title, body = "EGG", "NO STADIUM MODEL UNTIL IT HATCHES"
    else
      title = "3D MODEL UNAVAILABLE"
      body = "IMPORT / BUILD THE STADIUM 2 MODEL PACK IN MOD OPTIONS"
      if info and info.error then body = "MODEL PREVIEW COULD NOT BE BUILT" end
    end
    if f1 then G.setFont(f1) end
    G.setColor(1, 1, 1, 0.82)
    G.printf(title, modelX + geo.gap, modelTop + modelH * 0.40,
      modelW - geo.gap * 2, "center")
    if f2 then G.setFont(f2) end
    G.setColor(1, 1, 1, 0.46)
    G.printf(body, modelX + geo.gap, modelTop + modelH * 0.52,
      modelW - geo.gap * 2, "center")
  end

  local ix = x + geo.gap
  local iy = y + h - infoH - geo.gap
  local iw = w - geo.gap * 2
  local ih = infoH
  G.setColor(1, 1, 1, 0.055)
  roundRect("fill", ix, iy, iw, ih, geo.r * 0.55)
  G.setColor(1, 1, 1, 0.13)
  G.setLineWidth(math.max(1, 1.5 * s))
  roundRect("line", ix, iy, iw, ih, geo.r * 0.55)

  if mon then
    local hp = math.max(0, tonumber(mon.hp) or 0)
    local maxHp = tonumber(mon.maxHp)
      or (type(mon.stats) == "table" and tonumber(mon.stats.hp)) or math.max(1, hp)
    maxHp = math.max(1, maxHp)
    local ratio = math.max(0, math.min(1, hp / maxHp))
    local labelFont = font(math.max(11 * s, wh * 0.014))
    local valueFont = font(math.max(13 * s, wh * 0.017))
    if labelFont then G.setFont(labelFont) end
    G.setColor(1, 1, 1, 0.52)
    G.print("LEVEL", ix + iw * 0.06, iy + ih * 0.14)
    G.print("STATUS", ix + iw * 0.56, iy + ih * 0.14)
    if valueFont then G.setFont(valueFont) end
    G.setColor(1, 1, 1, 0.94)
    G.print(tostring(tonumber(mon.level) or 1), ix + iw * 0.06, iy + ih * 0.34)
    local status = mon.isEgg and "EGG" or hp <= 0 and "FNT" or cleanText(mon.status or "OK")
    if status == "" then status = "OK" end
    G.print(status, ix + iw * 0.56, iy + ih * 0.34)

    if labelFont then G.setFont(labelFont) end
    local held = "---"
    if mon.item then
      local itemDef = game and game.data and game.data.items and game.data.items[mon.item]
      held = cleanText((itemDef and itemDef.name) or mon.item)
    end
    G.setColor(1, 1, 1, 0.52)
    G.print(clipped("HELD  " .. held, G.getFont(), iw * 0.88),
      ix + iw * 0.06, iy + ih * 0.56)
    G.print("HP  " .. tostring(hp) .. " / " .. tostring(maxHp),
      ix + iw * 0.06, iy + ih * 0.71)
    local bx, by = ix + iw * 0.06, iy + ih * 0.88
    local bw, bh = iw * 0.88, math.max(6 * s, ih * 0.055)
    G.setColor(0, 0, 0, 0.48)
    roundRect("fill", bx, by, bw, bh, bh * 0.5)
    local cr, cg, cb = hpColor(ratio)
    G.setColor(cr, cg, cb, 0.97)
    if ratio > 0 then
      roundRect("fill", bx, by, math.max(2 * s, bw * ratio), bh, bh * 0.5)
    end
  else
    local f = font(math.max(12 * s, wh * 0.015))
    if f then G.setFont(f) end
    G.setColor(1, 1, 1, 0.52)
    G.printf("3D PARTY SHOWCASE", ix, iy + ih * 0.42, iw, "center")
  end
  return true
end

local function drawSmallChoice(ww, wh, title, subtitle, labels, cursor, opts)
  opts = opts or {}
  local G = love.graphics
  local s = uiScaleFor(ww, wh)
  local margin = math.max(18 * s, wh * 0.025)
  local count = math.max(1, #labels)
  local w = math.min(ww * (opts.widthFrac or 0.30), (opts.maxW or 390) * s)
  local gap = math.max(7 * s, wh * 0.008)
  local headerH = math.max(44 * s, wh * 0.054)
  local footerH = math.max(34 * s, wh * 0.044)
  local available = wh - margin * 2
  local rowH = math.max(36 * s, math.min(60 * s,
    (available - headerH - footerH - gap * (count + 1)) / count))
  local h = headerH + rowH * count + gap * (count + 1) + footerH
  local x = opts.x or margin
  local y = opts.y or (wh - h - margin)
  local r = math.max(14 * s, wh * 0.022)
  panel(x, y, w, h, r, 0.84, s)
  header(G, title, subtitle, x, y, w, headerH, wh, s)
  local f = font(math.max(13 * s, math.min(18 * s, rowH * 0.31)))
  for i, label in ipairs(labels) do
    local ry = y + headerH + gap + (i - 1) * (rowH + gap)
    local on = i == cursor
    if on then
      G.setColor(0.12, 0.29, 0.52, 0.96)
    else
      G.setColor(0.08, 0.17, 0.29, 0.92)
    end
    roundRect("fill", x + gap, ry, w - gap * 2, rowH, r * 0.55)
    if on then
      G.setColor(1.00, 0.71, 0.18, 0.98)
      G.setLineWidth(math.max(1, 2 * s))
      roundRect("line", x + gap, ry, w - gap * 2, rowH, r * 0.55)
    end
    if f then G.setFont(f) end
    G.setColor(1, 1, 1, 0.98)
    G.print(clipped(label, G.getFont(), w - gap * 4.4),
      x + gap * 2.2, ry + rowH * 0.30)
  end
  footer(G, opts.footer or "CROSS/A CONFIRM    CIRCLE/B BACK",
    x, y, w, h, gap, wh, s)
  return { x = x, y = y, w = w, h = h, s = s }
end

local function countTruthy(t)
  local n = 0
  for _, v in pairs(type(t) == "table" and t or {}) do if v then n = n + 1 end end
  return n
end

local function stackTop(game)
  local stack = game and game.stack
  if not (stack and type(stack.top) == "function") then return nil end
  local ok, top = pcall(stack.top, stack)
  return ok and top or nil
end

local function openedFromPause(game)
  local top = stackTop(game)
  if not top then return false end
  if StartMenuClass and getmetatable(top) == StartMenuClass then return true end
  return top._stadium2PauseSkinChain == true
end

local function specialBattleScreen(screen)
  if type(screen) ~= "table" then return false end
  local battle = type(screen.battle) == "table" and screen.battle or {}
  return screen.tutorial == true or screen.contest == true
    or screen.safari == true or screen.link == true
    or battle.tutorial == true or battle.contest == true
    or battle.safari == true or battle.link == true
end

local function partyContext(game, path, opts)
  local top = stackTop(game)
  if specialBattleScreen(opts) then return nil end
  if type(top) == "table"
      and top._vascGen2PartyUiContext then
    return top._vascGen2PartyUiContext
  end
  if type(top) == "table" and type(top.battle) == "table"
      and tostring(top.phase or "") == "submenu" then
    if specialBattleScreen(top) then return nil end
    return "battle"
  end
  if path == "src.ui.gen2.PcMenu" or path == "src.ui.gen2.CenterPcMenu"
      or path == "src.ui.gen2.ItemPcMenu" then return "menu" end
  if openedFromPause(game) then
    if path == "src.ui.gen2.PartyMenu" or path == "src.ui.gen2.SummaryMenu" then
      return "party"
    end
    return "menu"
  end
  -- Screens.push builds the destination before pushing it.  Depending on the
  -- engine version, Game2 may already have popped/replaced the START screen at
  -- that instant, so relying on `stack:top()` alone made the exact same normal
  -- PARTY/PACK/CARD/POKEGEAR opening randomly lose its ORAS skin.  Ordinary
  -- Gen-2 screens are presentation-safe by construction: their update,
  -- callbacks and save ownership remain native.  Make the advertised ORAS
  -- default deterministic, while the explicit special-battle guard above
  -- keeps tutorial/contest/Safari/link flows native.
  if path == "src.ui.gen2.PartyMenu" or path == "src.ui.gen2.SummaryMenu" then
    return "party"
  end
  return "menu"
end

local packRenderer

local function pcRenderer(screen, ww, wh)
  if screen.phase == "deposit" and type(screen.pack) == "table" then
    return packRenderer(screen.pack, ww, wh)
  end
  if not beginDraw(ww, wh, screen) then return false end
  local rows = {}
  local itemList = (screen.phase == "withdraw" or screen.phase == "toss")
    and type(screen.rows) == "table"
  if itemList then
    for _, entry in ipairs(screen.rows) do
      rows[#rows + 1] = { name = cleanText(entry.name or entry.label or entry.id),
        value = entry.count and ("×" .. tostring(entry.count)) or "" }
    end
    rows[#rows + 1] = { name = "CANCEL", meta = "BACK TO PC" }
  else
    for _, entry in ipairs(type(screen.entries) == "table" and screen.entries or {}) do
      rows[#rows + 1] = { name = cleanText(entry.label or entry.name or entry.id),
        meta = (entry.id == "seeya" or entry.id == "turnoff"
          or entry.id == "logoff") and "BACK" or "OPEN" }
    end
  end
  local title = itemList and (tostring(screen.phase):upper() .. " ITEM")
    or "POKéMON PC"
  local cursor = itemList and tonumber(screen.listIndex) or tonumber(screen.index)
  local geo = drawListPanel(ww, wh, title, "JOHTO STORAGE SYSTEM", rows,
    cursor or 1, tonumber(screen.scroll) or 0, {
      widthFrac = 0.50, maxW = 680, rowScale = 0.064,
      footer = "D-PAD SELECT    CROSS/A CONFIRM    CIRCLE/B BACK" })
  local message = screen.message
  if type(message) == "table" then
    message = message.pages and message.pages[message.page or 1] or message
    if type(message) == "table" then message = table.concat(message, " ") end
  end
  if screen.qtyState then
    local q = screen.qtyState
    message = table.concat(q.prompt or {}, " ") .. "  ×" .. tostring(q.qty or 1)
  elseif screen.confirm then
    local c = screen.confirm
    message = table.concat(c.prompt or {}, " ") .. "  "
      .. ((c.choice or 1) == 1 and "YES" or "NO")
  end
  drawMessage(ww, wh, geo.x, "PC",
    message or (itemList and "Choose an item." or "Choose a storage function."))
  endDraw()
  return true
end

local drawCrystalFront

local function boxMonName(mon)
  return cleanText(mon and (mon.nickname or mon.name or mon.species) or "POKéMON")
end

local function boxMonTypes(screen, mon)
  local game = screen and screen.game
  local def = mon and game and game.data and game.data.pokemon
    and game.data.pokemon[mon.species]
  local types = def and def.types or mon and mon.types
  if type(types) ~= "table" then return "—" end
  local labels = {}
  for i = 1, math.min(2, #types) do
    labels[#labels + 1] = cleanText(types[i])
  end
  return #labels > 0 and table.concat(labels, " / ") or "—"
end

local function drawBoxDetail(screen, mon, rect, ww, wh, prompt)
  local G = love.graphics
  local geo = rectGeometry(rect, ww, wh, 1, 1)
  panel(rect.x, rect.y, rect.w, rect.h, geo.r, 0.94, geo.s)
  header(G, mon and boxMonName(mon) or "ASC BOX",
    mon and ("SLOT " .. tostring(tonumber(screen.index) or 1))
      or tostring(screen.phase or screen.mode or "STORAGE"):upper(),
    rect.x, rect.y, rect.w, geo.headerH, wh, geo.s)
  local pad = math.max(10 * geo.s, geo.gap * 1.35)
  local bodyY = rect.y + geo.headerH + pad
  local bodyBottom = rect.y + rect.h - geo.footerH - pad
  local artH = math.max(88 * geo.s, (bodyBottom - bodyY) * 0.43)
  G.setColor(0.04, 0.11, 0.20, 0.90)
  roundRect("fill", rect.x + pad, bodyY, rect.w - pad * 2, artH,
    geo.r * 0.45)

  if mon then
    drawCrystalFront(screen, mon, rect.x + pad * 1.2, bodyY + pad * 0.35,
      rect.w - pad * 2.4, artH - pad * 0.7, "box")
  else
    local emptyFont = font(math.max(18 * geo.s, wh * 0.022))
    if emptyFont then G.setFont(emptyFont) end
    G.setColor(1, 1, 1, 0.30)
    G.printf(screen.phase == "insert" and "INSERT POSITION" or "NO POKéMON",
      rect.x + pad, bodyY + artH * 0.45, rect.w - pad * 2, "center")
  end

  local infoY = bodyY + artH + pad
  local infoH = math.max(1, bodyBottom - infoY)
  G.setColor(1, 1, 1, 0.045)
  roundRect("fill", rect.x + pad, infoY, rect.w - pad * 2, infoH,
    geo.r * 0.40)
  local labelFont = font(math.max(9 * geo.s, wh * 0.011))
  local valueFont = font(math.max(11 * geo.s, wh * 0.014))
  if mon then
    local hp = math.max(0, tonumber(mon.hp) or 0)
    local maxHp = tonumber(mon.maxHp)
      or (type(mon.stats) == "table" and tonumber(mon.stats.hp)) or math.max(1, hp)
    maxHp = math.max(1, maxHp)
    local rows = {
      { "LEVEL", tostring(tonumber(mon.level) or 1) },
      { "TYPE", boxMonTypes(screen, mon) },
      { "HP", tostring(hp) .. " / " .. tostring(maxHp) },
      { "ITEM", cleanText(mon.item or "—") },
    }
    local rowH = infoH / (#rows + 1)
    for i, row in ipairs(rows) do
      local ry = infoY + (i - 1) * rowH
      if labelFont then G.setFont(labelFont) end
      G.setColor(1, 1, 1, 0.46)
      G.print(row[1], rect.x + pad * 1.55, ry + rowH * 0.28)
      if valueFont then G.setFont(valueFont) end
      G.setColor(1, 1, 1, 0.92)
      G.printf(clipped(row[2], G.getFont(), rect.w * 0.50), rect.x + rect.w * 0.42,
        ry + rowH * 0.24, rect.w * 0.45 - pad, "right")
    end
    local ratio = math.max(0, math.min(1, hp / maxHp))
    local bx, by = rect.x + pad * 1.55, infoY + infoH - rowH * 0.48
    local bw, bh = rect.w - pad * 3.1, math.max(5 * geo.s, rowH * 0.16)
    G.setColor(0, 0, 0, 0.45); roundRect("fill", bx, by, bw, bh, bh * 0.5)
    local cr, cg, cb = hpColor(ratio)
    G.setColor(cr, cg, cb, 0.96)
    if ratio > 0 then roundRect("fill", bx, by, math.max(2 * geo.s, bw * ratio), bh, bh * 0.5) end
  end
  footer(G, prompt or "CHOOSE A POKéMON", rect.x, rect.y, rect.w, rect.h,
    geo.gap, wh, geo.s, screen.message)
  return geo
end

local function boxRenderer(screen, ww, wh)
  if not beginDraw(ww, wh, screen) then return false end
  local G = love.graphics
  local list = type(screen.list) == "function" and screen:list() or {}
  if type(list) ~= "table" then list = {} end
  local title = type(screen.title) == "function" and screen:title() or "POKéMON BOX"
  local prompt = type(screen.prompt) == "function" and screen:prompt()
    or screen.message or "Choose a POKéMON."
  local mode = tostring(screen.mode or "storage"):upper()
  local workspace = drawWideWorkspaceShell(ww, wh, "ASC BOX",
    cleanText(title) .. " / " .. mode, {
      primaryRatio=0.73,
      footer=screen.phase == "insert"
        and "UP/DOWN POSITION    LEFT/RIGHT BOX    CROSS/A INSERT    CIRCLE/B CANCEL"
        or "UP/DOWN POKéMON    LEFT/RIGHT BOX    CROSS/A ACTION    CIRCLE/B BACK",
    })

  local primary = workspace.primary
  local geo = rectGeometry(primary, ww, wh, 1, 1)
  panel(primary.x, primary.y, primary.w, primary.h, geo.r, 0.94, geo.s)
  local capacity = 20
  local isParty = screen.mode == "deposit"
  if type(screen.isParty) == "function" then
    local ok, value = pcall(screen.isParty, screen, screen.boxIndex)
    if ok and value then isParty = true end
  end
  if isParty then capacity = 6 end
  header(G, cleanText(title),
    (isParty and "PARTY" or "JOHTO STORAGE") .. "    "
      .. tostring(#list) .. " / " .. tostring(capacity),
    primary.x, primary.y, primary.w, geo.headerH, wh, geo.s)

  local pad = math.max(7 * geo.s, geo.gap)
  local cancelH = math.max(30 * geo.s, primary.h * 0.075)
  local gridX = primary.x + pad
  local gridY = primary.y + geo.headerH + pad
  local gridW = primary.w - pad * 2
  local gridH = primary.h - geo.headerH - geo.footerH - pad * 3 - cancelH
  local gridRows = capacity == 6 and 3 or 5
  local gridCols = math.ceil(capacity / gridRows)
  local cellGap = math.max(5 * geo.s, pad * 0.62)
  local cellW = (gridW - cellGap * (gridCols - 1)) / gridCols
  local cellH = (gridH - cellGap * (gridRows - 1)) / gridRows
  local accent = EDITION_ACCENTS[activeEdition] or EDITION_ACCENTS.crystal
  local selectedIndex = tonumber(screen.index) or 1
  local inserting = screen.phase == "insert"
  local movingFrom = type(screen.moveFrom) == "table" and screen.moveFrom or nil

  for slot = 1, capacity do
    -- Native Bills-PC input is a vertical five-row list. Lay the wide grid out
    -- column-major so UP/DOWN still moves visibly up/down; LEFT/RIGHT continues
    -- to change boxes exactly as the cartridge rules require.
    local col = math.floor((slot - 1) / gridRows)
    local row = (slot - 1) % gridRows
    local cx = gridX + col * (cellW + cellGap)
    local cy = gridY + row * (cellH + cellGap)
    local mon = list[slot]
    local on = selectedIndex == slot and (inserting or mon ~= nil)
    local from = movingFrom and tonumber(movingFrom.box) == tonumber(screen.boxIndex)
      and tonumber(movingFrom.slot) == slot
    G.setColor(on and 0.12 or 0.045, on and 0.29 or 0.11,
      on and 0.50 or 0.19, mon and 0.96 or 0.68)
    roundRect("fill", cx, cy, cellW, cellH, geo.r * 0.34)
    if on or from then
      local color = from and { 1.00, 0.48, 0.24 } or accent
      G.setColor(color[1], color[2], color[3], 0.98)
      G.setLineWidth(math.max(1, 2 * geo.s))
      roundRect("line", cx, cy, cellW, cellH, geo.r * 0.34)
    end
    if mon then
      local artW = math.min(cellW * 0.43, cellH * 0.82)
      drawCrystalFront(screen, mon, cx + cellGap * 0.45,
        cy + cellGap * 0.15, artW, cellH - cellGap * 0.30, "box")
      local nameFont = font(math.max(9 * geo.s, math.min(13 * geo.s, cellH * 0.19)))
      local metaFont = font(math.max(8 * geo.s, math.min(10 * geo.s, cellH * 0.15)))
      local tx = cx + artW + cellGap * 0.85
      local tw = cellW - artW - cellGap * 1.30
      if nameFont then G.setFont(nameFont) end
      G.setColor(1, 1, 1, 0.96)
      G.print(clipped(boxMonName(mon), G.getFont(), tw), tx, cy + cellH * 0.25)
      if metaFont then G.setFont(metaFont) end
      G.setColor(1, 1, 1, 0.56)
      G.print("LV " .. tostring(tonumber(mon.level) or 1), tx, cy + cellH * 0.58)
    else
      local emptyFont = font(math.max(10 * geo.s, cellH * 0.17))
      if emptyFont then G.setFont(emptyFont) end
      G.setColor(1, 1, 1, on and 0.72 or 0.18)
      G.printf(on and "INSERT" or "—", cx, cy + cellH * 0.40, cellW, "center")
    end
  end

  local cancelY = gridY + gridH + pad
  local cancelSelected = not inserting and selectedIndex > #list
  G.setColor(cancelSelected and 0.12 or 0.05, cancelSelected and 0.29 or 0.12,
    cancelSelected and 0.50 or 0.20, 0.96)
  roundRect("fill", gridX, cancelY, gridW, cancelH, geo.r * 0.32)
  if cancelSelected then
    G.setColor(accent[1], accent[2], accent[3], 0.98)
    G.setLineWidth(math.max(1, 2 * geo.s))
    roundRect("line", gridX, cancelY, gridW, cancelH, geo.r * 0.32)
  end
  local cancelFont = font(math.max(10 * geo.s, wh * 0.012))
  if cancelFont then G.setFont(cancelFont) end
  G.setColor(1, 1, 1, inserting and 0.22 or 0.90)
  G.printf(inserting and "INSERT MODE / B CANCELS" or "CANCEL / BACK",
    gridX, cancelY + cancelH * 0.30, gridW, "center")
  footer(G, "COLUMN-MAJOR / NATIVE BILLS-PC INPUT", primary.x, primary.y,
    primary.w, primary.h, geo.gap, wh, geo.s)

  local selected = list[selectedIndex]
  drawBoxDetail(screen, selected, workspace.rail, ww, wh, cleanText(prompt))
  if screen.phase == "submenu" and type(screen.submenuRows) == "function" then
    local ok, labels = pcall(screen.submenuRows, screen)
    if ok and type(labels) == "table" then
      drawSmallChoice(ww, wh, "POKéMON", "WHAT'S UP?", labels,
        tonumber(screen.submenuIndex) or 1, {
          x=workspace.rail.x + workspace.rail.w * 0.06,
          y=workspace.rail.y + workspace.rail.h * 0.54,
          widthFrac=0.24, maxW=workspace.rail.w * 0.88,
      })
    end
  end
  if screen._vascGen2SearchOpen then
    local lang = presentationLanguage(screen.game)
    local modeLabels = lang == "de"
      and { name="NAME", type="TYP", gender="GESCHLECHT" }
      or { name="NAME", type="TYPE", gender="GENDER" }
    local results = screen._vascGen2SearchResults or {}
    local selected = tonumber(screen._vascGen2SearchIndex) or 1
    local first = math.max(1, math.min(selected - 3, math.max(1, #results - 6)))
    local labels = {}
    for index = first, math.min(#results, first + 6) do
      local result = results[index]
      labels[#labels + 1] = ("BOX %02d / %02d   %s"):format(
        tonumber(result.box) or 0, tonumber(result.slot) or 0,
        boxMonName(result.mon))
    end
    if #labels == 0 then
      labels[1] = lang == "de" and "KEINE TREFFER" or "NO MATCHES"
    end
    local query = tostring(screen._vascGen2SearchQuery or "")
    if screen._vascGen2SearchEditing then query = query .. "|" end
    if query == "" then query = lang == "de" and "TIPPE..." or "TYPE..." end
    drawSmallChoice(ww, wh,
      (lang == "de" and "SUCHE " or "SEARCH ")
        .. modeLabels[screen._vascGen2SearchMode or "name"],
      query .. (lang == "de" and ("    %d TREFFER"):format(#results)
        or ("    %d MATCHES"):format(#results)), labels,
      #results == 0 and 1 or selected - first + 1, {
        x=ww * 0.19, y=wh * 0.14, widthFrac=0.62, maxW=900,
        footer=lang == "de"
          and "TEXT EINGEBEN    SELECT MODUS    A FINDEN    B ZURÜCK"
          or "TYPE QUERY    SELECT MODE    A LOCATE    B BACK",
      })
  end
  diagnosticOnce(screen, "box-dedicated", "gen2-menu-provider", {
    screen="BOX", provider="gen2-oras-box-grid", result="drawn",
    mode=screen.mode, phase=screen.phase, count=#list,
  })
  endDraw()
  return true
end

local function mailboxRenderer(screen, ww, wh)
  if not beginDraw(ww, wh, screen) then return false end
  local box = type(screen.box) == "function" and screen:box() or {}
  local rows = {}
  for _, entry in ipairs(type(box) == "table" and box or {}) do
    rows[#rows + 1] = { name = cleanText(entry.author or "UNKNOWN"),
      meta = cleanText(entry.type or "MAIL") }
  end
  if #rows == 0 then rows[1] = { name = "NO MAIL", disabled = true } end
  local geo = drawListPanel(ww, wh, "MAIL BOX", "JOHTO PC", rows,
    tonumber(screen.index) or 1, tonumber(screen.scroll) or 0, {
      widthFrac = 0.47, maxW = 630, rowScale = 0.070,
      footer = "D-PAD SELECT    CROSS/A ACTION    CIRCLE/B BACK" })
  local message
  if screen.message then
    message = screen.message.pages and screen.message.pages[screen.message.page or 1]
  elseif screen.confirm then
    local c = screen.confirm
    message = c.pages and c.pages[c.page or 1]
    if (tonumber(c.page) or 1) >= #(c.pages or {}) then
      message = type(message) == "table" and table.concat(message, " ") or message
      message = tostring(message or "") .. "  "
        .. ((c.choice or 1) == 1 and "YES" or "NO")
    end
  end
  if type(message) == "table" then message = table.concat(message, " ") end
  drawMessage(ww, wh, geo.x, "MAIL",
    message or "Read, return to the Pack, or attach the selected letter.")
  if screen.submenu then
    drawSmallChoice(ww, wh, "MAIL ACTION", "SELECTED LETTER",
      { "READ MAIL", "PUT IN PACK", "ATTACH MAIL", "CANCEL" },
      tonumber(screen.submenu.index) or 1,
      { widthFrac = 0.30, maxW = 410 })
  end
  endDraw()
  return true
end

local function decorationRenderer(screen, ww, wh)
  if not beginDraw(ww, wh, screen) then return false end
  local labels = {}
  local cursor, scroll = tonumber(screen.index) or 1, tonumber(screen.scroll) or 0
  if screen.mode == "side" then
    labels = { "RIGHT SIDE", "LEFT SIDE", "CANCEL" }
    cursor, scroll = tonumber(screen.sideIndex) or 1, 0
  elseif screen.mode == "items" then
    for _, decoId in ipairs(type(screen.rows) == "table" and screen.rows or {}) do
      local name = type(screen.rowName) == "function" and screen:rowName(decoId)
        or decoId
      labels[#labels + 1] = cleanText(name)
    end
  else
    for _, category in ipairs(type(screen.categories) == "table"
        and screen.categories or {}) do
      labels[#labels + 1] = cleanText(category.label or category.id)
    end
    labels[#labels + 1] = "EXIT"
  end
  local rows = {}
  for _, label in ipairs(labels) do rows[#rows + 1] = { name = label } end
  local mode = tostring(screen.mode or "category"):upper()
  local geo = drawListPanel(ww, wh, "DECORATION", mode, rows, cursor, scroll, {
    widthFrac = 0.48, maxW = 650, rowScale = 0.062, maxRows = 8,
    footer = "D-PAD SELECT    CROSS/A PLACE    CIRCLE/B BACK" })
  local message = screen.pages and screen.pages[screen.pageIndex or 1]
  drawMessage(ww, wh, geo.x, "ROOM",
    message or "Choose a decoration category and placement.")
  endDraw()
  return true
end

-- Resolve the actual Gen-II species behind the cart's localized display name.
-- NamingScreen receives only `monName` from several native call sites (fresh
-- catches, Bill's PC and the Name Rater), so presentation must not require a
-- new semantic argument from the engine.
local function namingSpecies(screen)
  local cached = rawget(screen, "_vascGen2NamingSpecies")
  if cached ~= nil then return cached or nil end
  local wanted = cleanText(screen.monName or ""):upper()
  local pokemon = screen.game and screen.game.data and screen.game.data.pokemon
  local found
  if type(pokemon) == "table" then
    if pokemon[wanted] then
      found = wanted
    else
      for id, def in pairs(pokemon) do
        local name = cleanText(type(def) == "table" and def.name or ""):upper()
        if tostring(id):upper() == wanted or (wanted ~= "" and name == wanted) then
          found = id
          break
        end
      end
    end
  end
  rawset(screen, "_vascGen2NamingSpecies", found or false)
  return found
end

local function kascCrystalFront(game, monOrSpecies, kind)
  if not (game and monOrSpecies) then return nil end
  local mon = type(monOrSpecies) == "table" and monOrSpecies or nil
  local species = mon and mon.species or monOrSpecies
  if not species then return nil end
  if type(Gen2CrystalFronts) == "table"
      and type(Gen2CrystalFronts.resolve) == "function" then
    local ok, result = pcall(Gen2CrystalFronts.resolve, game, monOrSpecies,
      { kind=kind or "menu" })
    if ok and type(result) == "table" and type(result.path) == "string" then
      return result.path, true
    end
  end
  if not (mod and type(mod.find) == "function") then return nil end
  local okHandle, handle = pcall(mod.find, "kanto_ascendant")
  if not (okHandle and handle and type(handle.exports) == "table") then return nil end
  local provider = handle.exports.crystalSpriteProvider
  if type(provider) == "table" and tonumber(provider.apiVersion) == 1
      and type(provider.resolveFront) == "function" then
    local ok, result = pcall(provider.resolveFront, game.data,
      mon or { species=species },
      { kind=kind or "menu", source="vasc_gen2_ui" })
    if ok and type(result) == "table" and type(result.path) == "string"
        and result.path ~= "" then
      return result.path, result.trueColor ~= false
    end
  end
  local animation = handle.exports.crystalAnimation
  if type(animation) == "table" and type(animation.staticFrameOne) == "function" then
    local shiny = type(Gen2CrystalFronts) == "table"
      and type(Gen2CrystalFronts.isShiny) == "function"
      and Gen2CrystalFronts.isShiny(mon) or false
    local ok, path = pcall(animation.staticFrameOne, {
      data=game.data, species=species, mon=mon or { species=species },
      kind=kind or "menu", source="vasc_gen2_ui",
    }, "front", shiny and "shiny" or "normal")
    if ok and type(path) == "string" and path ~= "" then return path, true end
  end
  return nil
end

local function crystalFrontFor(screen, monOrSpecies, kind)
  local mon = type(monOrSpecies) == "table" and monOrSpecies or nil
  local species = mon and mon.species or monOrSpecies
  local shiny = false
  if mon and type(Gen2CrystalFronts) == "table"
      and type(Gen2CrystalFronts.isShiny) == "function" then
    local ok, value = pcall(Gen2CrystalFronts.isShiny, mon)
    shiny = ok and value == true
  end
  local key = tostring(species or "") .. "#" .. tostring(kind or "menu")
    .. (shiny and "#shiny" or "#normal")
  local cache = rawget(screen, "_vascGen2CrystalFronts")
  if type(cache) ~= "table" then
    cache = {}
    rawset(screen, "_vascGen2CrystalFronts", cache)
  end
  if cache[key] ~= nil then return cache[key] or nil end
  local game = screen.game
  local path, trueColor = kascCrystalFront(game, monOrSpecies, kind)
  if not path then
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    path = def and def.spriteFront
    trueColor = def and def.trueColor and true or false
  end
  local Assets = engineAssetModule()
  if not (Assets and path) then cache[key] = false return nil end
  local ok, image = pcall(Assets.image, path)
  if not (ok and image) then cache[key] = false return nil end
  if type(image.setFilter) == "function" then
    pcall(image.setFilter, image, "nearest", "nearest")
  end
  cache[key] = { image=image, trueColor=trueColor and true or false,
    species=species }
  return cache[key]
end

drawCrystalFront = function(screen, monOrSpecies, x, y, w, h, kind)
  local resolved = crystalFrontFor(screen, monOrSpecies, kind)
  if not resolved then return false end
  local mon = type(monOrSpecies) == "table" and monOrSpecies or nil
  local species = mon and mon.species or monOrSpecies
  local G, image = love.graphics, resolved.image
  local iw, ih = image:getDimensions()
  local scale = math.min(w / math.max(1, iw), h / math.max(1, ih))
  scale = math.max(1, math.floor(scale))
  local dx = math.floor(x + (w - iw * scale) * 0.5)
  local dy = math.floor(y + h - ih * scale)
  local function body()
    G.setColor(1, 1, 1, 1)
    G.draw(image, dx, dy, 0, scale, scale)
  end
  local gameData = screen.game and screen.game.data
  local Palettes, Gbc = engineGen2Palettes(), engineGbcPalette()
  local colors = not resolved.trueColor and Palettes and gameData
    and type(Palettes.monColors) == "function"
    and Palettes.monColors(gameData.gen2Palettes, species) or nil
  if colors and Gbc and type(Gbc.with) == "function" then
    Gbc.with(colors, body)
  else
    body()
  end
  return true
end

-- A real widescreen nickname surface: large Crystal front, a readable live
-- name field and the native Gen-II keyboard/cursor model. Only drawing is
-- replaced; NamingScreen:update/accept/delete/case logic remains the engine's.
local function namingRenderer(screen, ww, wh)
  if not beginDraw(ww, wh, screen) then return false end
  local G = love.graphics
  local s = uiScaleFor(ww, wh)
  local margin = math.max(22 * s, math.min(ww, wh) * 0.035)
  local r = math.max(15 * s, math.min(ww, wh) * 0.020)
  local x, y = margin, margin
  local w, h = ww - margin * 2, wh - margin * 2

  G.setColor(0.010, 0.018, 0.034, 1)
  G.rectangle("fill", 0, 0, ww, wh)
  panel(x, y, w, h, r, 0.96, s)

  local headerH = math.max(66 * s, h * 0.105)
  local titleFont = font(math.max(20 * s, wh * 0.027))
  local metaFont = font(math.max(11 * s, wh * 0.014))
  if titleFont then G.setFont(titleFont) end
  G.setColor(1, 1, 1, 0.98)
  G.print(screen.monName and localized(screen.game, "NICKNAME", "SPITZNAME") or localized(screen.game, "NAME ENTRY", "NAMENSEINGABE"),
    x + w * 0.035, y + headerH * 0.20)
  if metaFont then G.setFont(metaFont) end
  G.setColor(1, 1, 1, 0.58)
  local subtitle = screen.monName and
    (cleanText(screen.monName) .. " / CRYSTAL FRONT") or cleanText(screen.prompt)
  G.print(clipped(subtitle, G.getFont(), w * 0.90),
    x + w * 0.035, y + headerH * 0.67)

  local gap = math.max(10 * s, h * 0.016)
  local bodyY = y + headerH + gap
  local footerH = math.max(42 * s, h * 0.065)
  local bodyH = h - headerH - footerH - gap * 2
  local previewW = math.max(190 * s, math.min(w * 0.29, 360 * s))
  local px, py = x + gap, bodyY
  local pw, ph = previewW, bodyH
  G.setColor(0.06, 0.14, 0.25, 0.88)
  roundRect("fill", px, py, pw, ph, r * 0.70)
  G.setColor(1, 1, 1, 0.09)
  roundRect("line", px, py, pw, ph, r * 0.70)

  local species = namingSpecies(screen)
  local artTop = py + ph * 0.09
  local artH = ph * 0.58
  if not (species and drawCrystalFront(screen, species,
      px + pw * 0.08, artTop, pw * 0.84, artH, "nickname")) then
    if screen.iconImage then
      local iw, ih = screen.iconImage:getDimensions()
      local frameW, frameH = math.min(16, iw), math.min(16, ih)
      local q = G.newQuad(0, 0, frameW, frameH, iw, ih)
      local k = math.max(2, math.floor(math.min(pw * 0.65 / frameW,
        artH * 0.65 / frameH)))
      G.setColor(1, 1, 1, 1)
      G.draw(screen.iconImage, q, px + (pw - frameW * k) * 0.5,
        artTop + (artH - frameH * k) * 0.5, 0, k, k)
    end
  end
  if metaFont then G.setFont(metaFont) end
  G.setColor(1, 1, 1, 0.48)
  G.printf(localized(screen.game, "YOUR NAME", "DEIN NAME"), px + gap, py + ph * 0.73, pw - gap * 2, "center")
  local nameFont = font(math.max(19 * s, wh * 0.025))
  if nameFont then G.setFont(nameFont) end
  G.setColor(1, 1, 1, 0.98)
  local liveName = cleanText(screen.text)
  if liveName == "" then liveName = "_" end
  G.printf(liveName, px + gap, py + ph * 0.80, pw - gap * 2, "center")
  if metaFont then G.setFont(metaFont) end
  G.setColor(1, 1, 1, 0.42)
  G.printf(tostring(#tostring(screen.text or "")) .. " / "
      .. tostring(tonumber(screen.maxLength) or 10),
    px + gap, py + ph * 0.91, pw - gap * 2, "center")

  local kx = px + pw + gap
  local kw = x + w - gap - kx
  local ky, kh = bodyY, bodyH
  local rows = type(screen.rows) == "function" and screen:rows() or {}
  local totalRows = #rows + 1
  local rowGap = math.max(5 * s, kh * 0.012)
  local cellH = math.max(28 * s,
    (kh - rowGap * (totalRows + 1)) / totalRows)
  local cellW = (kw - rowGap * 10) / 9
  local cellFont = font(math.max(13 * s, math.min(cellH * 0.38, wh * 0.022)))
  for ri, row in ipairs(rows) do
    for ci = 1, 9 do
      local cx = kx + rowGap + (ci - 1) * (cellW + rowGap)
      local cy = ky + rowGap + (ri - 1) * (cellH + rowGap)
      local on = tonumber(screen.row) == ri - 1 and tonumber(screen.col) == ci - 1
      G.setColor(on and 0.14 or 0.07, on and 0.32 or 0.17,
        on and 0.54 or 0.29, 0.96)
      roundRect("fill", cx, cy, cellW, cellH, r * 0.28)
      if on then
        G.setColor(1.00, 0.72, 0.20, 1)
        G.setLineWidth(math.max(1, 2 * s))
        roundRect("line", cx, cy, cellW, cellH, r * 0.28)
      end
      if cellFont then G.setFont(cellFont) end
      G.setColor(1, 1, 1, 0.96)
      G.printf(cleanText(row[ci] or " "), cx, cy + cellH * 0.27, cellW, "center")
    end
  end
  local bottomY = ky + rowGap + #rows * (cellH + rowGap)
  local bottomLabels = { screen.lower and localized(screen.game, "UPPER", "GROSS") or localized(screen.game, "lower", "klein"), localized(screen.game, "DELETE", "LÖSCHEN"), localized(screen.game, "DONE", "FERTIG") }
  local target = type(screen.bottomTarget) == "function" and screen:bottomTarget()
    or math.floor((tonumber(screen.col) or 0) / 3) + 1
  local onBottom = tonumber(screen.row) == #rows
  local bw = (kw - rowGap * 4) / 3
  for i, label in ipairs(bottomLabels) do
    local bx = kx + rowGap + (i - 1) * (bw + rowGap)
    local on = onBottom and target == i
    G.setColor(on and 0.18 or 0.08, on and 0.36 or 0.19,
      on and 0.58 or 0.31, 0.97)
    roundRect("fill", bx, bottomY, bw, cellH, r * 0.30)
    if on then
      G.setColor(1.00, 0.72, 0.20, 1)
      G.setLineWidth(math.max(1, 2 * s))
      roundRect("line", bx, bottomY, bw, cellH, r * 0.30)
    end
    if cellFont then G.setFont(cellFont) end
    G.setColor(1, 1, 1, 0.96)
    G.printf(label, bx, bottomY + cellH * 0.27, bw, "center")
  end

  footer(G, localized(screen.game, "D-PAD: SELECT   A: ENTER   B: DELETE   START: DONE", "STEUERKREUZ: AUSWAHL   A: EINGEBEN   B: LÖSCHEN   START: FERTIG"),
    x, y, w, h, gap, wh, s)
  endDraw()
  return true
end

local function drawStarterCrystalCard(world, ww, wh)
  if not (world and world.pokePic and world.pokePicName) then return false end
  if not beginDraw(ww, wh, world) then return false end
  local G = love.graphics
  local s = uiScaleFor(ww, wh)
  local w = math.min(ww * 0.42, 560 * s)
  local h = math.min(wh * 0.64, 520 * s)
  local x, y = (ww - w) * 0.5, (wh - h) * 0.5
  local r = math.max(16 * s, h * 0.035)
  panel(x, y, w, h, r, 0.97, s)
  header(G, "DEIN STARTER?", cleanText(world.pokePicName),
    x, y, w, h * 0.18, wh, s)
  local artX, artY = x + w * 0.08, y + h * 0.20
  local artW, artH = w * 0.84, h * 0.60
  G.setColor(0.07, 0.16, 0.27, 0.94)
  roundRect("fill", artX, artY, artW, artH, r * 0.58)
  if not drawCrystalFront(world, world.pokePicName,
      artX + artW * 0.06, artY + artH * 0.04,
      artW * 0.88, artH * 0.90, "starter") then
    local image = world.pokePic
    local iw, ih = image:getDimensions()
    local k = math.max(1, math.floor(math.min(artW * 0.82 / iw, artH * 0.82 / ih)))
    local dx, dy = artX + (artW - iw * k) * 0.5, artY + (artH - ih * k) * 0.5
    local Pal = engineGbcPalette()
    local function body()
      G.setColor(1, 1, 1, 1)
      G.draw(image, dx, dy, 0, k, k)
    end
    if world.pokePicColors and Pal and type(Pal.with) == "function" then
      Pal.with(world.pokePicColors, body)
    else
      body()
    end
  end
  local f = font(math.max(13 * s, wh * 0.017))
  if f then G.setFont(f) end
  G.setColor(1, 1, 1, 0.72)
  G.printf("A/B: ANSEHEN   /   DANACH AUSWAHL BESTÄTIGEN",
    x + w * 0.06, y + h * 0.86, w * 0.88, "center")
  endDraw()
  return true
end

local function patchStarterPresentation()
  local ok, World = pcall(require, "src.world.gen2.World")
  if not (ok and type(World) == "table") then
    return false, "src.world.gen2.World unavailable"
  end
  if World._vascGen2CrystalStarterPresentation then return true end
  if not (mod and mod.hooks and type(mod.hooks.wrap) == "function") then
    return false, "render.hud hook unavailable"
  end

  -- World:draw renders into Gold's 160x144 cartridge canvas.  Drawing the
  -- widescreen card there made it clip away (and, depending on the canvas
  -- state, could cover the native starter picture without replacing it).
  -- Paint the card in the final screen-space HUD pass instead.  Script/input
  -- ownership remains completely native; this hook only replaces pixels.
  mod.hooks:wrap("render.hud", function(next, game, viewport)
    local out = next(game, viewport)
    if not (customUIEnabled() and optionUsesOras("qol_ui_skin")) then
      return out
    end
    local stack = game and game.stack
    local world = stack and (
      (type(stack.top) == "function" and stack:top())
      or (type(stack.states) == "table" and stack.states[#stack.states])
    )
    if not (world and world.pokePic and world.pokePicName) then return out end
    local ww = viewport and tonumber(viewport.width)
    local wh = viewport and tonumber(viewport.height)
    ww, wh = targetDimensions(ww, wh)
    local okDraw, err = pcall(drawStarterCrystalCard, world, ww, wh)
    if not okDraw then M.lastError = "starter: " .. tostring(err) end
    return out
  end, 15100)
  World._vascGen2CrystalStarterPresentation = true
  M.targets["render.hud#starter"] = true
  return true
end

local function contextUsesOras(context, path)
  if path == "src.ui.gen2.PackMenu" then
    local style = selectedBagStyle()
    return style == "oras_wide" or style == "frlg_wide"
  end
  if path == "src.ui.gen2.PokedexMenu" then return modernDexEnabled() end
  if context == "battle" then return optionUsesOras("pokemonUiBattleParty") end
  if context == "party" then return optionUsesOras("pokemonUiPartyMenu") end
  if context == "menu" then return customUIEnabled() and optionUsesOras("qol_ui_skin") end
  return false
end

local function partyRenderer(screen, ww, wh)
  if not beginDraw(ww, wh, screen) then return false end
  local party = type(screen.party) == "table" and screen.party or {}
  local rows = {}
  for i, mon in ipairs(party) do
    local hp = math.max(0, tonumber(mon.hp) or 0)
    local maxHp = tonumber(mon.maxHp)
      or (type(mon.stats) == "table" and tonumber(mon.stats.hp)) or math.max(1, hp)
    maxHp = math.max(1, maxHp)
    local name = cleanText(mon.nickname or mon.name or mon.species or "POKéMON")
    local status = mon.isEgg and "EGG" or hp <= 0 and "FNT" or cleanText(mon.status or "")
    local meta = ("LV %d    HP %d/%d"):format(tonumber(mon.level) or 1, hp, maxHp)
    if status ~= "" then meta = meta .. "    " .. status end
    rows[#rows + 1] = {
      name = name,
      meta = meta,
      hpRatio = hp / maxHp,
      tag = screen.switchFrom == i and "MOVE FROM" or nil,
    }
  end
  rows[#rows + 1] = { name = "CANCEL", meta = "BACK TO PAUSE MENU" }
  local prompt = cleanText(screen.switchFrom and "Move to where?" or screen.prompt or "Choose a POKéMON.")
  local geo = drawListPanel(ww, wh, "POKéMON", prompt, rows,
    tonumber(screen.index) or 1, 0, {
      widthFrac = 0.47, maxW = 630, rowScale = 0.067,
      footer = "D-PAD / ARROWS SELECT    CROSS/A CONFIRM    CIRCLE/B BACK",
    })

  local selectedIndex = tonumber(screen.index) or 1
  local selected = selectedIndex >= 1 and selectedIndex <= #party and party[selectedIndex] or nil
  if not partyModelPanel(screen, selected, geo, ww, wh) then
    drawMessage(ww, wh, geo.x, "POKéMON", prompt)
  end

  if screen.submenu and type(screen.submenu.items) == "table" then
    local labels = {}
    for _, item in ipairs(screen.submenu.items) do labels[#labels + 1] = cleanText(item.label or item.id) end
    local mon = screen.submenu.mon or party[screen.submenu.slot or screen.index]
    drawSmallChoice(ww, wh, cleanText(mon and (mon.nickname or mon.name or mon.species) or "POKéMON"),
      "ACTION", labels, tonumber(screen.submenu.index) or 1,
      { widthFrac = 0.31, maxW = 420,
        x = geo.x + geo.gap,
        y = geo.y + geo.headerH + geo.gap })
  end
  endDraw()
  return true
end

local drawInfoRows

local function summaryTypeText(screen)
  if type(screen.typeNames) ~= "function" then return "---" end
  local ok, first, second = pcall(screen.typeNames, screen)
  if not ok then return "---" end
  first, second = cleanText(first or "---"), cleanText(second or "")
  if second ~= "" then return first .. " / " .. second end
  return first
end

local function summaryItemText(screen)
  if type(screen.itemName) == "function" then
    local ok, value = pcall(screen.itemName, screen)
    if ok and value and value ~= "" then return cleanText(value) end
  end
  return "---"
end

local function summaryStatus(mon)
  if type(mon) ~= "table" then return "---" end
  if mon.isEgg then return "EGG" end
  if (tonumber(mon.hp) or 0) <= 0 then return "FNT" end
  local status = cleanText(mon.status or "")
  return status ~= "" and status or "OK"
end

local function summaryInsightMode()
  local value = tostring(modOption("statusValues", "off")):lower()
  if value == "full" then return "full" end
  if value == "dv" or value == "dvs" then return "dv" end
  return "off"
end

local function gen2DvValues(mon)
  local dvs = type(mon) == "table" and mon.dvs or nil
  if type(dvs) ~= "table" then return {} end
  local attack = math.max(0, math.min(15, tonumber(dvs.attack) or 0))
  local defense = math.max(0, math.min(15, tonumber(dvs.defense) or 0))
  local speed = math.max(0, math.min(15, tonumber(dvs.speed) or 0))
  local special = math.max(0, math.min(15,
    tonumber(dvs.special or dvs.specialAttack or dvs.specialDefense) or 0))
  local hp = tonumber(dvs.hp)
  if hp == nil then
    hp = (attack % 2) * 8 + (defense % 2) * 4
      + (speed % 2) * 2 + (special % 2)
  end
  return {
    hp=math.floor(hp), attack=math.floor(attack), defense=math.floor(defense),
    speed=math.floor(speed), special=math.floor(special),
  }
end

local function statInsight(mon, stat, mode)
  if mode == "off" then return nil end
  local dvs = gen2DvValues(mon)
  if dvs[stat] == nil then return nil end
  local text = "DV " .. tostring(dvs[stat])
  if mode == "full" then
    local statExp = type(mon) == "table" and mon.statExp or nil
    local expKey = (stat == "special") and "special" or stat
    local value = type(statExp) == "table" and tonumber(statExp[expKey]) or nil
    if value == nil and expKey == "special" and type(statExp) == "table" then
      value = tonumber(statExp.specialAttack or statExp.specialDefense)
    end
    text = text .. "    STAT EXP " .. tostring(math.max(0, math.floor(value or 0)))
  end
  return text
end

local function summaryMoveRows(screen, detailed)
  local rows = {}
  local moves = type(screen.moveList) == "function" and screen:moveList()
    or (screen.mon and screen.mon.moves) or {}
  for i = 1, 4 do
    local entry = moves[i]
    if entry then
      local name = type(screen.moveName) == "function" and screen:moveName(entry)
        or entry.id or ("MOVE " .. i)
      local maxPp = tonumber(entry.maxPp) or tonumber(entry.pp) or 0
      local value = ("PP %d/%d"):format(tonumber(entry.pp) or 0, maxPp)
      local meta = ""
      if detailed and type(screen.moveDef) == "function" then
        local ok, def = pcall(screen.moveDef, screen, entry.id)
        if ok and type(def) == "table" then
          local t = cleanText(def.type or "")
          local power = tonumber(def.power) or 0
          meta = t
          if power >= 2 then meta = meta .. (meta ~= "" and "    " or "") .. "POWER " .. tostring(power) end
        end
      end
      rows[#rows + 1] = { name = cleanText(name), value = value, meta = meta }
    else
      rows[#rows + 1] = { name = "---", value = "PP --/--", meta = "EMPTY MOVE SLOT", disabled = true }
    end
  end
  return rows
end

local function summaryRenderer(screen, ww, wh)
  if not beginDraw(ww, wh, screen) then return false end
  local mon = screen.mon
  local isEgg = type(mon) == "table" and mon.isEgg == true
  local geo

  if isEgg then
    local cycles = tonumber(mon.eggSteps) or 0
    local rows = {
      { "EGG", "HATCHING" },
      { "HATCH CYCLES", tostring(cycles) },
      { "STATUS", cycles < 6 and "VERY CLOSE" or cycles < 11 and "CLOSE" or "WAITING" },
    }
    geo = drawInfoRows(ww, wh, "POKéMON SUMMARY", "EGG", rows,
      { widthFrac = 0.46, maxW = 620, rowScale = 0.073,
        footer = "UP/DOWN POKéMON    CROSS/A OR CIRCLE/B BACK" })
  elseif screen.moveDetail then
    local rows = summaryMoveRows(screen, true)
    geo = drawListPanel(ww, wh, "MOVE DETAILS",
      cleanText(mon and (mon.nickname or mon.name or mon.species) or "POKéMON"),
      rows, tonumber(screen.moveIndex) or 1, 0,
      { widthFrac = 0.47, maxW = 630, rowScale = 0.074,
        footer = "UP/DOWN MOVE    LEFT/RIGHT POKéMON    CROSS/A PICK / PLACE    CIRCLE/B BACK" })
  else
    local page = tonumber(screen.page) or 1
    if page == 2 then
      local rows = { { "HELD ITEM", summaryItemText(screen), "SELECT OPENS MOVE DETAILS" } }
      for _, row in ipairs(summaryMoveRows(screen, false)) do
        rows[#rows + 1] = { row.name, row.value, row.meta }
      end
      geo = drawInfoRows(ww, wh, "POKéMON SUMMARY", "MOVES / ITEM", rows,
        { widthFrac = 0.47, maxW = 630, rowScale = 0.066,
          footer = "UP/DOWN POKéMON    LEFT/RIGHT PAGE    SELECT MOVE DETAILS    CIRCLE/B BACK" })
    elseif page == 3 then
      local stats = type(mon.stats) == "table" and mon.stats or {}
      local ot = type(screen.otName) == "function" and screen:otName() or "---"
      local otId = type(screen.otId) == "function" and screen:otId() or 0
      local insight = summaryInsightMode()
      local rows = {
        { "OT", cleanText(ot) },
        { "ID No.", string.format("%05d", tonumber(otId) or 0) },
        { "HP", tostring(tonumber(stats.hp) or tonumber(mon.maxHp) or 0),
          statInsight(mon, "hp", insight) },
        { "ATTACK", tostring(tonumber(stats.attack) or 0),
          statInsight(mon, "attack", insight) },
        { "DEFENSE", tostring(tonumber(stats.defense) or 0),
          statInsight(mon, "defense", insight) },
        { "SPCL. ATK", tostring(tonumber(stats.specialAttack) or 0),
          statInsight(mon, "special", insight) },
        { "SPCL. DEF", tostring(tonumber(stats.specialDefense) or 0),
          statInsight(mon, "special", insight) },
        { "SPEED", tostring(tonumber(stats.speed) or 0),
          statInsight(mon, "speed", insight) },
      }
      geo = drawInfoRows(ww, wh, "POKéMON SUMMARY", "STATS / TRAINER", rows,
        { widthFrac = 0.47, maxW = 630, rowScale = 0.052,
          footer = "UP/DOWN POKéMON    LEFT/RIGHT PAGE    CROSS/A BACK    CIRCLE/B BACK" })
    else
      local hp = math.max(0, tonumber(mon.hp) or 0)
      local maxHp = tonumber(mon.maxHp)
        or (type(mon.stats) == "table" and tonumber(mon.stats.hp)) or math.max(1, hp)
      maxHp = math.max(1, maxHp)
      local nextExp = type(screen.expToNext) == "function" and screen:expToNext() or 0
      local rows = {
        { "HP", tostring(hp) .. " / " .. tostring(maxHp) },
        { "STATUS", summaryStatus(mon) },
        { "TYPE", summaryTypeText(screen) },
        { "EXP POINTS", tostring(tonumber(mon.experience) or 0) },
        { "TO NEXT LEVEL", tostring(tonumber(nextExp) or 0) },
      }
      geo = drawInfoRows(ww, wh, "POKéMON SUMMARY", "STATUS / EXP", rows,
        { widthFrac = 0.47, maxW = 630, rowScale = 0.067,
          footer = "UP/DOWN POKéMON    LEFT/RIGHT PAGE    CROSS/A NEXT    CIRCLE/B BACK" })
    end
  end

  if geo then partyModelPanel(screen, mon, geo, ww, wh) end
  endDraw()
  return true
end

local packMessage

local function sharedMenu(screen, ww, wh, title, rows, index, scroll, footer, header)
  if not (SharedMenus and type(SharedMenus.draw) == "function") then
    return false
  end
  local items = {}
  for _, row in ipairs(rows or {}) do
    items[#items + 1] = {
      label=cleanText(row.label or row.name or ""),
      right=row.right ~= nil and cleanText(row.right)
        or (row.value ~= nil and cleanText(row.value) or nil),
      help=cleanText(row.help or row.meta or row.description or ""),
      disabled=row.disabled,
    }
  end
  local game = type(screen) == "table" and screen.game or nil
  local save = type(game) == "table" and game.save or nil
  local flags = type(save) == "table" and save.flags or nil
  local regionHeader = type(flags) == "table" and flags.HALL_OF_FAME == true
    and "VOXEL ASCENDANT / JOHTO / KANTO"
    or "VOXEL ASCENDANT / JOHTO"
  return SharedMenus.draw(screen, {
    title=title,
    header=header or regionHeader,
    items=items,
    index=index,
    scroll=scroll,
    footer=footer,
  }, ww, wh)
end

local PACK_POCKETS = {
  { id="items", label="ITEMS" },
  { id="balls", label="POKé BÄLLE" },
  { id="key", label="BASIS-ITEMS" },
  { id="tms", label="TM/HM" },
}

-- The physical Gen-2 PACK screen owns the sorting state, while the shared
-- ORAS presenter draws the visible header button through a narrow adapter.
-- Keep presentation-only state mirrored so every successful START press also
-- names the mode that was actually applied (A-Z, RELEVANZ, STÄRKE ↑).
local function mirrorPackSortState(screen)
  local adapter = type(screen) == "table"
    and rawget(screen, "__vascManualBagSortProxy") or nil
  if type(adapter) ~= "table" then return end
  adapter.__vascManualBagSortModeIndex =
    rawget(screen, "__vascManualBagSortModeIndex")
  adapter.__vascManualBagSortMode =
    rawget(screen, "__vascManualBagSortMode")
  adapter.__vascManualBagSortModeLabel =
    rawget(screen, "__vascManualBagSortModeLabel")
  adapter.__vascManualBagSortCount =
    rawget(screen, "__vascManualBagSortCount")
end

function M.pointerToBagLogical(_, x, y)
  local ww, wh = targetDimensions()
  local scale = math.min(ww / 512, wh / 288)
  local left = math.floor((ww - 512 * scale) / 2)
  local top = math.floor((wh - 288 * scale) / 2)
  return (x - left) / scale, (y - top) / scale
end

-- Gen 2 owns a four-pocket Bag.order list. START sorts only the currently
-- visible pocket, retaining the selected item and every other pocket's slots.
-- LEFT/RIGHT and SELECT never enter this path: those remain the cartridge
-- owner's pocket navigation and item-move commands respectively.
local function sortGen2Pocket(screen)
  if type(screen) ~= "table" or type(screen.save) ~= "table"
      or type(screen.save.inventory) ~= "table" then
    return false, "gen2-pack-save-unavailable"
  end
  local okBag, Bag = pcall(require, "src.inventory.Bag")
  if not okBag or type(Bag) ~= "table" or type(Bag.order) ~= "function" then
    return false, "gen2-pack-order-unavailable"
  end
  local okOrder, order = pcall(Bag.order, screen.save, screen.bagData)
  if not okOrder or type(order) ~= "table" then
    return false, "gen2-pack-order-failed"
  end
  local pocket = type(screen.pocket) == "function" and screen:pocket() or nil
  local pocketId = type(pocket) == "table" and pocket.id or nil
  if not pocketId then return false, "gen2-pack-pocket-unavailable" end
  local pocketOf = type(screen.pocketOf) == "function"
    and function(id) return screen:pocketOf(id) end
    or function(id)
      local def = type(screen.items) == "table" and screen.items[id] or nil
      return type(def) == "table" and def.pocket or "ITEM"
    end
  local slots, ids = {}, {}
  for index, id in ipairs(order) do
    if pocketOf(id) == pocketId then
      slots[#slots + 1], ids[#ids + 1] = index, id
    end
  end
  if #ids < 2 then return true, "unchanged" end
  local selected = type(screen.rows) == "table" and screen.rows[screen.index]
  selected = type(selected) == "table" and selected.id or nil
  local mode = ManualBagSort and type(ManualBagSort.nextMode) == "function"
    and ManualBagSort.nextMode(screen, pocketId) or "alphabetical"
  if ManualBagSort and type(ManualBagSort.sortIds) == "function" then
    ids = ManualBagSort.sortIds(ids, screen.game, mode)
  else
    table.sort(ids, function(a, b)
      local ad = type(screen.items) == "table" and screen.items[a] or nil
      local bd = type(screen.items) == "table" and screen.items[b] or nil
      local an = cleanText(type(ad) == "table" and ad.name or a):upper()
      local bn = cleanText(type(bd) == "table" and bd.name or b):upper()
      if an == bn then return tostring(a) < tostring(b) end
      return an < bn
    end)
  end
  for index, slot in ipairs(slots) do order[slot] = ids[index] end
  if type(screen.rebuild) == "function" then screen:rebuild() end
  if selected ~= nil then
    for index, row in ipairs(type(screen.rows) == "table" and screen.rows or {}) do
      if row.id == selected then screen.index = index break end
    end
  end
  if type(screen.ensureVisible) == "function" then screen:ensureVisible() end
  if type(screen.storeCursor) == "function" then screen:storeCursor() end
  screen.__vascManualBagSortCount =
    (tonumber(screen.__vascManualBagSortCount) or 0) + 1
  mirrorPackSortState(screen)
  return true, "sorted", mode
end

M.sortGen2Pocket = sortGen2Pocket

local function packInteractionIdle(screen)
  return not (screen.qtyState or screen.switching or screen.message
    or screen.confirm or screen.submenu)
end

function M.handlePackStart(screen)
  local input = type(screen) == "table" and screen.game and screen.game.input
  if not (packInteractionIdle(screen) and input
      and type(input.wasPressed) == "function"
      and input:wasPressed("start")) then return false end
  local ok, reason = sortGen2Pocket(screen)
  return true, ok, reason
end

local function decoratePackInput(screen)
  if type(screen) ~= "table" or screen._vascGen2PackStartSort then return end
  local update = screen.update
  if type(update) ~= "function" then return end
  screen.update = function(self, ...)
    if contextUsesOras(self._vascGen2PartyUiContext,
        "src.ui.gen2.PackMenu") then
      local handled, ok, reason = M.handlePackStart(self)
      if handled then return ok, reason end
    end
    return update(self, ...)
  end
  screen._vascGen2PackStartSort = true
end

-- ASC BOX search parity for the native Gen-II Bills-PC owner.  The cartridge
-- still owns every box mutation and submenu action; this adapter only adds
-- the same START search surface/input seam used by Gen-I's ASC BOX.
local activeGen2SearchScreen
local SEARCH_MODES = { "name", "type", "gender" }
local GERMAN_TYPE_QUERY = {
  normal="normal", feuer="fire", wasser="water", elektro="electric",
  pflanze="grass", eis="ice", kampf="fighting", gift="poison",
  boden="ground", flug="flying", psycho="psychic", ["käfer"]="bug",
  kaefer="bug", gestein="rock", geist="ghost", drache="dragon",
  unlicht="dark", stahl="steel",
}

local function searchFold(value)
  value = tostring(value or "")
  value = value:gsub("A\204\136", "ä"):gsub("a\204\136", "ä")
    :gsub("O\204\136", "ö"):gsub("o\204\136", "ö")
    :gsub("U\204\136", "ü"):gsub("u\204\136", "ü")
  return value:lower():gsub("[_%-]+", " "):gsub("%s+", " ")
    :match("^%s*(.-)%s*$")
end

local function gen2SearchMatches(screen, mon, mode, query)
  query = searchFold(query)
  if query == "" or type(mon) ~= "table" then return false end
  if mode == "name" then
    local def = screen.game and screen.game.data and screen.game.data.pokemon
      and screen.game.data.pokemon[mon.species]
    return searchFold(mon.nickname):find(query, 1, true) ~= nil
      or searchFold(mon.species):find(query, 1, true) ~= nil
      or searchFold(def and def.name):find(query, 1, true) ~= nil
  elseif mode == "type" then
    query = GERMAN_TYPE_QUERY[query] or query
    local def = screen.game and screen.game.data and screen.game.data.pokemon
      and screen.game.data.pokemon[mon.species]
    for _, kind in ipairs((def and def.types) or mon.types or {}) do
      if searchFold(kind):find(query, 1, true) ~= nil then return true end
    end
  elseif mode == "gender" then
    local gender = searchFold(mon.gender or mon.sex)
    local wanted = ({ m="male", mann="male", ["männlich"]="male",
      maennlich="male", f="female", frau="female", weiblich="female",
      w="female", g="genderless", neutral="genderless" })[query] or query
    return gender == wanted or gender:find(wanted, 1, true) ~= nil
  end
  return false
end

local function rebuildGen2Search(screen)
  local results = {}
  local save = screen.game and screen.game.save or screen.save
  local boxes = type(save) == "table" and save.boxes or {}
  -- Crystal always owns fourteen boxes.  `ipairs` stops on the first sparse
  -- entry, which made every later box invisible to search on partially
  -- initialized/imported saves.
  for boxIndex = 1, math.max(14, #boxes) do
    local box = boxes[boxIndex]
    for slot, mon in ipairs(type(box) == "table" and box or {}) do
      if gen2SearchMatches(screen, mon, screen._vascGen2SearchMode,
          screen._vascGen2SearchQuery) then
        results[#results + 1] = { box=boxIndex, slot=slot, mon=mon }
      end
    end
  end
  screen._vascGen2SearchResults = results
  screen._vascGen2SearchIndex = #results == 0 and 1 or math.max(1,
    math.min(#results, tonumber(screen._vascGen2SearchIndex) or 1))
  return results
end

local function setGen2TextInput(screen, active)
  if active then activeGen2SearchScreen = screen
  elseif activeGen2SearchScreen == screen then activeGen2SearchScreen = nil end
  local keyboard = love and love.keyboard
  if keyboard and type(keyboard.setTextInput) == "function" then
    pcall(keyboard.setTextInput, active == true)
  end
end

local function beginGen2Search(screen)
  screen._vascGen2SearchOpen = true
  screen._vascGen2SearchEditing = true
  screen._vascGen2SearchMode = screen._vascGen2SearchMode or "name"
  screen._vascGen2SearchQuery = screen._vascGen2SearchQuery or ""
  screen._vascGen2SearchIndex = 1
  rebuildGen2Search(screen)
  setGen2TextInput(screen, true)
  return true
end

local function endGen2Search(screen)
  screen._vascGen2SearchOpen = false
  screen._vascGen2SearchEditing = false
  setGen2TextInput(screen, false)
  return true
end

local function removeLastUtf8(value)
  value = tostring(value or "")
  return value:gsub("[\128-\191]*[\1-\127\194-\244]$", "")
end

local function gen2SearchKey(screen, key)
  if not (screen and screen._vascGen2SearchOpen) then return false end
  if key == "backspace" or key == "delete" then
    screen._vascGen2SearchQuery = removeLastUtf8(screen._vascGen2SearchQuery)
    rebuildGen2Search(screen)
    return true
  elseif key == "escape" then
    return endGen2Search(screen)
  elseif key == "return" or key == "kpenter" then
    screen._vascGen2SearchEditing = false
    setGen2TextInput(screen, false)
    return true
  end
  return false
end

local function gen2SearchText(screen, value)
  if not (screen and screen._vascGen2SearchEditing)
      or type(value) ~= "string" then return false end
  local newline = value:find("[\r\n]")
  value = (newline and value:sub(1, newline - 1) or value)
    :gsub("[%z\1-\31\127]", "")
  if value ~= "" then
    screen._vascGen2SearchQuery = tostring(
      (screen._vascGen2SearchQuery or "") .. value):sub(1, 32)
    rebuildGen2Search(screen)
  end
  if newline then
    screen._vascGen2SearchEditing = false
    setGen2TextInput(screen, false)
  end
  return value ~= "" or newline ~= nil
end

local gen2TextInputBridgeInstalled = false
local function installGen2TextInputBridge()
  if not love or gen2TextInputBridgeInstalled then return end
  local previous = love.textinput
  -- The sandbox permits selected callback chains, but no private fields on
  -- love. Older hosts may reject even callbacks; their screen input remains
  -- available and opening the PC must still succeed.
  local installed = pcall(function()
    love.textinput = function(value, ...)
      if activeGen2SearchScreen
          and gen2SearchText(activeGen2SearchScreen, value) then return true end
      if type(previous) == "function" then return previous(value, ...) end
    end
  end)
  gen2TextInputBridgeInstalled = installed
end

local function handleGen2SearchInput(screen)
  local input = screen.game and screen.game.input
  if not (input and type(input.wasPressed) == "function") then return false end
  if not screen._vascGen2SearchOpen then
    if input:wasPressed("start") then return beginGen2Search(screen) end
    return false
  end
  if input:wasPressed("b") then return endGen2Search(screen) end
  if input:wasPressed("start") then
    screen._vascGen2SearchEditing = true
    setGen2TextInput(screen, true)
    return true
  end
  if input:wasPressed("select") then
    local current = screen._vascGen2SearchMode or "name"
    local index = 1
    for i, value in ipairs(SEARCH_MODES) do if value == current then index = i end end
    screen._vascGen2SearchMode = SEARCH_MODES[index % #SEARCH_MODES + 1]
    screen._vascGen2SearchQuery = ""
    screen._vascGen2SearchIndex = 1
    rebuildGen2Search(screen)
    return true
  end
  local results = screen._vascGen2SearchResults or {}
  if input:wasPressed("up") or input:wasPressed("down") then
    if #results > 0 then
      local delta = input:wasPressed("down") and 1 or -1
      screen._vascGen2SearchIndex =
        ((screen._vascGen2SearchIndex - 1 + delta) % #results) + 1
    end
    return true
  end
  if input:wasPressed("a") and #results > 0 then
    local result = results[screen._vascGen2SearchIndex or 1]
    screen.boxIndex, screen.index, screen.scroll = result.box, result.slot,
      math.max(0, result.slot - 5)
    if type(screen.clampIndex) == "function" then screen:clampIndex() end
    return endGen2Search(screen)
  end
  return true
end

local function decorateBoxSearch(screen)
  if type(screen) ~= "table" or screen._vascGen2BoxSearch then return screen end
  local update = screen.update
  if type(update) ~= "function" then return screen end
  installGen2TextInputBridge()
  screen.update = function(self, ...)
    if handleGen2SearchInput(self) then return end
    return update(self, ...)
  end
  screen.onKeyPressed = function(self, key) return gen2SearchKey(self, key) end
  screen.textinput = function(self, value) return gen2SearchText(self, value) end
  screen._vascGen2BoxSearch = true
  return screen
end

local function decoratePackSortButton(screen, adapter)
  if not (ManualBagSort and type(ManualBagSort.decorate) == "function") then
    return false, "manual-sort-provider-unavailable"
  end
  local okFont, Font = pcall(require, "src.render.Font")
  if not okFont then Font = nil end
  local sortOk, _, sortClaimed, sortReason = pcall(
    ManualBagSort.decorate, adapter, {
      Font=Font,
      sort=function() return sortGen2Pocket(screen) end,
    })
  if not sortOk or sortClaimed ~= true then
    local reason = tostring(sortOk and sortReason or sortClaimed)
    adapter.__vascManualBagSortLastError = reason
    return false, reason
  end
  screen.__vascManualBagSortProxy = adapter
  mirrorPackSortState(screen)
  return true
end

M.decoratePackSortButton = decoratePackSortButton

local function packBagAdapter(screen)
  local adapter = rawget(screen, "_vascGen2OrasBagAdapter")
  local style = selectedBagStyle()
  local language = presentationLanguage(screen.game)
  if adapter and adapter._vascGen2BagStyle == style and adapter.language == language then return adapter end
  local provider = style == "frlg_wide" and SharedFrlgBag or SharedBag
  if style == "external" then return nil, "GAME DEFAULT selected" end
  if not (provider and type(provider.decorate) == "function") then
    return nil, style .. " provider unavailable"
  end
  adapter = {
    game=screen.game,
    title=localized(screen.game, "BAG", "TASCHE"),
    items={}, index=1, scroll=0, rows=9,
    draw=function() end,
    __pockets=PACK_POCKETS,
    __pocketCount=#PACK_POCKETS,
    _vascGen2BagStyle=style, language=language,
  }
  local ok, decorated, claimed, reason = pcall(provider.decorate, adapter, {
    wide=true,
    force=true,
    language=presentationLanguage(screen.game),
    enabled=function() return selectedBagStyle() == style end,
    loadImage=function(path)
      local assets = mod and mod.assets
      if not (assets and type(assets.image) == "function") then
        error("mod.assets:image unavailable")
      end
      return assets:image(path)
    end,
    resolveAccent=function()
      return tostring(modOption("qol_bag_color", "auto")):lower()
    end,
    resolveBody=function()
      local selected = tostring(modOption("qol_bag_body", "auto")):lower()
      if selected ~= "auto" then return selected end
      local save = adapter.game and adapter.game.save or {}
      local version = tostring(save.version or "crystal"):lower()
      if version == "gold" or version == "silver" or version == "crystal" then
        return version
      end
      return "crystal"
    end,
    resolveForm=function()
      return tostring(modOption("qol_bag_form", "auto")):lower()
    end,
    resolveChromeAccent=function()
      return editionChromeFor(screen)
    end,
    describeItem=function(item)
      return item and item.description or localized(screen.game, "Choose an item.", "Wähle ein Item.")
    end,
  })
  if not ok or decorated ~= adapter or claimed ~= true then
    return nil, tostring(ok and (reason or claimed) or decorated)
  end
  decoratePackSortButton(screen, adapter)
  rawset(screen, "_vascGen2OrasBagAdapter", adapter)
  return adapter
end

local function drawPackBag(screen, ww, wh)
  local style = selectedBagStyle()
  local adapter, err = packBagAdapter(screen)
  if not adapter then
    M.lastError = "PACK: " .. tostring(err)
    diagnosticOnce(screen, "pack-adapter", "gen2-menu-provider", {
      screen="PACK", provider=style, result="fallback",
      reason=M.lastError,
    })
    return false
  end
  local items = {}
  for _, entry in ipairs(type(screen.rows) == "table" and screen.rows or {}) do
    local def = type(screen.items) == "table" and screen.items[entry.id] or nil
    local right = entry.showCount and ("×" .. tostring(math.floor(tonumber(entry.count) or 0))) or ""
    if entry.teaches then right = cleanText(entry.teaches) end
    items[#items + 1] = {
      label=cleanText(entry.name or entry.id),
      value=entry.id,
      right=right,
      description=cleanText(def and (def.description or def.desc)
        or packMessage(screen)),
    }
  end
  items[#items + 1] = {
    label=localized(screen.game, "CANCEL", "ZURÜCK"), value="__cancel",
    description=localized(screen.game, "Return to the START menu.", "Zurück zum START-Menü."),
  }
  local pocket = type(screen.pocket) == "function" and screen:pocket() or {}
  adapter.game = screen.game
  adapter.items = items
  adapter.index = math.max(1, math.min(#items, tonumber(screen.index) or 1))
  adapter.scroll = math.max(0, tonumber(screen.scroll) or 0)
  adapter.__pocketIndex = math.max(1, math.min(#PACK_POCKETS,
    tonumber(screen.pocketIndex) or 1))
  adapter.__pocketId = PACK_POCKETS[adapter.__pocketIndex].id
  adapter.__pocketLabel = cleanText(pocket.label or PACK_POCKETS[adapter.__pocketIndex].label)
  adapter.money = function()
    local save = screen.save or (screen.game and screen.game.save) or {}
    local player = save.player or {}
    return tonumber(player.money) or tonumber(save.money) or 0
  end

  local G = love and love.graphics
  if not (G and type(G.newCanvas) == "function") then return false end
  local canvas = rawget(screen, "_vascGen2OrasBagCanvas")
  if not canvas then
    local ok, made = pcall(G.newCanvas, 512, 288)
    if not ok or not made then return false end
    canvas = made
    if type(canvas.setFilter) == "function" then
      pcall(canvas.setFilter, canvas, "nearest", "nearest")
    end
    rawset(screen, "_vascGen2OrasBagCanvas", canvas)
  end
  local previous = type(G.getCanvas) == "function" and G.getCanvas() or nil
  local okPaint, paintErr = xpcall(function()
    G.push("all")
    G.setCanvas(canvas)
    G.origin()
    G.clear(0, 0, 0, 1)
    adapter:draw()
    local providerError = adapter.__vascOrasBagLastError
      or adapter.__vascOrasFrlgBagLastError
    if providerError then
      error(providerError)
    end
    local wide = style == "frlg_wide"
      and adapter.__vascOrasFrlgBagWidePresentation
      or adapter.__vascOrasBagWidePresentation
    if wide ~= true then
      error(style .. " declined its wide presentation")
    end
    G.setCanvas(previous)
    G.pop()
  end, function(value)
    return debug and debug.traceback and debug.traceback(value, 2) or tostring(value)
  end)
  if not okPaint then
    pcall(G.setCanvas, previous)
    pcall(G.pop)
    M.lastError = "PACK: " .. tostring(paintErr)
    diagnosticOnce(screen, "pack-paint", "gen2-menu-provider", {
      screen="PACK", provider=style, result="error",
      reason=M.lastError,
    })
    return false
  end
  G.push("all")
  G.origin()
  G.setColor(0.005, 0.012, 0.025, 1)
  G.rectangle("fill", 0, 0, ww, wh)
  local scale = math.min(ww / 512, wh / 288)
  local x, y = math.floor((ww - 512 * scale) / 2),
    math.floor((wh - 288 * scale) / 2)
  G.setColor(1, 1, 1, 1)
  G.draw(canvas, x, y, 0, scale, scale)
  G.pop()
  M.draws = M.draws + 1
  diagnosticOnce(screen, "pack-active", "gen2-menu-provider", {
    screen="PACK", provider=style, result="active", items=#items,
  })
  return true
end

local PACK_ACTION = { use = "USE", give = "GIVE", toss = "TOSS", sel = "SEL", quit = "QUIT" }

packMessage = function(screen)
  local lines = screen.message or (screen.confirm and screen.confirm.prompt)
  if type(lines) == "table" then return table.concat(lines, " ") end
  if lines then return lines end
  if type(screen.description) == "function" then
    local ok, value = pcall(screen.description, screen)
    if ok then return value end
  end
  return ""
end

packRenderer = function(screen, ww, wh)
  local okShared, shared = pcall(drawPackBag, screen, ww, wh)
  if okShared and shared then return true end
  M.lastError = "PACK: " .. tostring(okShared and "provider declined" or shared)
  diagnosticOnce(screen, "pack-call", "gen2-menu-provider", {
    screen="PACK", provider=selectedBagStyle(), result="native-fallback",
    reason=M.lastError,
  })
  -- Returning false is deliberate: patchScreen immediately invokes the exact
  -- PackMenu draw it captured before VASC installed.  No second, approximate
  -- menu is allowed between a failed wide provider and GAME DEFAULT.
  return false
end

local function optionValue(screen, row)
  if not row then return "" end
  if row.cancel then return "" end
  if row.frame then return "TYPE " .. tostring((screen.options or {}).frame or 1) end
  if type(row.text) == "function" then
    local ok, value = pcall(row.text, screen.options or {})
    return ok and cleanText(value) or "?"
  end
  if row.values then
    local value = (screen.options or {})[row.key]
    if row.display then value = row.display[value] or value end
    return cleanText(value)
  end
  if type(row.value) == "function" then
    local ok, value = pcall(row.value, screen.game)
    return ok and cleanText(value) or "?"
  end
  return ""
end

local function optionsRenderer(screen, ww, wh)
  local rows = {}
  for _, row in ipairs(type(screen.rows) == "table" and screen.rows or {}) do
    rows[#rows + 1] = {
      name = cleanText(row.label or row.id or "OPTION"),
      value = optionValue(screen, row),
      meta = row.activate and "OPEN" or (row.cancel and "BACK" or "LEFT / RIGHT TO CHANGE"),
    }
  end
  local okShared, handled = pcall(sharedMenu, screen, ww, wh, "OPTIONEN",
    rows, tonumber(screen.index) or 1, tonumber(screen.scroll) or 0,
    "STEUERKREUZ: AUSWAHL   LINKS/RECHTS: ÄNDERN   A: OK   B: ZURÜCK")
  if okShared and handled then return true end
  if not okShared then M.lastError = "OPTIONS: " .. tostring(handled) end
  if not beginDraw(ww, wh, screen) then return false end
  local geo = drawListPanel(ww, wh, "OPTIONS", "GAME SETTINGS", rows,
    tonumber(screen.index) or 1, tonumber(screen.scroll) or 0, {
      widthFrac = 0.56, maxW = 760, rowScale = 0.060,
      footer = "D-PAD SELECT    LEFT/RIGHT CHANGE    CROSS/A APPLY    CIRCLE/B BACK",
    })
  drawMessage(ww, wh, geo.x, "OPTIONS",
    "Settings still use Gold's native OPTION logic. Changes are applied and persisted exactly as before.")
  endDraw()
  return true
end

local function saveSummary(screen)
  if SaveModule == nil then
    local ok, got = pcall(require, "src.core.gen2.Save")
    SaveModule = ok and got or false
  end
  if SaveModule and type(SaveModule.summary) == "function" then
    local ok, s = pcall(SaveModule.summary, screen.save)
    if ok and s then return s end
  end
  local save = screen.save or {}
  local player = save.player or {}
  local play = save.playTime or {}
  local caught = 0
  for _, v in pairs((save.pokedex and save.pokedex.caught) or {}) do if v then caught = caught + 1 end end
  return {
    name = player.name or "GOLD",
    badges = countTruthy(player.badges),
    caught = caught,
    hours = play.hours or 0,
    minutes = play.minutes or 0,
  }
end

drawInfoRows = function(ww, wh, title, subtitle, rows, opts)
  opts = opts or {}
  local fake = {}
  for _, row in ipairs(rows) do
    fake[#fake + 1] = { name = row[1], value = row[2], meta = row[3] }
  end
  return drawListPanel(ww, wh, title, subtitle, fake, nil, 0, opts)
end

local function saveRenderer(screen, ww, wh)
  local sum = saveSummary(screen)
  local info = {
    { "PLAYER", cleanText(sum.name or "GOLD") },
    { "BADGES", tostring(sum.badges or 0) },
    { "POKéDEX", tostring(sum.caught or 0) .. " CAUGHT" },
    { "TIME", ("%d:%02d"):format(tonumber(sum.hours) or 0, tonumber(sum.minutes) or 0) },
  }
  local sharedRows = {}
  for _, row in ipairs(info) do
    sharedRows[#sharedRows + 1] = { name=row[1], value=row[2], meta="Aktueller Spielstand." }
  end
  local prompt = type(screen.prompt) == "function" and screen:prompt() or {}
  local promptText = type(prompt) == "table" and table.concat(prompt, " ")
    or tostring(prompt or "")
  if screen.phase == "confirm" or screen.phase == "overwrite" then
    sharedRows = {
      { name="JA", meta=promptText ~= "" and promptText or "Spiel speichern." },
      { name="NEIN", meta="Ohne Speichern zurückkehren." },
    }
  end
  local okShared, handled = pcall(sharedMenu, screen, ww, wh,
    screen.phase == "overwrite" and "SPIELSTAND ÜBERSCHREIBEN?" or "SPEICHERN",
    sharedRows, tonumber(screen.choice) or 1, 0,
    "A: BESTÄTIGEN   B: ZURÜCK")
  if okShared and handled then return true end
  if not okShared then M.lastError = "SAVE: " .. tostring(handled) end
  if not beginDraw(ww, wh, screen) then return false end
  local geo = drawInfoRows(ww, wh, "SAVE GAME", "CURRENT PROGRESS", info,
    { widthFrac = 0.42, maxW = 560, rowScale = 0.067,
      footer = "GOLD'S NATIVE SAVE ROUTINE REMAINS AUTHORITATIVE" })
  local text = promptText
  drawMessage(ww, wh, geo.x, "SAVE", text)
  if screen.phase == "confirm" or screen.phase == "overwrite" then
    drawSmallChoice(ww, wh,
      screen.phase == "overwrite" and "OVERWRITE SAVE?" or "SAVE THE GAME?",
      "CONFIRM", { "YES", "NO" }, tonumber(screen.choice) or 1,
      { widthFrac = 0.29, maxW = 390 })
  end
  endDraw()
  return true
end

local JOHTO_BADGES = { "ZEPHYR", "HIVE", "PLAIN", "FOG", "STORM", "MINERAL", "GLACIER", "RISING" }
local KANTO_BADGES = { "BOULDER", "CASCADE", "THUNDER", "RAINBOW", "SOUL", "MARSH", "VOLCANO", "EARTH" }

-- Presentation-only atlas derived from the HGSS Badge Case sheet by Kyo Wolf.
-- The original 990x650 source, extraction script and provenance receipt live
-- outside the runtime asset root; this compact atlas contains sixteen 48px
-- leader cells followed by sixteen transparent 32px badge cells.
local TRAINER_CARD_BADGE_CASE_ART =
  "assets/ui/gen2/trainer_card/hgss_badge_case_runtime.png"
local TRAINER_CARD_REGIONS = {
  johto = {
    title = "JOHTO-ORDEN", titleEn = "JOHTO BADGES",
    leadersEn = { "FALKNER", "BUGSY", "WHITNEY", "MORTY", "CHUCK", "JASMINE", "PRYCE", "CLAIR" },
    badges = JOHTO_BADGES,
    leaders = { "FALK", "KAI", "BIANKA", "JENS", "HARTWIG", "JASMIN", "NORBERT", "SANDRA" },
    atlasRow = 0,
  },
  kanto = {
    title = "KANTO-ORDEN", titleEn = "KANTO BADGES",
    leadersEn = { "BROCK", "MISTY", "LT. SURGE", "ERIKA", "JANINE", "SABRINA", "BLAINE", "BLUE" },
    badges = KANTO_BADGES,
    leaders = { "ROCKO", "MISTY", "MAJOR BOB", "ERIKA", "JANINA", "SABRINA", "PYRO", "BLAU" },
    atlasRow = 1,
  },
}

local TRAINER_CARD_ART = {
  gold = "assets/trainers/gen2/players/gold_front_hd.png",
  silver = "assets/trainers/gen2/players/silver_front_hd.png",
  kris = "assets/trainers/gen2/players/kris_front_hd.png",
}

local TRAINER_CARD_ACCENT = {
  gold = { 0.92, 0.67, 0.13 },
  silver = { 0.68, 0.75, 0.84 },
  crystal = { 0.12, 0.78, 0.95 },
}

local function trainerCardEdition(save)
  local edition = tostring(save and save.version or "crystal"):lower()
  if edition ~= "gold" and edition ~= "silver" then edition = "crystal" end
  return edition
end

local function trainerCardRegionLabel(save)
  local flags = type(save) == "table" and save.flags or nil
  return type(flags) == "table" and flags.HALL_OF_FAME == true
    and "JOHTO / KANTO" or "JOHTO"
end

local function trainerCardImage(save)
  local player = save and save.player or {}
  -- Gold/Ethan is the male player in both Gold and Silver. `silver_front_hd`
  -- is the rival and must never be selected merely because the installed ROM
  -- is Pokémon Silver; edition changes chrome, player identity does not.
  local id = player.gender == "female" and "kris" or "gold"
  local path = TRAINER_CARD_ART[id]
  if TrainerCardImages[path] ~= nil then return TrainerCardImages[path] or nil, id end
  local assets = mod and mod.assets
  if not (assets and type(assets.image) == "function") then
    TrainerCardImages[path] = false
    return nil, id
  end
  local ok, image = pcall(assets.image, assets, path)
  if not ok or not image then
    TrainerCardImages[path] = false
    return nil, id
  end
  if type(image.setFilter) == "function" then pcall(image.setFilter, image, "nearest", "nearest") end
  TrainerCardImages[path] = image
  return image, id
end

local function trainerCardBadgeCase()
  if TrainerCardBadgeCase == false then return nil end
  if TrainerCardBadgeCase then return TrainerCardBadgeCase end
  local G = love and love.graphics
  local assets = mod and mod.assets
  if not (G and type(G.newQuad) == "function" and assets
      and type(assets.image) == "function") then
    TrainerCardBadgeCase = false
    return nil
  end
  local ok, image = pcall(assets.image, assets, TRAINER_CARD_BADGE_CASE_ART)
  if not ok or not image or type(image.getDimensions) ~= "function" then
    TrainerCardBadgeCase = false
    return nil
  end
  local width, height = image:getDimensions()
  if width ~= 384 or height ~= 160 then
    TrainerCardBadgeCase = false
    return nil
  end
  if type(image.setFilter) == "function" then
    pcall(image.setFilter, image, "nearest", "nearest")
  end
  local atlas = { image=image, leaders={ johto={}, kanto={} }, badges={ johto={}, kanto={} } }
  for regionIndex, regionName in ipairs({ "johto", "kanto" }) do
    for index=1,8 do
      atlas.leaders[regionName][index] = G.newQuad(
        (index-1)*48, (regionIndex-1)*48, 48, 48, width, height)
      atlas.badges[regionName][index] = G.newQuad(
        (index-1)*32, 96+(regionIndex-1)*32, 32, 32, width, height)
    end
  end
  TrainerCardBadgeCase = atlas
  return atlas
end

local function cardFrame(x, y, w, h, r, accent, alpha, s)
  local G = love.graphics
  G.setColor(0.018, 0.030, 0.055, alpha or 0.94)
  roundRect("fill", x, y, w, h, r)
  G.setColor(accent[1], accent[2], accent[3], 0.98)
  G.setLineWidth(math.max(2, 3 * s))
  roundRect("line", x, y, w, h, r)
end

local GEN2_BADGE_COLORS = {
  { .58, .82, .94 }, { .91, .72, .18 }, { .88, .45, .62 }, { .55, .38, .72 },
  { .25, .67, .84 }, { .72, .74, .78 }, { .54, .83, .94 }, { .42, .48, .82 },
}

local function trainerRegionBadgeOwned(player, regionName, index)
  local region = TRAINER_CARD_REGIONS[regionName] or TRAINER_CARD_REGIONS.johto
  local badges = player and (regionName == "kanto" and player.kantoBadges
    or player.badges) or {}
  return badges[index] == true or badges[region.badges[index]] == true
end

local function trainerRegionBadgeCount(player, regionName)
  local count = 0
  for index=1,8 do
    if trainerRegionBadgeOwned(player, regionName, index) then count = count + 1 end
  end
  return count
end

local function drawTrainerBadge(index, cx, cy, size, owned)
  local G = love.graphics
  local c = GEN2_BADGE_COLORS[index] or GEN2_BADGE_COLORS[1]
  local alpha = owned and 1 or .18
  G.setColor(0.004, 0.010, 0.020, .78)
  G.circle("fill", cx, cy, size * .54)
  G.setColor(c[1], c[2], c[3], alpha)
  if index == 1 then
    G.polygon("fill", cx, cy-size*.48, cx+size*.42, cy+size*.30,
      cx-size*.42, cy+size*.30)
  elseif index == 2 then
    G.polygon("fill", cx-size*.45, cy-size*.12, cx-size*.16, cy-size*.35,
      cx, cy-size*.08, cx+size*.16, cy-size*.35, cx+size*.45, cy-size*.12,
      cx+size*.22, cy+size*.38, cx-size*.22, cy+size*.38)
  elseif index == 3 then
    G.circle("fill", cx, cy, size*.39)
    G.setColor(1, .82, .64, alpha); G.circle("fill", cx, cy, size*.19)
  elseif index == 4 then
    G.polygon("fill", cx, cy-size*.48, cx+size*.18, cy-size*.15,
      cx+size*.45, cy, cx+size*.18, cy+size*.15, cx, cy+size*.48,
      cx-size*.18, cy+size*.15, cx-size*.45, cy, cx-size*.18, cy-size*.15)
  elseif index == 5 then
    G.polygon("fill", cx-size*.42, cy-size*.30, cx, cy-size*.08,
      cx+size*.42, cy-size*.30, cx+size*.18, cy+size*.40,
      cx, cy+size*.18, cx-size*.18, cy+size*.40)
  elseif index == 6 then
    G.polygon("fill", cx-size*.42, cy, cx-size*.20, cy-size*.38,
      cx+size*.20, cy-size*.38, cx+size*.42, cy,
      cx+size*.20, cy+size*.38, cx-size*.20, cy+size*.38)
    G.setColor(.10, .15, .22, alpha); G.circle("fill", cx, cy, size*.16)
  elseif index == 7 then
    for spoke=0,5 do
      local a=spoke*math.pi/3
      G.line(cx-math.cos(a)*size*.43, cy-math.sin(a)*size*.43,
        cx+math.cos(a)*size*.43, cy+math.sin(a)*size*.43)
    end
  else
    G.polygon("fill", cx, cy-size*.48, cx+size*.43, cy-size*.20,
      cx+size*.27, cy+size*.40, cx-size*.27, cy+size*.40,
      cx-size*.43, cy-size*.20)
  end
  G.setColor(1, 1, 1, owned and .32 or .08)
  G.setLineWidth(math.max(1, size*.07)); G.circle("line", cx, cy, size*.50)
  G.setLineWidth(1)
end

local function drawTrainerBadgeSprite(regionName, index, cx, cy, size, owned)
  local G = love.graphics
  local atlas = trainerCardBadgeCase()
  local quad = atlas and atlas.badges[regionName]
    and atlas.badges[regionName][index]
  if not quad then
    drawTrainerBadge(index, cx, cy, size, owned)
    return false
  end
  local scale = size / 32
  G.setColor(owned and 1 or .36, owned and 1 or .42, owned and 1 or .48,
    owned and 1 or .34)
  G.draw(atlas.image, quad, cx-size*.5, cy-size*.5, 0, scale, scale)
  G.setColor(1, 1, 1, 1)
  return true
end

local function drawTrainerLeaderTile(regionName, index, x, y, w, h, s, player, game)
  local G = love.graphics
  local region = TRAINER_CARD_REGIONS[regionName]
  local owned = trainerRegionBadgeOwned(player, regionName, index)
  local atlas = trainerCardBadgeCase()
  local accent = owned and TRAINER_CARD_ACCENT.gold or TRAINER_CARD_ACCENT.crystal
  G.setColor(.025, .055, .085, owned and .98 or .78)
  roundRect("fill", x, y, w, h, math.max(7*s, h*.10))
  G.setColor(accent[1], accent[2], accent[3], owned and .90 or .34)
  G.setLineWidth(math.max(1, owned and 2*s or s))
  roundRect("line", x, y, w, h, math.max(7*s, h*.10))

  local portraitSize = math.min(h*.76, w*.36)
  local portraitX = x + 8*s
  local portraitY = y + (h-portraitSize)*.5
  local leaderQuad = atlas and atlas.leaders[regionName]
    and atlas.leaders[regionName][index]
  if leaderQuad then
    local scale = portraitSize / 48
    G.setColor(owned and 1 or .45, owned and 1 or .52, owned and 1 or .58,
      owned and 1 or .58)
    G.draw(atlas.image, leaderQuad, portraitX, portraitY, 0, scale, scale)
  else
    G.setColor(TRAINER_CARD_ACCENT.crystal[1],
      TRAINER_CARD_ACCENT.crystal[2], TRAINER_CARD_ACCENT.crystal[3], .22)
    G.circle("fill", portraitX+portraitSize*.5, portraitY+portraitSize*.38,
      portraitSize*.23)
    roundRect("fill", portraitX+portraitSize*.23, portraitY+portraitSize*.60,
      portraitSize*.54, portraitSize*.30, portraitSize*.08)
  end

  local textX = portraitX + portraitSize + 8*s
  local textW = w - (textX-x) - 40*s
  local leaderText = localized(game, region.leadersEn[index], region.leaders[index])
  local function fittedFont(text, size)
    local pixels = math.max(5, math.floor(size + 0.5))
    local result = font(pixels)
    while result and textW > 0 and pixels > 5
        and result:getWidth(text) > textW do
      pixels = pixels - 1
      result = font(pixels)
    end
    return result
  end
  local leaderFont = fittedFont(leaderText, math.max(9*s, h*.14))
  local badgeFont = fittedFont(region.badges[index], math.max(7*s, h*.105))
  if leaderFont then G.setFont(leaderFont) end
  G.setColor(1, 1, 1, owned and .98 or .58)
  G.printf(leaderText, textX, y+h*.24, textW, "left")
  if badgeFont then G.setFont(badgeFont) end
  G.setColor(accent[1], accent[2], accent[3], owned and .92 or .42)
  G.printf(region.badges[index], textX, y+h*.56, textW, "left")
  drawTrainerBadgeSprite(regionName, index, x+w-24*s, y+h*.5,
    math.min(30*s, h*.45), owned)
  G.setLineWidth(1)
end

local function trainerBadgeCasePage(ww, wh, player, regionName, game)
  local G = love.graphics
  local region = TRAINER_CARD_REGIONS[regionName]
  local s = uiScaleFor(ww, wh)
  local margin = math.max(18*s, wh*.030)
  local w = math.min(ww-margin*2, (wh-margin*2)*1.60)
  local h = w/1.60
  local x, y = (ww-w)*.5, (wh-h)*.5
  local pad = math.max(15*s, w*.024)
  local radius = math.max(14*s, h*.045)
  local accent = regionName == "kanto" and TRAINER_CARD_ACCENT.silver
    or TRAINER_CARD_ACCENT.gold

  G.setColor(.012, .028, .052, 1); G.rectangle("fill", 0, 0, ww, wh)
  G.setColor(0, 0, 0, .48); roundRect("fill", x+7*s, y+9*s, w, h, radius)
  G.setColor(.012, .025, .046, .985); roundRect("fill", x, y, w, h, radius)
  G.setColor(accent[1], accent[2], accent[3], 1)
  G.setLineWidth(math.max(3, 4*s)); roundRect("line", x, y, w, h, radius)
  G.setColor(TRAINER_CARD_ACCENT.crystal[1], TRAINER_CARD_ACCENT.crystal[2],
    TRAINER_CARD_ACCENT.crystal[3], .92)
  G.setLineWidth(math.max(2, 2*s)); roundRect("line", x+8*s, y+8*s,
    w-16*s, h-16*s, radius*.76)

  local headerH = h*.15
  G.setColor(.025, .055, .085, .96)
  roundRect("fill", x+pad, y+pad, w-pad*2, headerH, radius*.38)
  local title = font(math.max(20*s, h*.060))
  local small = font(math.max(9*s, h*.022))
  if title then G.setFont(title) end
  G.setColor(1, 1, 1, .98)
  G.print(localized(game, region.titleEn, region.title), x+pad*1.7, y+pad*1.55)
  if small then G.setFont(small) end
  G.setColor(accent[1], accent[2], accent[3], 1)
  G.printf(tostring(trainerRegionBadgeCount(player, regionName)) .. " / 8",
    x+w*.70, y+pad*1.95, w*.25-pad, "right")

  local bodyX, bodyY = x+pad, y+pad+headerH+pad*.65
  local bodyW = w-pad*2
  local footerH = h*.075
  local bodyH = y+h-pad-footerH-bodyY
  local gap = math.max(7*s, w*.010)
  local tileW = (bodyW-gap*3)/4
  local tileH = (bodyH-gap)/2
  for index=1,8 do
    local column = (index-1)%4
    local row = math.floor((index-1)/4)
    drawTrainerLeaderTile(regionName, index,
      bodyX+column*(tileW+gap), bodyY+row*(tileH+gap), tileW, tileH, s, player, game)
  end
  if small then G.setFont(small) end
  G.setColor(1, 1, 1, .58)
  G.printf(localized(game, "LEFT/RIGHT: PAGE    A/B: BACK", "LINKS/RECHTS: SEITE    A/B: ZURÜCK"),
    x+pad, y+h-pad*1.25, w-pad*2, "center")
  return true
end

local function trainerCardMainPage(screen, ww, wh, save, player)
  local G = love.graphics
  local s = uiScaleFor(ww, wh)
  local margin = math.max(18 * s, wh * 0.030)
  local w = math.min(ww - margin * 2, (wh - margin * 2) * 1.60)
  local h = w / 1.60
  local x, y = (ww - w) * .5, (wh - h) * .5
  local r = math.max(14 * s, h * 0.045)
  local edition = trainerCardEdition(save)
  local accent = TRAINER_CARD_ACCENT[edition]
  -- KASC base-card composition: edition-coloured outer card, crystalline
  -- inner keyline, diagonal security texture and two deliberate columns.
  G.setColor(.012, .028, .052, 1); G.rectangle("fill", 0, 0, ww, wh)
  G.setColor(accent[1], accent[2], accent[3], .10)
  for off=-h,w,52*s do
    G.polygon("fill", x+off,y, x+off+18*s,y,
      x+off+h+18*s,y+h, x+off+h,y+h)
  end
  G.setColor(0,0,0,.48); roundRect("fill", x+7*s,y+9*s,w,h,r)
  G.setColor(.012,.025,.046,.985); roundRect("fill",x,y,w,h,r)
  G.setColor(accent[1],accent[2],accent[3],1)
  G.setLineWidth(math.max(3,4*s)); roundRect("line",x,y,w,h,r)
  G.setColor(TRAINER_CARD_ACCENT.crystal[1],TRAINER_CARD_ACCENT.crystal[2],
    TRAINER_CARD_ACCENT.crystal[3],.92)
  G.setLineWidth(math.max(2,2*s)); roundRect("line",x+8*s,y+8*s,w-16*s,h-16*s,r*.76)

  local pad = math.max(15 * s, w * 0.024)
  local headerH = h * .17
  local title = font(math.max(20 * s, h * .060))
  local brand = font(math.max(10 * s, h * .026))
  local small = font(math.max(9 * s, h * .022))
  local label = font(math.max(10 * s, h * .026))
  local value = font(math.max(14 * s, h * .037))
  G.setColor(.025,.055,.085,.96); roundRect("fill",x+pad,y+pad,w-pad*2,headerH,r*.38)
  if brand then G.setFont(brand) end
  G.setColor(accent[1],accent[2],accent[3],1)
  G.print("VOXEL ASCENDANT",x+pad*1.7,y+pad*1.45)
  if title then G.setFont(title) end
  G.setColor(1,1,1,.98); G.print(localized(screen.game, "TRAINER CARD", "TRAINERKARTE"),x+pad*1.7,y+pad*2.35)
  if small then G.setFont(small) end
  G.setColor(TRAINER_CARD_ACCENT.crystal[1],TRAINER_CARD_ACCENT.crystal[2],
    TRAINER_CARD_ACCENT.crystal[3],1)
  G.printf(edition:upper() .. " / " .. trainerCardRegionLabel(save),
    x+w*.61,y+pad*1.65,w*.34-pad,"right")
  G.setColor(accent[1],accent[2],accent[3],.95)
  G.rectangle("fill",x+pad,y+pad+headerH-3*s,w-pad*2,3*s)

  local bodyY = y + pad + headerH + pad*.70
  local bodyH = h - (bodyY-y) - pad*1.55
  local avatarW = w * .285
  local avatarX, avatarY = x + pad, bodyY
  local avatarH = bodyH
  G.setColor(.025,.055,.085,.94); roundRect("fill",avatarX,avatarY,avatarW,avatarH,r*.42)
  G.setColor(TRAINER_CARD_ACCENT.crystal[1],TRAINER_CARD_ACCENT.crystal[2],
    TRAINER_CARD_ACCENT.crystal[3],.95)
  G.setLineWidth(math.max(2,2*s)); roundRect("line",avatarX,avatarY,avatarW,avatarH,r*.42)
  G.setColor(TRAINER_CARD_ACCENT.crystal[1],TRAINER_CARD_ACCENT.crystal[2],
    TRAINER_CARD_ACCENT.crystal[3],.10)
  G.circle("fill",avatarX+avatarW*.5,avatarY+avatarH*.40,avatarW*.40)
  local portrait, portraitId = trainerCardImage(save)
  if portrait and type(portrait.getDimensions) == "function" then
    local iw, ih = portrait:getDimensions()
    local maxW, maxH = avatarW * 0.84, avatarH * 0.68
    local k = math.min(maxW / iw, maxH / ih)
    G.setColor(1, 1, 1, 1)
    G.draw(portrait, avatarX + (avatarW - iw * k) * 0.5,
      avatarY + avatarH * 0.04, 0, k, k)
  end
  local caught = type(screen.caughtCount) == "function" and screen:caughtCount() or 0
  local time = save.playTime or {}
  local name = cleanText(player.name or "GOLD")
  if label then G.setFont(label) end
  G.setColor(1,1,1,.52); G.printf("TRAINER",avatarX,avatarY+avatarH*.78,avatarW,"center")
  if title then G.setFont(title) end
  G.setColor(1,1,1,.98); G.printf(name,avatarX+pad*.3,avatarY+avatarH*.83,avatarW-pad*.6,"center")
  if small then G.setFont(small) end
  G.setColor(TRAINER_CARD_ACCENT.crystal[1],TRAINER_CARD_ACCENT.crystal[2],
    TRAINER_CARD_ACCENT.crystal[3],.95)
  G.printf(edition:upper() .. "  /  ID " ..
    ("%05d"):format(tonumber(player.id) or 0),avatarX,avatarY+avatarH*.94,avatarW,"center")

  local rightX = avatarX + avatarW + pad*.75
  local rightW = x + w - pad - rightX
  local summaryH = bodyH * .36
  G.setColor(.025,.055,.085,.94); roundRect("fill",rightX,bodyY,rightW,summaryH,r*.38)
  G.setColor(TRAINER_CARD_ACCENT.crystal[1],TRAINER_CARD_ACCENT.crystal[2],
    TRAINER_CARD_ACCENT.crystal[3],.65)
  G.setLineWidth(math.max(1,1.5*s)); roundRect("line",rightX,bodyY,rightW,summaryH,r*.38)
  local badgeCount = trainerRegionBadgeCount(player,"johto")
    + trainerRegionBadgeCount(player,"kanto")
  local rank = badgeCount >= 16 and localized(screen.game, "INDIGO CHAMPION", "INDIGO-CHAMPION")
    or badgeCount >= 8 and localized(screen.game, "JOHTO CHAMPION", "JOHTO-CHAMPION") or localized(screen.game, "JOHTO TRAINER", "TRAINER AUS JOHTO")
  if label then G.setFont(label) end
  G.setColor(1,1,1,.50); G.print(localized(screen.game, "CURRENT TITLE", "AKTUELLER TITEL"),rightX+pad,bodyY+pad*.55)
  if title then G.setFont(title) end
  G.setColor(accent[1],accent[2],accent[3],1)
  G.print(rank,rightX+pad,bodyY+pad*1.38)
  local values = {
    {localized(screen.game, "MONEY", "GELD"),"¥"..tostring(math.floor(tonumber(player.money) or 0))},
    {localized(screen.game, "PLAY TIME", "SPIELZEIT"),("%d:%02d"):format(tonumber(time.hours) or 0,tonumber(time.minutes) or 0)},
    {"POKéDEX",tostring(caught)..localized(screen.game, " CAUGHT", " GEFANGEN")},
  }
  local vx=rightX+pad; local vw=(rightW-pad*2)/3
  for i,row in ipairs(values) do
    local rx=vx+(i-1)*vw
    if small then G.setFont(small) end
    G.setColor(1,1,1,.48); G.print(row[1],rx,bodyY+summaryH-pad*2.05)
    if value then G.setFont(value) end
    G.setColor(1,1,1,.98); G.print(row[2],rx,bodyY+summaryH-pad*1.22)
  end

  local badgesY = bodyY + summaryH + pad*.65
  local badgesH = bodyY + bodyH - badgesY
  G.setColor(.025,.055,.085,.94); roundRect("fill",rightX,badgesY,rightW,badgesH,r*.38)
  G.setColor(accent[1],accent[2],accent[3],.65)
  G.setLineWidth(math.max(1,1.5*s)); roundRect("line",rightX,badgesY,rightW,badgesH,r*.38)
  if label then G.setFont(label) end
  G.setColor(1,1,1,.55); G.print(localized(screen.game, "JOHTO BADGES", "JOHTO-ORDEN"),rightX+pad,badgesY+pad*.55)
  G.setColor(accent[1],accent[2],accent[3],1)
  G.printf(tostring(trainerRegionBadgeCount(player,"johto")).." / 8",
    rightX,badgesY+pad*.55,rightW-pad,"right")
  local tileGap=math.max(4*s,rightW*.008)
  local tilesX=rightX+pad*.65
  local tilesY=badgesY+pad*1.60
  local tilesW=rightW-pad*1.30
  local tilesH=badgesY+badgesH-pad*.48-tilesY
  local tileW=(tilesW-tileGap*3)/4
  local tileH=(tilesH-tileGap)/2
  for i=1,8 do
    local column=(i-1)%4
    local row=math.floor((i-1)/4)
    drawTrainerLeaderTile("johto",i,
      tilesX+column*(tileW+tileGap),tilesY+row*(tileH+tileGap),
      tileW,tileH,s,player,screen.game)
  end

  if small then G.setFont(small) end
  G.setColor(1,1,1,.58)
  G.printf(localized(screen.game, "LEFT/RIGHT: PAGE    A: BADGES    B: BACK", "LINKS/RECHTS: SEITE    A: ORDEN    B: ZURÜCK"),
    x+pad,y+h-pad*1.30,w-pad*2,"center")
  diagnosticOnce(screen, "trainer-card-dedicated", "gen2-menu-provider", {
    screen="TRAINER_CARD", provider="gen2-dedicated-card", result="drawn",
    edition=edition, portrait=portraitId,
  })
end

local function trainerRenderer(screen, ww, wh)
  local save = screen.save or {}
  local player = save.player or {}
  local page = tonumber(screen.page) or 1
  local flags = type(save) == "table" and save.flags or nil
  local postgame = type(flags) == "table" and flags.HALL_OF_FAME == true
  -- The engine may retain a page-3 cursor across saves/hot reloads. Never let
  -- that stale cursor reveal the postgame badge region before Hall of Fame.
  if page == 3 and not postgame then page = 2 end
  if not beginDraw(ww, wh, screen) then return false end
  if page == 1 then
    trainerCardMainPage(screen, ww, wh, save, player)
  else
    trainerBadgeCasePage(ww, wh, player, page == 3 and "kanto" or "johto", screen.game)
  end
  endDraw()
  return true
end

local function pokegearCard(screen)
  if type(screen.card) == "function" then
    local ok, card = pcall(screen.card, screen)
    if ok then return card end
  end
  return screen.cards and screen.cards[screen.cardIndex or 1] or nil
end

local function worldAtlasEnabled()
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return true end
  local ok, value = pcall(options.get, options, "gen2WorldMap")
  if not ok or value == nil then return true end
  return value ~= false
end

-- TownMap_GetKantoLandmarkLimits uses the Hall-of-Fame record as its real
-- postgame boundary.  Mirror that exact save receipt for presentation too:
-- before the League win no Kanto artwork or label is exposed; afterwards the
-- wide atlas may reveal both regions.  Cursor/Fly ownership remains native.
local function kantoAtlasUnlocked(screen)
  local save = screen and (screen.save or (screen.game and screen.game.save))
  local flags = type(save) == "table" and save.flags or nil
  return type(flags) == "table" and flags.HALL_OF_FAME == true
end
M.kantoAtlasUnlocked = kantoAtlasUnlocked

local function atlasRegionLabel(screen)
  return kantoAtlasUnlocked(screen) and "JOHTO + KANTO" or "JOHTO"
end

-- Pokégear is one native GSC device, not a collection of unrelated debug
-- windows.  Keep the cartridge card ids for input/ownership, but translate
-- their internal states (notably `strip` and `card`) into player-facing copy.
-- This also gives the renderer one stable vocabulary across Gold, Silver and
-- Crystal without changing any of Pokegear:update's state transitions.
local POKEGEAR_CARD_COPY = {
  clock = { label="CLOCK", eyebrow="LOCAL TIME", status="RTC LINKED" },
  map = { label="MAP", eyebrow="JOHTO ATLAS", status="LANDMARK LINK" },
  phone = { label="PHONE", eyebrow="POKéCOM", status="CONTACT LINK" },
  radio = { label="RADIO", eyebrow="POKéCOM", status="RADIO LINK" },
}

local function pokegearModeLabel(screen, cardId)
  cardId = tostring(cardId or "clock"):lower()
  if screen and screen.fly then return "FLY MAP" end
  if cardId == "phone" then
    if screen and screen.call then return "ACTIVE CALL" end
    if screen and screen.phoneSubmenu then return "CONTACT ACTION" end
    return "CONTACTS"
  elseif cardId == "radio" then
    return screen and screen.radio and "ON AIR" or "TUNER"
  elseif cardId == "map" then
    return "TOWN MAP"
  end
  return "DEVICE READY"
end

local function pokegearPrimaryRatio(cardId, fly)
  cardId = tostring(cardId or "clock"):lower()
  return fly and 0.70 or (cardId == "map" and 0.72 or 0.66)
end

local function pokegearWorkspaceGeometry(ww, wh, cardId, fly)
  return wideWorkspaceGeometry(ww, wh, {
    primaryRatio=pokegearPrimaryRatio(cardId, fly),
  })
end

local function landmarkRegion(screen, entry)
  if not entry then return nil end
  local source = screen.landmarks
    or (screen.data and screen.data.gen2Landmarks)
  local records = source and source.landmarks
  local pallet = records and records.LANDMARK_PALLET_TOWN
  local fastShip = records and records.LANDMARK_FAST_SHIP
  local index = tonumber(entry.index) or 0
  if fastShip and index == tonumber(fastShip.index) then return "johto" end
  return index >= tonumber(pallet and pallet.index or 0x2e)
    and "kanto" or "johto"
end

local function panoramaPoint(screen, entry, x, y, w, h)
  local region = landmarkRegion(screen, entry)
  local frame = region and WORLD_PANORAMA_FRAME[region]
  if not frame or not entry then return nil, nil, region end
  local nativeX = math.max(0, math.min(159, tonumber(entry.x) or 0)) / 159
  local nativeY = math.max(0, math.min(143, tonumber(entry.y) or 0)) / 143
  return x + (frame.x + nativeX * frame.w) * w,
    y + (frame.y + nativeY * frame.h) * h, region
end

local function panoramaViewPoint(screen, entry, view, x, y, w, h)
  local region = landmarkRegion(screen, entry)
  local frame = region and WORLD_PANORAMA_FRAME[region]
  if not frame or not entry then return nil, nil, region end
  if not kantoAtlasUnlocked(screen) and region == "kanto" then
    return nil, nil, region
  end
  local nativeX = math.max(0, math.min(159, tonumber(entry.x) or 0)) / 159
  local nativeY = math.max(0, math.min(143, tonumber(entry.y) or 0)) / 143
  local sourceX = frame.x + nativeX * frame.w
  local sourceY = frame.y + nativeY * frame.h
  if sourceX < view.x or sourceX > view.x + view.w
      or sourceY < view.y or sourceY > view.y + view.h then
    return nil, nil, region
  end
  return x + ((sourceX - view.x) / view.w) * w,
    y + ((sourceY - view.y) / view.h) * h, region
end

local function townMapCanvas(screen, region)
  local G = love.graphics
  screen._vascTownMapCanvases = screen._vascTownMapCanvases or {}
  local canvas = screen._vascTownMapCanvases[region]
  if not (canvas and type(canvas.getDimensions) == "function") then
    local ok, made = pcall(G.newCanvas, 160, 144)
    if not ok or not made then return nil end
    canvas = made
    if type(canvas.setFilter) == "function" then
      pcall(canvas.setFilter, canvas, "nearest", "nearest")
    end
    screen._vascTownMapCanvases[region] = canvas
  end
  local cells = screen.gfx and screen.gfx.maps and screen.gfx.maps[region]
  if not cells or type(screen.drawTilemap) ~= "function" then return nil end
  local previous = type(G.getCanvas) == "function" and G.getCanvas() or nil
  local ok = pcall(function()
    G.setCanvas(canvas)
    G.origin()
    G.clear(0, 0, 0, 1)
    screen:drawTilemap(cells)
    G.setCanvas(previous)
  end)
  if not ok then pcall(G.setCanvas, previous); return nil end
  return canvas
end

-- Paint the broad logo-free region atlas when available.  Marker and Fly
-- ownership still come exclusively from the installed edition's imported
-- landmarks/visited flags; native town-map canvases are the fail-open path.
-- The Hall-of-Fame receipt decides whether the panorama is cropped to Johto
-- or may reveal both regions.
local function drawPokegearMapPanel(screen, geo, ww, wh, current, mapRect)
  local G = love and love.graphics
  if not (G and type(G.newCanvas) == "function") then return false end

  local s = geo.s or uiScaleFor(ww, wh)
  local margin = geo.margin or math.max(18 * s, wh * 0.025)
  local x, y, w, h
  if type(mapRect) == "table" then
    x, y, w, h = mapRect.x, mapRect.y, mapRect.w, mapRect.h
  else
    x, y = margin, geo.y
    w, h = math.max(0, geo.x - margin * 2), geo.h
  end
  if w < 170 * s then return false end
  local mapGeo = rectGeometry({ x=x, y=y, w=w, h=h }, ww, wh, 1, 1)
  panel(x, y, w, h, mapGeo.r, 0.94, s)
  local showKanto = kantoAtlasUnlocked(screen)
  local activeRegion = type(screen.region) == "function"
    and tostring(screen:region()):upper() or "JOHTO"
  if not showKanto then activeRegion = "JOHTO" end
  local maps = screen.gfx and screen.gfx.maps
  local nativeAtlas = maps and maps.johto and (not showKanto or maps.kanto)
  local panorama = worldAtlasEnabled() and worldPanorama() or nil
  local atlas = panorama or nativeAtlas
  header(G, atlas and (atlasRegionLabel(screen) .. " ATLAS")
      or (activeRegion .. " MAP"),
    cleanText(current and current.name or ""),
    x, y, w, mapGeo.headerH, wh, s)
  local pad = math.max(12 * s, mapGeo.gap * 1.5)
  local top = y + mapGeo.headerH + pad
  local bottom = y + h - math.max(36 * s, mapGeo.footerH)
  local availW, availH = w - pad * 2, math.max(1, bottom - top)

  if panorama then
    local iw, ih = panorama:getDimensions()
    local view = showKanto and { x=0, y=0, w=1, h=1 }
      or WORLD_PANORAMA_FRAME.johto
    local sourceW, sourceH = iw * view.w, ih * view.h
    local k = math.min(availW / sourceW, availH / sourceH)
    local mapW, mapH = sourceW * k, sourceH * k
    local mapX = x + (w - mapW) * 0.5
    local mapY = top + (availH - mapH) * 0.5
    drawBitmapMapFrame(screen, mapX, mapY, mapW, mapH, s)
    G.setColor(1, 1, 1, 1)
    if showKanto then
      G.draw(panorama, mapX, mapY, 0, k, k)
    else
      local quad = G.newQuad(view.x * iw, view.y * ih,
        sourceW, sourceH, iw, ih)
      G.draw(panorama, quad, mapX, mapY, 0, k, k)
    end

    local selected = type(screen.flyRow) == "function" and screen:flyRow()
      or current
    local player = type(screen.playerLandmark) == "function"
      and screen:playerLandmark() or nil
    local records = screen.landmarks and screen.landmarks.landmarks or {}
    local function dot(entry, r, g, b, radius)
      if not entry then return end
      local px, py = panoramaViewPoint(screen, entry, view,
        mapX, mapY, mapW, mapH)
      if not px then return end
      G.setColor(0.02, 0.03, 0.04, 0.72)
      G.circle("fill", px, py, math.max(2, (radius + 1.3) * s))
      G.setColor(r, g, b, 0.98)
      G.circle("fill", px, py, math.max(1.5, radius * s))
    end
    for _, row in ipairs(screen.fly or {}) do
      dot(records[row.landmark], 0.30, 0.85, 1.0, 2.2)
    end
    dot(player, 1.0, 0.25, 0.20, 3.2)
    local chosen = selected and (selected.landmark
      and records[selected.landmark] or selected)
    dot(chosen, 1.0, 0.76, 0.10, 4.0)
  elseif nativeAtlas then
    local gap = math.max(8 * s, 4)
    -- Asset failure never removes the map: draw the extracted native region
    -- canvases, with Kanto present only after the same Hall-of-Fame receipt.
    local regions = showKanto and { "johto", "kanto" } or { "johto" }
    local totalNativeW = 160 * #regions
    local k = math.min((availW - gap * (#regions - 1)) / totalNativeW,
      availH / 144)
    local atlasW = totalNativeW * k + gap * (#regions - 1)
    local mapLeft = x + (w - atlasW) * 0.5
    local mapTop = top + (availH - 144 * k) * 0.5
    local selected = type(screen.flyRow) == "function" and screen:flyRow()
      or current
    local player = type(screen.playerLandmark) == "function"
      and screen:playerLandmark() or nil
    local records = screen.landmarks and screen.landmarks.landmarks or {}
    for order, region in ipairs(regions) do
      local canvas = townMapCanvas(screen, region)
      if canvas then
        local mapX = mapLeft + (order - 1) * (160 * k + gap)
        local mapY = mapTop
        drawBitmapMapFrame(screen, mapX, mapY, 160 * k, 144 * k, s)
        G.setColor(1, 1, 1, 1)
        G.draw(canvas, mapX, mapY, 0, k, k)
        local function dot(entry, r, g, b, radius)
          if not entry or landmarkRegion(screen, entry) ~= region then return end
          G.setColor(r, g, b, 0.95)
          G.circle("fill", mapX + (tonumber(entry.x) or 0) * k,
            mapY + (tonumber(entry.y) or 0) * k, radius * s)
        end
        for _, row in ipairs(screen.fly or {}) do
          dot(records[row.landmark], 0.30, 0.85, 1.0, 2.2)
        end
        dot(player, 1.0, 0.25, 0.20, 3.2)
        local chosen = selected and (selected.landmark
          and records[selected.landmark] or selected)
        dot(chosen, 1.0, 0.76, 0.10, 4.0)
      end
    end
  else
    local region = showKanto and activeRegion:lower() or "johto"
    local canvas = townMapCanvas(screen, region)
    if canvas then
      local k = math.min(availW / 160, availH / 144)
      local mapX = x + (w - 160 * k) * 0.5
      local mapY = top + (availH - 144 * k) * 0.5
      drawBitmapMapFrame(screen, mapX, mapY, 160 * k, 144 * k, s)
      G.setColor(1, 1, 1, 1)
      G.draw(canvas, mapX, mapY, 0, k, k)
    else
      -- Keep the wide workspace coherent while the native tilemap or optional
      -- panorama is still loading.  Returning false here used to make the
      -- caller paint a second panel/header on top of this one.
      G.setColor(1, 1, 1, 0.035)
      roundRect("fill", x + pad, top, availW, availH, mapGeo.r * 0.55)
      local titleFont = font(math.max(18 * s, wh * 0.024))
      local bodyFont = font(math.max(11 * s, wh * 0.014))
      if titleFont then G.setFont(titleFont) end
      G.setColor(1, 1, 1, 0.82)
      G.printf(activeRegion .. " TOWN MAP", x + pad,
        top + availH * 0.38, availW, "center")
      if bodyFont then G.setFont(bodyFont) end
      G.setColor(1, 1, 1, 0.48)
      G.printf("Native map data is loading.", x + pad,
        top + availH * 0.50, availW, "center")
    end
  end
  footer(G, atlas and "RED PLAYER / GOLD SELECTED / BLUE VISITED"
    or "LIVE GSC MAP / PLAYER + CURSOR", x, y, w, h,
    mapGeo.gap, wh, s)
  return true
end

local function drawPokegearGlyph(cardId, cx, cy, size, active)
  local G = love.graphics
  cardId = tostring(cardId or "clock"):lower()
  size = math.max(8, size or 16)
  local accent = EDITION_ACCENTS[activeEdition] or EDITION_ACCENTS.crystal
  if active then
    G.setColor(accent[1], accent[2], accent[3], 1)
  else
    G.setColor(1, 1, 1, 0.54)
  end
  G.setLineWidth(math.max(1, size * 0.10))
  if cardId == "clock" then
    G.circle("line", cx, cy, size * 0.42)
    G.line(cx, cy, cx, cy - size * 0.24)
    G.line(cx, cy, cx + size * 0.20, cy + size * 0.10)
  elseif cardId == "map" then
    G.rectangle("line", cx - size * 0.45, cy - size * 0.34,
      size * 0.90, size * 0.68, size * 0.08, size * 0.08)
    G.line(cx - size * 0.29, cy + size * 0.18,
      cx - size * 0.08, cy - size * 0.10,
      cx + size * 0.10, cy + size * 0.04,
      cx + size * 0.31, cy - size * 0.19)
  elseif cardId == "phone" then
    roundRect("line", cx - size * 0.28, cy - size * 0.43,
      size * 0.56, size * 0.86, size * 0.12)
    G.line(cx - size * 0.12, cy - size * 0.27,
      cx + size * 0.12, cy - size * 0.27)
    G.circle("fill", cx, cy + size * 0.28, math.max(1, size * 0.055))
  else
    G.rectangle("line", cx - size * 0.46, cy - size * 0.30,
      size * 0.92, size * 0.62, size * 0.08, size * 0.08)
    G.line(cx - size * 0.25, cy - size * 0.31,
      cx + size * 0.22, cy - size * 0.52)
    G.circle("line", cx + size * 0.23, cy, size * 0.13)
    G.line(cx - size * 0.30, cy - size * 0.08,
      cx - size * 0.06, cy - size * 0.08)
    G.line(cx - size * 0.30, cy + size * 0.08,
      cx - size * 0.10, cy + size * 0.08)
  end
end

local function drawPokegearTabs(screen, workspace, activeId)
  local G = love.graphics
  local cards = type(screen.cards) == "table" and screen.cards or {}
  if #cards == 0 then return end
  local s, gap = workspace.s, workspace.gap * 0.48
  local totalW = math.min(workspace.w * 0.58, 500 * s)
  local x = workspace.x + workspace.w - totalW - workspace.gap
  local y = workspace.y + workspace.headerH * 0.18
  local tabW = (totalW - gap * (#cards - 1)) / #cards
  local tabH = math.max(34 * s, workspace.headerH * 0.54)
  local f = font(math.max(9 * s, tabH * 0.25))
  for i, entry in ipairs(cards) do
    local id = tostring(entry.id or "clock"):lower()
    local tx = x + (i - 1) * (tabW + gap)
    local on = id == tostring(activeId):lower()
    G.setColor(on and 0.10 or 0.035, on and 0.25 or 0.075,
      on and 0.43 or 0.13, on and 0.98 or 0.92)
    roundRect("fill", tx, y, tabW, tabH, tabH * 0.20)
    G.setColor(1, 1, 1, on and 0.11 or 0.06)
    roundRect("line", tx, y, tabW, tabH, tabH * 0.20)
    if on then
      local accent = EDITION_ACCENTS[activeEdition] or EDITION_ACCENTS.crystal
      G.setColor(accent[1], accent[2], accent[3], 1)
      G.setLineWidth(math.max(1, 2 * s))
      roundRect("line", tx, y, tabW, tabH, tabH * 0.20)
      roundRect("fill", tx + tabW * 0.16, y + tabH - math.max(3 * s, tabH * 0.07),
        tabW * 0.68, math.max(2 * s, tabH * 0.055), tabH * 0.03)
    end
    drawPokegearGlyph(id, tx + tabW * 0.24, y + tabH * 0.50,
      math.min(tabH * 0.46, tabW * 0.22), on)
    if f then G.setFont(f) end
    G.setColor(1, 1, 1, on and 0.98 or 0.61)
    G.printf(cleanText(entry.label or id), tx + tabW * 0.38,
      y + tabH * 0.37, tabW * 0.56, "left")
  end
end

local function drawPokegearDeviceRail(screen, rect, ww, wh, activeId, region)
  local G = love.graphics
  local geo = rectGeometry(rect, ww, wh, 4, 4)
  local cards = type(screen.cards) == "table" and screen.cards or {}
  panel(rect.x, rect.y, rect.w, rect.h, geo.r, 0.94, geo.s)
  header(G, "POKéCOM", region .. " DEVICE", rect.x, rect.y, rect.w,
    geo.headerH, wh, geo.s)
  local pad = math.max(10 * geo.s, geo.gap * 1.4)
  local top = rect.y + geo.headerH + pad
  local bottom = rect.y + rect.h - geo.footerH - pad * 0.45
  local count = math.max(1, #cards)
  local rowGap = math.max(7 * geo.s, geo.gap * 0.75)
  local rowH = math.max(46 * geo.s,
    (bottom - top - rowGap * (count - 1)) / count)
  local labelFont = font(math.max(11 * geo.s, wh * 0.014))
  local metaFont = font(math.max(8 * geo.s, wh * 0.0105))
  local accent = EDITION_ACCENTS[activeEdition] or EDITION_ACCENTS.crystal
  for i, card in ipairs(cards) do
    local id = tostring(card.id or "clock"):lower()
    local copy = POKEGEAR_CARD_COPY[id] or POKEGEAR_CARD_COPY.clock
    local on = id == tostring(activeId):lower()
    local ry = top + (i - 1) * (rowH + rowGap)
    G.setColor(on and 0.075 or 0.025, on and 0.20 or 0.075,
      on and 0.35 or 0.13, on and 0.98 or 0.90)
    roundRect("fill", rect.x + pad, ry, rect.w - pad * 2, rowH,
      geo.r * 0.40)
    G.setColor(accent[1], accent[2], accent[3], on and 0.92 or 0.20)
    roundRect("fill", rect.x + pad, ry, math.max(3 * geo.s, pad * 0.25),
      rowH, geo.r * 0.18)
    drawPokegearGlyph(id, rect.x + pad * 2.45, ry + rowH * 0.50,
      math.min(rowH * 0.42, 20 * geo.s), on)
    local tx = rect.x + pad * 3.75
    if labelFont then G.setFont(labelFont) end
    G.setColor(1, 1, 1, on and 0.98 or 0.74)
    G.print(copy.label, tx, ry + rowH * 0.23)
    if metaFont then G.setFont(metaFont) end
    G.setColor(accent[1], accent[2], accent[3], on and 0.96 or 0.45)
    G.print(on and copy.status or "AVAILABLE", tx, ry + rowH * 0.60)
  end
  footer(G, "NATIVE GSC DATA / ASCENDANT DISPLAY", rect.x, rect.y,
    rect.w, rect.h, geo.gap, wh, geo.s)
end

local function drawPokegearMessageRail(rect, ww, wh, title, subtitle, text,
    status)
  local G = love.graphics
  local geo = rectGeometry(rect, ww, wh, 1, 1)
  local accent = EDITION_ACCENTS[activeEdition] or EDITION_ACCENTS.crystal
  panel(rect.x, rect.y, rect.w, rect.h, geo.r, 0.94, geo.s)
  header(G, title, subtitle, rect.x, rect.y, rect.w, geo.headerH, wh, geo.s)
  local pad = math.max(12 * geo.s, geo.gap * 1.6)
  local chipY = rect.y + geo.headerH + pad * 0.55
  local chipH = math.max(28 * geo.s, rect.h * 0.055)
  G.setColor(accent[1], accent[2], accent[3], 0.16)
  roundRect("fill", rect.x + pad, chipY, rect.w - pad * 2, chipH,
    chipH * 0.24)
  local meta = font(math.max(9 * geo.s, wh * 0.011))
  if meta then G.setFont(meta) end
  G.setColor(accent[1], accent[2], accent[3], 0.96)
  G.printf(cleanText(status or "POKéCOM READY"), rect.x + pad,
    chipY + chipH * 0.32, rect.w - pad * 2, "center")
  local bodyY = chipY + chipH + pad
  local bodyH = rect.y + rect.h - geo.footerH - pad - bodyY
  G.setColor(1, 1, 1, 0.045)
  roundRect("fill", rect.x + pad, bodyY, rect.w - pad * 2,
    math.max(1, bodyH), geo.r * 0.45)
  local bodyFont = font(math.max(12 * geo.s, wh * 0.015))
  if bodyFont then G.setFont(bodyFont) end
  G.setColor(1, 1, 1, 0.78)
  G.printf(cleanText(text), rect.x + pad * 1.45, bodyY + pad * 1.15,
    rect.w - pad * 2.9, "left")
  footer(G, "CIRCLE/B BACK", rect.x, rect.y, rect.w, rect.h,
    geo.gap, wh, geo.s)
end

local function drawPokegearMapStatus(screen, rect, ww, wh, rows, region)
  local G = love.graphics
  local geo = rectGeometry(rect, ww, wh, #rows, #rows)
  local accent = EDITION_ACCENTS[activeEdition] or EDITION_ACCENTS.crystal
  panel(rect.x, rect.y, rect.w, rect.h, geo.r, 0.94, geo.s)
  header(G, "MAP STATUS", region .. " NETWORK", rect.x, rect.y, rect.w,
    geo.headerH, wh, geo.s)
  local pad = math.max(10 * geo.s, geo.gap * 1.35)
  local top = rect.y + geo.headerH + pad
  local bottom = rect.y + rect.h - geo.footerH - pad * 0.40
  local rowGap = math.max(7 * geo.s, geo.gap * 0.70)
  local rowH = math.max(54 * geo.s,
    (bottom - top - rowGap * math.max(0, #rows - 1)) / math.max(1, #rows))
  local labelFont = font(math.max(9 * geo.s, wh * 0.011))
  local valueFont = font(math.max(12 * geo.s, wh * 0.015))
  for i, row in ipairs(rows) do
    local ry = top + (i - 1) * (rowH + rowGap)
    G.setColor(0.025, 0.075, 0.13, 0.94)
    roundRect("fill", rect.x + pad, ry, rect.w - pad * 2, rowH,
      geo.r * 0.40)
    G.setColor(accent[1], accent[2], accent[3], 0.78)
    roundRect("fill", rect.x + pad, ry,
      math.max(3 * geo.s, pad * 0.24), rowH, geo.r * 0.16)
    if labelFont then G.setFont(labelFont) end
    G.setColor(1, 1, 1, 0.48)
    G.print(cleanText(row[1]), rect.x + pad * 1.65, ry + rowH * 0.18)
    if valueFont then G.setFont(valueFont) end
    G.setColor(1, 1, 1, 0.94)
    G.print(clipped(row[2], G.getFont(), rect.w - pad * 3.3),
      rect.x + pad * 1.65, ry + rowH * 0.49)
  end
  footer(G, "UP/DOWN LANDMARK / LEFT/RIGHT CARD", rect.x, rect.y,
    rect.w, rect.h, geo.gap, wh, geo.s)
end

local function drawPokegearClock(screen, rect, ww, wh, hour, minute, weekday)
  local G = love.graphics
  local geo = rectGeometry(rect, ww, wh, 1, 1)
  local days = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY",
    "THURSDAY", "FRIDAY", "SATURDAY" }
  local accent = EDITION_ACCENTS[activeEdition] or EDITION_ACCENTS.crystal
  panel(rect.x, rect.y, rect.w, rect.h, geo.r, 0.94, geo.s)
  header(G, "JOHTO LOCAL TIME", days[weekday] or "DAY", rect.x, rect.y,
    rect.w, geo.headerH, wh, geo.s)

  local bodyY = rect.y + geo.headerH + geo.gap
  local bodyH = rect.h - geo.headerH - geo.footerH - geo.gap * 2
  local dialX = rect.x + rect.w * 0.27
  local dialY = bodyY + bodyH * 0.45
  local radius = math.min(rect.w * 0.18, bodyH * 0.32)
  G.setColor(1, 1, 1, 0.035)
  G.circle("fill", dialX, dialY, radius * 1.25)
  G.setColor(accent[1], accent[2], accent[3], 0.86)
  G.setLineWidth(math.max(2 * geo.s, radius * 0.045))
  G.circle("line", dialX, dialY, radius)
  for i = 0, 11 do
    local a = (i / 12) * math.pi * 2 - math.pi * 0.5
    local inner = radius * (i % 3 == 0 and 0.78 or 0.86)
    G.line(dialX + math.cos(a) * inner, dialY + math.sin(a) * inner,
      dialX + math.cos(a) * radius * 0.95,
      dialY + math.sin(a) * radius * 0.95)
  end
  local minuteA = ((minute % 60) / 60) * math.pi * 2 - math.pi * 0.5
  local hourA = (((hour % 12) + minute / 60) / 12) * math.pi * 2
    - math.pi * 0.5
  G.setColor(1, 1, 1, 0.96)
  G.setLineWidth(math.max(2 * geo.s, radius * 0.050))
  G.line(dialX, dialY, dialX + math.cos(hourA) * radius * 0.52,
    dialY + math.sin(hourA) * radius * 0.52)
  G.setColor(accent[1], accent[2], accent[3], 1)
  G.setLineWidth(math.max(2 * geo.s, radius * 0.035))
  G.line(dialX, dialY, dialX + math.cos(minuteA) * radius * 0.74,
    dialY + math.sin(minuteA) * radius * 0.74)
  G.circle("fill", dialX, dialY, math.max(3 * geo.s, radius * 0.07))

  local digitalX = rect.x + rect.w * 0.49
  local digitalW = rect.x + rect.w - geo.gap * 2 - digitalX
  local big = font(math.max(38 * geo.s,
    math.min(digitalW * 0.22, bodyH * 0.20)))
  local small = font(math.max(11 * geo.s, wh * 0.014))
  if small then G.setFont(small) end
  G.setColor(1, 1, 1, 0.48)
  G.print("REAL-TIME CLOCK", digitalX, dialY - radius * 0.68)
  if big then G.setFont(big) end
  G.setColor(1, 1, 1, 0.98)
  G.print(("%02d:%02d"):format(hour, minute), digitalX,
    dialY - radius * 0.34)
  if small then G.setFont(small) end
  G.setColor(accent[1], accent[2], accent[3], 0.94)
  G.print((activeEdition .. " edition"):upper(), digitalX,
    dialY + radius * 0.52)

  local chipY = bodyY + bodyH * 0.82
  local chipLeft = rect.x + rect.w * 0.50
  local chipRight = rect.x + rect.w - geo.gap * 1.35
  local chipGap = math.max(6 * geo.s, geo.gap * 0.65)
  local chipW = math.max(54 * geo.s,
    (chipRight - chipLeft - chipGap) * 0.5)
  local chipH = math.max(28 * geo.s, bodyH * 0.085)
  for i, label in ipairs({ "RTC LINKED", "JOHTO TIME" }) do
    local cx = chipLeft + (i - 1) * (chipW + chipGap)
    G.setColor(accent[1], accent[2], accent[3], i == 1 and 0.18 or 0.09)
    roundRect("fill", cx, chipY, chipW, chipH, chipH * 0.25)
    if small then G.setFont(small) end
    G.setColor(1, 1, 1, 0.72)
    G.printf(label, cx, chipY + chipH * 0.31, chipW, "center")
  end
  footer(G, "NATIVE RTC / LIVE WORLD CLOCK", rect.x, rect.y,
    rect.w, rect.h, geo.gap, wh, geo.s)
end

local function pokegearRenderer(screen, ww, wh)
  local card = pokegearCard(screen) or { id = "clock", label = "CLOCK" }
  local id = tostring(card.id or "clock"):lower()
  local mode = tostring(screen.mode or "card"):upper()
  local modeLabel = pokegearModeLabel(screen, id)
  diagnosticOnce(screen, "pokegear-dedicated", "gen2-menu-provider", {
    screen="POKEGEAR", provider="gen2-wide-pokegear", result="drawn",
    card=id, mode=mode,
  })
  if not beginDraw(ww, wh, screen) then return false end

  local regionLabel = atlasRegionLabel(screen)
  local workspace = drawWideWorkspaceShell(ww, wh, "POKéGEAR / POKéCOM",
    regionLabel .. " / " .. modeLabel,
    { primaryRatio=pokegearPrimaryRatio(id, screen.fly ~= nil),
      footer=screen.fly
        and "UP/DOWN SELECT    CROSS/A FLY    CIRCLE/B BACK"
        or "LEFT/RIGHT CARD    CROSS/A OPEN    CIRCLE/B BACK" })
  if not screen.fly then drawPokegearTabs(screen, workspace, id) end

  if screen.fly then
    local rows = {}
    for _, row in ipairs(screen.fly) do
      rows[#rows + 1] = {
        name=cleanText(row.name or "DESTINATION"),
        meta=kantoAtlasUnlocked(screen)
          and tostring(row.region or ""):upper() or "VISITED DESTINATION",
      }
    end
    local listGeo = rectGeometry(workspace.rail, ww, wh, #rows, 10)
    drawListPanel(ww, wh, "FLY", regionLabel, rows,
      tonumber(screen.flyIndex) or 1, 0, { geo=listGeo, maxRows=10,
        scrollbar=true, footer="UP/DOWN SELECT    A FLY    B BACK" })
    local selected = type(screen.flyRow) == "function" and screen:flyRow()
      or screen.fly[tonumber(screen.flyIndex) or 1]
    drawPokegearMapPanel(screen, listGeo, ww, wh, selected, workspace.primary)
    endDraw()
    return true
  end

  if id == "phone" then
    local list = type(screen.phoneList) == "function" and screen:phoneList() or {}
    local rows = {}
    for slot = 1, 4 do
      local contactId = list[slot + (tonumber(screen.phoneScroll) or 0)] or 0
      local label, className = "----------", nil
      if type(screen.contactRow) == "function" then
        local ok, a, b = pcall(screen.contactRow, screen, contactId)
        if ok then label, className = a or label, b end
      end
      rows[#rows + 1] = { name=cleanText(label),
        meta=cleanText(className or (contactId == 0 and "EMPTY SLOT" or "CONTACT")) }
    end
    local listGeo = rectGeometry(workspace.primary, ww, wh, #rows, 4)
    drawListPanel(ww, wh, "POKéCOM CONTACTS", regionLabel, rows,
      (tonumber(screen.phoneCursor) or 0) + 1, 0, { geo=listGeo,
        footer="UP/DOWN CONTACT    CROSS/A ACTION" })
    local callText = screen.call and screen.call.text
      or (type(screen.phoneText) == "function"
        and screen:phoneText("AskWhoCall")) or "Whom do you want to call?"
    drawPokegearMessageRail(workspace.rail, ww, wh,
      screen.call and cleanText(screen.call.name or "PHONE") or "POKéCOM",
      "PHONE", callText,
      screen.call and "CALL CONNECTED" or "SELECT A CONTACT")
    if screen.phoneSubmenu then
      local PokegearClass = package.loaded["src.ui.gen2.Pokegear"]
      local defs = PokegearClass and PokegearClass.PHONE_SUBMENUS
      local def = defs and defs[screen.phoneSubmenu]
      local labels = {}
      for _, label in ipairs(def and def.entries or { "CALL", "CANCEL" }) do
        labels[#labels + 1] = label
      end
      drawSmallChoice(ww, wh, "PHONE", "CONTACT ACTION", labels,
        (tonumber(screen.phoneSubmenuCursor) or 0) + 1,
        { widthFrac=0.28, maxW=360, x=workspace.rail.x,
          y=workspace.rail.y + workspace.rail.h * 0.45 })
    end
  elseif id == "radio" then
    local stations = type(screen.stations) == "function" and screen:stations() or {}
    local rows = {}
    for _, station in ipairs(stations) do
      rows[#rows + 1] = { name=cleanText(station.name or "NO STATION"),
        value=cleanText(station.frequency or ""),
        meta=station.station and "ON AIR" or "DEAD AIR",
        disabled=station.station == nil }
    end
    local listGeo = rectGeometry(workspace.primary, ww, wh, #rows, 10)
    drawListPanel(ww, wh, "POKéCOM RADIO", regionLabel, rows,
      tonumber(screen.station) or 1, 0, { geo=listGeo, maxRows=10,
        scrollbar=true, footer="UP/DOWN TUNE    LEFT/RIGHT CARD" })
    local radio, radioText = screen.radio, ""
    if radio then
      radioText = cleanText((radio.top or "") .. " " .. (radio.bottom or ""))
    end
    drawPokegearMessageRail(workspace.rail, ww, wh, "ON AIR", "POKéCOM RADIO",
      radioText ~= "" and radioText or "Tune a station with Up/Down.",
      radio and "SIGNAL LOCKED" or "SELECT A STATION")
  elseif id == "map" then
    local current = type(screen.mapLandmark) == "function"
      and screen:mapLandmark() or nil
    local playerLoc = type(screen.playerLandmark) == "function"
      and screen:playerLandmark() or nil
    local rows = {
      { "CURSOR", cleanText(current and current.name or "UNKNOWN") },
      { "PLAYER", cleanText(playerLoc and playerLoc.name or "UNKNOWN") },
      { "ATLAS", regionLabel },
    }
    local infoGeo = rectGeometry(workspace.rail, ww, wh, #rows, #rows)
    drawPokegearMapStatus(screen, workspace.rail, ww, wh, rows, regionLabel)
    if not drawPokegearMapPanel(screen, infoGeo, ww, wh, current,
        workspace.primary) then
      drawTextPanelAt(workspace.primary, ww, wh, "MAP", regionLabel,
        "Use Up/Down to move the native landmark cursor.", "")
    end
  else
    local hour, minute, weekday = 0, 0, 1
    if type(screen.clockParts) == "function" then
      local ok, a, b, c = pcall(screen.clockParts, screen)
      if ok then hour, minute, weekday = a or 0, b or 0, c or 1 end
    end
    drawPokegearClock(screen, workspace.primary, ww, wh, hour, minute, weekday)
    drawPokegearDeviceRail(screen, workspace.rail, ww, wh, id, regionLabel)
  end

  endDraw()
  return true
end

local function pokedexModelPanel(screen, row, rightGeo, ww, wh)
  local G = love.graphics
  if not (G and rightGeo) then return false end
  local s = rightGeo.s or uiScaleFor(ww, wh)
  local margin = math.max(18 * s, wh * 0.025)
  local x, y, w, h
  if rightGeo.directPanel then
    x, y, w, h = rightGeo.x, rightGeo.y, rightGeo.w, rightGeo.h
  else
    local available = math.max(0, rightGeo.x - margin * 2)
    if available < 170 * s then return false end
    w = math.min(available, ww * 0.46, 650 * s)
    local oldH = math.max(220 * s,
      math.min(wh * 0.66, rightGeo.h * 0.80, 620 * s))
    local bottomY = math.min(wh - margin, rightGeo.y + oldH)
    y = math.max(margin, math.min(rightGeo.y, wh * 0.035))
    h = math.max(300 * s, bottomY - y)
    x = margin
  end
  local r = math.max(14 * s, wh * 0.022)
  panel(x, y, w, h, r, 0.80, s)

  local seen = row and row.seen ~= false
  local game = screen and screen.game
  local species = row and row.species
  local spriteSource = modernDexSpriteSource()
  local name = seen and (type(screen.monName) == "function"
    and screen:monName(species) or species) or "?????"
  name = cleanText(name or "POKéMON")
  local number = row and row.dex and ("#%03d"):format(tonumber(row.dex) or 0) or ""
  local state = row and row.caught and "CAUGHT" or (seen and "SEEN" or "UNKNOWN")
  header(G, name, (number ~= "" and (number .. "    " .. state) or state),
    x, y, w, math.max(46 * s, h * 0.13), wh, s)

  local top = y + math.max(56 * s, h * 0.15)
  local bottom = y + h - math.max(38 * s, h * 0.10)
  local modelH = math.max(80 * s, bottom - top)
  local modelX = x + margin * 0.55
  local modelW = w - margin * 1.10

  G.setColor(1, 1, 1, 0.035)
  roundRect("fill", modelX, top, modelW, modelH, r * 0.60)
  G.setColor(1, 1, 1, 0.075)
  G.ellipse("fill", modelX + modelW * 0.50, top + modelH * 0.84,
    modelW * 0.28, math.max(5 * s, modelH * 0.045))

  local canvas, info
  local preview = partyPreviewModule()
  if spriteSource == "active" and seen and species
      and preview and type(preview.render) == "function" then
    local fakeMon = { species = species }
    local ok, rendered, details = pcall(preview.render, screen, fakeMon,
      math.min(modelW, 480), math.min(modelH, 480), {
        -- Internal model-view overscan only; the glass Pokédex box stays the
        -- same size. v0.2.75 frames from the CURRENT posed mesh and fits both
        -- horizontal and vertical FOV, so portrait viewers no longer crop
        -- wings/tails at the sides.
        renderScale = 1.55,
        horizontalPadding = 1.12,
        verticalPadding = 1.10,
        cameraMargin = 1.08,
        -- Aim just above the true posed centre for a small amount of visual
        -- headroom without throwing away the pose-aware auto-fit.
        focusBias = 0.05,
      })
    if ok then canvas, info = rendered, details
    else M.lastError = "Pokedex model preview: " .. tostring(rendered) end
  elseif preview and type(preview.release) == "function" then
    -- Moving to an unseen row or selecting a non-model sprite source must not
    -- leave the previous active Stadium model resident in the Dex panel.
    pcall(preview.release, screen)
  end

  -- CRYSTAL FRONTS is VASC Gen 2's standalone default. The resolver consumes
  -- the same coloured frame-one assets as Party, Starter and Naming; if one
  -- asset cannot be resolved, drawCrystalFront itself safely tries the active
  -- game front with the correct Gen-2 palette before the native path below.
  local paintedCrystal = false
  if not canvas and spriteSource == "crystal" and seen and species then
    local ok, painted = pcall(drawCrystalFront, screen, species,
      modelX, top, modelW, modelH, "pokedex")
    paintedCrystal = ok and painted == true
  end

  -- Stadium remains optional and GAME ORIGINAL is a strict cartridge path.
  -- ACTIVE also lands here when no optional 3D model is available.
  if not canvas and not paintedCrystal and seen and row
      and type(screen.drawPic) == "function" then
    screen._vascNativeDexCanvases = screen._vascNativeDexCanvases or {}
    local key = tostring(row.species)
    canvas = screen._vascNativeDexCanvases[key]
    if not (canvas and type(canvas.getDimensions) == "function") then
      local ok, made = pcall(G.newCanvas, 56, 56)
      if ok and made then
        canvas = made
        if type(canvas.setFilter) == "function" then
          pcall(canvas.setFilter, canvas, "nearest", "nearest")
        end
        local previous = type(G.getCanvas) == "function" and G.getCanvas() or nil
        local painted = pcall(function()
          G.setCanvas(canvas)
          G.origin()
          G.clear(0, 0, 0, 0)
          screen:drawPic(row, 0, 0, true)
          G.setCanvas(previous)
        end)
        if painted then
          screen._vascNativeDexCanvases[key] = canvas
          info = { native = true }
        else
          pcall(G.setCanvas, previous)
          canvas = nil
        end
      end
    else
      info = { native = true }
    end
  end

  if canvas and type(canvas.getDimensions) == "function" then
    local cw, ch = canvas:getDimensions()
    if cw and ch and cw > 0 and ch > 0 then
      local k = math.min(modelW / cw, modelH / ch)
      if info and info.native then k = k * 0.76 end
      local dw, dh = cw * k, ch * k
      G.setColor(1, 1, 1, 1)
      G.draw(canvas, modelX + (modelW - dw) * 0.5,
        top + (modelH - dh) * 0.5, 0, k, k)
    end
  elseif not paintedCrystal then
    local f1 = font(math.max(15 * s, wh * 0.019))
    local f2 = font(math.max(10 * s, wh * 0.013))
    if f1 then G.setFont(f1) end
    G.setColor(1, 1, 1, 0.82)
    G.printf(not seen and "POKéMON UNKNOWN" or "3D MODEL UNAVAILABLE",
      modelX + margin * 0.4, top + modelH * 0.42,
      modelW - margin * 0.8, "center")
    if f2 then G.setFont(f2) end
    G.setColor(1, 1, 1, 0.46)
    local text
    if not seen then
      text = "SEE THIS POKéMON TO REVEAL ITS MODEL"
    elseif info and info.disabled then
      text = "3D POKéMON MODELS IS OFF IN MOD SETTINGS"
    elseif info and info.error then
      text = "THE STADIUM 2 PREVIEW COULD NOT BE BUILT"
    else
      text = "IMPORT / BUILD THE STADIUM 2 MODEL PACK IN MOD SETTINGS"
    end
    G.printf(text, modelX + margin * 0.4, top + modelH * 0.54,
      modelW - margin * 0.8, "center")
  end

  return true
end

local function numberedDexOrder(dex)
  local keyed = {}
  for species, entry in pairs((dex and dex.entries) or {}) do
    local n = tonumber(entry and entry.dex)
    if n then keyed[#keyed + 1] = { n = n, species = species } end
  end
  table.sort(keyed, function(a, b)
    if a.n == b.n then return tostring(a.species) < tostring(b.species) end
    return a.n < b.n
  end)
  local out = {}
  for i, row in ipairs(keyed) do out[i] = row.species end
  return out
end
M.numberedDexOrder = numberedDexOrder

local function pokedexEntryText(screen, row)
  if not row then return "" end
  local entry = screen.dex and screen.dex.entries and screen.dex.entries[row.species]
  if not entry then return "" end
  local page = tonumber(screen.page) or 1
  return page == 2 and (entry.text2 or entry.text or "") or (entry.text or entry.text2 or "")
end

local function dexMapCanvas(screen, region)
  local G = love.graphics
  screen._vascDexMapCanvases = screen._vascDexMapCanvases or {}
  local canvas = screen._vascDexMapCanvases[region]
  if not (canvas and type(canvas.getDimensions) == "function") then
    local ok, made = pcall(G.newCanvas, 160, 144)
    if not ok or not made then return nil end
    canvas = made
    if type(canvas.setFilter) == "function" then
      pcall(canvas.setFilter, canvas, "nearest", "nearest")
    end
    screen._vascDexMapCanvases[region] = canvas
  end
  local cells = screen.mapGfx and screen.mapGfx.maps
    and screen.mapGfx.maps[region]
  if not cells or type(screen.drawTilemap) ~= "function" then return nil end
  local previous = type(G.getCanvas) == "function" and G.getCanvas() or nil
  local ok = pcall(function()
    G.setCanvas(canvas)
    G.origin()
    G.clear(0, 0, 0, 1)
    screen:drawTilemap(cells)
    G.setCanvas(previous)
  end)
  if not ok then pcall(G.setCanvas, previous); return nil end
  return canvas
end

local function drawDexAreaMap(screen, geo, ww, wh, region, nests, mapRect)
  local G = love.graphics
  local panorama = worldPanorama()
  local canvas = not panorama and dexMapCanvas(screen, region) or nil
  if not panorama and not canvas then return false end
  local s = geo.s or uiScaleFor(ww, wh)
  local margin = geo.margin or math.max(18 * s, wh * 0.025)
  local x, y, w, h
  if type(mapRect) == "table" then
    x, y, w, h = mapRect.x, mapRect.y, mapRect.w, mapRect.h
  else
    x, y = margin, geo.y
    w, h = math.max(0, geo.x - margin * 2), geo.h
  end
  if w < 170 * s then return false end
  local mapGeo = rectGeometry({ x=x, y=y, w=w, h=h }, ww, wh, 1, 1)
  panel(x, y, w, h, mapGeo.r, 0.94, s)
  header(G, region:upper() .. " ENCOUNTER MAP",
    tostring(#nests) .. " VISITED-STATE-AWARE AREA" .. (#nests == 1 and "" or "S"),
    x, y, w, mapGeo.headerH, wh, s)
  local pad = math.max(12 * s, mapGeo.gap * 1.5)
  local top = y + mapGeo.headerH + pad
  local bottom = y + h - math.max(38 * s, mapGeo.footerH)
  local sourceW, sourceH = 160, 144
  local view
  local iw, ih
  if panorama then
    iw, ih = panorama:getDimensions()
    view = WORLD_PANORAMA_FRAME[region] or WORLD_PANORAMA_FRAME.johto
    sourceW, sourceH = iw * view.w, ih * view.h
  end
  local k = math.min((w - pad * 2) / sourceW, (bottom - top) / sourceH)
  local mapW, mapH = sourceW * k, sourceH * k
  local mapX = x + (w - mapW) * 0.5
  local mapY = top + (bottom - top - mapH) * 0.5
  drawBitmapMapFrame(screen, mapX, mapY, mapW, mapH, s)
  G.setColor(1, 1, 1, 1)
  if panorama then
    local quad = G.newQuad(view.x * iw, view.y * ih,
      sourceW, sourceH, iw, ih)
    G.draw(panorama, quad, mapX, mapY, 0, k, k)
  else
    G.draw(canvas, mapX, mapY, 0, k, k)
  end
  Gen2Nests = engineModule(Gen2Nests, "src.core.gen2.Nests")
  if Gen2Nests then
    for _, index in ipairs(nests) do
      local mark = Gen2Nests.landmark(screen.data, index)
      if mark and mark.x and mark.y then
        local px, py
        if panorama then
          px, py = panoramaViewPoint(screen, mark, view,
            mapX, mapY, mapW, mapH)
        else
          px, py = mapX + mark.x * k, mapY + mark.y * k
        end
        if px and py then
          G.setColor(1.0, 0.28, 0.18, 0.95)
          G.circle("fill", px, py, math.max(2, 3.1 * s))
        end
      end
    end
  end
  footer(G, "LEFT/RIGHT REGION    RED = ENCOUNTER AREA    CIRCLE/B BACK",
    x, y, w, h, mapGeo.gap, wh, s)
  return true
end

local function dexAreaRows(screen, region)
  Gen2Nests = engineModule(Gen2Nests, "src.core.gen2.Nests")
  local current = type(screen.current) == "function" and screen:current() or nil
  local save = screen.game and screen.game.save
  local nests = Gen2Nests and current
    and Gen2Nests.find(screen.data, current.species, region, save) or {}
  local rows = {}
  for _, index in ipairs(nests) do
    local mark = Gen2Nests and Gen2Nests.landmark(screen.data, index)
    rows[#rows + 1] = {
      name = cleanText(mark and mark.name or ("LANDMARK " .. tostring(index))),
      meta = region:upper(),
    }
  end
  if #rows == 0 then
    rows[1] = { name = "AREA UNKNOWN", meta = region:upper(), disabled = true }
  end
  return rows, nests, current
end

local function drawUnownPreview(screen, geo, ww, wh, letter, label, word,
    previewRect)
  local G = love.graphics
  local s = geo.s or uiScaleFor(ww, wh)
  local margin = geo.margin or math.max(18 * s, wh * 0.025)
  local x, y, w, h
  if type(previewRect) == "table" then
    x, y, w, h = previewRect.x, previewRect.y, previewRect.w, previewRect.h
  else
    x, y = margin, geo.y
    w, h = math.max(0, geo.x - margin * 2), geo.h
  end
  if w < 170 * s then return false end
  local previewGeo = rectGeometry({ x=x, y=y, w=w, h=h }, ww, wh, 1, 1)
  panel(x, y, w, h, previewGeo.r, 0.94, s)
  header(G, "UNOWN " .. cleanText(label), cleanText(word),
    x, y, w, previewGeo.headerH, wh, s)
  local ok, canvas = pcall(G.newCanvas, 56, 56)
  if ok and canvas and letter and type(screen.drawUnownPic) == "function" then
    local previous = type(G.getCanvas) == "function" and G.getCanvas() or nil
    local painted = pcall(function()
      G.setCanvas(canvas)
      G.origin()
      G.clear(0, 0, 0, 0)
      screen:drawUnownPic(letter, 0, 0)
      G.setCanvas(previous)
    end)
    if painted then
      local availableH = h - previewGeo.headerH - previewGeo.footerH
        - previewGeo.gap * 3
      local k = math.min((w * 0.72) / 56, (availableH * 0.78) / 56)
      G.setColor(1, 1, 1, 1)
      G.draw(canvas, x + (w - 56 * k) * 0.5,
        y + previewGeo.headerH + (availableH - 56 * k) * 0.5, 0, k, k)
    else
      pcall(G.setCanvas, previous)
    end
  end
  footer(G, "LEFT/RIGHT FORM    CROSS/A OR CIRCLE/B BACK",
    x, y, w, h, previewGeo.gap, wh, s)
  return true
end

local function pokedexRenderer(screen, ww, wh)
  local view = screen.view or "list"
  local supported = {
    list = true, results = true, entry = true, area = true,
    option = true, search = true, unown = true,
  }
  if not supported[view] then return false end
  if not beginDraw(ww, wh, screen) then return false end
  local dexRegion = kantoAtlasUnlocked(screen) and "JOHTO + KANTO" or "JOHTO"
  local workspace = drawWideWorkspaceShell(ww, wh, "ASCENDANT DEX",
    dexRegion .. " / 251 POKéMON", {
      primaryRatio=KANTO_DEX_PRIMARY / (KANTO_DEX_PRIMARY + KANTO_DEX_RAIL),
      footer="D-PAD SELECT    CROSS/A CONFIRM    CIRCLE/B BACK",
    })

  if view == "list" or view == "results" then
    local rows = {}
    for _, row in ipairs(type(screen.rows) == "table" and screen.rows or {}) do
      local name = row.seen and (type(screen.monName) == "function" and screen:monName(row.species) or row.species) or "?????"
      rows[#rows + 1] = {
        name = cleanText(name),
        value = row.dex and ("#%03d"):format(tonumber(row.dex) or 0) or "",
        meta = row.caught and "CAUGHT" or (row.seen and "SEEN" or "UNKNOWN"),
        disabled = not row.seen,
      }
    end
    local seen, caught = 0, 0
    if type(screen.totals) == "function" then
      local ok, a, b = pcall(screen.totals, screen)
      if ok then seen, caught = a or 0, b or 0 end
    end
    local mode = "NUMBER"
    local dexIndex = math.max(1, math.min(#rows > 0 and #rows or 1,
      tonumber(screen.index) or 1))
    local geo = rectGeometry(workspace.primary, ww, wh, #rows, 9)
    drawListPanel(ww, wh, "POKéDEX",
      ("%s    SEEN %d    OWN %d    %d/%d"):format(mode, seen, caught,
        dexIndex, #rows),
      rows, dexIndex, nil,
      { geo=geo, maxRows=9,
        scrollbar = true,
        footer = "D-PAD SELECT    CROSS/A ENTRY    SELECT OPTIONS    START SEARCH    CIRCLE/B BACK" })
    local current = type(screen.current) == "function" and screen:current() or nil
    local viewerGeo = rectGeometry(workspace.rail, ww, wh, 1, 1)
    viewerGeo.directPanel = true
    pokedexModelPanel(screen, current, viewerGeo, ww, wh)
  elseif view == "entry" then
    local row = type(screen.current) == "function" and screen:current() or nil
    local name = row and (type(screen.monName) == "function" and screen:monName(row.species) or row.species) or "POKéMON"
    local entry = row and screen.dex and screen.dex.entries and screen.dex.entries[row.species] or nil
    local rows = {
      { "POKéMON", cleanText(name) },
      { "NUMBER", row and row.dex and ("#%03d"):format(tonumber(row.dex) or 0) or "—" },
      { "TYPE", cleanText(entry and entry.kind or "") },
      { "PAGE", tostring(tonumber(screen.page) or 1) .. "/2" },
    }
    local splitGap = workspace.gap
    local infoRect = { x=workspace.primary.x, y=workspace.primary.y,
      w=workspace.primary.w,
      h=workspace.primary.h * 0.43 - splitGap * 0.5 }
    local textRect = { x=workspace.primary.x,
      y=infoRect.y + infoRect.h + splitGap, w=workspace.primary.w,
      h=workspace.primary.h - infoRect.h - splitGap }
    local infoGeo = rectGeometry(infoRect, ww, wh, #rows, #rows)
    drawInfoRows(ww, wh, "POKéDEX ENTRY", cleanText(name), rows,
      { geo=infoGeo, footer="LEFT/RIGHT ACTION    CROSS/A SELECT" })
    drawTextPanelAt(textRect, ww, wh, cleanText(name),
      "DEX ENTRY / PAGE " .. tostring(tonumber(screen.page) or 1),
      pokedexEntryText(screen, row), "CIRCLE/B LIST")
    local actions = { "PAGE", "AREA", "CRY", "PRNT" }
    local viewerRect = { x=workspace.rail.x, y=workspace.rail.y,
      w=workspace.rail.w, h=workspace.rail.h * 0.61 }
    local actionRect = { x=workspace.rail.x,
      y=viewerRect.y + viewerRect.h + splitGap, w=workspace.rail.w,
      h=workspace.rail.h - viewerRect.h - splitGap }
    local viewerGeo = rectGeometry(viewerRect, ww, wh, 1, 1)
    viewerGeo.directPanel = true
    pokedexModelPanel(screen, row, viewerGeo, ww, wh)
    local actionRows = {}
    for _, action in ipairs(actions) do actionRows[#actionRows + 1] = { name=action } end
    local actionGeo = rectGeometry(actionRect, ww, wh, #actionRows, #actionRows)
    drawListPanel(ww, wh, "ACTIONS", "POKéDEX", actionRows,
      tonumber(screen.entryAction) or 1, 0, { geo=actionGeo,
        footer="LEFT/RIGHT SELECT    A CONFIRM" })
  elseif view == "area" then
    local region = type(screen.areaRegionName) == "function"
      and tostring(screen:areaRegionName()):lower() or "johto"
    if not kantoAtlasUnlocked(screen) then region = "johto" end
    local rows, nests, current = dexAreaRows(screen, region)
    local name = current and (type(screen.monName) == "function"
      and screen:monName(current.species) or current.species) or "POKéMON"
    local geo = rectGeometry(workspace.rail, ww, wh, #rows, 9)
    drawListPanel(ww, wh, "ENCOUNTER AREAS",
      cleanText(name) .. " / " .. region:upper(), rows, 1, 0,
      { geo=geo, maxRows=9,
        scrollbar = true,
        footer = "LEFT/RIGHT REGION    CROSS/A OR CIRCLE/B BACK" })
    drawDexAreaMap(screen, geo, ww, wh, region, nests, workspace.primary)
  elseif view == "search" then
    local rows = {
      { name = "TYPE 1", value = type(screen.searchTypeName) == "function"
          and cleanText(screen:searchTypeName(1)) or "-----" },
      { name = "TYPE 2", value = type(screen.searchTypeName) == "function"
          and cleanText(screen:searchTypeName(2)) or "-----" },
      { name = "BEGIN SEARCH", meta = "FILTER SEEN POKéMON" },
      { name = "CANCEL", meta = "RETURN TO DEX" },
    }
    local geo = rectGeometry(workspace.primary, ww, wh, #rows, #rows)
    drawListPanel(ww, wh, "MODERN DEX SEARCH",
      "TYPE FILTER", rows, tonumber(screen.searchIndex) or 1, 0,
      { geo=geo,
        footer = "UP/DOWN ROW    LEFT/RIGHT TYPE    CROSS/A SELECT    CIRCLE/B BACK" })
    drawTextPanelAt(workspace.rail, ww, wh, "SEARCH", "SEEN POKéMON",
      cleanText(screen.searchMessage or
        "Choose one or two types. Search returns only POKéMON already seen."),
      "CIRCLE/B BACK")
  elseif view == "unown" then
    Gen2Unown = engineModule(Gen2Unown, "src.core.gen2.Unown")
    local forms = type(screen.unownDex) == "function" and screen:unownDex() or {}
    local selected = math.max(1, math.min(#forms > 0 and #forms or 1,
      (tonumber(screen.unownIndex) or 0) + 1))
    local rows = {}
    for _, form in ipairs(forms) do
      rows[#rows + 1] = {
        name = Gen2Unown and cleanText(Gen2Unown.name(form)) or tostring(form),
        meta = Gen2Unown and cleanText(Gen2Unown.word(form)) or "UNOWN",
      }
    end
    if #rows == 0 then rows[1] = { name = "NO FORMS CAUGHT", disabled = true } end
    local geo = rectGeometry(workspace.primary, ww, wh, #rows, 11)
    drawListPanel(ww, wh, "UNOWN DEX", "CAUGHT ORDER",
      rows, selected, 0, { geo=geo, maxRows=11, scrollbar = true,
        footer = "LEFT/RIGHT FORM    CROSS/A OR CIRCLE/B BACK" })
    local letter = forms[selected]
    drawUnownPreview(screen, geo, ww, wh, letter,
      Gen2Unown and Gen2Unown.name(letter) or tostring(letter or "?"),
      Gen2Unown and Gen2Unown.word(letter) or "", workspace.rail)
  else
    local labels = {}
    local optionRows = type(screen.optionRows) == "function" and screen:optionRows() or nil
    for _, row in ipairs(optionRows or {}) do labels[#labels + 1] = cleanText(row.label or row.mode) end
    if #labels == 0 then labels = { "NEW POKéDEX MODE", "OLD POKéDEX MODE", "A TO Z MODE" } end
    local optionRowsWide = {}
    for _, label in ipairs(labels) do optionRowsWide[#optionRowsWide + 1] = { name=label } end
    local optionGeo = rectGeometry(workspace.primary, ww, wh,
      #optionRowsWide, #optionRowsWide)
    drawListPanel(ww, wh, "POKéDEX MODE", "SORT / DISPLAY", optionRowsWide,
      tonumber(screen.optionIndex) or 1, 0, { geo=optionGeo,
        footer="UP/DOWN SELECT    CROSS/A CONFIRM    CIRCLE/B BACK" })
    drawTextPanelAt(workspace.rail, ww, wh, "DEX MODE", dexRegion,
      "The native Gold, Silver and Crystal ordering modes remain active. This screen changes presentation only.",
      "")
  end

  endDraw()
  return true
end

local function patchScreen(path, renderer)
  local ok, Class = pcall(require, path)
  if not (ok and type(Class) == "table" and type(Class.new) == "function") then
    return false, path .. ".new unavailable"
  end
  -- `_stadium2PauseSubmenuPatched` was also written by the retired generic
  -- skin.  Treating that shared marker as ownership skipped PACK/CARD/GEAR on
  -- profiles upgraded from an older VASC build.  This module has its own
  -- marker and may safely wrap the already-decorated native methods once.
  if Class._vascGen2GoldSubmenuPatched then
    M.targets[path] = true
    return true
  end

  local nativeNew = Class.new
  local nativeUpdate = Class.update
  local nativeDraw = Class.draw
  local nativeWide = Class.drawWidescreen
  local nativeOpaque = Class.isOpaque

  -- The modern Pokédex is a catalog first: keep its backing row array in
  -- strict National Dex number order so cursor/index/current() all agree with
  -- what is drawn. GAME DEFAULT retains Gold's NEW/OLD/A-Z behavior exactly.
  if path == "src.ui.gen2.PokedexMenu" and type(Class.order) == "function" then
    local nativeOrder = Class.order
    Class.order = function(self, ...)
      if modernDexEnabled() then return numberedDexOrder(self and self.dex) end
      return nativeOrder(self, ...)
    end
  end

  Class.new = function(game, opts, ...)
    -- Presentation context is captured from the engine-owned caller.  A
    -- normal START party and a regular battle party have independent options;
    -- tutorial/contest/Safari/link flows deliberately receive no tag and stay
    -- native.  No callback or update method is replaced.
    local context = partyContext(game, path, opts)
    local instance = nativeNew(game, opts, ...)
    if path == "src.ui.gen2.BoxMenu" and type(instance) == "table" then
      decorateBoxSearch(instance)
    end
    if context and type(instance) == "table" then
      instance._vascGen2PartyUiContext = context
      if path == "src.ui.gen2.PackMenu" then decoratePackInput(instance) end
      instance._stadium2PauseSkin = contextUsesOras(context, path)
      instance._stadium2PauseSkinChain = true
      instance._stadium2Party3dSkin = path ~= "src.ui.gen2.PartyMenu"
      -- Glass party/summary screens intentionally leave the live world or
      -- battlefield visible underneath. Other pause submenus keep the old
      -- pause-only rule.
      if instance._stadium2PauseSkin then
        if path == "src.ui.gen2.PartyMenu" then
          local decorate = SharedParty and SharedParty.decoratePartyMenu
          local top = stackTop(game)
          local battle = type(top) == "table" and top.battle or nil
          local ok, decorated = false, nil
          if type(decorate) == "function" then
            ok, decorated = pcall(decorate, instance, {
              context=context == "battle" and "battle" or "start",
              battle=battle,
              language=presentationLanguage(game),
              chromeAccent=editionChromeFor(instance),
            })
          end
          if ok and decorated == instance then
            instance.isOpaque = true
            instance._vascGen2SharedOrasParty = true
            local sharedUpdate = rawget(instance, "update") or instance.update
            local sharedDraw = rawget(instance, "draw") or instance.draw
            local sharedWide = rawget(instance, "drawWidescreen")
              or instance.drawWidescreen
            if type(sharedUpdate) == "function" and type(nativeUpdate) == "function" then
              instance.update = function(self, ...)
                if contextUsesOras(self._vascGen2PartyUiContext, path) then
                  self.isOpaque = true
                  return sharedUpdate(self, ...)
                end
                self.isOpaque = nativeOpaque
                return nativeUpdate(self, ...)
              end
            end
            if type(sharedDraw) == "function" then
              instance.draw = function(self, ...)
                if contextUsesOras(self._vascGen2PartyUiContext, path) then
                  self.isOpaque = true
                  return sharedDraw(self, ...)
                end
                self.isOpaque = nativeOpaque
                return nativeDraw(self, ...)
              end
            end
            if type(sharedWide) == "function" and type(nativeWide) == "function" then
              instance.drawWidescreen = function(self, ww, wh, ...)
                if contextUsesOras(self._vascGen2PartyUiContext, path) then
                  self.isOpaque = true
                  return sharedWide(self, ww, wh, ...)
                end
                self.isOpaque = nativeOpaque
                return nativeWide(self, ww, wh, ...)
              end
            end
            M.tagged = M.tagged + 1
          else
            -- A presentation provider is optional; native PartyMenu remains a
            -- complete safe owner. Never fall back to the retired brown 3D
            -- preview when the selected shared provider could not decorate.
            -- The shared full-card decorator is preferred, but the local
            -- responsive ORAS renderer is a complete presentation fallback.
            -- Falling all the way back to Crystal here made a harmless preview
            -- provider miss look as if the user's ORAS option did nothing.
            instance._vascGen2SharedPartyFallback = true
            instance._stadium2PauseSkin = true
            instance.isOpaque = false
            M.tagged = M.tagged + 1
            if type(decorate) == "function" and not ok then
              M.lastError = path .. ": " .. tostring(decorated)
            end
          end
        elseif path == "src.ui.gen2.SummaryMenu" then
          local decorate = SharedSummary and SharedSummary.decorateSummaryMenu
          local originalUpdate = rawget(instance, "update") or instance.update
          local originalDraw = rawget(instance, "draw") or instance.draw
          local originalWide = rawget(instance, "drawWidescreen")
            or instance.drawWidescreen
          local ok, decorated = false, nil
          if type(decorate) == "function" then
            ok, decorated = pcall(decorate, instance, {
              pageCount=3,
              language=presentationLanguage(game),
              chromeAccent=editionChromeFor(instance),
            })
          end
          if ok and decorated == instance then
            instance.isOpaque = true
            instance._vascGen2SharedOrasSummary = true
            local sharedUpdate = rawget(instance, "update") or instance.update
            local sharedDraw = rawget(instance, "draw") or instance.draw
            local sharedWide = rawget(instance, "drawWidescreen")
              or instance.drawWidescreen
            if type(sharedUpdate) == "function" and type(originalUpdate) == "function" then
              instance.update = function(self, ...)
                if contextUsesOras(self._vascGen2PartyUiContext, path) then
                  self.isOpaque = true
                  return sharedUpdate(self, ...)
                end
                self.isOpaque = nativeOpaque
                return originalUpdate(self, ...)
              end
            end
            if type(sharedDraw) == "function" and type(originalDraw) == "function" then
              instance.draw = function(self, ...)
                if contextUsesOras(self._vascGen2PartyUiContext, path) then
                  self.isOpaque = true
                  return sharedDraw(self, ...)
                end
                self.isOpaque = nativeOpaque
                return originalDraw(self, ...)
              end
            end
            if type(sharedWide) == "function" then
              instance.drawWidescreen = function(self, ww, wh, ...)
                if contextUsesOras(self._vascGen2PartyUiContext, path) then
                  self.isOpaque = true
                  return sharedWide(self, ww, wh, ...)
                end
                self.isOpaque = nativeOpaque
                local fallback = originalWide or originalDraw
                if type(fallback) == "function" then
                  return fallback(self, ww, wh, ...)
                end
              end
            end
            diagnosticOnce(instance, "summary-shared", "gen2-menu-provider", {
              screen="SUMMARY", provider="shared-oras-summary", result="active",
              edition=editionForScreen(instance),
            })
            M.tagged = M.tagged + 1
          else
            -- The local renderer remains a complete fail-open presentation,
            -- but the shared presenter is the normal path because it owns the
            -- bundled Crystal front and full KASC Summary hierarchy.
            instance.isOpaque = false
            M.tagged = M.tagged + 1
            if type(decorate) == "function" and not ok then
              M.lastError = path .. ": " .. tostring(decorated)
            end
          end
        else
          instance.isOpaque = false
          M.tagged = M.tagged + 1
        end
      end
    end
    return instance
  end

  if type(nativeDraw) == "function" then
    Class.draw = function(self, ...)
      local useOras = self and contextUsesOras(
        self._vascGen2PartyUiContext, path)
      if not useOras then
        if self then self.isOpaque = nativeOpaque end
        return nativeDraw(self, ...)
      end
      if self and self._vascGen2PartyUiContext then
        self._stadium2PauseSkin = true
        self.isOpaque = false
        local ww, wh = targetDimensions()
        local okDraw, handled = pcall(renderer, self, ww, wh)
        if okDraw and handled then M.lastError = nil return end
        if not okDraw then M.lastError = path .. ": " .. tostring(handled) end
      end
      return nativeDraw(self, ...)
    end
  end

  if type(nativeWide) == "function" then
    Class.drawWidescreen = function(self, ww, wh, ...)
      local useOras = self and contextUsesOras(
        self._vascGen2PartyUiContext, path)
      if not useOras then
        if self then self.isOpaque = nativeOpaque end
        return nativeWide(self, ww, wh, ...)
      end
      if self and self._vascGen2PartyUiContext then
        self._stadium2PauseSkin = true
        self.isOpaque = false
        local okDraw, handled = pcall(renderer, self, ww, wh)
        if okDraw and handled then M.lastError = nil return end
        if not okDraw then M.lastError = path .. ": " .. tostring(handled) end
      end
      return nativeWide(self, ww, wh, ...)
    end
  end

  if path == "src.ui.gen2.PartyMenu" or path == "src.ui.gen2.SummaryMenu"
      or path == "src.ui.gen2.PokedexMenu" or path == "src.ui.gen2.BoxMenu" then
    local nativeExit = Class.exit
    Class.exit = function(self, ...)
      if path == "src.ui.gen2.BoxMenu" then
        if self and self._vascGen2SearchOpen then endGen2Search(self) end
      else
        local preview = partyPreviewModule()
        if preview and type(preview.release) == "function" then
          pcall(preview.release, self)
        end
      end
      if type(nativeExit) == "function" then return nativeExit(self, ...) end
    end
  end

  Class._vascGen2GoldSubmenuPatched = true
  Class._stadium2PauseSubmenuPatched = true
  M.targets[path] = true
  return true
end

-- Screens.resolve deliberately allows a registry-owned Gen2* factory to beat
-- the built-in class.  Constructor patching alone therefore cannot guarantee
-- presentation parity.  Decorate the settled instance emitted by the real
-- StateStack screen.pushed event as a second, id-based boundary.  Only draw
-- methods are replaced; update/input/callback/save ownership stays with the
-- resolved factory and every failure calls its original renderer.
local function installResolvedScreenWatcher(specs)
  local events = mod and mod.events
  if not (events and type(events.on) == "function") then
    return false, "mod.events unavailable for resolved Gen-2 screens"
  end
  local byId = {}
  for _, spec in ipairs(specs) do
    local short = tostring(spec[1]):match("src%.ui%.gen2%.(.+)$")
    if short then
      byId["Gen2" .. short] = { path=spec[1], renderer=spec[2] }
    end
  end
  local ok, err = pcall(events.on, events, "screen.pushed", function(event)
    local state = type(event) == "table" and event.state or nil
    local screenId = type(state) == "table" and tostring(state.screenId or "") or ""
    local spec = byId[screenId]
    if not spec or state._vascGen2ResolvedPresentation then return end

    local context = partyContext(state.game, spec.path, state)
    state._vascGen2PartyUiContext = state._vascGen2PartyUiContext or context
    if spec.path == "src.ui.gen2.PackMenu" then decoratePackInput(state) end
    if spec.path == "src.ui.gen2.BoxMenu" then decorateBoxSearch(state) end
    state._stadium2PauseSkin = contextUsesOras(
      state._vascGen2PartyUiContext, spec.path)
    state._stadium2PauseSkinChain = state._stadium2PauseSkin == true

    -- Built-in PARTY may already own the exact shared ORAS team renderer.
    -- Keep it and merely stamp the resolved-instance receipt; registry-owned
    -- party factories get the same decorator when their shape permits it.
    if screenId == "Gen2PartyMenu" and state._vascGen2SharedOrasParty then
      state._vascGen2ResolvedPresentation = "shared-party"
      diagnosticOnce(state, "resolved-presentation", "gen2-menu-provider", {
        screen=screenId, provider="resolved-shared-party", result="active",
      })
      return
    elseif screenId == "Gen2PartyMenu" and state._stadium2PauseSkin
        and SharedParty and type(SharedParty.decoratePartyMenu) == "function" then
      local decorated, result = pcall(SharedParty.decoratePartyMenu, state, {
        context=state._vascGen2PartyUiContext == "battle" and "battle" or "start",
        language=presentationLanguage(state.game),
        chromeAccent=editionChromeFor(state),
      })
      if decorated and result == state then
        state._vascGen2ResolvedPresentation = "shared-party"
        state._vascGen2SharedOrasParty = true
        diagnosticOnce(state, "resolved-presentation", "gen2-menu-provider", {
          screen=screenId, provider="resolved-shared-party", result="active",
        })
        return
      end
    elseif screenId == "Gen2SummaryMenu" and state._vascGen2SharedOrasSummary then
      state._vascGen2ResolvedPresentation = "shared-summary"
      diagnosticOnce(state, "resolved-presentation", "gen2-menu-provider", {
        screen=screenId, provider="resolved-shared-summary", result="active",
      })
      return
    elseif screenId == "Gen2SummaryMenu" and state._stadium2PauseSkin
        and SharedSummary and type(SharedSummary.decorateSummaryMenu) == "function" then
      local decorated, result = pcall(SharedSummary.decorateSummaryMenu, state, {
        pageCount=3,
        language=presentationLanguage(state.game),
        chromeAccent=editionChromeFor(state),
      })
      if decorated and result == state then
        state._vascGen2ResolvedPresentation = "shared-summary"
        state._vascGen2SharedOrasSummary = true
        diagnosticOnce(state, "resolved-presentation", "gen2-menu-provider", {
          screen=screenId, provider="resolved-shared-summary", result="active",
        })
        return
      end
    end

    local nativeDraw = state.draw
    local nativeWide = type(state.drawWidescreen) == "function"
      and state.drawWidescreen or nil
    local nativeOpaque = state.isOpaque
    if type(nativeDraw) ~= "function" then
      state._vascGen2ResolvedPresentation = "native-no-draw"
      diagnosticOnce(state, "resolved-presentation", "gen2-menu-provider", {
        screen=screenId, provider="resolved-instance", result="fallback",
        reason="draw unavailable",
      })
      return
    end

    local function wantsPresentation(self)
      return contextUsesOras(self._vascGen2PartyUiContext, spec.path)
    end
    local function drawResolved(self, ww, wh, fallback, ...)
      if wantsPresentation(self) then
        self._stadium2PauseSkin = true
        self._stadium2PauseSkinChain = true
        self.isOpaque = false
        local okDraw, handled = pcall(spec.renderer, self, ww, wh)
        if okDraw and handled then M.lastError = nil return end
        if not okDraw then
          M.lastError = spec.path .. " resolved: " .. tostring(handled)
        end
      else
        self.isOpaque = nativeOpaque
      end
      return fallback(self, ...)
    end

    state.draw = function(self, ...)
      local ww, wh = targetDimensions()
      return drawResolved(self, ww, wh, nativeDraw, ...)
    end
    state.drawWidescreen = function(self, ww, wh, ...)
      ww, wh = targetDimensions(ww, wh)
      local fallback = nativeWide or nativeDraw
      return drawResolved(self, ww, wh, fallback, ww, wh, ...)
    end
    state._vascGen2ResolvedPresentation = "specialized"
    state._vascGen2ResolvedNativeDraw = nativeDraw
    state._vascGen2ResolvedNativeWide = nativeWide
    M.resolved = (tonumber(M.resolved) or 0) + 1
    diagnosticOnce(state, "resolved-presentation", "gen2-menu-provider", {
      screen=screenId, provider="resolved-instance", result="active",
      path=spec.path,
    })
  end)
  if not ok then return false, tostring(err) end
  M.targets["screen.pushed#resolved-gen2"] = true
  return true
end

function M.install()
  if M.installed then return true end
  local okStart, Start = pcall(require, "src.ui.gen2.StartMenu")
  if not (okStart and type(Start) == "table") then
    return false, "src.ui.gen2.StartMenu unavailable"
  end
  StartMenuClass = Start

  local specs = {
    { "src.ui.gen2.PartyMenu", partyRenderer },
    { "src.ui.gen2.SummaryMenu", summaryRenderer },
    { "src.ui.gen2.PackMenu", packRenderer },
    { "src.ui.gen2.OptionsMenu", optionsRenderer },
    { "src.ui.gen2.SaveMenu", saveRenderer },
    { "src.ui.gen2.TrainerCard", trainerRenderer },
    { "src.ui.gen2.Pokegear", pokegearRenderer },
    { "src.ui.gen2.PokedexMenu", pokedexRenderer },
    { "src.ui.gen2.PcMenu", pcRenderer },
    { "src.ui.gen2.CenterPcMenu", pcRenderer },
    { "src.ui.gen2.ItemPcMenu", pcRenderer },
    { "src.ui.gen2.BoxMenu", boxRenderer },
    { "src.ui.gen2.MailboxMenu", mailboxRenderer },
    { "src.ui.gen2.DecorationMenu", decorationRenderer },
    { "src.ui.gen2.NamingScreen", namingRenderer },
  }
  local failures = {}
  for _, spec in ipairs(specs) do
    local ok, err = patchScreen(spec[1], spec[2])
    if not ok then failures[#failures + 1] = err end
  end
  if #failures > 0 then
    return false, table.concat(failures, "; ")
  end
  local watcherOk, watcherErr = installResolvedScreenWatcher(specs)
  if not watcherOk then return false, watcherErr end
  local starterOk, starterErr = patchStarterPresentation()
  if not starterOk then return false, starterErr end
  M.installed = true
  return true
end

function M.status()
  return {
    installed = M.installed,
    draws = M.draws,
    tagged = M.tagged,
    mapBitmapFrameDraws = M.mapBitmapFrameDraws,
    resolved = M.resolved or 0,
    targets = M.targets,
    lastError = M.lastError,
  }
end

-- Narrow QA seam: it exposes the production starter presentation without
-- changing World/Script ownership or the starter selection semantics.
M.drawStarterCrystalCard = drawStarterCrystalCard
M.trainerCardRegionLabel = trainerCardRegionLabel
M.drawTrainerBadgeCaseForQa = trainerBadgeCasePage
M.trainerCardBadgeCaseModel = function(player, regionName)
  local region = TRAINER_CARD_REGIONS[regionName]
  if not region then return nil end
  local entries = {}
  for index=1,8 do
    entries[index] = {
      leader=region.leaders[index], badge=region.badges[index],
      owned=trainerRegionBadgeOwned(player, regionName, index),
    }
  end
  return { region=regionName, title=region.title,
    owned=trainerRegionBadgeCount(player, regionName), entries=entries }
end
M.pokegearWorkspaceGeometry = pokegearWorkspaceGeometry
M.drawPokegearForQa = pokegearRenderer
M.bitmapMapFrameGeometry = bitmapMapFrameGeometry
M.drawBitmapMapFrameForQa = drawBitmapMapFrame
M.decorateBoxSearchForQa = decorateBoxSearch
M.rebuildGen2SearchForQa = rebuildGen2Search
M.gen2SearchTextForQa = gen2SearchText
M.gen2SearchKeyForQa = gen2SearchKey
M.pokegearPresentationState = function(screen, cardId)
  cardId = tostring(cardId or ((pokegearCard(screen) or {}).id) or "clock"):lower()
  local copy = POKEGEAR_CARD_COPY[cardId] or POKEGEAR_CARD_COPY.clock
  return {
    card = cardId,
    title = copy.label,
    eyebrow = copy.eyebrow,
    region = atlasRegionLabel(screen),
    mode = pokegearModeLabel(screen, cardId),
    kantoUnlocked = kantoAtlasUnlocked(screen),
  }
end

return M
