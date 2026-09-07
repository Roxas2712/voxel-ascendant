-- User-owned loose music, loaded from the installed mod's user/ directory.
-- A rescan folds every valid audio file into the engine's normal registry, so
-- playback, volume, filters, pause/resume and battle restoration remain the
-- engine's responsibility.

local V = ...
local LocalMusic = {}
local UserFiles = V.require("UserFiles")

LocalMusic.API_VERSION = 2
LocalMusic.ROOT = "user/music"
LocalMusic.KEY_PREFIX = "localMusic."
LocalMusic.ENABLED_KEY = "localMusic.enabled"

local CATEGORIES = {
  { id="wild", label="WILD BATTLES" },
  { id="trainer", label="TRAINER BATTLES" },
  { id="rival", label="RIVAL BATTLES" },
  { id="gym", label="GYM BATTLES" },
  { id="elite4", label="ELITE FOUR" },
  { id="champion", label="CHAMPION" },
  { id="field", label="FIELD / MAP" },
  { id="bike", label="BICYCLE" },
  { id="surf", label="SURF" },
  { id="victory", label="VICTORY" },
  { id="evolution", label="EVOLUTION / HATCH" },
  { id="title", label="TITLE" },
  { id="halloffame", label="HALL OF FAME" },
  { id="credits", label="CREDITS" },
  { id="jingle", label="SHORT JINGLES" },
  { id="scene", label="OTHER SCENES" },
}
local BY_ID = {}
for _, category in ipairs(CATEGORIES) do BY_ID[category.id] = category end

local GROUPS = {
  { id="battle", label="BATTLE THEMES",
    categories={"wild", "trainer", "rival", "gym", "elite4", "champion"} },
  { id="world", label="WORLD THEMES",
    categories={"field", "bike", "surf"} },
  { id="events", label="RESULTS / EVENTS",
    categories={"victory", "evolution", "jingle"} },
  { id="scenes", label="TITLE / SCENES",
    categories={"title", "halloffame", "credits", "scene"} },
}
local GROUP_BY_ID = {}
for _, group in ipairs(GROUPS) do GROUP_BY_ID[group.id] = group end

local EXTENSIONS = { mp3=true, ogg=true, wav=true, flac=true }
local tracks = {}
local replacements = {}
local registered = {}
local selected = {}
local enabled = false
local lastChoice = {}
local activeBattle = nil
local serial = 0
local observedCategories = {}
local observedExact = {}
local lastResolved = nil
local previewSession = nil

local function exists(path, kind)
  return UserFiles.info(path, kind) ~= nil
end

local function ensureTree()
  return exists(LocalMusic.ROOT .. "/README.txt", "file")
end

local function fileExtension(name)
  local ext = type(name) == "string" and name:match("%.([^.]+)$")
  return ext and string.lower(ext) or nil
end

