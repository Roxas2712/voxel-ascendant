-- STADIUM battles: finding the ROM, and building the models out of it once.
--
-- The mod does not ship the Pokemon Stadium models and cannot: they are that
-- game's data. What it ships is the READER -- StadiumRom, StadiumFragment,
-- StadiumFx and StadiumBuild -- and the player supplies the cartridge, which
-- is exactly the arrangement this engine already has for the Game Boy ROM it
-- is a recompilation of (src/import/RomImporter.lua).
--
-- So: supply a Pokemon Stadium (US) 1.0 ROM -- the OPTIONS row opens a file
-- picker for one, or drop it in `baseroms/` -- and the first time the
-- game runs with the mod on, the models are built. Once, on a loading screen,
-- in about ten seconds. After that the packs sit in the save directory and
-- the mod reads them like any other asset.
--
-- ------- where "baseroms/" is
--
-- One relative path, and it deliberately covers two different places at once,
-- because PhysFS searches the save directory AND the game folder under the
-- same names:
--
--   * a folder install, or a checkout -- `baseroms/` next to main.lua
--   * a packaged or fused build, where the game folder is inside an archive
--     and cannot be written to -- `baseroms/` in the save directory, whose
--     absolute path this reports on screen so it can be found
--
-- The file goes STRAIGHT IN THERE, with no revision subfolder under it. The
-- decompilation's own `make init` uses `baseroms/us/`, and the offline
-- pipeline under model_extract/ still reads from there because it shares that
-- tree -- but the instruction given to a player is "drop the file in this
-- folder", and one folder is the whole of it.
--
-- Any of `.z64`, `.n64` and `.v64` is accepted; StadiumRom normalises the
-- byte order on load.
--
-- ------- what "installed" means
--
-- A marker file next to the packs, holding the format magic, how many species
-- were written and the md5 of the ROM they came from. All three matter. The
-- magic catches a format change (the packs are rebuilt rather than read as
-- garbage), the count catches a build that was interrupted half way, and the
-- md5 catches the player swapping the ROM for a different revision.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local StadiumPack = V.require("StadiumPack")

local StadiumInstall = {}
local Compat = V.require("EngineCompat")

-- Where a ROM is looked for, and where the built packs are kept.
StadiumInstall.ROM_DIR = "baseroms"
StadiumInstall.DIR = StadiumPack.CACHE_DIR
StadiumInstall.MARKER = StadiumInstall.DIR .. "/pack.info"

-- Bumped whenever the .dsm format changes, so an old cache is rebuilt rather
-- than misread. Must track StadiumPack's magic.
StadiumInstall.FORMAT = "DSM7"

-- Bumped when the packs' CONTENT changes without the byte layout moving.
-- DSM7 keeps the DSM5/6 structural/material data and changes the extracted
-- CONTENT again so SetTileSize origin/window semantics are baked into UVs and
-- per-material texture variants.  FORMAT (not REV) changes because an older
-- pack cannot supply those discarded tile fields.
StadiumInstall.REV = 1

local function gameGeneration()
  -- The dispatcher already resolved the active cartridge before either
  -- generation runtime was entered.  Prefer that closed owner value over a
  -- second GameVersion probe: hot reloads and compatibility hosts can retain
  -- the other generation's module singleton, which made a Gen-1 import write
  -- a Gen-2-sized cache (or vice versa) and left the model provider looking in
  -- a cache which could never become ready.
  local host = V.mod and tonumber(V.mod._vascHostGeneration)
  if host == 1 or host == 2 then return host end
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if ok and type(GameVersion) == "table" then
    if type(GameVersion.generation) == "function" then
      local okGen, gen = pcall(GameVersion.generation)
      if okGen and tonumber(gen) then return tonumber(gen) end
    end
    if type(GameVersion.isGen2) == "function" then
      local okGen2, yes = pcall(GameVersion.isGen2)
      if okGen2 and yes then return 2 end
    end
  end
  return 1
end

local function stadium2ForGen1()
  return gameGeneration() == 1 and V.stadium2ForGen1 == true
end

local function usesStadium2()
  return gameGeneration() == 2 or stadium2ForGen1()
end

local function kascActive()
  if not stadium2ForGen1() then return false end
  local ok, compat = pcall(V.require, "KantoAscendantCompat")
  if not (ok and type(compat) == "table"
      and type(compat.active) == "function") then return false end
  local called, active = pcall(compat.active, V.mod)
  return called and active == true
