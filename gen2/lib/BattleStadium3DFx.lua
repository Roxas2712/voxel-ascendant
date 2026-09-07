-- Pokemon Stadium Overworld Models - Phase 5 world-space battle effects
--
-- This module does NOT replace Dramatic Shape's battle renderer. It wraps the
-- public Stadium.begin/update/draw/finish methods and draws additional
-- procedural billboards through Dramatic Shape's own Voxel3D scene while the
-- Stadium models are being drawn. Effects therefore occupy real arena (x,y,z)
-- positions and move correctly when the battle camera orbits.  v0.2.08 also
-- adapts Gold's Gen-2 BattleState/AnimRunner so these effects receive the real
-- move id, attacker side and animation frame in live Gold voxel battles.
--
-- No Pokemon Stadium effect assets are included or extracted here. The shapes
-- are original procedural stand-ins built from LÖVE canvases.
local V = ...
local M = {}

local PI, TAU = math.pi, math.pi * 2
local clamp = function(x,a,b) if x<a then return a elseif x>b then return b end return x end
local function lerp(a,b,t) return a + (b-a)*t end

local Stadium = V.require("Stadium")
local Voxel3D = V.require("Voxel3D")
local Mat4 = V.require("Mat4")
local BattleBillboard = V.require("BattleBillboard")
local BattleEffectAnchors = V.require("BattleEffectAnchors")

local live = { arena=nil, battle=nil, groundY=0, ready=false,
               attackerProfile=nil, targetProfile=nil }
local tex = {}
local installed = false

local function log(level, fmt, ...)
  local l = V and V.mod and V.mod.log
  local fn = l and l[level]
  if type(fn)=="function" then pcall(fn, l, fmt, ...) end
end

local function safeGraphics(fn)
  local g = love and love.graphics
  if not g then return false end
  local oldCanvas = g.getCanvas and g.getCanvas() or nil
  local ok, err = pcall(fn, g)
  if g.setCanvas then pcall(g.setCanvas, oldCanvas) end
  if g.setColor then pcall(g.setColor, 1,1,1,1) end
  if g.setBlendMode then pcall(g.setBlendMode, "alpha") end
  if not ok then log("warn", "Phase 5 texture build skipped: %s", tostring(err)) end
  return ok
end

local function makeCanvas(name, draw)
  if tex[name] then return tex[name] end
  local g = love and love.graphics
  if not (g and g.newCanvas) then return nil end
  safeGraphics(function(gfx)
    local c = gfx.newCanvas(32,32)
    if c.setFilter then c:setFilter("linear","linear") end
    gfx.setCanvas(c)
    gfx.clear(0,0,0,0)
    gfx.setBlendMode("alpha")
    draw(gfx)
    tex[name] = c
  end)
  return tex[name]
end

local function buildTextures()
  if live.ready then return true end
  makeCanvas("orb", function(g)
    for r=13,2,-1 do
      local q = r/13
      g.setColor(1.0, 0.72 + 0.25*(1-q), 0.18 + 0.70*(1-q), 0.055 + 0.075*(1-q))
      g.circle("fill",16,16,r)
    end
    g.setColor(1,1,1,0.95); g.circle("fill",16,16,4)
  end)
  makeCanvas("water", function(g)
    for r=13,2,-1 do
      local q=r/13
      g.setColor(0.16+0.45*(1-q),0.55+0.35*(1-q),1.0,0.05+0.08*(1-q))
      g.circle("fill",16,16,r)
    end
    g.setColor(0.84,0.96,1,0.9); g.ellipse("fill",12,11,4,2)
  end)
  makeCanvas("electric", function(g)
    g.setLineWidth(4); g.setColor(1,0.78,0.05,0.55)
    g.line(6,3,18,11,11,16,24,23,17,29)
    g.setLineWidth(1.5); g.setColor(1,1,0.80,1)
    g.line(6,3,18,11,11,16,24,23,17,29)
  end)
  makeCanvas("wind", function(g)
    -- Android/LuaJIT-safe wind streak. Avoid love.graphics.arc here because
    -- older LÖVE signatures differ and can leave tex.wind nil with no visible
    -- tornado. A hand-built polyline works on every renderer we target.
    local pts = {3,22, 6,17, 11,13, 17,11, 24,12, 29,16}
    g.setLineWidth(5); g.setColor(0.72,0.90,1.00,0.62)
    g.line(pts)
    g.setLineWidth(2); g.setColor(1,1,1,0.98)
    g.line(pts)
    g.setLineWidth(1); g.setColor(0.86,0.96,1.00,0.92)
    g.line(5,26,10,22,16,20,23,21,28,24)
  end)
  makeCanvas("ice", function(g)
    g.setColor(0.55,0.92,1,0.78); g.polygon("fill",16,1,23,15,16,31,9,15)
    g.setColor(1,1,1,0.9); g.polygon("fill",16,4,18,15,16,27,14,15)
  end)
  makeCanvas("psychic", function(g)
    g.setLineWidth(2)
    for r=13,4,-3 do
      g.setColor(0.92,0.28,1.0,0.22 + (13-r)*0.03)
      g.circle("line",16,16,r)
    end
    g.setColor(1,0.75,1,0.85); g.circle("fill",16,16,3)
  end)
  makeCanvas("poison", function(g)
    g.setColor(0.62,0.08,0.75,0.48); g.circle("fill",13,18,9); g.circle("fill",21,13,7)
    g.setColor(0.92,0.52,1,0.7); g.circle("line",13,18,9); g.circle("line",21,13,7)
  end)
  makeCanvas("ring", function(g)
    g.setLineWidth(3); g.setColor(1,1,1,0.82); g.circle("line",16,16,11)
    g.setLineWidth(1); g.setColor(1,0.78,0.25,0.72); g.circle("line",16,16,14)
  end)
  makeCanvas("dust", function(g)
    for i=1,12 do
      local a=i*2.399; local r=4+(i%5)*2.2; local s=2+(i%3)
      g.setColor(0.58,0.44,0.28,0.25 + (i%4)*0.08)
      g.circle("fill",16+math.cos(a)*r,16+math.sin(a)*r,s)
    end
  end)
  makeCanvas("leaf", function(g)
    g.setColor(0.20,0.82,0.24,0.82)
    g.ellipse("fill",16,16,5,13,0.68)
    g.setColor(0.72,1.00,0.56,0.92)
    g.line(12,23,20,9)
  end)
  makeCanvas("shadow", function(g)
    for r=13,3,-2 do
      local q=r/13
      g.setColor(0.26,0.05,0.42,0.04+0.055*(1-q))
      g.circle("fill",16,16,r)
    end
    g.setColor(0.72,0.34,0.92,0.72); g.circle("line",16,16,9)
  end)
  makeCanvas("spark", function(g)
    g.setColor(1,0.92,0.38,0.92)
    g.polygon("fill",16,1,19,11,30,9,21,16,30,23,19,21,16,31,13,21,2,23,11,16,2,9,13,11)
    g.setColor(1,1,1,0.92); g.circle("fill",16,16,3)
  end)
  makeCanvas("bubble", function(g)
    g.setColor(0.38,0.78,1,0.22); g.circle("fill",16,16,11)
    g.setColor(0.78,0.95,1,0.86); g.setLineWidth(2); g.circle("line",16,16,11)
    g.setColor(1,1,1,0.82); g.circle("fill",12,12,2)
  end)
  makeCanvas("heart", function(g)
    g.setColor(1,0.30,0.52,0.86)
    g.circle("fill",11,12,6); g.circle("fill",21,12,6)
    g.polygon("fill",5,14,27,14,16,29)
  end)
  makeCanvas("needle", function(g)
    g.setColor(0.38,0.24,0.10,0.92)
    g.polygon("fill",2,18,25,12,30,16,25,20)
    g.setColor(0.96,0.90,0.62,0.98)
    g.polygon("fill",3,16,25,13,30,16,25,17)
  end)
  makeCanvas("bone", function(g)
    g.setLineWidth(6); g.setColor(0.94,0.89,0.72,0.98)
    g.line(8,24,24,8)
    g.circle("fill",7,25,4); g.circle("fill",4,22,4)
    g.circle("fill",25,7,4); g.circle("fill",28,10,4)
    g.setLineWidth(1); g.setColor(1,1,0.91,0.72)
    g.line(9,21,22,8)
  end)
  makeCanvas("present", function(g)
    g.setColor(0.88,0.10,0.18,0.96); g.rectangle("fill",5,11,22,18)
    g.setColor(1.0,0.82,0.18,0.98); g.rectangle("fill",14,11,4,18)
    g.rectangle("fill",5,16,22,4)
    g.setLineWidth(3); g.line(16,12,10,6,16,8,22,6,16,12)
    g.setColor(1,1,0.72,0.82); g.rectangle("fill",6,12,20,2)
  end)
  makeCanvas("blade", function(g)
    g.setColor(0.70,0.82,0.94,0.96)
    g.polygon("fill",16,1,22,23,16,29,10,23)
    g.setColor(1,1,1,0.94)
    g.polygon("fill",16,3,18,22,16,25,14,22)
    g.setColor(0.72,0.52,0.18,0.98); g.rectangle("fill",8,24,16,3)
  end)
  makeCanvas("coin", function(g)
    g.setColor(0.96,0.66,0.08,0.98); g.circle("fill",16,16,12)
    g.setColor(1,0.92,0.42,0.98); g.circle("line",16,16,9)
    g.setLineWidth(2); g.line(12,16,20,16); g.line(16,12,16,20)
  end)
  makeCanvas("note", function(g)
    g.setColor(0.88,0.72,1.0,0.96)
    g.setLineWidth(4); g.line(18,5,18,22,27,18,27,4,18,7)
    g.circle("fill",13,24,6); g.circle("fill",23,20,6)
  end)
  makeCanvas("shield", function(g)
    g.setColor(0.30,0.82,1.0,0.28); g.circle("fill",16,16,14)
    g.setColor(0.82,0.97,1.0,0.94); g.setLineWidth(2)
    g.circle("line",16,16,13); g.polygon("line",16,3,28,12,23,28,9,28,4,12)
  end)
  makeCanvas("web", function(g)
    g.setColor(0.92,0.96,1.0,0.94); g.setLineWidth(1.5)
    for i=0,7 do
      local a=i*TAU/8; g.line(16,16,16+math.cos(a)*14,16+math.sin(a)*14)
    end
    for r=5,14,4 do g.circle("line",16,16,r) end
  end)
  makeCanvas("spike", function(g)
    g.setColor(0.42,0.44,0.50,0.98); g.polygon("fill",16,1,27,29,5,29)
    g.setColor(0.82,0.86,0.92,0.86); g.polygon("fill",16,4,17,25,10,27)
  end)
  makeCanvas("baton", function(g)
    g.setColor(0.92,0.74,0.22,0.98); g.setLineWidth(6); g.line(7,25,25,7)
    g.setColor(1,0.94,0.62,0.98); g.circle("fill",6,26,4); g.circle("fill",26,6,4)
  end)
  live.ready = tex.orb ~= nil
  return live.ready
