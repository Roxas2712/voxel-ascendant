-- Pokemon Stadium 2 / Pokemon Stadium GS ROM reader.
--
-- Unlike Stadium 1, Stadium 2 keeps battle model FRAGMENTs and their skeletal
-- animation banks in two parallel resource archives.  The public reverse-
-- engineering layout used here is:
--
--   0x027ED000  battle Pokemon model archive (282 entries)
--   0x02D7D000  battle animation-bank archive (282 entries)
--
-- Archive entry N is paired with animation entry N.  Entry 0 is a non-roster
-- slot; National Dex species 1..251 live at archive entries 1..251.  The mod
-- never ships any bytes from either game -- the player selects their own ROM
-- and this reader builds local DSM packs in the save directory.

local V = ...

local StadiumRom = V.require("StadiumRom")
local StadiumFragment = V.require("StadiumFragment")

local StadiumRom2 = {}

StadiumRom2.MODEL_ARCHIVE = 0x027ED000
StadiumRom2.ANIM_ARCHIVE  = 0x02D7D000
StadiumRom2.RESOURCE_TABLE = 0x00437620
StadiumRom2.ARCHIVE_COUNT = 282
StadiumRom2.N_POKEMON = 251

-- Canonical US image published by pret/pokestadiumgs.
StadiumRom2.US_MD5 = "1561c75d11cedf356a8ddb1a4a5f9d5d"
StadiumRom2.JP_MD5 = "a17aadcc962393d476edc321e59c504b"

local byte = string.byte
local sub = string.sub

local Rom = {}
Rom.__index = Rom

local function be32(s, o)
  local a, b, c, d = byte(s, o + 1, o + 4)
  if not d then return nil end
  return ((a * 256 + b) * 256 + c) * 256 + d
end

local function archiveInString(data, off)
  off = off or 0
  if type(data) ~= "string" or off < 0 or off + 0x10 > #data then return nil end
  local count = be32(data, off + 0x0C)
  if not count or count <= 0 or count >= 4096 then return nil end
  if off + 0x10 + count * 0x10 > #data then return nil end

  local out = {}
  for i = 0, count - 1 do
    local rec = off + 0x10 + i * 0x10
    local rel = be32(data, rec)
    local size = be32(data, rec + 4)
    if not rel or not size or rel < 0 or size < 0 then return nil end
    local start = off + rel
    if start < off or start + size > #data then return nil end
    out[i + 1] = { start = start, size = size, index = i }
  end
  return out
end

function StadiumRom2.open(bytes)
  local data = StadiumRom.normalise(bytes)
  if not data then return nil, "not an N64 ROM (bad magic)" end
  local self = setmetatable({ data = data }, Rom)

  local models = self:archive(StadiumRom2.MODEL_ARCHIVE)
  local anims = self:archive(StadiumRom2.ANIM_ARCHIVE)
  if not models or #models ~= StadiumRom2.ARCHIVE_COUNT
      or not anims or #anims ~= StadiumRom2.ARCHIVE_COUNT then
    return nil, "not a compatible Pokemon Stadium 2 ROM (expected 282-entry model and animation archives)"
  end
  return self
end

function Rom:u8(o)
  return byte(self.data, o + 1)
end

function Rom:u32(o)
  return be32(self.data, o) or 0
end

function Rom:archive(off)
  return archiveInString(self.data, off)
end

function Rom:title()
  local raw = sub(self.data, 0x20 + 1, 0x20 + 20)
  return (raw:gsub("%z", ""):gsub("%s+$", ""))
end

function Rom:md5()
  if self.hash ~= nil then return self.hash or nil end
  local ok, hex = pcall(function()
    local digest = love.data.hash("md5", self.data)
    if type(digest) == "userdata" and digest.getString then
      digest = digest:getString()
    end
    return love.data.encode("string", "hex", digest)
  end)
  self.hash = (ok and hex) or false
  return self.hash or nil
end