end

local function targetCount()
  if gameGeneration() == 2 then return 251 end
  if stadium2ForGen1() and kascActive() then return 251 end
  return 151
end

StadiumInstall.gameGeneration = gameGeneration
StadiumInstall.usesStadium2 = usesStadium2
StadiumInstall.kascActive = kascActive
StadiumInstall.targetCount = targetCount
StadiumInstall.COUNT = targetCount()

-- Named ROM files, then any ROM at all sitting in the folder.
--
-- Flat in `baseroms/`, with no revision subfolder: the offline pipeline under
-- model_extract/ keeps the decompilation's own `baseroms/us/` convention
-- because it shares that tree, but what is being asked of a PLAYER here is
-- "drop the file in this folder", and one folder is the whole of that
-- instruction. A path they have to build out of two parts is a path half of
-- them will get wrong, and the failure is silent -- the rungs are simply not
-- on the row.
local function namedRoms()
  local stem = usesStadium2() and "stadium2" or "stadium"
  return {
    StadiumInstall.ROM_DIR .. "/" .. stem .. ".z64",
    StadiumInstall.ROM_DIR .. "/" .. stem .. ".n64",
    StadiumInstall.ROM_DIR .. "/" .. stem .. ".v64",
    StadiumInstall.ROM_DIR .. "/baserom.z64",
    StadiumInstall.ROM_DIR .. "/baserom.n64",
    StadiumInstall.ROM_DIR .. "/baserom.v64",
  }
end

local function fs()
  return Compat.fs()
end

local function isFile(path)
  local f = fs()
  if not (f and f.getInfo) then return false end
  local ok, info = pcall(f.getInfo, path, "file")
  return (ok and info) and true or false
end

-- The ROM's path on the PhysFS read path, or nil.
function StadiumInstall.romPath()
  local f = fs()
  if not f then return nil end
  for _, path in ipairs(namedRoms()) do
    if isFile(path) then return path end
  end
  local ok, items = pcall(f.getDirectoryItems, StadiumInstall.ROM_DIR)
  if ok and items then
    table.sort(items)
    for _, name in ipairs(items) do
      if name:lower():match("%.[nvz]64$") then
        local path = StadiumInstall.ROM_DIR .. "/" .. name
        if isFile(path) then return path end
      end
    end
  end
  return nil
end

function StadiumInstall.romPresent()
  return StadiumInstall.romPath() ~= nil
end

-- Where to tell the player to put it. The save directory is the answer that
-- is always writable, and it is the one a packaged build needs.
function StadiumInstall.romHint()
  local f = fs()
  local base = (f and f.getSaveDirectory and select(2, pcall(f.getSaveDirectory)))
  if type(base) ~= "string" then base = "the game folder" end
  return base .. "/" .. StadiumInstall.ROM_DIR
end

-- The same thing with a FILENAME on the end, which is what a player actually
-- needs: a folder alone leaves them guessing what to call the file, and the
-- guess is not obviously "baserom.z64".
--
-- Taken from the head of NAMED rather than retyped, so the name shown is by
-- construction the first name looked for. It is not the ONLY one that works
-- -- `.n64` and `.v64` are accepted, and so is any other name carrying one
-- of those extensions -- but an instruction that names one file is one a
-- player can follow, and an instruction that lists every possibility is one
-- they have to interpret.
function StadiumInstall.romHintFile()
  local paths = namedRoms()
  return StadiumInstall.romHint() .. "/" .. (paths[1]:match("[^/]+$") or "")
end

-- ------- the marker

local function readMarker()
  local f = fs()
  if not (f and isFile(StadiumInstall.MARKER)) then return nil end
  local ok, text = pcall(f.read, StadiumInstall.MARKER)
  if not (ok and type(text) == "string") then return nil end
  local format, count, md5, rev = text:match("^(%S+)%s+(%d+)%s*(%S*)%s*(%S*)")
  if not format then return nil end
  return { format = format, count = tonumber(count), md5 = md5,
           rev = tonumber(rev) }
end

-- Whether a complete, current set of packs is on disk.
local readyCache = nil
local readyCount = nil

