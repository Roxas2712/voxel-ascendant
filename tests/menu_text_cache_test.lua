-- The cache must reduce allocations without changing glyphs, live values,
-- font reloads, or retaining an unbounded stream of diagnostic labels.
local splits, codes = 0, {}
local offset = 0
local Font = {BORDER={}}
function Font.split(value)
  splits = splits + 1
  local spans = {}
  for i=1,#value do spans[i]={from=i,to=i,code=value:byte(i)+offset} end
  return spans
end
function Font.advanceOf() return 8 end
function Font.spansFitting(spans,budget) return math.min(#spans,math.floor(budget/8)) end
function Font.drawCode(code,x,y) codes[#codes+1]=table.concat({code,x,y},':') end
package.loaded['src.render.Font']=Font
package.loaded['src.core.Strings']=function(s)return tostring(s)end
package.loaded['src.ui.Theme']={cursor=1,cursorHollow=2,moreArrow=3}
package.loaded['src.render.PaletteFX']={trueColorZone=function(x,y,w,h)return {x=x,y=y,w=w,h=h}end}
love={graphics={}}
for _,name in ipairs({'setColor','rectangle','setScissor','setLineWidth'})do love.graphics[name]=function()end end
love.graphics.getDimensions=function()return 1280,800 end
local root=os.getenv('VASC_TEST_ROOT') or '.'
local Style=assert(loadfile(root..'/lib/VascMenuStyle.lua'))()
local ui=Style.new({}, {skin='oras_fullscreen',language='en'})
local item={label='SUPPORT CODE',right='28735919',help='A increases the selected digit. LEFT/RIGHT selects one of the eight positions. Then select SEND SUPPORT LOG.'}
local menu=ui.decorateFocusHelp({title='VASC SUPPORT',index=1,scroll=0,items={item},footer='A:SELECT L/R:DIGIT B:BACK'},function(row)return row.help end,5)
local function draw()
  codes={};menu:draw();assert(not menu.__vascEmergencyCompactFallback,menu.__vascEmergencyCompactFallback)
  return table.concat(codes,';')
end
local expected=draw();local warm=splits
assert(draw()==expected);assert(splits==warm,'unchanged menu reparsed glyphs')
item.right='98765432';local changed=draw();assert(changed~=expected,'live code did not change')
Font.BORDER=nil -- Unknown provider: cache must be bypassed.
assert(draw()==changed,'cached live code differs from uncached rendering')
offset=1000;Font.BORDER={};local reloaded=draw()
assert(reloaded~=changed,'font reload retained old glyph codes')
Font.BORDER=nil;assert(draw()==reloaded,'font reload differs from uncached rendering')
Font.BORDER={};draw();local before=splits
for i=1,30 do draw()end
assert(splits==before,'warm menu split allocations returned')
local savedDraw=Font.drawCode;Font.drawCode=function()end
collectgarbage('collect');local memory=collectgarbage('count')
for i=1,2000 do
  item.label='LIVE '..i..string.rep('x',160)
  item.help='Sample '..i..string.rep('y',200)
  draw()
end
collectgarbage('collect')
assert(collectgarbage('count')-memory<2048,'diagnostic values grew the cache without bound')
Font.drawCode=savedDraw
item.help=string.rep('long help ',300)
local long=draw();Font.BORDER=nil;assert(draw()==long,'long uncached help changed layout')
print('PASS menu text cache: warm reuse, live values, font reload, unknown provider, bounded retention, long help')
