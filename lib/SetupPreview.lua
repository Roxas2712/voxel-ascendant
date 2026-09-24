-- Isolated presentation objects. Never touches a live actor or a model setting.
local V=...
local L=V.require('SetupLocale').text
local P={};P.__index=P
local Assets=require('src.render.Assets')
local shaderSource=[[
#ifdef VERTEX
attribute float VertexShade;
varying float shade;
uniform float turn;
uniform float fit;
uniform vec3 centre;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
 vec3 p=(vertex_position.xyz-centre)*fit;
 float x=p.x*cos(turn)+p.z*sin(turn);
 float z=-p.x*sin(turn)+p.z*cos(turn);
 shade=VertexShade;
 return vec4(x/180.0, -(p.y*0.94-z*0.34)/135.0, (z*0.94+p.y*0.34)/600.0,1.0);
}
#endif
#ifdef PIXEL
varying float shade;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
 vec4 c=Texel(tex,uv)*color;
 if(c.a<0.05) discard;
 return vec4(c.rgb*max(0.72,shade),c.a);
}
#endif
]]
function P.new(game)return setmetatable({game=game,time=0,dex=25},P)end
function P:release()
 if self.mon then self.mon:release();self.mon=nil end
 if self.canvas then self.canvas:release();self.canvas=nil end
end
function P:set(source,dex,human)
 local key=tostring(source)..':'..tostring(dex)..':'..tostring(human)
 if key==self.key then return end
 self:release();self.key=key;self.source=source;self.dex=dex or 25;self.human=human;self.error=nil;self.image=nil;self.anim=nil;self.sprite=nil;self.sheet=false;self.clip=nil;self.pendingHd=nil
 if human then
  local root='integrated/ascendant_pokemon_overworld/assets/characters/'
  local path=root..(source=='voxel' and 'voxel-demo/' or '')..'red_cards_4x3.png'
  if source=='classic' then
   local sprite=self.game.overworld and self.game.overworld.player and self.game.overworld.player.sprite
   self.error=L("Original character: preview follows the game. HD/Voxel shows Red as a style example.",'Originalfigur: Vorschau folgt dem Spiel. HD/Voxel zeigt Red als Stilbeispiel.')
   if type(sprite)=='table' and sprite.def then local api=V.mod.exports.overworldPokemon.walkingSprites;local def=api.fieldNativeDef(self.game.overworld.player,self.game.overworld) or sprite.def;self.sprite=require('src.render.SpriteRenderer').new(def);self.error=nil;return end
   return
  end
  local ok,img=pcall(Assets.image,V.mod.assets:path(path))
  if ok then self.image=img;self.sheet=true else self.error=L("Character preview unavailable.",'Figuren-Vorschau nicht verfügbar.') end
  return
 end
 self.sheet=false;self.runtimeSheet=false
 if source=='cobblemon' or source=='stadium2' then
  local ok,mon=pcall(function()
   local m=V.require('StadiumMon').new('preview',source=='cobblemon' and V.require('CobblemonPack') or nil)
   if not m:setSpecies(self.dex,true) then print('SETUP_MODEL_MISSING',self.dex);m:release();return nil end
   m:update(0);m:pose();m:upload();return m
  end)
  if not ok then print('SETUP_MODEL_ERROR',tostring(mon))end
  if ok and mon then
   self.mon=mon
   self.shader=self.shader or love.graphics.newShader(shaderSource)
   self.canvas=love.graphics.newCanvas(360,270)
   return
  end
  self.error=source=='stadium2' and L("Stadium model missing. Set up your own ROM import in the VASC menu.",'Stadium-Modell fehlt. Eigenen ROM-Import im VASC-Menü einrichten.') or L("Cobblemon preview unavailable. Check this build's model and texture loading. No separate installation is needed in current VASC builds. Fallback: game graphics.",'Cobblemon-Vorschau nicht verfügbar. Modell- und Texturladen dieser Version prüfen. Neue VASC-Versionen benötigen keine separate Einrichtung. Ersatz: Spielgrafik.')
 end
 local species=({[1]='BULBASAUR',[25]='PIKACHU',[6]='CHARIZARD',[133]='EEVEE'})[self.dex] or 'PIKACHU'
 self.species=species
 if source=='crystal' or source=='active' then
  local path
  if source=='crystal' then
   local ok,h=pcall(V.mod.find,'kanto_ascendant');if not ok or not h then ok,h=pcall(V.mod.find,V.mod,'kanto_ascendant')end
   local e=ok and h and h.exports
   if e and e.crystalSpriteProvider then local yes,r=pcall(e.crystalSpriteProvider.resolveFront,self.game.data,{species=species},{kind='dex',source='vasc_setup'});if yes and r then path=r.path end end
   if not path and e and e.crystalAnimation then local yes,r=pcall(e.crystalAnimation.staticFrameOne,{data=self.game.data,species=species,mon={species=species},kind='dex'},'front','normal');if yes then path=r end end
  else local ok,r=pcall(require('src.pokemon.Sprites').path,self.game.data,species,'front',{kind='dex'});if ok then path=r end end
  if path then local ok,img=pcall(Assets.image,path);if ok then self.image=img;return end end
  self.error=source=='crystal' and L("Crystal image missing. Open the Crystal pack directly below the choice. Fallback: game graphics.",'Crystal-Bild fehlt. Crystal-Paket direkt unter der Auswahl öffnen. Ersatz: Spielgrafik.') or L("Active sprite provider unavailable. Fallback: game graphics.",'Aktiver Sprite-Anbieter nicht verfügbar. Ersatz: Spielgrafik.')
 end
 if source=='pokemmo' or source=='full_hd' then
  local api=V.mod.exports.overworldPokemon.pokemonWalksheets
  local resolve=source=='pokemmo' and api.resolvePokeMMO or api.resolve
  local ok,r=pcall(resolve,self.game,{species=species})
  if ok and r and r.runtime then
   local cards=r.animationCards
   local rel=source=='full_hd' and r.atlas or r.runtime
   local path=V.mod.assets:path('integrated/ascendant_pokemon_overworld/'..rel)
   if source=='full_hd' and cards and cards.verified and cards.idle and cards.layout then path=cards.idle.sheet end
   local yes,img=pcall(Assets.image,path)
   if yes then
    self.image=img;self.runtimeSheet=source=='pokemmo';self.sheet=source=='full_hd';self.error=nil
    if source=='full_hd' and cards and cards.verified and cards.idle and cards.layout then
     self.clip={layout=cards.layout,columns=cards.idle.columns,duration=cards.idle.duration};self.sheet=false
    end
    return
   end
  end
 end
 if source=='full_hd' then
  local H=V.require('HdPokemonPresentation');local ok,a=pcall(H.create,self.game,{species=species},'front')
  if ok and a then self.anim=a;self.hd=H;return end
  self.hd=H;self.pendingHd={species=species};self.hdStarted=self.time
  self.error=L("HD pack for this example is missing or being prepared. Fallback: active game graphics.",'HD-Paket für dieses Beispiel fehlt oder wird vorbereitet. Ersatz: aktive Spielgrafik.')
 elseif source=='pokemmo' then
  local root='integrated/ascendant_pokemon_overworld/assets/'
  -- MMO sheets are optional; never mislabel the game sprite as an MMO preview.
  self.error=L("MMO preview needs the matching installed sprite pack. Fallback: active game graphics.",'MMO-Vorschau benötigt das passende installierte Spritepaket. Ersatz: aktive Spielgrafik.')
 end
 local def=self.game.data.pokemon[species]
 if def and def.spriteFront then local ok,img=pcall(Assets.image,def.spriteFront);if ok then self.image=img end end