function Rom:isExpectedUS()
  local hex = self:md5()
  return hex == nil or hex == StadiumRom2.US_MD5
end

function Rom:isKnownRevision()
  local hex = self:md5()
  return hex == nil or hex == StadiumRom2.US_MD5 or hex == StadiumRom2.JP_MD5
end

function Rom:models()
  if not self.modelDir then
    self.modelDir = self:archive(StadiumRom2.MODEL_ARCHIVE) or {}
  end
  return self.modelDir
end

function Rom:animationBanks()
  if not self.animDir then
    self.animDir = self:archive(StadiumRom2.ANIM_ARCHIVE) or {}
  end
  return self.animDir
end

-- There are 282 archive records, but only National Dex 1..251 are installed.
-- Stadium 2 indexes those Pokemon by their actual species number, so build
-- fileno 0 (Bulbasaur) maps to archive record 1, not record 0.
function Rom:modelCount()
  local n = #self:models() - 1
  return n > 0 and n or 0
end

local function rosterRecord(dir, fileno)
  if type(fileno) ~= "number" or fileno < 0 then return nil end
  local archiveIndex = fileno + 1 -- fileno 0 => archive index 1
  return dir[archiveIndex + 1]    -- Lua array is 1-based
end

function Rom:model(fileno)
  local rec = rosterRecord(self:models(), fileno)
  if not rec then return nil end
  local blob = sub(self.data, rec.start + 1, rec.start + rec.size)
  -- Current US GS model entries are direct FRAGMENT resources, but accepting
  -- Stadium's PERS-SZP/Yay0 wrapper here costs nothing and makes the reader
  -- tolerant of resource variants that use it.
  return StadiumRom.decompress(blob)
end

local function bankPayloads(romData, rec)
  if not rec then return nil, "animation bank is missing" end
  local raw = sub(romData, rec.start + 1, rec.start + rec.size)
  raw = StadiumRom.decompress(raw)
  local dir = archiveInString(raw, 0)
  if not dir then return nil, "animation bank has an invalid archive header" end
  local out = {}
  for i = 1, #dir do
    local r = dir[i]
    out[i] = sub(raw, r.start + 1, r.start + r.size)
  end
  return out
end

function Rom:animationPayloads(fileno)
  local rec = rosterRecord(self:animationBanks(), fileno)
  return bankPayloads(self.data, rec)
end

-- StadiumBuild calls this after the model FRAGMENT has been decoded.  The GS
-- model supplies Bone.Channel, while the paired external bank supplies the
-- actual skeletal clips.  StadiumFragment owns the sampling math so Stadium 1
-- and Stadium 2 keep one implementation of the packed/hermite track formats.
function Rom:attachAnimations(data, fileno)
  local expectedSpecies = fileno + 1
  if tonumber(data and data.species) ~= expectedSpecies then
    return false, ("Stadium 2 archive mapping mismatch: entry %d decoded as species %s (expected %d)")
      :format(expectedSpecies, tostring(data and data.species), expectedSpecies)
  end
  local payloads, err = self:animationPayloads(fileno)
  if not payloads then return false, err end
  local anims, aerr = StadiumFragment.decodeGSAnimations(payloads, data.bones)
  if not anims or #anims == 0 then
    return false, aerr or "no Stadium 2 skeletal animations decoded"
  end
  data.anims = anims
  self._animCounts = self._animCounts or {}
  self._animCounts[data.species] = #anims
  return true
end

-- Stadium 2's battle move/context routing table has not yet been mapped into
-- this extractor.  For overworld use we need a stable valid standby clip, so
-- all 185 Stadium-format routing slots conservatively select animation 0.
-- This keeps Gold/Silver overworld models animated without inventing semantic
-- attack/faint labels.  A later verified GS routing-table map can replace this
-- function without changing the DSM format or importer UI.
function Rom:battleRows(_species)
  local rows = {}
  for e = 0, 184 do rows[e] = { 0, -1 } end
  rows.n = 185
  return rows
end

return StadiumRom2
