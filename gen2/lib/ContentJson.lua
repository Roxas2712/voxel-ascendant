-- Strict, dependency-free JSON reader for content-profile contracts.
-- It rejects duplicate keys, invalid UTF-8, invalid surrogate pairs and
-- trailing data. The parser intentionally exposes no encoder and no file I/O.

local ContentJson = { null = {} }
local parseValue

local function fail(message, at)
  return nil, ("%s at byte %d"):format(tostring(message), tonumber(at) or 0)
end

local function skipWhitespace(text, at)
  while at <= #text do
    local byte = text:byte(at)
    if byte ~= 0x20 and byte ~= 0x09 and byte ~= 0x0A and byte ~= 0x0D then break end
    at = at + 1
  end
  return at
end

local function validUtf8(text)
  local at, size = 1, #text
  while at <= size do
    local a = text:byte(at)
    if a < 0x80 then
      at = at + 1
    else
      local count, minimum
      if a >= 0xC2 and a <= 0xDF then count, minimum = 1, 0x80
      elseif a >= 0xE0 and a <= 0xEF then count, minimum = 2, 0x800
      elseif a >= 0xF0 and a <= 0xF4 then count, minimum = 3, 0x10000
      else return false end
      if at + count > size then return false end
      local code = a % (2 ^ (6 - count))
      for offset = 1, count do
        local b = text:byte(at + offset)
        if b < 0x80 or b > 0xBF then return false end
        code = code * 64 + (b - 0x80)
      end
      if code < minimum or code > 0x10FFFF
         or (code >= 0xD800 and code <= 0xDFFF) then return false end
      at = at + count + 1
    end
  end
  return true
end

local function utf8Codepoint(code)
  if code <= 0x7F then return string.char(code) end
  if code <= 0x7FF then
    return string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64)
  end
  if code <= 0xFFFF then
    return string.char(0xE0 + math.floor(code / 4096),
      0x80 + math.floor(code / 64) % 64, 0x80 + code % 64)
  end
  return string.char(0xF0 + math.floor(code / 262144),
    0x80 + math.floor(code / 4096) % 64,
    0x80 + math.floor(code / 64) % 64, 0x80 + code % 64)
end

local function unicodeEscape(text, at)
  local hex = text:sub(at, at + 3)
  if #hex ~= 4 or not hex:match("^[0-9a-fA-F]+$") then
    return fail("invalid unicode escape", at)
  end
  local code = tonumber(hex, 16)
  local nextAt = at + 4
  if code >= 0xD800 and code <= 0xDBFF then
    if text:sub(nextAt, nextAt + 1) ~= "\\u" then
      return fail("high surrogate without low surrogate", nextAt)
    end
    local lowHex = text:sub(nextAt + 2, nextAt + 5)
    if #lowHex ~= 4 or not lowHex:match("^[0-9a-fA-F]+$") then
      return fail("invalid low surrogate", nextAt + 2)
    end
    local low = tonumber(lowHex, 16)
    if low < 0xDC00 or low > 0xDFFF then
      return fail("invalid low surrogate", nextAt + 2)
    end
    code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
    nextAt = nextAt + 6
  elseif code >= 0xDC00 and code <= 0xDFFF then
    return fail("unpaired low surrogate", at)
  end
  return utf8Codepoint(code), nextAt
end