end
function P:update(dt)
 self.time=self.time+dt
 if self.mon then self.mon:update(dt);self.mon:pose();self.mon:upload() end
 if self.pendingHd then
  self.hd.pump();local a,why=self.hd.create(self.game,self.pendingHd,'front')
  if a then self.anim=a;self.image=a.image;self.pendingHd=nil;self.error=nil end
 end
 if self.anim then self.hd.advancePresentation(self.anim,dt,self.game);self.image=self.anim.image end
end
function P:draw(x,y,w,h)
 local G=love.graphics
 G.setColor(0.02,0.055,0.09,1);G.rectangle('fill',x,y,w,h,14)
 G.setColor(0.10,0.25,0.29,1);G.ellipse('fill',x+w/2,y+h*.81,w*.28,h*.07)
 G.setColor(1,1,1,1)
 if self.mon then
  G.push('all');local old=G.getCanvas()
  G.setCanvas({self.canvas,depth=true});G.clear(0,0,0,0,true,true);G.origin();G.setShader(self.shader);G.setDepthMode('less',true);G.setMeshCullMode('none')
  local a,b,c,d,e,f=self.mon.rig:posedBounds()
  local size=math.max(d-a,e-b,f-c,1)
  self.shader:send('centre',{(a+d)/2,(b+e)/2,(c+f)/2});self.shader:send('fit',190/size);self.shader:send('turn',self.time*.2+3.14)
  for _,part in ipairs(self.mon.rig.parts)do if part.texture then part.mesh:setTexture(part.texture);G.draw(part.mesh)end end
  G.setCanvas(old);G.pop();G.setColor(1,1,1,1);G.draw(self.canvas,x,y,0,w/360,h/270)
 elseif self.sprite then
  G.push('all');G.translate(x+w/2-40,y+h*.8-80);G.scale(5,5);self.sprite:draw(0,0,0,0,'down',math.floor(self.time*5)%2,false);G.pop()
 elseif self.image then
  local iw,ih=self.image:getDimensions()
  if self.clip then
   local l=self.clip.layout;local col=math.floor((self.time%self.clip.duration)/self.clip.duration*self.clip.columns);local row=math.floor(self.time/4)%4
   local cw,ch=l.right-l.left,l.bottom-l.top;local quad=G.newQuad(col*l.cellWidth+l.left,row*l.cellHeight+l.top,cw,ch,iw,ih)
   local scale=math.min(w*.67/cw,h*.78/ch);G.draw(self.image,quad,x+w/2,y+h*.84,0,scale,scale,cw/2,ch);quad:release()
  elseif self.runtimeSheet then
   local ch=ih/6;local frame=math.floor(self.time*4)%2;local quad=G.newQuad(0,ch*frame,iw,ch,iw,ih);local scale=math.min(w*.65/iw,h*.8/ch);G.draw(self.image,quad,x+w/2,y+h*.84,0,scale,scale,iw/2,ch);quad:release()
  elseif self.sheet then
   local cw,ch=iw/3,ih/4;local col=math.floor(self.time*5)%3;local row=math.floor(self.time/3)%4
   local quad=G.newQuad(col*cw,row*ch,cw,ch,iw,ih);local s=math.min(w*.65/cw,h*.82/ch)
   G.draw(self.image,quad,x+w/2,y+h*.84,0,s,s,cw/2,ch);quad:release()
  else
   local s=math.min(w*.65/iw,h*.73/ih);G.draw(self.image,x+w/2,y+h*.83,0,s,s,iw/2,ih)
  end
 end
end
return P