end

local function moveDef(battle)
  if not battle then return nil end
  -- Gold's adapter resolves the move through Battle:moveDef once, because the
  -- live move id may be a symbolic key ("TACKLE") rather than a numeric table
  -- index.  Prefer that resolved definition so the 3D effect layer never
  -- depends on how a particular engine build keys game.data.moves.
  if type(battle.def) == "table" then return battle.def end
  local key = battle.animName
  local moves = battle.data and battle.data.moves
  if key ~= nil and type(moves) == "table" then
    local direct = moves[key]
    if type(direct) == "table" then return direct end
    local want = tonumber(key)
    for _, def in pairs(moves) do
      if type(def) == "table" then
        local index = tonumber(def.index or def.moveIndex or def.number)
        if want and index == want then return def end
        if type(key) == "string" then
          local id = tostring(def.id or def.name or "")
          if id == key then return def end
        end
      end
    end
  end
  return nil
end
local function norm(s) return type(s)=="string" and string.upper(s):gsub("[^A-Z0-9]","") or "" end
local function moveName(battle, def)
  local n = norm(def and (def.name or def.id))
  if n~="" then return n end
  return norm(battle and battle.animName)
end
local function moveType(def)
  local t=def and (def.type or def.moveType)
  if type(t)=="table" then t=t.id or t.name end
  return norm(t)
end
local function power(def) return tonumber(def and def.power) or 0 end

-- Gold does not expose the Gen-1 BattleState fields this module originally
-- listened to (animName/animPlaying/animAttackerIsPlayer).  Its native
-- AnimRunner does expose the same facts in a different shape: env.animId,
-- env.battleTurn, frames and stopped.  Adapt only those presentation fields so
-- every existing procedural effect below can stay generation-agnostic.
local function goldBattleAdapter(screen)
  if type(screen) ~= "table" then return nil end
  local moveId = screen._stadium3DFxMove
  local side = screen._stadium3DFxSide
  local token = screen._stadium3DFxToken
  local elapsed = tonumber(screen._stadium3DFxElapsed)
  if moveId == nil or side == nil or token == nil or elapsed == nil then return nil end
  if elapsed < 0 or elapsed > 1.10 then return nil end

  local data = (screen.game and screen.game.data)
    or (screen.battle and screen.battle.data) or {}
  local def = screen._stadium3DFxDef
  return {
    animPlaying = true,
    animName = moveId,
    animAttackerIsPlayer = side == "player",
    -- Keep the procedural effects on a deterministic ~60 Hz clock even when
    -- Gold swaps its native AnimRunner to the post-hit animation between
    -- update and render.  This was the v0.2.23 "sprites gone, 3D effect gone
    -- too" race.
    frame = math.floor(elapsed * 60 + 0.5),
    data = data,
    def = def,
    _goldScreen = screen,
    _goldToken = token,
  }
end

local SPECIAL = {
  HYPERBEAM="beam", SOLARBEAM="solarbeam", ICEBEAM="icebeam",
  HYDROPUMP="hydro", FIREBLAST="fireblast", THUNDER="thunder",
  SURF="surf", EARTHQUAKE="quake", EXPLOSION="explode", SELFDESTRUCT="explode",
  PSYCHIC="psychic", PSYBEAM="psybeam", CONFUSION="psychic",
  BLIZZARD="blizzard", AURORABEAM="aurora",
  ROCKSLIDE="rocks", ROCKTHROW="rocks", SWIFT="swift",
  THUNDERBOLT="thunderbolt", THUNDERSHOCK="thunderbolt", THUNDERWAVE="thunderwave",
  GUST="tornado", WHIRLWIND="tornado", RAZORWIND="tornado", WINGATTACK="windslash",
  FLAMETHROWER="flamethrower", EMBER="ember",
  BUBBLE="bubble", BUBBLEBEAM="bubble", WATERGUN="watergun",
  RAZORLEAF="razorleaf", VINEWHIP="vine", PETALDANCE="petals",
  MEGADRAIN="drain", ABSORB="drain", LEECHSEED="seed",
  POISONPOWDER="powder", STUNSPORE="powder", SLEEPPOWDER="powder", SPORE="powder",
  SLUDGEBOMB="sludge", ACID="sludge",
  NIGHTSHADE="night", LICK="night",
  DRAGONRAGE="dragon",
  DIG="dig", FISSURE="fissure",
  SEISMICTOSS="seismic", BODYSLAM="body", TAKEDOWN="body",
  -- Generation 2 move aliases. These reuse proven Stadium-style primitives
  -- instead of inventing new renderer dependencies.
  SHADOWBALL="night", CRUNCH="body", IRONTAIL="body", STEELWING="windslash",
  -- Keep the two box-legendaries' signature moves distinct instead of routing
  -- them through generic fire/wind aliases.  The assets remain procedural,
  -- but the staging now reads as Sacred Fire / Aeroblast specifically.
  SACREDFIRE="sacredfire", AEROBLAST="aeroblast", GIGADRAIN="drain",
  SPARK="thunderbolt", ZAPCANNON="thunder", OCTAZOOKA="watergun",
  POWDERSNOW="blizzard", DYNAMICPUNCH="body",
  ICYWIND="blizzard", FLAMEWHEEL="flamethrower", WHIRLPOOL="surf",
  MUDSLAP="quake", ROLLOUT="rocks", BONERUSH="rocks",
  FURYCUTTER="windslash", COTTONSPORE="powder",
  -- Dedicated Gen-I/II batch 1. These moves formerly fell through to a
  -- generic type aura/impact even though their silhouettes are unmistakable.
  FIRESPIN="firespin", WATERFALL="waterfall", PINMISSILE="pinmissile",
  BONEMERANG="bonemerang", TRIATTACK="triattack", PRESENT="present",
  MAGNITUDE="magnitude", PURSUIT="pursuit", SWORDSDANCE="swordsdance",
  RECOVER="recover",
}