local function parseString(text, at)
  if text:sub(at, at) ~= '"' then return fail("expected string", at) end
  at = at + 1
  local out = {}
  while at <= #text do
    local byte = text:byte(at)
    if byte == 0x22 then return table.concat(out), at + 1 end
    if byte < 0x20 then return fail("control character in string", at) end
    if byte == 0x5C then
      local escape = text:sub(at + 1, at + 1)
      local replacements = {
        ['"']='"', ['\\']='\\', ['/']='/', b='\b', f='\f',
        n='\n', r='\r', t='\t',
      }
      if replacements[escape] then
        out[#out + 1] = replacements[escape]
        at = at + 2
      elseif escape == "u" then
        local value, nextAt = unicodeEscape(text, at + 2)
        if type(nextAt) ~= "number" then return nil, value end
        out[#out + 1], at = value, nextAt
      else
        return fail("invalid string escape", at)
      end
    else
      local start = at
      repeat at = at + 1 until at > #text or text:byte(at) == 0x22
        or text:byte(at) == 0x5C or text:byte(at) < 0x20
      out[#out + 1] = text:sub(start, at - 1)
    end
  end
  return fail("unterminated string", at)
end

local function parseNumber(text, at)
  -- Lua patterns do not implement non-capturing groups. Validate a bounded
  -- candidate with the JSON grammar in explicit stages instead.
  local token
  local start = at
  if text:sub(at, at) == "-" then at = at + 1 end
  if text:sub(at, at) == "0" then
    at = at + 1
    if text:sub(at, at):match("%d") then return fail("leading zero", at) end
  elseif text:sub(at, at):match("[1-9]") then
    repeat at = at + 1 until not text:sub(at, at):match("%d")
  else
    return fail("invalid number", at)
  end
  if text:sub(at, at) == "." then
    at = at + 1
    if not text:sub(at, at):match("%d") then return fail("invalid fraction", at) end
    repeat at = at + 1 until not text:sub(at, at):match("%d")
  end
  if text:sub(at, at):match("[eE]") then
    at = at + 1
    if text:sub(at, at):match("[+-]") then at = at + 1 end
    if not text:sub(at, at):match("%d") then return fail("invalid exponent", at) end
    repeat at = at + 1 until not text:sub(at, at):match("%d")
  end
  token = text:sub(start, at - 1)
  local value = tonumber(token)
  if not value or value ~= value or value == math.huge or value == -math.huge then
    return fail("number outside supported range", start)
  end
  return value, at
end

local function parseArray(text, at)
  local out = {}
  at = skipWhitespace(text, at + 1)
  if text:sub(at, at) == "]" then return out, at + 1 end
  while true do
    local value, nextAt = parseValue(text, at)
    if type(nextAt) ~= "number" then return nil, value end
    out[#out + 1], at = value, skipWhitespace(text, nextAt)
    local token = text:sub(at, at)
    if token == "]" then return out, at + 1 end
    if token ~= "," then return fail("expected comma or closing bracket", at) end
    at = skipWhitespace(text, at + 1)
  end
end

local function parseObject(text, at)
  local out, seen = {}, {}
  at = skipWhitespace(text, at + 1)
  if text:sub(at, at) == "}" then return out, at + 1 end
  while true do
    local key, nextAt = parseString(text, at)
    if type(nextAt) ~= "number" then return nil, key end
    if seen[key] then return fail("duplicate object key " .. key, at) end
    seen[key] = true
    at = skipWhitespace(text, nextAt)
    if text:sub(at, at) ~= ":" then return fail("expected colon", at) end
    local value
    value, nextAt = parseValue(text, skipWhitespace(text, at + 1))
    if type(nextAt) ~= "number" then return nil, value end
    out[key], at = value, skipWhitespace(text, nextAt)
    local token = text:sub(at, at)
    if token == "}" then return out, at + 1 end
    if token ~= "," then return fail("expected comma or closing brace", at) end
    at = skipWhitespace(text, at + 1)
  end
end

parseValue = function(text, at)
  at = skipWhitespace(text, at)
  local token = text:sub(at, at)
  if token == '"' then return parseString(text, at) end
  if token == "{" then return parseObject(text, at) end
  if token == "[" then return parseArray(text, at) end
  if text:sub(at, at + 3) == "true" then return true, at + 4 end
  if text:sub(at, at + 4) == "false" then return false, at + 5 end
  if text:sub(at, at + 3) == "null" then return ContentJson.null, at + 4 end
  if token == "-" or token:match("%d") then return parseNumber(text, at) end
  return fail("unexpected token", at)
end

function ContentJson.decode(text)
  if type(text) ~= "string" then return nil, "JSON input must be a string" end
  if not validUtf8(text) then return nil, "JSON input is not valid UTF-8" end
  local value, nextAt = parseValue(text, 1)
  if type(nextAt) ~= "number" then return nil, value end
  nextAt = skipWhitespace(text, nextAt)
  if nextAt <= #text then return fail("trailing JSON data", nextAt) end
  return value
end

return ContentJson
