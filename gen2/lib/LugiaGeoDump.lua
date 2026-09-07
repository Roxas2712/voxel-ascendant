-- Dex-249-only Stadium 2 geo-layout diagnostic exporter.
--
-- This module deliberately does NOT participate in model construction.  It
-- reads the original decompressed Lugia FRAGMENT a second time and writes a
-- human-readable description of the scene graph and display-list attachment
-- points.  Keeping diagnostics separate from StadiumFragment is important:
-- previous attempts to preserve extra geo nodes in the shared importer caused
-- regressions across the full roster.  Nothing in this file changes a vertex,
-- bone, texture, animation, or DSM byte.

local V = ...
local Compat = V.require("EngineCompat")
local StadiumFragment = V.require("StadiumFragment")

local Dump = {}

local floor = math.floor
local byte = string.byte
local concat = table.concat

local function hx(v, n)
  if v == nil then return "nil" end
  n = n or 8
  if v < 0 then return "-0x" .. string.format("%0" .. n .. "X", -v) end
  return "0x" .. string.format("%0" .. n .. "X", v)
end

local function nfmt(v)
  if v == nil then return "nil" end
  return string.format("%.7g", v)
end

local function vec3(a, b, c)
  return ("(%s,%s,%s)"):format(nfmt(a), nfmt(b), nfmt(c))
end