-- Complete reviewed Pokemon Crystal move catalog. The numeric comments follow
-- pret/pokecrystal's canonical move_constants.asm order (01..fb). Every Gen-2
-- move is explicitly assigned to a semantic world-space choreography; FAMILY
-- below remains only a fail-open path for future/post-Gen-2 move definitions.
local GEN2_REVIEWED_ROUTE = {
  POUND="punch", -- 001
  KARATECHOP="punch", -- 002
  DOUBLESLAP="multi", -- 003
  COMETPUNCH="punch", -- 004
  MEGAPUNCH="punch", -- 005
  PAYDAY="coin", -- 006
  FIREPUNCH="punch", -- 007
  ICEPUNCH="punch", -- 008
  THUNDERPUNCH="punch", -- 009
  SCRATCH="slash", -- 010
  VICEGRIP="bite", -- 011
  GUILLOTINE="drill", -- 012
  RAZORWIND="windslash", -- 013
  SWORDSDANCE="swordsdance", -- 014
  CUT="slash", -- 015
  GUST="tornado", -- 016
  WINGATTACK="windslash", -- 017
  WHIRLWIND="tornado", -- 018
  FLY="dive", -- 019
  BIND="trap", -- 020
  SLAM="body", -- 021
  VINEWHIP="vine", -- 022
  STOMP="kick", -- 023
  DOUBLEKICK="kick", -- 024
  MEGAKICK="kick", -- 025
  JUMPKICK="kick", -- 026
  ROLLINGKICK="kick", -- 027
  SANDATTACK="sand", -- 028
  HEADBUTT="body", -- 029
  HORNATTACK="horn", -- 030
  FURYATTACK="multi", -- 031
  HORNDRILL="drill", -- 032
  TACKLE="body", -- 033
  BODYSLAM="body", -- 034
  WRAP="trap", -- 035
  TAKEDOWN="body", -- 036
  THRASH="body", -- 037
  DOUBLEEDGE="body", -- 038
  TAILWHIP="statdown", -- 039
  POISONSTING="pinmissile", -- 040
  TWINEEDLE="multi", -- 041
  PINMISSILE="pinmissile", -- 042
  LEER="statdown", -- 043
  BITE="bite", -- 044
  GROWL="statdown", -- 045
  ROAR="sound", -- 046
  SING="sound", -- 047
  SUPERSONIC="sound", -- 048
  SONICBOOM="sound", -- 049
  DISABLE="statdown", -- 050
  ACID="sludge", -- 051
  EMBER="ember", -- 052
  FLAMETHROWER="flamethrower", -- 053
  MIST="mist", -- 054
  WATERGUN="watergun", -- 055
  HYDROPUMP="hydro", -- 056
  SURF="surf", -- 057
  ICEBEAM="icebeam", -- 058
  BLIZZARD="blizzard", -- 059
  PSYBEAM="psybeam", -- 060
  BUBBLEBEAM="bubble", -- 061
  AURORABEAM="aurora", -- 062
  HYPERBEAM="beam", -- 063
  PECK="horn", -- 064
  DRILLPECK="drill", -- 065
  SUBMISSION="body", -- 066
  LOWKICK="kick", -- 067
  COUNTER="counter", -- 068
  SEISMICTOSS="seismic", -- 069
  STRENGTH="body", -- 070
  ABSORB="drain", -- 071
  MEGADRAIN="drain", -- 072
  LEECHSEED="seed", -- 073
  GROWTH="statup", -- 074
  RAZORLEAF="razorleaf", -- 075
  SOLARBEAM="solarbeam", -- 076
  POISONPOWDER="powder", -- 077
  STUNSPORE="powder", -- 078
  SLEEPPOWDER="powder", -- 079
  PETALDANCE="petals", -- 080
  STRINGSHOT="web", -- 081
  DRAGONRAGE="dragon", -- 082
  FIRESPIN="firespin", -- 083
  THUNDERSHOCK="thunderbolt", -- 084
  THUNDERBOLT="thunderbolt", -- 085
  THUNDERWAVE="thunderwave", -- 086
  THUNDER="thunder", -- 087
  ROCKTHROW="rocks", -- 088
  EARTHQUAKE="quake", -- 089
  FISSURE="fissure", -- 090
  DIG="dig", -- 091
  TOXIC="toxic", -- 092
  CONFUSION="psychic", -- 093
  PSYCHICM="psychic", -- 094
  HYPNOSIS="sleep", -- 095
  MEDITATE="statup", -- 096
  AGILITY="statup", -- 097
  QUICKATTACK="dash", -- 098
  RAGE="rage", -- 099
  TELEPORT="vanish", -- 100
  NIGHTSHADE="night", -- 101
  MIMIC="copy", -- 102
  SCREECH="statdown", -- 103
  DOUBLETEAM="vanish", -- 104
  RECOVER="recover", -- 105
  HARDEN="statup", -- 106
  MINIMIZE="statup", -- 107
  SMOKESCREEN="smoke", -- 108
  CONFUSERAY="confuse", -- 109
  WITHDRAW="statup", -- 110
  DEFENSECURL="statup", -- 111
  BARRIER="screen", -- 112
  LIGHTSCREEN="screen", -- 113
  HAZE="mist", -- 114
  REFLECT="screen", -- 115
  FOCUSENERGY="focus", -- 116
  BIDE="counter", -- 117
  METRONOME="copy", -- 118
  MIRRORMOVE="copy", -- 119
  SELFDESTRUCT="explode", -- 120
  EGGBOMB="egg", -- 121
  LICK="night", -- 122
  SMOG="toxic", -- 123
  SLUDGE="toxic", -- 124
  BONECLUB="bonemerang", -- 125
  FIREBLAST="fireblast", -- 126
  WATERFALL="waterfall", -- 127
  CLAMP="trap", -- 128
  SWIFT="swift", -- 129
  SKULLBASH="body", -- 130
  SPIKECANNON="multi", -- 131
  CONSTRICT="trap", -- 132
  AMNESIA="statup", -- 133
  KINESIS="statdown", -- 134
  SOFTBOILED="recover", -- 135
  HIJUMPKICK="kick", -- 136
  GLARE="focus", -- 137
  DREAMEATER="dream", -- 138
  POISONGAS="toxic", -- 139
  BARRAGE="multi", -- 140
  LEECHLIFE="drain", -- 141
  LOVELYKISS="kiss", -- 142
  SKYATTACK="dive", -- 143
  TRANSFORM="transform", -- 144
  BUBBLE="bubble", -- 145
  DIZZYPUNCH="punch", -- 146
  SPORE="powder", -- 147
  FLASH="statdown", -- 148
  PSYWAVE="psybeam", -- 149
  SPLASH="splash", -- 150
  ACIDARMOR="statup", -- 151
  CRABHAMMER="waterfall", -- 152
  EXPLOSION="explode", -- 153
  FURYSWIPES="multi", -- 154
  BONEMERANG="bonemerang", -- 155
  REST="recover", -- 156
  ROCKSLIDE="rocks", -- 157
  HYPERFANG="bite", -- 158
  SHARPEN="statup", -- 159
  CONVERSION="conversion", -- 160
  TRIATTACK="triattack", -- 161
  SUPERFANG="bite", -- 162
  SLASH="slash", -- 163
  SUBSTITUTE="substitute", -- 164
  STRUGGLE="body", -- 165
  SKETCH="copy", -- 166
  TRIPLEKICK="kick", -- 167
  THIEF="steal", -- 168
  SPIDERWEB="web", -- 169
  MINDREADER="focus", -- 170
  NIGHTMARE="cursefx", -- 171
  FLAMEWHEEL="flamethrower", -- 172
  SNORE="sound", -- 173
  CURSE="cursefx", -- 174
  FLAIL="body", -- 175
  CONVERSION2="conversion", -- 176
  AEROBLAST="aeroblast", -- 177
  COTTONSPORE="powder", -- 178
  REVERSAL="body", -- 179
  SPITE="cursefx", -- 180
  POWDERSNOW="blizzard", -- 181
  PROTECT="screen", -- 182
  MACHPUNCH="punch", -- 183
  SCARYFACE="statdown", -- 184
  FAINTATTACK="dash", -- 185
  SWEETKISS="kiss", -- 186
  BELLYDRUM="bellydrum", -- 187
  SLUDGEBOMB="sludge", -- 188
  MUDSLAP="sand", -- 189
  OCTAZOOKA="watergun", -- 190
  SPIKES="spikes", -- 191
  ZAPCANNON="thunder", -- 192
  FORESIGHT="focus", -- 193
  DESTINYBOND="cursefx", -- 194
  PERISHSONG="sound", -- 195
  ICYWIND="blizzard", -- 196
  DETECT="screen", -- 197
  BONERUSH="bonemerang", -- 198
  LOCKON="focus", -- 199
  OUTRAGE="rage", -- 200
  SANDSTORM="weather", -- 201
  GIGADRAIN="drain", -- 202
  ENDURE="screen", -- 203
  CHARM="statdown", -- 204
  ROLLOUT="rocks", -- 205
  FALSESWIPE="slash", -- 206
  SWAGGER="confuse", -- 207
  MILKDRINK="recover", -- 208
  SPARK="thunderbolt", -- 209
  FURYCUTTER="windslash", -- 210
  STEELWING="windslash", -- 211
  MEANLOOK="web", -- 212
  ATTRACT="kiss", -- 213
  SLEEPTALK="copy", -- 214
  HEALBELL="healbell", -- 215
  RETURN="body", -- 216
  PRESENT="present", -- 217
  FRUSTRATION="body", -- 218
  SAFEGUARD="screen", -- 219
  PAINSPLIT="painsplit", -- 220
  SACREDFIRE="sacredfire", -- 221
  MAGNITUDE="magnitude", -- 222
  DYNAMICPUNCH="punch", -- 223
  MEGAHORN="horn", -- 224
  DRAGONBREATH="dragon", -- 225
  BATONPASS="baton", -- 226
  ENCORE="copy", -- 227
  PURSUIT="pursuit", -- 228
  RAPIDSPIN="spin", -- 229
  SWEETSCENT="statdown", -- 230
  IRONTAIL="body", -- 231
  METALCLAW="slash", -- 232
  VITALTHROW="body", -- 233
  MORNINGSUN="recover", -- 234
  SYNTHESIS="recover", -- 235
  MOONLIGHT="recover", -- 236
  HIDDENPOWER="hiddenpower", -- 237
  CROSSCHOP="punch", -- 238
  TWISTER="tornado", -- 239
  RAINDANCE="weather", -- 240
  SUNNYDAY="weather", -- 241
  CRUNCH="body", -- 242
  MIRRORCOAT="counter", -- 243
  PSYCHUP="statup", -- 244
  EXTREMESPEED="dash", -- 245
  ANCIENTPOWER="rocks", -- 246
  SHADOWBALL="night", -- 247
  FUTURESIGHT="future", -- 248
  ROCKSMASH="punch", -- 249
  WHIRLPOOL="surf", -- 250
  BEATUP="multi", -- 251
}

local GEN2_REVIEWED_COUNT = 0
local GEN2_REVIEWED_PROFILE_COUNT = 0
local reviewedProfiles = {}
for move, route in pairs(GEN2_REVIEWED_ROUTE) do
  SPECIAL[move] = route
  GEN2_REVIEWED_COUNT = GEN2_REVIEWED_COUNT + 1
  if not reviewedProfiles[route] then
    reviewedProfiles[route] = true
    GEN2_REVIEWED_PROFILE_COUNT = GEN2_REVIEWED_PROFILE_COUNT + 1
  end
end

local FAMILY = {
  FIRE="fire", WATER="water", ELECTRIC="electric", ICE="ice",
  PSYCHIC="psychic", POISON="poison", GRASS="grass",
  NORMAL="impact", FIGHTING="impact", GROUND="ground", ROCK="rock",
  BUG="bug", GHOST="ghost", DRAGON="dragon", FLYING="wind",
  -- Gen 2 introduces Dark and Steel. Dark borrows the shadow family; Steel
  -- borrows the heavy rock/impact family so unknown Gen 2 moves still render.
  DARK="ghost", STEEL="rock",
}

local function phaseFor(battle, special)
  local duration = special and 52 or 42
  local f = tonumber(battle and battle.frame) or 0
  return (f % duration) / math.max(1,duration-1)
end

local function points()
  local arena, battle = live.arena, live.battle
  if not (arena and battle and arena.player and arena.enemy) then return nil end
  local playerAtk = battle.animAttackerIsPlayer and true or false
  local attackerSide = playerAtk and "player" or "enemy"
  local targetSide = playerAtk and "enemy" or "player"
  local attackerCell = arena[attackerSide]
  local targetCell = arena[targetSide]

  local attackerPoint, attackerProfile
  local targetPoint, targetProfile
  if type(Stadium.effectAnchor) == "function" then
    local okA, pointA, profileA = pcall(Stadium.effectAnchor,
      attackerSide, "emitter")
    if okA then attackerPoint, attackerProfile = pointA, profileA end
    local okB, pointB, profileB = pcall(Stadium.effectAnchor,
      targetSide, "body")
    if okB then targetPoint, targetProfile = pointB, profileB end
  end

  if type(attackerProfile) ~= "table" then
    attackerProfile = BattleEffectAnchors.profile(attackerCell[1],
      attackerCell[2], live.groundY or 0,
      attackerSide == "player" and 17 or 20, nil, 1, "fx-fallback")
  end
  if type(targetProfile) ~= "table" then
    targetProfile = BattleEffectAnchors.profile(targetCell[1], targetCell[2],
      live.groundY or 0, targetSide == "player" and 17 or 20,
      nil, 1, "fx-fallback")
  end
  attackerPoint = attackerPoint
    or BattleEffectAnchors.point(attackerProfile, "emitter")
  targetPoint = targetPoint or BattleEffectAnchors.point(targetProfile, "body")
  live.attackerProfile, live.targetProfile = attackerProfile, targetProfile
  return attackerPoint, targetPoint, attackerProfile, targetProfile
end

local function yawAt(x,z)
  local eye = Voxel3D.eye
  if type(BattleBillboard.yawToward)=="function" then
    return BattleBillboard.yawToward(x,z,eye)
  end
  if eye then return math.atan2(eye[1]-x, eye[3]-z) end
  return 0
end

local function cardMatrix(x,y,z,w,h,yaw,roll)
  local m = Mat4.mul(Mat4.translate(x,y,z), Mat4.rotateY(yaw or yawAt(x,z)))
  -- BattleBillboard's unit card is x=-.5..+.5, y=0..1. Center it vertically.
  m = Mat4.mul(m, Mat4.translate(0,-h*0.5,0))
  if roll and Mat4.rotateZ then m = Mat4.mul(m, Mat4.rotateZ(roll)) end
  return Mat4.mul(m, Mat4.scale(w,h,1))
end

local function drawCard(texture,x,y,z,w,h,pull,yaw,roll)
  if not texture then return end
  local m=cardMatrix(x,y,z,w,h,yaw,roll)
  Voxel3D.draw(BattleBillboard.mesh(), texture, m, pull or 0)
  live.drawSerial = (tonumber(live.drawSerial) or 0) + 1
end

local function drawCross(texture,x,y,z,w,h,pull,spin)
  local y0=yawAt(x,z) + (spin or 0)
  drawCard(texture,x,y,z,w,h,pull,y0)
  drawCard(texture,x,y,z,w,h,pull,y0+PI/2)
end

local function along(a,b,t,lift)
  local x=lerp(a[1],b[1],t); local y=lerp(a[2],b[2],t)+(lift or 0); local z=lerp(a[3],b[3],t)
  return x,y,z
end