local function displayName(name)
  local stem = name:gsub("%.[^.]+$", "")
  stem = stem:gsub("[_%-]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return stem ~= "" and stem or name
end

local function hash(value)
  local h = 2166136261
  for i = 1, #value do h = (h * 16777619 + value:byte(i)) % 2147483647 end
  return h
end

local function songId(category, filename)
  return ("VASC_LOCAL_%s_%08X"):format(string.upper(category),
                                        hash(category .. "/" .. filename))
end

local function directoryItems(path)
  local items = UserFiles.list(path)
  table.sort(items, function(a, b) return string.lower(a) < string.lower(b) end)
  return items
end

local function scan(mod)
  tracks, replacements = {}, {}
  ensureTree()
  local registry = mod and mod.content and mod.content.music
  for _, category in ipairs(CATEGORIES) do
    local list, seen = {}, {}
    local dir = LocalMusic.ROOT .. "/" .. category.id
    for _, filename in ipairs(directoryItems(dir)) do
      local ext = fileExtension(filename)
      local path = dir .. "/" .. filename
      if EXTENSIONS[ext] and exists(path, "file") then
        local id = songId(category.id, filename)
        if not seen[id] and registry and type(registry.register) == "function" then
          local assetPath = UserFiles.path(path)
          local ok = assetPath ~= nil
          if ok and not registered[id] then
            ok = pcall(registry.register, registry, id, { file=assetPath })
            if ok then registered[id] = true end
          end
          if ok and registered[id] then
            local track = { id=id, category=category.id, file=path,
                            assetPath=assetPath, filename=filename,
                            label=displayName(filename) }
            list[#list + 1] = track
            seen[id] = true
          end
        end
      end
    end
    tracks[category.id] = list
  end
  -- Exact replacement lane for every engine/KASC song ID. This deliberately
  -- has no one-row-per-song options UI: placing Music_WildBattle.mp3 in the
  -- folder means "replace that final resolved cue", while the category menus
  -- remain the convenient selection/shuffle layer above it.
  local seen = {}
  for _, filename in ipairs(directoryItems(LocalMusic.ROOT .. "/replace")) do
    local ext = fileExtension(filename)
    local originalId = filename:gsub("%.[^.]+$", "")
    local path = LocalMusic.ROOT .. "/replace/" .. filename
    if EXTENSIONS[ext] and originalId:match("^[A-Za-z0-9_.%-]+$")
       and not seen[originalId] and exists(path, "file") then
      local id = songId("replace", filename)
      local assetPath = UserFiles.path(path)
      local ok = assetPath ~= nil
      if ok and not registered[id]
         and registry and type(registry.register) == "function" then
        ok = pcall(registry.register, registry, id, { file=assetPath })
        if ok then registered[id] = true end
      end
      if ok and registered[id] then
        local track = { id=id, category="replace", file=path,
                        assetPath=assetPath, filename=filename,
                        originalId=originalId, label=displayName(filename) }
        replacements[originalId] = track
        seen[originalId] = true
      end
    end
  end
  return tracks
end

local function gameBuckets(game)
  local id = (V.mod and V.mod.id) or "VOXEL_ASCENDANT"
  local options = game and game.save and game.save.options
  if options then
    options.modOptions = options.modOptions or {}
    options.modOptions[id] = options.modOptions[id] or {}
  end
  local loader = game and game.mods
  if loader then
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[id] = loader.modOptions[id] or {}
  end
  return options and options.modOptions[id], loader and loader.modOptions[id]
end

local function trackById(category, id)
  for _, track in ipairs(tracks[category] or {}) do
    if track.id == id then return track end
  end
end

local function validChoice(category, value)
  if value == "original" then return "original" end
  if value == "shuffle" and #(tracks[category] or {}) > 0 then return "shuffle" end
  return trackById(category, value) and value or "original"
end

local function persist(game, category, value)
  selected[category] = validChoice(category, value)
  local save, loader = gameBuckets(game)
  local key = LocalMusic.KEY_PREFIX .. category
  if save then save[key] = selected[category] end
  if loader then loader[key] = selected[category] end
  if selected[category] ~= "original" then
    enabled = true
    if save then save[LocalMusic.ENABLED_KEY] = true end
    if loader then loader[LocalMusic.ENABLED_KEY] = true end
  end
  if game and type(game.writeOptions) == "function" then
    pcall(game.writeOptions, game)
  end
  return selected[category]
end

local function setEnabled(game, value)
  enabled = value == true
  local save, loader = gameBuckets(game)
  if save then save[LocalMusic.ENABLED_KEY] = enabled end
  if loader then loader[LocalMusic.ENABLED_KEY] = enabled end
  if game and type(game.writeOptions) == "function" then
    pcall(game.writeOptions, game)
  end
  return enabled
end

local function backToDefault(game)
  setEnabled(game, false)
  local save, loader = gameBuckets(game)
  for _, category in ipairs(CATEGORIES) do
    selected[category.id] = "original"
    local key = LocalMusic.KEY_PREFIX .. category.id
    if save then save[key] = "original" end
    if loader then loader[key] = "original" end
  end
  lastChoice = {}
  -- The companion-pack selector is VASC's other music replacement lane.
  -- Reset it as well so this action always exposes the final Game/KASC cue.
  local ok, battleMusic = pcall(V.require, "BattleMusic")
  if ok and battleMusic and battleMusic.setting
     and type(battleMusic.setting.setValue) == "function" then
    battleMusic.setting:setValue("original", game)
  end
  activeBattle = nil
  serial = serial + 1
  if game and type(game.writeOptions) == "function" then
    pcall(game.writeOptions, game)
  end
  return true
end

function LocalMusic.restore(game)
  if previewSession and type(LocalMusic.stopPreview) == "function" then
    LocalMusic.stopPreview(previewSession.game)
  end
  -- A newly loaded/created game may resolve the same category to a different
  -- edition or companion cue. Require a fresh hook observation before A/B.
  observedCategories, observedExact, lastResolved = {}, {}, nil
  local save, loader = gameBuckets(game)
  enabled = (save and save[LocalMusic.ENABLED_KEY]
             or loader and loader[LocalMusic.ENABLED_KEY]) == true
  for _, category in ipairs(CATEGORIES) do
    local key = LocalMusic.KEY_PREFIX .. category.id
    local value = save and save[key] or loader and loader[key] or "original"
    selected[category.id] = validChoice(category.id, value)
  end
end

local CHAMPIONS = { OPP_RIVAL3=true, OPP_CHAMPION=true, CHAMPION=true }
local ELITE = {
  OPP_LORELEI=true, OPP_BRUNO=true, OPP_AGATHA=true, OPP_LANCE=true,
}

function LocalMusic.categoryFor(ctx)
  if type(ctx) ~= "table" then return nil end
  if ctx.reason == "map" then
    if ctx.surfing then return "surf" end
    if ctx.onBike then return "bike" end
    return "field"
  end
  if ctx.reason == "bike" then return "bike" end
  if ctx.reason == "victory" then return "victory" end
  if ctx.reason == "evolution" or ctx.reason == "trade"
     or ctx.reason == "hatch" then return "evolution" end
  if ctx.reason == "title" then return "title" end
  if ctx.reason == "halloffame" then return "halloffame" end
  if ctx.reason == "credits" then return "credits" end
  if ctx.reason == "once" then return "jingle" end
  if ctx.reason == "direct" or ctx.reason == "oak_speech"
     or ctx.reason == "trainer_encounter" or ctx.reason == "script_playmusic"
     or ctx.reason == "script_fadeout" or ctx.reason == "magnettrain" then
    return "scene"
  end
  if ctx.reason ~= "battle" then return nil end
  local kind, trainer = ctx.battleKind or ctx.kind, tostring(ctx.trainerId or "")
  if kind == "wild" or kind == "safari" or kind == "ghost" or kind == "oldman" then
    return "wild"
  end
  if CHAMPIONS[trainer] or trainer:find("CHAMPION", 1, true) then return "champion" end
  if ELITE[trainer] or (kind == "final" and trainer == "") then return "elite4" end
  if kind == "gym" then return "gym" end
  if trainer:find("RIVAL", 1, true) or trainer:find("SILVER", 1, true)
     or trainer:find("KRIS", 1, true) or trainer:find("GOLD", 1, true) then
    return "rival"
  end
  if kind == "trainer" or kind == "final" then return "trainer" end
  return nil
end

local function rememberOriginal(current, ctx, category)
  if type(current) ~= "string" or current == "" or registered[current] then
    return
  end
  local exactId = replacements[current] and current or nil
  if category then observedCategories[category] = current end
  if exactId then observedExact[exactId] = true end
  lastResolved = {
    originalId=current, category=category, exactId=exactId,
    reason=type(ctx) == "table" and ctx.reason or nil,
  }
end

local function shuffled(category, ctx)
  local list = tracks[category] or {}
  if #list == 0 then return nil end
  local token = category .. "|" .. tostring(ctx and ctx.mapId or "")
                .. "|" .. tostring(ctx and ctx.trainerId or "")
                .. "|" .. tostring(serial)
  local at = (hash(token) % #list) + 1
  if #list > 1 and list[at].id == lastChoice[category] then at = at % #list + 1 end
  return list[at]
end

function LocalMusic.resolve(current, ctx)
  local category = LocalMusic.categoryFor(ctx)
  rememberOriginal(current, ctx, category)
  if not enabled then return current end
  local exact = type(current) == "string" and replacements[current] or nil
  local fallback = exact and exact.id or current
  if not category then return fallback end
  local choice = validChoice(category, selected[category] or "original")
  if choice == "original" then return fallback end
  if ctx.reason == "battle" and activeBattle then return activeBattle.id end
  local track = choice == "shuffle" and shuffled(category, ctx)
                or trackById(category, choice)
  if not track then return fallback end
  if ctx.reason == "battle" then activeBattle = track end
  lastChoice[category] = track.id
  return track.id
end

function LocalMusic.finish()
  activeBattle = nil
  serial = serial + 1
end

local function copyResolution(value)
  if type(value) ~= "table" then return nil end
  return {
    originalId=value.originalId, category=value.category,
    exactId=value.exactId, reason=value.reason,
  }
end

local function previewReceipt()
  if not previewSession then return nil end
  return {
    kind=previewSession.kind, songId=previewSession.songId,
    label=previewSession.label, originalId=previewSession.originalId,
  }
end

function LocalMusic.status()
  local categories, exact = {}, {}
  for id, song in pairs(observedCategories) do categories[id] = song end
  for id in pairs(observedExact) do exact[id] = true end
  return {
    apiVersion=LocalMusic.API_VERSION, enabled=enabled,
    observed={ categories=categories, exact=exact,
               lastResolved=copyResolution(lastResolved) },
    preview=previewReceipt(),
  }
end

local function originalFor(target)
  if type(target) ~= "table" then
    return nil, "a category or exact target is required"
  end
  if target.category ~= nil then
    local category = tostring(target.category)
    if not BY_ID[category] then return nil, "unknown music category" end
    local song = observedCategories[category]
    if song then return song end
    return nil, "no Game/KASC cue has been observed for this category yet"
  end
  if target.exactId ~= nil then
    local exactId = tostring(target.exactId)
    if not replacements[exactId] then return nil, "unknown exact replacement" end
    if observedExact[exactId] then return exactId end
    return nil, "this exact Game/KASC cue has not been observed yet"
  end
  return nil, "a category or exact target is required"
end

local function anyTrack(id)
  if type(id) ~= "string" then return nil end
  for _, list in pairs(tracks) do
    for _, track in ipairs(list) do
      if track.id == id then return track end
    end
  end
  for _, track in pairs(replacements) do
    if track.id == id then return track end
  end
end

local function songAvailable(game, id)
  local songs = game and game.data and game.data.audio and game.data.audio.songs
  local def = songs and songs[id]
  return type(def) == "table"
     and (def.file ~= nil or def.chip ~= nil
          or (def.address ~= nil and def.bank ~= nil))
end

local function engineMusic()
  local ok, Music = pcall(require, "src.core.Music")
  if not ok or type(Music) ~= "table" or type(Music.play) ~= "function" then
    return nil, "the game music preview service is unavailable"
  end
  return Music
end

local function previewSong(game, id, receipt)
  if not songAvailable(game, id) then
    return nil, "the resolved song is not available in the current game"
  end
  local Music, unavailable = engineMusic()
  if not Music then return nil, unavailable end
  if previewSession and previewSession.game ~= game then
    return nil, "a music preview is already active in another game"
  end
  local created = previewSession == nil
  if created then
    local previous
    if type(Music.current) == "function" then
      local ok, value = pcall(Music.current)
      if ok and type(value) == "string" then previous = value end
    end
    previewSession = { game=game, previousId=previous }
  end
  local ok, err = pcall(Music.play, game.data, id, true, {
    reason="direct", selected=true,
  })
  if not ok then
    if created then previewSession = nil end
    return nil, tostring(err)
  end
  previewSession.kind = receipt.kind
  previewSession.songId = id
  previewSession.label = receipt.label
  previewSession.originalId = receipt.originalId
  return true
end

function LocalMusic.previewOriginal(game, target)
  local id, unavailable = originalFor(target)
  if not id then return nil, unavailable end
  return previewSong(game, id, {
    kind="original", label=id, originalId=id,
  })
end

function LocalMusic.previewTrack(game, trackId)
  local track = anyTrack(trackId)
  if not track then return nil, "unknown local music track" end
  return previewSong(game, track.id, {
    kind="custom", label=track.label, originalId=track.originalId,
  })
end

function LocalMusic.stopPreview(game)
  local session = previewSession
  previewSession = nil
  if not session then return false end
  local Music = engineMusic()
  if not Music then return false end
  -- Always restore through the game whose music state was snapshotted.  A
  -- stale caller must not replay that receipt into a different game object.
  local activeGame = session.game or game
  local data = activeGame and activeGame.data
  if type(Music.stop) == "function" then pcall(Music.stop) end
  if session.previousId and songAvailable(activeGame, session.previousId) then
    local ok = pcall(Music.play, data, session.previousId, true, {
      reason="direct", selected=true,
    })
    if ok then return true end
  end
  if data and type(Music.restoreMap) == "function" then
    pcall(Music.restoreMap, data)
  end
  return true
end

local function choiceLabel(category)
  local choice = validChoice(category, selected[category] or "original")
  if choice == "original" then return "ORIGINAL" end
  if choice == "shuffle" then return "SHUFFLE" end
  local track = trackById(category, choice)
  return track and string.upper(track.label:sub(1, 14)) or "ORIGINAL"
end

function LocalMusic.row(mod)
  return {
    id = ((V.mod and V.mod.id) or "VOXEL_ASCENDANT") .. ":localMusic",
    label = "USER MUSIC",
    value = function()
      local n = 0
      for _, list in pairs(tracks) do n = n + #list end
      if not enabled then return "GAME/KASC" end
      return n == 0 and "ON / EMPTY" or ("ON / " .. tostring(n))
    end,
    activate = function(game) mod.ui.push(game, "VascUserMusic") end,
  }
end

local function vascList(mod, game, title, items, opts)
  local menu = mod.ui.ListMenu.new(game, title, items, opts)
  local ok, hub = pcall(V.require, "VascMenu")
  if ok and hub and type(hub.decorateActive) == "function" then
    return hub.decorateActive(mod, menu)
  end
  return menu
end

local function installScreens(mod)
  local screens = mod and mod.content and mod.content.screens
  if not screens or type(screens.register) ~= "function" then return false end
  screens:register("VascUserMusic", {
    new = function(game)
      local items = {
        { label="CONTENT PROFILE", right=enabled and "CUSTOM" or "INACTIVE" },
        { label="RESCAN FOLDERS", rescan=true },
      }
      for _, group in ipairs(GROUPS) do
        items[#items + 1] = { label=group.label, group=group.id }
      end
      local exactCount = 0
      for _ in pairs(replacements) do exactCount = exactCount + 1 end
      items[#items + 1] = { label="EXACT SONG REPLACEMENTS",
                            right=tostring(exactCount), exact=true }
      items[#items + 1] = { label="FOLDER GUIDE", guide=true }
      return vascList(mod, game, "VASC MUSIC", items, {
        wrap=true,
        onChoose=function(item, menu)
          if item.rescan then
            scan(mod)
          elseif item.guide then
            mod.ui.push(game, "VascUserMusicHelp")
          elseif item.exact then
            mod.ui.push(game, "VascUserMusicExact")
          else
            mod.ui.push(game, "VascUserMusicGroup", { group=item.group })
          end
        end,
      })
    end,
  })
  screens:register("VascUserMusicGroup", {
    new = function(game, opts)
      local group = GROUP_BY_ID[opts and opts.group] or GROUPS[1]
      local items = {}
      for _, categoryId in ipairs(group.categories) do
        local category = BY_ID[categoryId]
        items[#items + 1] = { label=category.label,
                              right=choiceLabel(categoryId),
                              category=categoryId }
      end
      return vascList(mod, game, group.label, items, {
        wrap=true,
        onChoose=function(item)
          mod.ui.push(game, "VascUserMusicCategory",
                      { category=item.category })
        end,
      })
    end,
  })
  screens:register("VascUserMusicCategory", {
    new = function(game, opts)
      local category = opts and opts.category
      local def = BY_ID[category] or CATEGORIES[1]
      local items = {
        { label="ORIGINAL", value="original" },
      }
      if #(tracks[def.id] or {}) > 0 then
        items[#items + 1] = { label="SHUFFLE", value="shuffle" }
      end
      items[#items + 1] = { label="MUSIC A/B PREVIEW", preview=true }
      for _, track in ipairs(tracks[def.id] or {}) do
        items[#items + 1] = { label=string.upper(track.label:sub(1, 18)), value=track.id }
      end
      return vascList(mod, game, def.label, items, {
        wrap=true,
        onChoose=function(item, menu)
          if item.preview then
            mod.ui.push(game, "VascUserMusicPreview", { category=def.id })
          else
            persist(game, def.id, item.value)
            menu:close()
          end
        end,
      })
    end,
  })
  screens:register("VascUserMusicHelp", {
    new = function(game)
      local items = {
        { label="ADD AUDIO TO:" },
        { label="SAVE DIR/MODS/" },
        { label="VOXEL_ASCENDANT/USER/" },
        { label="MUSIC/<TYPE>" },
        { label="/REPLACE/<SONG_ID>" },
        { label="THEN CHOOSE RESCAN" },
        { label="WIN: %APPDATA%/LOVE" },
        { label="MAC: LIBRARY/APP SUPPORT" },
        { label="LINUX: .LOCAL/SHARE/LOVE" },
        { label="IOS: FILES/GEN1RECOMP++" },
        { label="ANDROID: ANDROID/DATA" },
        { label="README_EN + README_DE" },
        { label="BACK = GAME/KASC" },
      }
      return vascList(mod, game, "USER MUSIC HELP", items, {
        onChoose=function(_, menu) menu:close() end,
      })
    end,
  })
  screens:register("VascUserMusicExact", {
    new = function(game)
      local items = {}
      for originalId, track in pairs(replacements) do
        items[#items + 1] = {
          label=string.upper(originalId:sub(1, 18)), right=track.filename,
          exactId=originalId,
        }
      end
      table.sort(items, function(a, b) return a.label < b.label end)
      if #items == 0 then items[1] = { label="NO EXACT REPLACEMENTS" } end
      return vascList(mod, game, "EXACT SONG IDS", items, {
        onChoose=function(item, menu)
          if item.exactId then
            mod.ui.push(game, "VascUserMusicPreview", { exactId=item.exactId })
          else
            menu:close()
          end
        end,
      })
    end,
  })
  screens:register("VascUserMusicPreview", {
    new = function(game, opts)
      local target = opts and opts.exactId
        and { exactId=opts.exactId } or { category=opts and opts.category }
      local originalId = originalFor(target)
      local items = {}
      if originalId then
        items[#items + 1] = {
          label="PLAY LAST ORIGINAL", right=originalId:sub(1, 18),
          original=true,
        }
      else
        items[#items + 1] = {
          label="ORIGINAL UNSEEN", right="UNAVAILABLE", unavailable=true,
        }
      end
      if target.exactId then
        local track = replacements[target.exactId]
        if track then
          items[#items + 1] = {
            label="PREVIEW CUSTOM", right=track.label:sub(1, 18), track=track.id,
          }
        end
      else
        for _, track in ipairs(tracks[target.category] or {}) do
          items[#items + 1] = {
            label="CUSTOM " .. string.upper(track.label:sub(1, 11)),
            right="PREVIEW", track=track.id,
          }
        end
      end
      items[#items + 1] = { label="STOP + RESTORE", stop=true }
      return vascList(mod, game, "MUSIC A/B PREVIEW", items, {
        wrap=true,
        onChoose=function(item)
          if item.original then
            LocalMusic.previewOriginal(game, target)
          elseif item.track then
            LocalMusic.previewTrack(game, item.track)
          elseif item.stop then
            LocalMusic.stopPreview(game)
          end
        end,
        onCancel=function() LocalMusic.stopPreview(game) end,
      })
    end,
  })
  return true
end

local function profileResolve(song, ctx)
  local ok, content = pcall(V.require, "LocalContent")
  if ok and type(content) == "table"
     and type(content.resolveMusic) == "function" then
    return content.resolveMusic(song, ctx)
  end
  return LocalMusic.resolve(song, ctx)
end

local function installOneShotRelay()
  local ok, Music = pcall(require, "src.core.Music")
  if not ok or type(Music) ~= "table" or type(Music.playOnce) ~= "function" then
    return false
  end
  local current = Music.playOnce
  local held = rawget(Music, "voxelAscendantLocalOneShotRelay")
  if held then
    if current ~= held.wrapper then return false end
    held.resolve = function(song) return profileResolve(song, {reason="once"}) end
    return true
  end
  held = {}
  held.resolve = function(song) return profileResolve(song, {reason="once"}) end
  -- Music.playOnce verifies that the playing ID equals its argument before it
  -- arms map-theme restoration. Resolve the local alias before entering that
  -- function so a replaced healing/jingle cue still restores correctly.
  held.wrapper = function(data, song)
    local okResolve, resolved = pcall(held.resolve, song)
    return current(data, okResolve and resolved or song)
  end
  Music.playOnce = held.wrapper
  Music.voxelAscendantLocalOneShotRelay = held
  return true
end

function LocalMusic.install(mod)
  scan(mod)
  installScreens(mod)
  installOneShotRelay()
  if not (mod and mod.hooks and type(mod.hooks.wrap) == "function") then
    return false
  end
  mod.hooks:wrap("music.select", function(nextSong, current, ctx)
    return profileResolve(nextSong(current, ctx), ctx)
  end, 2000000)
  return true
end

function LocalMusic.list(category)
  local out = {}
  if category == "replace" then
    for _, track in pairs(replacements) do
      out[#out + 1] = { id=track.id, label=track.label,
                        filename=track.filename, category=track.category,
                        originalId=track.originalId }
    end
    table.sort(out, function(a, b) return a.originalId < b.originalId end)
    return out
  end
  for _, track in ipairs(tracks[category] or {}) do
    out[#out + 1] = { id=track.id, label=track.label,
                      filename=track.filename, category=track.category }
  end
  return out
end

LocalMusic.categories = CATEGORIES
LocalMusic.persist = persist
LocalMusic.scan = scan
LocalMusic.setEnabled = setEnabled
LocalMusic.enabled = function() return enabled end
LocalMusic.backToDefault = backToDefault

return LocalMusic
