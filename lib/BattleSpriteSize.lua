-- Presentation units, deliberately not a metre-for-pixel simulation.
-- The same fixed reference is used by geometry, camera fit and HUD safety.
local Size = {}
local references = setmetatable({}, { __mode = 'k' })
local function positive(value)
  value = tonumber(value)
  return value and value == value and value > 0 and value < math.huge and value or nil
end
function Size.speciesScale(heightIn)
  local height = positive(heightIn)
  if not height then return 1 end
  local meters = height * 0.0254
  -- Smoothly approaches 0.72 / 1.56; at 1m the value is exactly one.
  return 0.72 + 0.84 * (1 - 2 / (meters + 2))
end
function Size.referenceExtent(tex, x0, y0, x1, y1)
  if not tex then return nil end
  local receipt = tex.ascendantSpriteReceipt
  local explicit = type(receipt) == 'table' and receipt.apiVersion == 1
    and receipt.body == 'full' and positive(receipt.referenceExtent) or nil
  if explicit and explicit <= 8192 then return explicit, 'animation-envelope' end
  local ownCard = tex.kantoAscendantNonCrystalHd == true
    or tex.kantoAscendantMegaSupersampled == true
    or tex.kantoAscendantGorochuSupersampled == true
  -- Never use the inner/native rear's receipt after a wrapper repaints it.
  local native = not ownCard and positive(tex.vascReferenceExtent) or nil
  if native and native > 8192 then native = nil end
  if native and tex.vascReferenceComplete == true then
    return native, 'animation-envelope'
  end
  local owner = tex.vascRenderMon or tex.vascRenderBattler
  local key = tex.vascRenderModelKey
  if (type(owner) ~= 'table' and type(owner) ~= 'userdata')
      or type(key) ~= 'string' then return nil end
  key = key .. '|' .. tostring(tex.kantoAscendantNonCrystalHdProvider or '')
    .. '|' .. tostring(tex.vascSpriteSourceKey or '')
  local held = references[owner]
  if held and held[key] then return held[key], 'frozen-source' end
  -- Native raw images are complete even during a send-out. A captured canvas
  -- may be a shrinking/fainting body: never use it to calibrate future frames.
  local extent = native
  if not extent and not tex.inkTransient and type(x0)=='number'
      and type(y0)=='number' and type(x1)=='number' and type(y1)=='number'
      and x1>=x0 and y1>=y0 then extent=math.max(x1-x0+1,y1-y0+1) end
  if not positive(extent) or extent < 4 or extent > 8192 then return nil end
  held = held or {}; references[owner] = held; held[key] = extent
  return extent, 'frozen-source'
end
return Size