local function projectileTrail(texture,a,b,phase,pull,size,count,arc,spin)
  count=count or 7
  for i=0,count-1 do
    local lag=i*0.055
    local t=clamp(phase*1.22-lag,0,1)
    if t>0 and t<1 then
      local x,y,z=along(a,b,t, math.sin(t*PI)*(arc or 0))
      local fade=1-i/count
      drawCross(texture,x,y,z,size*fade,size*fade,pull,(spin or 0)+phase*TAU+i*.7)
    end
  end
end

local function beam(texture,a,b,phase,pull,width)
  local reach=clamp((phase-0.18)/0.38,0,1)
  if reach<=0 then return end
  local segs=16
  for i=1,segs do
    local t=(i/segs)*reach
    local x,y,z=along(a,b,t, math.sin(t*PI)*0.7)
    local pulse=0.82+0.18*math.sin(phase*TAU*6+i)
    drawCross(texture,x,y,z,width*pulse,width*pulse,pull,phase*2+i*.31)
  end
end

local function targetBurst(texture,b,phase,pull,scale)
  local env=clamp(1-math.abs(phase-.68)/.22,0,1)
  if env<=0 then return end
  for i=1,8 do
    local a=i*TAU/8 + phase*2
    local r=(1-env)*5 + 1
    local x=b[1]+math.cos(a)*r; local z=b[3]+math.sin(a)*r; local y=b[2]+math.sin(a*2)*2
    drawCross(texture,x,y,z,(scale or 3)*(0.5+env),(scale or 3)*(0.5+env),pull,a)
  end
end

local function orbitCloud(texture,c,phase,pull,count,radius,size,rise)
  for i=1,(count or 10) do
    local ang=i*2.399 + phase*TAU*1.7
    local r=(radius or 5)*(0.45 + (i%5)/7)
    local y=(c[2] or 0) + ((i%4)-1.5)*(rise or 1.5) + math.sin(ang*1.7)*1.2
    drawCross(texture,c[1]+math.cos(ang)*r,y,c[3]+math.sin(ang)*r,size or 2.6,size or 2.6,pull,ang)
  end
end

local function groundRing(texture,c,phase,pull,count,radius,size)
  local grow=clamp(phase*1.5,0,1)
  for i=1,(count or 12) do
    local ang=i*TAU/(count or 12)+phase*1.2
    local r=(radius or 8)*grow
    drawCross(texture,c[1]+math.cos(ang)*r,(live.groundY or 0)+1.2,c[3]+math.sin(ang)*r,size or 2.4,size or 2.0,pull,ang)
  end
end