local function rawHex(f, o, size)
  if o == nil or o < 0 or o + size > #f.d then return "<out-of-range>" end
  local t = {}
  for i = 0, size - 1 do t[#t + 1] = string.format("%02X", f:u8(o + i)) end
  return concat(t, " ")
end

local function safePtr(f, o)
  local ok, p = pcall(f.ptr, f, o)
  if not ok then return nil end
  return p
end

-- Summarise a display list without changing the extractor's RSP cache.  This
-- lets the dump identify which geo node owns a large rigid mesh chunk (the
-- detached Lugia wings/body pieces are exactly that kind of failure).
local function dlSummary(f, start)
  if start == nil then return "DL=nil" end
  local seen = {}
  local loads, verts, tris, calls, commands = 0, 0, 0, 0, 0
  local minx, miny, minz, maxx, maxy, maxz

  local function addVertexBlock(a, n)
    if not a or a < 0 or a + n * 0x10 > #f.d then return end
    loads = loads + 1
    verts = verts + n
    for i = 0, n - 1 do
      local p = a + i * 0x10
      local x, y, z = f:s16(p), f:s16(p + 2), f:s16(p + 4)
      if not minx or x < minx then minx = x end
      if not miny or y < miny then miny = y end
      if not minz or z < minz then minz = z end
      if not maxx or x > maxx then maxx = x end
      if not maxy or y > maxy then maxy = y end
      if not maxz or z > maxz then maxz = z end
    end
  end

  local function walk(o, depth)
    if o == nil or depth > 8 or seen[o] then return end
    seen[o] = true
    local guard = 0
    while o >= 0 and o + 8 <= #f.d and guard < 8192 do
      guard = guard + 1
      commands = commands + 1
      local w0, w1 = f:u32(o), f:u32(o + 4)
      local op = floor(w0 / 0x1000000)
      o = o + 8
      if op == 0xDF then
        return
      elseif op == 0xDE then
        calls = calls + 1
        walk(f:off(w1), depth + 1)
        if floor(w0 / 0x10000) % 256 ~= 0 then return end
      elseif op == 0x01 then
        local n = floor(w0 / 0x1000) % 256
        addVertexBlock(f:off(w1), n)
      elseif op == 0x05 then
        tris = tris + 1
      elseif op == 0x06 then
        tris = tris + 2
      end
    end
  end

  local ok = pcall(walk, start, 0)
  if not ok then return ("DL=%s <summary-error>"):format(hx(start)) end
  local bounds = "none"
  if minx then
    bounds = ("[%d,%d,%d]-[%d,%d,%d]"):format(minx, miny, minz, maxx, maxy, maxz)
  end
  return ("DL=%s cmds=%d calls=%d vtxLoads=%d verts=%d tris=%d rawBounds=%s")
    :format(hx(start), commands, calls, loads, verts, tris, bounds)
end

local function commandDetails(f, o, cmd)
  if cmd == 0x00 then
    return "BRANCH_LINK -> " .. hx(safePtr(f, o + 4))
  elseif cmd == 0x01 then
    return "END"
  elseif cmd == 0x02 then
    return "JUMP -> " .. hx(safePtr(f, o + 4))
  elseif cmd == 0x03 then
    return "BRANCH -> " .. hx(safePtr(f, o + 4))
  elseif cmd == 0x04 then
    return "RETURN"
  elseif cmd == 0x05 then
    return "OPEN_NODE"
  elseif cmd == 0x06 then
    return "CLOSE_NODE"
  elseif cmd == 0x08 then
    return ("FX callback=%s arg=%s"):format(hx(f:u32(o + 4)), hx(safePtr(f, o + 8)))
  elseif cmd == 0x17 then
    return ("MODEL_HEADER tex=%d tlut=%d verts=%d texTbl=%s tlutTbl=%s vtxBase=%s")
      :format(f:s16(o + 2), f:s16(o + 4), f:s16(o + 6),
              hx(safePtr(f, o + 8)), hx(safePtr(f, o + 0xC)), hx(safePtr(f, o + 0x10)))
  elseif cmd == 0x18 then
    return "SHADOW/DEFAULT_ORIGIN"
  elseif cmd == 0x1B then
    return ("STATIC_TR t=%s rDeg=%s")
      :format(vec3(f:s16(o + 0xA), f:s16(o + 0xC), f:s16(o + 0xE)),
              vec3(f:s16(o + 4), f:s16(o + 6), f:s16(o + 8)))
  elseif cmd == 0x1C then
    return ("STATIC_SCALE s=%s")
      :format(vec3(f:s32(o + 4) / 65536.0, f:s32(o + 8) / 65536.0,
                   f:s32(o + 0xC) / 65536.0))
  elseif cmd == 0x1D then
    return ("JOINT id=%d flags=0x%02X chan=%d t=%s r=%s s=%s")
      :format(f:u8(o + 1), f:u8(o + 2), f:s8(o + 3),
              vec3(f:s16(o + 4), f:s16(o + 6), f:s16(o + 8)),
              vec3(f:s16(o + 0xA), f:s16(o + 0xC), f:s16(o + 0xE)),
              vec3(f:s32(o + 0x10) / 65536.0, f:s32(o + 0x14) / 65536.0,
                   f:s32(o + 0x18) / 65536.0))
  elseif cmd == 0x1E then
    local dl = safePtr(f, o + 4)
    return ("DL_NAMED layer=%d boneId=%d %s")
      :format(f:u8(o + 1), f:s16(o + 2), dlSummary(f, dl))
  elseif cmd == 0x20 then
    local dl = safePtr(f, o + 0x10)
    return ("DL_LOCAL_TR layer=%d unk02=%d rDeg=%s t=%s %s")
      :format(f:u8(o + 1), f:s16(o + 2),
              vec3(f:s16(o + 4), f:s16(o + 6), f:s16(o + 8)),
              vec3(f:s16(o + 0xA), f:s16(o + 0xC), f:s16(o + 0xE)),
              dlSummary(f, dl))
  elseif cmd == 0x21 then
    local dl = safePtr(f, o + 0xC)
    return ("DL_CAMERA_LOCAL layer=%d pos=%s scale=%s %s")
      :format(f:u8(o + 1), vec3(f:s16(o + 2), f:s16(o + 4), f:s16(o + 6)),
              nfmt(f:s32(o + 8) / 65536.0), dlSummary(f, dl))
  elseif cmd == 0x22 then
    local dl = safePtr(f, o + 4)
    return ("DL_CURRENT layer=%d %s"):format(f:u8(o + 1), dlSummary(f, dl))
  elseif cmd == 0x23 then
    return ("MATERIAL layer=%d texAnim=%d mat=%s tex=%d tlut=%d rgba=(%d,%d,%d,%d)")
      :format(f:u8(o + 1), f:s16(o + 2), hx(safePtr(f, o + 4)),
              f:s16(o + 8), f:s16(o + 0xA),
              f:u8(o + 0xC), f:u8(o + 0xD), f:u8(o + 0xE), f:u8(o + 0xF))
  elseif cmd == 0x24 then
    return ("ATTACHMENT_TAG id=%d"):format(f:s16(o + 2))
  elseif cmd == 0x25 then
    return "SET_CURRENT_FLAG_4"
  end
  return ""
end

local function skinList(prim)
  local seen, out = {}, {}
  for i = 1, #(prim.skin or {}) do
    local b = prim.skin[i]
    if b ~= nil and not seen[b] then seen[b] = true; out[#out + 1] = b end
  end
  table.sort(out)
  for i = 1, #out do out[i] = tostring(out[i]) end
  return concat(out, ",")
end

local function primBounds(prim)
  local p = prim.pos or {}
  local minx, miny, minz, maxx, maxy, maxz
  for i = 1, #p, 3 do
    local x, y, z = p[i], p[i + 1], p[i + 2]
    if x and y and z then
      if not minx or x < minx then minx = x end
      if not miny or y < miny then miny = y end
      if not minz or z < minz then minz = z end
      if not maxx or x > maxx then maxx = x end
      if not maxy or y > maxy then maxy = y end
      if not maxz or z > maxz then maxz = z end
    end
  end
  if not minx then return "none" end
  return ("[%g,%g,%g]-[%g,%g,%g]"):format(minx, miny, minz, maxx, maxy, maxz)
end

local function md5(s)
  local ok, out = pcall(function()
    if not (love and love.data and love.data.hash and love.data.encode) then return nil end
    local d = love.data.hash("md5", s)
    if type(d) == "userdata" and d.getString then d = d:getString() end
    return love.data.encode("string", "hex", d)
  end)
  return (ok and out) or nil
end

function Dump.generate(blob, data, fileno, rom)
  local f, err = StadiumFragment.open(blob, ("lugia-%03d.bin"):format((fileno or 248) + 1))
  if not f then return nil, err end
  local root = f:root()
  if not root then return nil, "could not locate FRAGMENT root" end
  local geoPtr = safePtr(f, root + 0x08)
  local layouts = geoPtr and f:ptrList(geoPtr) or {}

  local lines = {}
  local function add(s) lines[#lines + 1] = s end

  add("Pokemon Stadium 2 Lugia / Dex 249 geo-layout diagnostic")
  add("Generated by VASC4J")
  add("This file contains offsets/numbers only; it does NOT contain ROM model bytes.")
  add("")
  add(("fileno=%s parsedSpecies=%s fragmentBytes=%d fragmentMD5=%s")
      :format(tostring(fileno), tostring(data and data.species), #blob, tostring(md5(blob) or "unavailable")))
  if rom and type(rom.md5) == "function" then
    local ok, h = pcall(rom.md5, rom)
    add("romMD5=" .. tostring((ok and h) or "unavailable"))
  end
  add(("root=%s geoPointerTable=%s geoLayouts=%d")
      :format(hx(root), hx(geoPtr), #layouts))
  for i = 1, #layouts do add(("  layout[%d]=%s"):format(i - 1, hx(layouts[i]))) end
  add("")

  add("=== PARSED MODEL SUMMARY (stable extractor output; diagnostic only) ===")
  add(("bones=%d prims=%d textures=%d anims=%d auxAnims=%d")
      :format(#(data.bones or {}), #(data.prims or {}), #(data.textures or {}),
              #(data.anims or {}), #(data.auxAnims or {})))
  add("rootScale=" .. vec3((data.rootScale or {})[1], (data.rootScale or {})[2], (data.rootScale or {})[3]))
  if data.warnings and #data.warnings > 0 then
    for i = 1, #data.warnings do add("warning[" .. i .. "]=" .. tostring(data.warnings[i])) end
  else
    add("warnings=none")
  end
  add("")

  add("=== EXTRACTED BONE TABLE ===")
  for i = 1, #(data.bones or {}) do
    local b = data.bones[i]
    add(("bone[%d] parent=%s id=%s flags=0x%02X chan=%s t=%s r=%s s=%s")
      :format(i - 1, tostring(b.parent), tostring(b.boneId), tonumber(b.flags) or 0,
              tostring(b.chan), vec3(b.t[1], b.t[2], b.t[3]),
              vec3(b.r[1], b.r[2], b.r[3]), vec3(b.s[1], b.s[2], b.s[3])))
  end
  add("")

  add("=== EXTRACTED PRIMITIVE / SKIN OWNERSHIP ===")
  for i = 1, #(data.prims or {}) do
    local p = data.prims[i]
    add(("prim[%d] tex=%s nverts=%s nidx=%s skinBones={%s} localBounds=%s")
      :format(i - 1, tostring(p.tex), tostring(p.nverts), tostring(p.nidx),
              skinList(p), primBounds(p)))
  end
  add("")

  add("=== RAW GEO LAYOUT WALK ===")
  add("Columns: sequence, file offset, call depth, graph depth, parserBone, parent graph node, decoded fields, raw command")

  local seq, maxCommands = 0, 30000
  local parserStack = { -1 }
  local nextBone = 0
  local graph = { [0] = "ROOT" }

  local function parserCurBone()
    local n = #parserStack
    if n >= 2 then return parserStack[n - 1] end
    return -1
  end

  local function cloneArray(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
  end

  local function walk(o, callDepth, graphDepth, restoreGraphOnEnd)
    if o == nil or callDepth > 48 then return graphDepth end
    local guard = 0
    while o and o >= 0 and o < #f.d and guard < maxCommands do
      guard = guard + 1
      seq = seq + 1
      if seq > maxCommands then add("ABORT: command safety limit reached"); return graphDepth end
      local cmd = f:u8(o)
      local size = StadiumFragment.CMD_SIZES[cmd]
      if not size then
        add(("%05d off=%s call=%02d graph=%02d UNKNOWN_OP=%s"):format(seq, hx(o), callDepth, graphDepth, hx(cmd, 2)))
        return graphDepth
      end
      local parent = graph[graphDepth - 1] or "ROOT"
      local details = commandDetails(f, o, cmd)
      add(("%05d off=%s call=%02d graph=%02d parserBone=%s parent=%s op=0x%02X %-18s raw=%s")
        :format(seq, hx(o), callDepth, graphDepth, tostring(parserCurBone()),
                tostring(parent), cmd, details, rawHex(f, o, size)))

      if cmd == 0x01 then
        return graphDepth
      elseif cmd == 0x04 then
        return graphDepth
      elseif cmd == 0x00 then
        -- Stadium's branch-and-link/end pair restores graph depth and return
        -- state.  Clone both views so the diagnostic records that semantics
        -- without changing the stable extractor's own behaviour.
        local savedParser, savedGraph = cloneArray(parserStack), cloneArray(graph)
        walk(safePtr(f, o + 4), callDepth + 1, graphDepth, true)
        parserStack, graph = savedParser, savedGraph
      elseif cmd == 0x03 then
        -- Ordinary branch/return does not have the END command's explicit
        -- graph-index restoration; balanced child layouts normally end at the
        -- same depth. Preserve whatever depth the branch returns.
        graphDepth = walk(safePtr(f, o + 4), callDepth + 1, graphDepth, false)
      elseif cmd == 0x02 then
        o = safePtr(f, o + 4)
        if o == nil then return graphDepth end
        cmd = nil
      elseif cmd == 0x05 then
        parserStack[#parserStack + 1] = parserStack[#parserStack]
        graph[graphDepth + 1] = graph[graphDepth]
        graphDepth = graphDepth + 1
      elseif cmd == 0x06 then
        if #parserStack > 1 then parserStack[#parserStack] = nil end
        graph[graphDepth] = nil
        if graphDepth > 0 then graphDepth = graphDepth - 1 end
      elseif cmd == 0x1D then
        local bi = nextBone
        nextBone = nextBone + 1
        parserStack[#parserStack] = bi
        graph[graphDepth] = ("JOINT#%d/id%d@%s"):format(bi, f:u8(o + 1), hx(o))
      elseif cmd ~= 0x12 and cmd ~= 0x15 and cmd ~= 0x25 then
        -- Most non-control geo commands create a graph node.  Keeping a label
        -- for the most recently created node at this depth makes the parent
        -- relationship visible without trying to emulate the renderer.
        graph[graphDepth] = ("OP%02X@%s"):format(cmd, hx(o))
      end

      if cmd ~= nil then o = o + size end
    end
    if restoreGraphOnEnd then return graphDepth end
    return graphDepth
  end

  for i = 1, #layouts do
    add("")
    add(("--- layout[%d] %s ---"):format(i - 1, hx(layouts[i])))
    local savedParser, savedGraph, savedNext = cloneArray(parserStack), cloneArray(graph), nextBone
    walk(layouts[i], 0, 0, false)
    parserStack, graph, nextBone = savedParser, savedGraph, savedNext
  end

  add("")
  add("=== END DUMP ===")
  return concat(lines, "\n") .. "\n"
end

function Dump.write(blob, data, fileno, rom, path)
  local text, err = Dump.generate(blob, data, fileno, rom)
  if not text then return false, err end
  local fs = Compat.fs()
  if not (fs and type(fs.write) == "function") then return false, "filesystem unavailable" end
  local dir = path and path:match("^(.*)/[^/]+$")
  if dir and fs.createDirectory then pcall(fs.createDirectory, dir) end
  local ok, werr = fs.write(path or "cache/stadium/lugia_debug/249_geo_dump.txt", text)
  if not ok then return false, tostring(werr) end
  return true
end

return Dump
