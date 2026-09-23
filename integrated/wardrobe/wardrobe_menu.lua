return function(mod,opts)
  local W=assert(opts.wardrobe)
  local M={}
  local function tr(en,de)return opts.i18n and opts.i18n.text(en,de)or en end
  local function pop(game,screen)if game.stack:top()==screen then game.stack:pop()end end
  local function copy(t)local result={};for k,v in pairs(t)do result[k]=v end;return result end
  local labels={head={'Headwear','Kopfbedeckung'},hairstyle={'Hairstyle','Frisur'},hair={'Hair colour','Haarfarbe'},
    ash={'L cap','L-Cap'},ash_back={'L cap backwards','L-Cap rueckwaerts'},
    streak={'Highlights','Straehnen'},eyewear={'Glasses','Brille'},upper={'Top','Oberteil'},lower={'Bottom / dress','Hose / Kleid'},footwear={'Shoes','Schuhe'},
    classic={'Outfit cap','Outfit-Cap'},none={'None','Keine'},backward={'Cap backwards','Cap rueckwaerts'},beanie={'Beanie','Wollmuetze'},
    bag={'Bag','Tasche'},pink={'Pink','Rosa'},
    standard={'Standard','Normal'},spiky={'Spiky','Spiky'},natural={'Natural','Natur'},
    black={'Black','Schwarz'},brown={'Brown','Braun'},blond={'Blond','Blond'},silver={'Silver','Silber'},
    red={'Red','Rot'},blue={'Blue','Blau'},purple={'Purple','Violett'},glasses={'Glasses','Brille'},
    sunglasses={'Sunglasses','Sonnenbrille'},preset={'Outfit default','Wie Outfit'},original={'Original','Original'},
    hoodie={'Hoodie','Kapuzenjacke'},field={'Field jacket','Feldjacke'},league={'League jacket','Ligajacke'},
    sailor={'Sailor shirt','Streifenshirt'},raincoat={'Raincoat','Regenjacke'},fleece={'Fleece','Fleecejacke'},
    sport={'Sport shirt','Sportshirt'},vest={'Utility vest','Weste'},shirt={'Dress shirt','Hemd'},cardigan={'Cardigan','Strickjacke'},tee={'T-shirt','T-Shirt'},
    sneakers={'Sneakers','Sneaker'},ankleboots={'Ankle boots','Schnuerboots'},tallboots={'Tall boots','Stiefel'},loafers={'Loafers','Halbschuhe'},
    jeans={'Jeans','Jeans'},cargo={'Cargo trousers','Cargohose'},track={'Track trousers','Trainingshose'},
    shorts={'Shorts','Shorts'},skirt={'Skirt','Rock'},dress={'Dress','Kleid'}}
  local function label(key)local pair=labels[key];return pair and tr(pair[1],pair[2])or key end
  function M.customize(game,id,preview)
    if not W.appearanceReady then return false,'art-under-revision'end
    local List=mod.ui.KantoListMenu or mod.ui.ListMenu
    local menu
    local function rows()
      local result={}
      for _,key in ipairs({'upper','lower','footwear','head','bag','hairstyle','eyewear','hair','streak'})do
        if (key~='hairstyle'or id=='RED')and(key~='bag'or id=='GREEN')then
          local values=W.assets.options and W.assets.options(id,preview.selection,key)or W.options[key]
          if #values>1 then result[#result+1]={key=key,label=label(key),right=label(preview.selection[key]or W.options[key][1])}end
        end
      end
      result[#result+1]={label=tr('BACK TO PREVIEW','ZUR VORSCHAU'),close=true}
      return result
    end
    menu=List.new(game,tr('CUSTOMIZE','KOMBINIEREN'),rows(),{
      footer=tr('A:CHOOSE B:BACK','A:WAHL B:ZURUECK'),onCancel=function()pop(game,menu)end,
      onChoose=function(item)
        if item.close then pop(game,menu);return end
        local choices={};local sub
        local values=W.assets.options and W.assets.options(id,preview.selection,item.key)or W.options[item.key]
        for _,value in ipairs(values)do choices[#choices+1]={label=label(value),value=value,
          right=preview.selection[item.key]==value and'*'or nil}end
        sub=List.new(game,label(item.key),choices,{footer=tr('A:PREVIEW B:BACK','A:VORSCHAU B:ZURUECK'),
          onCancel=function()pop(game,sub)end,onChoose=function(choice)
            local candidate=copy(preview.selection);candidate[item.key]=choice.value
            if item.key=='hairstyle'and choice.value=='spiky'then candidate.head='none'end
            if item.key=='head'and choice.value~='none'then candidate.hairstyle='standard'end
            local ok,why=preview:setSelection(candidate)
            if ok then pop(game,sub);pop(game,menu)else preview.error=tr('Art unavailable','Grafik fehlt');preview.detail=why;pop(game,sub);pop(game,menu)end
          end})
        game.stack:push(sub)
      end})
    game.stack:push(menu);return menu
  end
  local function previewPath(id,selection)
    if W.walker2d and W.presentation.mode(selection)=='2d'then
      return W.walker2d.build(id,selection),1,6
    end
    if selection.style~='native'then
      return W.presentation.resolve(W.assets.sources(id)[1],id,selection),3,4
    end
    return W.resolve(mod.path..'/assets/characters/crystal_chars/'..id:lower()..'_walk.png',id,selection),1,6
  end
  function M.preview(game,id,row,selection)
    local screen={isOpaque=true,age=0,direction=0,selection=copy(selection),error=nil,wardrobePreviewOwner=M}
    local image,cols,rows,quads
    local function load()
      screen.presentationMode=W.presentation.mode(screen.selection)
      if screen.hdSurface then screen.hdSurface:release();screen.hdSurface=nil end
      screen.hdReceipt=nil
      local path;path,cols,rows=previewPath(id,screen.selection)
      screen.imagePath=path
      image=require('src.render.Assets').image(path)
      local w,h=image:getDimensions();quads={}
      for y=0,rows-1 do quads[y]={};for x=0,cols-1 do quads[y][x]=love.graphics.newQuad(x*w/cols,y*h/rows,w/cols,h/rows,w,h)end end
    end
    load()
    local function ensureMode()
      if screen.presentationMode~=W.presentation.mode(screen.selection)then load()end
    end
    function screen:setSelection(candidate)
      local ok,why=W.assets.prepare(id,candidate,game)
      if not ok then return false,why end
      self.selection=copy(candidate);self.error=nil;load();return true
    end
    function screen:sgbPalettes()
      return {require('src.render.PaletteFX').trueColorZone(0,0,19,17)}
    end
    function screen:update(dt)
      ensureMode()
      self.age=self.age+dt
      local input=game.input
      if input:wasPressed('b')then pop(game,self);return end
      if input:wasPressed('left')then self.direction=(self.direction+3)%4 end
      if input:wasPressed('right')then self.direction=(self.direction+1)%4 end
      if W.appearanceReady and self.selection.style~='native'and input:wasPressed('select')then
        M.customize(game,id,self);return
      end
      if input:wasPressed('a')then
        local ok,why=W.choose(id,self.selection,game)
        if ok then pop(game,self)else self.error=tr('Cannot change now','Wechsel nicht moeglich');self.detail=why end
      end
    end
    function screen:draw()
      ensureMode()
      local G=love.graphics;local Font=require('src.render.Font')
      G.clear(1,1,1,1);G.setColor(0,0,0,1)
      Font.draw(tr(row.en,row.de),8,4)
      Font.draw(self.presentationMode:upper(),136,4)
      Font.drawBox(1,2,18,12)
      local w,h=image:getDimensions();local cw,ch=w/cols,h/rows
      local direction=self.direction
      local column=math.floor(self.age*7)%4;column=({0,1,0,2})[column+1]
      local r=direction
      local flip=false
      if cols==1 then
        local walking=column~=0
        r=({0,2,1,2})[direction+1]+(walking and 3 or 0)
        flip=direction==3 or(direction%2==0 and column==2)
        column=0
      end
      local scale=math.min(75/cw,(cols==3 and 82 or 84)/ch)
      G.setColor(1,1,1,1)
      if cols==1 then scale=math.floor(scale)end
      G.draw(image,quads[r][math.min(column,cols-1)],80+(flip and 1 or -1)*cw*scale/2,23,0,flip and -scale or scale,scale)
      require('src.render.PaletteFX').markTrueColor(80-cw*scale/2,23,cw*scale,ch*scale)
      G.setColor(0,0,0,1)
      Font.draw(self.error or tr('A:WEAR B:BACK','A:AN B:ZURUECK'),4,118)
      Font.draw(W.appearanceReady and self.selection.style~='native'and tr('SEL:PARTS LR:TURN','SEL:TEILE LR:DREH')or tr('L/R:TURN','L/R:DREHEN'),4,132)
      G.setColor(1,1,1,1)
    end
    function screen:drawHD(viewport)
      ensureMode()
      if self.selection.style=='native'or cols==1 then return end
      local G=love.graphics
      local pixelScale=tonumber(viewport.scale)or 1
      local dpiX,dpiY=tonumber(viewport.dpiX)or 1,tonumber(viewport.dpiY)or 1
      -- Stop above the inner bottom rule of Font.drawBox. An 84px white
      -- surface used to erase the middle of that rule when drawn in the HUD.
      local width,height=math.ceil(120*pixelScale),math.ceil(82*pixelScale)
      if not self.hdSurface or self.hdSurface:getWidth()~=width or self.hdSurface:getHeight()~=height then
        if self.hdSurface then self.hdSurface:release()end
        self.hdSurface=require('src.render.PixelCanvas').new(width,height,'nearest')
      end
      local w,h=image:getDimensions();local cw,ch=w/cols,h/rows
      local column=({0,1,0,2})[math.floor(self.age*7)%4+1]
      local scale=math.min(75/cw,82/ch)
      local minFilter,magFilter,anisotropy=image:getFilter()
      G.push('all')
      local ok,err=pcall(function()
        G.setCanvas(self.hdSurface);G.origin();G.setScissor();G.setShader();G.setBlendMode('alpha')
        G.clear(1,1,1,1);G.setColor(1,1,1,1)
        -- Rasterize the ORIGINAL atlas directly at framebuffer density. The
        -- 160x144 draw above is only the low-resolution/error fallback.
        G.scale(pixelScale,pixelScale)
        image:setFilter('linear','linear')
        G.draw(image,quads[self.direction][column],60-cw*scale/2,0,0,scale,scale)
      end)
      image:setFilter(minFilter,magFilter,anisotropy)
      G.pop()
      if not ok then error(err,0)end
      G.push('all')
      local presented,problem=pcall(function()
        G.setCanvas();G.origin();G.setScissor();G.setShader();G.setBlendMode('alpha');G.setColor(1,1,1,1)
        G.draw(self.hdSurface,(viewport.gameX or 0)+20*pixelScale/dpiX,
          (viewport.gameY or 0)+23*pixelScale/dpiY,0,1/dpiX,1/dpiY)
      end)
      G.pop();if not presented then error(problem,0)end
      self.hdReceipt={sourceWidth=cw,sourceHeight=ch,surfaceWidth=width,surfaceHeight=height,
        spritePixelHeight=ch*scale*pixelScale,frame=column,direction=self.direction,pixelScale=pixelScale}
    end
    function screen:exit()
      if self.hdSurface then self.hdSurface:release();self.hdSurface=nil end
    end
    game.stack:push(screen);return screen
  end
  function M.new(game)
    local id=W.character();local menu
    local function items()
      local current=W.get(id);local result={}
      for _,row in ipairs(W.rows(id))do
        result[#result+1]={label=tr(row.en,row.de),row=row,
          right=current.outfit==row.id and current.style=='hd'and'*'or nil}
      end
      result[#result+1]={label=tr('VANILLA SPRITES','VANILLA-SPRITES'),native=true,
        right=current.style=='native'and'*'or nil,row={id='original',en='VANILLA',de='VANILLA'}}
      result[#result+1]={label=tr('CLOSE','SCHLIESSEN'),close=true}
      return result
    end
    local List=mod.ui.KantoListMenu or mod.ui.ListMenu
    menu=List.new(game,tr('WARDROBE','KLEIDERSCHRANK'),items(),{
      footer=tr('A:PREVIEW B:CLOSE','A:VORSCHAU B:ZURUECK'),
      onCancel=function()pop(game,menu)end,
      onChoose=function(item)
        if item.close then pop(game,menu);return end
        local selection=W.get(id)
        selection.outfit=item.row.id;selection.style=item.native and'native'or'hd'
        selection.upper='preset';selection.lower='preset';selection.footwear='preset'
        if W.assets.forOutfit then selection=W.assets.forOutfit(id,selection)end
        if item.native or not W.appearanceReady then selection={outfit='original',head='classic',style=item.native and'native'or'hd',hair='natural',streak='none',eyewear='none',hairstyle='standard',upper='preset',lower='preset',footwear='preset'}end
        M.preview(game,id,item.row,selection)
      end})
    local update=menu.update
    menu.update=function(self,dt)self.items=items();return update(self,dt)end
    return menu
  end
  function M.open(game)
    W.bind(game)
    local allowed,why=W.canChange(game);if not allowed then return false,why end
    local screen=M.new(game);game.stack:push(screen);return screen
  end
  if mod.hooks and type(mod.hooks.wrap)=='function'then
    M.unsubscribeHD=mod.hooks:wrap('render.hud',function(nextHud,game,viewport)
      nextHud(game,viewport)
      local top=game and game.stack and game.stack:top()
      if not top or top.wardrobePreviewOwner~=M then return end
      local ok,err=pcall(top.drawHD,top,viewport)
      M.hdError=not ok and tostring(err)or nil
    end,125)
  end
  return M
end