-- True world-space lightning: a jagged 3D trunk plus short side branches.
-- This stays entirely in the Phase 5 billboard layer and never touches the
-- Stadium model/summon path.
local function lightningBolt(a,b,phase,pull,width,seed,branches)
  local segs=18
  local wobble=(1-clamp(phase,0,1))*0.35 + 0.65
  local pts={}
  for i=0,segs do
    local t=i/segs
    local x,y,z=along(a,b,t, math.sin(t*PI)*0.8)
    if i>0 and i<segs then
      local k=(seed or 1)*11.731 + i*19.173 + math.floor(phase*22)*7.17
      local j1=math.sin(k*1.37)*1.55*wobble
      local j2=math.cos(k*1.91)*1.55*wobble
      x=x+j1; z=z+j2; y=y+math.sin(k*.73)*1.1*wobble
    end
    pts[#pts+1]={x,y,z}
  end
  for i=1,#pts do
    local q=pts[i]
    local pulse=0.78+0.22*math.sin(phase*TAU*12+i*1.7)
    drawCross(tex.electric,q[1],q[2],q[3],width*pulse,width*1.45*pulse,pull,phase*8+i*.41)
  end
  local n=branches or 5
  for j=1,n do
    local idx=2+((j*3 + (seed or 0)) % math.max(2,segs-2))
    local q=pts[idx]
    local ang=j*2.399 + phase*5 + (seed or 0)
    local len=2.2+(j%3)*1.4
    local tip={q[1]+math.cos(ang)*len, q[2]+((j%2==0) and 1.4 or -0.8), q[3]+math.sin(ang)*len}
    for k=1,4 do
      local t=k/4
      local x,y,z=along(q,tip,t,0)
      drawCross(tex.electric,x,y,z,width*.62,width*.92,pull,ang+k*.3)
    end
  end
end

-- 3D tornado funnel assembled from many world-space wind cards. Each level
-- spins independently and widens toward the top, making the funnel retain its
-- volume when Dramatic Shape's battle camera rotates.
local function tornadoFx(center,phase,pull,height,baseRadius,topRadius,strength)
  height=height or 20
  baseRadius=baseRadius or 1.8
  topRadius=topRadius or 8.0
  strength=strength or 1
  -- Big, high-contrast stacked rings.  This intentionally uses more visible
  -- geometry than v0.1.29 so the funnel reads clearly on a phone screen and
  -- remains visible from every Dramatic Shape camera angle.
  local levels=12
  local slices=7
  local ground=(live.groundY or 0)
  for level=0,levels-1 do
    local v=level/(levels-1)
    local y=ground+1.2+v*height
    local radius=lerp(baseRadius,topRadius,v)
      *(0.94+0.10*math.sin(phase*TAU*4+level*.65))
    for i=1,slices do
      local ang=i*TAU/slices + phase*TAU*(2.8+v*1.1) + level*.52
      local x=center[1]+math.cos(ang)*radius
      local z=center[3]+math.sin(ang)*radius
      local size=(2.1+v*3.5)*strength
      drawCross(tex.wind,x,y,z,size*2.15,size*0.72,pull,ang+PI*.5)
    end
  end
  -- Dense inner column so the tornado cannot disappear when viewed edge-on.
  for i=1,18 do
    local v=(i-1)/17
    local y=ground+1.3+v*height
    local ang=phase*TAU*3.6+i*1.73
    local r=0.65+v*2.0
    drawCross(tex.wind,center[1]+math.cos(ang)*r,y,center[3]+math.sin(ang)*r,
      (2.0+v*2.2)*strength,(1.1+v*.8)*strength,pull,ang)
  end
  -- Broad base dust/wind skirt anchors it visibly to the battle floor.
  for i=1,16 do
    local ang=i*TAU/16-phase*TAU*2.4
    local r=2.5+(i%5)*1.15
    drawCross(tex.wind,center[1]+math.cos(ang)*r,ground+1.0+(i%3)*.3,
      center[3]+math.sin(ang)*r,3.4*strength,1.25*strength,pull,ang)
  end
end

local function windSlash(a,b,phase,pull,strength)
  for i=0,7 do
    local t=clamp(phase*1.35-i*.045,0,1)
    if t>0 and t<1 then
      local x,y,z=along(a,b,t,math.sin(t*PI)*2.3)
      local ang=phase*TAU*4+i*.8
      drawCross(tex.wind,x,y,z,4.2*strength,1.5*strength,pull,ang)
    end
  end
end

local function drainStream(a,b,phase,pull)
  for i=0,9 do
    local t=clamp(phase*1.15-i*.045,0,1)
    if t>0 and t<1 then
      -- reverse travel: target energy flows back toward attacker
      local x,y,z=along(b,a,t,math.sin(t*PI)*3.0)
      drawCross(tex.leaf,x,y,z,2.0,2.8,pull,phase*4+i*.4)
    end
  end
end

-- A rising helix around the victim. Unlike Flamethrower's straight stream,
-- Fire Spin remains rooted at the target and closes into a hot central cage.
local function fireSpinFx(b,profile,phase,pull,strength)
  local env=math.sin(clamp(phase,0,1)*PI)
  local cage=BattleEffectAnchors.cage(profile)
  for level=0,10 do
    local v=level/10
    local radius=(cage.radius*(0.58+v*.42))*(0.72+env*.28)
    for side=0,1 do
      local ang=phase*TAU*3.8+v*TAU*2.3+side*PI
      drawCross(tex.orb,b[1]+math.cos(ang)*radius,cage.base+v*cage.span,
        b[3]+math.sin(ang)*radius,(2.3+v*1.8)*strength,
        (2.0+v*1.5)*strength,pull,ang)
    end
  end
  groundRing(tex.orb,b,phase,pull,14,7.2,2.4*strength)
  if phase>.48 then targetBurst(tex.orb,b,phase,pull,3.2*strength) end
end

-- Waterfall first drives a low surge across the arena, then carries the hit
-- upward in a foaming column instead of reading as another Water Gun.
local function waterfallFx(a,b,phase,pull,strength)
  for i=0,12 do
    local t=clamp(phase*1.42-i*.045,0,1)
    if t>0 and t<1 then
      local x,y,z=along(a,b,t,math.sin(t*PI)*1.4)
      drawCross(tex.water,x,(live.groundY or 0)+1.6+math.sin(i+phase*8)*.8,z,
        4.1*strength,2.4*strength,pull,t*3+i)
    end
  end
  if phase>.38 then
    local rise=clamp((phase-.38)/.45,0,1)
    for i=0,9 do
      local v=i/9
      local ang=i*2.399+phase*TAU*2
      local r=1.2+(i%3)*1.1
      drawCross(tex.water,b[1]+math.cos(ang)*r,
        (live.groundY or 0)+2+v*17*rise,b[3]+math.sin(ang)*r,
        (3.2-v*.8)*strength,(3.8-v*.6)*strength,pull,ang)
    end
    targetBurst(tex.water,b,phase,pull,3.4*strength)
  end
end

local function pinMissileFx(a,b,phase,pull,strength)
  for i=1,11 do
    local t=clamp(phase*1.48-(i-1)*.047,0,1)
    if t>0 and t<1 then
      local x,y,z=along(a,b,t,math.sin(t*PI)*(2+(i%3)))
      local spread=(i%3-1)*.9*(1-t)
      drawCross(tex.needle,x,y+spread,z-spread,2.8*strength,
        1.15*strength,pull,t*7+i*.63)
    end
  end
  if phase>.52 then targetBurst(tex.ring,b,phase,pull,2.5*strength) end
end

local function bonemerangFx(a,b,phase,pull,strength)
  local q=clamp(phase*2,0,2)
  local outbound=q<=1
  local t=outbound and q or (2-q)
  local from,to=outbound and a or b,outbound and b or a
  for i=0,3 do
    local ghost=clamp(t-i*.035,0,1)
    if ghost>0 and ghost<1 then
      local x,y,z=along(from,to,ghost,math.sin(ghost*PI)*7.0)
      local s=(3.6-i*.45)*strength
      drawCross(tex.bone,x,y,z,s,s,pull,phase*TAU*7-i*.4)
    end
  end
  if math.abs(phase-.5)<.18 then targetBurst(tex.dust,b,phase,pull,3.0*strength) end
end

local function triAttackFx(a,b,phase,pull,strength)
  local textures={tex.orb,tex.ice,tex.electric}
  for lane=1,3 do
    for i=0,7 do
      local t=clamp(phase*1.35-i*.055,0,1)
      if t>0 and t<1 then
        local x,y,z=along(a,b,t,math.sin(t*PI)*2.0)
        local ang=phase*TAU*2+lane*TAU/3+t*TAU
        local r=1.2+math.sin(t*PI)*2.0
        drawCross(textures[lane],x+math.cos(ang)*r,y+math.sin(ang*1.3)*r,
          z+math.sin(ang)*r,2.2*strength,2.2*strength,pull,ang)
      end
    end
  end
  if phase>.55 then
    targetBurst(tex.orb,b,phase,pull,2.8*strength)
    targetBurst(tex.ice,b,phase,pull,2.6*strength)
    targetBurst(tex.electric,b,phase,pull,2.4*strength)
  end
end

local function presentFx(a,b,phase,pull,strength)
  local t=clamp(phase*1.22,0,1)
  if t<1 then
    local x,y,z=along(a,b,t,math.sin(t*PI)*9.0)
    drawCross(tex.present,x,y,z,4.5*strength,4.5*strength,pull,phase*TAU*2)
  end
  if phase>.58 then
    -- Present may damage or heal in Crystal; a mystery burst of hearts and
    -- sparks communicates both outcomes without predicting battle logic.
    targetBurst(tex.spark,b,phase,pull,3.4*strength)
    orbitCloud(tex.heart,b,phase,pull,6,4.2,1.8*strength,2.2)
  end
end

local function magnitudeFx(a,b,phase,pull,strength)
  groundRing(tex.dust,a,phase,pull,12,5.5,2.1*strength)
  for wave=1,4 do
    local t=clamp(phase*1.35-(wave-1)*.11,0,1)
    if t>0 then
      local x,y,z=along(a,b,t,0)
      groundRing(tex.ring,{x,y,z},t,pull,8,3.2+wave,1.5*strength)
      for i=1,5 do
        local ang=i*TAU/5+wave
        drawCross(tex.dust,x+math.cos(ang)*(1+wave),
          (live.groundY or 0)+1.1,z+math.sin(ang)*(1+wave),
          2.2*strength,1.6*strength,pull,ang)
      end
    end
  end
  if phase>.48 then targetBurst(tex.dust,b,phase,pull,4.0*strength) end
end

local function pursuitFx(a,b,phase,pull,strength)
  projectileTrail(tex.shadow,a,b,clamp(phase*1.35,0,1),pull,
    3.7*strength,12,1.4,phase*TAU*4)
  if phase>.42 then
    orbitCloud(tex.shadow,b,phase,pull,8,4.6,2.8*strength,1.7)
    targetBurst(tex.ring,b,phase,pull,3.2*strength)
  end
end

local function swordsDanceFx(a,phase,pull,strength)
  local env=math.sin(clamp(phase,0,1)*PI)
  for i=1,6 do
    local v=(i-1)/5
    local ang=phase*TAU*2.4+i*TAU/6
    local radius=4.5+v*2.0
    drawCross(tex.blade,a[1]+math.cos(ang)*radius,a[2]-3+v*13,
      a[3]+math.sin(ang)*radius,(3.0+env)*strength,
      (4.6+env)*strength,pull,ang+phase*TAU)
  end
  groundRing(tex.spark,a,phase,pull,10,6.2,1.8*strength)
end

local function recoverFx(a,phase,pull,strength)
  local env=math.sin(clamp(phase,0,1)*PI)
  groundRing(tex.ring,a,phase,pull,12,7.0,2.0*strength)
  for i=1,12 do
    local ang=i*2.399+phase*TAU*1.5
    local rise=(phase*18+i*2.3)%19
    local r=2.2+(i%4)*1.1
    local texture=(i%3==0) and tex.heart or tex.spark
    drawCross(texture,a[1]+math.cos(ang)*r,a[2]-7+rise,
      a[3]+math.sin(ang)*r,(1.4+env*.8)*strength,
      (1.4+env*.8)*strength,pull,ang)
  end
  if phase>.45 then orbitCloud(tex.ring,a,phase,pull,6,3.2,2.2,1.3) end
end

local function textureForFamily(family)
  if family=="fire" then return tex.orb
  elseif family=="water" then return tex.water
  elseif family=="electric" then return tex.electric
  elseif family=="ice" then return tex.ice
  elseif family=="psychic" then return tex.psychic
  elseif family=="poison" or family=="ghost" then return tex.poison
  elseif family=="grass" or family=="bug" then return tex.leaf
  elseif family=="wind" then return tex.wind
  elseif family=="ground" or family=="rock" then return tex.dust end
  return tex.ring
end

-- Shared semantic choreographies for the complete 251-move catalog. These are
-- intentionally composed from the same small world-space vocabulary as the
-- signature effects above: similar moves read as a family, while their live
-- type, strength, origin and target keep the presentation battle-correct.
local function semanticFx(route,a,b,phase,pull,strength,family)
  local typed=textureForFamily(family)
  if route=="punch" then
    local t=clamp(phase*1.42,0,1)
    local x,y,z=along(a,b,t,math.sin(t*PI)*1.8)
    drawCross(typed,x,y,z,3.3*strength,3.3*strength,pull,phase*TAU*2)
    targetBurst(tex.spark,b,phase,pull,3.7*strength)
  elseif route=="multi" then
    for i=1,7 do
      local q=clamp(phase*1.55-(i-1)*.075,0,1)
      local ang=i*2.399+phase*5
      drawCross(typed,b[1]+math.cos(ang)*(3+i%3),b[2]+math.sin(ang*1.7)*3,
        b[3]+math.sin(ang)*(3+i%3),2.3*strength,2.3*strength,pull,ang+q)
    end
    targetBurst(tex.ring,b,phase,pull,3.0*strength)
  elseif route=="slash" then
    windSlash(a,b,phase,pull,.75*strength)
    for i=1,3 do
      local q=clamp(phase*1.45-(i-1)*.11,0,1)
      local x,y,z=along(a,b,q,math.sin(q*PI)*2)
      drawCross(tex.blade,x,y,z,3.4*strength,5.0*strength,pull,
        phase*TAU*3+i*PI/3)
    end
  elseif route=="bite" then
    local close=math.sin(clamp(phase,0,1)*PI)
    drawCross(tex.blade,b[1],b[2]+7-close*5,b[3],3.6*strength,
      5.8*strength,pull,PI)
    drawCross(tex.blade,b[1],b[2]-7+close*5,b[3],3.6*strength,
      5.8*strength,pull,0)
    targetBurst(tex.shadow,b,phase,pull,3.0*strength)
  elseif route=="drill" then
    for i=0,8 do
      local q=clamp(phase*1.35-i*.055,0,1)
      local x,y,z=along(a,b,q,math.sin(q*PI)*2.2)
      local ang=q*TAU*4+i*.7
      drawCross(tex.needle,x+math.cos(ang)*1.5,y,z+math.sin(ang)*1.5,
        3.4*strength,1.5*strength,pull,ang)
    end
    targetBurst(tex.dust,b,phase,pull,3.6*strength)
  elseif route=="dive" then
    if phase<.35 then orbitCloud(tex.shadow,a,phase,pull,7,4.2,2.3,2.0) end
    windSlash(a,b,clamp((phase-.22)/.78,0,1),pull,1.25*strength)
    targetBurst(tex.wind,b,phase,pull,4.0*strength)
  elseif route=="trap" then
    for i=1,10 do
      local ang=i*TAU/10+phase*TAU*2.5
      local r=4.2+(i%2)*1.4
      drawCross(tex.bone,b[1]+math.cos(ang)*r,b[2]+(i%4-1.5)*2.2,
        b[3]+math.sin(ang)*r,2.2*strength,2.2*strength,pull,ang)
    end
    groundRing(tex.ring,b,phase,pull,10,5.8,1.8*strength)
  elseif route=="kick" then
    local sweep=phase*PI*1.4-.7
    drawCross(tex.ring,b[1]+math.cos(sweep)*5,b[2]+math.sin(sweep)*4,b[3],
      4.8*strength,2.0*strength,pull,sweep)
    targetBurst(tex.dust,b,phase,pull,3.8*strength)
  elseif route=="sand" then
    projectileTrail(tex.dust,a,b,phase,pull,2.7*strength,10,2.2,phase*6)
    orbitCloud(tex.dust,b,phase,pull,14,6.0,2.4*strength,2.5)
  elseif route=="horn" then
    projectileTrail(tex.needle,a,b,phase,pull,3.2*strength,6,1.2,phase*2)
    targetBurst(tex.ring,b,phase,pull,4.2*strength)
  elseif route=="statdown" then
    orbitCloud(tex.shadow,b,-phase,pull,10,5.2,2.1*strength,2.6)
    for i=1,5 do
      local y=b[2]+8-phase*15+i
      drawCross(tex.poison,b[1]+math.cos(i*2.1)*3,y,b[3]+math.sin(i*2.1)*3,
        1.7*strength,1.7*strength,pull,i)
    end
  elseif route=="statup" then
    orbitCloud(tex.spark,a,phase,pull,10,4.8,2.0*strength,2.8)
    groundRing(tex.ring,a,phase,pull,9,5.8,1.7*strength)
  elseif route=="sound" then
    projectileTrail(tex.note,a,b,phase,pull,2.6*strength,8,4.5,phase*4)
    orbitCloud(tex.ring,b,phase,pull,8,5.3,2.1*strength,2.0)
  elseif route=="mist" then
    orbitCloud(tex.bubble,b,phase,pull,16,7.0,2.8*strength,3.2)
    orbitCloud(tex.ice,b,-phase,pull,8,5.0,1.8*strength,2.0)
  elseif route=="counter" then
    if phase<.48 then orbitCloud(tex.shield,a,phase,pull,8,4.5,2.7,2.0)
    else projectileTrail(tex.ring,a,b,(phase-.48)/.52,pull,3.3*strength,8,2.0) end
    targetBurst(tex.ring,b,phase,pull,3.7*strength)
  elseif route=="web" then
    projectileTrail(tex.web,a,b,phase,pull,2.5*strength,5,3.0,phase*2)
    drawCross(tex.web,b[1],b[2],b[3],7.2*strength,7.2*strength,pull,phase)
  elseif route=="toxic" then
    projectileTrail(tex.poison,a,b,phase,pull,2.8*strength,7,3.8,phase*3)
    orbitCloud(tex.poison,b,phase,pull,14,6.2,2.5*strength,3.0)
  elseif route=="sleep" then
    for i=1,10 do
      local ang=i*2.399; local rise=(phase*18+i*2)%18
      drawCross(i%3==0 and tex.note or tex.bubble,b[1]+math.cos(ang)*3,
        b[2]-6+rise,b[3]+math.sin(ang)*3,2.0*strength,2.0*strength,pull,ang)
    end
  elseif route=="dash" then
    for i=0,9 do
      local q=clamp(phase*1.6-i*.045,0,1)
      local x,y,z=along(a,b,q,math.sin(q*PI)*.8)
      drawCross(tex.shadow,x,y,z,(3.7-i*.18)*strength,2.0*strength,pull,q*3)
    end
    targetBurst(tex.spark,b,phase,pull,3.8*strength)
  elseif route=="rage" then
    orbitCloud(tex.orb,a,phase*2,pull,12,5.0,2.4*strength,2.4)
    targetBurst(tex.ring,b,phase,pull,4.4*strength)
    groundRing(tex.dust,b,phase,pull,10,6.0,2.1*strength)
  elseif route=="vanish" then
    local shrink=1-clamp(phase*1.3,0,1)
    for i=1,9 do
      local ang=i*TAU/9+phase*4; local r=(2+i*.45)*shrink
      drawCross(tex.shadow,a[1]+math.cos(ang)*r,a[2]+math.sin(ang*2)*r*.4,
        a[3]+math.sin(ang)*r,2.5*strength,2.5*strength,pull,ang)
    end
  elseif route=="copy" then
    projectileTrail(tex.psychic,b,a,phase,pull,2.5*strength,8,4.0,phase*4)
    orbitCloud(tex.ring,a,phase,pull,7,4.2,2.1*strength,1.8)
  elseif route=="smoke" then
    orbitCloud(tex.dust,b,phase,pull,18,7.0,3.2*strength,4.0)
    orbitCloud(tex.shadow,b,-phase,pull,9,4.5,2.6*strength,2.5)
  elseif route=="confuse" then
    orbitCloud(tex.psychic,b,phase*1.8,pull,12,5.4,2.3*strength,2.3)
    orbitCloud(tex.ring,b,-phase,pull,6,3.5,1.8*strength,1.2)
  elseif route=="screen" then
    for i=1,8 do
      local ang=i*TAU/8+phase*.8
      drawCross(tex.shield,a[1]+math.cos(ang)*5,a[2]+math.sin(ang*2)*3,
        a[3]+math.sin(ang)*5,3.5*strength,4.2*strength,pull,ang)
    end
  elseif route=="focus" then
    for i=1,6 do
      local r=2+i*1.25+math.sin(phase*TAU+i)
      drawCross(tex.ring,b[1]+math.cos(i*TAU/6)*r,b[2],
        b[3]+math.sin(i*TAU/6)*r,2.0*strength,2.0*strength,pull,i)
    end
    projectileTrail(tex.spark,a,b,phase,pull,1.5*strength,4,1.0)
  elseif route=="coin" then
    projectileTrail(tex.coin,a,b,phase,pull,2.7*strength,8,6.0,phase*6)
    orbitCloud(tex.coin,b,phase,pull,7,4.5,2.2*strength,2.6)
  elseif route=="egg" then
    local t=clamp(phase*1.3,0,1); local x,y,z=along(a,b,t,math.sin(t*PI)*8)
    drawCross(tex.present,x,y,z,4.2*strength,4.2*strength,pull,phase*TAU*3)
    targetBurst(tex.ring,b,phase,pull,4.4*strength)
  elseif route=="dream" then
    projectileTrail(tex.shadow,b,a,phase,pull,3.0*strength,10,5.0,phase*3)
    orbitCloud(tex.psychic,a,phase,pull,8,4.0,2.2*strength,1.8)
  elseif route=="kiss" then
    projectileTrail(tex.heart,a,b,phase,pull,2.7*strength,7,5.5,phase*2)
    orbitCloud(tex.heart,b,phase,pull,8,4.5,2.1*strength,2.0)
  elseif route=="transform" then
    orbitCloud(tex.psychic,a,phase*1.5,pull,12,5.5,2.5*strength,2.8)
    groundRing(tex.ring,a,phase,pull,12,7.0,2.1*strength)
  elseif route=="splash" then
    groundRing(tex.water,a,phase,pull,14,7.5,2.8*strength)
    orbitCloud(tex.bubble,a,phase,pull,10,4.5,2.2*strength,3.2)
  elseif route=="conversion" then
    orbitCloud(tex.orb,a,phase,pull,5,4.0,2.0*strength,1.4)
    orbitCloud(tex.ice,a,-phase,pull,5,5.2,2.0*strength,1.8)
    orbitCloud(tex.electric,a,phase*1.5,pull,5,6.2,1.8*strength,2.0)
  elseif route=="substitute" then
    orbitCloud(tex.shield,a,phase,pull,9,4.8,2.8*strength,2.1)
    drawCross(tex.shadow,a[1],a[2],a[3],7.5*strength,7.5*strength,pull,phase)
  elseif route=="steal" then
    projectileTrail(tex.shadow,b,a,phase,pull,3.0*strength,9,3.0,phase*4)
    orbitCloud(tex.coin,a,phase,pull,6,3.8,1.8*strength,1.7)
  elseif route=="cursefx" then
    beam(tex.shadow,a,b,phase,pull,1.5*strength)
    orbitCloud(tex.shadow,b,phase,pull,13,6.0,2.8*strength,3.0)
    groundRing(tex.poison,b,phase,pull,10,6.0,2.0*strength)
  elseif route=="bellydrum" then
    for i=1,12 do
      local ang=i*TAU/12+phase*TAU*2
      drawCross(i%3==0 and tex.note or tex.ring,a[1]+math.cos(ang)*5,
        a[2]+math.sin(ang*2)*2,a[3]+math.sin(ang)*5,
        2.4*strength,2.4*strength,pull,ang)
    end
    groundRing(tex.dust,a,phase,pull,12,7.0,2.2*strength)
  elseif route=="spikes" then
    for i=1,12 do
      local ang=i*TAU/12; local r=3+(i%4)*1.8
      drawCard(tex.spike,b[1]+math.cos(ang)*r,(live.groundY or 0)+.8,
        b[3]+math.sin(ang)*r,2.4*strength,4.5*strength,pull,ang)
    end
  elseif route=="healbell" then
    orbitCloud(tex.note,a,phase,pull,10,5.0,2.4*strength,3.0)
    orbitCloud(tex.heart,a,-phase,pull,8,4.0,2.0*strength,2.1)
    groundRing(tex.ring,a,phase,pull,12,7.5,2.0*strength)
  elseif route=="weather" then
    local weatherTex=family=="water" and tex.water
      or (family=="fire" and tex.spark or tex.dust)
    for i=1,20 do
      local ang=i*2.399+phase*4; local r=4+(i%7)*1.8
      drawCross(weatherTex,b[1]+math.cos(ang)*r,b[2]+(i%6-2)*3,
        b[3]+math.sin(ang)*r,2.5*strength,2.5*strength,pull,ang)
    end
    groundRing(tex.ring,b,phase,pull,14,10,2.1*strength)
  elseif route=="painsplit" then
    beam(tex.psychic,a,b,phase,pull,1.4*strength)
    beam(tex.shadow,b,a,phase,pull,1.4*strength)
    local x,y,z=along(a,b,.5,math.sin(phase*PI)*3)
    drawCross(tex.ring,x,y,z,5.0*strength,5.0*strength,pull,phase*TAU)
  elseif route=="baton" then
    local t=clamp(phase*1.25,0,1); local x,y,z=along(a,b,t,math.sin(t*PI)*6)
    drawCross(tex.baton,x,y,z,4.0*strength,4.0*strength,pull,phase*TAU*4)
    orbitCloud(tex.spark,b,phase,pull,7,4.0,1.8*strength,1.6)
  elseif route=="spin" then
    tornadoFx(a,phase,pull,9,1.0,4.5,.7*strength)
    projectileTrail(tex.wind,a,b,phase,pull,2.8*strength,7,2.0,phase*TAU*5)
    targetBurst(tex.dust,b,phase,pull,3.0*strength)
  elseif route=="future" then
    local gather=math.sin(clamp(phase,0,1)*PI)
    orbitCloud(tex.psychic,b,-phase*1.7,pull,14,7*(1-gather*.55),
      2.5*strength,3.0)
    targetBurst(tex.spark,b,phase,pull,4.0*strength)
  elseif route=="hiddenpower" then
    orbitCloud(tex.orb,a,phase,pull,6,4.0,1.8*strength,1.4)
    orbitCloud(tex.water,a,-phase,pull,6,5.0,1.8*strength,1.7)
    orbitCloud(tex.electric,a,phase*1.5,pull,6,6.0,1.7*strength,2.0)
    projectileTrail(typed,a,b,phase,pull,2.7*strength,7,3.0,phase*4)
    targetBurst(typed,b,phase,pull,3.4*strength)
  else
    return false
  end
  return true
end

local function drawWorldFx(pull)
  local battle=live.battle
  if not (battle and battle.animPlaying and battle.animName and live.arena) then return false end
  if not buildTextures() then return false end
  local def=moveDef(battle); if not def then return false end
  local name=moveName(battle,def)
  local special=SPECIAL[name]
  local family=FAMILY[moveType(def)]
  local movePower=power(def)
  -- v0.2.23 takes ownership of Gold's visible OBJ move layer while Stadium
  -- presentation is active, so EVERY move needs a world-space answer. Named
  -- status moves keep their dedicated effects; other zero-power moves get a
  -- restrained type-coloured aura instead of falling back to the old 2D OBJ
  -- sprites. Damaging unknowns get a generic impact below.
  local phase=phaseFor(battle,special)
  local a,b,attackerProfile,targetProfile=points(); if not a then return false end
  local strength=clamp(.8+movePower/220,.8,1.5)
  local p=(pull or 0)-0.15 -- a tiny camera-ward bias keeps translucent cards off terrain
  local drawBefore = tonumber(live.drawSerial) or 0

  if not special and movePower <= 0 then
    local aura = tex.ring
    if family=="fire" then aura=tex.orb
    elseif family=="water" then aura=tex.water
    elseif family=="electric" then aura=tex.electric
    elseif family=="ice" then aura=tex.ice
    elseif family=="psychic" then aura=tex.psychic
    elseif family=="poison" or family=="ghost" then aura=tex.poison
    elseif family=="grass" or family=="bug" then aura=tex.leaf
    elseif family=="wind" then aura=tex.wind
    elseif family=="ground" or family=="rock" then aura=tex.dust end
    orbitCloud(aura,b,phase,p,10,5,2.0,2.0)
    groundRing(tex.ring,b,phase,p,7,5,1.7)
    return (tonumber(live.drawSerial) or 0) > drawBefore
  end

  if special=="aeroblast" then
    -- Lugia: a compressed rotating air lance, followed by expanding pressure
    -- rings at impact.  Two counter-rotating helices keep it volumetric from
    -- the orbit camera instead of reading as one flat slash billboard.
    local reach=clamp((phase-.08)/.62,0,1)
    local segs=18
    for i=1,segs do
      local t=(i/segs)*reach
      if t>0 then
        local x,y,z=along(a,b,t,math.sin(t*PI)*1.3)
        local r=(1-t)*2.8 + .6
        local ang=t*TAU*3.5 + phase*TAU*5
        drawCross(tex.wind,x+math.cos(ang)*r,y+math.sin(ang*1.7)*r*.45,
          z+math.sin(ang)*r,3.8*strength,1.15*strength,p,ang)
        drawCross(tex.wind,x+math.cos(ang+PI)*r,y+math.sin((ang+PI)*1.7)*r*.45,
          z+math.sin(ang+PI)*r,3.1*strength,1.0*strength,p,ang+PI)
      end
    end
    if phase>.48 then
      targetBurst(tex.wind,b,phase,p,5.2*strength)
      groundRing(tex.ring,b,clamp((phase-.48)/.45,0,1),p,14,9.5,2.8)
    end
  elseif special=="sacredfire" then
    -- Ho-Oh: gather hot sparks around the user, then send a dense fire core
    -- wrapped in a rotating corona.  The final ring makes the hit feel larger
    -- than Flamethrower/Ember without copying Stadium textures.
    if phase<.28 then
      orbitCloud(tex.orb,a,phase,p,14,5.2,2.6,2.4)
      orbitCloud(tex.spark,a,phase,p,7,3.3,1.7,1.4)
    else
      projectileTrail(tex.orb,a,b,phase,p,4.8*strength,10,3.4,phase*TAU*2)
      beam(tex.orb,a,b,phase,p,1.35*strength)
      if phase>.5 then
        targetBurst(tex.orb,b,phase,p,5.8*strength)
        groundRing(tex.spark,b,clamp((phase-.5)/.42,0,1),p,16,8.5,2.5)
      end
    end
  elseif special=="beam" then
    if phase<.28 then
      for i=1,7 do
        local ang=i*TAU/7+phase*5; local r=4*(1-phase/.28)
        drawCross(tex.orb,a[1]+math.cos(ang)*r,a[2]+math.sin(ang*2),a[3]+math.sin(ang)*r,2.8,2.8,p,ang)
      end
    else beam(tex.orb,a,b,phase,p,2.3*strength); targetBurst(tex.ring,b,phase,p,3.2*strength) end
  elseif special=="solarbeam" then
    if phase<.34 then
      orbitCloud(tex.leaf,a,phase,p,10,5,2.3,1.4)
      orbitCloud(tex.spark,a,phase,p,6,3.5,1.6,1.0)
    else
      beam(tex.leaf,a,b,phase,p,2.5*strength); beam(tex.spark,a,b,phase,p,1.4*strength)
      targetBurst(tex.leaf,b,phase,p,3.8)
    end
  elseif special=="hydro" then
    beam(tex.water,a,b,phase,p,2.4*strength); projectileTrail(tex.water,a,b,phase,p,3.4,10,3.0); targetBurst(tex.water,b,phase,p,3.5)
  elseif special=="watergun" then
    projectileTrail(tex.water,a,b,phase,p,2.4*strength,9,1.2); targetBurst(tex.water,b,phase,p,2.4)
  elseif special=="bubble" then
    projectileTrail(tex.bubble,a,b,phase,p,3.1*strength,10,4.5,phase*2); targetBurst(tex.bubble,b,phase,p,3.0)
  elseif special=="fireblast" then
    projectileTrail(tex.orb,a,b,phase,p,4.2*strength,6,2.2,phase*4); targetBurst(tex.orb,b,phase,p,5.0*strength)
  elseif special=="flamethrower" then
    beam(tex.orb,a,b,phase,p,1.9*strength); projectileTrail(tex.orb,a,b,phase,p,3.0,12,2.0,phase*6); targetBurst(tex.orb,b,phase,p,3.5)
  elseif special=="ember" then
    projectileTrail(tex.orb,a,b,phase,p,2.1*strength,8,4.0,phase*5); targetBurst(tex.orb,b,phase,p,2.3)
  elseif special=="thunder" then
    local top={b[1],b[2]+30,b[3]}
    lightningBolt(top,b,phase,p,3.2*strength,7,7)
    targetBurst(tex.electric,b,phase,p,4.8)
  elseif special=="thunderbolt" then
    lightningBolt(a,b,phase,p,2.45*strength,13,6)
    orbitCloud(tex.electric,b,phase,p,9,4.3,2.6,2.0)
    targetBurst(tex.electric,b,phase,p,3.8)
  elseif special=="thunderwave" then
    -- Multiple thinner bolts curl around the target instead of a flat halo.
    for i=1,4 do
      local ang=i*TAU/4+phase*TAU*2
      local src={b[1]+math.cos(ang)*7,b[2]+4+math.sin(ang*2)*2,b[3]+math.sin(ang)*7}
      lightningBolt(src,b,phase,p,1.25,20+i,2)
    end
    orbitCloud(tex.electric,b,phase,p,10,5.0,2.1,2.0)
  elseif special=="tornado" then
    local travel=clamp((phase-.05)/.58,0,1)
    local cx,cy,cz=along(a,b,travel,0)
    tornadoFx({cx,cy,cz},phase,p,17,1.2,6.3,1.0*strength)
    if phase>.55 then targetBurst(tex.wind,b,phase,p,4.2*strength) end
  elseif special=="windslash" then
    windSlash(a,b,phase,p,strength)
    if phase>.5 then tornadoFx(b,phase,p,10,1.0,3.8,.72*strength) end
  elseif special=="surf" then
    for i=1,14 do
      local t=(i-1)/13; local x,y,z=along(a,b,t,0)
      local wave=math.sin(t*TAU-phase*TAU*2)*3 + 3
      drawCross(tex.water,x,(live.groundY or 0)+2+wave,z,5.5,5.5,p,t*2)
    end
  elseif special=="quake" then
    for i=1,18 do
      local ang=i*2.399+phase; local r=3+(i%6)*2.2
      drawCross(tex.dust,b[1]+math.cos(ang)*r,(live.groundY or 0)+1.2,b[3]+math.sin(ang)*r,3.2,2.2,p,ang)
    end
  elseif special=="dig" then
    groundRing(tex.dust,a,phase,p,12,7,2.8); groundRing(tex.dust,b,clamp(phase-.28,0,1),p,12,6,2.8)
  elseif special=="fissure" then
    groundRing(tex.dust,b,phase,p,18,12,3.1)
    for i=1,10 do
      local ang=i*2.399
      drawCross(tex.shadow,b[1]+math.cos(ang)*(2+i*.5),(live.groundY or 0)+.7,b[3]+math.sin(ang)*(2+i*.5),3.2,1.4,p,ang)
    end
  elseif special=="explode" then
    local env=math.sin(clamp(phase,0,1)*PI)
    for i=1,18 do
      local ang=i*2.399; local r=env*(3+(i%7)*2)
      drawCross(tex.orb,a[1]+math.cos(ang)*r,a[2]+math.sin(ang*1.7)*r*.5,a[3]+math.sin(ang)*r,4+env*5,4+env*5,p,ang)
    end
  elseif special=="icebeam" then
    beam(tex.ice,a,b,phase,p,2.6*strength); targetBurst(tex.ice,b,phase,p,4)
  elseif special=="aurora" then
    beam(tex.psychic,a,b,phase,p,1.9*strength); projectileTrail(tex.ice,a,b,phase,p,2.1,9,3.5,phase*3)
  elseif special=="blizzard" then
    for i=1,22 do
      local ang=i*2.399+phase*4; local r=3+(i%8)*1.8
      drawCard(tex.ice,b[1]+math.cos(ang)*r,b[2]+(i%5)*2-3,b[3]+math.sin(ang)*r,2.5,4,p,nil,ang)
    end
  elseif special=="psychic" then
    for i=1,7 do
      local ang=i*TAU/7+phase*3; local r=2+i*.8+math.sin(phase*TAU+i)*2
      drawCross(tex.psychic,b[1]+math.cos(ang)*r,b[2]+math.sin(ang*2)*2,b[3]+math.sin(ang)*r,3+i*.4,3+i*.4,p,ang)
    end
  elseif special=="psybeam" then
    projectileTrail(tex.psychic,a,b,phase,p,3.0,12,2.0,phase*8); beam(tex.spark,a,b,phase,p,1.2)
  elseif special=="night" then
    projectileTrail(tex.shadow,a,b,phase,p,3.4,8,4.0,phase*3); orbitCloud(tex.shadow,b,phase,p,9,5,3.0,2.5)
  elseif special=="dragon" then
    beam(tex.orb,a,b,phase,p,2.0*strength); orbitCloud(tex.psychic,b,phase,p,7,4.2,2.5,2.0)
  elseif special=="rocks" then
    for i=1,12 do
      local t=clamp(phase*1.4-i*.035,0,1)
      if t>0 then drawCross(tex.dust,b[1]+math.cos(i)*5,b[2]+12*(1-t),b[3]+math.sin(i)*5,3.4,3.4,p,i) end
    end
  elseif special=="swift" then
    projectileTrail(tex.spark,a,b,phase,p,2.6,9,4.0,phase*5)
  elseif special=="razorleaf" then
    projectileTrail(tex.leaf,a,b,phase,p,2.4*strength,12,5.0,phase*8); targetBurst(tex.leaf,b,phase,p,3.0)
  elseif special=="vine" then
    beam(tex.leaf,a,b,phase,p,1.3*strength); targetBurst(tex.leaf,b,phase,p,2.6)
  elseif special=="petals" then
    orbitCloud(tex.leaf,b,phase,p,18,8,2.5,3.0)
  elseif special=="drain" then
    drainStream(a,b,phase,p); orbitCloud(tex.leaf,a,phase,p,7,3.6,2.0,1.5)
  elseif special=="seed" then
    projectileTrail(tex.leaf,a,b,phase,p,2.0,5,5.0,phase*3); orbitCloud(tex.leaf,b,phase,p,8,4,2.0,1.0)
  elseif special=="powder" then
    orbitCloud(tex.poison,b,phase,p,16,7,2.5,4.0)
  elseif special=="sludge" then
    projectileTrail(tex.poison,a,b,phase,p,3.7*strength,8,6.0,phase*2); targetBurst(tex.poison,b,phase,p,4.0)
  elseif special=="seismic" then
    groundRing(tex.dust,b,phase,p,14,9,2.5); targetBurst(tex.ring,b,phase,p,4.2)
  elseif special=="body" then
    targetBurst(tex.ring,b,phase,p,4.6*strength); groundRing(tex.dust,b,phase,p,10,6,2.0)
  elseif special=="firespin" then
    fireSpinFx(b,targetProfile,phase,p,strength)
  elseif special=="waterfall" then
    waterfallFx(a,b,phase,p,strength)
  elseif special=="pinmissile" then
    pinMissileFx(a,b,phase,p,strength)
  elseif special=="bonemerang" then
    bonemerangFx(a,b,phase,p,strength)
  elseif special=="triattack" then
    triAttackFx(a,b,phase,p,strength)
  elseif special=="present" then
    presentFx(a,b,phase,p,strength)
  elseif special=="magnitude" then
    magnitudeFx(a,b,phase,p,strength)
  elseif special=="pursuit" then
    pursuitFx(a,b,phase,p,strength)
  elseif special=="swordsdance" then
    swordsDanceFx(a,phase,p,strength)
  elseif special=="recover" then
    recoverFx(a,phase,p,strength)
  elseif semanticFx(special,a,b,phase,p,strength,family) then
    -- Complete Gen-2 catalog routes which share reviewed semantic primitives.
  elseif family=="fire" then
    projectileTrail(tex.orb,a,b,phase,p,3.0*strength,7,3.0); targetBurst(tex.orb,b,phase,p,3.0)
  elseif family=="water" then
    projectileTrail(tex.water,a,b,phase,p,2.8*strength,8,3.0); targetBurst(tex.water,b,phase,p,2.8)
  elseif family=="electric" then
    lightningBolt(a,b,phase,p,2.15*strength,31,5); targetBurst(tex.electric,b,phase,p,3.4)
  elseif family=="ice" then
    projectileTrail(tex.ice,a,b,phase,p,2.5*strength,7,4.0); targetBurst(tex.ice,b,phase,p,3.0)
  elseif family=="psychic" then
    projectileTrail(tex.psychic,a,b,phase,p,2.8*strength,6,2.0); targetBurst(tex.psychic,b,phase,p,3.3)
  elseif family=="poison" then
    projectileTrail(tex.poison,a,b,phase,p,3.0*strength,7,4.0); targetBurst(tex.poison,b,phase,p,3.2)
  elseif family=="wind" then
    local travel=clamp((phase-.02)/.72,0,1)
    local cx,cy,cz=along(a,b,travel,0)
    tornadoFx({cx,cy,cz},phase,p,18,1.5,6.8,.92*strength)
    if phase>.58 then targetBurst(tex.wind,b,phase,p,4.0*strength) end
  elseif family=="grass" then
    projectileTrail(tex.leaf,a,b,phase,p,2.6*strength,8,4.5,phase*4); targetBurst(tex.leaf,b,phase,p,2.8)
  elseif family=="ghost" then
    projectileTrail(tex.shadow,a,b,phase,p,3.0*strength,7,4.5,phase*3); targetBurst(tex.shadow,b,phase,p,3.4)
  elseif family=="dragon" then
    projectileTrail(tex.psychic,a,b,phase,p,3.0*strength,7,3.0,phase*4); targetBurst(tex.orb,b,phase,p,3.2)
  elseif family=="ground" then
    groundRing(tex.dust,b,phase,p,12,8,2.3); targetBurst(tex.dust,b,phase,p,2.8)
  elseif family=="rock" then
    targetBurst(tex.dust,b,phase,p,3.2*strength); groundRing(tex.dust,b,phase,p,8,5,2.2)
  elseif family=="bug" then
    projectileTrail(tex.leaf,a,b,phase,p,2.3*strength,7,3.0,phase*5); targetBurst(tex.ring,b,phase,p,2.6)
  elseif family=="impact" and movePower>0 then
    targetBurst(tex.ring,b,phase,p,3.4*strength)
  else
    -- A move whose type/name is not in the current family table still gets a
    -- real 3D hit cue, so Gold never has to resurrect its sprite OBJ layer.
    projectileTrail(tex.ring,a,b,phase,p,2.2*strength,5,2.0)
    targetBurst(tex.ring,b,phase,p,2.8*strength)
  end
  return (tonumber(live.drawSerial) or 0) > drawBefore
end

function M.install()
  if installed or Stadium._stadiumPhase5WorldFx then return true end
  if type(Stadium.begin)~="function" or type(Stadium.update)~="function" or type(Stadium.draw)~="function" then
    return false, "Dramatic Shape Stadium world hooks unavailable"
  end

  local innerBegin, innerUpdate, innerUpdateGen2, innerDraw, innerFinish =
    Stadium.begin, Stadium.update, Stadium.updateGen2, Stadium.draw, Stadium.finish

  -- Observe Gold's own move-animation entry point.  v0.2.24 latches the
  -- presentation independently of Gold's AnimRunner object: Gold is allowed to
  -- swap from the move script to an after-hit/damage runner before the world
  -- canvas is rendered, and tying the 3D layer to that object made the effect
  -- vanish even though the move itself was still on screen.
  local goldToken = 0
  local function resolveGoldMoveDef(screen, moveId)
    local battle = screen and screen.battle
    if battle and type(battle.moveDef) == "function" then
      local okDef, def = pcall(battle.moveDef, battle, moveId)
      if okDef and type(def) == "table" then return def end
    end
    local data = (screen and screen.game and screen.game.data)
      or (battle and battle.data) or {}
    local moves = data and data.moves
    if type(moves) == "table" then
      local direct = moves[moveId]
      if type(direct) == "table" then return direct end
      local want = tonumber(moveId)
      for _, def in pairs(moves) do
        if type(def) == "table" then
          local index = tonumber(def.index or def.moveIndex or def.number)
          if want and index == want then return def end
          if type(moveId) == "string" then
            local id = tostring(def.id or def.name or "")
            if id == moveId then return def end
          end
        end
      end
    end
    return nil
  end

  local okGold, GoldBattleState = pcall(require, "src.ui.gen2.BattleState")
  if okGold and type(GoldBattleState) == "table"
      and type(GoldBattleState.animForMove) == "function"
      and not GoldBattleState._stadium3DFxMoveHook then
    local innerAnimForMove = GoldBattleState.animForMove
    GoldBattleState.animForMove = function(self, moveId, side, ...)
      local started = innerAnimForMove(self, moveId, side, ...)
      if moveId ~= nil and (side == "player" or side == "enemy") then
        goldToken = goldToken + 1
        self._stadium3DFxMove = moveId
        self._stadium3DFxSide = side
        self._stadium3DFxDef = resolveGoldMoveDef(self, moveId)
        self._stadium3DFxToken = goldToken
        self._stadium3DFxElapsed = 0
        self._stadium3DFxReadyToken = nil
        self._stadium3DFxReadyFrames = 0
      end
      return started
    end
    GoldBattleState._stadium3DFxMoveHook = true
  end

  -- Fail open. Gold's cartridge OBJ attack sprites are hidden only after the
  -- world-space renderer has successfully drawn the SAME latched move on at
  -- least two prior frames. If the 3D path is absent, late, or throws, Gold's
  -- original effect remains visible instead of v0.2.23's "nothing at all".
  if okGold and type(GoldBattleState) == "table"
      and type(GoldBattleState.drawSceneBody) == "function"
      and not GoldBattleState._stadium3DFxObjSuppress then
    local innerDrawSceneBody = GoldBattleState.drawSceneBody
    GoldBattleState.drawSceneBody = function(self, ...)
      local adapted = goldBattleAdapter(self)
      local token = adapted and adapted._goldToken
      local owns = token ~= nil
        and self._stadium3DFxReadyToken == token
        and (tonumber(self._stadium3DFxReadyFrames) or 0) >= 2
      local view = self and self.animView
      if owns and view and type(view.drawObjects) == "function" then
        local priorRaw = rawget(view, "drawObjects")
        view.drawObjects = function() end
        local out = { pcall(innerDrawSceneBody, self, ...) }
        if priorRaw ~= nil then view.drawObjects = priorRaw else view.drawObjects = nil end
        if not out[1] then error(out[2], 0) end
        table.remove(out, 1)
        local u=(table and table.unpack) or unpack
        if u then return u(out) end
        return
      end
      return innerDrawSceneBody(self, ...)
    end
    GoldBattleState._stadium3DFxObjSuppress = true
  end

  Stadium.begin = function(arena, ...)
    -- innerBegin starts by finishing the previous Stadium session. Set the FX
    -- arena only afterwards; doing it before that cleanup allowed the wrapped
    -- finish call to erase the new arena again.
    local out = { innerBegin(arena, ...) }
    if out[1] ~= false then
      live.arena, live.battle, live.groundY = arena, nil, 0
      live.attackerProfile, live.targetProfile = nil, nil
      pcall(buildTextures)
      if type(Stadium.effectProfile) == "function" then
        pcall(Stadium.effectProfile, "player")
        pcall(Stadium.effectProfile, "enemy")
      end
    end
    local u=(table and table.unpack) or unpack
    if u then return u(out) end
  end

  Stadium.update = function(dt, battle, groundY, ...)
    live.battle = battle or live.battle
    if groundY~=nil then live.groundY=groundY end
    return innerUpdate(dt, battle, groundY, ...)
  end

  if type(innerUpdateGen2) == "function" then
    Stadium.updateGen2 = function(dt, screen, groundY, ...)
      if type(screen) == "table" and screen._stadium3DFxToken ~= nil then
        local elapsed = (tonumber(screen._stadium3DFxElapsed) or 0)
          + math.max(0, tonumber(dt) or 0)
        screen._stadium3DFxElapsed = elapsed
        if elapsed > 1.10 then
          screen._stadium3DFxMove = nil
          screen._stadium3DFxSide = nil
          screen._stadium3DFxDef = nil
          screen._stadium3DFxToken = nil
          screen._stadium3DFxElapsed = nil
          screen._stadium3DFxReadyToken = nil
          screen._stadium3DFxReadyFrames = 0
        end
      end
      live.battle = goldBattleAdapter(screen)
      if groundY~=nil then live.groundY=groundY end
      return innerUpdateGen2(dt, screen, groundY, ...)
    end
  end

  Stadium.draw = function(pull, ...)
    local out={innerDraw(pull, ...)}
    local ok,drew=pcall(drawWorldFx,pull)
    if not ok then
      log("warn","Phase 5 world effect skipped: %s",tostring(drew))
    elseif drew and live.battle and live.battle._goldScreen then
      local screen = live.battle._goldScreen
      local token = live.battle._goldToken
      if token ~= nil then
        if screen._stadium3DFxReadyToken == token then
          screen._stadium3DFxReadyFrames =
            (tonumber(screen._stadium3DFxReadyFrames) or 0) + 1
        else
          screen._stadium3DFxReadyToken = token
          screen._stadium3DFxReadyFrames = 1
        end
      end
    end
    local u=(table and table.unpack) or unpack
    if u then return u(out) end
  end

  if type(innerFinish)=="function" then
    Stadium.finish = function(...)
      live.arena, live.battle, live.groundY = nil,nil,0
      live.attackerProfile, live.targetProfile = nil,nil
      return innerFinish(...)
    end
  end

  Stadium._stadiumPhase5WorldFx=true
  installed=true
  log("info","Pokemon Stadium Phase 5 world-space battle effects installed")
  return true
end

function M.coverage()
  return {
    generation=2,
    reviewedMoves=GEN2_REVIEWED_COUNT,
    expectedMoves=251,
    choreographyProfiles=GEN2_REVIEWED_PROFILE_COUNT,
    complete=GEN2_REVIEWED_COUNT==251,
    smartTargetAnchors=true,
  }
end

function M.anchorSnapshot()
  return {
    attacker=live.attackerProfile,
    target=live.targetProfile,
    arena=live.arena,
    groundY=live.groundY,
  }
end

function M.active() return installed and Stadium.active and Stadium.active() or false end
return M
