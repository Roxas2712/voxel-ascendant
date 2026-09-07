local function eq(actual, expected, label)
  assert(actual == expected, (label or '') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local handle = assert(io.open(arg[1] or 'battle_hud_oras.lua', 'rb'))
local source = handle:read('*a'); handle:close()
local function section(first, last)
  local a = assert(source:find(first, 1, true), first)
  local b = assert(source:find(last, a + #first, true), last)
  return source:sub(a, b-1)
end
local Font = require('src.render.Font')
local code = section('local function splitBattleMessageText', '-- Return the first physical pixel row')
  .. section('local function floatingHudLive', "-- Safari's BALLxNN")
  .. '\nreturn { message=visibleBattleMessageLines, textBox=visibleTextBoxMessageLines, live=floatingHudLive }'
local chunk = assert(loadstring(code, '@hud-release-regression'))
setfenv(chunk, setmetatable({Font=Font}, {__index=_G}))
local api = chunk()
local function shown(n) local t={} for i=1,n do t[i]=1 end return t end
for _, token in ipairs({'{PROMPT}','<PROMPT>','[PROMPT]'}) do
  local raw='Enemy GEODUDE!' .. token .. ' next'
  for count=0,#Font.split(raw) do
    local b={current={text=raw},shown={shown(count)},lineIndex=1}
    local actual=api.message(b)[1]
    local upto=count > 0 and Font.split(raw)[count].to or 0
    local expected=raw:sub(1,math.min(upto,14))
    if upto > 14+#token then expected=expected .. raw:sub(15+#token,upto) end
    eq(actual,expected,'typewriter marker ' .. token .. ' at ' .. count)
  end
  local b={current={text='Sucked health from\nEnemy GEODUDE!' .. token},shown={shown(17),shown(30)},lineIndex=2,msgPrompt=true}
  eq(table.concat(api.message(b),'\n'),'Sucked health from\nEnemy GEODUDE!','drain page')
  b.current=nil; b.msgPrompt=nil; b.msgHold=true
  eq(table.concat(api.message(b),'\n'),'Sucked health from\nEnemy GEODUDE!','held page')
  local box={shown={shown(17)},visibleText=function() return {'A' .. token .. 'B'} end}
  eq(api.textBox(box)[1],'AB','textbox marker')
end
local b={current={text='Choose a PROMPT option'},shown={shown(40)},lineIndex=1,msgWaiting=true}
eq(api.message(b)[1],'Choose a PROMPT option','ordinary word')
local prepared='Enemy GEODUDE! next'
for count=0,#Font.split(prepared) do
  local b={current={text='Enemy GEODUDE!{PROMPT} next'},
    lines={{text=prepared}},shown={shown(count)},lineIndex=1}
  eq(api.message(b)[1],prepared:sub(1,count),'engine-prepared glyph count')
end
local pages={current={text='one{PROMPT}\ntwo\vthree{PROMPT}'},
  lines={{text='one'},{text='two'},{text='three'}},shown={shown(3),shown(5)},lineIndex=3,msgWaiting=true}
eq(table.concat(api.message(pages),'|'),'two|three','CONT rolling page')
local battle = {player={mon={hp=85}}, enemy={mon={hp=0}, shownHP=12}}
eq(api.live(battle,0), true, 'HP still draining')
battle.enemy.fainted=true
eq(api.live(battle,0), false, 'fainted enemy card')
battle.enemy={mon={hp=30}, shownHP=30}
eq(api.live(battle,0), true, 'next enemy card')
battle.enemySendingOut=true
eq(api.live(battle,0), false, 'send-out card')
battle.enemySendingOut=nil
battle.player.fainted=true
local _, player=api.live(battle,0)
eq(player,false,'own faint card')
print('battle HUD release regressions: ok')
