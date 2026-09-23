-- One set of live option owners: keyboard and touch never keep separate values.
local V=...
local M={PEOPLE_KEY="f6",FOLLOWER_KEY="f7",SPRITES_KEY="0",settings={}}
local Game=require("src.core.Game")
local unpack=table.unpack or unpack
local function pack(...)return{n=select("#",...),...}end
local function top(game)return game and game.stack and game.stack:top()end
local function loaded(game)
  local t=top(game)
  return game and game.save and game.overworld and t and not t.onKeyPressed
    and not t.imeActive
end
local function battle(game)
  for _,s in ipairs(game.stack and game.stack.states or {})do
    if s.player and s.enemy and s.data and s.phase then return s end
  end
end
local function notify(title,value)V.require("ShortcutToast").notify(title,value)end
local function api()return V.mod.exports and V.mod.exports.overworldPokemon end
function M.people(game)
  local setting=M.settings.apo_hd_walking_sprites
  if not loaded(game) or not setting or not (api() and api().walkingSprites)then return false end
  local card=V.mod.exports.voxelCharacterCard
  if card then
    if not card.cycle(game)then notify('[F6] PERSONEN','Nach der Aktion umschalten');return true end
    notify('[F6] PERSONEN',card.label())
  else
    setting:cycle(game);notify('[F6] PERSONEN',setting:get()and'HD'or'2D / ORIGINAL')
  end
  return true
end
function M.followerChoices(game)
  local s=M.settings.apo_follower_sprite_source
  local rows={{id="original",label="2D / ORIGINAL"}}
  if not s then return rows end
  for i,id in ipairs(s.values)do
    local available=s:allows(i)
    local content=V.mod.exports and V.mod.exports.ascendantContent
    if content and content.store then
      local style=V.require("SpriteSettingContent").required(s.key,id)
      if style then available=available and content.store:styleMounted(style)==true end
    end
    if id=="stadium2" then
      local probe=V.mod.exports and V.mod.exports.overworldPokemonModelAvailable
      local mon=game and game.save and game.save.party and game.save.party[1]
      local def=mon and game.data and game.data.pokemon[mon.species]
      local dex=def and(def.dex or def.dexNo or def.number)
      local ok,yes=pcall(function()return probe and probe(dex)end)
      available=available and ok and yes==true
    end
    if available then rows[#rows+1]={id=id,label=s.labels[i]}end
  end
  return rows
end
function M.followers(game)
  local source,on=M.settings.apo_follower_sprite_source,M.settings.apo_hd_pokemon_followers
  if not loaded(game)or not source or not on or not(api()and api().pokemonWorldSprites)then return false end
  local current=on:get()and source:get()or"original"
  local rows=M.followerChoices(game);local at=0
  for i,r in ipairs(rows)do if r.id==current then at=i end end
  local nextRow=rows[at%#rows+1]
  if nextRow.id=="original"then on:setValue(false,game)
  else
    source:setValue(nextRow.id,game)
    if source:get()==nextRow.id then on:setValue(true,game)end
  end
  local actual=on:get()and source:get()or"original"
  for _,r in ipairs(rows)do if r.id==actual then notify("[F7] BEGLEITER",r.label)end end
  return true
end
function M.open(game)
  if not loaded(game)or battle(game)then return false end
  if top(game)._vascSpriteSettings then return true end
  local previous=top(game)
  V.mod.ui.push(game,"VascSettings",{section="pokemon"})
  local t=top(game)
  if not t or t==previous then return false end
  t._vascSpriteSettings=true
  return true
end
function M.actions(game)
  if not loaded(game)or battle(game)or top(game)._vascSpriteSettings then return{}end
  local rows={{label="[0] Sprite-Auswahl",fn=M.open}}
  if top(game)==game.overworld then
    if M.settings.apo_hd_walking_sprites and api()and api().walkingSprites then
      rows[#rows+1]={label="[F6] Personen: "..(V.mod.exports.voxelCharacterCard and V.mod.exports.voxelCharacterCard.label()or(M.settings.apo_hd_walking_sprites:get()and"HD"or"2D")),fn=M.people}
    end
    if M.settings.apo_follower_sprite_source and api()and api().pokemonWorldSprites then
      rows[#rows+1]={label="[F7] Begleiter wechseln",fn=M.followers}
    end
  end
  return rows
end
function M.draw(game)
  M.paint=nil
  -- The unified panel owns these buttons; do not stack a second shortcut
  -- strip underneath its launcher (especially in short/narrow windows).
  if V.Controls then return end
  local rows=M.actions(game);if #rows==0 then return end
  local g=love.graphics;local w,h=g.getDimensions()
  local s=math.max(.7,math.min(1.5,w/960,h/600))
  g.push("all");g.origin();g.setCanvas();g.setShader();g.setScissor();g.setBlendMode("alpha")
  M.font=M.font or g.newFont(13);g.setFont(M.font)
  for i,row in ipairs(rows)do
    local r={12*s,(82+(i-1)*34)*s,190*s,30*s};row.rect=r
    g.setColor(.025,.07,.10,.9);g.rectangle("fill",r[1],r[2],r[3],r[4],5,5)
    g.setColor(.2,.75,.83,1);g.rectangle("line",r[1],r[2],r[3],r[4],5,5)
    g.setColor(1,1,1,1);g.print(row.label,r[1]+8*s,r[2]+7*s,0,s,s)
  end
  g.pop();M.paint={screen=top(game),w=w,h=h,rows=rows}
end
function M.press(game,x,y)
  local p=M.paint;if not p or p.screen~=top(game)or not loaded(game)then return false end
  local w,h=love.graphics.getDimensions();if w~=p.w or h~=p.h then return false end
  for _,row in ipairs(p.rows)do
    local r=row.rect
    if x>=r[1]and x<r[1]+r[3]and y>=r[2]and y<r[2]+r[4]then
      M.paint=nil;return row.fn(game)
    end
  end
  return false
end
function M.install(entries)
  for _,row in ipairs(entries)do local s=row[1];M.settings[s.key]=s end
  if M.installed then return end;M.installed=true
  local key=Game.keypressed
  function Game:keypressed(k,...)
    if k==M.PEOPLE_KEY and M.people(self)then return end
    if k==M.FOLLOWER_KEY and M.followers(self)then return end
    if k==M.SPRITES_KEY and M.open(self)then return end
    return key(self,k,...)
  end
  local draw=Game.draw
  function Game:draw(...)local result=pack(draw(self,...));M.draw(self);return unpack(result,1,result.n)end
  V.mod.hooks:wrap("input.pointer",function(next,game,p)
    if p and p.phase=="pressed"and(p.source=="touch"or p.source=="mouse")
      and(p.source~="mouse"or p.button==nil or p.button==1)and M.press(game,p.x,p.y)then return true end
    return next(game,p)
  end,2000001)
  V.Controls=V.require("VascControls")
  V.Controls.install(M)
end
return M
