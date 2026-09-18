-- Download screens follow KASC's existing 160x144 options layout.
local M={}
function M.clean(value)
  local s=tostring(value or '')
  for a,b in pairs({['ä']='ae',['ö']='oe',['ü']='ue',['Ä']='Ae',['Ö']='Oe',['Ü']='Ue',['ß']='ss',['é']='e',['É']='E',['—']=' - ',['–']='-', ['→']=' > ',['&']='/'})do s=s:gsub(a,b)end
  return (s:gsub('[^\32-\126\n]',''))
end
function M.new(mod,game,spec)
  local Font=require('src.render.Font');local Theme=require('src.ui.Theme')
  local screen={game=game,items=spec.rows,index=1,scroll=0,isOpaque=true,key=spec.key}
  local function fit(s,width)
    s=M.clean(s)
    if Font.width(s)<=width then return s end
    while #s>0 and Font.width(s..'..')>width do s=s:sub(1,-2)end
    return s..'..'
  end
  function screen:sgbPalettes()return {require('src.render.PaletteFX').trueColorZone(0,0,19,17)}end
  function screen:update()
    local input=self.game.input;local count=#self.items
    if count==0 then return end
    self.index=math.max(1,math.min(self.index,count))
    if input:wasPressed('up')then self.index=(self.index-2)%count+1
    elseif input:wasPressed('down')then self.index=self.index%count+1
    elseif input:wasPressed('a')then spec.onChoose(self.items[self.index])
    elseif input:wasPressed('select')then
      local row=self.items[self.index]
      local text=M.clean(row.label)..'\n'..M.clean(row.right)..'\n\n'..M.clean(row.help or spec.help)
      self.game.stack:push(require('src.render.TextBox').new(self.game,text))
    elseif input:wasPressed('b')then self.game.stack:pop()end
    if self.index<=self.scroll then self.scroll=self.index-1
    elseif self.index>self.scroll+5 then self.scroll=self.index-5 end
  end
  function screen:draw()
    local g=love.graphics
    g.setColor(.06,.18,.36,1);g.rectangle('fill',0,0,160,144)
    g.setColor(.18,.52,.82,1);g.rectangle('fill',0,0,160,18)
    g.setColor(1,1,1,1);Font.draw(fit(spec.title,150),5,5)
    for slot=1,5 do
      local i=self.scroll+slot;local row=self.items[i];if not row then break end
      local y=20+(slot-1)*21;local chosen=i==self.index
      g.setColor(chosen and .98 or .94,chosen and .72 or .91,chosen and .18 or .76,1)
      g.rectangle('fill',3,y,154,19);g.setColor(.06,.12,.20,1)
      local label=({['CHOOSE FILE / IMPORT']='FILE / IMPORT',['DATEI WÄHLEN / IMPORTIEREN']='DATEI IMPORTIEREN'})[row.label]or row.label
      Font.draw(fit(label,138),14,y+2)
      Font.draw(fit(row.right,138),14,y+10)
      if chosen then Font.drawCode(Theme.cursor,5,y+5)end
    end
    g.setColor(.18,.52,.82,1);g.rectangle('fill',0,124,160,20)
    g.setColor(1,1,1,1);Font.draw('A:OK SEL:HELP',3,126)
    Font.draw('B:BACK  '..self.index..'/'..#self.items,3,135)
  end
  return screen
end
return M
