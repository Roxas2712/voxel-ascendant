local stored = { water = "full" }
local cache = {}

local V = {
  mod = {
    id = "VOXEL_ASCENDANT",
    options = { get = function(_, key) return stored[key] end },
  },
}

local Sky = {
  DITHER = true,
  DITHER_START = 0.6,
  RAY_DITHER = false,
  GLOW_REACH = 1,
  GRADIENT_BANDS = 96,
}
local rampReady = true
function Sky.ramp()
  if not rampReady then return nil end
  return { kind = "shared-ramp" }, Sky.GRADIENT_BANDS, {}
end
function Sky.ditherStart(ray)
  return Sky.DITHER and (not ray or Sky.RAY_DITHER)
         and Sky.DITHER_START or 2
end

function V.require(name)
  if cache[name] then return cache[name] end
  if name == "ModSetting" then
    cache[name] = assert(loadfile("lib/ModSetting.lua"))(V)
  elseif name == "Sky" then
    cache[name] = Sky
  elseif name == "DayNight" then
    cache[name] = { body = function() return nil end }
  elseif name == "ShadowMap" or name == "Mat4" then
    cache[name] = {}
  else
    cache[name] = {}
  end
  return cache[name]
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected "
          .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local Water = assert(loadfile("lib/Water.lua"))(V)
local sent = {}
local shader = {}
function shader:send(name, ...)
  sent[name] = { ... }
end

local function send(ray)
  sent = {}
  Water.sendSky(shader, {
    reflect = { kind = "frame-copy" },
    skyEdge = 72,
    skyRay = ray,
    screen = { 320, 180 },
    cell = 2,
    fov = 1,
  })
  return sent.skyStart and sent.skyStart[1]
end

eq(send(nil), Sky.DITHER_START,
   "level/orbit water keeps the visible sky's compact dither")
eq(sent.skyCount[1], Sky.GRADIENT_BANDS,
   "water does not receive the visible sky's exact 96-step ramp")
local ray = { base = {}, du = {}, dv = {} }
eq(send(ray), 2,
   "1ST/3RD water disables the same angular checker ribbons as the sky")
Sky.RAY_DITHER = true
eq(send(ray), Sky.DITHER_START,
   "water follows an explicit future ray-dither policy through Sky's API")

rampReady = false
eq(send(ray), 2, "sky-off water keeps its sampler-safe no-dither fallback")
eq(sent.skyOn[1], 0, "sky-off water reflection remains disabled")

print("water sky dither contract: ok")
