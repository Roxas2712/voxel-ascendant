-- Standalone VASC hub.  Kanto Ascendant may collect the same Start-menu row
-- into its own menu, but the screen itself has no dependency on KASC.

local V = ...
local VascMenu = {}

local PAGES = {
  {
    title="CAMERAS + WORLD",
    "VOXEL: ORBIT / 1ST / 3RD",
    "V OR ZR/R2 CYCLES VIEWS",
    "1ST/3RD RELEASE MOUSE ON",
    "APP FOCUS LOSS; CLICK GAME",
    "TO CAPTURE IT AGAIN.",
  },
  {
    title="BATTLES",
    "3D-BTL: MAP / ARENA / DISCS",
    "ARENA USES FIXED 3X FOOTING.",
    "STADIUM DIRECTS ARENA ONLY.",
    "BTL CAM 1X/2X/3X APPLIES",
    "TO MAP AND DISCS.",
  },
  {
    title="TIME + WEATHER",
    "DAYTIME AUTO BLENDS DAWN,",
    "DAY, DUSK AND NIGHT.",
    "MANUAL PHASES OVERRIDE AUTO.",
    "WEATHER AUTO FOLLOWS MAPS;",
    "FORCED MODES STAY SELECTED.",
  },
  {
    title="USER MUSIC",
    "OPEN USER MUSIC IN THIS MENU.",
    "ADD OWN AUDIO BY CATEGORY.",
    "RESCAN, THEN PICK ORIGINAL,",
    "SHUFFLE OR AN EXACT TRACK.",
    "BACK RESTORES GAME/KASC.",
  },
  {
    title="USER SPRITES",
    "README IN USER/SPRITES LISTS",
    "THE FILE NAMING CONTRACT.",
    "CUSTOM IS OFF BY DEFAULT.",
    "RESCAN ENABLES VALID PNGS;",
    "BACK RESTORES GAME/KASC.",
  },
  {
    title="CUSTOM FILES / DESKTOP",
    "WINDOWS SAVE ROOT:",
    "%APPDATA%/LOVE/POKEMON-LOVE2D",
    "MAC: ~/LIBRARY/APPLICATION",
    "SUPPORT/LOVE/POKEMON-LOVE2D",
    "LINUX: ~/.LOCAL/SHARE/LOVE/",
    "POKEMON-LOVE2D",
  },
  {
    title="CUSTOM FILES / MOBILE",
    "IOS FILES: ON MY IPHONE/",
    "GEN1RECOMP++/MODS/...",
    "ANDROID: ANDROID/DATA/",
    "COM.THEBOISCLUB.POKEMONRED/",
    "FILES/SAVE/POKEMON-LOVE2D",
    "THEN MODS/VOXEL_ASCENDANT",
  },
  {
    title="CUSTOM FILES / CONSOLE",
    "SWITCH: SDMC:/SWITCH/",
    "GEN1RECOMP/POKEMON-LOVE2D",
    "XBOX: LOCALSTATE/",
    "POKEMON-LOVE2D",
    "THEN MODS/VOXEL_ASCENDANT",
    "AND USER/MUSIC OR SPRITES",
  },
  {
    title="PERFORMANCE + SAFETY",
    "DEVICE PROFILE AUTO IS SAFE.",
    "ECO REDUCES COST; CUSTOM KEEPS",
    "YOUR INDIVIDUAL SETTINGS.",
    "PRELOAD IS RAM-ONLY. ORIGINAL",
    "RENDERING REMAINS THE FALLBACK.",
  },
}

local function font()
  return require("src.render.Font")
end

local function text(value, x, y, color)
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
  font().draw(value, x, y)
end

local function frame(x, y, w, h, fill, edge)
  love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 1)
  love.graphics.rectangle("fill", x, y, w, h)
  love.graphics.setColor(edge[1], edge[2], edge[3], edge[4] or 1)
  love.graphics.rectangle("line", x + .5, y + .5, w - 1, h - 1)
end