function StadiumInstall.ready()
  local wanted = targetCount()
  if readyCache ~= nil and readyCount == wanted then return readyCache end
  local m = readMarker()
  -- v0.2.79 / DSM7 adds the missing SetTileSize origin/clamp-window semantics
  -- and rebuilds texture variants to the RDP's effective sampling window.
  -- DSM6 has the SetTile flags but not enough information to recover SL/TL or
  -- SH/TH after extraction, so it must rebuild once from the Stadium 2 ROM.
  local formatOk = m and m.format == StadiumInstall.FORMAT
    and m.rev == StadiumInstall.REV
  readyCount = wanted
  readyCache = (formatOk and m.count >= wanted) and true or false
  return readyCache
end

-- Whether a complete set came WITH the mod folder -- a developer checkout
-- that has run tools/stadium_pack.py. Never true of a released build, which
-- carries no models at all.
--
-- Sampled at both ends of the dex rather than counted. The question being
-- asked is "did somebody run the packer here", not "is every one of the 151
-- present"; a genuinely half-written folder is a case for the marker file,
-- which is what catches an interrupted RUNTIME build.
local function shipped()
  local mod = V.mod
  if not (mod and mod.read) then return false end
  for _, dex in ipairs({ 1, targetCount() }) do
    local ok, bytes = pcall(mod.read, mod,
                            ("%s/%03d.dsm"):format(StadiumPack.DIR, dex))
    if not (ok and type(bytes) == "string" and #bytes > 4) then return false end
  end
  return true
end

-- Whether the STADIUM rungs can be offered at all: either the packs have been
-- built from the player's ROM, or the mod folder already carries a set.
function StadiumInstall.available()
  if StadiumInstall.ready() then return true end
  return shipped()
end

-- Whether there is work to do: something to build from, and nothing usable
-- yet.
--
-- A checkout that already carries a set is NOT pending. Building anyway would
-- be correct and would also mean a ten-second loading screen on the first run
-- of every checkout, to arrive at the files that were already sitting there.
function StadiumInstall.pending()
  if StadiumInstall.available() then return false end
  return StadiumInstall.romPresent()
end

function StadiumInstall.forget()
  readyCache = nil
  readyCount = nil
end

-- ------- building

local job = nil
local status = { state = "idle", done = 0, total = targetCount() }

StadiumInstall.status = status

local function writePack(species, bytes)
  local f = fs()
  if not f then return false, "no filesystem" end
  local ok, err = f.write(("%s/%03d.dsm"):format(StadiumInstall.DIR, species),
                          bytes)
  if not ok then return false, tostring(err) end

  -- v0.2.22 diagnostic convenience: keep a clearly named COPY of Lugia's
  -- generated DSM beside the raw geo-layout dump.  The normal 249.dsm remains
  -- in its usual place and is byte-for-byte identical; this copy exists only
  -- so the player can zip/upload two obvious files without hunting through the
  -- whole cache directory.
  if tonumber(species) == 249 then
    local dbg = StadiumInstall.DIR .. "/lugia_debug"
    pcall(f.createDirectory, dbg)
    pcall(f.write, dbg .. "/249.dsm", bytes)
    local saveDir = "<save directory>"
    if type(f.getSaveDirectory) == "function" then
      local okSave, got = pcall(f.getSaveDirectory)
      if okSave and got then saveDir = tostring(got) end
    end
    local note = table.concat({
      "VASC4J - Lugia diagnostic files",
      "",
      "Upload BOTH of these files back to ChatGPT:",
      "  1) 249_geo_dump.txt",
      "  2) 249.dsm",
      "",
      "They are generated from your local Stadium 2 import. The text dump",
      "contains offsets/numeric transform information only, not ROM model bytes.",
      "",
      "Save directory:",
      saveDir,
      "",
      "Relative folder:",
      dbg,
      "",
    }, "\n")
    pcall(f.write, dbg .. "/UPLOAD_THESE_TWO_FILES.txt", note)
  end
  return true
end

-- Open the ROM found in `baseroms/` and start a stepped build. Returns false
-- plus a reason when there is nothing to build from.
function StadiumInstall.begin()
  local f = fs()
  if not f then return false, "no filesystem" end
  local path = StadiumInstall.romPath()
  if not path then return false, "no ROM in " .. StadiumInstall.ROM_DIR end

  local okRead, bytes = pcall(f.read, path)
  if not (okRead and type(bytes) == "string") then
    return false, "could not read " .. path
  end
  return StadiumInstall.beginFrom(bytes, path)
end

-- The same, from bytes somebody else has already got hold of -- which is the
-- IMPORTED path (StadiumRomPick), where the file is at an absolute location
-- love.filesystem cannot see and was read with io.open.
--
-- The two entry points share everything from here down on purpose: an
-- imported cartridge and a dropped one produce the same 151 files, the same
-- marker and the same md5, so there is exactly one build in this mod and no
-- second one to keep in step.
--
-- `label` is only ever used to say WHICH file a complaint is about.
function StadiumInstall.beginFrom(bytes, label)
  local f = fs()
  if not f then return false, "no filesystem" end
  if type(bytes) ~= "string" or #bytes == 0 then return false, "empty file" end

  local StadiumBuild = V.require("StadiumBuild")
  local wanted = targetCount()
  StadiumInstall.COUNT = wanted
  status.total = wanted
  status.wrongVersion = false
  status.sourceGame = usesStadium2()
    and "Pokemon Stadium 2" or "Pokemon Stadium"

  local RomReader
  if usesStadium2() then
    RomReader = V.require("StadiumRom2")
  else
    RomReader = V.require("StadiumRom")
  end

  local rom, err = RomReader.open(bytes)
  if not rom then
    if usesStadium2() then
      return false, "This model source needs a Pokemon Stadium 2 ROM: "
        .. tostring(err)
    end
    return false, tostring(err)
  end

  if not rom:isExpectedUS() then
    status.wrongVersion = true
    if usesStadium2() then
      V.mod.log:warn("stadium2: %s is md5 %s -- canonical Pokemon Stadium 2 US "
                     .. "is md5 %s. The archive layout will still be validated "
                     .. "before a build is started.",
                     tostring(label or "the ROM"), tostring(rom:md5()),
                     tostring(RomReader.US_MD5))
    else
      V.mod.log:warn("stadium: %s is md5 %s -- the model offsets are keyed to "
                     .. "Pokemon Stadium (US) 1.0, which is md5 %s. Building "
                     .. "anyway, but the models may be wrong or fail to build.",
                     tostring(label or "the ROM"), tostring(rom:md5()),
                     tostring(RomReader.US_MD5))
    end
  end

  local models = rom:modelCount()
  if not (models and models >= wanted) then
    if usesStadium2() then
      return false, "needs Pokemon Stadium 2 with the full 251-Pokemon model archive"
    end
    return false, "needs Pokemon Stadium US 1.0"
  end

  pcall(f.createDirectory, StadiumInstall.DIR)
  job = StadiumBuild.job(rom, writePack, wanted)
  job.md5 = rom:md5()
  job.sourceGame = status.sourceGame
  status.state = "building"
  status.done = 0
  status.total = job.total
  status.error = nil
  return true
end

-- One species. Returns true while there is more to do.
function StadiumInstall.step()
  if not job then return false end
  local more = job:step()
  status.done = job.done
  status.species = job.species
  if job.error then
    status.state = "failed"
    status.error = job.error
    job = nil
    return false
  end
  if not more then
    local f = fs()
    -- `job.total > 0` as well as "nothing failed", because a job with nothing
    -- IN it satisfies the second on its own -- and the marker this writes is
    -- what makes a set count as installed, so it must never be written for a
    -- build that did not happen. beginFrom refuses such a ROM outright; this
    -- is the same rule stated where the consequence is.
    local wrote = #job.failed == 0 and job.total > 0
    if wrote and f then
      pcall(f.write, StadiumInstall.MARKER,
            ("%s %d %s %d\n"):format(StadiumInstall.FORMAT, job.total,
                                     tostring(job.md5 or ""),
                                     StadiumInstall.REV))
      readyCache = nil
      StadiumPack.forget()
    end
    if not wrote then
      status.state = "failed"
      -- EVERY species failing is not a bad build, it is the wrong file: the
      -- offsets the reader walks are Pokemon Stadium's, so a different game
      -- -- or the Game Boy cartridge the player already imported once, which
      -- is the mistake a file picker invites -- misses on all 151 rather than
      -- on a few. Worth telling apart, because "0 of 151 models were built"
      -- reads as a broken mod and this reads as a wrong click.
      if #job.failed >= job.total then
        if usesStadium2() then
          status.error = "needs a compatible Pokemon Stadium 2 ROM / GS model+animation archives"
        else
          status.error = "needs Pokemon Stadium US 1.0"
        end
      else
        status.error = ("%d of %d models could not be built")
                       :format(#job.failed, job.total)
      end
    else
      status.state = "done"
    end
    job = nil
    return false
  end
  return true
end

function StadiumInstall.cancel()
  job = nil
  status.state = "idle"
end

return StadiumInstall
