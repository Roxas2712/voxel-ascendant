-- The same setup draft and actions in a single-column touch layout.
local V=...;local L=V.require('SetupLocale').text;local M={};local fonts={}
function M.draw(s,sourceHelp)
 local G=love.graphics;local w,h=G.getDimensions();local scale=w/540;local height=h/scale
 local accent=V.require('EditionAccent').color(s.editionPreview)
 local ink={.95,.97,1,1};local muted={.74,.81,.9,1};local fill={.06,.12,.21,1}
 local hits={};s.physical={portrait=true,scale=scale,x=0,y=0,hits=hits}
 G.push('all');G.setCanvas();G.origin();G.setShader();G.setDepthMode();G.setScissor();G.setColor(.025,.045,.085,1);G.rectangle('fill',0,0,w,h);G.scale(scale,scale)
 local function panel(x,y,ww,hh,selected)
  G.setColor(fill);G.rectangle('fill',x,y,ww,hh,8)
  if selected then G.setColor(accent);G.setLineWidth(1.5);G.rectangle('line',x+.8,y+.8,ww-1.6,hh-1.6,8)end
 end
 local function text(value,x,y,ww,hh,size,color)
  value=tostring(value or '');local font
  repeat
   local px=math.max(8,math.floor(size*scale+.5));font=fonts[px]
   if not font then font=G.newFont(px);fonts[px]=font end
   local _,lines=font:getWrap(value,ww*scale)
   if #lines*font:getHeight()<=hh*scale or size<=10 then break end
   size=size-1
  until false
  G.push('all');G.setScissor(x*scale,y*scale,ww*scale,hh*scale);G.translate(x,y);G.scale(1/scale,1/scale);G.setFont(font);G.setColor(color or ink);G.printf(value,0,0,ww*scale,'left');G.pop()
 end
 local function hit(x,y,ww,hh,fn)hits[#hits+1]={x=x,y=y,w=ww,h=hh,action=fn}end
 local function button(x,y,ww,label,fn)panel(x,y,ww,40,true);text(label,x+8,y+9,ww-16,24,16);hit(x,y,ww,40,fn)end
 local p=s:current();local rows=s:rows();local summary=p.kind=='summary'
 text((s.kasc and 'VASC / KASC' or 'VASC')..' · '..L('YOUR LOOK','DEIN LOOK'),16,16,400,25,18)
 text(s.page..' / '..#s.pages,450,16,74,25,16,muted)
 text(p.title,16,52,508,46,23)
 local description=p.kind=='welcome'and L('Choose a style, then compare the preview below. Everything stays a draft until Apply.','Wähle einen Stil und vergleiche die Vorschau darunter. Bis zum Übernehmen bleibt alles ein Entwurf.')or p.description
 text(description,16,104,508,64,15,muted)
 local count=height>=840 and 4 or 3;local start=math.max(1,math.min(s.index-1,#rows-count+1))
 local rowY=180;local rowH=58
 for i=start,math.min(#rows,start+count-1)do
  local row=rows[i];local y=rowY+(i-start)*rowH;panel(16,y,508,52,i==s.index)
  text(row.label,26,y+5,488,row.key and 25 or 42,16,row.disabled and muted or ink)
  if row.key then text('< '..s:label(row)..' >',26,y+30,488,19,14,muted)end
  local index=i;hit(16,y,508,52,function()s.index=index;s.message=nil;s:refreshPreview();s:choose()end)
 end
 local navY=rowY+count*rowH+4
 button(16,navY,80,L('Up','Hoch'),function()s.index=math.max(1,s.index-1);s.message=nil;s:refreshPreview()end)
 text(s.index..' / '..#rows,110,navY+10,300,24,15,muted)
 button(444,navY,80,L('Down','Runter'),function()s.index=math.min(#rows,s.index+1);s.message=nil;s:refreshPreview()end)
 local footerY=height-58;local helpH=height>=840 and 132 or 94;local helpY=footerY-helpH-12
 local py=navY+52;local ph=helpY-py-12;local row=rows[s.index];local scene
 if ph>=100 and (p.kind=='world' or p.kind=='battle'and not(row and(row.key=='_battleGraphics'or row.key=='pokemonModelSkin'or row.action=='rom'or row.action=='content')))then
  local mode=s.draft[s.stageKey];local name=p.kind=='world'and 'world-'..(s.draft.outdoorHorizon or 'voxel')or 'battle-'..(mode==true and 'map'or mode==false and 'classic'or tostring(mode))
  s.sceneImages=s.sceneImages or {}
  if s.sceneImages[name]==nil then local ok,img=pcall(require('src.render.Assets').image,V.mod.assets:path('assets/setup-demo/'..name..'.png'));s.sceneImages[name]=ok and img or false end
  scene=s.sceneImages[name]
 end
 if ph>=100 then
  panel(16,py,508,ph,false)
  if p.kind=='battle_controls'then
   s:drawControlsPreview(22,py+4,496,ph-28)
   text(L('Layout preview · touch spacing can differ','Layoutvorschau · Touch-Abstände können abweichen'),26,py+ph-22,488,20,13,muted)
  elseif scene then
   local iw,ih=scene:getDimensions();local fit=math.min(488/iw,(ph-32)/ih);G.setColor(1,1,1,1);G.draw(scene,270-iw*fit/2,py+6,0,fit,fit)
   text(L('Example capture','Beispielaufnahme'),26,py+ph-24,488,20,13,muted)
  elseif p.kind=='people'or p.kind=='pokemon'or p.kind=='dex'or p.kind=='battle'then
   s.preview:draw(22,py+4,496,ph-28)
   text(L('Tap preview: next example','Vorschau antippen: nächstes Beispiel'),26,py+ph-22,488,20,13,muted)
   hit(16,py,508,ph,function()s.species=s.species%4+1;s:refreshPreview()end)
  elseif p.kind=='effect'then
   local d=V.require('SetupEffects').details(s.effects,p.effect,s.draft)
   text(L('Performance: ','Leistung: ')..d.performance..'\n'..L('Image: ','Bild: ')..d.visual..'\n'..L('Combination: ','Kombination: ')..d.combined,28,py+12,484,ph-24,16)
  else
   text(p.kind=='welcome'and L('Compare your look. Nothing changes until Apply.','Vergleiche deinen Look. Erst Übernehmen ändert die Einstellungen.')or s:recommendation(),28,py+12,484,ph-24,18)
  end
 else helpY=py;helpH=footerY-helpY-12 end
 local help=row and row.help or ''
 if row and row.context then help=sourceHelp[s.draft[row.key]]or help end
 if s.message then help=s.message
 elseif s.preview.error and not scene and(p.kind=='people'or p.kind=='pokemon'or p.kind=='dex'or p.kind=='battle')then help=help..'\n'..s.preview.error end
 panel(16,helpY,508,helpH,false);text(help,28,helpY+10,484,helpH-20,15,s.message and {1,.84,.5,1}or ink)
 button(16,footerY,130,L('Back','Zurück'),function()if s.subpage then s.subpage=nil else s.page=math.max(1,s.page-1)end;s.index=1;s:refreshPreview()end)
 button(158,footerY,180,L('Save for later','Später speichern'),function()s:pause()end)
 button(350,footerY,174,summary and L('Apply','Übernehmen')or L('Next','Weiter'),function()if summary then s:apply()else s:next()end end)
 G.pop()
end
return M