local function newHelp(game)
  local state = { game=game, isOpaque=true, page=1 }
  function state:update()
    local input = self.game.input
    if input:wasPressed("right") or input:wasPressed("a") then
      self.page = self.page % #PAGES + 1
    elseif input:wasPressed("left") then
      self.page = (self.page - 2) % #PAGES + 1
    elseif input:wasPressed("b") or input:wasPressed("start") then
      self.game.stack:pop()
    end
  end
  function state:draw()
    love.graphics.setColor(.025, .055, .065, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    frame(5, 5, 150, 128, {.055,.105,.105,1}, {.30,.82,.64,1})
    local page = PAGES[self.page]
    text("VASC HELP", 12, 11, {.95,.80,.27,1})
    text(page.title, 12, 27, {.55,1,.82,1})
    for i, line in ipairs(page) do text(line, 12, 35 + i * 12, {.90,.96,.90,1}) end
    text(("<  %d / %d  >"):format(self.page, #PAGES), 54, 119,
         {.58,.75,.70,1})
    text("B/START: BACK", 28, 131, {.58,.75,.70,1})
  end
  return state
end

local function restoreAll(game)
  local okMusic, music = pcall(function()
    return V and type(V.require) == "function" and V.require("LocalMusic")
  end)
  local okSprites, sprites = pcall(function()
    return V and type(V.require) == "function" and V.require("LocalSprites")
  end)
  local musicDone = okMusic and music
                    and type(music.backToDefault) == "function"
                    and music.backToDefault(game)
  local spritesDone = okSprites and sprites
                      and type(sprites.backToDefault) == "function"
                      and sprites.backToDefault(game)
  return musicDone == true and spritesDone == true
end

local function newHub(mod, game)
  local items = {
    {label="SETTINGS", screen="OptionsMenu"},
    {label="USER MUSIC", screen="VascUserMusic"},
    {label="USER SPRITES", screen="VascUserSprites"},
    {label="ALL TO GAME/KASC", action="restore"},
    {label="HELP", screen="VascHelp"},
  }
  local state = {game=game, isOpaque=true, items=items, index=1,
                 restoreStatus=nil}
  function state:update()
    local input = self.game.input
    if input:wasPressed("up") then
      self.index = (self.index - 2) % #self.items + 1
    elseif input:wasPressed("down") then
      self.index = self.index % #self.items + 1
    elseif input:wasPressed("start") then
      mod.ui.push(self.game, "VascHelp")
    elseif input:wasPressed("a") then
      local item = self.items[self.index]
      if item.action == "restore" then
        self.restoreStatus = restoreAll(self.game) and "GAME/KASC RESTORED"
                                                      or "RESTORE UNAVAILABLE"
      else
        mod.ui.push(self.game, item.screen)
      end
    elseif input:wasPressed("b") then
      self.game.stack:pop()
    end
  end
  function state:draw()
    love.graphics.setColor(.025, .055, .065, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    frame(5, 5, 150, 128, {.055,.105,.105,1}, {.30,.82,.64,1})
    text("VOXEL ASCENDANT", 16, 12, {.95,.80,.27,1})
    text("2.0.1", 112, 24, {.48,.75,.68,1})
    for i, item in ipairs(self.items) do
      local y = 31 + i * 15
      if i == self.index then
        frame(12, y - 3, 136, 16, {.12,.30,.25,1}, {.45,.95,.68,1})
        text(">", 16, y, {.95,.80,.27,1})
      end
      text(item.label, 28, y, i == self.index and {.95,1,.88,1}
                                      or {.68,.85,.78,1})
    end
    text(self.restoreStatus or "START: HELP", 12, 119, {.58,.75,.70,1})
    text("A: OPEN   B: BACK", 12, 131, {.58,.75,.70,1})
  end
  return state
end

function VascMenu.install(mod)
  local screens = mod and mod.content and mod.content.screens
  if not screens or type(screens.register) ~= "function" then return false end
  screens:register("VascMenu", {new=function(game) return newHub(mod, game) end})
  screens:register("VascHelp", {new=function(game) return newHelp(game) end})
  return true
end

VascMenu._newHub = newHub
VascMenu._newHelp = newHelp
VascMenu.restoreAll = restoreAll
VascMenu.pages = PAGES

return VascMenu
